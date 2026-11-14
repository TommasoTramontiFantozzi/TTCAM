unit gcodeGen;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Math, EasyLazFreeType, TTTypes,  lazfreetype, RegExpr;

type
  TTransformationMatrix=record
    a,b,c,d,e,f:double;
end;
type
  TGCodeOptions = record
    XStart: Double;          // Coordinata X iniziale
    YStart: Double;          // Coordinata Y iniziale
    ZSafe: Double;           // Altezza di sicurezza Z
    ZStart: Double;          // Superficie del pezzo (Z0)
    ZDepth: Double;          // Profondità totale dell'incisione (valore negativo)
    ZStep: Double;           // Profondità di ogni singola passata (valore positivo)
    ZFeedRate: Double;       // Velocità di affondamento (F per Z)
    XYFeedRate: Double;      // Velocità di taglio (F per X/Y)
    ToolDiameter: Double;    // Diametro della fresa
    ScaleFactor: Double;     // Fattore di scala per convertire i punti TTF in mm
    Enabled: Boolean;
    RapidFeedRate: Double;
    SpindleSpeed: integer;
    LaserMode: Boolean;
    Fill: Boolean;
    PerimeterWidth: Double;  //Larghezza del perimetro
    Compensation: byte;      //Interna, esterna o nessuna
    Direction: byte;         //Climb o Conventional
    MaxRampAngle:double;     //Massimo amngolo di discesa lungo l'elica
    FinishAllowance:double;  //Margine di finitura del perimetro che verrà fresatu in ultimo
    TMatrix:TTransformationMatrix;
  end;

type
  TCompensazione = (compEsterna, compInterna);
  TCutDirection = (cdClimb, cdConventional);

function GeneraGCodeRettangoloCompensato(x0, y0, larghezza, altezza, raggio, diametro_fresa: Double; avanzamento,ZStep,ZDepth,ZSafe:Double): string;
function GeneraGCodeForoElicoidale(XCentro, YCentro, DiametroForo, DiametroFresa, ProfonditaTotale, PassoZ: Double; AvanzamentoXY: Double; AvanzamentoZ: Double; ZSafe:double): string;
function GenerateTextGCode(const TextStr: string; const FontPath: string; FontSize: Integer; const Options: TGCodeOptions):string;
function GenerateVectorTextGCode(const TextStr: string; const FontPath: string;
  const Options: TGCodeOptions):string;
type
  TGCodeTransformProgressProc = procedure(Percent: Integer) of object;

function TrasformaGCode(const GCodeTesto: string; DeltaX, DeltaY, GradiRotazione, CentroX, CentroY: Double; ProgressCallback: TGCodeTransformProgressProc = nil): string;
procedure CalcolaCentroGCode(const GCodeTesto: string; out CentroX, CentroY: Double);
function GeneraGCodeRettangoloTuffo(x0, y0, larghezza, altezza, raggio, diametro_fresa: Double;
  avanzamento, ZStep, ZDepth, ZSafe: Double; tipo_comp: TCompensazione;
  spessore_scavo: Double; // 0 o pari al diametro = passata singola. Maggiore = passate multiple.
  riempimento_totale: Boolean // Se True, svuota tutto l'interno (ignora lo spessore_scavo)
): string;
function GeneraGCodeRettangoloElicoidale(
  x0, y0, larghezza, altezza, raggio, diametro_fresa: Double;
  avanzamento_XY, avanzamento_Z, RPM: Double;
  ZStep, AngoloRampaMax, ZStart, ZDepth, ZSafe: Double;
  tipo_comp: byte;
  direzione: byte;
  spessore_scavo: Double;
  FinishAllowance: Double;
  riempimento_totale: Boolean;
  const Matrice: TTransformationMatrix // Aggiunto parametro matrice
): string;
function GeneraGCodeCerchioElicoidale(
 xc, yc, raggio, diametro_fresa: Double;
 avanzamento, ZStep, ZDepth, ZSafe: Double; tipo_comp: TCompensazione;
 spessore_scavo: Double; riempimento_totale: Boolean
): string;

function GeneraGCodeCerchioSvuotamentoElicoidale(
  xc, yc, raggio, diametro_fresa: Double;
  avanzamento_XY, avanzamento_Z, RPM: Double;
  ZStep, MaxRampAngle, ZStart, ZDepth, ZSafe: Double;
  tipo_comp: byte;
  direzione: byte;
  spessore_scavo: Double;
  FinishAllowance: Double;
  riempimento_totale: Boolean;
  const Matrice: TTransformationMatrix // Aggiunto parametro matrice
): string;
function GeneraGCodeRettaCentrataRampa(
  x1, y1, x2, y2: Double;
  diametro_fresa: Double;
  avanzamento_XY, avanzamento_Z, RPM: Double;
  ZStep, MaxRampAngle, ZStart, ZDepth, ZSafe: Double;
  tipo_comp: byte;
  direzione: byte;
  spessore_scavo: Double;
  FinishAllowance: Double;
  const Matrice: TTransformationMatrix // Aggiunto parametro matrice
): string;
function GenerateCounterboreGCode(Options: TGCodeOptions; DiameterMajor, DepthMajor, DiameterMinor: Double): string;
function ConvertCNCToLaser(const SourceGCode: string; LaserPower: Integer; UseM4: Boolean): string;
function ConvertCNCToLaserMultiPass(const SourceGCode: string; LaserPower: Integer; UseM4: Boolean; LaserPasses: Integer;XYFeed:double;rapidFeed:double): string;

implementation

procedure ApplicaMatrice(var x, y: Double; const m: TTransformationMatrix);
var
  x_orig: Double;
begin
  x_orig := x;
  x := m.a * x_orig + m.c * y + m.e;
  y := m.b * x_orig + m.d * y + m.f;
end;

procedure CalcolaCentroGCode(const GCodeTesto: string; out CentroX, CentroY: Double);
var
  LineeOriginali: TStringList;
  Linea, Codice: string;
  I: Integer;
  RegexX, RegexY: TRegExpr;
  X_Puro, Y_Puro: Double;
  MinX, MaxX, MinY, MaxY: Double;
  TrovatoX, TrovatoY: Boolean;
  PosCommento: Integer;
  FS: TFormatSettings;
begin
  // Inizializzazione delle variabili di output e flag
  CentroX := 0.0;
  CentroY := 0.0;
  TrovatoX := False;
  TrovatoY := False;

  // Limiti geometrici iniziali
  MinX := 0.0; MaxX := 0.0;
  MinY := 0.0; MaxY := 0.0;

  // Configura i parametri di formattazione standard (punto decimale)
  {$IFDEF FPC}
  FS := DefaultFormatSettings;
  {$ELSE}
  GetLocaleFormatSettings(0, FS);
  {$ENDIF}
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;

  LineeOriginali := TStringList.Create;

  RegexX := TRegExpr.Create;
  RegexX.Expression := '([X])([-+]?\d*\.\d+|\d+\.?\d*)';
  RegexX.ModifierI := True;

  RegexY := TRegExpr.Create;
  RegexY.Expression := '([Y])([-+]?\d*\.\d+|\d+\.?\d*)';
  RegexY.ModifierI := True;

  try
    LineeOriginali.Text := GCodeTesto;

    for I := 0 to LineeOriginali.Count - 1 do
    begin
      Linea := LineeOriginali[I];

      // Salta linee vuote o commenti totali
      if (Trim(Linea) = '') or (LeftStr(Trim(Linea), 1) = ';') then
        Continue;

      // Isola il codice eliminando i commenti a fine riga
      PosCommento := Pos(';', Linea);
      if PosCommento > 0 then
        Codice := Copy(Linea, 1, PosCommento - 1)
      else
        Codice := Linea;

      // Cerca la coordinata X
      if RegexX.Exec(Codice) then
      begin
        X_Puro := StrToFloatDef(RegexX.Match[2], 0.0, FS);
        if not TrovatoX then
        begin
          MinX := X_Puro;
          MaxX := X_Puro;
          TrovatoX := True;
        end
        else
        begin
          if X_Puro < MinX then MinX := X_Puro;
          if X_Puro > MaxX then MaxX := X_Puro;
        end;
      end;

      // Cerca la coordinata Y
      if RegexY.Exec(Codice) then
      begin
        Y_Puro := StrToFloatDef(RegexY.Match[2], 0.0, FS);
        if not TrovatoY then
        begin
          MinY := Y_Puro;
          MaxY := Y_Puro;
          TrovatoY := True;
        end
        else
        begin
          if Y_Puro < MinY then MinY := Y_Puro;
          if Y_Puro > MaxY then MaxY := Y_Puro;
        end;
      end;
    end;

    // Se sono state trovate coordinate, calcola il punto medio
    if TrovatoX then CentroX := (MinX + MaxX) / 2.0;
    if TrovatoY then CentroY := (MinY + MaxY) / 2.0;

  finally
    RegexX.Free;
    RegexY.Free;
    LineeOriginali.Free;
  end;
end;

function TrasformaGCode(const GCodeTesto: string; DeltaX, DeltaY, GradiRotazione, CentroX, CentroY: Double; ProgressCallback: TGCodeTransformProgressProc = nil): string;
var
  LineeOriginali, LineeModificate: TStringList;
  Linea, Codice, Commento, NuovoCodice: string;
  I_Idx: Integer;
  Radianti, CosVal, SinVal: Double;
  RegexX, RegexY, RegexI, RegexJ, RegexS: TRegExpr;
  X_Puro, Y_Puro, X_Relativo, Y_Relativo, X_Ruotato, Y_Ruotato, X_Finale, Y_Finale, S: Double;
  I_Puro, J_Puro, I_Ruotato, J_Ruotato: Double;
  HaX, HaY, HaI, HaJ, HaS: Boolean;
  PosCommento: Integer;
  LastReportedPercent, CurPercent: Integer;
  FS: TFormatSettings;
begin
  // Configura i parametri di formattazione in modo standard (punto decimale)
  {$IFDEF FPC}
  FS := DefaultFormatSettings;
  {$ELSE}
  GetLocaleFormatSettings(0, FS);
  {$ENDIF}
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;

  // Calcolo delle costanti trigonometriche per la rotazione
  Radianti := DegToRad(GradiRotazione);
  CosVal := Cos(Radianti);
  SinVal := Sin(Radianti);

  // Inizializzazione delle liste di stringhe
  LineeOriginali := TStringList.Create;
  LineeModificate := TStringList.Create;

  // Inizializzazione delle espressioni regolari per X, Y, I, J
  RegexX := TRegExpr.Create;
  RegexX.Expression := '([X])([-+]?\d*\.\d+|\d+\.?\d*)';
  RegexX.ModifierI := True;

  RegexY := TRegExpr.Create;
  RegexY.Expression := '([Y])([-+]?\d*\.\d+|\d+\.?\d*)';
  RegexY.ModifierI := True;

  RegexI := TRegExpr.Create;
  RegexI.Expression := '([I])([-+]?\d*\.\d+|\d+\.?\d*)';
  RegexI.ModifierI := True;

  RegexJ := TRegExpr.Create;
  RegexJ.Expression := '([J])([-+]?\d*\.\d+|\d+\.?\d*)';
  RegexJ.ModifierI := True;

  RegexS := TRegExpr.Create;
  RegexS.Expression := '([S])([-+]?\d*\.\d+|\d+\.?\d*)';
  RegexS.ModifierI := True;

  try
    LineeOriginali.Text := GCodeTesto;
    X_Puro := 0.0;
    Y_Puro := 0.0;
    LastReportedPercent := -1;
    if Assigned(ProgressCallback) then ProgressCallback(0);
    for I_Idx := 0 to LineeOriginali.Count - 1 do
    begin
      if Assigned(ProgressCallback) and (LineeOriginali.Count>0) then
      begin
        CurPercent := EnsureRange(Round(100 * I_Idx / LineeOriginali.Count), 0, 100);
        if CurPercent <> LastReportedPercent then
        begin
          LastReportedPercent := CurPercent;
          ProgressCallback(CurPercent);
        end;
      end;
      Linea := LineeOriginali[I_Idx];
      if (Trim(Linea) = '') or (LeftStr(Trim(Linea), 1) = ';') then
      begin
        LineeModificate.Add(Linea);
        Continue;
      end;

      PosCommento := Pos(';', Linea);
      if PosCommento > 0 then
      begin
        Codice := Copy(Linea, 1, PosCommento - 1);
        Commento := Copy(Linea, PosCommento, MaxInt);
      end
      else
      begin
        Codice := Linea;
        Commento := '';
      end;

      // Verifica la presenza dei vari parametri
      HaX := RegexX.Exec(Codice);
      HaY := RegexY.Exec(Codice);
      HaI := RegexI.Exec(Codice);
      HaJ := RegexJ.Exec(Codice);
      HaS := RegexS.Exec(Codice);

      if not HaX and not HaY and not HaI and not HaJ then
      begin
        LineeModificate.Add(Linea);
        Continue;
      end;

      NuovoCodice := Codice;

      if HaS then
      begin
        S := StrToFloatDef(RegexS.Match[2], 0.0, FS);
        NuovoCodice := RegexS.Replace(NuovoCodice, '', False)
      end;

      // --- TRASFORMAZIONE COORDINATE ASSOLUTE (X e Y) ---
      if HaX or HaY then
      begin
        if HaX then X_Puro := StrToFloatDef(RegexX.Match[2], 0.0, FS);
        if HaY then Y_Puro := StrToFloatDef(RegexY.Match[2], 0.0, FS);

        // 1. Trasla rispetto al centro di rotazione locale
        X_Relativo := X_Puro - CentroX;
        Y_Relativo := Y_Puro - CentroY;

        // 2. Ruota le coordinate absolute
        X_Ruotato := X_Relativo * CosVal - Y_Relativo * SinVal;
        Y_Ruotato := X_Relativo * SinVal + Y_Relativo * CosVal;

        // 3. Ripristina il centro e aggiungi il Delta di traslazione finale
        X_Finale := X_Ruotato + CentroX + DeltaX;
        Y_Finale := Y_Ruotato + CentroY + DeltaY;

        // Sostituzione o iniezione di X e Y nel testo della riga
        if HaX then
          NuovoCodice := RegexX.Replace(NuovoCodice, 'X' + FloatToStrF(X_Finale, ffFixed, 15, 3, FS), False)
        else if (DeltaX <> 0.0) or (GradiRotazione <> 0.0) or (CentroX <> 0.0) then
          NuovoCodice := TrimRight(NuovoCodice) + ' X' + FloatToStrF(X_Finale, ffFixed, 15, 3, FS);

        if HaY then
          NuovoCodice := RegexY.Replace(NuovoCodice, 'Y' + FloatToStrF(Y_Finale, ffFixed, 15, 3, FS), False)
        else if (DeltaY <> 0.0) or (GradiRotazione <> 0.0) or (CentroY <> 0.0) then
          NuovoCodice := TrimRight(NuovoCodice) + ' Y' + FloatToStrF(Y_Finale, ffFixed, 15, 3, FS);
      end;

      // --- TRASFORMAZIONE COORDINATE INCREMENTALI DEL CENTRO (I e J) ---
      if HaI or HaJ then
      begin
        I_Puro := 0.0;
        J_Puro := 0.0;
        if HaI then I_Puro := StrToFloatDef(RegexI.Match[2], 0.0, FS);
        if HaJ then J_Puro := StrToFloatDef(RegexJ.Match[2], 0.0, FS);

        // Per i vettori incrementali si applica SOLO la rotazione pura dell'angolo.
        // NON si applica lo sfasamento del CentroX/Y né il DeltaX/Y!
        I_Ruotato := I_Puro * CosVal - J_Puro * SinVal;
        J_Ruotato := I_Puro * SinVal + J_Puro * CosVal;

        if HaI then
          NuovoCodice := RegexI.Replace(NuovoCodice, 'I' + FloatToStrF(I_Ruotato, ffFixed, 15, 3, FS), False);
        if HaJ then
          NuovoCodice := RegexJ.Replace(NuovoCodice, 'J' + FloatToStrF(J_Ruotato, ffFixed, 15, 3, FS), False);
      end;
      if HaS then
      begin
        NuovoCodice := TrimRight(NuovoCodice) + ' S' + FloatToStrF(S, ffFixed, 15, 1, FS);
      end;
      LineeModificate.Add(NuovoCodice + Commento);
    end;
    Result := LineeModificate.Text;
  finally
    RegexX.Free;
    RegexY.Free;
    RegexI.Free;
    RegexJ.Free;
    LineeOriginali.Free;
    LineeModificate.Free;
  end;
  if Assigned(ProgressCallback) then ProgressCallback(100);
