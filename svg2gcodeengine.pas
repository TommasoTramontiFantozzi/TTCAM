unit Svg2GcodeEngine;

{$mode objfpc}{$H+}
{$inline on}

interface

uses
  SysUtils, Classes, Math, DOM, XMLRead, Contnrs;

type
  TPoint2D = record
    X, Y: Double;
  end;
  TContour = array of TPoint2D;
  TContourArray = array of TContour;
  TDoubleArray = array of Double;
  TCutSegment = record P1, P2: TPoint2D; end;
  TCutArray = array of TCutSegment;

type
  TViewBoxArray = array[0..3] of Single;

  // Support class storing contour details before generating G-code
  TStoredContour = class
  public
    Points: TContour;          // Main outline or primary contour
    Holes: TContourArray;      // Internal islands/holes (sub-paths within the same object)
    IsClosed: Boolean;
    StrokeWidth: Double;       // Target stroke width in mm after scaling
    FillColor: string;         // Fill attribute direct or from style, empty if none
    constructor Create(const APoints: TContour; AIsClosed: Boolean; AStrokeWidth: Double; const AFillColor: string);
    procedure AddHole(const AHole: TContour; AHoleClosed: Boolean);
  end;

function ConvertSvgToVectorGCode(
  const FileSvg: TMemoryStream;
  FeedRateXY: Integer;     // X-Y feed rate in G1 (mm/min)
  FeedRateZ: Integer;      // Z plunge feed rate in vertical/ramps (mm/min)
  ZSicura: Double;         // Safe retract Z coordinate
  ZStart: Double;          // Starting Z coordinate (top of material)
  ZDepth: Double;          // Cutting total depth (will be subtracted from ZStart)
  ZStep: Double;           // Maximum depth step per pass
  DiametroFresaMM: Double; // Tool diameter (mm)
  tipo_comp: Byte;         // Compensation: 0 = Internal, 1 = External, 2 = None
  NumTabs: Integer;        // Number of tabs for closed profiles (0 to disable)
  SpessoreTabMM: Double;   // Height of the tab from bottom of cut
  FattoreScala: Double;    // Scale multiplier (1.0 = real scale)
  HelicalRamp: Boolean;    // Helicoidal (helical) continuous ramping/approximation
  ClimbMilling: Boolean;   // True = Climb (Concorde), False = Conventional (Discorde)
  FinishAllowance: Double;  // Material to leave for a final finish pass (Sovrametallo)
  Fill:boolean=true
): string;

implementation

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

function CalcolaAreaPoligono(const Contour: TContour): Double;
var
  I, J: Integer;
  Area: Double;
begin
  Area := 0;
  if Length(Contour) < 3 then Exit(0);
  J := High(Contour);
  for I := 0 to High(Contour) do
  begin
    Area := Area + (Contour[J].X * Contour[I].Y) - (Contour[I].X * Contour[J].Y);
    J := I;
  end;
  Result := Abs(Area) / 2.0;
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

function IsPointInPolygon(const Pt: TPoint2D; const Polygon: TContour): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if Length(Polygon) < 3 then Exit;
  J := High(Polygon);
  for I := 0 to High(Polygon) do
  begin
    if ((Polygon[I].Y > Pt.Y) <> (Polygon[J].Y > Pt.Y)) and
       (Pt.X < (Polygon[J].X - Polygon[I].X) * (Pt.Y - Polygon[I].Y) / (Polygon[J].Y - Polygon[I].Y) + Polygon[I].X) then
    begin
      Result := not Result;
    end;
    J := I;
  end;
end;

procedure SortDoubleArray(var A: TDoubleArray);
var
  I, J: Integer;
  Temp: Double;
begin
  if Length(A) < 2 then Exit;
  for I := 0 to High(A) - 1 do
    for J := I + 1 to High(A) do
      if A[I] > A[J] then
      begin
        Temp := A[I];
        A[I] := A[J];
        A[J] := Temp;
      end;
end;

procedure AddIntersections(Y: Double; const Contour: TContour; var XInts: TDoubleArray);
var
  I, J: Integer;
  X, MinY_Seg, MaxY_Seg: Double;
