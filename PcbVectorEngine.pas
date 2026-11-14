unit PcbVectorEngine;
{$mode objfpc}{$H+}
{$inline on}

interface

uses
  SysUtils, Classes, Graphics, GraphType, LCLIntf, FPimage, IntfGraphics, Math;

type
  TPoint2D = record
    X, Y: Double;
    pX,pY:integer;
  end;
  TContour = array of TPoint2D;

type
  TContourToken = record
    PuntiOriginali: TContour;
    IsForo: Boolean;
    IDPista: Integer; // Identificativo univoco del tracciato
  end;
  TContourTokenArray = array of TContourToken;

type
  // Struttura per memorizzare i dati di ogni singola isola da incidere
  TIsolaIncisione = record
    PuntiOffset: TContour;
    ContourLen: Integer;
    // Coordinata di partenza del movimento (il primo punto dell'offset)
    StartPt: TPoint2D;
    aa:double;
  end;

function ConvertPcbToDrillGCode(
  const Immagine: TMemoryStream;
  RisoluzioneMM: Double;
  FeedRateForatura: Integer;
  ZSicura: Double;
  ZForatura: Double;
  DiametroMassimoForoMM: Double
): string;

function ConvertPcbToIncisioneGCode(
  const Immagine: TMemoryStream;
  RisoluzioneMM: Double;
  FeedRate: Integer;
  ZSicura: Double;
  ZIncisione: Double;
  DiametroFresaMM: Double;
  DiametroMassimoForoMM: Double
): string;

function ConvertPcbToIncisioneGCodeAdattiva(
  const Immagine: TMemoryStream;
  RisoluzioneMM: Double;
  FeedRate: Integer;
  ZSicura: Double;
  ZIncisione: Double;
  DiametroFresaMM: Double;
  DiametroMassimoForoMM: Double;
  estensionePisteMM:double
): string;

implementation

function TryGetArcRadius(const P1, P2, P3: TPoint2D; out IsClockwise: Boolean): Double; inline;
var
  A, B, C, D, G, E, F, CX, CY: Double;
begin
  Result := 0; IsClockwise := False;
  A := P2.X - P1.X; B := P2.Y - P1.Y;
  C := P3.X - P1.X; D := P3.Y - P1.Y;
  G := 2 * (A * D - B * C);
  if Abs(G) < 0.000001 then Exit;
  E := (P2.X*P2.X + P2.Y*P2.Y) - (P1.X*P1.X + P1.Y*P1.Y);
  F := (P3.X*P3.X + P3.Y*P3.Y) - (P1.X*P1.X + P1.Y*P1.Y);
  CX := (D * E - B * F) / G;
  CY := (A * F - C * E) / G;
  Result := Sqrt(Sqr(P1.X - CX) + Sqr(P1.Y - CY));
  IsClockwise := (A * D - B * C) < 0;
end;

function CalcolaPuntoOffset(const Precedente, Corrente, Successivo: TPoint2D; Distanza: Double): TPoint2D; inline;
var
  DX1, DY1, DX2, DY2, Len1, Len2, NX1, NY1, NX2, NY2, BisX, BisY, LenBis: Double;
begin
  Result := Corrente;
  DX1 := Corrente.X - Precedente.X; DY1 := Corrente.Y - Precedente.Y; Len1 := Sqrt(DX1*DX1 + DY1*DY1);
  DX2 := Successivo.X - Corrente.X; DY2 := Successivo.Y - Corrente.Y; Len2 := Sqrt(DX2*DX2 + DY2*DY2);

  if (Len1 < 0.00001) or (Len2 < 0.00001) then begin
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

function ConvertPcbToDrillGCode(
  const Immagine: TMemoryStream;
  RisoluzioneMM: Double;
  FeedRateForatura: Integer;
  ZSicura: Double;
  ZForatura: Double;
  DiametroMassimoForoMM: Double
): string;
type
  TForoPiazzola = record
    X, Y: Double;
  end;
var
  Bmp: TBitmap;
  Pic: TPicture;
  IntfImg: TLazIntfImage;
  LineeGCode: TStringList;
  W, H, PadW, PadH, X, Y, CX, CY, NX, NY: Integer;
  Grid: array of array of Boolean;
  ColorGrid: array of array of TFPColor;
  Visitati: array of array of Boolean;

  function IsEdgePixelFast(AX, AY: Integer): Boolean; inline;
  begin
    if (AX <= 0) or (AX >= PadW - 1) or (AY <= 0) or (AY >= PadH - 1) then Exit(False);
    if not Grid[AX, AY] then Exit(False);
    Result := (not Grid[AX+1, AY]) or (not Grid[AX-1, AY]) or
              (not Grid[AX, AY+1]) or (not Grid[AX, AY-1]);
  end;

var
  Contorno: TContour;
  ContourLen, Dir, D, Step: Integer;
  TrovatoVicino: Boolean;
  DX: array[0..7] of Integer = (1, 1, 0, -1, -1, -1, 0, 1);
  DY: array[0..7] of Integer = (0, 1, 1, 1, 0, -1, -1, -1);
  I, J, IndiceVicino: Integer;
  ImgColor: TFPColor;
  MinXpixels, MaxXpixels, MinYpixels, MaxYpixels: integer;
  MinXMM, MaxXMM, MinYMM, MaxYMM: Double;
  LarghezzaIsola, AltezzaIsola: Double;
  CentroX, CentroY, DistMin, DistAttuale: Double;
  SommaX, SommaY: Double;
  IsAForo: Boolean;
  ColoreContornoPiazzola: TFPColor;
  ColoreCentroPiazzola:TFPColor;

  // Array per ottimizzazione TSP (Traveling Salesman Problem)
  ListaFori: array of TForoPiazzola;
  ForiCount: Integer;
  ForiOrdinati: array of TForoPiazzola;
  ForiVisitati: array of Boolean;
  CurrX, CurrY: Double;