end;


function GeneraGCodeRettaCentrataRampa(
  x1, y1, x2, y2: Double;
  diametro_fresa: Double;
  avanzamento_XY, avanzamento_Z, RPM: Double;
  ZStep, MaxRampAngle, ZStart, ZDepth, ZSafe: Double;
  tipo_comp: byte;
  direzione: byte;
  spessore_scavo: Double;
  FinishAllowance: Double;
  const Matrice: TTransformationMatrix // Aggiunto parametro matrice
): string;
var
  fresa_raggio, step_over, offset_corrente, semi_spessore_massimo: Double;
  dx, dy, lunghezza, nx, ny, ux, uy: Double;
  cx1, cy1, cx2, cy2: Double;
  ox1, oy1, ox2, oy2, start_x, start_y, end_x, end_y: Double;
  GCodeList: TStringList;
  FormatSettings: TFormatSettings;
  z_corrente, z_target, z_step_dinamico, z_step_angolo: Double;
  fine_scavo, ultima_passata_z, direzione_avanti: Boolean;
  lato_corrente: Integer;
  moltiplicatore_lato: Double;
  tox1, toy1, tox2, toy2, tstart_x, tstart_y, tend_x, tend_y: Double;
begin
  ZStep           := abs(ZStep);
  MaxRampAngle    := abs(MaxRampAngle);
  ZStart          := abs(ZStart);
  ZDepth          := abs(ZDepth);
  ZSafe           := abs(ZSafe);
  if ZSafe = 0 then ZSafe := 5;
  spessore_scavo  := abs(spessore_scavo);
  FinishAllowance := abs(FinishAllowance);
  ZDepth:=ZDepth+ZStart;

  dx := x2 - x1; dy := y2 - y1;
  lunghezza := sqrt(dx * dx + dy * dy);

  if (lunghezza <= 0) then raise Exception.Create('Lunghezza della retta deve essere maggiore di zero.');
  fresa_raggio := diametro_fresa / 2;

  ux := dx / lunghezza; uy := dy / lunghezza;
  nx := -dy / lunghezza; ny := dx / lunghezza;

  cx1 := x1 + (ux * fresa_raggio); cy1 := y1 + (uy * fresa_raggio);
  cx2 := x2 - (ux * fresa_raggio); cy2 := y2 - (uy * fresa_raggio);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  step_over := diametro_fresa * 0.60;

  GCodeList := TStringList.Create;
  try
    GCodeList.Add('; --- Inizio Retta con Svuotamento e Matrice ---');
    GCodeList.Add('G21 ; Unità mm | G90 ; Assoluto');

    if RPM > 0 then GCodeList.Add(Format('S%f M3', [RPM], FormatSettings));

    if tipo_comp = 2 then
    begin
      if (spessore_scavo <= diametro_fresa) then semi_spessore_massimo := 0
      else semi_spessore_massimo := (spessore_scavo / 2) - fresa_raggio;
    end
    else
    begin
      if (spessore_scavo <= diametro_fresa) then semi_spessore_massimo := FinishAllowance
      else semi_spessore_massimo := ((spessore_scavo / 2) - fresa_raggio) + FinishAllowance;
    end;

    if direzione = 0 then moltiplicatore_lato := -1.0 else moltiplicatore_lato := 1.0;

    offset_corrente := 0; fine_scavo := False; lato_corrente := 1;

    while not fine_scavo do
    begin
      ox1 := cx1 + (nx * offset_corrente * moltiplicatore_lato);
      oy1 := cy1 + (ny * offset_corrente * moltiplicatore_lato);
      ox2 := cx2 + (nx * offset_corrente * moltiplicatore_lato);
      oy2 := cy2 + (ny * offset_corrente * moltiplicatore_lato);

      z_step_dinamico := ZStep;
      if MaxRampAngle > 0 then
      begin
        z_step_angolo := lunghezza * Tan(MaxRampAngle * Pi / 180.0);
        if z_step_angolo < z_step_dinamico then z_step_dinamico := z_step_angolo;
      end;
      if z_step_dinamico <= 0 then z_step_dinamico := 0.1;

      GCodeList.Add(Format('; --- Traccia Parallela Offset: %f ---', [offset_corrente * moltiplicatore_lato], FormatSettings));

      tox1 := ox1; toy1 := oy1; ApplicaMatrice(tox1, toy1, Matrice);
      tox2 := ox2; toy2 := oy2; ApplicaMatrice(tox2, toy2, Matrice);

      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
      GCodeList.Add(Format('G0 X%f Y%f', [tox1, toy1], FormatSettings));
      GCodeList.Add(Format('G1 Z-%f F%s', [ZStart, FloatToStr(avanzamento_Z, FormatSettings)], FormatSettings));

      z_corrente := -ZStart; ultima_passata_z := False; direzione_avanti := True;

      start_x := tox1; start_y := toy1;
      end_x := tox2;   end_y := toy2;

      while not ultima_passata_z do
      begin
        if (z_corrente - z_step_dinamico) <= -ZDepth then
        begin
          z_target := -ZDepth; ultima_passata_z := True;
        end
        else
          z_target := z_corrente - z_step_dinamico;

        if direzione_avanti then
          GCodeList.Add(Format('G1 X%f Y%f Z%f F%s', [end_x, end_y, z_target, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings))
        else
          GCodeList.Add(Format('G1 X%f Y%f Z%f F%s', [start_x, start_y, z_target, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));

        z_corrente := z_target;
        direzione_avanti := not direzione_avanti;
      end;

      GCodeList.Add('; Spianatura fondo');
      if direzione_avanti then GCodeList.Add(Format('G1 X%f Y%f', [end_x, end_y], FormatSettings))
      else GCodeList.Add(Format('G1 X%f Y%f', [start_x, start_y], FormatSettings));

      GCodeList.Add(Format('G1 X%f Y%f', [tox1, toy1], FormatSettings));
      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));

      if semi_spessore_massimo = 0 then fine_scavo := True
      else begin
        if lato_corrente = 1 then
        begin
          if offset_corrente <= -semi_spessore_massimo then
          begin
            lato_corrente := 2; offset_corrente := step_over;
            if offset_corrente > semi_spessore_massimo then offset_corrente := semi_spessore_massimo;
          end
          else begin
            offset_corrente := offset_corrente - step_over;
            if offset_corrente < -semi_spessore_massimo then offset_corrente := -semi_spessore_massimo;
          end;
        end
        else if lato_corrente = 2 then
        begin
          if offset_corrente >= semi_spessore_massimo then fine_scavo := True
          else begin
            offset_corrente := offset_corrente + step_over;
            if offset_corrente > semi_spessore_massimo then offset_corrente := semi_spessore_massimo;
          end;
        end;
      end;
    end;

    // Finitura Pareti Retta
    if (FinishAllowance > 0) and (tipo_comp in [0, 1]) then
    begin
      GCodeList.Add('; --- Finitura Parete Destra ---');
      offset_corrente := -((spessore_scavo / 2) - fresa_raggio);
      ox1 := cx1 + (nx * offset_corrente * moltiplicatore_lato); oy1 := cy1 + (ny * offset_corrente * moltiplicatore_lato);
      ox2 := cx2 + (nx * offset_corrente * moltiplicatore_lato); oy2 := cy2 + (ny * offset_corrente * moltiplicatore_lato);
      tox1 := ox1; toy1 := oy1; ApplicaMatrice(tox1, toy1, Matrice);
      tox2 := ox2; toy2 := oy2; ApplicaMatrice(tox2, toy2, Matrice);

      GCodeList.Add(Format('G0 X%f Y%f', [tox1, toy1], FormatSettings));
      GCodeList.Add(Format('G1 Z-%f F%s', [ZDepth, FloatToStr(avanzamento_Z, FormatSettings)], FormatSettings));
      GCodeList.Add(Format('G1 X%f Y%f F%s', [tox2, toy2, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));

      if spessore_scavo > diametro_fresa then
      begin
        GCodeList.Add('; --- Finitura Parete Sinistra ---');
        offset_corrente := ((spessore_scavo / 2) - fresa_raggio);
        ox1 := cx1 + (nx * offset_corrente * moltiplicatore_lato); oy1 := cy1 + (ny * offset_corrente * moltiplicatore_lato);
        ox2 := cx2 + (nx * offset_corrente * moltiplicatore_lato); oy2 := cy2 + (ny * offset_corrente * moltiplicatore_lato);
        tox1 := ox1; toy1 := oy1; ApplicaMatrice(tox1, toy1, Matrice);
        tox2 := ox2; toy2 := oy2; ApplicaMatrice(tox2, toy2, Matrice);

        GCodeList.Add(Format('G0 X%f Y%f', [tox1, toy1], FormatSettings));
        GCodeList.Add(Format('G1 Z-%f F%s', [ZDepth, FloatToStr(avanzamento_Z, FormatSettings)], FormatSettings));
        GCodeList.Add(Format('G1 X%f Y%f F%s', [tox2, toy2, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
        GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
      end;
    end;

    if RPM > 0 then GCodeList.Add('M5');
    GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
    Result := GCodeList.Text;
  finally
    GCodeList.Free;
  end;
end;


function GeneraGCodeRettangoloCompensato(x0, y0, larghezza, altezza, raggio, diametro_fresa: Double; avanzamento,ZStep,ZDepth,ZSafe:Double): string;
var
  offset, raggio_effettivo: Double;
  x_min, x_max, y_min, y_max: Double;
  start_x, start_y: Double;
  GCodeList: TStringList;
  FormatSettings: TFormatSettings;
  Z:double;
begin
  ZStep:=abs(ZStep);
  ZDepth:=abs(ZDepth);
  ZSafe:=abs(ZSafe);
  if ZSafe=0 then ZSafe:=5;

  // Controllo validità parametri geometrici
  if (raggio * 2 > larghezza) or (raggio * 2 > altezza) then
    raise Exception.Create('Il raggio di curvatura è troppo grande per le dimensioni del rettangolo.');

  if (raggio < 0) {or (diametro_fresa < 0)} then
    raise Exception.Create('Raggio e diametro fresa non possono essere negativi.');

  // Configurazione per forzare il punto decimale (.) nel G-code anziché la virgola (,)
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';

  // Calcolo del raggio effettivo che il centro dell'utensile deve descrivere
  offset := diametro_fresa / 2;
  raggio_effettivo := raggio + offset;

  // Coordinate del rettangolo compensate (estese verso l'esterno di un offset)
  x_min := x0 - offset;
  x_max := x0 + larghezza + offset;
  y_min := y0 - offset;
  y_max := y0 + altezza + offset;

  GCodeList := TStringList.Create;
  try
    GCodeList.Add('; --- Inizio Rettangolo con Compensazione Fresa ---');
    GCodeList.Add(Format('; Diametro fresa: %gmm (Offset: %gmm)', [diametro_fresa, offset], FormatSettings));
    GCodeList.Add('G21 ; Imposta unità in mm');
    GCodeList.Add('G90 ; Posizionamento assoluto');
    Z:=-ZStep;
    while (Z>-ZDepth) do
    begin

      // Se il raggio finale descritto dal centro utensile è zero (fresa e raggio = 0)
      if raggio_effettivo = 0 then
      begin
        GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
        GCodeList.Add(Format('G0 X%f Y%f', [x_min, y_min], FormatSettings));
        GCodeList.Add(Format('G1 Z%f F%f', [Z, avanzamento], FormatSettings));
        GCodeList.Add(Format('G1 X%f Y%f F%f', [x_max, y_min, avanzamento], FormatSettings));
        GCodeList.Add(Format('G1 X%f Y%f', [x_max, y_max], FormatSettings));
        GCodeList.Add(Format('G1 X%f Y%f', [x_min, y_max], FormatSettings));
        GCodeList.Add(Format('G1 X%f Y%f', [x_min, y_min], FormatSettings));
      end
      else
      begin
        // Punto iniziale: fine del primo arco in basso a sinistra (inizio del lato inferiore)
        start_x := x_min + raggio_effettivo;
        start_y := y_min;

        GCodeList.Add(Format('G0 Z%f ;ZSafe', [ZSafe], FormatSettings));
        GCodeList.Add(Format('G0 X%f Y%f ; Rapido al punto iniziale compensato', [start_x, start_y], FormatSettings));

        GCodeList.Add(Format('G1 Z%f F%f', [Z, avanzamento], FormatSettings));
        // Lato inferiore -> Arco in basso a destra
        GCodeList.Add(Format('G1 X%f Y%f F%f', [x_max - raggio_effettivo, y_min, avanzamento], FormatSettings));
        GCodeList.Add(Format('G3 X%f Y%f I0 J%f', [x_max, y_min + raggio_effettivo, raggio_effettivo], FormatSettings));

        // Lato destro -> Arco in alto a destra
        GCodeList.Add(Format('G1 X%f Y%f', [x_max, y_max - raggio_effettivo], FormatSettings));
        GCodeList.Add(Format('G3 X%f Y%f I%f J0', [x_max - raggio_effettivo, y_max, -raggio_effettivo], FormatSettings));

        // Lato superiore -> Arco in alto a sinistra
        GCodeList.Add(Format('G1 X%f Y%f', [x_min + raggio_effettivo, y_max], FormatSettings));
        GCodeList.Add(Format('G3 X%f Y%f I0 J%f', [x_min, y_max - raggio_effettivo, -raggio_effettivo], FormatSettings));

        // Lato sinistro -> Arco in basso a sinistra
        GCodeList.Add(Format('G1 X%f Y%f', [x_min, y_min + raggio_effettivo], FormatSettings));
        GCodeList.Add(Format('G3 X%f Y%f I%f J0', [start_x, start_y, raggio_effettivo], FormatSettings));
      end;
      Z:=Z-ZStep;
    end;

    GCodeList.Add('; --- Fine Rettangolo ---');

    // Ritorna l'intero testo separato da a capo
    Result := GCodeList.Text;
  finally
    GCodeList.Free;
  end;
end;

// Verifica se la matrice preserva la circolarità (no skew, scalatura uniforme)
function IsMatrixCircularPreserving(const m: TTransformationMatrix): Boolean;
var
  Sx2, Sy2, DotProduct: Double;
  Tol: Double;
begin
  Tol := 1e-5; // Tolleranza per calcoli a virgola mobile
  Sx2 := m.a * m.a + m.b * m.b;
  Sy2 := m.c * m.c + m.d * m.d;
  DotProduct := m.a * m.c + m.b * m.d;
  // Per mantenere la circolarità, le scale devono essere uguali e gli assi ortogonali (prodotto scalare nullo)
  Result := (Abs(Sx2 - Sy2) < Tol) and (Abs(DotProduct) < Tol);
end;

// Scrive nel GCode un arco interpolato (G2/G3) o la sua discretizzazione in G1 se deformato
procedure ScriviArcoOttimizzato(
  GCodeList: TStringList;
  const g_arco: string; // 'G2' o 'G3'
  xs, ys, xe, ye, xc, yc: Double; // Coordinate originali non trasformate
  z_start, z_end: Double;
  const Matrice: TTransformationMatrix;
  const FormatSettings: TFormatSettings;
  avanzamento: Double;
  forza_F: Boolean
);
var
  txs, tys, txe, tye, txc, tyc, tI, tJ: Double;
  theta_s, theta_e, theta_diff, theta, r, x, y, z: Double;
  i, N: Integer;
  f_str: string;
  is_cerchio_completo: Boolean;
begin
  if forza_F then
    f_str := ' F' + FloatToStr(avanzamento, FormatSettings)
  else
    f_str := '';

  // Controlliamo se si tratta di un cerchio chiuso a 360° (punto iniziale = finale)
  is_cerchio_completo := (Abs(xs - xe) < 1e-5) and (Abs(ys - ye) < 1e-5);

  // Se la matrice preserva la circolarità, usiamo l'arco nativo G2/G3 (molto più leggero)
  if IsMatrixCircularPreserving(Matrice) then
  begin
    txs := xs; tys := ys; ApplicaMatrice(txs, tys, Matrice);
    txe := xe; tye := ye; ApplicaMatrice(txe, tye, Matrice);
    txc := xc; tyc := yc; ApplicaMatrice(txc, tyc, Matrice);

    tI := txc - txs;
    tJ := tyc - tys;

    if z_start <> z_end then
      GCodeList.Add(Format('%s X%f Y%f Z%f I%f J%f%s', [g_arco, txe, tye, z_end, tI, tJ, f_str], FormatSettings))
    else
      GCodeList.Add(Format('%s X%f Y%f I%f J%f%s', [g_arco, txe, tye, tI, tJ, f_str], FormatSettings));
  end
  else
  begin
    // Se c'è skew o asimmetria (ellisse), dobbiamo discretizzare forzatamente in G1
    r := Sqrt((xs - xc)*(xs - xc) + (ys - yc)*(ys - yc));

    theta_s := ArcTan2(ys - yc, xs - xc);

    if is_cerchio_completo then
    begin
      // Se è un cerchio intero, la differenza angolare deve essere esattamente un giro completo
      if g_arco = 'G3' then
        theta_diff := 2.0 * Pi
      else
        theta_diff := -2.0 * Pi;
    end
    else
    begin
      theta_e := ArcTan2(ye - yc, xe - xc);
      // Risolviamo l'orientamento angolare corretto per archi parziali
      if g_arco = 'G3' then // CCW (Antiorario)
      begin
        if theta_e <= theta_s then theta_e := theta_e + (2.0 * Pi);
      end
      else // CW (Orario)
      begin
        if theta_e >= theta_s then theta_e := theta_e - (2.0 * Pi);
      end;
      theta_diff := theta_e - theta_s;
    end;

    // Calcolo dei segmenti (64 per un cerchio completo, proporzionali per archi minori)
    N := Round(Abs(theta_diff) / (Pi / 32.0));
    if N < 12 then N := 12; // Risoluzione minima per raccordi fluidi

    for i := 1 to N do
    begin
      theta := theta_s + (i / N) * theta_diff;

      // Calcoliamo la Z in modo perfettamente lineare lungo la progressione dei segmenti
      z := z_start + (i / N) * (z_end - z_start);

      x := xc + r * Cos(theta);
      y := yc + r * Sin(theta);

      // Applichiamo la deformazione della matrice SVG (incluso lo skew) solo alla fine del calcolo geometrico
      ApplicaMatrice(x, y, Matrice);

      if (i = 1) and forza_F then
        GCodeList.Add(Format('G1 X%f Y%f Z%f F%s', [x, y, z, FloatToStr(avanzamento, FormatSettings)], FormatSettings))
      else
        GCodeList.Add(Format('G1 X%f Y%f Z%f', [x, y, z], FormatSettings));
    end;
  end;
end;


//tipo_comp=0 --> Compensazione interna
//tipo_comp=1 --> Compensazione esterna
//tipo_comp=2 --> Compensazione nessuna
//direzione=0 --> Direzione Climb
//direzione=1 --> Direzione Conventional
function GeneraGCodeRettangoloElicoidale(
  x0, y0, larghezza, altezza, raggio, diametro_fresa: Double;
  avanzamento_XY, avanzamento_Z, RPM: Double;
  ZStep, AngoloRampaMax, ZStart, ZDepth, ZSafe: Double;
  tipo_comp: byte;
  direzione: byte;
  spessore_scavo: Double;
  FinishAllowance: Double;
  riempimento_totale: Boolean;
  const Matrice: TTransformationMatrix
): string;
var
  fresa_raggio, step_over, offset_corrente, offset_massimo: Double;
  x_min, x_max, y_min, y_max: Double;
  raggio_effettivo, start_x, start_y: Double;
  GCodeList: TStringList;
  FormatSettings: TFormatSettings;
  z_corrente, z_target_giro, z_per_elemento, z_step_dinamico: Double;
  fine_scavo, ultima_passata_z: Boolean;
  perimetro_totale, z_step_angolo: Double;
  usa_orario: Boolean;
  g_arco: string;
  tx, ty, tstart_x, tstart_y: Double;
begin
  ZStep           := abs(ZStep);
  AngoloRampaMax  := abs(AngoloRampaMax);
  ZStart          := abs(ZStart);
  ZDepth          := abs(ZDepth);
  ZSafe           := abs(ZSafe);
  if ZSafe = 0 then ZSafe := 5;
  spessore_scavo  := abs(spessore_scavo);
  FinishAllowance := abs(FinishAllowance);

  if ZStart >= ZDepth then
    raise Exception.Create('ZStart deve essere minore della profondità totale ZDepth.');
  if (raggio * 2 > larghezza) or (raggio * 2 > altezza) then
    raise Exception.Create('Il raggio di curvatura è troppo grande per le dimensioni del rettangolo.');

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';

  fresa_raggio := diametro_fresa / 2;
  step_over    := diametro_fresa * 0.60;

  if (tipo_comp = 0) or (tipo_comp = 2) then
    usa_orario := (direzione = 0)
  else
    usa_orario := (direzione = 1);

  if usa_orario then g_arco := 'G2' else g_arco := 'G3';

  GCodeList := TStringList.Create;
  try
    GCodeList.Add('; --- Inizio Rettangolo Elicoidale Avanzato con Matrice Integrata ---');
    GCodeList.Add('G21 ; Unità in mm | G90 ; Posizionamento assoluto');

    if RPM > 0 then
      GCodeList.Add(Format('S%f M3', [RPM], FormatSettings));

    // --- Inizializzazione Offset Iniziale ---
        if tipo_comp = 1 then
          offset_corrente := fresa_raggio + FinishAllowance
        else if tipo_comp = 0 then
          offset_corrente := -fresa_raggio - FinishAllowance
        else // tipo_comp = 2 (Nessuna compensazione / Centrato)
        begin
          if spessore_scavo > diametro_fresa then
            offset_corrente := -(spessore_scavo - diametro_fresa) / 2.0
          else
            offset_corrente := 0.0;
        end;

        // --- Inizializzazione Offset Massimo ---
        if (tipo_comp = 2) then
        begin
          if spessore_scavo > diametro_fresa then
            offset_massimo := (spessore_scavo - diametro_fresa) / 2.0
          else
            offset_massimo := 0.0;
        end
        else if riempimento_totale and (tipo_comp = 0) then
        begin
          if larghezza < altezza then offset_massimo := -(larghezza / 2) else offset_massimo := -(altezza / 2);
        end
        else if spessore_scavo > diametro_fresa then
        begin
          if tipo_comp = 1 then offset_massimo := fresa_raggio + (spessore_scavo - diametro_fresa)
          else offset_massimo := -fresa_raggio - (spessore_scavo - diametro_fresa);
        end
        else
          offset_massimo := offset_corrente;

    fine_scavo := False;

    while not fine_scavo do
    begin
      x_min := x0 - offset_corrente; x_max := x0 + larghezza + offset_corrente;
      y_min := y0 - offset_corrente; y_max := y0 + altezza + offset_corrente;

      raggio_effettivo := raggio + offset_corrente;
      if raggio_effettivo < 0 then raggio_effettivo := 0;

      if (tipo_comp = 0) and ((x_max <= x_min) or (y_max <= y_min)) then
      begin
        fine_scavo := True;
        Break;
      end;

      if raggio_effettivo = 0 then
        perimetro_totale := ((x_max - x_min) * 2) + ((y_max - y_min) * 2)
      else
        perimetro_totale := ((x_max - x_min - (2 * raggio_effettivo)) * 2) + ((y_max - y_min - (2 * raggio_effettivo)) * 2) + (2 * Pi * raggio_effettivo);

      z_step_dinamico := ZStep;
      if AngoloRampaMax > 0 then
      begin
        z_step_angolo := perimetro_totale * Tan(AngoloRampaMax * Pi / 180.0);
        if z_step_angolo < z_step_dinamico then z_step_dinamico := z_step_angolo;
      end;

      if z_step_dinamico < 0.1 then z_step_dinamico := 0.1;

      GCodeList.Add(Format('; --- Lavorazione Anello Offset: %f ---', [offset_corrente], FormatSettings));

      if not usa_orario then
      begin
        start_x := x_min + raggio_effettivo; start_y := y_min;
      end
      else
      begin
        start_x := x_min; start_y := y_min + raggio_effettivo;
      end;

      tstart_x := start_x; tstart_y := start_y; ApplicaMatrice(tstart_x, tstart_y, Matrice);

      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
      GCodeList.Add(Format('G0 X%f Y%f', [tstart_x, tstart_y], FormatSettings));
      GCodeList.Add(Format('G1 Z-%f F%s', [ZStart, FloatToStr(avanzamento_Z, FormatSettings)], FormatSettings));

      z_corrente := -ZStart;
      ultima_passata_z := False;

      while not ultima_passata_z do
      begin
        if (z_corrente - z_step_dinamico) <= -ZDepth then
        begin
          z_target_giro := -ZDepth; ultima_passata_z := True;
        end
        else
          z_target_giro := z_corrente - z_step_dinamico;

        z_per_elemento := (z_target_giro - z_corrente) / 8.0;

        if raggio_effettivo = 0 then
        begin
          // Rampa spigoli vivi (Usa solo G1 trasformatore)
          if not usa_orario then
          begin
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_max; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f F%s', [tx, ty, z_corrente, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_max; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_min; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_min; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));
          end
          else
          begin
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_min; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f F%s', [tx, ty, z_corrente, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_max; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_max; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));
            z_corrente := z_corrente + (z_per_elemento * 2); tx := x_min; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));
          end;
        end
        else
        begin
          // RAMPA ELICOIDALE CON ANGOLI ARROTONDATI (Esecuzione Archi Protetti)
          if not usa_orario then
          begin
            z_corrente := z_corrente + z_per_elemento; tx := x_max - raggio_effettivo; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f F%s', [tx, ty, z_corrente, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));

            // Angolo 1
            ScriviArcoOttimizzato(GCodeList, g_arco, x_max - raggio_effettivo, y_min, x_max, y_min + raggio_effettivo, x_max - raggio_effettivo, y_min + raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;

            z_corrente := z_corrente + z_per_elemento; tx := x_max; ty := y_max - raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));

            // Angolo 2
            ScriviArcoOttimizzato(GCodeList, g_arco, x_max, y_max - raggio_effettivo, x_max - raggio_effettivo, y_max, x_max - raggio_effettivo, y_max - raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;

            z_corrente := z_corrente + z_per_elemento; tx := x_min + raggio_effettivo; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));

            // Angolo 3
            ScriviArcoOttimizzato(GCodeList, g_arco, x_min + raggio_effettivo, y_max, x_min, y_max - raggio_effettivo, x_min + raggio_effettivo, y_max - raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;

            z_corrente := z_corrente + z_per_elemento; tx := x_min; ty := y_min + raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));

            // Angolo 4 (Raccordo finale sul punto di partenza)
            ScriviArcoOttimizzato(GCodeList, g_arco, x_min, y_min + raggio_effettivo, start_x, start_y, x_min + raggio_effettivo, y_min + raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;
          end
          else
          begin
            z_corrente := z_corrente + z_per_elemento; tx := x_min; ty := y_max - raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f F%s', [tx, ty, z_corrente, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));

            // Angolo 1 (CW)
            ScriviArcoOttimizzato(GCodeList, g_arco, x_min, y_max - raggio_effettivo, x_min + raggio_effettivo, y_max, x_min + raggio_effettivo, y_max - raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;

            z_corrente := z_corrente + z_per_elemento; tx := x_max - raggio_effettivo; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));

            // Angolo 2 (CW)
            ScriviArcoOttimizzato(GCodeList, g_arco, x_max - raggio_effettivo, y_max, x_max, y_max - raggio_effettivo, x_max - raggio_effettivo, y_max - raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;

            z_corrente := z_corrente + z_per_elemento; tx := x_max; ty := y_min + raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));

            // Angolo 3 (CW)
            ScriviArcoOttimizzato(GCodeList, g_arco, x_max, y_min + raggio_effettivo, x_max - raggio_effettivo, y_min, x_max - raggio_effettivo, y_min + raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;

            z_corrente := z_corrente + z_per_elemento; tx := x_min + raggio_effettivo; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_corrente], FormatSettings));

            // Angolo 4 (CW)
            ScriviArcoOttimizzato(GCodeList, g_arco, x_min + raggio_effettivo, y_min, start_x, start_y, x_min + raggio_effettivo, y_min + raggio_effettivo, z_corrente, z_corrente + z_per_elemento, Matrice, FormatSettings, avanzamento_XY, False);
            z_corrente := z_corrente + z_per_elemento;
          end;
        end;
      end;

      // Passata di spianatura fondo a Z fissa
      GCodeList.Add('; Passata di spianatura fondo a Z fissa');
      if raggio_effettivo = 0 then
      begin
        if not usa_orario then
        begin
          tx := x_max; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_max; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_min; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_min; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
        end
        else
        begin
          tx := x_min; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_max; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_max; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_min; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
        end;
      end
      else
      begin
        if not usa_orario then
        begin
          tx := x_max - raggio_effettivo; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max - raggio_effettivo, y_min, x_max, y_min + raggio_effettivo, x_max - raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_max; ty := y_max - raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max, y_max - raggio_effettivo, x_max - raggio_effettivo, y_max, x_max - raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_min + raggio_effettivo; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min + raggio_effettivo, y_max, x_min, y_max - raggio_effettivo, x_min + raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_min; ty := y_min + raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min, y_min + raggio_effettivo, start_x, start_y, x_min + raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
        end
        else
        begin
          tx := x_min; ty := y_max - raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min, y_max - raggio_effettivo, x_min + raggio_effettivo, y_max, x_min + raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_max - raggio_effettivo; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max - raggio_effettivo, y_max, x_max, y_max - raggio_effettivo, x_max - raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_max; ty := y_min + raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max, y_min + raggio_effettivo, x_max - raggio_effettivo, y_min, x_max - raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_min + raggio_effettivo; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min + raggio_effettivo, y_min, start_x, start_y, x_min + raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
        end;
      end;

      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));

      // Gestione passo laterale (Safe & Loop Free)
      if offset_massimo > offset_corrente then
      begin
        if offset_corrente >= offset_massimo then fine_scavo := True
        else begin
          offset_corrente := offset_corrente + step_over;
          if offset_corrente > offset_massimo then offset_corrente := offset_massimo;
        end;
      end
      else
      begin
        if offset_corrente <= offset_massimo then fine_scavo := True
        else begin
          offset_corrente := offset_corrente - step_over;
          if offset_corrente < offset_massimo then offset_corrente := offset_massimo;
        end;
      end;
    end;

    // --- PASSATA FINALE DI FINITURA PARETI ---
    if (FinishAllowance > 0) and (tipo_comp in [0, 1]) then
    begin
      GCodeList.Add('; --- Passata Finale di Finitura Pareti ---');
      if tipo_comp = 1 then offset_corrente := fresa_raggio else offset_corrente := -fresa_raggio;
      x_min := x0 - offset_corrente; x_max := x0 + larghezza + offset_corrente;
      y_min := y0 - offset_corrente; y_max := y0 + altezza + offset_corrente;
      raggio_effettivo := raggio + offset_corrente; if raggio_effettivo < 0 then raggio_effettivo := 0;

      if not usa_orario then
      begin
        start_x := x_min + raggio_effettivo; start_y := y_min;
      end
      else
      begin
        start_x := x_min; start_y := y_min + raggio_effettivo;
      end;
      tstart_x := start_x; tstart_y := start_y; ApplicaMatrice(tstart_x, tstart_y, Matrice);

      GCodeList.Add(Format('G0 X%f Y%f', [tstart_x, tstart_y], FormatSettings));
      GCodeList.Add(Format('G1 Z-%f F%s', [ZDepth, FloatToStr(avanzamento_Z, FormatSettings)], FormatSettings));

      if raggio_effettivo = 0 then
      begin
        if not usa_orario then
        begin
          tx := x_max; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f F%s', [tx, ty, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
          tx := x_max; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_min; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_min; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
        end
        else
        begin
          tx := x_min; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f F%s', [tx, ty, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
          tx := x_max; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_max; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          tx := x_min; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
        end;
      end
      else
      begin
        if not usa_orario then
        begin
          tx := x_max - raggio_effettivo; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f F%s', [tx, ty, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max - raggio_effettivo, y_min, x_max, y_min + raggio_effettivo, x_max - raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_max; ty := y_max - raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max, y_max - raggio_effettivo, x_max - raggio_effettivo, y_max, x_max - raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_min + raggio_effettivo; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min + raggio_effettivo, y_max, x_min, y_max - raggio_effettivo, x_min + raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_min; ty := y_min + raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min, y_min + raggio_effettivo, start_x, start_y, x_min + raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
        end
        else
        begin
          tx := x_min; ty := y_max - raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f F%s', [tx, ty, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min, y_max - raggio_effettivo, x_min + raggio_effettivo, y_max, x_min + raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_max - raggio_effettivo; ty := y_max; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max - raggio_effettivo, y_max, x_max, y_max - raggio_effettivo, x_max - raggio_effettivo, y_max - raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_max; ty := y_min + raggio_effettivo; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_max, y_min + raggio_effettivo, x_max - raggio_effettivo, y_min, x_max - raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
          tx := x_min + raggio_effettivo; ty := y_min; ApplicaMatrice(tx, ty, Matrice); GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          ScriviArcoOttimizzato(GCodeList, g_arco, x_min + raggio_effettivo, y_min, start_x, start_y, x_min + raggio_effettivo, y_min + raggio_effettivo, -ZDepth, -ZDepth, Matrice, FormatSettings, avanzamento_XY, False);
        end;
      end;
      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
    end;

    if RPM > 0 then GCodeList.Add('M5');
    GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
    Result := GCodeList.Text;
  finally
    GCodeList.Free;
  end;