begin
  if Length(Contour) < 2 then Exit;
  J := High(Contour);
  for I := 0 to High(Contour) do
  begin
    MinY_Seg := Min(Contour[I].Y, Contour[J].Y);
    MaxY_Seg := Max(Contour[I].Y, Contour[J].Y);

    if (Y > MinY_Seg) and (Y <= MaxY_Seg) then
    begin
      if Abs(Contour[J].Y - Contour[I].Y) > 0.00001 then
      begin
        X := Contour[I].X + (Y - Contour[I].Y) / (Contour[J].Y - Contour[I].Y) * (Contour[J].X - Contour[I].X);
        SetLength(XInts, Length(XInts) + 1);
        XInts[High(XInts)] := X;
      end;
    end;
    J := I;
  end;
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
        if Length(LocalContour) > 0 then
          FlushLocalContour(False);

        NextPt.X := GetNextSvgNumber(DStr, Idx);
        NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'm' then
        begin
          NextPt.X := NextPt.X + (CurrPt.X / Scala);
          NextPt.Y := NextPt.Y + (CurrPt.Y / Scala);
        end;
        NextPt.X := NextPt.X * Scala;
        NextPt.Y := NextPt.Y * Scala;
        SetLength(LocalContour, Length(LocalContour) + 1);
        LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt;
        StartPt := NextPt;
      end;
      'L', 'l': begin
        NextPt.X := GetNextSvgNumber(DStr, Idx);
        NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'l' then
        begin
          NextPt.X := NextPt.X + (CurrPt.X / Scala);
          NextPt.Y := NextPt.Y + (CurrPt.Y / Scala);
        end;
        NextPt.X := NextPt.X * Scala;
        NextPt.Y := NextPt.Y * Scala;
        SetLength(LocalContour, Length(LocalContour) + 1);
        LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt;
      end;
      'H', 'h': begin
        NextPt.X := GetNextSvgNumber(DStr, Idx);
        if Cmd = 'h' then NextPt.X := NextPt.X + (CurrPt.X / Scala);
        NextPt.X := NextPt.X * Scala;
        NextPt.Y := CurrPt.Y;
        SetLength(LocalContour, Length(LocalContour) + 1);
        LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt;
      end;
      'V', 'v': begin
        NextPt.X := CurrPt.X;
        NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'v' then NextPt.Y := NextPt.Y + (CurrPt.Y / Scala);
        NextPt.Y := NextPt.Y * Scala;
        SetLength(LocalContour, Length(LocalContour) + 1);
        LocalContour[High(LocalContour)] := NextPt;
        CurrPt := NextPt;
      end;
      'C', 'c': begin
        Ctrl1.X := GetNextSvgNumber(DStr, Idx); Ctrl1.Y := -GetNextSvgNumber(DStr, Idx);
        Ctrl2.X := GetNextSvgNumber(DStr, Idx); Ctrl2.Y := -GetNextSvgNumber(DStr, Idx);
        NextPt.X := GetNextSvgNumber(DStr, Idx); NextPt.Y := -GetNextSvgNumber(DStr, Idx);
        if Cmd = 'c' then
        begin
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
        if Length(LocalContour) > 0 then
        begin
          SetLength(LocalContour, Length(LocalContour) + 1);
          LocalContour[High(LocalContour)] := StartPt;
        end;
        CurrPt := StartPt;
        FlushLocalContour(True);
      end;
    end;
    LastCmd := Cmd;
  end;

  if Length(LocalContour) > 0 then
    FlushLocalContour(False);

  Result := CurrentContourObj <> nil;
end;

function ExtractSVGViewBox(const SVGString: string): TViewBoxArray;
var
  StringStream: TStringStream;
  XMLDoc: TXMLDocument;
  RootNode: TDOMNode;
  ViewBoxStr: string;
  StringList: TStringList;
  i: Integer;
