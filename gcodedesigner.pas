unit gcodeDesigner;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,OpenGLContext,gl,math;
type
  TMoveMode = (mmG0, mmG1, mmG2, mmG3);

  // Struttura binaria compatta per un singolo movimento pre-calcolato
  TGCodeCommand = record
    MoveMode: TMoveMode;
    IsLaserMode: Boolean;
    isLaserPicture:boolean;
    LaserOn: double;
    IsTravel: Boolean;          // Pre-calcolato: True se è un movimento a vuoto (Z>0 o Laser Off)

    // Coordinate e quote
    X, Y, Z: Single;
    StartX, StartY, StartZ: Single; // Utili per ricostruire archi e segmenti al volo

    // Dati specifici per archi (G2/G3) pre-calcolati per non rifare ArcTan2 ad ogni frame
    CenterX, CenterY: Single;
    Radius: Single;
    StartAng, Sweep: Single;
    ForzaLineaDiretta: Boolean;
    originalRow:integer;
  end;

  TGCodeProgram = array of TGCodeCommand;

type
  TCompileGCodeProgressProc = procedure(Percent: Integer) of object;

procedure DrawGCode(const gcode: string; travelShow:boolean; percentage:double);
procedure GetGCodeBounds(const gcode: string; var minX, minY, minZ, maxX, maxY, maxZ: double);
procedure DrawAxes(HRange,VRange: Double; CurrentScale: Double);
function CompileGCode(const gcode: string; ProgressCallback: TCompileGCodeProgressProc = nil): TGCodeProgram;
function DrawGCodeCompiled(const programData: TGCodeProgram; travelShow: boolean; percentage: double):integer;
procedure GetGCodeBoundsCompiled(const programData: TGCodeProgram; var minX, minY, minZ, maxX, maxY, maxZ: double);

implementation

procedure GetGCodeBoundsCompiled(const programData: TGCodeProgram; var minX, minY, minZ, maxX, maxY, maxZ: double);
var
  i: Integer;
  cmd: TGCodeCommand;

  // Funzione ausiliaria per verificare se un angolo (in radianti) è compreso nell'arco (sweep)
  function IsAngleInArc(TargetAng, StartAng, SweepAng: Double): Boolean;
  var
    Diff: Double;
  begin
    // Normalizziamo l'angolo target rispetto all'inizio dell'arco
    Diff := TargetAng - StartAng;

    // Riportiamo tutto nell'intervallo [-PI, PI] o [0, 2*PI] a seconda del segno dello sweep
    if SweepAng > 0 then
    begin
      while Diff < 0 do Diff := Diff + 2.0 * Pi;
      while Diff > 2.0 * Pi do Diff := Diff - 2.0 * Pi;
      Result := Diff <= SweepAng;
    end
    else
    begin
      while Diff > 0 do Diff := Diff - 2.0 * Pi;
      while Diff < -2.0 * Pi do Diff := Diff + 2.0 * Pi;
      Result := Diff >= SweepAng;
    end;
  end;

  procedure CheckPoint(X, Y, Z: Double);
  begin
    if X < minX then minX := X;
    if X > maxX then maxX := X;
    if Y < minY then minY := Y;
    if Y > maxY then maxY := Y;
    if Z < minZ then minZ := Z;
    if Z > maxZ then maxZ := Z;
  end;

begin
  if Length(programData) = 0 then
  begin
    minX := 0; minY := 0; minZ := 0;
    maxX := 0; maxY := 0; maxZ := 0;
    Exit;
  end;

  // Inizializza con il primissimo punto di partenza del programma
  minX := programData[0].StartX; maxX := minX;
  minY := programData[0].StartY; maxY := minY;
  minZ := programData[0].StartZ; maxZ := minZ;

  for i := 0 to Length(programData) - 1 do
  begin
    cmd := programData[i];

    // Controlla sempre i punti base (Inizio e Fine movimento)
    CheckPoint(cmd.StartX, cmd.StartY, cmd.StartZ);
    CheckPoint(cmd.X, cmd.Y, cmd.Z);

    // Se è un arco valido e non declassato a linea, analizziamo i punti di tangenza estremi
    if ((cmd.MoveMode = mmG2) or (cmd.MoveMode = mmG3)) and (not cmd.ForzaLineaDiretta) and (cmd.Radius > 0.001) then
    begin
      // 1. Estremo Est (Angolo = 0 o 2*PI)
      if IsAngleInArc(0.0, cmd.StartAng, cmd.Sweep) or IsAngleInArc(2.0 * Pi, cmd.StartAng, cmd.Sweep) then
        CheckPoint(cmd.CenterX + cmd.Radius, cmd.CenterY, cmd.Z); // Nota: usiamo cmd.Z (o una quota media) per la Z

      // 2. Estremo Nord (Angolo = PI/2, ovvero 90°)
      if IsAngleInArc(Pi / 2.0, cmd.StartAng, cmd.Sweep) then
        CheckPoint(cmd.CenterX, cmd.CenterY + cmd.Radius, cmd.Z);

      // 3. Estremo Ovest (Angolo = PI o -PI, ovvero 180°)
      if IsAngleInArc(Pi, cmd.StartAng, cmd.Sweep) or IsAngleInArc(-Pi, cmd.StartAng, cmd.Sweep) then
        CheckPoint(cmd.CenterX - cmd.Radius, cmd.CenterY, cmd.Z);

      // 4. Estremo Sud (Angolo = 3/2*PI o -PI/2, ovvero 270°)
      if IsAngleInArc(3.0 * Pi / 2.0, cmd.StartAng, cmd.Sweep) or IsAngleInArc(-Pi / 2.0, cmd.StartAng, cmd.Sweep) then
        CheckPoint(cmd.CenterX, cmd.CenterY - cmd.Radius, cmd.Z);
    end;
  end;
end;

procedure SetPerspectiveView;
begin
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  // Allontaniamo la camera per vedere l'oggetto
  glTranslatef(0, 0, -2);

  // Ruotiamo la vista per vederla in 3D (Assonometria)
  glRotatef(-60, 1, 0, 0); // Inclina per vedere l'asse Z
  glRotatef(45, 0, 0, 1);  // Ruota per vedere X e Y