begin
  Result := '';
  Grid := nil; ColorGrid := nil; Visitati := nil; Contorno := nil;
  ListaFori := nil; ForiOrdinati := nil; ForiVisitati := nil;
  ForiCount := 0;

  Bmp := TBitmap.Create;
  Pic := TPicture.Create;
  IntfImg := TLazIntfImage.Create(0, 0);
  LineeGCode := TStringList.Create;
  try
    try
      immagine.Position:=0;
      Pic.LoadFromStream(Immagine);
      Bmp.Assign(Pic.Graphic);
      IntfImg.LoadFromBitmap(Bmp.Handle, Bmp.MaskHandle);
    except
      result:=';Could not open file'+#10;
      exit;
    end;
    W := IntfImg.Width; H := IntfImg.Height;
    PadW := W + 4; PadH := H + 4;
    SetLength(Grid, PadW, PadH);
    SetLength(ColorGrid, PadW, PadH);
    SetLength(Visitati, PadW, PadH);

    for Y := 0 to PadH - 1 do
      for X := 0 to PadW - 1 do
      begin
        Grid[X, Y] := False;
        Visitati[X, Y] := False;
      end;

    for Y := 0 to H - 1 do
    begin
      for X := 0 to W - 1 do
      begin
        ImgColor := IntfImg.Colors[X, Y];
        ColorGrid[X + 2, Y + 2] := ImgColor;
        Grid[X + 2, Y + 2] := ((ImgColor.red + ImgColor.green + ImgColor.blue) div 3) > 15000;
      end;
    end;

    // --- FASE 1: Rilevamento di tutti i centri dei fori ---
    for Y := 1 to PadH - 2 do
    begin
      for X := 1 to PadW - 2 do
      begin
        if IsEdgePixelFast(X, Y) and (not Visitati[X, Y]) then
        begin
          ContourLen := 0;
          SetLength(Contorno, PadW * 2 + PadH * 2);
          CX := X; CY := Y; Dir := 0;
          ColoreContornoPiazzola := ColorGrid[CX, CY];
          repeat
            if ContourLen >= Length(Contorno) then
              SetLength(Contorno, Length(Contorno) * 2);
            Visitati[CX, CY] := True;
            Contorno[ContourLen].X := (CX - 2) * RisoluzioneMM;
            Contorno[ContourLen].Y := (H - 1 - (CY - 2)) * RisoluzioneMM;
            Contorno[ContourLen].pX := (CX - 2);
            Contorno[ContourLen].pY := (H - 1 - (CY - 2));
            Inc(ContourLen);
            TrovatoVicino := False;
            for D := 0 to 7 do
            begin
              Step := (Dir + D) mod 8;
              NX := CX + DX[Step]; NY := CY + DY[Step];
              if IsEdgePixelFast(NX, NY) and (not Visitati[NX, NY]) then
              begin
                CX := NX; CY := NY;
                Dir := (Step + 5) mod 8;
                TrovatoVicino := True;
                Break;
              end;
            end;
          until not TrovatoVicino;

          if ContourLen > 2 then
          begin
            SetLength(Contorno, ContourLen);
            MinXMM := 1e9; MaxXMM := -1e9; MinYMM := 1e9; MaxYMM := -1e9;
            SommaX := 0; SommaY := 0;
            MinXpixels:=Contorno[0].pX;MaxXpixels:=Contorno[0].pX;MinYpixels:=Contorno[0].pY;MaxYpixels:=Contorno[0].pY;
            for I := 0 to ContourLen - 1 do
            begin
              if Contorno[I].X < MinXMM then MinXMM := Contorno[I].X;
              if Contorno[I].X > MaxXMM then MaxXMM := Contorno[I].X;
              if Contorno[I].Y < MinYMM then MinYMM := Contorno[I].Y;
              if Contorno[I].Y > MaxYMM then MaxYMM := Contorno[I].Y;
              if Contorno[I].pX < MinXpixels then MinXpixels := Contorno[I].pX;
              if Contorno[I].pX > MaxXpixels then MaxXpixels := Contorno[I].pX;
              if Contorno[I].pY < MinYpixels then MinYpixels := Contorno[I].pY;
              if Contorno[I].pY > MaxYpixels then MaxYpixels := Contorno[I].pY;
              SommaX := SommaX + Contorno[I].X;
              SommaY := SommaY + Contorno[I].Y;
            end;
            LarghezzaIsola := MaxXMM - MinXMM;
            AltezzaIsola := MaxYMM - MinYMM;

            IsAForo := (LarghezzaIsola > 0.05) and (LarghezzaIsola <= DiametroMassimoForoMM) and
                       (AltezzaIsola > 0.05) and (AltezzaIsola <= DiametroMassimoForoMM) and
                       (Abs(LarghezzaIsola - AltezzaIsola) < (RisoluzioneMM * 2.0));
            if IsAForo then
            begin
              IsAForo := (ColoreContornoPiazzola.Red > 50000) and
                         (ColoreContornoPiazzola.Green < 15000) and
                         (ColoreContornoPiazzola.Blue < 15000);
              if IsAForo = false then
              begin
                ColoreCentroPiazzola:=ColorGrid[(MinXpixels+MaxXpixels) div 2, H-(MinYpixels+MaxYpixels) div 2];
                IsAForo := (ColoreCentroPiazzola.Red > 50000) and
                           (ColoreCentroPiazzola.Green < 15000) and
                           (ColoreCentroPiazzola.Blue < 15000);
              end;
            end;

            if IsAForo then
            begin
              Inc(ForiCount);
              SetLength(ListaFori, ForiCount);
              ListaFori[ForiCount - 1].X := SommaX / ContourLen;
              ListaFori[ForiCount - 1].Y := SommaY / ContourLen;
            end;
          end;
        end;
      end;
    end;

    // --- FASE 2: Ottimizzazione del percorso (Nearest Neighbor) ---
    if ForiCount > 0 then
    begin
      SetLength(ForiOrdinati, ForiCount);
      SetLength(ForiVisitati, ForiCount);
      for I := 0 to ForiCount - 1 do ForiVisitati[I] := False;

      // Partiamo dalle coordinate Home della macchina (0, 0)
      CurrX := 0.0;
      CurrY := 0.0;

      for I := 0 to ForiCount - 1 do
      begin
        IndiceVicino := -1;
        DistMin := 1e18; // Valore di partenza infinitamente grande

        for J := 0 to ForiCount - 1 do
        begin
          if not ForiVisitati[J] then
          begin
            // Distanza euclidea al quadrato (evita la radice quadrata flettere le prestazioni)
            DistAttuale := Sqr(ListaFori[J].X - CurrX) + Sqr(ListaFori[J].Y - CurrY);
            if DistAttuale < DistMin then
            begin
              DistMin := DistAttuale;
              IndiceVicino := J;
            end;
          end;
        end;

        if IndiceVicino <> -1 then
        begin
          ForiVisitati[IndiceVicino] := True;
          ForiOrdinati[I] := ListaFori[IndiceVicino];
          // Il prossimo foro viene cercato a partire dalla posizione attuale appena raggiunta
          CurrX := ForiOrdinati[I].X;
          CurrY := ForiOrdinati[I].Y;
        end;
      end;
    end;

    // --- FASE 3: Generazione G-Code Ordinato ---
    LineeGCode.Add('G21 ; Unita in millimetri');
    LineeGCode.Add('G90 ; Coordinate assolute');
    LineeGCode.Add(Format('G0 Z%.3f F1000 ; Quota di sicurezza iniziale', [ZSicura]));
    LineeGCode.Add('; =============================================');
    LineeGCode.Add(';  FASE: FORATURA AUTOMATICA OTTIMIZZATA');
    LineeGCode.Add('; =============================================');

    for I := 0 to ForiCount - 1 do
    begin
      LineeGCode.Add(Format('G0 X%.3f Y%.3f ; Centro foro piazzola rossa', [ForiOrdinati[I].X, ForiOrdinati[I].Y]));
      LineeGCode.Add(Format('G1 Z%.3f F%d ; Foro', [ZForatura, FeedRateForatura]));
      LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
    end;

    // Chiusura del file G-Code
    LineeGCode.Add('M5 ; Arresto mandrino');
    LineeGCode.Add('G0 X0 Y0 ; Ritorno Home macchina');