end;

function GeneraGCodeRettangoloTuffo(
  x0, y0, larghezza, altezza, raggio, diametro_fresa: Double;
  avanzamento, ZStep, ZDepth, ZSafe: Double;
  tipo_comp: TCompensazione;
  spessore_scavo: Double; // 0 o pari al diametro = passata singola. Maggiore = passate multiple.
  riempimento_totale: Boolean // Se True, svuota tutto l'interno (ignora lo spessore_scavo)
): string;
var
  fresa_raggio, step_over, offset_corrente, offset_massimo: Double;
  x_min, x_max, y_min, y_max: Double;
  raggio_effettivo, start_x, start_y: Double;
  GCodeList: TStringList;
  FormatSettings: TFormatSettings;
  Z: Double;
  fine_scavo: Boolean;
begin
  // Standardizzazione valori passati
  ZStep := abs(ZStep);
  ZDepth := abs(ZDepth);
  ZSafe := abs(ZSafe);
  if ZSafe = 0 then ZSafe := 5;
  spessore_scavo := abs(spessore_scavo);

  // Controllo validità parametri geometrici nominali
  if (raggio * 2 > larghezza) or (raggio * 2 > altezza) then
    raise Exception.Create('Il raggio di curvatura è troppo grande per le dimensioni del rettangolo.');

  if (raggio < 0) or (diametro_fresa <= 0) then
    raise Exception.Create('Raggio non valido o diametro fresa deve essere maggiore di zero.');

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';

  fresa_raggio := diametro_fresa / 2;

  // Lo StepOver è il passo laterale tra le passate. Di solito è il 50%-70% del diametro fresa.
  // Qui impostiamo il 60% per garantire la corretta sovrapposizione ed evitare "creste" di materiale.
  step_over := diametro_fresa * 0.60;

  GCodeList := TStringList.Create;
  try
    GCodeList.Add('; --- Inizio Rettangolo Avanzato ---');
    GCodeList.Add(Format('; Diametro fresa: %fmm | Passo Laterale (StepOver): %fmm', [diametro_fresa, step_over], FormatSettings));
    GCodeList.Add('G21 ; Unità in mm');
    GCodeList.Add('G90 ; Posizionamento assoluto');

    // 1. GESTIONE DELLA PROFONDITÀ (Ciclo Z principale)
    Z := -ZStep;
    while (Z >= -ZDepth) do
    begin
      GCodeList.Add(Format('; --- Livello Z: %f ---', [Z], FormatSettings));

      // Inizializziamo l'offset iniziale in base al tipo di compensazione scelta
      if tipo_comp = compEsterna then
        offset_corrente := fresa_raggio
      else
        offset_corrente := -fresa_raggio;

      // Calcolo dell'estensione massima dell'offset laterale
      if riempimento_totale and (tipo_comp = compInterna) then
        // Se dobbiamo svuotare tutto l'interno, il limite è il centro del lato più corto
        if larghezza < altezza then offset_massimo := -(larghezza / 2) else offset_massimo := -(altezza / 2)
      else if spessore_scavo > diametro_fresa then
        // Se lo spessore richiesto è maggiore della fresa, calcoliamo lo spostamento extra
        if tipo_comp = compEsterna then
          offset_massimo := fresa_raggio + (spessore_scavo - diametro_fresa)
        else
          offset_massimo := -fresa_raggio - (spessore_scavo - diametro_fresa)
      else
        // Passata singola standard
        offset_massimo := offset_corrente;

      fine_scavo := False;

      // 2. GESTIONE DELLE PASSATE LATERALI CONCENTRICHE (Ciclo Offset)
      while not fine_scavo do
      begin
        // Calcolo delle coordinate rettangolari correnti modificate dall'offset corrente
        x_min := x0 - offset_corrente;
        x_max := x0 + larghezza + offset_corrente;
        y_min := y0 - offset_corrente;
        y_max := y0 + altezza + offset_corrente;

        // Calcolo del raggio d'angolo modificato per questa specifica passata
        raggio_effettivo := raggio + offset_corrente;
        if raggio_effettivo < 0 then raggio_effettivo := 0; // Protezione per geometrie interne strette

        // Controllo di sicurezza per evitare il collasso delle geometrie interne
        if (tipo_comp = compInterna) and ((x_max <= x_min) or (y_max <= y_min)) then
        begin
          fine_scavo := True;
          Break;
        end;

        // --- Generazione codice di Movimento per il rettangolo corrente ---
        if raggio_effettivo = 0 then
        begin
          // Rettangolo a spigoli vivi
          GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
          GCodeList.Add(Format('G0 X%f Y%f', [x_min, y_min], FormatSettings));
          GCodeList.Add(Format('G1 Z%f F%f', [Z, avanzamento], FormatSettings));
          GCodeList.Add(Format('G1 X%f Y%f F%f', [x_max, y_min, avanzamento], FormatSettings));
          GCodeList.Add(Format('G1 X%f Y%f', [x_max, y_max], FormatSettings));
          GCodeList.Add(Format('G1 X%f Y%f', [x_min, y_max], FormatSettings));
          GCodeList.Add(Format('G1 X%f Y%f', [x_min, y_min], FormatSettings));
        end
        else
        begin
          // Rettangolo ad angoli arrotondati
          start_x := x_min + raggio_effettivo;
          start_y := y_min;

          GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
          GCodeList.Add(Format('G0 X%f Y%f', [start_x, start_y], FormatSettings));
          GCodeList.Add(Format('G1 Z%f F%f', [Z, avanzamento], FormatSettings));

          // Lato inferiore -> Arco in basso a destra
          GCodeList.Add(Format('G1 X%f Y%f F%f', [x_max - raggio_effettivo, y_min, avanzamento], FormatSettings));
          GCodeList.Add(Format('G3 X%f Y%f I0 J%f', [x_max, y_min + raggio_effettivo, raggio_effettivo], FormatSettings));

          // Lato destro -> Arco in alto a destra
          GCodeList.Add(Format('G1 X%f Y%f', [x_max, y_max - raggio_effettivo], FormatSettings));
          GCodeList.Add(Format('G3 X%f Y%f I%f J0', [x_max - raggio_effettivo, y_max, -raggio_effettivo], FormatSettings));

          // Lato superiore -> Arco in alto a sinistra
          GCodeList.Add(Format('G1 X%f Y%f', [x_min + raggio_effettivo, y_max], FormatSettings));
          GCodeList.Add(Format('G3 X%f Y%f I0 J%f', [x_min, y_max - raggio_effettivo, -raggio_effettivo], FormatSettings));

          // Lato sinistro -> Arco in basso a sinistra
          GCodeList.Add(Format('G1 X%f Y%f', [x_min, y_min + raggio_effettivo], FormatSettings));
          GCodeList.Add(Format('G3 X%f Y%f I%f J0', [start_x, start_y, raggio_effettivo], FormatSettings));
        end;

        // --- Incremento e controllo del passo laterale ---
        if tipo_comp = compEsterna then
        begin
          if offset_corrente >= offset_massimo then fine_scavo := True
          else
          begin
            offset_corrente := offset_corrente + step_over;
            if offset_corrente > offset_massimo then offset_corrente := offset_massimo;
          end;
        end
        else // compInterna
        begin
          if offset_corrente <= offset_massimo then fine_scavo := True
          else
          begin
            offset_corrente := offset_corrente - step_over;
            if offset_corrente < offset_massimo then offset_corrente := offset_massimo;
          end;
        end;
      end;

      // Gestione della passata finale esatta a ZDepth se il ciclo a step la salta
      if (Z > -ZDepth) and (Z - ZStep < -ZDepth) then Z := -ZDepth
      else Z := Z - ZStep;
    end;

    GCodeList.Add('G0 Z' + FloatToStr(ZSafe, FormatSettings) + ' ; Ritorno a quota di sicurezza');
    GCodeList.Add('; --- Fine Rettangolo Avanzato ---');
    Result := GCodeList.Text;
  finally
    GCodeList.Free;
  end;