end;

function CalculateDynamicStep(Range: Double): Integer;
var
  Exponent: Double;
begin
  // Vogliamo circa 10 intervalli nel range visibile
  // Log10 ci dice l'ordine di grandezza
  Exponent := Floor(Log10(Range / 5));
  Result := Round(Power(10, Exponent));

  // Se il risultato è troppo rado, possiamo rifinirlo (es. passi da 5)
  if (Range / Result) > 20 then Result := Result * 5;
  if Result < 1 then Result := 1; // Minimo 1mm
end;

procedure DrawDigit(digit: char; x, y, size: Double);
var
  w: Double; // Larghezza del carattere
  h: Double; // Altezza del carattere
begin
  w := size * 0.7; // Larghezza proporzionale (puoi ridurla a 0.5 se li vuoi più stretti)
  h := size * 1.5; // Altezza totale

  glBegin(GL_LINE_STRIP);
    case digit of
      '0': begin glVertex2f(x, y); glVertex2f(x+w, y); glVertex2f(x+w, y+h); glVertex2f(x, y+h); glVertex2f(x, y); end;
      '1': begin glVertex2f(x+w, y); glVertex2f(x+w, y+h); end;
      '2': begin glVertex2f(x, y+h); glVertex2f(x+w, y+h); glVertex2f(x+w, y+h/2); glVertex2f(x, y+h/2); glVertex2f(x, y); glVertex2f(x+w, y); end;
      '3': begin glVertex2f(x, y+h); glVertex2f(x+w, y+h); glVertex2f(x+w, y); glVertex2f(x, y);
                 glEnd; glBegin(GL_LINES); glVertex2f(x, y+h/2); glVertex2f(x+w, y+h/2); end;
      '4': begin glVertex2f(x, y+h); glVertex2f(x, y+h/2); glVertex2f(x+w, y+h/2);
                 glEnd; glBegin(GL_LINES); glVertex2f(x+w, y+h); glVertex2f(x+w, y); end;
      '5': begin glVertex2f(x+w, y+h); glVertex2f(x, y+h); glVertex2f(x, y+h/2); glVertex2f(x+w, y+h/2); glVertex2f(x+w, y); glVertex2f(x, y); end;
      '6': begin glVertex2f(x+w, y+h); glVertex2f(x, y+h); glVertex2f(x, y); glVertex2f(x+w, y); glVertex2f(x+w, y+h/2); glVertex2f(x, y+h/2); end;
      '7': begin glVertex2f(x, y+h); glVertex2f(x+w, y+h); glVertex2f(x+w, y); end;
      '8': begin glVertex2f(x, y); glVertex2f(x+w, y); glVertex2f(x+w, y+h); glVertex2f(x, y+h); glVertex2f(x, y);
                 glEnd; glBegin(GL_LINES); glVertex2f(x, y+h/2); glVertex2f(x+w, y+h/2); end;
      '9': begin glVertex2f(x, y); glVertex2f(x+w, y); glVertex2f(x+w, y+h); glVertex2f(x, y+h); glVertex2f(x, y+h/2); glVertex2f(x+w, y+h/2); end;
      '-': begin glVertex2f(x, y+h/2); glVertex2f(x+w, y+h/2); end;
      '.', ',': begin glEnd; glPointSize(2); glBegin(GL_POINTS); glVertex2f(x+w/2, y); end;
    end;
  glEnd;
end;

procedure DrawText3D(s: string; x, y, size: Double);
var
  i: integer;
  spacing: Double;
begin
  spacing := size * 1.1; // Spazio tra i caratteri
  for i := 1 to Length(s) do
    DrawDigit(s[i], x + (i-1) * spacing, y, size);
end;

procedure DrawAxes(HRange,VRange: Double; CurrentScale: Double);
var
  HStepMM,VStepMM, startVal, endVal, i: Integer;
  txt: string;
  fixedSize, tickSize, textWidth: Double;
  lastX:double=0;
  lastY:double=0;
  maxSize:double;
begin
  // 1. Calcola lo step ideale basato sul range
  HStepMM := CalculateDynamicStep(HRange);
  VStepMM := CalculateDynamicStep(VRange);

  // 2. Dimensioni fisse (non cambiano con lo zoom)
  fixedSize := 0.01 / CurrentScale;

  startVal := Floor(-HRange / HStepMM) * HStepMM;
  endVal   := Ceil(HRange / HStepMM) * HStepMM;

    tickSize  := (endVal-startVal);

  // --- DISEGNO ---
  i := startVal;
  while i <= endVal do
  begin
    if (i <> 0) then
    begin
      txt := IntToStr(i);

      // NUMERI ASSE X (Centrati sulla tacca)
      if abs(i- (Length(txt) * fixedSize * 0.4)-lastX)>4*fixedSize * 0.4 then
      begin
        // TACCHE
        glLineWidth(2.0);
        glColor3f(0.1, 0.1, 0.1);
        glBegin(GL_LINES);
          glVertex3f(i, startVal, 0); glVertex3f(i, endVal, 0);
        glEnd;
        glLineWidth(1.0);
        glColor3f(0.8, 0.3, 0.3);
        DrawText3D(txt, i - (Length(txt) * fixedSize * 0.4), -fixedSize * 3, endVal/150);
        lastX:=i+ (Length(txt) * fixedSize * 0.4);
      end;
    end;
    inc(i, HStepMM);
  end;

  //startVal := Floor(-VRange / VStepMM) * VStepMM;
  //endVal   := Ceil(VRange / VStepMM) * VStepMM;

  // --- DISEGNO ---
  i := startVal;
  while i <= endVal do
  begin
    if (i <> 0) then
    begin
      txt := IntToStr(i);

      // NUMERI ASSE Y (A sinistra)
      if abs(i- (Length(txt) * fixedSize * 0.4)-lastY)>4*fixedSize * 0.4  then
      begin
        textWidth := Length(txt) * (fixedSize * 1.1);

        glLineWidth(2.0);
        glColor3f(0.1, 0.1, 0.1);
        glBegin(GL_LINES);
          glVertex3f(startVal, i, 0); glVertex3f(endVal, i, 0);
        glEnd;
        glLineWidth(1.0);
        glColor3f(0.3, 0.8, 0.3);
        DrawText3D(txt, -textWidth * 2, i - (fixedSize * 0.7), endVal/100);
        lastY:=i + (fixedSize * 0.7);
      end;
    end;
    inc(i, VStepMM);
  end;
  maxSize:=max(HRange,VRange)*1.2;
  HStepMM := CalculateDynamicStep(maxSize);

  // ASSI PRINCIPALI
  glLineWidth(2.0);
  glBegin(GL_LINES);
    glColor3f(0.7, 0.2, 0.2); glVertex3f(startVal, 0, 0); glVertex3f(endVal, 0, 0);
    glColor3f(0.2, 0.7, 0.2); glVertex3f(0, startVal, 0); glVertex3f(0, endVal, 0);
  glEnd;