//    LineeGCode.Add('M30 ; Fine del programma');
    Result := LineeGCode.Text;
  finally
    LineeGCode.Free;
    IntfImg.Free;
    Bmp.Free;
    Pic.Free;
    ListaFori := nil;
    ForiOrdinati := nil;
    ForiVisitati := nil;
  end;
end;

function ConvertPcbToIncisioneGCode(
  const Immagine: TMemoryStream;
  RisoluzioneMM: Double;
  FeedRate: Integer;
  ZSicura: Double;
  ZIncisione: Double;
  DiametroFresaMM: Double;
  DiametroMassimoForoMM: Double
): string;
var
  Bmp: TBitmap;
  Pic: TPicture;
  IntfImg: TLazIntfImage;
  LineeGCode: TStringList;
  W, H, PadW, PadH, X, Y, CX, CY, NX, NY: Integer;
  RaggioOffset, SogliaToleranzaArco: Double;
  Grid: array of array of Boolean;
  ColorGrid: array of array of TFPColor;
  Visitati: array of array of Boolean;

  function IsEdgePixelFast(AX, AY: Integer): Boolean; inline;
  begin
    if (AX <= 0) or (AX >= PadW - 1) or (AY <= 0) or (AY >= PadH - 1) then Exit(False);
    if not Grid[AX, AY] then Exit(False);
    Result := (not Grid[AX+1, AY]) or (not Grid[AX-1, AY]) or
              (not Grid[AX, AY+1]) or (not Grid[AX, AY-1]);
  end;

var
  Contorno: TContour;
  ContourLen, Dir, D, Step: Integer;
  TrovatoVicino: Boolean;
  DX: array[0..7] of Integer = (1, 1, 0, -1, -1, -1, 0, 1);
  DY: array[0..7] of Integer = (0, 1, 1, 1, 0, -1, -1, -1);
  I, J: Integer;
  P1, P2, P3: TPoint2D;
  Raggio: Double;
  IsCW: Boolean;
  ImgColor: TFPColor;
  PassoCampione: Integer;
  MinXMM, MaxXMM, MinYMM, MaxYMM: Double;
  LarghezzaIsola, AltezzaIsola: Double;
  IsAForo: Boolean;
  ColoreContornoPiazzola: TFPColor;

  // Variabili per l'ottimizzazione TSP delle isole
  ElencoIsole: array of TIsolaIncisione;
  IsoleCount: Integer;
  IsolaCorrente: TIsolaIncisione;
  IsoleVisitateTSP: array of Boolean;
  CurrX, CurrY, DistMin, DistAttuale: Double;
  IdxProssimo, IdxCorrente: Integer;

