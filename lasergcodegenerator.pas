unit LaserGCodeGenerator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math, FPImage, FPCanvas, FPReadPNG, FPReadBMP, FPReadJPEG;

type
  TLaserProgressProc = procedure(Percent: Integer) of object;

function GeneraGCodeLaser(
 const Immagine: TMemoryStream;
 const PotenzaMax: Integer;
 const PotenzaMin: Integer;
 const LarghezzaMM: Double;
 const SpotDiameterMM: Double;
 const FeedRateXY: Double;
 const FeedRateRapido: Double;
 const Invertita: Boolean;
 const numPasses: integer=1;
 const Gamma: Double = 1.5;
 ProgressCallback: TLaserProgressProc = nil
): string;

function GeneraGCodeLaserCrosshatch(
 const Immagine: TMemoryStream;
 const PotenzaMax: Integer;
 const PotenzaMin: Integer;
 const LarghezzaMM: Double;
 const SpotDiameterMM: Double;
 const FeedRateXY: Double;
 const FeedRateRapido: Double;
 const Invertita: Boolean;
 const numPasses: integer=1;
 const AngoloPrimoPassaggio: Integer = 45;
 const Gamma: Double = 1.5;
 ProgressCallback: TLaserProgressProc = nil
): string;

implementation

function RegistraReaderDaEstensione(const FilePath: string): TFPCustomImageReader;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FilePath));
  if (Ext = '.png') then
    Result := TFPReaderPNG.Create
  else if (Ext = '.bmp') then
    Result := TFPReaderBMP.Create
  else if (Ext = '.jpg') or (Ext = '.jpeg') then
    Result := TFPReaderJPEG.Create
  else
    Result := nil;
end;

function RidimensionaImmagine(Source: TFPCustomImage; NewWidth, NewHeight: Integer): TFPCustomImage;
var
  X, Y: Integer;
  OldX, OldY: Double;
  X1, Y1, X2, Y2: Integer;
  Rx, Ry: Double;
  C00, C10, C01, C11: TFPColor;
  Red, Green, Blue: Word;
begin
  Result := TFPMemoryImage.Create(NewWidth, NewHeight);

  for Y := 0 to NewHeight - 1 do
  begin
    if NewHeight > 1 then
      OldY := Y * (Source.Height - 1) / (NewHeight - 1)
    else
      OldY := 0;
    Y1 := Trunc(OldY);
    Y2 := Y1 + 1;
    if Y2 >= Source.Height then Y2 := Source.Height - 1;
    Ry := OldY - Y1;

    for X := 0 to NewWidth - 1 do
    begin
      if NewWidth > 1 then
        OldX := X * (Source.Width - 1) / (NewWidth - 1)
      else
        OldX := 0;
      X1 := Trunc(OldX);
      X2 := X1 + 1;
      if X2 >= Source.Width then X2 := Source.Width - 1;
      Rx := OldX - X1;

      C00 := Source.Colors[X1, Y1];
      C10 := Source.Colors[X2, Y1];
      C01 := Source.Colors[X1, Y2];
      C11 := Source.Colors[X2, Y2];

      Red := Round((1 - Rx) * (1 - Ry) * C00.Red + Rx * (1 - Ry) * C10.Red + (1 - Rx) * Ry * C00.Red + Rx * Ry * C11.Red);
      Green := Round((1 - Rx) * (1 - Ry) * C00.Green + Rx * (1 - Ry) * C10.Green + (1 - Rx) * Ry * C00.Green + Rx * Ry * C11.Green);
      Blue := Round((1 - Rx) * (1 - Ry) * C00.Blue + Rx * (1 - Ry) * C10.Blue + (1 - Rx) * Ry * C00.Blue + Rx * Ry * C11.Blue);

      Result.Colors[X, Y] := FPColor(Red, Green, Blue);
    end;
  end;
end;

