unit ImageToGCode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, FPImage, FPCanvas, Graphics, IntfGraphics;

type
  TGCodeParams = record
    FileData: TMemoryStream;          // Percorso file immagine
    WidthMM: Double;           // Larghezza desiderata in mm
    ToolDiameterMM: Double;    // Diametro della fresa in mm
    StepoverRatio: Double;     // Passo laterale (es. 0.35 = 35% del diametro)
    MaxDepthStepMM: Double;    // Profondità massima per singola passata (Slicing)
    ZWhiteMM: Double;          // Profondità al BIANCO (es. 0.0)
    ZBlackMM: Double;          // Profondità al NERO (es. -10.0)
    XYFeedRate: Double;        // Velocità di lavoro (G1) in mm/min
    ZFeedRate: Double;         // Velocità di affondamento Z in mm/min
    RapidFeedRate: Double;     // Velocità degli spostamenti rapidi (G0)
    SafeZ: Double;             // Quota Z di sicurezza
    CrossHatch: Boolean;       // TRUE = Attiva raster incrociato a 45°/135°
  end;

  TGCodeProgressProc = procedure(Percent: Integer) of object;

function ExportImageToGCode(const Params: TGCodeParams; ProgressCallback: TGCodeProgressProc = nil): string;

implementation

type
  TRGBGrid = array of array of Byte; // 0 = Nero, 255 = Bianco

function LoadImageToGrayscale(const FileData: TMemoryStream; out Grid: TRGBGrid; out ImgW, ImgH: Integer): Boolean;
var
  Pic: TPicture;
  Img: TLazIntfImage;
  x, y: Integer;
  C: TFPColor;
  Gray: Byte;
begin
  Result := False;
  ImgW := 0;
  ImgH := 0;

  Pic := TPicture.Create;
  Img := TLazIntfImage.Create(0, 0);
  try
    try
      FileData.Position:=0;;
      Pic.LoadFromStream(FileData);
      if (Pic.Graphic = nil) or Pic.Graphic.Empty then Exit;

      Img.LoadFromBitmap(Pic.Bitmap.Handle, Pic.Bitmap.MaskHandle);
      ImgW := Img.Width;
      ImgH := Img.Height;
      SetLength(Grid, ImgW, ImgH);

      for y := 0 to ImgH - 1 do
      begin
        for x := 0 to ImgW - 1 do
        begin
          C := Img.Colors[x, y];
          Gray := Round((C.red * 0.299 + C.green * 0.587 + C.blue * 0.114) / 256);
          Grid[x, y] := Gray;
        end;
      end;
      Result := True;
    except
      Result := False;
    end;
  finally
    Img.Free;
    Pic.Free;
  end;
end;

function GrayToZTarget(Gray: Byte; ZWhite, ZBlack: Double): Double;
var
  Factor: Double;
begin
  Factor := (255 - Gray) / 255.0;
  Result := ZWhite + (ZBlack - ZWhite) * Factor;
end;

