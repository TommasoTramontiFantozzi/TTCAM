unit savedatastruct;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, md5, gcodegen;

type
  TOperazione = record
    op: integer;
    X, Y: single;
    RapidFeed: single;
    HFeed: single;
    ZFeed: single;
    ToolDia: single;
    ZStart: single;
    ZDepth: single;
    ZStep: single;
    maxRamp:single;
    finishAllowance:single;
    Spindle: integer;
    direction: byte;
    specific: array of single;
    specificBool: array of boolean;
    specificInteger: array of integer;
    specificText: array of string;
    text: string;
    fontName: string;
    laserMode: boolean;
    enabled: boolean;
    filename: string;
    result: string;
    listPosition: integer;
    TransformationMatrix: TTransformationMatrix;
    FileData: TMemoryStream; // Copia binaria del file esterno (PCB/SVG/Laser/Sculpt): il progetto non dipende piu dal percorso su disco
  end;
  POperazione = ^TOperazione;

const
  // Numero di versione del programma con cui viene salvato il file di progetto
  TTCAM_VERSION_MAJOR: Word = 1;
  TTCAM_VERSION_MINOR: Word = 0;

function SalvaListaOperazioni(AList: TList; const AFileName: string; const AProjectComment: string): boolean;
procedure CaricaListaOperazioni(AList: TList; const AFileName: string; out AFileVersionMajor, AFileVersionMinor: Word; out AProjectComment: string);

