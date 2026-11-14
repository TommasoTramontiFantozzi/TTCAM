unit Svg2GcodeClipperEngine;

{$mode objfpc}{$H+}
{$inline on}

interface

uses
  SysUtils, Classes, Math, DOM, XMLRead, Contnrs, clipper;

type
  TPoint2D = record
    X, Y: Double;
  end;
  TContour = array of TPoint2D;
  TContourArray = array of TContour;

type
  TViewBoxArray = array[0..3] of Single;

  // Support class storing contour details before generating G-code
  TStoredContour = class
  public
    Points: TContour;
    Holes: TContourArray;
    IsClosed: Boolean;
    StrokeWidth: Double;
    FillColor: string;
    constructor Create(const APoints: TContour; AIsClosed: Boolean; AStrokeWidth: Double; const AFillColor: string);
    procedure AddHole(const AHole: TContour; AHoleClosed: Boolean);
  end;

function ConvertSvgToVectorGCodeClipper(
  const FileSvg: TMemoryStream;
  FeedRateXY: Integer;
  FeedRateZ: Integer;
  ZSicura: Double;
  ZStart: Double;
  ZDepth: Double;
  ZStep: Double;
  DiametroFresaMM: Double;
  tipo_comp: Byte;         // Compensation: 0 = Internal, 1 = External, 2 = None
  NumTabs: Integer;
  SpessoreTabMM: Double;
  FattoreScala: Double;
  HelicalRamp: Boolean;
  ClimbMilling: Boolean;
  FinishAllowance: Double
): string;

implementation

const
  ClipScale = 100000.0; // Fattore di scala per convertire i Double in interi per Clipper

// Helper per creare al volo un record TPoint2D senza errori di cast
function MakePoint2D(const AX, AY: Double): TPoint2D; inline;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function FloatPointToIntPoint(const Pt: TPoint2D): TIntPoint; inline;
begin
  Result.X := Round(Pt.X * ClipScale);
  Result.Y := Round(Pt.Y * ClipScale);
end;

function IntPointToFloatPoint(const Pt: TIntPoint): TPoint2D; inline;
begin
  Result.X := Pt.X / ClipScale;
  Result.Y := Pt.Y / ClipScale;
end;

constructor TStoredContour.Create(const APoints: TContour; AIsClosed: Boolean; AStrokeWidth: Double; const AFillColor: string);
var
  I, CleanCount: Integer;
  PtPrec, PFirst, PLast: TPoint2D;
  ContornoClean: TContour;
begin
  IsClosed := AIsClosed;
  StrokeWidth := AStrokeWidth;
  FillColor := AFillColor;
  SetLength(Holes, 0);

  if Length(APoints) = 0 then
  begin
    SetLength(Points, 0);
    Exit;
  end;

  SetLength(ContornoClean, Length(APoints));
  CleanCount := 0;
  for I := 0 to High(APoints) do
  begin
    if CleanCount > 0 then
    begin
      PtPrec := ContornoClean[CleanCount - 1];
      if (Abs(APoints[I].X - PtPrec.X) < 0.00001) and (Abs(APoints[I].Y - PtPrec.Y) < 0.00001) then
        Continue;
    end;
    ContornoClean[CleanCount] := APoints[I];
    Inc(CleanCount);
  end;
  SetLength(ContornoClean, CleanCount);

  if IsClosed and (CleanCount >= 2) then
  begin
    PFirst := ContornoClean[0];
    PLast := ContornoClean[CleanCount - 1];
    if (Abs(PFirst.X - PLast.X) < 0.00001) and (Abs(PFirst.Y - PLast.Y) < 0.00001) then
    begin
      Dec(CleanCount);
      SetLength(ContornoClean, CleanCount);
    end;
  end;

  SetLength(Points, CleanCount);
  for I := 0 to CleanCount - 1 do
    Points[I] := ContornoClean[I];
end;

procedure TStoredContour.AddHole(const AHole: TContour; AHoleClosed: Boolean);
var
  I, CleanCount: Integer;
  PtPrec, PFirst, PLast: TPoint2D;
  ContornoClean: TContour;
begin
  if Length(AHole) = 0 then Exit;

  SetLength(ContornoClean, Length(AHole));
  CleanCount := 0;
  for I := 0 to High(AHole) do
  begin
    if CleanCount > 0 then
    begin
      PtPrec := ContornoClean[CleanCount - 1];
      if (Abs(AHole[I].X - PtPrec.X) < 0.00001) and (Abs(AHole[I].Y - PtPrec.Y) < 0.00001) then
        Continue;
    end;
    ContornoClean[CleanCount] := AHole[I];
    Inc(CleanCount);
  end;
  SetLength(ContornoClean, CleanCount);

  if AHoleClosed and (CleanCount >= 2) then
  begin
    PFirst := ContornoClean[0];
    PLast := ContornoClean[CleanCount - 1];
    if (Abs(PFirst.X - PLast.X) < 0.00001) and (Abs(PFirst.Y - PLast.Y) < 0.00001) then
    begin
      Dec(CleanCount);
      SetLength(ContornoClean, CleanCount);
    end;
  end;

  SetLength(ContornoClean, CleanCount);
  SetLength(Holes, Length(Holes) + 1);
  Holes[High(Holes)] := ContornoClean;
end;

function IsPolygonClockwise(const Contour: TContour): Boolean;
var
  I, J: Integer;
  Area: Double;
begin
  Area := 0;
  if Length(Contour) < 3 then Exit(False);
  J := High(Contour);
  for I := 0 to High(Contour) do
  begin
    Area := Area + (Contour[J].X + Contour[I].X) * (Contour[J].Y - Contour[I].Y);
    J := I;
  end;
  Result := Area > 0;
end;

function CalcolaPuntoOffset(const Precedente, Corrente, Successivo: TPoint2D; Distanza: Double): TPoint2D; inline;
var
  DX1, DY1, DX2, DY2, Len1, Len2, NX1, NY1, NX2, NY2, BisX, BisY, LenBis: Double;
