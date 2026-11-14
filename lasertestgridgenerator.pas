unit LaserTestGridGenerator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math;

{**
 * Genera uno script G-Code per una griglia di test (Power Scale / Material Test).
 * Incide una serie di quadratini a potenze crescenti per calibrare i limiti del legno.
 *
 * @param RighePotenza       Numero di step di potenza (es. 10 per step da 10% a 100%)
 * @param PotenzaMacchinaMax Potenza massima configurata sulla macchina (es. 1000 o 255)
 * @param DimQuadratinoMM    Dimensione del lato di ogni quadratino in mm (es. 10.0)
 * @param SpazioMM           Spazio tra un quadratino e l'altro in mm (es. 2.0)
 * @param SpotDiameterMM     Diametro del fascio laser / passo di scansione (es. 0.08 o 0.1)
 * @param FeedRateXY         Velocità di incisione del test in mm/min (es. 3000)
 * @param FeedRateRapido     Velocità degli spostamenti a vuoto in mm/min (es. 5000)
 * @return Stringa contenente il codice G-Code completo
 *}
function GeneraGCodeGrigliaTest(
  const RighePotenza: Integer;
  const PotenzaMacchinaMax: Integer;
  const DimQuadratinoMM: Double;
  const SpazioMM: Double;
  const SpotDiameterMM: Double;
  const FeedRateXY: Double;
  const FeedRateRapido: Double;
  const UsaM4: Boolean = True
): string;

implementation

function GeneraGCodeGrigliaTest(
  const RighePotenza: Integer;
  const PotenzaMacchinaMax: Integer;
  const DimQuadratinoMM: Double;
  const SpazioMM: Double;
  const SpotDiameterMM: Double;
  const FeedRateXY: Double;
  const FeedRateRapido: Double;
  const UsaM4: Boolean = True
): string;
var
  GCode: TStringList;
  StepIdx, LineePerQuadratino, L: Integer;
  PotenzaAttuale: Integer;
  BaseX, StartX, EndX, CurrentY: Double;
  LaserOnCode: string;
  InvertiDirezione: Boolean;
begin
  Result := '';
  
  if RighePotenza <= 0 then Exit;
  if SpotDiameterMM <= 0 then Exit;

  GCode := TStringList.Create;
  try
    if UsaM4 then
      LaserOnCode := 'M4'
    else
      LaserOnCode := 'M3';

    // Intestazione G-Code
    GCode.Add('; --- GRADIENT TEST GRID GENERATOR ---');
    GCode.Add(';LaserPicture');
    GCode.Add('; Utilizza questa griglia per individuare visivamente i limiti del tuo legno');
    GCode.Add(Format('; Step totali di potenza: %d', [RighePotenza]));
    GCode.Add(Format('; Risoluzione (Passo): %.3f mm', [SpotDiameterMM]));
    GCode.Add('G21 ; Unita in millimetri');
    GCode.Add('G90 ; Coordinate assolute');
    GCode.Add('M5  ; Spegne il laser prima di partire');
    GCode.Add(Format('G0 F%.1f ; Imposta velocita spostamenti rapidi', [FeedRateRapido]));
    LineePerQuadratino := Max(1, Round(DimQuadratinoMM / SpotDiameterMM));

    // Ciclo attraverso tutti gli step di potenza richiesti
    for StepIdx := 0 to RighePotenza - 1 do
    begin
      // Calcola la potenza per questo specifico quadratino (es. da 10% a 100%)
      PotenzaAttuale := Round(((StepIdx + 1) / RighePotenza) * PotenzaMacchinaMax);
      
      // Calcola la posizione X iniziale del quadratino nella griglia orizzontale
      BaseX := StepIdx * (DimQuadratinoMM + SpazioMM);

      GCode.Add('');
      GCode.Add(Format('; --- QUADRATINO STEP %d: Potenza S%d (%.1f%%) ---', 
        [StepIdx + 1, PotenzaAttuale, ((StepIdx + 1) / RighePotenza) * 100.0]));

      InvertiDirezione := False;

      // Scansione raster del singolo quadratino (dal basso verso l'alto)
      for L := 0 to LineePerQuadratino - 1 do
      begin
        CurrentY := L * SpotDiameterMM;
        
        // Logica bidirezionale (Zig-Zag) per minimizzare i tempi morti di spostamento
        if not InvertiDirezione then
        begin
          StartX := BaseX;
          EndX := BaseX + DimQuadratinoMM;
        end
        else
        begin
          StartX := BaseX + DimQuadratinoMM;
          EndX := BaseX;
        end;

        // Movimento rapido all'inizio della linea di scansione corrente
        GCode.Add(Format('G0 X%.3f Y%.3f', [StartX, CurrentY]));
        
        // Attivazione del laser con la velocità di lavoro e la potenza di test
        GCode.Add(Format('G1 F%.1f %s S%d', [FeedRateXY, LaserOnCode, PotenzaAttuale]));
        
        // Tracciamento della linea attiva fino alla fine del quadratino
        GCode.Add(Format('G1 X%.3f', [EndX]));
        
        // Spegne il laser a fine linea per sicurezza e transizione
        GCode.Add('M5');

        // Alterna la direzione per la linea successiva
        InvertiDirezione := not InvertiDirezione;
      end;
    end;

    // Chiusura dello script G-Code e ritorno in home
    GCode.Add('');
    GCode.Add('M5 ; Spegne il laser definitivamente');
    GCode.Add('G0 X0 Y0 ; Torna all''origine');
    GCode.Add(';-LaserPicture');
    GCode.Add('; --- FINE DEL TEST DI DINAMICA ---');

    Result := GCode.Text;
  finally
    GCode.Free;
  end;
end;

end.