begin
  Result := '';
  Grid := nil; ColorGrid := nil; Visitati := nil; Contorno := nil;
  ElencoIsole := nil; IsoleVisitateTSP := nil;

  Bmp := TBitmap.Create;
  Pic := TPicture.Create;
  IntfImg := TLazIntfImage.Create(0, 0);
  LineeGCode := TStringList.Create;
  try
    try
      Immagine.Position:=0;
      Pic.LoadFromStream(Immagine);
      Bmp.Assign(Pic.Graphic);
      IntfImg.LoadFromBitmap(Bmp.Handle, Bmp.MaskHandle);
    except
      result:=';Could not open file'+#10;
      exit;
    end;
    W := IntfImg.Width; H := IntfImg.Height;
    PadW := W + 4; PadH := H + 4;
    RaggioOffset := DiametroFresaMM / 2.0;
    SogliaToleranzaArco := RisoluzioneMM * 1.5;
    PassoCampione := 3;

    SetLength(Grid, PadW, PadH);
    SetLength(ColorGrid, PadW, PadH);
    SetLength(Visitati, PadW, PadH);

    for Y := 0 to PadH - 1 do
      for X := 0 to PadW - 1 do
      begin
        Grid[X, Y] := False;
        Visitati[X, Y] := False;
      end;

    for Y := 0 to H - 1 do
    begin
      for X := 0 to W - 1 do
      begin
        ImgColor := IntfImg.Colors[X, Y];
        ColorGrid[X + 2, Y + 2] := ImgColor;
        Grid[X + 2, Y + 2] := ((ImgColor.red + ImgColor.green + ImgColor.blue) div 3) > 15000;
      end;
    end;

    IsoleCount := 0;
    SetLength(ElencoIsole, 16); // Allocazione iniziale dinamica

    // 1️⃣ FASE: RACCOLTA E CALCOLO DELLE ISOLE DA INCIDERE
    for Y := 1 to PadH - 2 do
    begin
      for X := 1 to PadW - 2 do
      begin
        if IsEdgePixelFast(X, Y) and (not Visitati[X, Y]) then
        begin
          ContourLen := 0;
          SetLength(Contorno, PadW * 2 + PadH * 2);
          CX := X; CY := Y; Dir := 0;
          ColoreContornoPiazzola := ColorGrid[CX, CY];

          repeat
            if ContourLen >= Length(Contorno) then
              SetLength(Contorno, Length(Contorno) * 2);
            Visitati[CX, CY] := True;
            Contorno[ContourLen].X := (CX - 2) * RisoluzioneMM;
            Contorno[ContourLen].Y := (H - 1 - (CY - 2)) * RisoluzioneMM;
            Inc(ContourLen);
            TrovatoVicino := False;
            for D := 0 to 7 do
            begin
              Step := (Dir + D) mod 8;
              NX := CX + DX[Step]; NY := CY + DY[Step];
              if IsEdgePixelFast(NX, NY) and (not Visitati[NX, NY]) then
              begin
                CX := NX; CY := NY;
                Dir := (Step + 5) mod 8;
                TrovatoVicino := True;
                Break;
              end;
            end;
          until not TrovatoVicino;

          if ContourLen > 2 then
          begin
            SetLength(Contorno, ContourLen);
            MinXMM := 1e9; MaxXMM := -1e9; MinYMM := 1e9; MaxYMM := -1e9;
            for I := 0 to ContourLen - 1 do
            begin
              if Contorno[I].X < MinXMM then MinXMM := Contorno[I].X;
              if Contorno[I].X > MaxXMM then MaxXMM := Contorno[I].X;
              if Contorno[I].Y < MinYMM then MinYMM := Contorno[I].Y;
              if Contorno[I].Y > MaxYMM then MaxYMM := Contorno[I].Y;
            end;

            LarghezzaIsola := MaxXMM - MinXMM;
            AltezzaIsola := MaxYMM - MinYMM;
            IsAForo := (LarghezzaIsola > 0.05) and (LarghezzaIsola <= DiametroMassimoForoMM) and
                       (AltezzaIsola > 0.05) and (AltezzaIsola <= DiametroMassimoForoMM) and
                       (Abs(LarghezzaIsola - AltezzaIsola) < (RisoluzioneMM * 2.0));

            if IsAForo then
            begin
              IsAForo := (ColoreContornoPiazzola.Red > 50000) and
                         (ColoreContornoPiazzola.Green < 15000) and
                         (ColoreContornoPiazzola.Blue < 15000);
            end;

            // Se NON è un foro, salviamo l'isola nell'elenco temporaneo per l'ottimizzazione
            if not IsAForo then
            begin
              if IsoleCount >= Length(ElencoIsole) then
                SetLength(ElencoIsole, Length(ElencoIsole) * 2);

              SetLength(ElencoIsole[IsoleCount].PuntiOffset, ContourLen);
              ElencoIsole[IsoleCount].ContourLen := ContourLen;

              for I := 0 to ContourLen - 1 do
              begin
                if I = 0 then P1 := Contorno[ContourLen - 1] else P1 := Contorno[I - 1];
                P2 := Contorno[I];
                if I = ContourLen - 1 then P3 := Contorno[0] else P3 := Contorno[I + 1];
                ElencoIsole[IsoleCount].PuntiOffset[I] := CalcolaPuntoOffset(P1, P2, P3, RaggioOffset);
              end;

              ElencoIsole[IsoleCount].StartPt := ElencoIsole[IsoleCount].PuntiOffset[0];
              Inc(IsoleCount);
            end;
          end;
        end;
      end;
    end;

    // 2️⃣ FASE: GENERAZIONE INTESTAZIONE G-CODE
    LineeGCode.Add('; =============================================');
    LineeGCode.Add(';  FASE: INCISIONE TRACCIATI OTTIMIZZATI (TSP)');
    LineeGCode.Add('; =============================================');
    LineeGCode.Add('G21 ; Unita in millimetri');
    LineeGCode.Add('G90 ; Coordinate assolute');
    LineeGCode.Add(Format('G0 Z%.3f F1000 ; Quota di sicurezza iniziale', [ZSicura]));
    LineeGCode.Add('M03 ; Attiva mandrino');

    // 3️⃣ FASE: ORDINAMENTO GREEDY (NEAREST NEIGHBOR) E SCRITTURA PERCORSO
    if IsoleCount > 0 then
    begin
      SetLength(IsoleVisitateTSP, IsoleCount);
      for I := 0 to IsoleCount - 1 do IsoleVisitateTSP[I] := False;

      // Partiamo dalla Home (X0, Y0)
      CurrX := 0.0;
      CurrY := 0.0;

      for I := 0 to IsoleCount - 1 do
      begin
        DistMin := 1e12;
        IdxProssimo := -1;

        // Cerca l'isola non visitata più vicina alla posizione attuale della fresa
        for J := 0 to IsoleCount - 1 do
        begin
          if not IsoleVisitateTSP[J] then
          begin
            // Distanza euclidea al quadrato (evitiamo la radice quadrata sqrt per velocità)
            DistAttuale := Sqr(ElencoIsole[J].StartPt.X - CurrX) + Sqr(ElencoIsole[J].StartPt.Y - CurrY);
            if DistAttuale < DistMin then
            begin
              DistMin := DistAttuale;
              IdxProssimo := J;
            end;
          end;
        end;

        // Se troviamo la prossima isola, la incidiamo
        if IdxProssimo <> -1 then
        begin
          IsoleVisitateTSP[IdxProssimo] := True;
          IsolaCorrente := ElencoIsole[IdxProssimo];
          ContourLen := IsolaCorrente.ContourLen;

          // Movimento in rapido verso il primo punto dell'isola selezionata
          LineeGCode.Add(Format('G0 X%.3f Y%.3f ; Spostamento rapido ottimizzato', [IsolaCorrente.StartPt.X, IsolaCorrente.StartPt.Y]));
          LineeGCode.Add(Format('G1 Z%.3f F%d', [ZIncisione, FeedRate]));

          // Generazione tracciato interno (Archi G2/G3 o Linee G1)
          IdxCorrente := 0;
          while IdxCorrente < ContourLen - (PassoCampione * 2) do
          begin
            P1 := IsolaCorrente.PuntiOffset[IdxCorrente];
            P2 := IsolaCorrente.PuntiOffset[IdxCorrente + PassoCampione];
            P3 := IsolaCorrente.PuntiOffset[IdxCorrente + (PassoCampione * 2)];
            Raggio := TryGetArcRadius(P1, P2, P3, IsCW);

            if (Raggio > (SogliaToleranzaArco * PassoCampione)) and (Raggio < 50.0) then
            begin
              if IsCW then
                LineeGCode.Add(Format('G2 X%.3f Y%.3f R%.3f', [P3.X, P3.Y, Raggio]))
              else
                LineeGCode.Add(Format('G3 X%.3f Y%.3f R%.3f', [P3.X, P3.Y, Raggio]));
              IdxCorrente := IdxCorrente + (PassoCampione * 2);
            end else begin
              LineeGCode.Add(Format('G1 X%.3f Y%.3f', [P2.X, P2.Y]));
              IdxCorrente := IdxCorrente + PassoCampione;
            end;
          end;

          while IdxCorrente < ContourLen do
          begin
            LineeGCode.Add(Format('G1 X%.3f Y%.3f', [IsolaCorrente.PuntiOffset[IdxCorrente].X, IsolaCorrente.PuntiOffset[IdxCorrente].Y]));
            Inc(IdxCorrente);
          end;

          // Chiusura isola e risalita a quota sicura

          LineeGCode.Add(Format('G1 X%.3f Y%.3f ; Sigillo', [IsolaCorrente.StartPt.X, IsolaCorrente.StartPt.Y]));
          LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
          // Aggiorna la posizione attuale della fresa con l'ultimo punto lavorato
          CurrX := IsolaCorrente.StartPt.X;
          CurrY := IsolaCorrente.StartPt.Y;
        end;
      end;
    end;
    // 4️⃣ FASE: CHIUSURA PROGRAMMA
    LineeGCode.Add('M5 ; Arresto mandrino definitivo');
    LineeGCode.Add('G0 X0 Y0 ; Ritorno Home macchina');