begin
  Result := Corrente;
  DX1 := Corrente.X - Precedente.X; DY1 := Corrente.Y - Precedente.Y; Len1 := Sqrt(DX1*DX1 + DY1*DY1);
  DX2 := Successivo.X - Corrente.X; DY2 := Successivo.Y - Corrente.Y; Len2 := Sqrt(DX2*DX2 + DY2*DY2);
  if (Len1 < 0.00001) or (Len2 < 0.00001) then
  begin
    if Len1 > 0.00001 then begin
      Result.X := Corrente.X + (-DY1 / Len1) * Distanza;
      Result.Y := Corrente.Y + (DX1 / Len1) * Distanza;
    end;
    Exit;
  end;
  NX1 := -DY1 / Len1; NY1 := DX1 / Len1;
  NX2 := -DY2 / Len2; NY2 := DX2 / Len2;
  BisX := NX1 + NX2; BisY := NY1 + NY2; LenBis := Sqrt(BisX*BisX + BisY*BisY);
  if LenBis > 0.00001 then begin
    Result.X := Corrente.X + (BisX / LenBis) * Distanza;
    Result.Y := Corrente.Y + (BisY / LenBis) * Distanza;
  end else begin
    Result.X := Corrente.X + NX1 * Distanza;
    Result.Y := Corrente.Y + NY1 * Distanza;
  end;
end;

function GetNextSvgNumber(const S: string; var Index: Integer): Double;
var
  Start: Integer;
  Tmp: string;
  Fs: TFormatSettings;