function ExportImageToGCode(const Params: TGCodeParams; ProgressCallback: TGCodeProgressProc = nil): string;
var
  Grid: TRGBGrid;
  ImgW, ImgH: Integer;
  GCodeBuilder: TStringList;

  PixelSizeMM: Double;
  HeightMM: Double;
  StepoverMM: Double;

  TotalDepth: Double;
  NumPasses, Pass: Integer;
  CurrentPassZTarget: Double;

  RowUnitsTotal, RowUnitsDone: Integer;
  LastReportedPercent: Integer;

  FormatSettings: TFormatSettings;

  procedure ReportRowProgress;
  var
    Percent: Integer;
  begin
    Inc(RowUnitsDone);
    if not Assigned(ProgressCallback) then Exit;
    Percent := EnsureRange(Round(100 * RowUnitsDone / RowUnitsTotal), 0, 100);
    if Percent <> LastReportedPercent then
    begin
      LastReportedPercent := Percent;
      ProgressCallback(Percent);
    end;
  end;

  procedure GenerateScanPass(AngleDeg: Double; PassName: string);
  var
    NumDiag, DiagIdx, StepIdx, TotalStepsInDiag: Integer;
    D, StartX, StartY, EndX, EndY: Double;
    RealX, RealY, QueryX, QueryY: Double;
    Px, Py: Integer;
    TargetZ, ActualZ: Double;
    IsFirstPoint: Boolean;
    DiagLength: Double;

    // Per Scansione 0°
    NumLinesY, NumStepsX, iX, iY: Integer;
    StepX, StepY: Double;
  begin
    GCodeBuilder.Add(Format('; --- Direct scan angle: %.1f deg (%s) ---', [AngleDeg, PassName], FormatSettings));
    IsFirstPoint := True;

    // RASTER 0 GRADI (Standard orizzontale)
    if SameValue(AngleDeg, 0.0, 0.1) then
    begin
      NumLinesY := Max(1, Round(HeightMM / StepoverMM));
      NumStepsX := Max(1, Round(Params.WidthMM / StepoverMM));
      StepX := Params.WidthMM / NumStepsX;
      StepY := HeightMM / NumLinesY;

      for iY := 0 to NumLinesY do
      begin
        RealY := iY * StepY;
        for iX := 0 to NumStepsX do
        begin
          if (iY mod 2 = 1) then
            RealX := (NumStepsX - iX) * StepX
          else
            RealX := iX * StepX;

          Px := EnsureRange(Round((RealX / Params.WidthMM) * (ImgW - 1)), 0, ImgW - 1);
          Py := EnsureRange(Round((1.0 - (RealY / HeightMM)) * (ImgH - 1)), 0, ImgH - 1);

          TargetZ := GrayToZTarget(Grid[Px, Py], Params.ZWhiteMM, Params.ZBlackMM);

          if Params.ZBlackMM < Params.ZWhiteMM then
            ActualZ := Max(TargetZ, CurrentPassZTarget)
          else
            ActualZ := Min(TargetZ, CurrentPassZTarget);

          if IsFirstPoint then
          begin
            GCodeBuilder.Add(Format('G0 X%.3f Y%.3f F%.1f', [RealX, RealY, Params.RapidFeedRate], FormatSettings));
            GCodeBuilder.Add(Format('G1 Z%.3f F%.1f', [ActualZ, Params.ZFeedRate], FormatSettings));
            IsFirstPoint := False;
          end
          else
          begin
            GCodeBuilder.Add(Format('G1 X%.3f Y%.3f Z%.3f F%.1f', [RealX, RealY, ActualZ, Params.XYFeedRate], FormatSettings));
          end;
        end;
        ReportRowProgress;
      end;
    end
    else
    // RASTER DIAGONALE (45° o 135°)
    begin
      // Ora StepoverMM è VERO e GIÀ INIZIALIZZATO!
      NumDiag := Max(1, Round((Params.WidthMM + HeightMM) / StepoverMM));

      for DiagIdx := 0 to NumDiag do
      begin
        D := -Params.WidthMM + (DiagIdx * (Params.WidthMM + HeightMM) / NumDiag);

        if D >= 0 then
        begin
          StartX := 0;
          StartY := D;
        end
        else
        begin
          StartX := -D;
          StartY := 0;
        end;

        if (HeightMM - D) <= Params.WidthMM then
        begin
          EndX := HeightMM - D;
          EndY := HeightMM;
        end
        else
        begin
          EndX := Params.WidthMM;
          EndY := Params.WidthMM + D;
        end;

        DiagLength := Hypot(EndX - StartX, EndY - StartY);

        if DiagLength > 0.001 then
        begin
          TotalStepsInDiag := Max(1, Round(DiagLength / StepoverMM));

          for StepIdx := 0 to TotalStepsInDiag do
          begin
            if (DiagIdx mod 2 = 1) then
            begin
              RealX := EndX + (StartX - EndX) * (StepIdx / TotalStepsInDiag);
              RealY := EndY + (StartY - EndY) * (StepIdx / TotalStepsInDiag);
            end
            else
            begin
              RealX := StartX + (EndX - StartX) * (StepIdx / TotalStepsInDiag);
              RealY := StartY + (EndY - StartY) * (StepIdx / TotalStepsInDiag);
            end;

            if SameValue(AngleDeg, 135.0, 0.1) or SameValue(AngleDeg, -45.0, 0.1) then
              QueryX := Params.WidthMM - RealX
            else
              QueryX := RealX;

            QueryY := RealY;

            Px := EnsureRange(Round((QueryX / Params.WidthMM) * (ImgW - 1)), 0, ImgW - 1);
            Py := EnsureRange(Round((1.0 - (QueryY / HeightMM)) * (ImgH - 1)), 0, ImgH - 1);

            TargetZ := GrayToZTarget(Grid[Px, Py], Params.ZWhiteMM, Params.ZBlackMM);

            if Params.ZBlackMM < Params.ZWhiteMM then
              ActualZ := Max(TargetZ, CurrentPassZTarget)
            else
              ActualZ := Min(TargetZ, CurrentPassZTarget);

            if IsFirstPoint then
            begin
              GCodeBuilder.Add(Format('G0 X%.3f Y%.3f F%.1f', [QueryX, QueryY, Params.RapidFeedRate], FormatSettings));
              GCodeBuilder.Add(Format('G1 Z%.3f F%.1f', [ActualZ, Params.ZFeedRate], FormatSettings));
              IsFirstPoint := False;
            end
            else
            begin
              GCodeBuilder.Add(Format('G1 X%.3f Y%.3f Z%.3f F%.1f', [QueryX, QueryY, ActualZ, Params.XYFeedRate], FormatSettings));
            end;
          end;
        end;
        ReportRowProgress;
      end;
    end;

    // Discesa di sicurezza ZSafe a fine passata
    GCodeBuilder.Add(Format('G0 Z%.3f F%.1f', [Params.SafeZ, Params.RapidFeedRate], FormatSettings));
  end;