//    LineeGCode.Add('M30 ; Fine del programma');
    Result := LineeGCode.Text;
  finally
    LineeGCode.Free;
    IntfImg.Free;
    Bmp.Free;
    Pic.Free;
    // Pulizia array dinamici record
    for I := 0 to IsoleCount - 1 do  ElencoIsole[I].PuntiOffset := nil;
    ElencoIsole := nil;
    IsoleVisitateTSP := nil;
  end;
end;

function ConvertPcbToIncisioneGCodeAdattiva(
  const Immagine: TMemoryStream;
  RisoluzioneMM: Double;
  FeedRate: Integer;
  ZSicura: Double;
  ZIncisione: Double;
  DiametroFresaMM: Double;
  DiametroMassimoForoMM: Double;
  estensionePisteMM:double
): string;
var
  Bmp: TBitmap;
  Pic: TPicture;
  IntfImg: TLazIntfImage;
  LineeGCode: TStringList;
  W, H, PadW, PadH, X, Y, CX, CY, NX, NY: Integer;
  RaggioOffset, SogliaToleranzaArco: Double;
  Grid,Grid2: array of array of Boolean;
  ColorGrid: array of array of TFPColor;
  Visitati: array of array of Boolean;

  function IsEdgePixelFast(AX, AY: Integer): Boolean; inline;
  begin
    if (AX <= 0) or (AX >= PadW - 1) or (AY <= 0) or (AY >= PadH - 1) then Exit(False);
    if not Grid[AX, AY] then Exit(False);
    Result := (not Grid[AX+1, AY]) or (not Grid[AX-1, AY]) or
              (not Grid[AX, AY+1]) or (not Grid[AX, AY-1]);
  end;

