unit LaserGCodeGenerator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math, FPImage, FPCanvas, FPReadPNG, FPReadBMP, FPReadJPEG;

type
  TLaserProgressProc = procedure(Percent: Integer) of object;

{**
 * Genera una stringa G-Code per incisione laser raster da un'immagine.
 * L'immagine viene riscalata per corrispondere esattamente alle dimensioni
 * fisiche richieste in base allo spot del laser.
 *
 * @param NomeFile           Percorso del file immagine (PNG, BMP, JPG)
 * @param PotenzaMax         Potenza massima laser (es. 255 o 1000)
 * @param PotenzaMin         Potenza minima laser (es. 0)
 * @param LarghezzaMM        Larghezza desiderata dell'incisione in mm (es. 100.0)
 * @param SpotDiameterMM     Diametro spot/fascio del laser in mm (es. 0.08 o 0.1)
 * @param FeedRateXY         Velocità di lavoro/incisione in mm/min (es. 1500)
 * @param FeedRateRapido     Velocità spostamenti rapidi in mm/min (es. 3000)
 * @param Invertita          True per invertire i colori (negativo)
 * @return Stringa contenente lo script G-Code
 *}
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
 ProgressCallback: TLaserProgressProc = nil
): string;

implementation

// Seleziona il reader idoneo in base all'estensione del file
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

// Ridimensiona l'immagine sorgente alle nuove dimensioni in pixel usando il ricampionamento bilineare
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

      // Interpolazione bilineare per ciascun canale di colore
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
  ProgressCallback: TLaserProgressProc = nil
): string;
var
  a:integer;
  OriginalImg, ResizedImg: TFPCustomImage;
  Reader: TFPCustomImageReader;
  GCode: TStringList;
  TargetWidthPX, TargetHeightPX: Integer;
  AltezzaMM: Double;
  X, Y: Integer;
  Color: TFPColor;
  Grayscale: Double;
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
    // 1. Calcolo del numero necessario di pixel in base allo Spot Laser
    TargetWidthPX := Max(2, Round(LarghezzaMM / SpotDiameterMM));

    // Mantiene le proporzioni originali dell'immagine (Aspect Ratio)
    TargetHeightPX := Max(2, Round((OriginalImg.Height / OriginalImg.Width) * TargetWidthPX));
    AltezzaMM := TargetHeightPX * SpotDiameterMM;

    // 2. Ridimensionamento dell'immagine in memoria
    ResizedImg := RidimensionaImmagine(OriginalImg, TargetWidthPX, TargetHeightPX);

    try
      // Header del G-Code
      GCode.Add(';LaserPicture');
      GCode.Add('; --- G-CODE GENERATO PER INCISIONE LASER ---');
     // GCode.Add('; Immagine originale: ' + ExtractFileName(NomeFile));
      GCode.Add(Format('; Dimensioni originali: %d x %d px', [OriginalImg.Width, OriginalImg.Height]));
      GCode.Add(Format('; Griglia di lavoro: %d x %d px', [TargetWidthPX, TargetHeightPX]));
      GCode.Add(Format('; Dimensione Incisione: %.2f x %.2f mm', [LarghezzaMM, AltezzaMM]));
      GCode.Add(Format('; Spot Laser (Passo): %.3f mm', [SpotDiameterMM]));
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
        // Scansione riga per riga dall'alto verso il basso
        for Y := 0 to TargetHeightPX - 1 do
        begin
          // Calcolo coordinata Y (0,0 nell'angolo in basso a sinistra)
          CurrentY := (TargetHeightPX - 1 - Y) * SpotDiameterMM;

          // Posizionamento rapido all'inizio della nuova riga
          GCode.Add(Format('G0 X0.000 Y%.3f', [CurrentY]));

          for X := 0 to TargetWidthPX - 1 do
          begin
            CurrentX := X * SpotDiameterMM;
            Color := ResizedImg.Colors[X, Y];

            // Calcolo luminanza standard (0.0 = Nero, 1.0 = Bianco)
            Grayscale := (0.299 * (Color.Red / 65535.0)) +
                         (0.587 * (Color.Green / 65535.0)) +
                         (0.114 * (Color.Blue / 65535.0));

            if Invertita then
              Grayscale := 1.0 - Grayscale;

            // Pixel scuro = Potenza Laser maggiore
            Power := Round(PotenzaMin + (1.0 - Grayscale) * (PotenzaMax - PotenzaMin));

            if Power > PotenzaMin then
            begin
              if not LaserOn then
              begin
                GCode.Add(Format('G1 F%.1f', [FeedRateXY]));
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
          end;

          // Spegne il laser a fine riga
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

      // Footer del G-Code
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