begin
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  while (Index <= Length(S)) and (S[Index] in [' ', ',', #9, #10, #13]) do Inc(Index);
  if Index > Length(S) then Exit(0);
  Start := Index;
  if S[Index] = '-' then Inc(Index);
  while (Index <= Length(S)) and (S[Index] in ['0'..'9', '.', 'e', 'E', '-']) do Inc(Index);
  Tmp := Copy(S, Start, Index - Start);
  Result := StrToFloatDef(Tmp, 0.0, Fs);
end;

function GetMergedAttribute(const Node: TDOMNode; const Name: string): string;
var
  AttrNode: TDOMNode;
  StyleStr: string;
  P, EndP: Integer;
  SearchKey: string;
begin
  Result := '';
  if Assigned(Node) and Assigned(Node.Attributes) then
  begin
    AttrNode := Node.Attributes.GetNamedItem(Name);
    if Assigned(AttrNode) then
      Result := AttrNode.NodeValue;
  end;

  if Result = '' then
  begin
    if Assigned(Node) and Assigned(Node.Attributes) then
    begin
      AttrNode := Node.Attributes.GetNamedItem('style');
      if Assigned(AttrNode) then
      begin
        StyleStr := AttrNode.NodeValue;
        SearchKey := Name + ':';
        P := Pos(SearchKey, StyleStr);
        if P > 0 then
        begin
          Inc(P, Length(SearchKey));
          while (P <= Length(StyleStr)) and (StyleStr[P] = ' ') do Inc(P);
          EndP := P;
          while (EndP <= Length(StyleStr)) and (StyleStr[EndP] <> ';') do Inc(EndP);
          Result := Trim(Copy(StyleStr, P, EndP - P));
        end;
      end;
    end;
  end;
  Result := Trim(Result);
end;

procedure ParseStrokeWidth(const Node: TDOMNode; DefaultVal, Scala: Double; FS: TFormatSettings; out ResultVal: Double);
var
  S: string;
  Val: Double;
begin
  ResultVal := DefaultVal;
  S := GetMergedAttribute(Node, 'stroke-width');
  if S <> '' then
  begin
    while (S <> '') and not (S[Length(S)] in ['0'..'9', '.']) do
      Delete(S, Length(S), 1);
    Val := StrToFloatDef(S, -1.0, FS);
    if Val >= 0.0 then
      ResultVal := Val * Scala;
  end;
end;

procedure ParsePointsString(const PStr: string; var Contour: TContour; Scala: Double);
var
  Idx: Integer;
  Pt: TPoint2D;
begin
  SetLength(Contour, 0);
  Idx := 1;
  while Idx <= Length(PStr) do
  begin
    while (Idx <= Length(PStr)) and (PStr[Idx] in [' ', ',', #9, #10, #13]) do Inc(Idx);
    if Idx > Length(PStr) then Break;
    Pt.X := GetNextSvgNumber(PStr, Idx) * Scala;
    Pt.Y := -GetNextSvgNumber(PStr, Idx) * Scala;
    SetLength(Contour, Length(Contour) + 1);
    Contour[High(Contour)] := Pt;
  end;
end;

procedure InterpolateBezierCubic(const P1, P2, P3, P4: TPoint2D; var Contour: TContour);
var
  I: Integer;
  T, Omn, Omn2, Omn3, T2, T3: Double;
  Steps: Integer;
  Pt: TPoint2D;
begin
  Steps := 16;
  for I := 1 to Steps do
  begin
    T := I / Steps;
    Omn := 1.0 - T; Omn2 := Omn * Omn; Omn3 := Omn2 * Omn;
    T2 := T * T; T3 := T2 * T;
    Pt.X := Omn3*P1.X + 3*Omn2*T*P2.X + 3*Omn*T2*P3.X + T3*P4.X;
    Pt.Y := Omn3*P1.Y + 3*Omn2*T*P2.Y + 3*Omn*T2*P3.Y + T3*P4.Y;
    SetLength(Contour, Length(Contour) + 1);
    Contour[High(Contour)] := Pt;
  end;
end;

function ParsePathStringAndStore(const DStr: string; ContourList: TObjectList; StrokeW: Double; const FillVal: string; Scala: Double): Boolean;
var
  Idx: Integer;
  Cmd, LastCmd: Char;
  CurrPt, StartPt, Ctrl1, Ctrl2, NextPt: TPoint2D;
  LocalContour: TContour;
  CurrentContourObj: TStoredContour;

  procedure FlushLocalContour(IsClosed: Boolean);
  begin
    if Length(LocalContour) > 0 then
    begin
      if CurrentContourObj = nil then
      begin
        CurrentContourObj := TStoredContour.Create(LocalContour, IsClosed, StrokeW, FillVal);
        ContourList.Add(CurrentContourObj);
      end
      else
      begin
        CurrentContourObj.AddHole(LocalContour, IsClosed);
      end;
      SetLength(LocalContour, 0);
    end;
  end;

begin
  Result := False;
  SetLength(LocalContour, 0);
  Idx := 1;
  Cmd := ' '; LastCmd := ' ';
  CurrPt.X := 0; CurrPt.Y := 0; StartPt.X := 0; StartPt.Y := 0;
  CurrentContourObj := nil;

  while Idx <= Length(DStr) do
  begin
    while (Idx <= Length(DStr)) and (DStr[Idx] in [' ', ',', #9, #10, #13]) do Inc(Idx);
    if Idx > Length(DStr) then Break;
    if DStr[Idx] in ['M','m','L','l','H','h','V','v','C','c','Z','z'] then
    begin
      Cmd := DStr[Idx];
      Inc(Idx);
    end else if LastCmd <> ' ' then
    begin
      if LastCmd = 'M' then Cmd := 'L'
      else if LastCmd = 'm' then Cmd := 'l'
      else Cmd := LastCmd;
    end;
    case Cmd of
      'M', 'm': begin
        if Length(LocalContour) > 0 then FlushLocalContour(False);
        NextPt.X := GetNextSvgNumber(DStr, Idx); NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'm' then begin NextPt.X := NextPt.X + (CurrPt.X / Scala); NextPt.Y := NextPt.Y + (CurrPt.Y / Scala); end;
        NextPt.X := NextPt.X * Scala; NextPt.Y := NextPt.Y * Scala;
        SetLength(LocalContour, Length(LocalContour) + 1); LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt; StartPt := NextPt;
      end;
      'L', 'l': begin
        NextPt.X := GetNextSvgNumber(DStr, Idx); NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'l' then begin NextPt.X := NextPt.X + (CurrPt.X / Scala); NextPt.Y := NextPt.Y + (CurrPt.Y / Scala); end;
        NextPt.X := NextPt.X * Scala; NextPt.Y := NextPt.Y * Scala;
        SetLength(LocalContour, Length(LocalContour) + 1); LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt;
      end;
      'H', 'h': begin
        NextPt.X := GetNextSvgNumber(DStr, Idx);
        if Cmd = 'h' then NextPt.X := NextPt.X + (CurrPt.X / Scala);
        NextPt.X := NextPt.X * Scala; NextPt.Y := CurrPt.Y;
        SetLength(LocalContour, Length(LocalContour) + 1); LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt;
      end;
      'V', 'v': begin
        NextPt.X := CurrPt.X; NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'v' then NextPt.Y := NextPt.Y + (CurrPt.Y / Scala);
        NextPt.Y := NextPt.Y * Scala;
        SetLength(LocalContour, Length(LocalContour) + 1); LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt;
      end;
      'C', 'c': begin
        Ctrl1.X := GetNextSvgNumber(DStr, Idx); Ctrl1.Y := -GetNextSvgNumber(DStr, Idx);
        Ctrl2.X := GetNextSvgNumber(DStr, Idx); Ctrl2.Y := -GetNextSvgNumber(DStr, Idx);
        NextPt.X := GetNextSvgNumber(DStr, Idx); NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'c' then begin
          Ctrl1.X := Ctrl1.X + (CurrPt.X / Scala); Ctrl1.Y := Ctrl1.Y + (CurrPt.Y / Scala);
          Ctrl2.X := Ctrl2.X + (CurrPt.X / Scala); Ctrl2.Y := Ctrl2.Y + (CurrPt.Y / Scala);
          NextPt.X := NextPt.X + (CurrPt.X / Scala); NextPt.Y := NextPt.Y + (CurrPt.Y / Scala);
        end;
        Ctrl1.X := Ctrl1.X * Scala; Ctrl1.Y := Ctrl1.Y * Scala;
        Ctrl2.X := Ctrl2.X * Scala; Ctrl2.Y := Ctrl2.Y * Scala;
        NextPt.X := NextPt.X * Scala; NextPt.Y := NextPt.Y * Scala;
        InterpolateBezierCubic(CurrPt, Ctrl1, Ctrl2, NextPt, LocalContour);
        CurrPt := NextPt;
      end;
      'Z', 'z': begin
        if Length(LocalContour) > 0 then begin SetLength(LocalContour, Length(LocalContour) + 1); LocalContour[High(LocalContour)] := StartPt; end;
        CurrPt := StartPt; FlushLocalContour(True);
      end;
    end;
    LastCmd := Cmd;
  end;

  if Length(LocalContour) > 0 then FlushLocalContour(False);
  Result := CurrentContourObj <> nil;
end;

function ExtractSVGViewBox(const SVGString: string): TViewBoxArray;
var StringStream: TStringStream; XMLDoc: TXMLDocument; RootNode: TDOMNode; ViewBoxStr: string; StringList: TStringList; i: Integer;
begin
  for i := 0 to 3 do Result[i] := 0.0;
  if SVGString = '' then Exit;
  StringStream := TStringStream.Create(SVGString, TEncoding.UTF8); StringList := TStringList.Create;
  try
    try
      ReadXMLFile(XMLDoc, StringStream);
      try
        RootNode := XMLDoc.DocumentElement;
        if (RootNode <> nil) and (SameText(RootNode.NodeName, 'svg')) then begin
          if RootNode.Attributes.GetNamedItem('viewBox') <> nil then begin
            ViewBoxStr := RootNode.Attributes.GetNamedItem('viewBox').NodeValue;
            ViewBoxStr := StringReplace(ViewBoxStr, ',', ' ', [rfReplaceAll]);
            StringList.Delimiter := ' '; StringList.StrictDelimiter := True; StringList.DelimitedText := ViewBoxStr;
            if StringList.Count >= 4 then for i := 0 to 3 do Result[i] := StrToFloatDef(StringList[i], 0.0);
          end;
        end;
      finally XMLDoc.Free; end;
    except end;
  finally StringList.Free; StringStream.Free; end;
end;

function ConvertSVGValue(const ValueStr: string; FS: TFormatSettings; const ViewBox: TViewBoxArray; Axis: string): Double;
var CleanStr: string; PercentVal: Double; BaseDimension: Double;
begin
  Result := 0.0; CleanStr := Trim(ValueStr); if CleanStr = '' then Exit;
  FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
  if RightStr(CleanStr, 1) = '%' then begin
    CleanStr := LeftStr(CleanStr, Length(CleanStr) - 1); PercentVal := StrToFloatDef(CleanStr, 0.0, FS);
    if Axis = 'X' then BaseDimension := ViewBox[2] else BaseDimension := ViewBox[3];
    Result := (PercentVal / 100.0) * BaseDimension;
  end else Result := StrToFloatDef(CleanStr, 0.0, FS);
end;

function ConvertSvgToVectorGCodeClipper(
  const FileSvg: TMemoryStream;
  FeedRateXY: Integer;
  FeedRateZ: Integer;
  ZSicura: Double;
  ZStart: Double;
  ZDepth: Double;
  ZStep: Double;
  DiametroFresaMM: Double;
  tipo_comp: Byte;         // Compensation: 0 = Internal, 1 = External, 2 = None
  NumTabs: Integer;
  SpessoreTabMM: Double;
  FattoreScala: Double;
  HelicalRamp: Boolean;
  ClimbMilling: Boolean;
  FinishAllowance: Double
): string;
var
  Doc: TXMLDocument;
  LineeGCode: TStringList;
  ContourList: TObjectList;
  RaggioFresa, ZFinale, StepCorrente, ZQuotaTab: Double;
  Fs: TFormatSettings;
  MinX, MinY: Double;
  viewbox: TViewBoxArray;

  // Variabili di supporto per il calcolo della compensazione geometrica classica
  IsOutside: Boolean;
  RaggioOffsetRough, RaggioOffsetFinish: Double;
  IsHoleOutside: Boolean;

  procedure ReverseContour(var C: TContour);
  var
    I, J: Integer;
    Tmp: TPoint2D;
  begin
    I := 0;
    J := High(C);
    while I < J do
    begin
      Tmp := C[I];
      C[I] := C[J];
      C[J] := Tmp;
      Inc(I);
      Dec(J);
    end;
  end;

  procedure WriteToolpath(const Contorno: TContour; IsClosed: Boolean; ZStartPass, ZEndPass: Double; DoRamp: Boolean; IsFinishPass: Boolean);
  var
    I, IntervalloTab, ProssimoPuntoTab: Integer;
    TotalLength, AccumulatedLength, DX, DY, Ratio, PointZ: Double;
  begin
    if Length(Contorno) < 2 then Exit;

    LineeGCode.Add(Format('G0 X%.3f Y%.3f', [Contorno[0].X, Contorno[0].Y]));
    LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
    LineeGCode.Add(Format('G0 Z%.3f ; Sfioramento', [ZStartPass + 0.5]));

    IntervalloTab := 0;
    if (NumTabs > 0) and IsClosed and (not DoRamp) and IsFinishPass and (Length(Contorno) > NumTabs) then
      IntervalloTab := Length(Contorno) div NumTabs;

    if DoRamp and IsClosed then
    begin
      LineeGCode.Add('; --- Entrata Elicoidale ---');
      TotalLength := 0.0;
      for I := 0 to High(Contorno) do
      begin
        if I = High(Contorno) then begin DX := Contorno[0].X - Contorno[I].X; DY := Contorno[0].Y - Contorno[I].Y; end
        else begin DX := Contorno[I+1].X - Contorno[I].X; DY := Contorno[I+1].Y - Contorno[I].Y; end;
        TotalLength := TotalLength + Sqrt(DX*DX + DY*DY);
      end;

      if TotalLength > 0.01 then
      begin
        AccumulatedLength := 0.0;
        for I := 0 to High(Contorno) do
        begin
          if I = High(Contorno) then begin DX := Contorno[0].X - Contorno[I].X; DY := Contorno[0].Y - Contorno[I].Y; end
          else begin DX := Contorno[I+1].X - Contorno[I].X; DY := Contorno[I+1].Y - Contorno[I].Y; end;
          AccumulatedLength := AccumulatedLength + Sqrt(DX*DX + DY*DY);
          Ratio := AccumulatedLength / TotalLength;
          PointZ := ZStartPass + Ratio * (ZEndPass - ZStartPass);

          if I = High(Contorno) then
            LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d', [Contorno[0].X, Contorno[0].Y, PointZ, FeedRateXY]))
          else
            LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d', [Contorno[I+1].X, Contorno[I+1].Y, PointZ, FeedRateXY]));
        end;

        for I := 1 to High(Contorno) do
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [Contorno[I].X, Contorno[I].Y, FeedRateXY]));
        LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [Contorno[0].X, Contorno[0].Y, FeedRateXY]));
      end;
    end
    else
    begin
      LineeGCode.Add(Format('G1 Z%.3f F%d ; Discesa', [ZEndPass, FeedRateZ]));
      ProssimoPuntoTab := IntervalloTab;

      for I := 1 to High(Contorno) do
      begin
        if (IntervalloTab > 0) and (I = ProssimoPuntoTab) and (I < High(Contorno)) then
        begin
          LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d ; TAB', [Contorno[I].X, Contorno[I].Y, ZQuotaTab, FeedRateZ]));
          LineeGCode.Add(Format('G1 Z%.3f F%d', [ZEndPass, FeedRateZ]));
          Inc(ProssimoPuntoTab, IntervalloTab);
        end
        else
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [Contorno[I].X, Contorno[I].Y, FeedRateXY]));
      end;

      if IsClosed then
      begin
        LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [Contorno[0].X, Contorno[0].Y, FeedRateXY]));
      end;
    end;
    LineeGCode.Add(Format('G0 Z%.3f ; Svincolo', [ZSicura]));
  end;

  procedure ProcessAndWriteContourClassic(const Contorno: TContour; IsClosed: Boolean; CurrentRaggioOffset: Double; IsOutsideCut: Boolean; ZStartPass, ZEndPass: Double; DoRamp: Boolean; IsFinishPass: Boolean);
  var
    ContornoOffset, ContornoPulito: TContour;
    I, CleanCount: Integer;
    P1, P2, P3, PtPrec, PFirst, PLast: TPoint2D;
    SegnoOffset: Double;
    IsCW, DesiredCW: Boolean;
  begin
    if Length(Contorno) < 2 then Exit;

    SetLength(ContornoPulito, Length(Contorno));
    CleanCount := 0;
    for I := 0 to High(Contorno) do
    begin
      if CleanCount > 0 then
      begin
        PtPrec := ContornoPulito[CleanCount - 1];
        if (Abs(Contorno[I].X - PtPrec.X) < 0.00001) and (Abs(Contorno[I].Y - PtPrec.Y) < 0.00001) then
          Continue;
      end;
      ContornoPulito[CleanCount] := Contorno[I];
      Inc(CleanCount);
    end;
    SetLength(ContornoPulito, CleanCount);

    if IsClosed and (CleanCount >= 2) then
    begin
      PFirst := ContornoPulito[0];
      PLast := ContornoPulito[CleanCount - 1];
      if (Abs(PFirst.X - PLast.X) < 0.00001) and (Abs(PFirst.Y - PLast.Y) < 0.00001) then
      begin
        Dec(CleanCount);
        ContornoPulito := Copy(ContornoPulito, 0, CleanCount);
      end;
    end;

    if CleanCount < 2 then Exit;

    if IsClosed then
    begin
      if CleanCount >= 3 then
      begin
        IsCW := IsPolygonClockwise(ContornoPulito);

        if IsOutsideCut then
          DesiredCW := not ClimbMilling
        else
          DesiredCW := ClimbMilling;

        if IsCW <> DesiredCW then
        begin
          ReverseContour(ContornoPulito);
          IsCW := DesiredCW;
        end;

        if IsOutsideCut then
          SegnoOffset := IfThen(IsCW, CurrentRaggioOffset, -CurrentRaggioOffset)
        else
          SegnoOffset := IfThen(IsCW, -CurrentRaggioOffset, CurrentRaggioOffset);
      end else
        SegnoOffset := CurrentRaggioOffset;
    end
    else
      SegnoOffset := 0.0;

    SetLength(ContornoOffset, CleanCount);
    for I := 0 to High(ContornoPulito) do
    begin
      if I = 0 then P1 := ContornoPulito[High(ContornoPulito)] else P1 := ContornoPulito[I - 1];
      P2 := ContornoPulito[I];
      if I = High(ContornoPulito) then P3 := ContornoPulito[0] else P3 := ContornoPulito[I + 1];
      if IsClosed then
        ContornoOffset[I] := CalcolaPuntoOffset(P1, P2, P3, SegnoOffset)
      else
        ContornoOffset[I] := P2;
    end;

    for I := 0 to High(ContornoOffset) do
    begin
      ContornoOffset[I].X := ContornoOffset[I].X - MinX;
      ContornoOffset[I].Y := ContornoOffset[I].Y - MinY;
    end;

    WriteToolpath(ContornoOffset, IsClosed, ZStartPass, ZEndPass, DoRamp, IsFinishPass);
  end;

  procedure ProcessPocketConcentricClipper(StoredObj: TStoredContour);
  var
    co: TClipperOffset;
    BasePaths: TPaths;
    Solution: TPaths;
    AllPasses: array of TPaths;
    Path: TPath;
    I, J, PIdx: Integer;
    QuotaZ, ZPassStart, ZPassEnd: Double;
    PassataFinita: Boolean;
    CurrentOffset, Stepover: Double;
    ContourTmp: TContour;
    IsCW, DesiredCW: Boolean;
  begin
    SetLength(BasePaths, 1 + Length(StoredObj.Holes));

    SetLength(Path, Length(StoredObj.Points));
    for I := 0 to High(StoredObj.Points) do
      Path[I] := FloatPointToIntPoint(MakePoint2D(StoredObj.Points[I].X - MinX, StoredObj.Points[I].Y - MinY));
    if not Orientation(Path) then ReversePath(Path);
    BasePaths[0] := Path;

    for I := 0 to High(StoredObj.Holes) do
    begin
      SetLength(Path, Length(StoredObj.Holes[I]));
      for J := 0 to High(StoredObj.Holes[I]) do
        Path[J] := FloatPointToIntPoint(MakePoint2D(StoredObj.Holes[I][J].X - MinX, StoredObj.Holes[I][J].Y - MinY));
      if Orientation(Path) then ReversePath(Path);
      BasePaths[I+1] := Path;
    end;

    Stepover := 0.8 * DiametroFresaMM;
    if Stepover < 0.1 then Stepover := 0.1;

    CurrentOffset := RaggioFresa + FinishAllowance;
    SetLength(AllPasses, 0);
    while True do
    begin
      co := TClipperOffset.Create;
      try
        co.AddPaths(BasePaths, jtRound, etClosedPolygon);
        co.Execute(Solution, -CurrentOffset * ClipScale);
      finally
        co.Free;
      end;

      if Length(Solution) = 0 then Break;

      SetLength(AllPasses, Length(AllPasses) + 1);
      AllPasses[High(AllPasses)] := Solution;
      CurrentOffset := CurrentOffset + Stepover;
    end;

    QuotaZ := ZStart;
    PassataFinita := False;

    repeat
      ZPassStart := QuotaZ;
      QuotaZ := QuotaZ - StepCorrente;
      if QuotaZ <= ZFinale then begin
        QuotaZ := ZFinale;
        PassataFinita := True;
      end;
      ZPassEnd := QuotaZ;

      LineeGCode.Add(Format('; --- Z Layer Sbozzatura Concentrica %.3f ---', [ZPassEnd]));

      for PIdx := High(AllPasses) downto 0 do
      begin
        Solution := AllPasses[PIdx];
        for I := 0 to High(Solution) do
        begin
          IsCW := Orientation(Solution[I]);
          if IsCW then DesiredCW := ClimbMilling
          else DesiredCW := not ClimbMilling;

          if IsCW <> DesiredCW then ReversePath(Solution[I]);

          SetLength(ContourTmp, Length(Solution[I]));
          for J := 0 to High(Solution[I]) do
            ContourTmp[J] := IntPointToFloatPoint(Solution[I][J]);

          WriteToolpath(ContourTmp, True, ZPassStart, ZPassEnd, HelicalRamp and (PIdx = High(AllPasses)), False);
        end;
      end;

      if FinishAllowance > 0.0001 then
      begin
        LineeGCode.Add(Format('; --- Z Layer Finitura Concentrica %.3f ---', [ZPassEnd]));
        co := TClipperOffset.Create;
        try
          co.AddPaths(BasePaths, jtRound, etClosedPolygon);
          co.Execute(Solution, -RaggioFresa * ClipScale);
        finally
          co.Free;
        end;

        for I := 0 to High(Solution) do
        begin
          IsCW := Orientation(Solution[I]);
          if IsCW then DesiredCW := ClimbMilling else DesiredCW := not ClimbMilling;
          if IsCW <> DesiredCW then ReversePath(Solution[I]);

          SetLength(ContourTmp, Length(Solution[I]));
          for J := 0 to High(Solution[I]) do
            ContourTmp[J] := IntPointToFloatPoint(Solution[I][J]);

          WriteToolpath(ContourTmp, True, ZPassStart, ZPassEnd, False, True);
        end;
      end;

    until PassataFinita;
  end;