var
  Contorno: TContour;
  ContourLen, Dir, D, Step: Integer;
  TrovatoVicino: Boolean;
  DX: array[0..7] of Integer = (1, 1, 0, -1, -1, -1, 0, 1);
  DY: array[0..7] of Integer = (0, 1, 1, 1, 0, -1, -1, -1);
  I, J: Integer;
  P1, P2, P3: TPoint2D;
  Raggio: Double;
  IsCW: Boolean;
  ImgColor: TFPColor;
  PassoCampione: Integer;
  MinXpixels, MaxXpixels, MinYpixels, MaxYpixels: integer;
  MinXMM, MaxXMM, MinYMM, MaxYMM: Double;
  LarghezzaIsola, AltezzaIsola: Double;
  IsAForo: Boolean;
  ColoreContornoPiazzola: TFPColor;
  ColoreCentroPiazzola: TFPColor;

  // Variabili per l'ottimizzazione TSP delle isole
  ElencoIsole: array of TIsolaIncisione;
  IsoleCount: Integer;
  IsolaCorrente: TIsolaIncisione;
  IsoleVisitateTSP: array of Boolean;
  CurrX, CurrY, DistMin, DistAttuale: Double;
  IdxProssimo, IdxCorrente: Integer;
  a,b,PassoRaggio:double;
  aa,bb:integer;
  pic2:TPicture;