function GeneraGCodeLaser(
  const Immagine: TMemoryStream;
  const PotenzaMax: Integer;
  const PotenzaMin: Integer;
  const LarghezzaMM: Double;
  const SpotDiameterMM: Double;
  const FeedRateXY: Double;
  const FeedRateRapido: Double;
  const Invertita: Boolean;
  const numPasses: integer=1;
  const Gamma: Double = 1.5;
  ProgressCallback: TLaserProgressProc = nil
): string;
var
  a:integer;
  OriginalImg, ResizedImg: TFPCustomImage;
  GCode: TStringList;
  TargetWidthPX, TargetHeightPX: Integer;
  AltezzaMM: Double;
  X, Y, StartX, EndX, StepX: Integer;
  Color: TFPColor;
  Grayscale, Intensity: Double;
  Power: Integer;
  CurrentX, CurrentY: Double;
  LaserOn: Boolean;
  RowsTotal, RowsDone, LastReportedPercent, Percent: Integer;
begin
  Result := '';

  if LarghezzaMM <= 0 then
    raise Exception.Create('Width must be more than 0.');

  if SpotDiameterMM <= 0 then
    raise Exception.Create('Laser spot diameter must be more than 0.');

  OriginalImg := TFPMemoryImage.Create(0, 0);
  GCode := TStringList.Create;
  try
    Immagine.Position:=0;
    OriginalImg.LoadFromStream(Immagine);
  except
    raise Exception.Create('File format unsupported or corrupted. Use PNG, BMP o JPG.');
  end;

  try
    TargetWidthPX := Max(2, Round(LarghezzaMM / SpotDiameterMM));
    TargetHeightPX := Max(2, Round((OriginalImg.Height / OriginalImg.Width) * TargetWidthPX));
    AltezzaMM := TargetHeightPX * SpotDiameterMM;

    ResizedImg := RidimensionaImmagine(OriginalImg, TargetWidthPX, TargetHeightPX);

    try
      GCode.Add(';LaserPicture');
      GCode.Add('; --- G-CODE GENERATO PER INCISIONE LASER BIDIREZIONALE CON CURVA GAMMA ---');
      GCode.Add(Format('; Dimensioni originali: %d x %d px', [OriginalImg.Width, OriginalImg.Height]));
      GCode.Add(Format('; Griglia di lavoro: %d x %d px', [TargetWidthPX, TargetHeightPX]));
      GCode.Add(Format('; Dimensione Incisione: %.2f x %.2f mm', [LarghezzaMM, AltezzaMM]));
      GCode.Add(Format('; Spot Laser (Passo): %.3f mm', [SpotDiameterMM]));
      GCode.Add(Format('; Fattore Gamma applicato: %.2f', [Gamma]));
      GCode.Add('G21 ; Unita di misura in mm');
      GCode.Add('G90 ; Coordinate assolute');
      GCode.Add('M5  ; Spegne il laser');
      GCode.Add(Format('G0 F%.1f ; Imposta velocità rapida', [FeedRateRapido]));

      RowsTotal := Max(1, numPasses * TargetHeightPX);
      RowsDone := 0;
      LastReportedPercent := -1;
      if Assigned(ProgressCallback) then ProgressCallback(0);

      LaserOn := False;
      for a := 1 to numPasses do
      begin
        GCode.Add(';Pass num.'+inttostr(a));
        
        for Y := 0 to TargetHeightPX - 1 do
        begin
          CurrentY := (TargetHeightPX - 1 - Y) * SpotDiameterMM;

          if (Y mod 2 = 0) then
          begin
            StartX := 0;
            EndX := TargetWidthPX - 1;
            StepX := 1;
          end
          else
          begin
            StartX := TargetWidthPX - 1;
            EndX := 0;
            StepX := -1;
          end;

          CurrentX := StartX * SpotDiameterMM;
          GCode.Add(Format('G0 X%.3f Y%.3f', [CurrentX, CurrentY]));

          X := StartX;
          while True do
          begin
            CurrentX := X * SpotDiameterMM;
            Color := ResizedImg.Colors[X, Y];

            Grayscale := (0.299 * (Color.Red / 65535.0)) +
                         (0.587 * (Color.Green / 65535.0)) +
                         (0.114 * (Color.Blue / 65535.0));

            if Invertita then
              Grayscale := 1.0 - Grayscale;

            Intensity := 1.0 - Grayscale;
            if (Gamma <> 1.0) and (Intensity > 0.0) then
              Intensity := Math.Power(Intensity, Gamma);

            Power := Round(PotenzaMin + Intensity * (PotenzaMax - PotenzaMin));
            if Power >= PotenzaMin then
            begin
              if not LaserOn then
              begin
                GCode.Add(Format('G1 F%.1f', [FeedRateXY]));
                GCode.Add('M4 ; Attiva laser in modalita dinamica');
                LaserOn := True;
              end;
              GCode.Add(Format('G1 X%.3f S%d', [CurrentX, Power]));
            end
            else
            begin
              if LaserOn then
              begin
                GCode.Add('M5');
                LaserOn := False;
              end;
              GCode.Add(Format('G0 X%.3f', [CurrentX]));
            end;

            if X = EndX then Break;
            X := X + StepX;
          end;

          if LaserOn then
          begin
            GCode.Add('M5');
            LaserOn := False;
          end;

          Inc(RowsDone);
          if Assigned(ProgressCallback) then
          begin
            Percent := EnsureRange(Round(100 * RowsDone / RowsTotal), 0, 100);
            if Percent <> LastReportedPercent then
            begin
              LastReportedPercent := Percent;
              ProgressCallback(Percent);
            end;
          end;
        end;
      end;

      GCode.Add('M5 ; Spegne il laser');
      GCode.Add('G0 X0 Y0 ; Torna all''origine');
      GCode.Add('; --- FINE G-CODE ---');
      GCode.Add(';-LaserPicture');
      Result := GCode.Text;

    finally
      ResizedImg.Free;
    end;

  finally
    OriginalImg.Free;
    GCode.Free;
  end;
  if Assigned(ProgressCallback) then ProgressCallback(100);