{ Stessa logica di CaricaListaOperazioni, ma legge da uno stream gia' aperto invece che da un
  percorso su disco (lo stream resta di proprieta' del chiamante, non viene liberato qui).
  Usata per caricare i progetti di esempio incorporati come risorsa RCDATA nell'eseguibile. }
procedure CaricaListaOperazioniStream(AList: TList; AStream: TStream; out AFileVersionMajor, AFileVersionMinor: Word; out AProjectComment: string);

{ Alloca una nuova TOperazione garantendo che FileData parta a nil: New() non azzera i campi
  non "managed" come un riferimento a classe, quindi va sempre usata al posto di New() nudo. }
procedure NewOperazione(out P: POperazione);

{ Imposta il nome file di una TOperazione e ne incorpora il contenuto binario in FileData,
  cosi la feature (PCB/SVG/Laser Picture/Sculpting) resta utilizzabile anche se il file
  originale viene spostato, rinominato o non e' piu' raggiungibile allo stesso percorso. }
procedure SetOperationFile(P: POperazione; const AFileName: string);

{ Materializza FileData (se presente) in un file temporaneo, mantenendo l'estensione
  originale (necessaria ai reader di immagini/SVG), e ne restituisce il percorso da usare
  per la generazione del GCode; IsTemp indica se il chiamante deve poi cancellarlo.
  Se non ci sono dati incorporati ricade sul percorso originale su disco. }
function ResolveOperationFile(P: POperazione; out IsTemp: boolean): string;

{ Libera in modo sicuro una TOperazione allocata con New(), incluso lo stream incorporato }
procedure FreeOperazione(var P: POperazione);

implementation

const
  // Identificativo univoco del formato file (4 byte)
  FILE_SIGNATURE = 'CAM#';
  HEADER_SIZE = 16; // 4 byte firma + 8 byte per Int64 (dimensione file) + 2+2 byte versione major/minor

{ Sotto-routine interna per calcolare l'MD5 di una porzione specifica dello Stream }
function CalcolaMD5Stream(Stream: TStream; Lunghezza: Int64): TMD5Digest;
var
  Context: TMD5Context;
  Buffer: array[0..4095] of Byte;
  Letti, DaLeggere: Integer;
begin
  MD5Init(Context);
  Stream.Position := 0;
  while Lunghezza > 0 do
  begin
    if Lunghezza > SizeOf(Buffer) then
      DaLeggere := SizeOf(Buffer)
    else
      DaLeggere := Lunghezza;

    Letti := Stream.Read(Buffer[0], DaLeggere);
    if Letti <= 0 then Break;

    MD5Update(Context, Buffer[0], Letti);
    Dec(Lunghezza, Letti);
  end;
  MD5Final(Context, Result);
end;

{ Sotto-routine di logica pura per scrivere una stringa Pascal standard }
procedure InviaStringa(Stream: TStream; const S: string);
var
  L: Integer;
begin
  L := Length(S);
  Stream.WriteBuffer(L, SizeOf(L));
  if L > 0 then
    Stream.WriteBuffer(S[1], L * SizeOf(Char));
end;

{ Sotto-routine di logica pura per leggere una stringa Pascal standard }
function RiceviStringa(Stream: TStream): string;
var
  L: Integer;
begin
  Stream.ReadBuffer(L, SizeOf(L));
  SetLength(Result, L);
  if L > 0 then
    Stream.ReadBuffer(Result[1], L * SizeOf(Char));
end;

procedure NewOperazione(out P: POperazione);
begin
  New(P);
  P^.FileData := nil;
end;

procedure SetOperationFile(P: POperazione; const AFileName: string);
begin
  if (AFileName <> '') and FileExists(AFileName) then
  begin
    // Percorso raggiungibile: (ri)legge sempre il contenuto corrente su disco
    if not Assigned(P^.FileData) then
      P^.FileData := TMemoryStream.Create;
    try
      P^.FileData.LoadFromFile(AFileName);
      P^.FileData.Position := 0;
    except
      P^.FileData.Clear;
    end;
  end
  else if P^.filename <> AFileName then
  begin
    // Il nome file e' cambiato (o e' stato svuotato) ma il nuovo percorso non e' raggiungibile:
    // non c'e' piu' un contenuto valido da incorporare per il nuovo riferimento.
    if not Assigned(P^.FileData) then
      P^.FileData := TMemoryStream.Create
    else
      P^.FileData.Clear;
  end;
  // Se AFileName coincide con il vecchio filename ma non e' raggiungibile su disco (es. dopo
  // aver caricato un progetto su un altro PC), si preserva il FileData gia' incorporato.
  P^.filename := AFileName;
end;

function ResolveOperationFile(P: POperazione; out IsTemp: boolean): string;
var
  Ext: string;
  TempFS: TFileStream;
  Guid: TGUID;
begin
  IsTemp := false;
  Result := P^.filename;
  if Assigned(P^.FileData) and (P^.FileData.Size > 0) then
  begin
    Ext := ExtractFileExt(P^.filename);
    CreateGUID(Guid);
    Result := IncludeTrailingPathDelimiter(GetTempDir) + 'ttcam_' + Copy(GUIDToString(Guid), 2, 36) + Ext;
    TempFS := TFileStream.Create(Result, fmCreate);
    try
      P^.FileData.Position := 0;
      TempFS.CopyFrom(P^.FileData, P^.FileData.Size);
      P^.FileData.Position := 0;
    finally
      TempFS.Free;
    end;
    IsTemp := true;
  end;
end;

procedure FreeOperazione(var P: POperazione);
begin
  if not Assigned(P) then Exit;
  FreeAndNil(P^.FileData);
  Finalize(P^);
  Dispose(P);
  P := nil;
end;

{ SALVATAGGIO DI UN SINGOLO RECORD }
procedure InviaRecord(Stream: TStream; P: POperazione);
var
  L, I: Integer;
  L64: Int64;
begin
  // 1. Campi numerici fissi iniziali
  Stream.WriteBuffer(P^.op, SizeOf(Integer));
  Stream.WriteBuffer(P^.X, SizeOf(Single));
  Stream.WriteBuffer(P^.Y, SizeOf(Single));
  Stream.WriteBuffer(P^.RapidFeed, SizeOf(Single));
  Stream.WriteBuffer(P^.HFeed, SizeOf(Single));
  Stream.WriteBuffer(P^.ZFeed, SizeOf(Single));
  Stream.WriteBuffer(P^.ToolDia, SizeOf(Single));
  Stream.WriteBuffer(P^.ZStart, SizeOf(Single));
  Stream.WriteBuffer(P^.ZDepth, SizeOf(Single));
  Stream.WriteBuffer(P^.ZStep, SizeOf(Single));
  Stream.WriteBuffer(P^.maxRamp, SizeOf(Single));
  Stream.WriteBuffer(P^.finishAllowance, SizeOf(Single));
  Stream.WriteBuffer(P^.Spindle, SizeOf(Integer));
  Stream.WriteBuffer(P^.direction, SizeOf(byte));

  // 2. Array Dinamico di Single (Lunghezza + Dati)
  L := Length(P^.specific);
  Stream.WriteBuffer(L, SizeOf(L));
  if L > 0 then
    Stream.WriteBuffer(P^.specific[0], L * SizeOf(Single));

  // 3. Array Dinamico di Boolean (Lunghezza + Dati)
  L := Length(P^.specificBool);
  Stream.WriteBuffer(L, SizeOf(L));
  if L > 0 then
    Stream.WriteBuffer(P^.specificBool[0], L * SizeOf(Boolean));

  // 4. Array Dinamico di Integer (Lunghezza + Dati)
  L := Length(P^.specificInteger);
  Stream.WriteBuffer(L, SizeOf(L));
  if L > 0 then
    Stream.WriteBuffer(P^.specificInteger[0], L * SizeOf(Integer));

  // 5. Array Dinamico di Stringhe (Lunghezza + Ciclo per ogni stringa)
  L := Length(P^.specificText);
  Stream.WriteBuffer(L, SizeOf(L));
  for I := 0 to L - 1 do
    InviaStringa(Stream, P^.specificText[I]);

  // 6. Stringhe singole centrali
  InviaStringa(Stream, P^.text);
  InviaStringa(Stream, P^.fontName);

  // 7. Campi Booleani
  Stream.WriteBuffer(P^.laserMode, SizeOf(Boolean));
  Stream.WriteBuffer(P^.enabled, SizeOf(Boolean));

  // 8. Ultime Stringhe e dati intermedi
  InviaStringa(Stream, P^.filename);
  InviaStringa(Stream, P^.result);
  Stream.WriteBuffer(P^.listPosition, SizeOf(Integer));

  // 9. Salvataggio della matrice di trasformazione
  Stream.WriteBuffer(P^.TransformationMatrix, SizeOf(TTransformationMatrix));

  // 10. Salvataggio del file binario incorporato (PCB/SVG/Laser Picture/Sculpting), se presente
  if Assigned(P^.FileData) then
    L64 := P^.FileData.Size
  else
    L64 := 0;
  Stream.WriteBuffer(L64, SizeOf(L64));
  if L64 > 0 then
  begin
    P^.FileData.Position := 0;
    Stream.CopyFrom(P^.FileData, L64);
    P^.FileData.Position := 0;
  end;
end;

{ CARICAMENTO DI UN SINGOLO RECORD }
procedure RiceviRecord(Stream: TStream; P: POperazione);
var
  L, I: Integer;
  L64: Int64;
begin
  // 1. Campi numerici fissi iniziali
  Stream.ReadBuffer(P^.op, SizeOf(Integer));
  Stream.ReadBuffer(P^.X, SizeOf(Single));
  Stream.ReadBuffer(P^.Y, SizeOf(Single));
  Stream.ReadBuffer(P^.RapidFeed, SizeOf(Single));
  Stream.ReadBuffer(P^.HFeed, SizeOf(Single));
  Stream.ReadBuffer(P^.ZFeed, SizeOf(Single));
  Stream.ReadBuffer(P^.ToolDia, SizeOf(Single));
  Stream.ReadBuffer(P^.ZStart, SizeOf(Single));
  Stream.ReadBuffer(P^.ZDepth, SizeOf(Single));
  Stream.ReadBuffer(P^.ZStep, SizeOf(Single));
  Stream.ReadBuffer(P^.maxRamp, SizeOf(Single));
  Stream.ReadBuffer(P^.finishAllowance, SizeOf(Single));
  Stream.ReadBuffer(P^.Spindle, SizeOf(Integer));
  Stream.ReadBuffer(P^.direction, SizeOf(byte));

  // 2. Array Dinamico di Single
  Stream.ReadBuffer(L, SizeOf(L));
  SetLength(P^.specific, L);
  if L > 0 then
    Stream.ReadBuffer(P^.specific[0], L * SizeOf(Single));

  // 3. Array Dinamico di Boolean
  Stream.ReadBuffer(L, SizeOf(L));
  SetLength(P^.specificBool, L);
  if L > 0 then
    Stream.ReadBuffer(P^.specificBool[0], L * SizeOf(Boolean));

  // 4. Array Dinamico di Integer
  Stream.ReadBuffer(L, SizeOf(L));
  SetLength(P^.specificInteger, L);
  if L > 0 then
    Stream.ReadBuffer(P^.specificInteger[0], L * SizeOf(Integer));

  // 5. Array Dinamico di Stringhe
  Stream.ReadBuffer(L, SizeOf(L));
  SetLength(P^.specificText, L);
  for I := 0 to L - 1 do
    P^.specificText[I] := RiceviStringa(Stream);

  // 6. Stringhe singole centrali
  P^.text := RiceviStringa(Stream);
  P^.fontName := RiceviStringa(Stream);

  // 7. Campi Booleani
  Stream.ReadBuffer(P^.laserMode, SizeOf(Boolean));
  Stream.ReadBuffer(P^.enabled, SizeOf(Boolean));

  // 8. Ultime Stringhe e dati intermedi
  P^.filename := RiceviStringa(Stream);
  P^.result := RiceviStringa(Stream);
  Stream.ReadBuffer(P^.listPosition, SizeOf(Integer));

  // 9. Caricamento della matrice di trasformazione
  Stream.ReadBuffer(P^.TransformationMatrix, SizeOf(TTransformationMatrix));

  // 10. Caricamento del file binario incorporato (PCB/SVG/Laser Picture/Sculpting), se presente
  Stream.ReadBuffer(L64, SizeOf(L64));
  if L64 > 0 then
  begin
    P^.FileData := TMemoryStream.Create;
    P^.FileData.CopyFrom(Stream, L64);
    P^.FileData.Position := 0;
  end
  else
    P^.FileData := nil;
end;

{ FUNZIONE GLOBALE DI SALVATAGGIO DELLA TLIST }
function SalvaListaOperazioni(AList: TList; const AFileName: string; const AProjectComment: string): boolean;
var
  FS: TFileStream;
  TotaleRecord, I: Integer;
  DummySize: Int64;
  FinalSize: Int64;
  Digest: TMD5Digest;
begin
  Result := false;
  if AList = nil then Exit;

  FS := TFileStream.Create(AFileName, fmCreate);
  try
    // 1. Scrittura Intestazione (Firma + Placeholder per la dimensione del file + Versione programma)
    FS.WriteBuffer(FILE_SIGNATURE[1], Length(FILE_SIGNATURE));
    DummySize := 0;
    FS.WriteBuffer(DummySize, SizeOf(DummySize));
    FS.WriteBuffer(TTCAM_VERSION_MAJOR, SizeOf(TTCAM_VERSION_MAJOR));
    FS.WriteBuffer(TTCAM_VERSION_MINOR, SizeOf(TTCAM_VERSION_MINOR));

    // 1b. Commento di progetto (nota libera inserita dall'utente)
    InviaStringa(FS, AProjectComment);

    // 2. Scrittura dei dati effettivi (Payload)
    TotaleRecord := AList.Count;
    FS.WriteBuffer(TotaleRecord, SizeOf(TotaleRecord));

    for I := 0 to TotaleRecord - 1 do
      InviaRecord(FS, POperazione(AList[I]));

    // 3. Calcolo e aggiornamento della dimensione finale del file nel file stesso
    FinalSize := FS.Size + SizeOf(TMD5Digest); // Dimensione totale includendo il checksum finale
    FS.Position := Length(FILE_SIGNATURE);
    FS.WriteBuffer(FinalSize, SizeOf(FinalSize));

    // 4. Calcolo del checksum MD5 (su tutto il file, escludendo lo spazio per l'MD5 stesso)
    Digest := CalcolaMD5Stream(FS, FS.Size);

    // 5. Scrittura del checksum in coda al file
    FS.Position := FS.Size;
    FS.WriteBuffer(Digest, SizeOf(Digest));

    Result := true;
  finally
    FS.Free;
  end;
end;

procedure CaricaListaOperazioniStream(AList: TList; AStream: TStream; out AFileVersionMajor, AFileVersionMinor: Word; out AProjectComment: string);
var
  TotaleRecord, I: Integer;
  NuovoP: POperazione;
  a: integer;
  LettaFirma: array[1..4] of Char;
  LettaDimensione: Int64;
  MD5Letto, MD5Calcolato: TMD5Digest;
begin
  AFileVersionMajor := 0;
  AFileVersionMinor := 0;
  AProjectComment := '';
  if (AList = nil) or (AStream = nil) then Exit;

  // Controllo di sicurezza minimo sulla dimensione (Header + MD5)
  if AStream.Size < (HEADER_SIZE + SizeOf(TMD5Digest)) then
    raise Exception.Create('File corrotto: dimensione troppo piccola per essere un file CAM valido.');

  // 1. Validazione Firma Intestazione
  AStream.ReadBuffer(LettaFirma[1], 4);
  if LettaFirma <> FILE_SIGNATURE then
    raise Exception.Create('Formato file non valido: firma dell''intestazione non riconosciuta.');

  // 2. Validazione Dimensione dichiarata
  AStream.ReadBuffer(LettaDimensione, SizeOf(LettaDimensione));
  if AStream.Size <> LettaDimensione then
    raise Exception.CreateFmt('Integrità file compromessa: la dimensione reale (%d byte) ' +
      'non corrisponde a quella dichiarata nell''intestazione (%d byte).', [AStream.Size, LettaDimensione]);

  // 2b. Lettura del numero di versione del programma con cui e' stato salvato il progetto
  AStream.ReadBuffer(AFileVersionMajor, SizeOf(AFileVersionMajor));
  AStream.ReadBuffer(AFileVersionMinor, SizeOf(AFileVersionMinor));

  // 3. Estrazione e validazione del Checksum MD5 posizionato in coda
  AStream.Position := AStream.Size - SizeOf(TMD5Digest);
  AStream.ReadBuffer(MD5Letto, SizeOf(MD5Letto));

  // Calcoliamo l'MD5 su tutto lo stream eccetto gli ultimi 16 byte del checksum
  MD5Calcolato := CalcolaMD5Stream(AStream, AStream.Size - SizeOf(TMD5Digest));

  if not MD5Match(MD5Letto, MD5Calcolato) then
    raise Exception.Create('Integrità file compromessa: il checksum MD5 non corrisponde. Il file potrebbe essere corrotto.');

  // --- Se tutti i controlli passano, procediamo a liberare la vecchia lista e a caricare i dati ---
  for a := 0 to AList.Count - 1 do
  begin
    NuovoP := AList.Items[a];
    FreeOperazione(NuovoP);
  end;
  AList.Clear;

  // Posizioniamo lo stream subito dopo l'intestazione per iniziare a leggere il payload
  AStream.Position := HEADER_SIZE;
  AProjectComment := RiceviStringa(AStream);
  AStream.ReadBuffer(TotaleRecord, SizeOf(TotaleRecord));

  for I := 0 to TotaleRecord - 1 do
  begin
    New(NuovoP);
    Initialize(NuovoP^);
    RiceviRecord(AStream, NuovoP);
    AList.Add(NuovoP);
  end;
end;

{ FUNZIONE GLOBALE DI CARICAMENTO DELLA TLIST DA FILE }
procedure CaricaListaOperazioni(AList: TList; const AFileName: string; out AFileVersionMajor, AFileVersionMinor: Word; out AProjectComment: string);
var
  FS: TFileStream;
begin
  AFileVersionMajor := 0;
  AFileVersionMinor := 0;
  AProjectComment := '';
  if (AList = nil) or not FileExists(AFileName) then Exit;

  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    CaricaListaOperazioniStream(AList, FS, AFileVersionMajor, AFileVersionMinor, AProjectComment);
  finally
    FS.Free;
  end;
end;

end.