end;

function GeneraGCodeForoElicoidale(         //Spessore singolo
  XCentro, YCentro, DiametroForo, DiametroFresa, ProfonditaTotale, PassoZ: Double;
  AvanzamentoXY: Double;
  AvanzamentoZ: Double; ZSafe:double): string;
var
  RaggioTraiettoria, StartX, StartY, ZAttuale: Double;
  GCode: TStringList;
  FS: TFormatSettings;
begin
  // Validazione input
  if DiametroForo <= DiametroFresa then
    raise Exception.Create('Il diametro del foro deve essere maggiore del diametro della fresa.');
  if (ProfonditaTotale <= 0) or (PassoZ <= 0) then
    raise Exception.Create('Profondità e passo Z devono essere valori positivi.');

  // Configurazione formattazione numerica con punto decimale (.)
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  // Calcolo della traiettoria del CENTRO fresa
  RaggioTraiettoria := (DiametroForo - DiametroFresa) / 2.0;
  StartX := XCentro + RaggioTraiettoria;
  StartY := YCentro;

  GCode := TStringList.Create;
  try
    GCode.Add('; --- Inizio Foratura Elicoidale ---');
    GCode.Add(Format('; Foro Ø: %fmm | Fresa Ø: %fmm', [DiametroForo, DiametroFresa], FS));
    GCode.Add('G21 ; Unità in mm');
    GCode.Add('G90 ; Posizionamento assoluto');

    // 1. Posizionamento rapido sopra il centro del foro
    GCode.Add(Format('G0 Z%f ;ZSafe', [ZSafe], FormatSettings));
    //GCode.Add(Format('G0 X%.3f Y%.3f', [XCentro, YCentro], FS));

    // 2. Discesa a Z0 e spostamento sul punto di inizio cerchio
    //GCode.Add(Format('G1 Z0.0 F%.1f', [AvanzamentoZ], FS));
    GCode.Add(Format('G1 X%.3f Y%.3f F%.1f', [StartX, StartY, AvanzamentoXY], FS));
    GCode.Add(Format('G1 Z0.0 F%.1f', [AvanzamentoZ], FS));

    // 3. Ciclo per le passate elicoidali
    ZAttuale := 0.0;
    while ZAttuale > -ProfonditaTotale do
    begin
      ZAttuale := ZAttuale - PassoZ;
      if ZAttuale < -ProfonditaTotale then
        ZAttuale := -ProfonditaTotale;

      GCode.Add(Format('G3 X%.3f Y%.3f Z%.3f I%.3f J0.0 F%.1f',
        [StartX, StartY, ZAttuale, -RaggioTraiettoria, AvanzamentoXY], FS));
    end;

    // 4. Passata di finitura a fondo foro
    GCode.Add(Format('G3 X%.3f Y%.3f I%.3f J0.0', [StartX, StartY, -RaggioTraiettoria], FS));

    // 5. Ritorno al centro del foro
    //GCode.Add(Format('G1 X%.3f Y%.3f', [XCentro, YCentro], FS));

    // 6. Sollevamento rapido
    GCode.Add(Format('G0 Z%f ;ZSafe', [ZSafe], FormatSettings));
    GCode.Add('; --- Fine Foratura ---');

    Result := GCode.Text;
  finally
    GCode.Free;
  end;