end;

  // Funzione di supporto per estrarre i valori dopo le lettere (es. X-10.5)
  function GetValue(const s: string; letter: char; default: double): double;
  var
    p, i: integer;
    cleanStr, valStr: string;
    code: integer;
  begin
    Result := default;

    // 1. Rimuove i commenti (tutto ciò che segue ;)
    p := Pos(';', s);
    if p > 0 then cleanStr := Copy(s, 1, p - 1) else cleanStr := s;

    // 2. CORREZIONE FONDAMENTALE: Rimuove tutti gli spazi bianchi residui.
    // In questo modo i caratteri saranno sempre adiacenti (es: X149.971Y-91.312I-0.050)
    cleanStr := StringReplace(cleanStr, ' ', '', [rfReplaceAll]);
    cleanStr := StringReplace(cleanStr, #9, '', [rfReplaceAll]); // Rimuove eventuali Tabulazioni

    p := Pos(letter, cleanStr);
    if p > 0 then
    begin
      valStr := '';
      for i := p + 1 to Length(cleanStr) do
      begin
        // Se incontri un segno più o meno, è valido SOLO se è il primo carattere del numero
        if (cleanStr[i] in ['-', '+']) and (valStr <> '') then
          break; // Un segno meno successivo (es. la I-0.050) interrompe la lettura della Y corrente

        if cleanStr[i] in ['0'..'9', '.', '-', '+'] then
          valStr := valStr + cleanStr[i]
        else
          break; // Qualsiasi carattere non numerico (un'altra lettera) interrompe SUBITO il token
      end;

      if valStr <> '' then
      begin
        // Sostituisce l'eventuale virgola con il punto prima di usare Val
        valStr := StringReplace(valStr, ',', '.', [rfReplaceAll]);
        Val(valStr, Result, code);
      end;
    end;
  end;

  function CompileGCode(const gcode: string; ProgressCallback: TCompileGCodeProgressProc = nil): TGCodeProgram;
  var
    lines: TStringList;
    line: string;
    i: integer;
    currX, currY, currZ: double;
    nextX, nextY, nextZ: double;
    centerX, centerY, startAng, endAng, sweep, radius, rawRadius: double;
    offsetI, offsetJ, endRadius, dist, midX, midY, radicando, h, factor: double;

    currentMoveMode: integer;
    isIncremental: boolean;
    isLaserMode: boolean;
    isLaserPicture:boolean;
    laserOn: double;
    sValue: double;
    forzaLinea: boolean;
    isRadiusMode: boolean;

    cmd: TGCodeCommand;
    count: Integer;
    lastReportedPercent, curPercent: Integer;

    procedure ImpostaStatoTravel(var c: TGCodeCommand; qZ: Double);
    begin
      if c.IsLaserMode then
        c.IsTravel := c.LaserOn=0
      else
        c.IsTravel := (qZ > 0.0);
    end;

  begin
    Result := nil;
    lines := TStringList.Create;
    try
      lines.Text := gcode;
      SetLength(Result, lines.Count); // Allocazione iniziale massima
      count := 0;

      currX := 0.0; currY := 0.0; currZ := 0.0;
      currentMoveMode := 0;
      isIncremental := false;
      isLaserMode := false;
      isLaserPicture:=false;
      laserOn := 0;

      lastReportedPercent := -1;
      if Assigned(ProgressCallback) then ProgressCallback(0);

      for i := 0 to lines.Count - 1 do
      begin
        if Assigned(ProgressCallback) and (lines.Count>0) then
        begin
          curPercent := EnsureRange(Round(100 * i / lines.Count), 0, 100);
          if curPercent <> lastReportedPercent then
          begin
            lastReportedPercent := curPercent;
            ProgressCallback(curPercent);
          end;
        end;
        line := UpperCase(Trim(lines[i]));
        if line = '' then continue;

        if line = ';LASER' then begin isLaserMode := true; continue; end;
        if line = ';-LASER' then begin isLaserMode := false; laserOn := 0; continue; end;
        if line = ';LASERPICTURE' then begin isLaserPicture:=true; isLaserMode := true; continue; end;
        if line = ';-LASERPICTURE' then begin isLaserPicture:=false; isLaserMode := false; laserOn := 0; continue; end;
        if line = ';' then continue;

        if isLaserMode then
        begin
          if (Pos('M3', line) > 0) or (Pos('M4', line) > 0) or (Pos('G1', line) > 0) or (Pos('G01', line) > 0) then
          begin
            sValue := GetValue(line, 'S', -1.0);
            if sValue > 0.0 then laserOn := sValue else if sValue = 0.0 then laserOn := 0;
          end;
          if Pos('M5', line) > 0 then laserOn := 0;
        end;

        if (Pos('G90', line) > 0) then isIncremental := false;
        if (Pos('G91', line) > 0) then isIncremental := true;
        if (Pos('G', line) > 0) then currentMoveMode := round(GetValue(line, 'G', currentMoveMode));

        if not ((Pos('X', line) > 0) or (Pos('Y', line) > 0) or (Pos('Z', line) > 0) or
                (Pos('I', line) > 0) or (Pos('J', line) > 0) or (Pos('R', line) > 0)) then continue;

        if isIncremental then
        begin
          nextX := currX + GetValue(line, 'X', 0.0);
          nextY := currY + GetValue(line, 'Y', 0.0);
          nextZ := currZ + GetValue(line, 'Z', 0.0);
        end
        else
        begin
          nextX := GetValue(line, 'X', currX);
          nextY := GetValue(line, 'Y', currY);
          nextZ := GetValue(line, 'Z', currZ);
        end;

        // Prepariamo il record base
        FillChar(cmd, SizeOf(cmd), 0);
        cmd.MoveMode := TMoveMode(currentMoveMode);
        cmd.IsLaserMode := isLaserMode;
        cmd.isLaserPicture := isLaserPicture;
        cmd.LaserOn := laserOn;
        cmd.StartX := currX; cmd.StartY := currY; cmd.StartZ := currZ;
        cmd.X := nextX; cmd.Y := nextY; cmd.Z := nextZ;
        cmd.originalRow:=i+1;
        ImpostaStatoTravel(cmd, nextZ);

        // Elaborazione geometrica Archi spostata qui (una volta sola!)
        if (currentMoveMode = 2) or (currentMoveMode = 3) then
        begin
          rawRadius := GetValue(line, 'R', 0.0);
          forzaLinea := false;
          isRadiusMode := abs(rawRadius) > 0.00001;

          if isRadiusMode then
          begin
            radius := abs(rawRadius);
            midX := (currX + nextX) / 2.0; midY := (currY + nextY) / 2.0;
            dist := sqrt(sqr(nextX - currX) + sqr(nextY - currY));
            if (dist < 0.001) or (dist > (radius * 2.0)) then forzaLinea := true
            else
            begin
              radicando := sqr(radius) - sqr(dist / 2.0);
              if radicando < 0 then radicando := 0;
              h := sqrt(radicando);
              if currentMoveMode = 2 then
                if rawRadius > 0 then factor := 1.0 else factor := -1.0
              else
                if rawRadius > 0 then factor := -1.0 else factor := 1.0;
              centerX := midX + factor * h * (nextY - currY) / dist;
              centerY := midY - factor * h * (nextX - currX) / dist;
              cmd.CenterX := centerX; cmd.CenterY := centerY;
              cmd.Radius := radius;
            end;
          end
          else
          begin
            offsetI := GetValue(line, 'I', 0.0); offsetJ := GetValue(line, 'J', 0.0);
            centerX := currX + offsetI; centerY := currY + offsetJ;
            radius := sqrt(sqr(offsetI) + sqr(offsetJ));
            endRadius := sqrt(sqr(nextX - centerX) + sqr(nextY - centerY));
            if (abs(radius - endRadius) > 0.1) then
            begin
              centerX := currX + offsetI; centerY := currY + offsetJ;
              radius := sqrt(sqr(offsetI) + sqr(offsetJ));
              if abs(radius - endRadius) > 0.5 then forzaLinea := true;
            end;
            dist := sqrt(sqr(nextX - currX) + sqr(nextY - currY));
            if radius < 0.001 then forzaLinea := true;

            cmd.CenterX := centerX; cmd.CenterY := centerY; cmd.Radius := radius;
          end;

          if (not forzaLinea) and (radius > 0.001) then
          begin
            startAng := ArcTan2(currY - centerY, currX - centerX);
            endAng := ArcTan2(nextY - centerY, nextX - centerX);
            sweep := endAng - startAng;
            if currentMoveMode = 2 then
            begin
              if sweep > 0 then sweep := sweep - 2.0 * Pi;
              if isRadiusMode and (rawRadius > 0) and (sweep < -Pi) then sweep := sweep + 2.0 * Pi;
            end
            else
            begin
              if sweep < 0 then sweep := sweep + 2.0 * Pi;
              if isRadiusMode and (rawRadius > 0) and (sweep > Pi) then sweep := sweep - 2.0 * Pi;
            end;
            if not isRadiusMode and (dist < 0.001) then
            begin
              if currentMoveMode = 2 then sweep := -2.0 * Pi else sweep := 2.0 * Pi;
            end;

            cmd.StartAng := startAng;
            cmd.Sweep := sweep;
          end;
          cmd.ForzaLineaDiretta := forzaLinea;
        end;

        // Salvataggio comando strutturato
        Result[count] := cmd;
        Inc(count);

        currX := nextX; currY := nextY; currZ := nextZ;
      end;
      SetLength(Result, count); // Ridimensiona alla dimensione effettiva
    finally
      lines.Free;
    end;
    if Assigned(ProgressCallback) then ProgressCallback(100);
  end;


procedure GetGCodeBounds(const gcode: string; var minX, minY, minZ, maxX, maxY, maxZ: double);
var
  lines: TStringList;
  line: string;
  i: integer;
  currX, currY, currZ: double;
  nextX, nextY, nextZ: double;
  centerX, centerY, radius, startAng, endAng, sweep, checkAng: double;
  offsetI, offsetJ: double;
  isG2, isG3, isRadiusMode: boolean;
  midX, midY, dist, radicando, h, factor: double;
  quadrante: integer;
begin
  // Inizializzazione con valori estremi
  minX := 1e9; minY := 1e9; minZ := 1e9;
  maxX := -1e9; maxY := -1e9; maxZ := -1e9;

  currX := 0; currY := 0; currZ := 0;

  lines := TStringList.Create;
  try
    lines.Text := gcode;
    for i := 0 to lines.Count - 1 do
    begin
      line := UpperCase(Trim(lines[i]));
      if line = '' then continue;

      isG2 := (Pos('G2 ', line) > 0);
      isG3 := (Pos('G3 ', line) > 0);

      nextX := GetValue(line, 'X', currX);
      nextY := GetValue(line, 'Y', currY);
      nextZ := GetValue(line, 'Z', currZ);

      // Aggiornamento standard per i punti di arrivo (valido per G0, G1 e terminali di G2/G3)
      if nextX < minX then minX := nextX; if nextX > maxX then maxX := nextX;
      if nextY < minY then minY := nextY; if nextY > maxY then maxY := nextY;
      if nextZ < minZ then minZ := nextZ; if nextZ > maxZ then maxZ := nextZ;

      // Se è anche un punto di partenza (il primo movimento), consideriamo anche curr
      if currX < minX then minX := currX; if currX > maxX then maxX := currX;
      if currY < minY then minY := currY; if currY > maxY then maxY := currY;

      // Se è un arco, dobbiamo controllare se la "pancia" sporge
      if isG2 or isG3 then
      begin
        radius := GetValue(line, 'R', -1.0);
        isRadiusMode := radius > 0.00001;

        if isRadiusMode then
        begin
          midX := (currX + nextX) / 2.0;
          midY := (currY + nextY) / 2.0;
          dist := sqrt(sqr(nextX - currX) + sqr(nextY - currY));

          if (dist >= 0.005) and (dist <= (radius * 2.0)) then
          begin
            radicando := sqr(radius) - sqr(dist / 2.0);
            if radicando < 0 then radicando := 0;
            h := sqrt(radicando);
            if isG2 then factor := 1.0 else factor := -1.0;

            centerX := midX - factor * h * (nextY - currY) / dist;
            centerY := midY + factor * h * (nextX - currX) / dist;
          end else continue; // Salta se geometricamente impossibile
        end
        else
        begin
          offsetI := GetValue(line, 'I', 0.0);
          offsetJ := GetValue(line, 'J', 0.0);
          centerX := currX + offsetI;
          centerY := currY + offsetJ;
          radius := sqrt(sqr(offsetI) + sqr(offsetJ));
        end;

        if radius > 0.001 then
        begin
          startAng := ArcTan2(currY - centerY, currX - centerX);
          endAng := ArcTan2(nextY - centerY, nextX - centerX);
          sweep := endAng - startAng;

          // Normalizzazione dello sweep identica a quella usata nel disegno
          if isG2 then
          begin
            while sweep >= 0 do sweep := sweep - 2.0 * Pi;
            if isRadiusMode and (sweep < -Pi) then sweep := sweep + 2.0 * Pi;
          end
          else
          begin
            while sweep <= 0 do sweep := sweep + 2.0 * Pi;
            if isRadiusMode and (sweep > Pi) then sweep := sweep - 2.0 * Pi;
          end;

          // Controlliamo i 4 punti estremi (0, Pi/2, Pi, 3/2*Pi radianti)
          // Verifichiamo se l'arco passa attraverso uno di questi angoli principali
          for quadrante := 0 to 3 do
          begin
            checkAng := quadrante * (Pi / 2.0); // 0°, 90°, 180°, 270°

            // Calcoliamo la differenza angolare relativa rispetto all'inizio
            dist := checkAng - startAng;

            // Normalizziamo la distanza in base al senso di marcia
            if isG3 then
            begin
              while dist <= 0 do dist := dist + 2.0 * Pi;
              // Se la distanza angolare per raggiungere il punto cardinale
              // è minore dello sweep totale, l'arco ci passa sopra!
              if dist < sweep then
              begin
                if quadrante = 0 then if (centerX + radius) > maxX then maxX := centerX + radius; // Est
                if quadrante = 1 then if (centerY + radius) > maxY then maxY := centerY + radius; // Nord
                if quadrante = 2 then if (centerX - radius) < minX then minX := centerX - radius; // Ovest
                if quadrante = 3 then if (centerY - radius) < minY then minY := centerY - radius; // Sud
              end;
            end
            else // G2 (Senso Orario, sweep negativo)
            begin
              while dist >= 0 do dist := dist - 2.0 * Pi;
              if dist > sweep then // Ricorda che sono entrambi negativi
              begin
                if quadrante = 0 then if (centerX + radius) > maxX then maxX := centerX + radius;
                if quadrante = 1 then if (centerY + radius) > maxY then maxY := centerY + radius;
                if quadrante = 2 then if (centerX - radius) < minX then minX := centerX - radius;
                if quadrante = 3 then if (centerY - radius) < minY then minY := centerY - radius;
              end;
            end;
          end;
        end;
      end;

      currX := nextX; currY := nextY; currZ := nextZ;
    end;
  finally
    lines.Free;
  end;
end;

procedure DrawGCode(const gcode: string; travelShow:boolean; percentage:double);
const
  SEGMENTS_PER_ARC = 64; // Aumentato per eliminare qualsiasi segmentazione visiva
var
  lines: TStringList;
  line: string;
  i, s: integer;
  currX, currY, currZ: double;
  nextX, nextY, nextZ: double;
  centerX, centerY, startAng, endAng, sweep, radius, curAng: double;
  offsetI, offsetJ: double;
  forzaLineaDiretta: boolean;
  midX, midY, dist, radicando, h, factor: double;
  calcolatiX, calcolatiY: double;
  isRadiusMode: boolean;
  endRadius: double;
  rawRadius: double;
  // STATI MODALI DEL COORD-SYSTEM E DEL MOVIMENTO
  currentMoveMode: integer; // 0=G0, 1=G1, 2=G2, 3=G3
  isIncremental: boolean; // Gestione G90 (false) e G91 (true)

  // STATI GESTIONE MODALITÀ LASER
  isLaserMode: boolean;   // True se abbiamo letto ;Laser, False se ;-Laser
  laserOn: boolean;       // True se M3/M4 con S > 0, False se M5 o S = 0
  sValue: double;         // Valore del parametro S
  travel:boolean;
  // Procedura interna per impostare correttamente il colore in base allo stato macchina
  procedure ImpostaColore(quotaZ: double);
  begin
    if isLaserMode then
    begin
      if laserOn then
      begin
        glColor3f(0.0, 0.0, 1.0);  // Blu: Laser Acceso
        travel:=false;
      end
      else
      begin
        glColor3f(1.0, 0.0, 0.0); // Rosso: Laser Spento / Spostamento
        travel:=true;
      end;
    end
    else
    begin
      // Modalità Fresa: Verde se Z <= 0 (incluso lo zero fisso)
      if (quotaZ < 0.0)or((quotaZ = 0.0) and (currZ<=0)) then
      begin
        glColor3f(0.0, 1.0, 0.0);  // Verde: Lavoro Fresa (Z <= 0)
        travel:=false;
      end
      else
      begin
        glColor3f(1.0, 0.0, 0.0); // Rosso: Spostamento aereo (Z > 0)
        travel:=true;
      end;
    end;
  end;

begin
  lines := TStringList.Create;
  try
    lines.Text := gcode;
    // Inizializzazione degli stati macchina standard (Default GRBL/Candle)
    currX := 0.0; currY := 0.0; currZ := 0.0;
    currentMoveMode := 0;
    isIncremental := false; // Default: G90 (Assoluto)

    // Inizializzazione stati laser
    isLaserMode := false;
    laserOn := false;

    i := 0;
    while (i <= lines.Count - 1) and (i / lines.Count <= percentage) do
    begin
      line := UpperCase(Trim(lines[i]));
      inc(i);
      if line = '' then continue;

      // --- GESTIONE DEI COMMENTI DIRETTIVI DI MODALITÀ ---
      if line = ';LASER' then
      begin
        isLaserMode := true;
        continue;
      end;
      if line = ';-LASER' then
      begin
        isLaserMode := false;
        laserOn := false; // Reset di sicurezza
        continue;
      end;

      if line = ';' then continue; // Salta gli altri commenti nativi

      // --- INTERPRETAZIONE DEI COMANDI ACCENSIONE/SPEGNIMENTO LASER (M3, M4, M5) ---
      if isLaserMode then
      begin
        if (Pos('M3', line) > 0) or (Pos('M4', line) > 0) then
        begin
          sValue := GetValue(line, 'S', -1.0);
          if sValue > 0.0 then
            laserOn := true
          else if sValue = 0.0 then
            laserOn := false;
        end;
        if Pos('M5', line) > 0 then
        begin
          laserOn := false;
        end;
      end;

      // Controllo cambio sistema di coordinate globale
      if (Pos('G90', line) > 0) then isIncremental := false;
      if (Pos('G91', line) > 0) then isIncremental := true;

      if (Pos('G', line) > 0) then
        currentMoveMode := round(GetValue(line, 'G', currentMoveMode));

      // Se la riga non contiene coordinate o istruzioni di movimento, la saltiamo
      if not ( (Pos('X', line) > 0) or (Pos('Y', line) > 0) or (Pos('Z', line) > 0) or
               (Pos('I', line) > 0) or (Pos('J', line) > 0) or (Pos('R', line) > 0) ) then
        continue;

      // Calcolo coordinate traguardo tenendo conto dello stato G90/G91
      if isIncremental then
      begin
        nextX := currX + GetValue(line, 'X', 0.0);
        nextY := currY + GetValue(line, 'Y', 0.0);
        nextZ := currZ + GetValue(line, 'Z', 0.0);
      end
      else
      begin
        nextX := GetValue(line, 'X', currX);
        nextY := GetValue(line, 'Y', currY);
        nextZ := GetValue(line, 'Z', currZ);
      end;

      // --- ELABORAZIONE MOVIMENTI IN CURVA (G2 / G3) ---
      if (currentMoveMode = 2) or (currentMoveMode = 3) then
      begin
        rawRadius := GetValue(line, 'R', 0.0);
        forzaLineaDiretta := false;
        isRadiusMode := abs(rawRadius) > 0.00001;
        if isRadiusMode then
        begin
          radius := abs(rawRadius);
          midX := (currX + nextX) / 2.0;
          midY := (currY + nextY) / 2.0;
          dist := sqrt(sqr(nextX - currX) + sqr(nextY - currY));
          if (dist < 0.001) or (dist > (radius * 2.0)) then
            forzaLineaDiretta := true
          else
          begin
            radicando := sqr(radius) - sqr(dist / 2.0);
            if radicando < 0 then radicando := 0;
            h := sqrt(radicando);
            if currentMoveMode = 2 then
            begin
              if rawRadius > 0 then factor := 1.0 else factor := -1.0;
            end
            else
            begin
              if rawRadius > 0 then factor := -1.0 else factor := 1.0;
            end;
            centerX := midX + factor * h * (nextY - currY) / dist;
            centerY := midY - factor * h * (nextX - currX) / dist;
          end;
        end
        else
        begin
          offsetI := GetValue(line, 'I', 0.0);
          offsetJ := GetValue(line, 'J', 0.0);
          centerX := currX + offsetI;
          centerY := currY + offsetJ;
          radius := sqrt(sqr(offsetI) + sqr(offsetJ));
          endRadius := sqrt(sqr(nextX - centerX) + sqr(nextY - centerY));
          if (abs(radius - endRadius) > 0.1) then
          begin
            centerX := offsetI;
            centerY := offsetJ;
            radius := sqrt(sqr(currX - centerX) + sqr(currY - centerY));
            endRadius := sqrt(sqr(nextX - centerX) + sqr(nextY - centerY));
            if (abs(radius - endRadius) > 0.1) then
            begin
              centerX := currX + offsetI;
              centerY := currY + offsetJ;
              radius := sqrt(sqr(offsetI) + sqr(offsetJ));
              if abs(radius - endRadius) > 0.5 then
                forzaLineaDiretta := true;
            end;
          end;
          dist := sqrt(sqr(nextX - currX) + sqr(nextY - currY));
          if radius < 0.001 then forzaLineaDiretta := true;
        end;

        if (not forzaLineaDiretta) and (radius > 0.001) then
        begin
          startAng := ArcTan2(currY - centerY, currX - centerX);
          endAng := ArcTan2(nextY - centerY, nextX - centerX);
          sweep := endAng - startAng;
          if currentMoveMode = 2 then
          begin
            if sweep > 0 then sweep := sweep - 2.0 * Pi;
            if isRadiusMode and (rawRadius > 0) and (sweep < -Pi) then sweep := sweep + 2.0 * Pi;
            if isRadiusMode and (rawRadius < 0) and (sweep > -Pi) then sweep := sweep - 2.0 * Pi;
          end
          else
          begin
            if sweep < 0 then sweep := sweep + 2.0 * Pi;
            if isRadiusMode and (rawRadius > 0) and (sweep > Pi) then sweep := sweep - 2.0 * Pi;
            if isRadiusMode and (rawRadius < 0) and (sweep < Pi) then sweep := sweep + 2.0 * Pi;
          end;
          if not isRadiusMode and (dist < 0.001) then
          begin
            if currentMoveMode = 2 then sweep := -2.0 * Pi else sweep := 2.0 * Pi;
          end;

          if IsNaN(sweep) or IsInfinite(sweep) or (abs(sweep) < 0.00001) then
          begin
            glBegin(GL_LINES);
            ImpostaColore(nextZ);
            // Controllo travelShow in modalità Laser e Fresa
            if (isLaserMode and (laserOn or (travelShow and travel))) or (not isLaserMode and ((not travel) or (travelShow and travel))) then
            begin
              glVertex3f(currX, currY, currZ);
              glVertex3f(nextX, nextY, nextZ);
            end;
            glEnd();
          end
          else
          begin
            // DISEGNO FLUIDO DELL'ARCO
            if (isLaserMode and (laserOn or travelShow)) or (not isLaserMode) then
            begin
              glBegin(GL_LINE_STRIP);
              for s := 0 to SEGMENTS_PER_ARC do
              begin
                curAng := startAng + (sweep * (s / SEGMENTS_PER_ARC));
                nextZ := currZ + (GetValue(line, 'Z', currZ) - currZ) * (s / SEGMENTS_PER_ARC);
                calcolatiX := centerX + cos(curAng) * radius;
                calcolatiY := centerY + sin(curAng) * radius;

                ImpostaColore(nextZ);
                if isLaserMode then
                begin
                  glVertex3f(calcolatiX, calcolatiY, nextZ);
                end
                else
                begin
                  if (not travel) or (travelShow and travel) then glVertex3f(calcolatiX, calcolatiY, nextZ);
                end;
              end;
              glEnd();
            end;
          end;
        end;
        if forzaLineaDiretta then
        begin
          glBegin(GL_LINES);
          ImpostaColore(nextZ);
          if (isLaserMode and (laserOn or (travelShow and travel))) or (not isLaserMode and ((not travel) or (travelShow and travel))) then
          begin
            glVertex3f(currX, currY, currZ);
            glVertex3f(nextX, nextY, nextZ);
          end;
          glEnd();
        end;
      end;

      // --- DISEGNO DELLE PARTI RETTILINEE (G0 / G1 o Archi Falliti) ---
      if forzaLineaDiretta or (currentMoveMode = 0) or (currentMoveMode = 1) then
      begin
        // CASO 1: Il segmento attraversa lo zero (Una parte sopra e una strettamente sotto) - Solo se non siamo in modalità Laser
        if not isLaserMode and (((currZ > 0.0) and (nextZ < 0.0)) or ((currZ < 0.0) and (nextZ > 0.0))) then
        begin
          factor := -currZ / (nextZ - currZ);
          calcolatiX := currX + factor * (nextX - currX);
          calcolatiY := currY + factor * (nextY - currY);
          glBegin(GL_LINES);
          ImpostaColore(currZ);
          if (not travel) or (travelShow and travel) then
          begin
            glVertex3f(currX, currY, currZ);
            glVertex3f(calcolatiX, calcolatiY, 0.0);
          end;
          glEnd();
          glBegin(GL_LINES);
          ImpostaColore(nextZ);
          if (not travel) or (travelShow and travel) then
          begin
            glVertex3f(calcolatiX, calcolatiY, 0.0);
            glVertex3f(nextX, nextY, nextZ);
          end;
          glEnd();
        end
        // CASO 2: Il segmento è interamente sopra o sotto, oppure siamo in modalità Laser
        else
        begin
          glBegin(GL_LINES);
          ImpostaColore(nextZ);
          // Applica travelShow: disegna se il laser è acceso OPPURE se travelShow è true
          if (isLaserMode and (laserOn or (travelShow and travel))) or (not isLaserMode and ((not travel) or (travelShow and travel))) then
          begin
            glVertex3f(currX, currY, currZ);
            glVertex3f(nextX, nextY, nextZ);
          end;
          glEnd();
        end;
      end;
      // Aggiornamento registri di stato macchina per la riga successiva
      currX := nextX;
      currY := nextY;
      currZ := nextZ;
    end; // Fine ciclo While
  finally
    lines.Free;
  end;
end;

function DrawGCodeCompiled(const programData: TGCodeProgram; travelShow: boolean; percentage: double):integer;
const
  SEGMENTS_PER_ARC = 64;
var
  i, s: integer;
  limit: integer;
  cmd: TGCodeCommand;
  curAng, calcolatiX, calcolatiY, nextZ, prevZ, segmentZ, factor: Double;
  isTravelSegment: Boolean;

  procedure ImpostaColoreDynamic(const c: TGCodeCommand; quotaZ: Double);
  begin
    if c.IsLaserMode then
    begin
      //if c.LaserOn then glColor3f(0.0, 0.0, 1.0) else glColor3f(1.0, 0.0, 0.0);
      if cmd.isLaserPicture then
      begin
        if c.LaserOn>0 then glColor3f(0.0, 0.0, c.LaserOn/1000) else glColor3f(1.0, 0.0, 0.0);
      end
      else
      begin
        if c.LaserOn>0 then glColor3f(0.0, 0.0, 1.0) else glColor3f(1.0, 0.0, 0.0);
      end;
    end
    else
    begin
      // Ripristino fedele del controllo colore originale
      if (quotaZ < 0.0) or ((quotaZ = 0.0) and (c.StartZ <= 0.0)) then
        glColor3f(0.0, 1.0, 0.0)  // Verde: Lavoro
      else
        glColor3f(1.0, 0.0, 0.0); // Rosso: Spostamento
    end;
  end;

begin
  limit := Round((Length(programData) - 1) * percentage);
  result:=0;
  if Length(programData) = 0 then Exit;

  if limit < 0 then limit := 0;

  result:=programData[limit].originalRow;
  for i := 0 to limit do
  begin
    cmd := programData[i];

    // --- DISEGNO MOVIMENTI IN CURVA (G2 / G3) ---
    if (cmd.MoveMode = mmG2) or (cmd.MoveMode = mmG3) then
    begin
      if (not cmd.ForzaLineaDiretta) and (cmd.Radius > 0.001) then
      begin
        if IsNaN(cmd.Sweep) or IsInfinite(cmd.Sweep) or (abs(cmd.Sweep) < 0.00001) then
        begin
          isTravelSegment := not cmd.IsLaserMode and (cmd.StartZ >= 0.0) and (cmd.Z >= 0.0) and not ((cmd.StartZ = 0.0) and (cmd.Z = 0.0));
          if (cmd.IsLaserMode and ((cmd.LaserOn>0) or travelShow)) or
             (not cmd.IsLaserMode and ((not isTravelSegment) or travelShow)) then
          begin
            glBegin(GL_LINES);
              ImpostaColoreDynamic(cmd, cmd.Z);
              if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.StartX, cmd.StartY, 0) else glVertex3f(cmd.StartX, cmd.StartY, cmd.StartZ);
              if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.X, cmd.Y, 0) else glVertex3f(cmd.X, cmd.Y, cmd.Z);
            glEnd();
          end;
        end
        else
        begin
          glBegin(GL_LINE_STRIP);
          prevZ := cmd.StartZ;
          for s := 0 to SEGMENTS_PER_ARC do
          begin
            segmentZ := cmd.StartZ + (cmd.Z - cmd.StartZ) * (s / SEGMENTS_PER_ARC);
            curAng := cmd.StartAng + (cmd.Sweep * (s / SEGMENTS_PER_ARC));
            calcolatiX := cmd.CenterX + cos(curAng) * cmd.Radius;
            calcolatiY := cmd.CenterY + sin(curAng) * cmd.Radius;

            isTravelSegment := not cmd.IsLaserMode and (prevZ >= 0.0) and (segmentZ >= 0.0) and not ((prevZ = 0.0) and (segmentZ = 0.0));

            if (cmd.IsLaserMode and ((cmd.LaserOn>0) or travelShow)) or
               (not cmd.IsLaserMode and ((not isTravelSegment) or travelShow)) then
            begin
              ImpostaColoreDynamic(cmd, segmentZ);
              if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(calcolatiX, calcolatiY, 0) else glVertex3f(calcolatiX, calcolatiY, segmentZ);
            end;
            prevZ := segmentZ;
          end;
          glEnd();
        end;
      end
      else
      begin
        isTravelSegment := not cmd.IsLaserMode and (cmd.StartZ >= 0.0) and (cmd.Z >= 0.0) and not ((cmd.StartZ = 0.0) and (cmd.Z = 0.0));
        if (cmd.IsLaserMode and ((cmd.LaserOn>0) or travelShow)) or
           (not cmd.IsLaserMode and ((not isTravelSegment) or travelShow)) then
        begin
          glBegin(GL_LINES);
            ImpostaColoreDynamic(cmd, cmd.Z);
          if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.StartX, cmd.StartY, 0) else glVertex3f(cmd.StartX, cmd.StartY, cmd.StartZ);
          if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.X, cmd.Y, 0) else glVertex3f(cmd.X, cmd.Y, cmd.Z);
          glEnd();
        end;
      end;
    end

    // --- DISEGNO DELLE PARTI RETTILINEE (G0 / G1) ---
    else
    begin
      // CASO 1: Il segmento attraversa in modo netto lo zero (Uno strettamente sopra e uno strettamente sotto)
      if not cmd.IsLaserMode and (((cmd.StartZ > 0.0) and (cmd.Z < 0.0)) or ((cmd.StartZ < 0.0) and (cmd.Z > 0.0))) then
      begin
        factor := -cmd.StartZ / (cmd.Z - cmd.StartZ);
        calcolatiX := cmd.StartX + factor * (cmd.X - cmd.StartX);
        calcolatiY := cmd.StartY + factor * (cmd.Y - cmd.StartY);

        // Prima parte (dalla partenza allo zero)
        isTravelSegment := (cmd.StartZ > 0.0);
        if (not isTravelSegment) or travelShow then
        begin
          glBegin(GL_LINES);
            ImpostaColoreDynamic(cmd, cmd.StartZ);
            if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.StartX, cmd.StartY, 0) else glVertex3f(cmd.StartX, cmd.StartY, cmd.StartZ);
            glVertex3f(calcolatiX, calcolatiY, 0.0);
          glEnd();
        end;

        // Seconda parte (dallo zero all'arrivo)
        isTravelSegment := (cmd.Z > 0.0);
        if (not isTravelSegment) or travelShow then
        begin
          glBegin(GL_LINES);
            ImpostaColoreDynamic(cmd, cmd.Z);
            glVertex3f(calcolatiX, calcolatiY, 0.0);
            if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.X, cmd.Y, 0) else glVertex3f(cmd.X, cmd.Y, cmd.Z);
          glEnd();
        end;
      end

      // CASO 2: Movimenti verticali puri che toccano lo zero o segmenti interamente sullo stesso lato
      else
      begin
        // Un segmento è di spostamento aereo puro se entrambi i punti sono >= 0, escludendo il caso in cui siano entrambi a quota 0 di lavoro
        isTravelSegment := not cmd.IsLaserMode and (cmd.StartZ >= 0.0) and (cmd.Z >= 0.0) and not ((cmd.StartZ = 0.0) and (cmd.Z = 0.0));

        if (cmd.IsLaserMode and ((cmd.LaserOn>0) or travelShow)) or
           (not cmd.IsLaserMode and ((not isTravelSegment) or travelShow)) then
        begin
          glBegin(GL_LINES);
            ImpostaColoreDynamic(cmd, cmd.Z);
            if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.StartX, cmd.StartY, 0) else glVertex3f(cmd.StartX, cmd.StartY, cmd.StartZ);
            if (cmd.MoveMode<>mmG0)and(cmd.IsLaserMode) then glVertex3f(cmd.X, cmd.Y, 0) else glVertex3f(cmd.X, cmd.Y, cmd.Z);
          glEnd();
        end;
      end;
    end;
  end;
end;
end.