end;

function GeneraGCodeLaserCrosshatch(
  const Immagine: TMemoryStream;
  const PotenzaMax: Integer;
  const PotenzaMin: Integer;
  const LarghezzaMM: Double;
  const SpotDiameterMM: Double;
  const FeedRateXY: Double;
  const FeedRateRapido: Double;
  const Invertita: Boolean;
  const numPasses: integer=1;
  const AngoloPrimoPassaggio: Integer = 45;
  const Gamma: Double = 1.5;
  ProgressCallback: TLaserProgressProc = nil
): string;
var
  OriginalImg, ResizedImg: TFPCustomImage;
  GCode: TStringList;
  TargetWidthPX, TargetHeightPX: Integer;
  AltezzaMM, PassiDiagonali: Double;
  X, Y, PassiCount, i, PxX, PxY, PassIdx: Integer;
  StartX, EndX, StepX, StartY, EndY, StepY: Integer;
  Color: TFPColor;
  Grayscale, Intensity, Distanza, Proiezione, posX, posY: Double;
  Power: Integer;
  LaserOn: Boolean;
  UnitsPerPass, RowsTotal, RowsDone, LastReportedPercent, Percent: Integer;
begin
  Result := '';

  if LarghezzaMM <= 0 then
    raise Exception.Create('Width must be more than 0.');

  if SpotDiameterMM <= 0 then
    raise Exception.Create('Laser spot diameter must be more than 0.');

  OriginalImg := TFPMemoryImage.Create(0, 0);
  GCode := TStringList.Create;
  try
    Immagine.Position := 0;
    OriginalImg.LoadFromStream(Immagine);
  except
    raise Exception.Create('File format unsupported or corrupted. Use PNG, BMP o JPG.');
  end;

  try
    TargetWidthPX := Max(2, Round(LarghezzaMM / SpotDiameterMM));
    TargetHeightPX := Max(2, Round((OriginalImg.Height / OriginalImg.Width) * TargetWidthPX));
    AltezzaMM := TargetHeightPX * SpotDiameterMM;

    ResizedImg := RidimensionaImmagine(OriginalImg, TargetWidthPX, TargetHeightPX);

    try
      GCode.Add(';LaserPicture');
      GCode.Add('; CROSSHATCH MODE - BIDIRECTIONAL WITH GAMMA CURVE');
      GCode.Add('; --- G-CODE GENERATO PER INCISIONE LASER CROSSHATCH ---');
      GCode.Add(Format('; Dimensioni area: %.2f x %.2f mm', [LarghezzaMM, AltezzaMM]));
      GCode.Add(Format('; Configurazione setup: Angolo primario %d gradi', [AngoloPrimoPassaggio]));
      GCode.Add(Format('; Fattore Gamma applicato: %.2f', [Gamma]));
      GCode.Add('G21 ; Unita di misura in mm');
      GCode.Add('G90 ; Coordinate assolute');
      GCode.Add('M5  ; Spegne il laser');
      GCode.Add(Format('G0 F%.1f ; Velocita rapidi', [FeedRateRapido]));

      LaserOn := False;

      if AngoloPrimoPassaggio = 0 then
        UnitsPerPass := TargetHeightPX + TargetWidthPX
      else
      begin
        PassiDiagonali := (LarghezzaMM + AltezzaMM) / SpotDiameterMM;
        UnitsPerPass := 2 * (Round(PassiDiagonali) + 1);
      end;
      RowsTotal := Max(1, numPasses * UnitsPerPass);
      RowsDone := 0;
      LastReportedPercent := -1;
      if Assigned(ProgressCallback) then ProgressCallback(0);

      for PassIdx := 1 to numPasses do
      begin
        GCode.Add(';Pass num.'+IntToStr(PassIdx));

        // ==========================================
        // PASSAGGIO 1: Orientamento Primario (0° o 45°)
        // ==========================================
        if AngoloPrimoPassaggio = 0 then
        begin
          GCode.Add('; --- PASSAGGIO 1: SCANSIONE ORIZZONTALE (0 GRADI) ---');
          for Y := 0 to TargetHeightPX - 1 do
          begin
            posY := (TargetHeightPX - 1 - Y) * SpotDiameterMM;

            if (Y mod 2 = 0) then
            begin
              StartX := 0; EndX := TargetWidthPX - 1; StepX := 1;
            end
            else
            begin
              StartX := TargetWidthPX - 1; EndX := 0; StepX := -1;
            end;

            posX := StartX * SpotDiameterMM;
            GCode.Add(Format('G0 X%.3f Y%.3f', [posX, posY]));

            X := StartX;
            while True do
            begin
              posX := X * SpotDiameterMM;
              Color := ResizedImg.Colors[X, Y];
              Grayscale := (0.299 * (Color.Red / 65535.0)) + (0.587 * (Color.Green / 65535.0)) + (0.114 * (Color.Blue / 65535.0));
              if Invertita then Grayscale := 1.0 - Grayscale;
              
              Intensity := 1.0 - Grayscale;
              if (Gamma <> 1.0) and (Intensity > 0.0) then
                Intensity := Math.Power(Intensity, Gamma);

              Power := Round(PotenzaMin + Intensity * (PotenzaMax - PotenzaMin));

              if Power >= PotenzaMin then
              begin
                if not LaserOn then
                begin
                  GCode.Add(Format('G1 F%.1f', [FeedRateXY]));
                  GCode.Add('M4 ; Attiva laser in modalita dinamica');
                  LaserOn := True;
                end;
                GCode.Add(Format('G1 X%.3f S%d', [posX, Power]));
              end
              else
              begin
                if LaserOn then begin GCode.Add('M5'); LaserOn := False; end;
                GCode.Add(Format('G0 X%.3f', [posX]));
              end;

              if X = EndX then Break;
              X := X + StepX;
            end;
            if LaserOn then begin GCode.Add('M5'); LaserOn := False; end;
            Inc(RowsDone);
            if Assigned(ProgressCallback) then
            begin
              Percent := EnsureRange(Round(100 * RowsDone / RowsTotal), 0, 100);
              if Percent <> LastReportedPercent then
              begin
                LastReportedPercent := Percent;
                ProgressCallback(Percent);
              end;
            end;
          end;
        end
        else
        begin
          GCode.Add('; --- PASSAGGIO 1: SCANSIONE DIAGONALE INCLINATA (45 GRADI) ---');
          PassiDiagonali := (LarghezzaMM + AltezzaMM) / SpotDiameterMM;
          PassiCount := Round(PassiDiagonali);
          
          for i := 0 to PassiCount do
          begin
            Distanza := i * SpotDiameterMM;
            GCode.Add('; Riga diagonale /');
            
            if (i mod 2 = 0) then
            begin
              StartX := 0; EndX := TargetWidthPX - 1; StepX := 1;
            end
            else
            begin
              StartX := TargetWidthPX - 1; EndX := 0; StepX := -1;
            end;

            X := StartX;
            while True do
            begin
              posX := X * SpotDiameterMM;
              posY := Distanza - posX; 
              
              if (posY >= 0) and (posY <= AltezzaMM) then
              begin
                PxX := X;
                PxY := TargetHeightPX - 1 - Round(posY / SpotDiameterMM);
                if PxY < 0 then PxY := 0;
                if PxY >= TargetHeightPX then PxY := TargetHeightPX - 1;

                Color := ResizedImg.Colors[PxX, PxY];
                Grayscale := (0.299 * (Color.Red / 65535.0)) + (0.587 * (Color.Green / 65535.0)) + (0.114 * (Color.Blue / 65535.0));
                if Invertita then Grayscale := 1.0 - Grayscale;
                
                Intensity := 1.0 - Grayscale;
                if (Gamma <> 1.0) and (Intensity > 0.0) then
                  Intensity := Math.Power(Intensity, Gamma);

                Power := Round(PotenzaMin + Intensity * (PotenzaMax - PotenzaMin));

                if not LaserOn then
                begin
                  GCode.Add(Format('G0 X%.3f Y%.3f', [posX, posY]));
                  if Power >= PotenzaMin then
                  begin
                    GCode.Add(Format('G1 F%.1f', [FeedRateXY]));
                    GCode.Add('M4 ; Attiva laser in modalita dinamica');
                    LaserOn := True;
                    GCode.Add(Format('G1 X%.3f Y%.3f S%d', [posX, posY, Power]));
                  end;
                end
                else
                begin
                  if Power >= PotenzaMin then
                    GCode.Add(Format('G1 X%.3f Y%.3f S%d', [posX, posY, Power]))
                  else
                  begin
                    GCode.Add('M5');
                    LaserOn := False;
                    GCode.Add(Format('G0 X%.3f Y%.3f', [posX, posY]));
                  end;
                end;
              end;

              if X = EndX then Break;
              X := X + StepX;
            end;
            if LaserOn then begin GCode.Add('M5'); LaserOn := False; end;
            Inc(RowsDone);
            if Assigned(ProgressCallback) then
            begin
              Percent := EnsureRange(Round(100 * RowsDone / RowsTotal), 0, 100);
              if Percent <> LastReportedPercent then
              begin
                LastReportedPercent := Percent;
                ProgressCallback(Percent);
              end;
            end;
          end;
        end;

        // ==========================================
        // PASSAGGIO 2: Orientamento Incrociato (90° o 135°)
        // ==========================================
        if AngoloPrimoPassaggio = 0 then
        begin
          GCode.Add('; --- PASSAGGIO 2: SCANSIONE VERTICALE INCROCIATA (90 GRADI) ---');
          for X := 0 to TargetWidthPX - 1 do
          begin
            posX := X * SpotDiameterMM;

            if (X mod 2 = 0) then
            begin
              StartY := TargetHeightPX - 1; EndY := 0; StepY := -1;
            end
            else
            begin
              StartY := 0; EndY := TargetHeightPX - 1; StepY := 1;
            end;

            posY := (TargetHeightPX - 1 - StartY) * SpotDiameterMM;
            GCode.Add(Format('G0 X%.3f Y%.3f', [posX, posY]));

            Y := StartY;
            while True do
            begin
              posY := (TargetHeightPX - 1 - Y) * SpotDiameterMM;
              Color := ResizedImg.Colors[X, Y];
              Grayscale := (0.299 * (Color.Red / 65535.0)) + (0.587 * (Color.Green / 65535.0)) + (0.114 * (Color.Blue / 65535.0));
              if Invertita then Grayscale := 1.0 - Grayscale;
              
              Intensity := 1.0 - Grayscale;
              if (Gamma <> 1.0) and (Intensity > 0.0) then
                Intensity := Math.Power(Intensity, Gamma);

              Power := Round(PotenzaMin + Intensity * (PotenzaMax - PotenzaMin));

              if Power >= PotenzaMin then
              begin
                if not LaserOn then begin
                  GCode.Add(Format('G1 F%.1f', [FeedRateXY]));
                  GCode.Add('M4 ; Attiva laser in modalita dinamica');
                  LaserOn := True;
                end;
                GCode.Add(Format('G1 Y%.3f S%d', [posY, Power]));
              end
              else
              begin
                if LaserOn then begin GCode.Add('M5'); LaserOn := False; end;
                GCode.Add(Format('G0 Y%.3f', [posY]));
              end;

              if Y = EndY then Break;
              Y := Y + StepY;
            end;
            if LaserOn then begin GCode.Add('M5'); LaserOn := False; end;
            Inc(RowsDone);
            if Assigned(ProgressCallback) then
            begin
              Percent := EnsureRange(Round(100 * RowsDone / RowsTotal), 0, 100);
              if Percent <> LastReportedPercent then
              begin
                LastReportedPercent := Percent;
                ProgressCallback(Percent);
              end;
            end;
          end;
        end
        else
        begin
          GCode.Add('; --- PASSAGGIO 2: SCANSIONE DIAGONALE INCROCIATA (135 GRADI) ---');
          PassiDiagonali := (LarghezzaMM + AltezzaMM) / SpotDiameterMM;
          PassiCount := Round(PassiDiagonali);
          
          for i := 0 to PassiCount do
          begin
            Proiezione := (i * SpotDiameterMM) - AltezzaMM;
            GCode.Add('; Riga diagonale ');
            
            if (i mod 2 = 0) then
            begin
              StartX := 0; EndX := TargetWidthPX - 1; StepX := 1;
            end
            else
            begin
              StartX := TargetWidthPX - 1; EndX := 0; StepX := -1;
            end;

            X := StartX;
            while True do
            begin
              posX := X * SpotDiameterMM;
              posY := posX - Proiezione;
              
              if (posY >= 0) and (posY <= AltezzaMM) then
              begin
                PxX := X;
                PxY := TargetHeightPX - 1 - Round(posY / SpotDiameterMM);
                if PxY < 0 then PxY := 0;
                if PxY >= TargetHeightPX then PxY := TargetHeightPX - 1;

                Color := ResizedImg.Colors[PxX, PxY];
                Grayscale := (0.299 * (Color.Red / 65535.0)) + (0.587 * (Color.Green / 65535.0)) + (0.114 * (Color.Blue / 65535.0));
                if Invertita then Grayscale := 1.0 - Grayscale;
                
                Intensity := 1.0 - Grayscale;
                if (Gamma <> 1.0) and (Intensity > 0.0) then
                  Intensity := Math.Power(Intensity, Gamma);

                Power := Round(PotenzaMin + Intensity * (PotenzaMax - PotenzaMin));

                if not LaserOn then
                begin
                  GCode.Add(Format('G0 X%.3f Y%.3f', [posX, posY]));
                  if Power >= PotenzaMin then
                  begin
                    GCode.Add(Format('G1 F%.1f', [FeedRateXY]));
                    GCode.Add('M4 ; Attiva laser in modalita dinamica');
                    LaserOn := True;
                    GCode.Add(Format('G1 X%.3f Y%.3f S%d', [posX, posY, Power]));
                  end;
                end
                else
                begin
                  if Power >= PotenzaMin then
                    GCode.Add(Format('G1 X%.3f Y%.3f S%d', [posX, posY, Power]))
                  else
                  begin
                    GCode.Add('M5');
                    LaserOn := False;
                    GCode.Add(Format('G0 X%.3f Y%.3f', [posX, posY]));
                  end;
                end;
              end;

              if X = EndX then Break;
              X := X + StepX;
            end;
            if LaserOn then begin GCode.Add('M5'); LaserOn := False; end;
            Inc(RowsDone);
            if Assigned(ProgressCallback) then
            begin
              Percent := EnsureRange(Round(100 * RowsDone / RowsTotal), 0, 100);
              if Percent <> LastReportedPercent then
              begin
                LastReportedPercent := Percent;
                ProgressCallback(Percent);
              end;
            end;
          end;
        end;

      end; // for PassIdx

      GCode.Add('M5 ; Spegne il laser');
      GCode.Add('G0 X0 Y0 ; Torna all''origine');
      GCode.Add('; --- FINE G-CODE ---');
      GCode.Add(';-LaserPicture');
      Result := GCode.Text;

    finally
      ResizedImg.Free;
    end;

  finally
    OriginalImg.Free;
    GCode.Free;
  end;
  if Assigned(ProgressCallback) then ProgressCallback(100);
end;

end.