end;

function GeneraGCodeCerchioElicoidale(
 xc, yc, raggio, diametro_fresa: Double;
 avanzamento, ZStep, ZDepth, ZSafe: Double;
 tipo_comp: TCompensazione;
 spessore_scavo: Double;
 riempimento_totale: Boolean
): string;
var
 fresa_raggio, step_over, offset_corrente, offset_massimo: Double;
 raggio_effettivo, start_x, start_y: Double;
 GCodeList: TStringList;
 FormatSettings: TFormatSettings;
 z_corrente, z_target_giro: Double;
 fine_scavo, ultima_passata_z: Boolean;
begin
 // Standardizzazione valori passati
 ZStep := abs(ZStep);
 ZDepth := abs(ZDepth);
 ZSafe := abs(ZSafe);
 if ZSafe = 0 then ZSafe := 5;
 spessore_scavo := abs(spessore_scavo);

 if (raggio <= 0) or (diametro_fresa <= 0) then
   raise Exception.Create('Raggio e diametro fresa devono essere maggiori di zero.');

 FormatSettings := DefaultFormatSettings;
 FormatSettings.DecimalSeparator := '.';
 fresa_raggio := diametro_fresa / 2;
 step_over := diametro_fresa * 0.60;
 GCodeList := TStringList.Create;

 try
   GCodeList.Add('; --- Inizio Cerchio con Rampa Elicoidale Continua ---');
   GCodeList.Add(Format('; Diametro fresa: %fmm | Rampa Z-Step per giro: %fmm', [diametro_fresa, ZStep], FormatSettings));
   GCodeList.Add('G21 ; Unità in mm');
   GCodeList.Add('G90 ; Posizionamento assoluto');

   // Inizializziamo l'offset iniziale in base alla compensazione
   if tipo_comp = compEsterna then
     offset_corrente := fresa_raggio
   else
     offset_corrente := -fresa_raggio;

   // Calcolo dell'offset massimo per lo svuotamento laterale
   if riempimento_totale and (tipo_comp = compInterna) then
     offset_massimo := -raggio
   else if spessore_scavo > diametro_fresa then
     if tipo_comp = compEsterna then
       offset_massimo := fresa_raggio + (spessore_scavo - diametro_fresa)
     else
       offset_massimo := -fresa_raggio - (spessore_scavo - diametro_fresa)
   else
     offset_massimo := offset_corrente;

   fine_scavo := False;

   // CICLO 1: Spostamento Laterale (Anelli Concentrici)
   while not fine_scavo do
   begin
     raggio_effettivo := raggio + offset_corrente;

     // Se il raggio diventa nullo o negativo nello svuotamento interno, ci fermiamo
     if (tipo_comp = compInterna) and (raggio_effettivo <= 0) then
     begin
       fine_scavo := True;
       Break;
     end;

     GCodeList.Add(Format('; --- Lavorazione Anello Offset: %f (Raggio Effettivo: %f) ---', [offset_corrente, raggio_effettivo], FormatSettings));

     // Punto di attacco a ore 9 (sinistra del cerchio) per fare archi in senso antiorario (G3)
     start_x := xc - raggio_effettivo;
     start_y := yc;

     // Posizionamento rapido iniziale a quota di sicurezza e sul punto di attacco
     GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
     GCodeList.Add(Format('G0 X%f Y%f', [start_x, start_y], FormatSettings));
     GCodeList.Add('G1 Z0 F' + FloatToStr(avanzamento, FormatSettings) + ' ; Appoggio sulla superficie');

     z_corrente := 0;
     ultima_passata_z := False;

     // CICLO 2: Discesa Elicoidale (Rampa in Z per l'anello corrente)
     while not ultima_passata_z do
     begin
       // Calcolo della Z target per questo specifico giro completo
       if (z_corrente - ZStep) <= -ZDepth then
       begin
         z_target_giro := -ZDepth;
         ultima_passata_z := True; // Il prossimo ciclo sarà l'ultimo di pulizia a Z fissa
       end
       else
       begin
         z_target_giro := z_corrente - ZStep;
       end;

       // Esegue un cerchio completo in G3 (CCW) distribuendo la discesa in Z su tutto il giro
       // Con punto iniziale a (xc - R), il centro si trova a X relativo +R (I = raggio_effettivo, J = 0)
       GCodeList.Add(Format('G3 X%f Y%f Z%f I%f J0', [start_x, start_y, z_target_giro, raggio_effettivo], FormatSettings));

       z_corrente := z_target_giro;
     end;

     // --- PASSATA DI PULIZIA FINALE A Z FISSA (-ZDepth) ---
     GCodeList.Add('; Passata di spianatura fondo a Z fissa');
     GCodeList.Add(Format('G3 X%f Y%f I%f J0', [start_x, start_y, raggio_effettivo], FormatSettings));

     // Disimpegno rapido in Z prima di passare al cerchio concentrico successivo
     GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));

     // Incremento del passo laterale per il ciclo degli anelli
     if tipo_comp = compEsterna then
     begin
       if offset_corrente >= offset_massimo then
         fine_scavo := True
       else
       begin
         offset_corrente := offset_corrente + step_over;
         if offset_corrente > offset_massimo then offset_corrente := offset_massimo;
       end;
     end
     else
     begin
       if offset_corrente <= offset_massimo then
         fine_scavo := True
       else
       begin
         offset_corrente := offset_corrente - step_over;
         if offset_corrente < offset_massimo then offset_corrente := offset_massimo;
       end;
     end;
   end;

   GCodeList.Add('G0 Z' + FloatToStr(ZSafe, FormatSettings) + ' ; Fine corsa di sicurezza');
   GCodeList.Add('; --- Fine Cerchio ---');
   Result := GCodeList.Text;
 finally
   GCodeList.Free;
 end;
end;