begin
  for i := 0 to 3 do
    Result[i] := 0.0;

  if SVGString = '' then Exit;

  StringStream := TStringStream.Create(SVGString, TEncoding.UTF8);
  StringList := TStringList.Create;
  try
    try
      ReadXMLFile(XMLDoc, StringStream);
      try
        RootNode := XMLDoc.DocumentElement;
        if (RootNode <> nil) and (SameText(RootNode.NodeName, 'svg')) then
        begin
          if RootNode.Attributes.GetNamedItem('viewBox') <> nil then
          begin
            ViewBoxStr := RootNode.Attributes.GetNamedItem('viewBox').NodeValue;
            ViewBoxStr := StringReplace(ViewBoxStr, ',', ' ', [rfReplaceAll]);
            StringList.Delimiter := ' ';
            StringList.StrictDelimiter := True;
            StringList.DelimitedText := ViewBoxStr;
            if StringList.Count >= 4 then
            begin
              for i := 0 to 3 do
                Result[i] := StrToFloatDef(StringList[i], 0.0);
            end;
          end;
        end;
      finally
        XMLDoc.Free;
      end;
    except
    end;
  finally
    StringList.Free;
    StringStream.Free;
  end;
end;

function ConvertSVGValue(const ValueStr: string; FS: TFormatSettings; const ViewBox: TViewBoxArray; Axis: string): Double;
var
  CleanStr: string;
  PercentVal: Double;
  BaseDimension: Double;
begin
  Result := 0.0;
  CleanStr := Trim(ValueStr);
  if CleanStr = '' then Exit;

  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  if RightStr(CleanStr, 1) = '%' then
  begin
    CleanStr := LeftStr(CleanStr, Length(CleanStr) - 1);
    PercentVal := StrToFloatDef(CleanStr, 0.0, FS);
    if Axis = 'X' then
      BaseDimension := ViewBox[2]
    else
      BaseDimension := ViewBox[3];
    Result := (PercentVal / 100.0) * BaseDimension;
  end
  else
  begin
    Result := StrToFloatDef(CleanStr, 0.0, FS);
  end;
end;