var
  ListaNodi: TDOMNodeList;
  NodoAttr: TDOMNode;
  ContornoCorrente, ContourTmp: TContour;
  I, J, HIdx: Integer;
  CX, CY, RX, RY, X, Y, W, H, X1, Y1, X2, Y2, Angolo: Double;
  Pt: TPoint2D;
  Sc: Double;
  Stored: TStoredContour;
  TargetWidth, ToolDiam, Spacing, OffsetAmount: Double;
  StrokeW: Double;
  NPasses, KPass, JVertex: Integer;
  QuotaZ, ZPassStart, ZPassEnd: Double;
  PassataFinita: Boolean;
  StrokeContour: TContour;
  P1Extend, P2Extend, P3Extend: TPoint2D;

begin
  Result := '';
  SetLength(StrokeContour, 0);
  FinishAllowance := Max(0.0, FinishAllowance);
  Sc := FattoreScala;
  if Sc <= 0.0 then Sc := 1.0;

  RaggioFresa := DiametroFresaMM / 2.0;
  // Configurazione logica e valori di compensazione basati su tipo_comp
  IsOutside := (tipo_comp <> 0); // Esterno (1) e Nessuno (2) valutano a True per determinare la direzione di taglio concorde/discorde
  if tipo_comp = 2 then
  begin
    RaggioOffsetRough := 0.0;
    RaggioOffsetFinish := 0.0;
  end
  else
  begin
    RaggioOffsetRough := RaggioFresa + FinishAllowance;
    RaggioOffsetFinish := RaggioFresa;
  end;

  ZFinale := ZStart - Abs(ZDepth);
  StepCorrente := Abs(ZStep);
  if StepCorrente < 0.001 then StepCorrente := Abs(ZDepth);

  ZQuotaTab := ZFinale + Abs(SpessoreTabMM);
  if ZQuotaTab > ZStart then ZQuotaTab := ZStart;

  LineeGCode := TStringList.Create;
  ContourList := TObjectList.Create(True);
  Fs := DefaultFormatSettings;
  Fs.DecimalSeparator := '.';
  MinX := Infinity;
  MinY := Infinity;

  try
    FileSvg.Position:=0;
    ReadXMLFile(Doc, FileSvg);
    try
      ListaNodi := Doc.GetElementsByTagName('svg');
      viewbox[0]:=0; viewbox[1]:=0; viewbox[2]:=0; viewbox[3]:=0;
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('viewBox');
        if (NodoAttr <> nil) and (NodoAttr.NodeValue <> '') then
          viewbox := ExtractSVGViewBox('<svg viewBox="' + NodoAttr.NodeValue + '" ></svg>');
      end;

      ListaNodi := Doc.GetElementsByTagName('path');
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('d');
        if Assigned(NodoAttr) then
        begin
          ParseStrokeWidth(ListaNodi.Item[I], DiametroFresaMM, Sc, Fs, StrokeW);
          ParsePathStringAndStore(NodoAttr.NodeValue, ContourList, StrokeW, GetMergedAttribute(ListaNodi.Item[I], 'fill'), Sc);
        end;
      end;

      ListaNodi := Doc.GetElementsByTagName('circle');
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('cx'); if Assigned(NodoAttr) then CX := ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'X') * Sc else CX := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('cy'); if Assigned(NodoAttr) then CY := -ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'Y') * Sc else CY := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('r'); if Assigned(NodoAttr) then RX := StrToFloatDef(NodoAttr.NodeValue, 0.0, Fs) * Sc else RX := 0;
        SetLength(ContornoCorrente, 0);
        for J := 0 to 72 do
        begin
          Angolo := DegToRad(J * 5);
          Pt.X := CX + RX * Cos(Angolo);
          Pt.Y := CY + RX * Sin(Angolo);
          SetLength(ContornoCorrente, Length(ContornoCorrente) + 1);
          ContornoCorrente[High(ContornoCorrente)] := Pt;
        end;
        ParseStrokeWidth(ListaNodi.Item[I], DiametroFresaMM, Sc, Fs, StrokeW);
        ContourList.Add(TStoredContour.Create(ContornoCorrente, True, StrokeW, GetMergedAttribute(ListaNodi.Item[I], 'fill')));
      end;

      ListaNodi := Doc.GetElementsByTagName('ellipse');
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('cx'); if Assigned(NodoAttr) then CX := ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'X') * Sc else CX := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('cy'); if Assigned(NodoAttr) then CY := -ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'Y') * Sc else CY := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('rx'); if Assigned(NodoAttr) then RX := StrToFloatDef(NodoAttr.NodeValue, 0.0, Fs) * Sc else RX := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('ry'); if Assigned(NodoAttr) then RY := StrToFloatDef(NodoAttr.NodeValue, 0.0, Fs) * Sc else RY := 0;
        SetLength(ContornoCorrente, 0);
        for J := 0 to 72 do
        begin
          Angolo := DegToRad(J * 5);
          Pt.X := CX + RX * Cos(Angolo);
          Pt.Y := CY + RY * Sin(Angolo);
          SetLength(ContornoCorrente, Length(ContornoCorrente) + 1);
          ContornoCorrente[High(ContornoCorrente)] := Pt;
        end;
        ParseStrokeWidth(ListaNodi.Item[I], DiametroFresaMM, Sc, Fs, StrokeW);
        ContourList.Add(TStoredContour.Create(ContornoCorrente, True, StrokeW, GetMergedAttribute(ListaNodi.Item[I], 'fill')));
      end;

      ListaNodi := Doc.GetElementsByTagName('rect');
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('x'); if Assigned(NodoAttr) then X := ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'X') * Sc else X := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('y'); if Assigned(NodoAttr) then Y := -ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'Y') * Sc else Y := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('width'); if Assigned(NodoAttr) then W := ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'X') * Sc else W := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('height'); if Assigned(NodoAttr) then H := ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'Y') * Sc else H := 0;
        SetLength(ContornoCorrente, 4);
        ContornoCorrente[0].X := X; ContornoCorrente[0].Y := Y;
        ContornoCorrente[1].X := X + W; ContornoCorrente[1].Y := Y;
        ContornoCorrente[2].X := X + W; ContornoCorrente[2].Y := Y - H;
        ContornoCorrente[3].X := X; ContornoCorrente[3].Y := Y - H;
        ParseStrokeWidth(ListaNodi.Item[I], DiametroFresaMM, Sc, Fs, StrokeW);
        ContourList.Add(TStoredContour.Create(ContornoCorrente, True, StrokeW, GetMergedAttribute(ListaNodi.Item[I], 'fill')));
      end;

      ListaNodi := Doc.GetElementsByTagName('polygon');
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('points');
        if Assigned(NodoAttr) then
        begin
          ParsePointsString(NodoAttr.NodeValue, ContornoCorrente, Sc);
          if Length(ContornoCorrente) > 0 then
          begin
            ParseStrokeWidth(ListaNodi.Item[I], DiametroFresaMM, Sc, Fs, StrokeW);
            ContourList.Add(TStoredContour.Create(ContornoCorrente, True, StrokeW, GetMergedAttribute(ListaNodi.Item[I], 'fill')));
          end;
        end;
      end;

      ListaNodi := Doc.GetElementsByTagName('polyline');
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('points');
        if Assigned(NodoAttr) then
        begin
          ParsePointsString(NodoAttr.NodeValue, ContornoCorrente, Sc);
          if Length(ContornoCorrente) > 0 then
          begin
            ParseStrokeWidth(ListaNodi.Item[I], DiametroFresaMM, Sc, Fs, StrokeW);
            ContourList.Add(TStoredContour.Create(ContornoCorrente, False, StrokeW, GetMergedAttribute(ListaNodi.Item[I], 'fill')));
          end;
        end;
      end;

      ListaNodi := Doc.GetElementsByTagName('line');
      for I := 0 to ListaNodi.Count - 1 do
      begin
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('x1'); if Assigned(NodoAttr) then X1 := ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'X') * Sc else X1 := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('y1'); if Assigned(NodoAttr) then Y1 := -ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'Y') * Sc else Y1 := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('x2'); if Assigned(NodoAttr) then X2 := ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'X') * Sc else X2 := 0;
        NodoAttr := ListaNodi.Item[I].Attributes.GetNamedItem('y2'); if Assigned(NodoAttr) then Y2 := -ConvertSVGValue(NodoAttr.NodeValue, Fs, viewbox, 'Y') * Sc else Y2 := 0;
        SetLength(ContornoCorrente, 2);
        ContornoCorrente[0].X := X1; ContornoCorrente[0].Y := Y1;
        ContornoCorrente[1].X := X2; ContornoCorrente[1].Y := Y2;
        ParseStrokeWidth(ListaNodi.Item[I], DiametroFresaMM, Sc, Fs, StrokeW);
        ContourList.Add(TStoredContour.Create(ContornoCorrente, False, StrokeW, GetMergedAttribute(ListaNodi.Item[I], 'fill')));
      end;

      for I := 0 to ContourList.Count - 1 do
      begin
        Stored := TStoredContour(ContourList[I]);
        for J := 0 to High(Stored.Points) do
        begin
          if Stored.Points[J].X < MinX then MinX := Stored.Points[J].X;
          if Stored.Points[J].Y < MinY then MinY := Stored.Points[J].Y;
        end;
        for HIdx := 0 to High(Stored.Holes) do
          for J := 0 to High(Stored.Holes[HIdx]) do
          begin
            if Stored.Holes[HIdx][J].X < MinX then MinX := Stored.Holes[HIdx][J].X;
            if Stored.Holes[HIdx][J].Y < MinY then MinY := Stored.Holes[HIdx][J].Y;
          end;
      end;

      LineeGCode.Add('G21 ; Unita metriche in millimetri');
      LineeGCode.Add('G90 ; Coordinate assolute');
      LineeGCode.Add(Format('G0 Z%.3f F2000', [ZSicura]));
      LineeGCode.Add('M03 ; Mandrino attivo');

      if (MinX = Infinity) or (MinY = Infinity) then
      begin
        MinX := 0;
        MinY := 0;
      end;

      for I := 0 to ContourList.Count - 1 do
      begin
        Stored := TStoredContour(ContourList[I]);

        if Stored.IsClosed and (SameText(Stored.FillColor, 'black') or SameText(Stored.FillColor, '#000000')) and (Stored.FillColor <> '') then
        begin
          // --- Elaborazione TASCA con CLIPPER ---
          ProcessPocketConcentricClipper(Stored);
        end
        else
        begin
          // --- Elaborazione GEOMETRICA CLASSICA (Senza Clipper) ---
          TargetWidth := Stored.StrokeWidth;
          ToolDiam := DiametroFresaMM;

          QuotaZ := ZStart;
          PassataFinita := False;

          repeat
            ZPassStart := QuotaZ;
            QuotaZ := QuotaZ - StepCorrente;
            if QuotaZ <= ZFinale then begin
              QuotaZ := ZFinale;
              PassataFinita := True;
            end;
            ZPassEnd := QuotaZ;

            if (TargetWidth > ToolDiam + 0.001) then
            begin
              NPasses := Ceil(TargetWidth / ToolDiam);
              if NPasses < 2 then NPasses := 2;
              Spacing := (TargetWidth - ToolDiam) / (NPasses - 1);

              for KPass := 0 to NPasses - 1 do
              begin
                OffsetAmount := -(TargetWidth - ToolDiam) / 2.0 + KPass * Spacing;
                SetLength(StrokeContour, Length(Stored.Points));

                for JVertex := 0 to High(Stored.Points) do
                begin
                  if Stored.IsClosed then
                  begin
                    if JVertex = 0 then P1Extend := Stored.Points[High(Stored.Points)] else P1Extend := Stored.Points[JVertex - 1];
                    P2Extend := Stored.Points[JVertex];
                    if JVertex = High(Stored.Points) then P3Extend := Stored.Points[0] else P3Extend := Stored.Points[JVertex + 1];
                    StrokeContour[JVertex] := CalcolaPuntoOffset(P1Extend, P2Extend, P3Extend, IfThen(IsPolygonClockwise(Stored.Points), 1.0, -1.0) * OffsetAmount);
                  end
                  else
                  begin
                    if JVertex = 0 then
                    begin
                      P2Extend := Stored.Points[0];
                      P3Extend := Stored.Points[1];
                      P1Extend.X := P2Extend.X - (P3Extend.X - P2Extend.X);
                      P1Extend.Y := P2Extend.Y - (P3Extend.Y - P2Extend.Y);
                    end
                    else if JVertex = High(Stored.Points) then
                    begin
                      P1Extend := Stored.Points[JVertex - 1];
                      P2Extend := Stored.Points[JVertex];
                      P3Extend.X := P2Extend.X + (P2Extend.X - P1Extend.X);
                      P3Extend.Y := P2Extend.Y + (P2Extend.Y - P1Extend.Y);
                    end
                    else
                    begin
                      P1Extend := Stored.Points[JVertex - 1];
                      P2Extend := Stored.Points[JVertex];
                      P3Extend := Stored.Points[JVertex + 1];
                    end;
                    StrokeContour[JVertex] := CalcolaPuntoOffset(P1Extend, P2Extend, P3Extend, OffsetAmount);
                  end;
                end;
                ProcessAndWriteContourClassic(StrokeContour, Stored.IsClosed, 0.0, IsOutside, ZPassStart, ZPassEnd, HelicalRamp, True);
              end;
            end
            else
            begin
              if (tipo_comp <> 2) and (FinishAllowance > 0.0001) then
              begin
                ProcessAndWriteContourClassic(Stored.Points, Stored.IsClosed, RaggioOffsetRough, IsOutside, ZPassStart, ZPassEnd, HelicalRamp, False);
                ProcessAndWriteContourClassic(Stored.Points, Stored.IsClosed, RaggioOffsetFinish, IsOutside, ZPassStart, ZPassEnd, False, True);
              end
              else
              begin
                ProcessAndWriteContourClassic(Stored.Points, Stored.IsClosed, RaggioOffsetFinish, IsOutside, ZPassStart, ZPassEnd, HelicalRamp, True);
              end;

              for HIdx := 0 to High(Stored.Holes) do
              begin
                IsHoleOutside := not IsOutside;
                if (tipo_comp <> 2) and (FinishAllowance > 0.0001) then
                begin
                  ProcessAndWriteContourClassic(Stored.Holes[HIdx], True, RaggioOffsetRough, IsHoleOutside, ZPassStart, ZPassEnd, HelicalRamp, False);
                  ProcessAndWriteContourClassic(Stored.Holes[HIdx], True, RaggioOffsetFinish, IsHoleOutside, ZPassStart, ZPassEnd, False, True);
                end
                else
                begin
                  ProcessAndWriteContourClassic(Stored.Holes[HIdx], True, RaggioOffsetFinish, IsHoleOutside, ZPassStart, ZPassEnd, HelicalRamp, True);
                end;
              end;
            end;
          until PassataFinita;
        end;
      end;
    finally
      Doc.Free;
    end;
    LineeGCode.Add('M05 ; Arresto Mandrino');
    LineeGCode.Add('G0 X0 Y0 ; Ritorno Home');
    Result := LineeGCode.Text;
  except
    on E: Exception do
      Result := '; Errore durante la conversione: ' + E.Message;
  end;
  ContourList.Free;
  LineeGCode.Free;
end;

end.