function GeneraGCodeCerchioSvuotamentoElicoidale(
  xc, yc, raggio, diametro_fresa: Double;
  avanzamento_XY, avanzamento_Z, RPM: Double;
  ZStep, MaxRampAngle, ZStart, ZDepth, ZSafe: Double;
  tipo_comp: byte;
  direzione: byte;
  spessore_scavo: Double;
  FinishAllowance: Double;
  riempimento_totale: Boolean;
  const Matrice: TTransformationMatrix
): string;
var
  fresa_raggio, step_over, offset_corrente, offset_massimo: Double;
  raggio_effettivo, start_x, start_y: Double;
  GCodeList: TStringList;
  FormatSettings: TFormatSettings;
  z_corrente, z_target_giro, z_step_dinamico: Double;
  fine_scavo, ultima_passata_z: Boolean;
  perimetro_cerchio, z_step_angolo: Double;
  usa_orario: Boolean;
  g_arco: string;
  tx, ty, tI, tJ: Double;
  DeformaCerchio: Boolean;
  passi_per_giro, step_giro: Integer;
  theta_s, theta_diff, theta_corrente, z_segmento: Double;
begin
  ZStep           := abs(ZStep);
  MaxRampAngle    := abs(MaxRampAngle);
  ZStart          := abs(ZStart);
  ZDepth          := abs(ZDepth);
  ZSafe           := abs(ZSafe);
  if ZSafe = 0 then ZSafe := 5;
  spessore_scavo  := abs(spessore_scavo);
  FinishAllowance := abs(FinishAllowance);

  if ZStart >= ZDepth then
    raise Exception.Create('ZStart deve essere minore della profondità totale ZDepth.');
  if (raggio <= 0) then
    raise Exception.Create('Raggio deve essere maggiore di zero.');

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  fresa_raggio := diametro_fresa / 2;
  step_over := diametro_fresa * 0.60;

  if (tipo_comp = 0) or (tipo_comp = 2) then
    usa_orario := (direzione = 0)
  else
    usa_orario := (direzione = 1);

  if usa_orario then g_arco := 'G2' else g_arco := 'G3';

  DeformaCerchio := not IsMatrixCircularPreserving(Matrice);
  passi_per_giro := 72;

  GCodeList := TStringList.Create;
  try
    GCodeList.Add('; --- Cerchio Elicoidale Bilanciato ed Esente da Deformazioni ---');
    GCodeList.Add('G21 ; mm | G90 ; Assoluto');

    if RPM > 0 then GCodeList.Add(Format('S%f M3', [RPM], FormatSettings));

    // --- Inizializzazione Offset Iniziale ---
        if tipo_comp = 1 then
          offset_corrente := fresa_raggio + FinishAllowance
        else if tipo_comp = 0 then
          offset_corrente := -fresa_raggio - FinishAllowance
        else // tipo_comp = 2 (Nessuna compensazione / Centrato)
        begin
          if spessore_scavo > diametro_fresa then
            offset_corrente := -(spessore_scavo - diametro_fresa) / 2.0
          else
            offset_corrente := 0.0;
        end;

        // --- Inizializzazione Offset Massimo ---
        if (tipo_comp = 2) then
        begin
          if spessore_scavo > diametro_fresa then
            offset_massimo := (spessore_scavo - diametro_fresa) / 2.0
          else
            offset_massimo := 0.0;
        end
        else if riempimento_totale and (tipo_comp = 0) then
          offset_massimo := -raggio
        else if spessore_scavo > diametro_fresa then
        begin
          if tipo_comp = 1 then offset_massimo := fresa_raggio + (spessore_scavo - diametro_fresa)
          else offset_massimo := -fresa_raggio - (spessore_scavo - diametro_fresa);
        end
        else
          offset_massimo := offset_corrente;

    fine_scavo := False;

    if (tipo_comp = 0) and (not riempimento_totale) and (spessore_scavo >= diametro_fresa) then
    begin
      offset_corrente := offset_massimo;
      offset_massimo := -fresa_raggio - FinishAllowance;
    end;

    while not fine_scavo do
    begin
      raggio_effettivo := raggio + offset_corrente;

      if (tipo_comp = 0) and (raggio_effettivo <= 0) then
      begin
        if riempimento_totale then
        begin
          tx := xc; ty := yc; ApplicaMatrice(tx, ty, Matrice);
          GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
          GCodeList.Add(Format('G0 X%f Y%f', [tx, ty], FormatSettings));
          GCodeList.Add(Format('G1 Z-%f F%f', [ZDepth, avanzamento_Z], FormatSettings));
          GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
        end;
        fine_scavo := True; Break;
      end;

      perimetro_cerchio := 2.0 * Pi * raggio_effettivo;
      z_step_dinamico := ZStep;
      if MaxRampAngle > 0 then
      begin
        z_step_angolo := perimetro_cerchio * Tan(MaxRampAngle * Pi / 180.0);
        if z_step_angolo < z_step_dinamico then z_step_dinamico := z_step_angolo;
      end;
      if z_step_dinamico < 0.1 then z_step_dinamico := 0.1;

      GCodeList.Add(Format('; --- Anello Corrente Reff: %f ---', [raggio_effettivo], FormatSettings));

      start_x := xc - raggio_effettivo; start_y := yc;
      tx := start_x; ty := start_y; ApplicaMatrice(tx, ty, Matrice);

      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
      GCodeList.Add(Format('G0 X%f Y%f', [tx, ty], FormatSettings));
      GCodeList.Add(Format('G1 Z-%f F%s', [ZStart, FloatToStr(avanzamento_Z, FormatSettings)], FormatSettings));

      z_corrente := -ZStart;
      ultima_passata_z := False;

      while not ultima_passata_z do
      begin
        if (z_corrente - z_step_dinamico) <= -ZDepth then
        begin
          z_target_giro := -ZDepth; ultima_passata_z := True;
        end
        else
          z_target_giro := z_corrente - z_step_dinamico;

        if not DeformaCerchio then
        begin
          tx := start_x; ty := start_y; ApplicaMatrice(tx, ty, Matrice);
          tI := xc - start_x; tJ := yc - start_y;
          tI := Matrice.a * tI + Matrice.c * tJ;
          tJ := Matrice.b * (xc - start_x) + Matrice.d * (yc - start_y);
          GCodeList.Add(Format('%s X%f Y%f Z%f I%f J%f F%s', [g_arco, tx, ty, z_target_giro, tI, tJ, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
        end
        else
        begin
          theta_s := Pi;
          if not usa_orario then theta_diff := 2.0 * Pi else theta_diff := -2.0 * Pi;

          for step_giro := 1 to passi_per_giro do
          begin
            theta_corrente := theta_s + (step_giro / passi_per_giro) * theta_diff;
            tx := xc + raggio_effettivo * Cos(theta_corrente);
            ty := yc + raggio_effettivo * Sin(theta_corrente);
            z_segmento := z_corrente + (step_giro / passi_per_giro) * (z_target_giro - z_corrente);
            ApplicaMatrice(tx, ty, Matrice);
            GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, z_segmento], FormatSettings));
          end;
        end;
        z_corrente := z_target_giro;
      end;

      GCodeList.Add('; Passata di spianatura fondo a Z fissa');
      if not DeformaCerchio then
      begin
        tx := start_x; ty := start_y; ApplicaMatrice(tx, ty, Matrice);
        tI := xc - start_x; tJ := yc - start_y;
        tI := Matrice.a * tI + Matrice.c * tJ;
        tJ := Matrice.b * (xc - start_x) + Matrice.d * (yc - start_y);
        GCodeList.Add(Format('%s X%f Y%f I%f J%f', [g_arco, tx, ty, tI, tJ], FormatSettings));
      end
      else
      begin
        theta_s := Pi;
        if not usa_orario then theta_diff := 2.0 * Pi else theta_diff := -2.0 * Pi;
        for step_giro := 1 to passi_per_giro do
        begin
          theta_corrente := theta_s + (step_giro / passi_per_giro) * theta_diff;
          tx := xc + raggio_effettivo * Cos(theta_corrente);
          ty := yc + raggio_effettivo * Sin(theta_corrente);
          ApplicaMatrice(tx, ty, Matrice);
          GCodeList.Add(Format('G1 X%f Y%f Z%f', [tx, ty, -ZDepth], FormatSettings));
        end;
      end;

      GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));

      if offset_massimo > offset_corrente then
      begin
        if offset_corrente >= offset_massimo then fine_scavo := True
        else begin
          offset_corrente := offset_corrente + step_over;
          if offset_corrente > offset_massimo then offset_corrente := offset_massimo;
        end;
      end
      else
      begin
        if offset_corrente <= offset_massimo then fine_scavo := True
        else begin
          offset_corrente := offset_corrente - step_over;
          if offset_corrente < offset_massimo then offset_corrente := offset_massimo;
        end;
      end;
    end;

    if (FinishAllowance > 0) and (tipo_comp in [0, 1]) then
    begin
      GCodeList.Add('; --- Passata Finale di Finitura Pareti ---');
      if tipo_comp = 1 then offset_corrente := fresa_raggio else offset_corrente := -fresa_raggio;
      raggio_effettivo := raggio + offset_corrente;

      if raggio_effettivo > 0 then
      begin
        start_x := xc - raggio_effettivo; start_y := yc;
        tx := start_x; ty := start_y; ApplicaMatrice(tx, ty, Matrice);

        GCodeList.Add(Format('G0 X%f Y%f', [tx, ty], FormatSettings));
        GCodeList.Add(Format('G1 Z-%f F%s', [ZDepth, FloatToStr(avanzamento_Z, FormatSettings)], FormatSettings));

        if not DeformaCerchio then
        begin
          tI := xc - start_x; tJ := yc - start_y;
          tI := Matrice.a * tI + Matrice.c * tJ;
          tJ := Matrice.b * (xc - start_x) + Matrice.d * (yc - start_y);
          GCodeList.Add(Format('%s X%f Y%f I%f J%f F%s', [g_arco, tx, ty, tI, tJ, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings));
        end
        else
        begin
          theta_s := Pi;
          if not usa_orario then theta_diff := 2.0 * Pi else theta_diff := -2.0 * Pi;
          for step_giro := 1 to passi_per_giro do
          begin
            theta_corrente := theta_s + (step_giro / passi_per_giro) * theta_diff;
            tx := xc + raggio_effettivo * Cos(theta_corrente);
            ty := yc + raggio_effettivo * Sin(theta_corrente);
            ApplicaMatrice(tx, ty, Matrice);
            if step_giro = 1 then
              GCodeList.Add(Format('G1 X%f Y%f F%s', [tx, ty, FloatToStr(avanzamento_XY, FormatSettings)], FormatSettings))
            else
              GCodeList.Add(Format('G1 X%f Y%f', [tx, ty], FormatSettings));
          end;
        end;
        GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
      end;
    end;

    if RPM > 0 then GCodeList.Add('M5');
    GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
    Result := GCodeList.Text;
  finally
    GCodeList.Free;
  end;
end;

function GeneraGCodeTracciaCerchioElicoidale(
 xc, yc, raggio, diametro_fresa: Double;
 avanzamento, ZStep, ZDepth, ZSafe: Double;
 tipo_comp: TCompensazione
): string;
var
 fresa_raggio, raggio_effettivo: Double;
 start_x, start_y: Double;
 GCodeList: TStringList;
 FormatSettings: TFormatSettings;
 z_corrente, z_target_giro: Double;
 ultima_passata_z: Boolean;
begin
 // Standardizzazione valori
 ZStep := abs(ZStep);
 ZDepth := abs(ZDepth);
 ZSafe := abs(ZSafe);
 if ZSafe = 0 then ZSafe := 5;

 if (raggio <= 0) or (diametro_fresa <= 0) then
   raise Exception.Create('Raggio e diametro fresa devono essere maggiori di zero.');

 FormatSettings := DefaultFormatSettings;
 FormatSettings.DecimalSeparator := '.';
 fresa_raggio := diametro_fresa / 2;

 // Calcolo del raggio di lavoro in base alla compensazione richiesta
 if tipo_comp = compEsterna then
   raggio_effettivo := raggio + fresa_raggio
 else if tipo_comp = compInterna then
   raggio_effettivo := raggio - fresa_raggio
 else
   raggio_effettivo := raggio; // Centro utensile sulla linea se non specificato

 if raggio_effettivo <= 0 then
   raise Exception.Create('Il raggio effettivo è minore o uguale a zero. Fresa troppo grande.');

 GCodeList := TStringList.Create;
 try
   GCodeList.Add('; --- Inizio Cerchio Decorativo (Traccia Singola in Rampa) ---');
   GCodeList.Add('G21 ; Unità in mm');
   GCodeList.Add('G90 ; Posizionamento assoluto');

   // Punto di attacco sul perimetro (a sinistra, ore 9)
   start_x := xc - raggio_effettivo;
   start_y := yc;

   // 1. Posizionamento rapido in aria sopra il punto di inizio della traccia
   GCodeList.Add(Format('G0 Z%f', [ZSafe], FormatSettings));
   GCodeList.Add(Format('G0 X%f Y%f', [start_x, start_y], FormatSettings));

   // 2. Discesa rapida a Z0 (sfioramento materiale)
   GCodeList.Add(Format('G1 Z0 F%f ; Appoggio sulla superficie', [avanzamento], FormatSettings));

   z_corrente := 0;
   ultima_passata_z := False;

   // 3. Discesa Elicoidale Continua lungo la circonferenza
   while not ultima_passata_z do
   begin
     if (z_corrente - ZStep) <= -ZDepth then
     begin
       z_target_giro := -ZDepth;
       ultima_passata_z := True; // Il prossimo sarà il giro di pulizia a fondo piatto
     end
     else
     begin
       z_target_giro := z_corrente - ZStep;
     end;

     // Esegue un cerchio completo scendendo in Z (Interpolazione elicoidale)
     GCodeList.Add(Format('G3 X%f Y%f Z%f I%f J0', [start_x, start_y, z_target_giro, raggio_effettivo], FormatSettings));

     z_corrente := z_target_giro;
   end;

   // 4. Passata di finitura a Z fissa (spiana il fondo della traccia)
   GCodeList.Add('; Passata di spianatura fondo a Z fissa');
   GCodeList.Add(Format('G3 X%f Y%f I%f J0', [start_x, start_y, raggio_effettivo], FormatSettings));

   // 5. Ritiro finale in sicurezza
   GCodeList.Add(Format('G0 Z%f ; Disimpegno di sicurezza', [ZSafe], FormatSettings));
   GCodeList.Add('; --- Fine Cerchio Decorativo ---');

   Result := GCodeList.Text;
 finally
   GCodeList.Free;
 end;
end;

function GenerateTextGCode(const TextStr: string; const FontPath: string;
  FontSize: Integer; const Options: TGCodeOptions):string;
var
  Bmp: TBitmap;
  X, Y: Integer;
  CurZ: Double;
  Passata: Integer;
  NumPassate: Integer;
  RaggioFresa: Double;
  RealX,RealY:double;
  OutputList: TStringList;
begin
  result:='';
  OutputList:=TStringList.Create;
  OutputList.Clear;
  if (TextStr = '') or (FontPath='') or (Options.ZStep <= 0) then Exit;

  Bmp := TBitmap.Create;
  try
    // Carica il font TTF nel sistema per la sessione corrente
    //Screen.Fonts.Add(FontPath);
    Bmp.Canvas.Font.Name := FontPath;
    Bmp.Canvas.Font.Size := FontSize;
    Bmp.Canvas.Font.Color := clBlack;
    Bmp.Canvas.Brush.Color := clWhite;

    // Calcola le dimensioni del testo
    Bmp.Width := Bmp.Canvas.TextWidth(TextStr) + 20;
    Bmp.Height := Bmp.Canvas.TextHeight(TextStr) + 20;

    // Disegna il testo sulla bitmap
    Bmp.Canvas.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    Bmp.Canvas.TextOut(10, 10, TextStr);
    Bmp.SaveToFile('/home/tommaso/jjjj.bmp');
    // Inizializzazione parametri G-code
    RaggioFresa := Options.ToolDiameter / 2.0;
    NumPassate := Ceil(Abs(Options.ZDepth) / Options.ZStep);

    // Intestazione G-code
    OutputList.Add('( G-Code Generato da Lazarus )');
    OutputList.Add(Format('G21 (Unità in mm)', []));
    OutputList.Add(Format('G90 (Coordinate assolute)', []));
    OutputList.Add(Format('G00 Z%.3f (Posizionamento quota sicurezza)', [Options.ZSafe]));

    // Ciclo Multipassata (Profondità Z)
    for Passata := 1 to NumPassate do
    begin
      CurZ := Options.ZStart - (Passata * Options.ZStep);
      if CurZ < Options.ZDepth then CurZ := Options.ZDepth; // Limita alla profondità massima

      OutputList.Add(Format('( --- PASSATA %d su %d a Z%.3f --- )', [Passata, NumPassate, CurZ]));

      // Scansione semplificata dei pixel neri (contorno/percorso)
      // Nota: Questo algoritmo segue i pixel. Per una fresatura reale traccia le linee.
      for Y := 0 to Bmp.Height - 1 do
      begin
        for X := 0 to Bmp.Width - 1 do
        begin
          // Se il pixel è nero, consideriamo il punto come percorso utensile
          if Bmp.Canvas.Pixels[X, Y] <> clWhite then
          begin
            // Calcolo delle coordinate reali considerando offset X/Y e compensazione raggio fresa
            // Invertiamo la Y perché nei font l'origine è in alto a sinistra, nel CNC in basso a sinistra
            RealX := Options.XStart + X + RaggioFresa;
            RealY := Options.YStart + (Bmp.Height - Y) + RaggioFresa;

            // Spostamento rapido sopra il punto
            OutputList.Add(Format('G00 X%.3f Y%.3f', [RealX, RealY]));
            // Affondamento alla Z corrente della passata
            OutputList.Add(Format('G01 Z%.3f F%.1f', [CurZ, Options.ZFeedRate]));
            // Esecuzione micro-taglio (punto singolo o linea se si estende l'algoritmo)
            OutputList.Add(Format('G01 X%.3f Y%.3f F%.1f', [RealX, RealY, Options.XYFeedRate]));
            // Ritorno in sicurezza prima di muoversi al prossimo pixel slegato
            OutputList.Add(Format('G00 Z%.3f', [Options.ZSafe]));
          end;
        end;
      end;
    end;

    // Fine Programma
    OutputList.Add('G00 Z' + Format('%.3f', [Options.ZSafe]));
    //OutputList.Add('M30 (Fine programma)');

  finally
    Bmp.Free;
  end;
  result:=OutputList.Text;
  OutputList.Free;
end;

type
  TVertexType = (vtMoveTo, vtLineTo);

  TPathPoint = record
    X, Y: Double;
    PType: TVertexType;
  end;

function GenerateVectorTextGCode(const TextStr: string; const FontPath: string;
  const Options: TGCodeOptions):string;
var
  Font: TFreeTypeFont;
  Glyph: TFreeTypeGlyph;
  I, CharIdx, ContourIdx, PointIdx: Integer;
  NumPassate: Integer;
  Passata: Integer;
  CurZ: Double;
  RaggioFresa: Double;
  XOffset: Double;
  OutputList: TStringList;
  // Lista dinamica dei punti che compongono l'intero testo
  TextPoints: array of TPathPoint;
  PtCount: Integer;
  GlyphIndex: Integer;
  GlyphOutline: TT_Outline;
  ContourCount,PointsInContour: Integer;
  StartIdx, EndIdx,ActualPtIdx: Integer;
  RawX,RawY,P1X,P1Y,NextX,NextY:double;
  AdvanceMetrics:TT_Glyph_Metrics;
  ZDepth:double;
  CurrX,CurrY:double;
  P2X, P2Y: Double;
  NextPtIdx: Integer;
  StepIdx,Steps:integer;
  T,T1,TSq,TwoT1T,TSq2,BX,BY:double;
  StartX,StartY:double;
  ScaleFactor:double;

  procedure AddPoint(AX, AY: Double; AType: TVertexType);
  begin
    Inc(PtCount);
    SetLength(TextPoints, PtCount);
    TextPoints[PtCount - 1].X := AX;
    TextPoints[PtCount - 1].Y := AY;
    TextPoints[PtCount - 1].PType := AType;
  end;

begin
  if (TextStr = '') or (Options.ZStep <= 0) then Exit;
  OutputList:=TStringList.Create;
  PtCount := 0;
  XOffset := 0;
  RaggioFresa := Options.ToolDiameter / 2.0;

  // 1. ESTRAZIONE DEI VETTORI DAL FONT TTF
  Font := TFreeTypeFont.Create;
  try
    Font.Name := FontPath;
    //Font.Style:=[ftsBold];
    ScaleFactor:=options.ScaleFactor;
    ScaleFactor:=ScaleFactor/800;
    for CharIdx := 1 to Length(TextStr) do
    begin
      GlyphIndex := Font.CharIndex[ord(TextStr[CharIdx])];
      Glyph := Font.Glyph[GlyphIndex];
      if Assigned(Glyph) then
      begin
        // Scorri i contorni geometrici della lettera
        if TT_Get_Glyph_Outline(Glyph.Data, GlyphOutline) = 0 then
        begin
          ContourCount := GlyphOutline.n_contours;
          ContourCount := GlyphOutline.n_contours;
          for ContourIdx := 0 to ContourCount - 1 do
          begin
            if ContourIdx = 0 then
              StartIdx := 0
            else
              StartIdx := GlyphOutline.conEnds^[ContourIdx - 1] + 1;

            EndIdx := GlyphOutline.conEnds^[ContourIdx];
            PointsInContour := EndIdx - StartIdx + 1;

            if PointsInContour > 0 then
            begin
              // 1. Carichiamo il primo punto del contorno
              ActualPtIdx := StartIdx;
              RawX := GlyphOutline.points^[ActualPtIdx].x * ScaleFactor;
              RawY := GlyphOutline.points^[ActualPtIdx].y * ScaleFactor;

              CurrX := Options.XStart + XOffset + RawX + RaggioFresa;
              CurrY := Options.YStart + RawY + RaggioFresa;

              // Inizio del profilo (MoveTo)
              AddPoint(CurrX, CurrY, vtMoveTo);

              PointIdx := 1;
              while PointIdx < PointsInContour do
              begin
                ActualPtIdx := StartIdx + PointIdx;

                // Controlla se il punto corrente è di controllo (Off-Curve, bit 0 = 0)
                if (GlyphOutline.flags^[ActualPtIdx] and $01) = 0 then
                begin
                  // P1 = Punto di controllo corrente (Off-Curve)
                  P1X := Options.XStart + XOffset + (GlyphOutline.points^[ActualPtIdx].x * ScaleFactor) + RaggioFresa;
                  P1Y := Options.YStart + (GlyphOutline.points^[ActualPtIdx].y * ScaleFactor) + RaggioFresa;

                  // Determina il punto finale della curva P2

                  if PointIdx = PointsInContour - 1 then
                    NextPtIdx := StartIdx
                  else
                    NextPtIdx := StartIdx + PointIdx + 1;

                  // Gestione speciale TrueType: due punti Off-Curve consecutivi
                  if (GlyphOutline.flags^[NextPtIdx] and $01) = 0 then
                  begin
                    NextX := Options.XStart + XOffset + (GlyphOutline.points^[NextPtIdx].x * ScaleFactor) + RaggioFresa;
                    NextY := Options.YStart + (GlyphOutline.points^[NextPtIdx].y * ScaleFactor) + RaggioFresa;
                    P2X := (P1X + NextX) / 2.0;
                    P2Y := (P1Y + NextY) / 2.0;
                    Inc(PointIdx);
                  end
                  else
                  begin
                    P2X := Options.XStart + XOffset + (GlyphOutline.points^[NextPtIdx].x * ScaleFactor) + RaggioFresa;
                    P2Y := Options.YStart + (GlyphOutline.points^[NextPtIdx].y * ScaleFactor) + RaggioFresa;
                    PointIdx := PointIdx + 2;
                  end;

                  // --- INTERPOLAZIONE MATEMATICA DI BÉZIER DIRETTA ---
                  // Suddividiamo la curva in 10 piccoli segmenti lineari per renderla fluidissima
                  Steps := 10;
                  for StepIdx := 1 to Steps do
                  begin
                    T := StepIdx / Steps;
                    T1 := 1.0 - T;
                    TSq := T1 * T1;
                    TwoT1T := 2.0 * T1 * T;
                    TSq2 := T * T;

                    BX := TSq * CurrX + TwoT1T * P1X + TSq2 * P2X;
                    BY := TSq * CurrY + TwoT1T * P1Y + TSq2 * P2Y;
                    AddPoint(BX, BY, vtLineTo);
                  end;

                  // Aggiorna la posizione attuale con la fine della curva
                  CurrX := P2X;
                  CurrY := P2Y;
                end
                else
                begin
                  // Punto standard On-Curve: traccia una linea retta normale
                  CurrX := Options.XStart + XOffset + (GlyphOutline.points^[ActualPtIdx].x * ScaleFactor) + RaggioFresa;
                  CurrY := Options.YStart + (GlyphOutline.points^[ActualPtIdx].y * ScaleFactor) + RaggioFresa;

                  AddPoint(CurrX, CurrY, vtLineTo);
                  Inc(PointIdx);
                end;
              end;

              // Chiudi il contorno tornando esattamente al punto iniziale se non coincide
              StartX := Options.XStart + XOffset + (GlyphOutline.points^[StartIdx].x * ScaleFactor) + RaggioFresa;
              StartY := Options.YStart + (GlyphOutline.points^[StartIdx].y * ScaleFactor) + RaggioFresa;
              if (Abs(CurrX - StartX) > 0.001) or (Abs(CurrY - StartY) > 0.001) then
                AddPoint(StartX, StartY, vtLineTo);
            end;
          end;
        end;
        // Avanzamento orizzontale per la lettera successiva
        if TT_Get_Glyph_Metrics(Glyph.Data, AdvanceMetrics) = 0 then
          XOffset := XOffset + (AdvanceMetrics.advance * ScaleFactor)
        else
          XOffset := XOffset + ((Glyph.Advance * 64.0)* ScaleFactor);
        //Glyph.Free;
      end;
    end;
  finally
    Font.Free;
  end;

  // 2. GENERAZIONE DEL G-CODE MULTIPASSATA FLUIDO
  if PtCount = 0 then Exit;
  NumPassate := Ceil(Abs(Options.ZDepth) / Options.ZStep);

  // Intestazione G-code standard
  OutputList.Add('( G-Code Vettoriale Fluido - Lazarus )');
  OutputList.Add('G21 (Unità in mm)');
  OutputList.Add('G90 (Coordinate assolute)');
  OutputList.Add(Format('G00 Z%.3f (Posizionamento sicurezza iniziale)', [Options.ZSafe]));
  OutputList.Add(Format('M3 S%d', [Options.SpindleSpeed]));
  ZDepth:=-abs(Options.ZDepth);
  // Ciclo principale delle passate in profondità
  for Passata := 1 to NumPassate do
  begin
    CurZ := Options.ZStart - (Passata * Options.ZStep);
    if CurZ < ZDepth then CurZ := ZDepth; // Protezione limite massimo

    OutputList.Add(Format('( --- INIZIO PASSATA %d A QUOTA Z%.3f --- )', [Passata, CurZ]));

    for I := 0 to PtCount - 1 do
    begin
      case TextPoints[I].PType of
        vtMoveTo:
          begin
            // 1. Spostamento rapido sul piano X Y senza tagliare (Fresa ALTA)
            OutputList.Add(Format('G00 Z%.3f', [Options.ZSafe]));
            OutputList.Add(Format('G00 X%.3f Y%.3f', [TextPoints[I].X, TextPoints[I].Y]));
            // 2. Affondamento verticale controllato (La fresa scende nel materiale)
            OutputList.Add(Format('G01 Z%.3f F%.1f', [CurZ, Options.ZFeedRate]));
          end;

        vtLineTo:
          begin
            // 3. Taglio continuo lungo la linea (La fresa RESTA GIÙ e si muove)
            OutputList.Add(Format('G01 X%.3f Y%.3f F%.1f', [TextPoints[I].X, TextPoints[I].Y, Options.XYFeedRate]));
          end;
      end;
    end;
  end;

  // Fine Lavorazione e disimpegno
  OutputList.Add(Format('G00 Z%.3f (Alzata di sicurezza finale)', [Options.ZSafe]));
  OutputList.Add('M5');
  //OutputList.Add('M30 (Fine programma)');
  result:=OutputList.Text;
  OutputList.Free;
end;

function GenerateCounterboreGCode(Options: TGCodeOptions; DiameterMajor, DepthMajor, DiameterMinor: Double): string;
var
  TransformationMatrix:TTransformationMatrix;
begin
  TransformationMatrix.a:=1;
  TransformationMatrix.b:=0;
  TransformationMatrix.c:=0;
  TransformationMatrix.d:=1;
  TransformationMatrix.e:=0;
  TransformationMatrix.f:=0;
  Options.MaxRampAngle:=5;
  if Options.ZDepth-DepthMajor>0 then
  begin
    result:=GeneraGCodeCerchioSvuotamentoElicoidale(Options.XStart,Options.YStart,DiameterMajor/2,Options.ToolDiameter,Options.XYFeedRate,Options.ZFeedRate,Options.SpindleSpeed,Options.ZStep,Options.MaxRampAngle,Options.ZStart,Options.ZStart+DepthMajor,Options.ZSafe,0,Options.Direction,0,0.2,true,TransformationMatrix);
    result:=result+GeneraGCodeCerchioSvuotamentoElicoidale(Options.XStart,Options.YStart,DiameterMinor/2,Options.ToolDiameter,Options.XYFeedRate,Options.ZFeedRate,Options.SpindleSpeed,Options.ZStep,Options.MaxRampAngle,Options.ZStart+DepthMajor,Options.ZStart+Options.ZDepth,Options.ZSafe,0,Options.Direction,0,0.2,true,TransformationMatrix);
  end
  else
  begin
    result:=';DepthMajor must be bigger than ZDepth';
  end;
end;

function ConvertCNCToLaser(const SourceGCode: string; LaserPower: Integer; UseM4: Boolean): string;
var
  Lines: TStringList;
  OutputList: TStringList;
  i: Integer;
  Line, UpperLine: string;
  ZPos: Double;
  LaserOn: Boolean;
  FormatSettings: TFormatSettings;
  LaserOnCmd: string;

  // Funzione interna per estrarre il valore di un asse (es. Z)
  function GetAxisValue(const CodeLine: string; AxisChar: Char; var Value: Double): Boolean;
  var
    PosAxis, PosSpace: Integer;
    NumStr: string;
  begin
    Result := False;
    PosAxis := Pos(AxisChar, CodeLine);
    if PosAxis > 0 then
    begin
      NumStr := Copy(CodeLine, PosAxis + 1, MaxInt);
      PosSpace := Pos(' ', NumStr);
      if PosSpace > 0 then
        NumStr := Copy(NumStr, 1, PosSpace - 1);

      Result := TryStrToFloat(NumStr, Value, FormatSettings);
    end;
  end;

begin
  Result := '';
  Lines := TStringList.Create;
  OutputList := TStringList.Create;

  // Forza il punto come separatore decimale standard del G-Code
  //FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';

  // Determina se usare M3 (Costante) o M4 (Dinamico)
  if UseM4 then
    LaserOnCmd := 'M4 S' + IntToStr(LaserPower)
  else
    LaserOnCmd := 'M3 S' + IntToStr(LaserPower);

  try
    Lines.Text := SourceGCode;
    LaserOn := False;
    ZPos := 0.0; // Valore iniziale di default (coordinate assolute G90)

    for i := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[i]);
      UpperLine := UpperCase(Line);

      // Salta e trascrive righe vuote o commenti puri
      if (Line = '') or (Line = ';') or (Line = '(') then
      begin
        OutputList.Add(Line);
        Continue;
      end;

      // Aggiorna la coordinata Z se presente nella riga
      GetAxisValue(UpperLine, 'Z', ZPos);

      // Verifica se la riga contiene un comando di movimento
      if (Pos('G0', UpperLine) > 0) or (Pos('G1', UpperLine) > 0) or
         (Pos('G2', UpperLine) > 0) or (Pos('G3', UpperLine) > 0) or
         ((Pos('X', UpperLine) = 0) and (Pos('Y', UpperLine) = 0) and (Pos('Z', UpperLine) > 0)) then
      begin

        // CONDIZIONE 1: Se è un movimento rapido G0, spegne SEMPRE il laser
        if Pos('G0', UpperLine) > 0 then
        begin
          if LaserOn then
          begin
            OutputList.Add('M5 ; Spegne Laser per G0');
            LaserOn := False;
          end;
        end

        // CONDIZIONE 2: Movimenti di lavoro (G1, G2, G3) o affondamenti puri
        else
        begin
          if (ZPos <= 0) then
          begin
            // Se scende sotto lo zero e il laser è spento, lo accende PRIMA del movimento
            if not LaserOn then
            begin
              OutputList.Add(LaserOnCmd + ' ; Accende Laser');
              LaserOn := True;
            end;
          end
          else
          begin
            // Se la Z è sollevata (>0) e il laser è acceso, lo spegne PRIMA del movimento
            if LaserOn then
            begin
              OutputList.Add('M5 ; Spegne Laser (Z > 0)');
              LaserOn := False;
            end;
          end;
        end;
      end;

      // Filtra i vecchi comandi mandrino della fresa (M3, M4, M5) per evitare conflitti
      if (Pos('M3', UpperLine) = 0) and (Pos('M4', UpperLine) = 0) and (Pos('M5', UpperLine) = 0) then
      begin
        OutputList.Add(Line);
      end;
    end;

    // Spegnimento di sicurezza finale
    if LaserOn then
      OutputList.Add('M5 ; Sicurezza finale Laser');

    Result := OutputList.Text;
  finally
    Lines.Free;
    OutputList.Free;
  end;