function ConvertSvgToVectorGCode(
  const FileSvg: TMemoryStream;
  FeedRateXY: Integer;     // X-Y feed rate in G1 (mm/min)
  FeedRateZ: Integer;      // Z plunge feed rate in vertical/ramps (mm/min)
  ZSicura: Double;         // Safe retract Z coordinate
  ZStart: Double;          // Starting Z coordinate (top of material)
  ZDepth: Double;          // Cutting total depth (will be subtracted from ZStart)
  ZStep: Double;           // Maximum depth step per pass
  DiametroFresaMM: Double; // Tool diameter (mm)
  tipo_comp: Byte;         // Compensation: 0 = Internal, 1 = External, 2 = None
  NumTabs: Integer;        // Number of tabs for closed profiles (0 to disable)
  SpessoreTabMM: Double;   // Height of the tab from bottom of cut
  FattoreScala: Double;    // Scale multiplier (1.0 = real scale)
  HelicalRamp: Boolean;    // Helicoidal (helical) continuous ramping/approximation
  ClimbMilling: Boolean;   // True = Climb (Concorde), False = Conventional (Discorde)
  FinishAllowance: Double;  // Material to leave for a final finish pass (Sovrametallo)
  Fill:boolean=true
): string;
var
  Doc: TXMLDocument;
  LineeGCode: TStringList;
  ContourList: TObjectList;
  RaggioFresa: Double;
  ZFinale, StepCorrente, ZQuotaTab: Double;
  Fs: TFormatSettings;
  MinX, MinY: Double;
  viewbox: TViewBoxArray;

  // Variabili di supporto per la compensazione
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

  procedure ProcessAndWriteContour(const Contorno: TContour; IsClosed: Boolean; CurrentRaggioOffset: Double; IsOutsideCut: Boolean);
  var
    ContornoOffset, ContornoPulito: TContour;
    I, CleanCount: Integer;
    P1, P2, P3, PtPrec, PFirst, PLast: TPoint2D;
    SegnoOffset: Double;
    IsCW, DesiredCW: Boolean;
    QuotaZAttuale: Double;
    PassataFinita, IsUltimaPassata: Boolean;
    IntervalloTab, ProssimoPuntoTab: Integer;
    TotalLength, AccumulatedLength, Ratio, PointZ, ZPassStart, ZPassEnd, DX, DY: Double;
    CompletedSpiral: Boolean;
    SpiralPassIndex: Integer;
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
        SetLength(ContornoPulito, CleanCount); // Nota: qui la variabile corretta è ContornoPulito
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

    TotalLength := 0.0;
    if IsClosed and (Length(ContornoOffset) >= 2) then
    begin
      for I := 0 to High(ContornoOffset) do
      begin
        if I = High(ContornoOffset) then
        begin
          DX := ContornoOffset[0].X - ContornoOffset[I].X;
          DY := ContornoOffset[0].Y - ContornoOffset[I].Y;
        end
        else
        begin
          DX := ContornoOffset[I+1].X - ContornoOffset[I].X;
          DY := ContornoOffset[I+1].Y - ContornoOffset[I].Y;
        end;
        TotalLength := TotalLength + Sqrt(DX*DX + DY*DY);
      end;
    end;

    if HelicalRamp and IsClosed and (TotalLength > 0.01) then
    begin
      LineeGCode.Add('; --- Helicoidal Spiral Entry ---');
      ZPassStart := ZStart;
      CompletedSpiral := False;
      SpiralPassIndex := 0;

      LineeGCode.Add(Format('G0 X%.3f Y%.3f', [ContornoOffset[0].X, ContornoOffset[0].Y]));
      LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
      LineeGCode.Add(Format('G0 Z%.3f ; Sfioramento', [ZStart]));

      repeat
        ZPassEnd := ZPassStart - StepCorrente;
        if ZPassEnd <= ZFinale then
        begin
          ZPassEnd := ZFinale;
          CompletedSpiral := True;
        end;

        AccumulatedLength := 0.0;
        for I := 0 to High(ContornoOffset) do
        begin
          if I = High(ContornoOffset) then
          begin
            DX := ContornoOffset[0].X - ContornoOffset[I].X;
            DY := ContornoOffset[0].Y - ContornoOffset[I].Y;
            AccumulatedLength := AccumulatedLength + Sqrt(DX*DX + DY*DY);
            Ratio := AccumulatedLength / TotalLength;
            PointZ := ZPassStart + Ratio * (ZPassEnd - ZPassStart);
            LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d', [ContornoOffset[0].X, ContornoOffset[0].Y, PointZ, FeedRateXY]));
          end
          else
          begin
            DX := ContornoOffset[I+1].X - ContornoOffset[I].X;
            DY := ContornoOffset[I+1].Y - ContornoOffset[I].Y;
            AccumulatedLength := AccumulatedLength + Sqrt(DX*DX + DY*DY);
            Ratio := AccumulatedLength / TotalLength;
            PointZ := ZPassStart + Ratio * (ZPassEnd - ZPassStart);
            LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d', [ContornoOffset[I+1].X, ContornoOffset[I+1].Y, PointZ, FeedRateXY]));
          end;
        end;
        ZPassStart := ZPassEnd;
        Inc(SpiralPassIndex);
      until CompletedSpiral;

      if (NumTabs > 0) and (Length(ContornoOffset) > NumTabs) then
        IntervalloTab := Length(ContornoOffset) div NumTabs
      else
        IntervalloTab := 0;

      ProssimoPuntoTab := IntervalloTab;
      for I := 1 to High(ContornoOffset) do
      begin
        if (IntervalloTab > 0) and (I = ProssimoPuntoTab) and (I < High(ContornoOffset)) then
        begin
          LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d ; TAB', [ContornoOffset[I].X, ContornoOffset[I].Y, ZQuotaTab, FeedRateZ]));
          LineeGCode.Add(Format('G1 Z%.3f F%d', [ZFinale, FeedRateZ]));
          Inc(ProssimoPuntoTab, IntervalloTab);
        end
        else
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [ContornoOffset[I].X, ContornoOffset[I].Y, FeedRateXY]));
      end;
      LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [ContornoOffset[0].X, ContornoOffset[0].Y, FeedRateXY]));
    end
    else
    begin
      LineeGCode.Add(Format('G0 X%.3f Y%.3f', [ContornoOffset[0].X, ContornoOffset[0].Y]));
      LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
      LineeGCode.Add(Format('G0 Z%.3f ; Sfioramento', [ZStart]));
      QuotaZAttuale := ZStart;
      PassataFinita := False;

      if (NumTabs > 0) and IsClosed and (Length(ContornoOffset) > NumTabs) then
        IntervalloTab := Length(ContornoOffset) div NumTabs
      else
        IntervalloTab := 0;

      repeat
        QuotaZAttuale := QuotaZAttuale - StepCorrente;
        IsUltimaPassata := False;
        if QuotaZAttuale <= ZFinale then
        begin
          QuotaZAttuale := ZFinale;
          PassataFinita := True;
          IsUltimaPassata := True;
        end;

        if Length(ContornoOffset) >= 2 then
          LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d', [ContornoOffset[0].X, ContornoOffset[0].Y, QuotaZAttuale, FeedRateZ]));

        ProssimoPuntoTab := IntervalloTab;
        for I := 1 to High(ContornoOffset) do
        begin
          if IsUltimaPassata and (IntervalloTab > 0) and (I = ProssimoPuntoTab) and (I < High(ContornoOffset)) then
          begin
            LineeGCode.Add(Format('G1 X%.3f Y%.3f Z%.3f F%d ; TAB', [ContornoOffset[I].X, ContornoOffset[I].Y, ZQuotaTab, FeedRateZ]));
            LineeGCode.Add(Format('G1 Z%.3f F%d', [QuotaZAttuale, FeedRateZ]));
            Inc(ProssimoPuntoTab, IntervalloTab);
          end
          else
            LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [ContornoOffset[I].X, ContornoOffset[I].Y, FeedRateXY]));
        end;

        if IsClosed then
        begin
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [ContornoOffset[0].X, ContornoOffset[0].Y, FeedRateXY]));
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [ContornoOffset[0].X, ContornoOffset[0].Y, FeedRateXY]));
        end;
      until PassataFinita;
    end;
    LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
  end;

  procedure ProcessPocketZigZag(StoredObj: TStoredContour);
  var
    RoughOuter, FinishOuter: TContour;
    RoughHoles, FinishHoles: TContourArray;
    I, J, HIdx: Integer;
    InwardSign, HoleSign: Double;
    P1Ext, P2Ext, P3Ext: TPoint2D;
    QuotaZ: Double;
    PassataFinita: Boolean;
    MinY_Safe, MaxY_Safe, CurrY: Double;
    XInts: TDoubleArray;
    LayerCuts: TCutArray;
    MidX: Double;
    MidPt: TPoint2D;
    IsValid, IsCW, DesiredCW: Boolean;
    DirRight: Boolean;
    CutIdx: Integer;
    Stepover: Double;
  begin
    IsCW := IsPolygonClockwise(StoredObj.Points);
    if IsCW <> ClimbMilling then
    begin
      ReverseContour(StoredObj.Points);
      IsCW := ClimbMilling;
    end;
    InwardSign := IfThen(IsCW, -1.0, 1.0);

    SetLength(RoughOuter, Length(StoredObj.Points));
    SetLength(FinishOuter, Length(StoredObj.Points));
    for J := 0 to High(StoredObj.Points) do begin
      if J = 0 then P1Ext := StoredObj.Points[High(StoredObj.Points)] else P1Ext := StoredObj.Points[J - 1];
      P2Ext := StoredObj.Points[J];
      if J = High(StoredObj.Points) then P3Ext := StoredObj.Points[0] else P3Ext := StoredObj.Points[J + 1];

      RoughOuter[J] := CalcolaPuntoOffset(P1Ext, P2Ext, P3Ext, InwardSign * (RaggioFresa + FinishAllowance));
      RoughOuter[J].X := RoughOuter[J].X - MinX; RoughOuter[J].Y := RoughOuter[J].Y - MinY;

      FinishOuter[J] := CalcolaPuntoOffset(P1Ext, P2Ext, P3Ext, InwardSign * RaggioFresa);
      FinishOuter[J].X := FinishOuter[J].X - MinX; FinishOuter[J].Y := FinishOuter[J].Y - MinY;
    end;

    SetLength(FinishHoles, Length(StoredObj.Holes));
    SetLength(RoughHoles, Length(StoredObj.Holes));
    for HIdx := 0 to High(StoredObj.Holes) do begin
      IsCW := IsPolygonClockwise(StoredObj.Holes[HIdx]);
      DesiredCW := not ClimbMilling;
      if IsCW <> DesiredCW then
      begin
        ReverseContour(StoredObj.Holes[HIdx]);
        IsCW := DesiredCW;
      end;
      HoleSign := IfThen(IsCW, 1.0, -1.0);

      SetLength(FinishHoles[HIdx], Length(StoredObj.Holes[HIdx]));
      SetLength(RoughHoles[HIdx], Length(StoredObj.Holes[HIdx]));

      for J := 0 to High(StoredObj.Holes[HIdx]) do begin
        if J = 0 then P1Ext := StoredObj.Holes[HIdx][High(StoredObj.Holes[HIdx])] else P1Ext := StoredObj.Holes[HIdx][J - 1];
        P2Ext := StoredObj.Holes[HIdx][J];
        if J = High(StoredObj.Holes[HIdx]) then P3Ext := StoredObj.Holes[HIdx][0] else P3Ext := StoredObj.Holes[HIdx][J + 1];

        RoughHoles[HIdx][J] := CalcolaPuntoOffset(P1Ext, P2Ext, P3Ext, HoleSign * (RaggioFresa + FinishAllowance));
        RoughHoles[HIdx][J].X := RoughHoles[HIdx][J].X - MinX; RoughHoles[HIdx][J].Y := RoughHoles[HIdx][J].Y - MinY;

        FinishHoles[HIdx][J] := CalcolaPuntoOffset(P1Ext, P2Ext, P3Ext, HoleSign * RaggioFresa);
        FinishHoles[HIdx][J].X := FinishHoles[HIdx][J].X - MinX; FinishHoles[HIdx][J].Y := FinishHoles[HIdx][J].Y - MinY;
      end;
    end;

    MinY_Safe := Infinity; MaxY_Safe := -Infinity;
    for I := 0 to High(RoughOuter) do begin
      if RoughOuter[I].Y < MinY_Safe then MinY_Safe := RoughOuter[I].Y;
      if RoughOuter[I].Y > MaxY_Safe then MaxY_Safe := RoughOuter[I].Y;
    end;

    Stepover := 0.8 * DiametroFresaMM;
    if Stepover < 0.1 then Stepover := 0.1;

    QuotaZ := ZStart;
    PassataFinita := False;

    repeat
      QuotaZ := QuotaZ - StepCorrente;
      if QuotaZ <= ZFinale then begin
        QuotaZ := ZFinale;
        PassataFinita := True;
      end;

      LineeGCode.Add(Format('; --- Z Layer Sbozzatura %.3f ---', [QuotaZ]));

      if Length(RoughOuter) > 0 then begin
        LineeGCode.Add(Format('G0 X%.3f Y%.3f ; Rough Outer', [RoughOuter[0].X, RoughOuter[0].Y]));
        LineeGCode.Add(Format('G1 Z%.3f F%d', [QuotaZ, FeedRateZ]));
        for I := 1 to High(RoughOuter) do
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [RoughOuter[I].X, RoughOuter[I].Y, FeedRateXY]));
        LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [RoughOuter[0].X, RoughOuter[0].Y, FeedRateXY]));
        LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
      end;

      for HIdx := 0 to High(RoughHoles) do begin
        if Length(RoughHoles[HIdx]) > 0 then begin
          LineeGCode.Add(Format('G0 X%.3f Y%.3f ; Rough Hole', [RoughHoles[HIdx][0].X, RoughHoles[HIdx][0].Y]));
          LineeGCode.Add(Format('G1 Z%.3f F%d', [QuotaZ, FeedRateZ]));
          for I := 1 to High(RoughHoles[HIdx]) do
            LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [RoughHoles[HIdx][I].X, RoughHoles[HIdx][I].Y, FeedRateXY]));
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [RoughHoles[HIdx][0].X, RoughHoles[HIdx][0].Y, FeedRateXY]));
          LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
        end;
      end;

      CurrY := MinY_Safe + Stepover;
      DirRight := True;

      while CurrY < MaxY_Safe do begin
        SetLength(XInts, 0);
        AddIntersections(CurrY, RoughOuter, XInts);
        for HIdx := 0 to High(RoughHoles) do
          AddIntersections(CurrY, RoughHoles[HIdx], XInts);

        SortDoubleArray(XInts);

        if Length(XInts) > 0 then
        begin
          J := 1;
          for I := 1 to High(XInts) do
          begin
            if Abs(XInts[I] - XInts[I - 1]) > 0.001 then
            begin
              XInts[J] := XInts[I];
              Inc(J);
            end;
          end;
          SetLength(XInts, J);
        end;

        SetLength(LayerCuts, 0);
        I := 0;
        while I < Length(XInts) - 1 do begin
          MidX := (XInts[I] + XInts[I+1]) / 2.0;
          MidPt.X := MidX; MidPt.Y := CurrY;
          IsValid := IsPointInPolygon(MidPt, RoughOuter);

          if IsValid then
            for HIdx := 0 to High(RoughHoles) do
              if IsPointInPolygon(MidPt, RoughHoles[HIdx]) then begin
                IsValid := False; Break;
              end;

          if IsValid then begin
            SetLength(LayerCuts, Length(LayerCuts) + 1);
            LayerCuts[High(LayerCuts)].P1.X := XInts[I]; LayerCuts[High(LayerCuts)].P1.Y := CurrY;
            LayerCuts[High(LayerCuts)].P2.X := XInts[I+1]; LayerCuts[High(LayerCuts)].P2.Y := CurrY;
          end;
          Inc(I);
        end;

        if Length(LayerCuts) > 0 then begin
          if DirRight then begin
            for CutIdx := 0 to High(LayerCuts) do begin
              LineeGCode.Add(Format('G0 X%.3f Y%.3f', [LayerCuts[CutIdx].P1.X, LayerCuts[CutIdx].P1.Y]));
              LineeGCode.Add(Format('G1 Z%.3f F%d', [QuotaZ, FeedRateZ]));
              LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [LayerCuts[CutIdx].P2.X, LayerCuts[CutIdx].P2.Y, FeedRateXY]));
              LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
            end;
          end else begin
            for CutIdx := High(LayerCuts) downto 0 do begin
              LineeGCode.Add(Format('G0 X%.3f Y%.3f', [LayerCuts[CutIdx].P2.X, LayerCuts[CutIdx].P2.Y]));
              LineeGCode.Add(Format('G1 Z%.3f F%d', [QuotaZ, FeedRateZ]));
              LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [LayerCuts[CutIdx].P1.X, LayerCuts[CutIdx].P1.Y, FeedRateXY]));
              LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
            end;
          end;
        end;

        DirRight := not DirRight;
        CurrY := CurrY + Stepover;
      end;

      if FinishAllowance > 0.0001 then
      begin
        LineeGCode.Add(Format('; --- Z Layer Finitura (Sovrametallo) %.3f ---', [QuotaZ]));
        if Length(FinishOuter) > 0 then begin
          LineeGCode.Add(Format('G0 X%.3f Y%.3f ; Finish Outer', [FinishOuter[0].X, FinishOuter[0].Y]));
          LineeGCode.Add(Format('G1 Z%.3f F%d', [QuotaZ, FeedRateZ]));
          for I := 1 to High(FinishOuter) do
            LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [FinishOuter[I].X, FinishOuter[I].Y, FeedRateXY]));
          LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [FinishOuter[0].X, FinishOuter[0].Y, FeedRateXY]));
          LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
        end;

        for HIdx := 0 to High(FinishHoles) do begin
          if Length(FinishHoles[HIdx]) > 0 then begin
            LineeGCode.Add(Format('G0 X%.3f Y%.3f ; Finish Hole', [FinishHoles[HIdx][0].X, FinishHoles[HIdx][0].Y]));
            LineeGCode.Add(Format('G1 Z%.3f F%d', [QuotaZ, FeedRateZ]));
            for I := 1 to High(FinishHoles[HIdx]) do
              LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [FinishHoles[HIdx][I].X, FinishHoles[HIdx][I].Y, FeedRateXY]));
            LineeGCode.Add(Format('G1 X%.3f Y%.3f F%d', [FinishHoles[HIdx][0].X, FinishHoles[HIdx][0].Y, FeedRateXY]));
            LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
          end;
        end;
      end;

    until PassataFinita;
  end;