begin
  Result := '';
  FormatSettings.DecimalSeparator := '.';

  // 1. CARICAMENTO IMMAGINE
  if not LoadImageToGrayscale(Params.FileData, Grid, ImgW, ImgH) then Exit;

  // 2. CALCOLO GEOMETRIE E STEPOVER SUBITO (PRIMA DI TUTTO!)
  PixelSizeMM := Params.WidthMM / ImgW;
  HeightMM := ImgH * PixelSizeMM;

  StepoverMM := Params.ToolDiameterMM * Params.StepoverRatio;
  if StepoverMM <= 0 then StepoverMM := 0.5;

  TotalDepth := Abs(Params.ZBlackMM - Params.ZWhiteMM);
  if (TotalDepth <= 0) or (Params.MaxDepthStepMM <= 0) then
    NumPasses := 1
  else
    NumPasses := Ceil(TotalDepth / Params.MaxDepthStepMM);

  // Stima del numero totale di "righe" di scansione, per riportare l'avanzamento
  if Params.CrossHatch then
    RowUnitsTotal := NumPasses * 2 * (Max(1, Round((Params.WidthMM + HeightMM) / StepoverMM)) + 1)
  else
    RowUnitsTotal := NumPasses * (Max(1, Round(HeightMM / StepoverMM)) + 1);
  if RowUnitsTotal <= 0 then RowUnitsTotal := 1;
  RowUnitsDone := 0;
  LastReportedPercent := -1;
  if Assigned(ProgressCallback) then ProgressCallback(0);

  GCodeBuilder := TStringList.Create;
  try
    // Header G-Code
    GCodeBuilder.Add('; Generato da Lazarus ImageToGCode');
    GCodeBuilder.Add('G21 ; Unita in mm');
    GCodeBuilder.Add('G90 ; Posizionamento assoluto');
    GCodeBuilder.Add(Format('G0 Z%.3f F%.1f', [Params.SafeZ, Params.RapidFeedRate], FormatSettings));
    GCodeBuilder.Add(Format('G0 X0 Y0 F%.1f', [Params.RapidFeedRate], FormatSettings));

    // CICLO SLICING PER PASSI DI PROFONDITÀ
    for Pass := 1 to NumPasses do
    begin
      CurrentPassZTarget := Params.ZWhiteMM + (Params.ZBlackMM - Params.ZWhiteMM) * (Pass / NumPasses);

      GCodeBuilder.Add('; =================================================');
      GCodeBuilder.Add(Format('; --- INIZIO STRATO %d/%d (Z Max Strato: %.3f) ---',
        [Pass, NumPasses, CurrentPassZTarget], FormatSettings));
      GCodeBuilder.Add('; =================================================');

      if Params.CrossHatch then
      begin
        // RASTER INCROCIATO: Passata A (+45°) + Passata B (135°)
        GenerateScanPass(45.0, 'Passata Incrociata A');
        GenerateScanPass(135.0, 'Passata Incrociata B');
      end
      else
      begin
        // RASTER STANDARD (0° Parallelo all'asse X)
        GenerateScanPass(0.0, 'Passata Standard');
      end;
    end;

    // Footer - Ritorno in origine in sicurezza
    GCodeBuilder.Add(Format('G0 Z%.3f F%.1f', [Params.SafeZ, Params.RapidFeedRate], FormatSettings));
    GCodeBuilder.Add('G0 X0 Y0');
    GCodeBuilder.Add('M30 ; Fine Programma');

    Result := GCodeBuilder.Text;
  finally
    GCodeBuilder.Free;
  end;
  if Assigned(ProgressCallback) then ProgressCallback(100);
end;

end.