end;

function ConvertCNCToLaserMultiPass(const SourceGCode: string; LaserPower: Integer; UseM4: Boolean; LaserPasses: Integer;XYFeed:double;rapidFeed:double): string;
var
  Lines, ProfileLines, OutputList: TStringList;
  i, Pass: Integer;
  Line, UpperLine, LaserOnCmd: string;
  ZPos: Double;
  LaserOn: Boolean;
  FormatSettings: TFormatSettings;
  function GetAxisValue(const CodeLine: string; AxisChar: Char; var Value: Double): Boolean;
  var
    PosAxis, PosSpace: Integer;
    NumStr: string;
  begin
    Result := False;
    PosAxis := Pos(AxisChar, CodeLine);
    if PosAxis > 0 then
    begin
      NumStr := Copy(CodeLine, PosAxis + 1, MaxInt);
      PosSpace := Pos(' ', NumStr);
      if PosSpace > 0 then
        NumStr := Copy(NumStr, 1, PosSpace - 1);
      Result := TryStrToFloat(NumStr, Value, FormatSettings);
    end;
  end;

  // Nuova funzione di supporto per rimuovere il parametro Z preservando il resto del comando
  function CleanZMove(const CodeLine: string): string;
  var
    PosZ, i: Integer;
    InComment: Boolean;
  begin
    Result := CodeLine;
    PosZ := Pos('Z', UpperCase(Result));

    // Controlliamo se c'è una Z e che non sia dentro un commento
    if PosZ > 0 then
    begin
      InComment := False;
      for i := 1 to PosZ - 1 do
      begin
        if (Result[i] = ';') or (Result[i] = '(') then
        begin
          InComment := True;
          Break;
        end;
      end;

      if not InComment then
      begin
        // Elimina da 'Z' fino al primo spazio successivo (o fine riga)
        i := PosZ;
        while (i <= Length(Result)) and (Result[i] <> ' ') and (Result[i] <> ';') and (Result[i] <> '(') do
          Inc(i);

        Delete(Result, PosZ, i - PosZ);
        Result := Trim(Result);
      end;
    end;
  end;