var
  ListaNodi: TDOMNodeList;
  NodoAttr: TDOMNode;
  ContornoCorrente: TContour;
  I, J, HIdx: Integer;
  CX, CY, RX, RY, X, Y, W, H, X1, Y1, X2, Y2, Angolo: Double;
  Pt: TPoint2D;
  Sc: Double;
  Stored: TStoredContour;
  TargetWidth, ToolDiam, Spacing, OffsetAmount: Double;
  StrokeContour: TContour;
  P1Extend, P2Extend, P3Extend: TPoint2D;
  StrokeW: Double;
  NPasses, KPass, JVertex: Integer;

begin
  Result := '';
  SetLength(ContornoCorrente, 0);
  SetLength(StrokeContour, 0);
  FinishAllowance := Max(0.0, FinishAllowance);

  Sc := FattoreScala;
  if Sc <= 0.0 then Sc := 1.0;
  RaggioFresa := DiametroFresaMM / 2.0;
  // Setup delle variabili di controllo compensazione basate sul parametro tipo_comp
  IsOutside := (tipo_comp <> 0); // 1 (Esterna) e 2 (Nessuna) usano True per la direzione di taglio concorde/discorde
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

  // ZFinale viene ora calcolato in base alla quota di partenza ZStart
  ZFinale := ZStart - Abs(ZDepth);
  StepCorrente := Abs(ZStep);
  if StepCorrente < 0.001 then StepCorrente := Abs(ZDepth);

  // I tab non possono superare il limite superiore del pezzo (ZStart)
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
        begin
          for J := 0 to High(Stored.Holes[HIdx]) do
          begin
            if Stored.Holes[HIdx][J].X < MinX then MinX := Stored.Holes[HIdx][J].X;
            if Stored.Holes[HIdx][J].Y < MinY then MinY := Stored.Holes[HIdx][J].Y;
          end;
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

        if Stored.IsClosed and Fill and (SameText(Stored.FillColor, 'black') or SameText(Stored.FillColor, '#000000')) and (Stored.FillColor <> '') then
        begin
          ProcessPocketZigZag(Stored);
        end
        else
        begin
          TargetWidth := Stored.StrokeWidth;
          ToolDiam := DiametroFresaMM;

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
              ProcessAndWriteContour(StrokeContour, Stored.IsClosed, 0.0, IsOutside);
            end;
          end
          else
          begin
            if (tipo_comp <> 2) and (FinishAllowance > 0.0001) then
            begin
              LineeGCode.Add('; --- Sbozzatura Contorno ---');
              ProcessAndWriteContour(Stored.Points, Stored.IsClosed, RaggioOffsetRough, IsOutside);
              LineeGCode.Add('; --- Finitura Contorno ---');
              ProcessAndWriteContour(Stored.Points, Stored.IsClosed, RaggioOffsetFinish, IsOutside);
            end
            else
              ProcessAndWriteContour(Stored.Points, Stored.IsClosed, RaggioOffsetFinish, IsOutside);

            for HIdx := 0 to High(Stored.Holes) do
            begin
              IsHoleOutside := not IsOutside;
              if (tipo_comp <> 2) and (FinishAllowance > 0.0001) then
              begin
                LineeGCode.Add('; --- Sbozzatura Foro ---');
                ProcessAndWriteContour(Stored.Holes[HIdx], Stored.IsClosed, RaggioOffsetRough, IsHoleOutside);
                LineeGCode.Add('; --- Finitura Foro ---');
                ProcessAndWriteContour(Stored.Holes[HIdx], Stored.IsClosed, RaggioOffsetFinish, IsHoleOutside);
              end
              else
                ProcessAndWriteContour(Stored.Holes[HIdx], Stored.IsClosed, RaggioOffsetFinish, IsHoleOutside);
            end;
          end;
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