begin
  Result := '';
  Grid := nil; ColorGrid := nil; Visitati := nil; Contorno := nil;
  ElencoIsole := nil; IsoleVisitateTSP := nil;

  Bmp := TBitmap.Create;
  Pic := TPicture.Create;
  IntfImg := TLazIntfImage.Create(0, 0);
  LineeGCode := TStringList.Create;
  try
    try
      Immagine.Position:=0;
      Pic.LoadFromStream(Immagine);
      Bmp.Assign(Pic.Graphic);
      IntfImg.LoadFromBitmap(Bmp.Handle, Bmp.MaskHandle);
    except
      result:=';Could not open file'+#10;
      exit;
    end;
    W := IntfImg.Width; H := IntfImg.Height;
    PadW := W + 4; PadH := H + 4;
    RaggioOffset := DiametroFresaMM / 2.0;
    SogliaToleranzaArco := RisoluzioneMM * 1.5;
    PassoCampione := 3;

    SetLength(Grid, PadW, PadH);
    SetLength(Grid2, PadW, PadH);
    SetLength(ColorGrid, PadW, PadH);
    SetLength(Visitati, PadW, PadH);

    for Y := 0 to PadH - 1 do
      for X := 0 to PadW - 1 do
      begin
        Grid[X, Y] := False;
        Visitati[X, Y] := False;
      end;

    for Y := 0 to H - 1 do
    begin
      for X := 0 to W - 1 do
      begin
        ImgColor := IntfImg.Colors[X, Y];
        ColorGrid[X + 2, Y + 2] := ImgColor;
        Grid[X + 2, Y + 2] := ((ImgColor.red + ImgColor.green + ImgColor.blue) div 3) > 15000;
        Grid2[X + 2, Y + 2] := ((ImgColor.red + ImgColor.green + ImgColor.blue) div 3) > 15000;
      end;
    end;

    IsoleCount := 0;
    SetLength(ElencoIsole, 16); // Allocazione iniziale dinamica

    // 1️⃣ FASE UNIFICATA: RACCOLTA, ESPANSIONE ADATTIVA E CALCOLO OFFSET
    for Y := 1 to PadH - 2 do
    begin
      for X := 1 to PadW - 2 do
      begin
        if IsEdgePixelFast(X, Y) and (not Visitati[X, Y]) then
        begin
          ContourLen := 0;
          SetLength(Contorno, PadW * 2 + PadH * 2);
          CX := X; CY := Y; Dir := 0;
          ColoreContornoPiazzola := ColorGrid[CX, CY];

          // Tracciamento del contorno originale (Pixel)
          repeat
            if ContourLen >= Length(Contorno) then
              SetLength(Contorno, Length(Contorno) * 2);

            Visitati[CX, CY] := True;

            // Salviamo le coordinate reali in millimetri
            Contorno[ContourLen].X := (CX - 2) * RisoluzioneMM;
            Contorno[ContourLen].Y := (H - 1 - (CY - 2)) * RisoluzioneMM;
            // Conserviamo le coordinate pixel originali per l'analisi adattiva
            Contorno[ContourLen].pX := CX;
            Contorno[ContourLen].pY := CY;

            Inc(ContourLen);
            TrovatoVicino := False;

            for D := 0 to 7 do
            begin
              Step := (Dir + D) mod 8;
              NX := CX + DX[Step]; NY := CY + DY[Step];
              if IsEdgePixelFast(NX, NY) and (not Visitati[NX, NY]) then
              begin
                CX := NX; CY := NY;
                Dir := (Step + 5) mod 8;
                TrovatoVicino := True;
                Break;
              end;
            end;
          until not TrovatoVicino;

          if ContourLen > 2 then
          begin
            SetLength(Contorno, ContourLen);

            // Validazione se l'isola è un foro di piazzola
            MinXMM := 1e9; MaxXMM := -1e9; MinYMM := 1e9; MaxYMM := -1e9;
            MinXpixels:=Contorno[0].pX;MaxXpixels:=Contorno[0].pX;MinYpixels:=Contorno[0].pY;MaxYpixels:=Contorno[0].pY;
            for I := 0 to ContourLen - 1 do
            begin
              if Contorno[I].X < MinXMM then MinXMM := Contorno[I].X;
              if Contorno[I].X > MaxXMM then MaxXMM := Contorno[I].X;
              if Contorno[I].Y < MinYMM then MinYMM := Contorno[I].Y;
              if Contorno[I].Y > MaxYMM then MaxYMM := Contorno[I].Y;
              if Contorno[I].pX < MinXpixels then MinXpixels := Contorno[I].pX;
              if Contorno[I].pX > MaxXpixels then MaxXpixels := Contorno[I].pX;
              if Contorno[I].pY < MinYpixels then MinYpixels := Contorno[I].pY;
              if Contorno[I].pY > MaxYpixels then MaxYpixels := Contorno[I].pY;
            end;

            LarghezzaIsola := MaxXMM - MinXMM;
            AltezzaIsola := MaxYMM - MinYMM;

            IsAForo := (LarghezzaIsola > 0.05) and (LarghezzaIsola <= DiametroMassimoForoMM) and
                       (AltezzaIsola > 0.05) and (AltezzaIsola <= DiametroMassimoForoMM) and
                       (Abs(LarghezzaIsola - AltezzaIsola) < (RisoluzioneMM * 2.0));

            if IsAForo then
            begin
              IsAForo := (ColoreContornoPiazzola.Red > 50000) and
                         (ColoreContornoPiazzola.Green < 15000) and
                         (ColoreContornoPiazzola.Blue < 15000);
              if IsAForo = false then
              begin
                ColoreCentroPiazzola:=ColorGrid[(MinXpixels+MaxXpixels) div 2, (MinYpixels+MaxYpixels) div 2];
                IsAForo := (ColoreCentroPiazzola.Red > 50000) and
                           (ColoreCentroPiazzola.Green < 15000) and
                           (ColoreCentroPiazzola.Blue < 15000);
              end;

            end;

            // Se NON è un foro, eseguiamo l'espansione e salviamo l'isola
            if not IsAForo then
            begin
              if IsoleCount >= Length(ElencoIsole) then
                SetLength(ElencoIsole, Length(ElencoIsole) * 2);

              SetLength(ElencoIsole[IsoleCount].PuntiOffset, ContourLen);
              ElencoIsole[IsoleCount].ContourLen := ContourLen;

              // --- Logica Adattiva Ottimizzata ---
              // Calcoliamo lo spostamento massimo sicuro basandoci sulla griglia esistente
              // --- Logica Adattiva Blindata e Precisa ---
              b := estensionePisteMM;
              a := 0.00;

              // Avanziamo a passi di un pixel (RisoluzioneMM) per essere fulminei
              // Usiamo una frazione (es. la metà) se si desidera una precisione sub-pixel,
              // ma RisoluzioneMM è la scelta ottimale per non sovrapporsi mai.
              PassoRaggio := RisoluzioneMM;

              while a < b do
              begin
                // Incrementiamo il raggio per il test successivo
                a := a + PassoRaggio;
                if a > b then a := b;

                TrovatoVicino := False; // Flag di collisione

                // CONTROLLO TOTALE: Scansioniamo OGNI singolo punto del contorno
                for I := 0 to ContourLen - 1 do
                begin
                  if I = 0 then P1 := Contorno[ContourLen - 1] else P1 := Contorno[I - 1];
                  P2 := Contorno[I];
                  if I = ContourLen - 1 then P3 := Contorno[0] else P3 := Contorno[I + 1];

                  // Calcola la posizione teorica espansa per questo punto
                  P3 := CalcolaPuntoOffset(P1, P2, P3, RaggioOffset + a);

                  // Conversione Millimetri -> Pixel
                  aa := 2 + Round(P3.X / RisoluzioneMM);
                  bb := (H - 1) - Round(P3.Y / RisoluzioneMM) + 2;

                  // Controllo collisione rigoroso sulla griglia
                  if (aa >= 0) and (aa < PadW) and (bb >= 0) and (bb < PadH) then
                  begin
                    if not Grid2[aa, bb] then
                    begin
                      TrovatoVicino := True; // Collisione rilevata!
                      Break;
                    end;
                  end else begin
                    TrovatoVicino := True; // Fuori dai limiti del PCB
                    Break;
                  end;
                end;

                // Se questo step ha causato una collisione, indietreggiamo allo step sicuro precedente e usciamo
                if TrovatoVicino then
                begin
                  a := a - PassoRaggio;
                  if a < 0 then a := 0;
                  Break;
                end;

                // Se abbiamo raggiunto il limite massimo richiesto dall'utente, fermiamo il while
                if a = b then Break;
              end;

              // Salviamo il raggio finale massimo calcolato per questa isola
              ElencoIsole[IsoleCount].aa := a;

              // Generiamo i punti di offset definitivi e marchiamo l'area occupata in Grid2
              for I := 0 to ContourLen - 1 do
              begin
                if I = 0 then P1 := Contorno[ContourLen - 1] else P1 := Contorno[I - 1];
                P2 := Contorno[I];
                if I = ContourLen - 1 then P3 := Contorno[0] else P3 := Contorno[I + 1];

                ElencoIsole[IsoleCount].PuntiOffset[I] := CalcolaPuntoOffset(P1, P2, P3, RaggioOffset + a);

                // "Consumiamo" lo spazio nella griglia per bloccare le isole successive
                aa := 2 + Round(ElencoIsole[IsoleCount].PuntiOffset[I].X / RisoluzioneMM);
                bb := (H - 1) - Round(ElencoIsole[IsoleCount].PuntiOffset[I].Y / RisoluzioneMM) + 2;

                if (aa >= 0) and (aa < PadW) and (bb >= 0) and (bb < PadH) then
                  Grid2[aa, bb] := False;
              end;

              ElencoIsole[IsoleCount].StartPt := ElencoIsole[IsoleCount].PuntiOffset[0];
              Inc(IsoleCount);

            end;
          end;
        end;
      end;
    end;

    // Nota: Tutta la seconda scansione che era presente a pagina 4 e 5 è stata eliminata.

    // 2️⃣ FASE: GENERAZIONE INTESTAZIONE G-CODE
    LineeGCode.Add('G21 ; Unita in millimetri');
    LineeGCode.Add('G90 ; Coordinate assolute');
    LineeGCode.Add(Format('G0 Z%.3f F1000 ; Quota di sicurezza iniziale', [ZSicura]));
    LineeGCode.Add('M03 ; Attiva mandrino');
    LineeGCode.Add('; =============================================');
    LineeGCode.Add(';  FASE: INCISIONE TRACCIATI OTTIMIZZATI (TSP)');
    LineeGCode.Add('; =============================================');

    // 3️⃣ FASE: ORDINAMENTO GREEDY (NEAREST NEIGHBOR) E SCRITTURA PERCORSO
    if IsoleCount > 0 then
    begin
      SetLength(IsoleVisitateTSP, IsoleCount);
      for I := 0 to IsoleCount - 1 do IsoleVisitateTSP[I] := False;

      // Partiamo dalla Home (X0, Y0)
      CurrX := 0.0;
      CurrY := 0.0;

      for I := 0 to IsoleCount - 1 do
      begin
        DistMin := 1e12;
        IdxProssimo := -1;

        // Cerca l'isola non visitata più vicina alla posizione attuale della fresa
        for J := 0 to IsoleCount - 1 do
        begin
          if not IsoleVisitateTSP[J] then
          begin
            // Distanza euclidea al quadrato (evitiamo la radice quadrata sqrt per velocità)
            DistAttuale := Sqr(ElencoIsole[J].StartPt.X - CurrX) + Sqr(ElencoIsole[J].StartPt.Y - CurrY);
            if DistAttuale < DistMin then
            begin
              DistMin := DistAttuale;
              IdxProssimo := J;
            end;
          end;
        end;

        // Se troviamo la prossima isola, la incidiamo
        if IdxProssimo <> -1 then
        begin
          IsoleVisitateTSP[IdxProssimo] := True;
          IsolaCorrente := ElencoIsole[IdxProssimo];
          ContourLen := IsolaCorrente.ContourLen;

          // Movimento in rapido verso il primo punto dell'isola selezionata
          LineeGCode.Add(Format('G0 X%.3f Y%.3f ; Spostamento rapido ottimizzato', [IsolaCorrente.StartPt.X, IsolaCorrente.StartPt.Y]));
          LineeGCode.Add(Format('G1 Z%.3f F%d', [ZIncisione, FeedRate]));

          // Generazione tracciato interno (Archi G2/G3 o Linee G1)
          IdxCorrente := 0;
          while IdxCorrente < ContourLen - (PassoCampione * 2) do
          begin
            P1 := IsolaCorrente.PuntiOffset[IdxCorrente];
            P2 := IsolaCorrente.PuntiOffset[IdxCorrente + PassoCampione];
            P3 := IsolaCorrente.PuntiOffset[IdxCorrente + (PassoCampione * 2)];
            Raggio := TryGetArcRadius(P1, P2, P3, IsCW);

            if (Raggio > (SogliaToleranzaArco * PassoCampione)) and (Raggio < 50.0) then
            begin
              if IsCW then
                LineeGCode.Add(Format('G2 X%.3f Y%.3f R%.3f', [P3.X, P3.Y, Raggio]))
              else
                LineeGCode.Add(Format('G3 X%.3f Y%.3f R%.3f', [P3.X, P3.Y, Raggio]));
              IdxCorrente := IdxCorrente + (PassoCampione * 2);
            end else begin
              LineeGCode.Add(Format('G1 X%.3f Y%.3f', [P2.X, P2.Y]));
              IdxCorrente := IdxCorrente + PassoCampione;
            end;
          end;

          while IdxCorrente < ContourLen do
          begin
            LineeGCode.Add(Format('G1 X%.3f Y%.3f', [IsolaCorrente.PuntiOffset[IdxCorrente].X, IsolaCorrente.PuntiOffset[IdxCorrente].Y]));
            Inc(IdxCorrente);
          end;

          // Chiusura isola e risalita a quota sicura

          LineeGCode.Add(Format('G1 X%.3f Y%.3f ; Sigillo', [IsolaCorrente.StartPt.X, IsolaCorrente.StartPt.Y]));
          LineeGCode.Add(Format('G0 Z%.3f', [ZSicura]));
          // Aggiorna la posizione attuale della fresa con l'ultimo punto lavorato
          CurrX := IsolaCorrente.StartPt.X;
          CurrY := IsolaCorrente.StartPt.Y;
        end;
      end;
    end;
    // 4️⃣ FASE: CHIUSURA PROGRAMMA
    LineeGCode.Add('M5 ; Arresto mandrino definitivo');
    LineeGCode.Add('G0 X0 Y0 ; Ritorno Home macchina');
//    LineeGCode.Add('M30 ; Fine del programma');
    Result := LineeGCode.Text;
  finally
    LineeGCode.Free;
    IntfImg.Free;
    Bmp.Free;
    Pic.Free;
    // Pulizia array dinamici record
    for I := 0 to IsoleCount - 1 do  ElencoIsole[I].PuntiOffset := nil;
    ElencoIsole := nil;
    IsoleVisitateTSP := nil;
  end;
end;

end.