begin
  Result := '';
  Lines := TStringList.Create;
  ProfileLines := TStringList.Create;
  OutputList := TStringList.Create;
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';

  if UseM4 then LaserOnCmd := 'M4 S' + IntToStr(LaserPower)
  else LaserOnCmd := 'M3 S' + IntToStr(LaserPower);

  try
    Lines.Text := SourceGCode;
    ZPos := 0.0;

    // --- FASE 1: ESTRAZIONE DEL PROFILO UNICO ---
    for i := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[i]);
      UpperLine := UpperCase(Line);
      if (Line = '') or (Line = ';') or (Line = '(') then Continue;

      GetAxisValue(UpperLine, 'Z', ZPos);
      ProfileLines.Add(Line);
    end;

    // --- FASE 2: GENERAZIONE DEI PASSAGGI LASER ---
    LaserOn := False;
    ZPos := 0.0;
    OutputList.Add(';Laser');
    OutputList.Add('; --- INIZIO CODICE LASER GENERATO ---');
    OutputList.Add('G90 ; Coordinate assolute');
    OutputList.Add(Format('G0 F%f', [rapidFeed], FormatSettings));
    OutputList.Add(Format('G1 F%f', [XYFeed], FormatSettings));
    OutputList.Add(Format('G2 F%f', [XYFeed], FormatSettings));
    OutputList.Add(Format('G3 F%f', [XYFeed], FormatSettings));

    for Pass := 1 to LaserPasses do
    begin
      OutputList.Add('; --- INIZIO PASSATA LASER GENERATA NUMERO: ' + IntToStr(Pass) + ' ---');

      // Se si desidera far scendere l'asse Z gestito elettronicamente a ogni passata,
      // basta decommentare le righe seguenti:
      // CurrentZOffset := -(Pass - 1) * 0.5;
      // OutputList.Add('G0 Z' + FloatToStrF(CurrentZOffset, ffFixed, 1, 3, FormatSettings));

      for i := 0 to ProfileLines.Count - 1 do
      begin
        Line := trim(ProfileLines[i]);
        UpperLine := UpperCase(Line);
        GetAxisValue(UpperLine, 'Z', ZPos);

        if (Pos('G0 ', UpperLine) = 1) or (Pos('G1 ', UpperLine) = 1) or
           (Pos('G2 ', UpperLine) = 1) or (Pos('G3 ', UpperLine) = 1) or
           (Pos('G00 ', UpperLine) = 1) or (Pos('G01 ', UpperLine) = 1) or
           (Pos('G02 ', UpperLine) = 1) or (Pos('G03 ', UpperLine) = 1) or
           ((Pos('X', UpperLine) = 0) and (Pos('Y', UpperLine) = 0) and (Pos('Z', UpperLine) > 0)) then
        begin
          if (Pos('G0 ', UpperLine) = 1)or(Pos('G00 ', UpperLine) = 1) then
          begin
            if LaserOn then
            begin
              OutputList.Add('M5 ; Spegne Laser per G0');
              LaserOn := False;
            end;
          end
          else
          begin
            if (ZPos <= 0) then
            begin
              if not LaserOn then
              begin
                OutputList.Add(LaserOnCmd + ' ; Accende Laser');
                LaserOn := True;
              end;
            end
            else
            begin
              if LaserOn then
              begin
                OutputList.Add('M5 ; Spegne Laser (Z > 0)');
                LaserOn := False;
              end;
            end;
          end;
        end;

        // Copia la riga filtrando i comandi mandrino e pulendo i movimenti Z residui
        if (Pos('M3', UpperLine) = 0) and (Pos('M4', UpperLine) = 0) and (Pos('M5', UpperLine) = 0)and(Pos('M03', UpperLine) = 0) and (Pos('M04', UpperLine) = 0) and (Pos('M05', UpperLine) = 0) then
        begin
          // Se la riga conteneva *solo* un movimento Z (es. "G1 Z-2.000 FX"), la saltiamo
          // Se contiene anche X o Y, rimuoviamo solo la Z
          if (Pos('X', UpperLine) = 0) and (Pos('Y', UpperLine) = 0) and (Pos('Z', UpperLine) > 0) then
            Continue
          else
          begin
            OutputList.Add(CleanZMove(Line));
          end;
        end;
      end;
    end;

    if LaserOn then OutputList.Add('M5 ; Sicurezza finale');
    OutputList.Add(Format('G0 Z%f', [ZPos], FormatSettings));
    OutputList.Add(';-Laser');
    Result := OutputList.Text;
  finally
    Lines.Free;
    ProfileLines.Free;
    OutputList.Free;
  end;
end;


end.

