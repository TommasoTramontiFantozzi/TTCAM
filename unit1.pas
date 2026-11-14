unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Spin, EditBtn, ComCtrls, Buttons, Menus, gcodeGen, OpenGLContext, grandeeditortesto, gl,
  math, PcbVectorEngine, Svg2GcodeEngine, risolutore, savedatastruct, strutils,
  Svg2GcodeClipperEngine, gcodedesigner, LaserGCodeGenerator, ImageToGCode, unit2, helpContent,
  fpvectorial, fpvectorial2canvas, svgvectorialreader, fpvutils, Types, lasertestgridgenerator;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    CheckBox4: TCheckBox;
    ComboBox1: TComboBox;
    ComboBox2: TComboBox;
    ComboBox3: TComboBox;
    ComboBox4: TComboBox;
    ComboBox5: TComboBox;
    CommonSpinEdit10: TFloatSpinEdit;
    CommonSpinEdit8: TFloatSpinEdit;
    CommonSpinEdit9: TFloatSpinEdit;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Edit6: TEdit;
    Edit7: TEdit;
    EditButton1: TEditButton;
    CommonSpinEdit1: TFloatSpinEdit;
    FloatSpinEdit1: TFloatSpinEdit;
    FloatSpinEdit10: TFloatSpinEdit;
    FloatSpinEdit11: TFloatSpinEdit;
    FloatSpinEdit12: TFloatSpinEdit;
    CommonSpinEdit2: TFloatSpinEdit;
    CommonSpinEdit3: TFloatSpinEdit;
    CommonSpinEdit4: TFloatSpinEdit;
    CommonSpinEdit5: TFloatSpinEdit;
    CommonSpinEdit6: TFloatSpinEdit;
    FloatSpinEdit2: TFloatSpinEdit;
    FloatSpinEdit3: TFloatSpinEdit;
    FloatSpinEdit4: TFloatSpinEdit;
    FloatSpinEdit5: TFloatSpinEdit;
    GroupBox4: TGroupBox;
    Label35: TLabel;
    Label36: TLabel;
    Label37: TLabel;
    Label38: TLabel;
    Memo2: TMemo;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem9: TMenuItem;
    Panel10: TPanel;
    Panel11: TPanel;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    RadioButton4: TRadioButton;
    RadioGroup1: TRadioGroup;
    Separator1: TMenuItem;
    SpeedButton12: TSpeedButton;
    SpeedButton13: TSpeedButton;
    SpeedButton14: TSpeedButton;
    SpinEdit3: TSpinEdit;
    SpinEdit4: TSpinEdit;
    StatusBar1: TStatusBar;
    ToolButton2: TToolButton;
    transformationMatrix1: TFloatSpinEdit;
    FloatSpinEdit7: TFloatSpinEdit;
    FloatSpinEdit8: TFloatSpinEdit;
    FloatSpinEdit9: TFloatSpinEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    ImageList1: TImageList;
    ImageList2: TImageList;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label18: TLabel;
    Label19: TLabel;
    Label2: TLabel;
    Label20: TLabel;
    Label21: TLabel;
    Label22: TLabel;
    Label23: TLabel;
    Label24: TLabel;
    Label25: TLabel;
    Label26: TLabel;
    Label27: TLabel;
    Label28: TLabel;
    Label29: TLabel;
    Label3: TLabel;
    Label30: TLabel;
    Label31: TLabel;
    Label32: TLabel;
    Label33: TLabel;
    Label34: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    ListBox1: TListBox;
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem16: TMenuItem;
    MenuItem17: TMenuItem;
    OpenDialog1: TOpenDialog;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    Panel7: TPanel;
    Panel8: TPanel;
    Panel9: TPanel;
    SaveDialog1: TSaveDialog;
    ScrollBox1: TScrollBox;
    ScrollBox2: TScrollBox;
    SpeedButton1: TSpeedButton;
    SpeedButton10: TSpeedButton;
    SpeedButton11: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    SpeedButton6: TSpeedButton;
    SpeedButton7: TSpeedButton;
    SpeedButton8: TSpeedButton;
    SpeedButton9: TSpeedButton;
    CommonSpinEdit7: TSpinEdit;
    SpinEdit1: TSpinEdit;
    SpinEdit2: TSpinEdit;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    ToggleBox1: TToggleBox;
    ToolBar1: TToolBar;
    ToolBar2: TToolBar;
    ToolButton1: TToolButton;
    TrackBar1: TTrackBar;
    transformationMatrix2: TFloatSpinEdit;
    transformationMatrix3: TFloatSpinEdit;
    transformationMatrix4: TFloatSpinEdit;
    transformationMatrix5: TFloatSpinEdit;
    transformationMatrix6: TFloatSpinEdit;
    transformationMatrix7: TFloatSpinEdit;
    transformationMatrix8: TFloatSpinEdit;
    transformationMatrix9: TFloatSpinEdit;
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure CheckBox2Change(Sender: TObject);
    procedure CheckBox3Change(Sender: TObject);
    procedure CheckBox4Change(Sender: TObject);
    procedure EditButton1ButtonClick(Sender: TObject);
    procedure MenuItem10Click(Sender: TObject);
    procedure MenuItem11Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure ListBox1SelectionChange(Sender: TObject; User: boolean);
    function ListBoxAggiusta:boolean;
    procedure aggiorna(pxx:POperazione);
    function errorMessages(pxx:POperazione):string;
    procedure GLboxPaint(Sender: TObject);
    procedure GLboxResize(Sender: TObject);
    procedure DrawGCodeAutoCenteredCompiled(const programData: TGCodeProgram; calcLimits: boolean; WindowWidth, WindowHeight: integer; travelShow: boolean; percentage: double);
    procedure MenuItem2Click(Sender: TObject);
    procedure MenuItem3Click(Sender: TObject);
    procedure MenuItem4Click(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure MenuItem7Click(Sender: TObject);
    procedure MenuItem8Click(Sender: TObject);
    procedure MenuItem9Click(Sender: TObject);
    procedure MenuItem13Click(Sender: TObject);
    procedure MenuItem14Click(Sender: TObject);
    procedure MenuItem15Click(Sender: TObject);
    procedure MenuItem16Click(Sender: TObject);
    procedure MenuItem17Click(Sender: TObject);
    procedure LoadExampleProject(const AResourceName: string);
    function ConfirmDiscardChanges(const AQuestion: string): boolean;
    procedure RadioButton4Change(Sender: TObject);
    procedure SpeedButton10Click(Sender: TObject);
    procedure SpeedButton11Click(Sender: TObject);
    procedure SpeedButton12Click(Sender: TObject);
    procedure SpeedButton13Click(Sender: TObject);
    procedure SpeedButton14Click(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
    procedure SpeedButton3Click(Sender: TObject);
    procedure SpeedButton4Click(Sender: TObject);
    procedure glBOXMouseWheelUp(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure glBOXMouseWheelDown(Sender: TObject; Shift: TShiftState;
      MousePos: TPoint; var Handled: Boolean);
    procedure glBOXMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure glBOXMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure glBOXMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure glBOXDblClick(Sender: TObject);
    procedure ResetView;
    procedure SpeedButton5Click(Sender: TObject);
    procedure SpeedButton6Click(Sender: TObject);
    procedure SpeedButton7Click(Sender: TObject);
    procedure SpeedButton8Click(Sender: TObject);
    procedure SpeedButton9Click(Sender: TObject);
    procedure impostaTabOrder;
    procedure SpinEdit3EditingDone(Sender: TObject);
    procedure SpinEdit4EditingDone(Sender: TObject);
    procedure ToggleBox1Change(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
    procedure laserModeSetting(onOff:boolean);
    function saveData(forceAskFileName:boolean=false):boolean;
    function sostituisciRisolvi(N:integer;pqq:POperazione;tx:string):double;
    procedure slezionatoElemento;
    procedure buttonIcon;
    procedure ShowImagePreview(const AFile: string; ABytes: Int64);
    procedure ShowImagePreview(const pxx: POperazione);
    procedure BtnExportPreviewClick(Sender: TObject);
    procedure ShowProgressDialog(const ACaption: string);
    procedure HideProgressDialog;
    procedure HeavyOpProgress(Percent: Integer);
  private
    GCodeEditor:TGrandeEditorTesto;
    selezionato:integer;
    nomeFile:string;
    ProjectComment:string;
    PreviewExportFile:string;
    PreviewExportStream:TMemoryStream;
    PreviewExportName:string;
    ProgressDlg: TForm;
    ProgressBarDlg: TProgressBar;
    ProgressLabelDlg: TLabel;
    saved:boolean;
    laserTmp:boolean;
    op:integer;
    opList:TList;
    g_path:string;
    fontList:TStringList;
    gCode:string;
    gCodeCompiled:TGCodeProgram;
    travelShow:boolean;
    minX, minY, minZ, maxX, maxY, maxZ: double;
    FZoom: Double; // <--- Variabile per memorizzare lo zoom
    FCenterX, FCenterY,FCenterZ: Double; // Il centro attuale della vista (in coordinate G-Code)
    FAngleX,FAngleY,FAngleZ:double;
    FMouseX_Px, FMouseY_Px: Integer; // Memorizzano la posizione in pixel
    // --- NUOVE VARIABILI PER IL PAN ---
      FPanX, FPanY: Double;          // Spostamento totale accumulato nel mondo G-Code
      FLastMouseX, FLastMouseY: Integer; // Ultima posizione del mouse in pixel durante il drag
      FIsPanning: Boolean;          // True se la rotellina è premuta e stiamo spostando
      FIsRotating: Boolean;          // True se il pulsante destro è premuto e stiamo ruotando
  public

  end;

var
  Form1: TForm1;
  GLBox:TOpenGLControl;

implementation

{$R *.lfm}

{ TForm1 }

function IsWordChar(Ch: Char): Boolean; inline;
begin
  // A word character is alphanumeric or an underscore. Everything else
  // (spaces, tabs, commas, +, -, *, /, etc.) serves as a word boundary.
  Result := CharInSet(Ch, ['a'..'z', 'A'..'Z', '0'..'9', '_']);
end;

function PosWholeWord(const ASubstring, AText: string): Integer;
var
  SubLen, TextLen, StartPos, FoundPos: Integer;
  IsLeftValid, IsRightValid: Boolean;
begin
  Result := 0; // Default to 0 (not found)
  SubLen := Length(ASubstring);
  TextLen := Length(AText);

  if (SubLen = 0) or (TextLen = 0) or (SubLen > TextLen) then
    Exit;

  StartPos := 1;

  // Use PosEx to continually look for the substring within the text loop
  while True do
  begin
    FoundPos := PosEx(ASubstring, AText, StartPos);

    // Break early if the substring cannot be found anymore
    if FoundPos = 0 then
      Break;

    // 1. Validate Left Boundary
    if FoundPos = 1 then
      IsLeftValid := True // Start of the string is a valid boundary
    else
      IsLeftValid := not IsWordChar(AText[FoundPos - 1]);

    // 2. Validate Right Boundary
    if (FoundPos + SubLen - 1) = TextLen then
      IsRightValid := True // End of the string is a valid boundary
    else
      IsRightValid := not IsWordChar(AText[FoundPos + SubLen]);

    // 3. If both boundaries are valid, we found our whole word match
    if IsLeftValid and IsRightValid then
    begin
      Result := FoundPos;
      Exit;
    end;

    // Advance search past the current occurrence to check the next one
    StartPos := FoundPos + 1;
  end;
end;

procedure ClearAndFreeRecordList(AList: TList);
var
  I: Integer;
begin
  for I := 0 to AList.Count - 1 do
  begin
    if Assigned(AList[I]) then
      Dispose(POperazione(AList[I]));
  end;
  AList.Clear;
end;

procedure SaveRecordListToFile(AList: TList; const FileName: string);
var
  FS: TFileStream;
  I: Integer;
begin
  FS := TFileStream.Create(FileName, fmCreate);
  try
    I := AList.Count;
    FS.Write(I, SizeOf(Integer));
    for I := 0 to AList.Count - 1 do
    begin
      FS.Write(POperazione(AList[I])^, SizeOf(TOperazione));
    end;
  finally
    FS.Free;
  end;
end;

procedure LoadRecordListFromFile(AList: TList; const FileName: string);
var
  FS: TFileStream;
  I, TotalCount: Integer;
  PRec: POperazione;
begin
  ClearAndFreeRecordList(AList);
  FS := TFileStream.Create(FileName, fmOpenRead);
  try
    FS.Read(TotalCount, SizeOf(Integer));
    for I := 0 to TotalCount - 1 do
    begin
      New(PRec);
      FS.Read(PRec^, SizeOf(TOperazione));
      AList.Add(PRec);
    end;
  finally
    FS.Free;
  end;
end;

function ReadStringFromFile(const FileName: string): string;
var
  S: TFileStream;
  Count: SizeInt;
begin
  S := TFileStream.Create(FileName, fmOpenRead);
  try
    Count := S.Size;
    SetLength(Result, Count);
    S.ReadBuffer(Pointer(Result)^, Count);
  finally
    S.Free;
  end;
end;

procedure TForm1.DrawGCodeAutoCenteredCompiled(const programData: TGCodeProgram; calcLimits: boolean; WindowWidth, WindowHeight: integer; travelShow: boolean; percentage: double);
var
  sizeX, sizeY: double;
  aspectWindow: double;
  padX, padY: double;
  halfWidth, halfHeight: double;
begin
  // Attiva il test di profondità se disegni in 3D
  glEnable(GL_DEPTH_TEST);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  // 1. Calcola i limiti reali del pezzo in modo binario ultra-veloce
  if calcLimits and (Length(programData) > 0) then
  begin
    GetGCodeBoundsCompiled(programData, minX, minY, minZ, maxX, maxY, maxZ);
    FCenterX := (minX + maxX) / 2.0;
    FCenterY := (minY + maxY) / 2.0;
    FCenterZ := (minZ + maxZ) / 2.0;
  end;

  sizeX := maxX - minX;
  sizeY := maxY - minY;
  if sizeX <= 0 then sizeX := 1;
  if sizeY <= 0 then sizeY := 1;

  padX := sizeX * 0.1;
  padY := sizeY * 0.1;

  // Calcoliamo la bounding box allargata del pezzo
  sizeX := (maxX + padX) - (minX - padX);
  sizeY := (maxY + padY) - (minY - padY);

  // 2. GESTIONE ADATTAMENTO ASPECT RATIO (Previene le distorsioni)
  if (WindowWidth <= 0) or (WindowHeight <= 0) then Exit;
  aspectWindow := WindowWidth / WindowHeight;

  if (sizeX / sizeY) > aspectWindow then
    sizeY := sizeX / aspectWindow
  else
    sizeX := sizeY * aspectWindow;

  // 3. PROIEZIONE ORTOGRAFICA (Gestisce solo dimensioni e ZOOM)
  halfWidth := (sizeX / 2.0) / FZoom;
  halfHeight := (sizeY / 2.0) / FZoom;

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(-halfWidth, halfWidth, -halfHeight, halfHeight, -2000.0, 2000.0);

  // 4. MODELVIEW (Gestisce ROTAZIONE e PAN)
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();

  // A. Inclinazione 3D (Rotazioni)
  glRotated(-FAngleX, 1.0, 0.0, 0.0);
  glRotated(FAngleZ, 0.0, 0.0, 1.0);

  // B. Traslazione del centro (PAN) + Spostamento origine sul centro del pezzo
  glTranslated(FPanX, FPanY, 0.0);
  glTranslated(-FCenterX, -FCenterY, 0.0);

  // 5. DISEGNO EFFETTIVO DEI COSTRUTTI (Assi e G-Code compilato)
  // La griglia/assi e' un riferimento di sfondo, non un vero oggetto 3D: viene
  // disegnata col depth test disattivato cosi non partecipa mai allo z-buffer.
  // Altrimenti, giacendo sullo stesso piano Z=0 di gran parte del disegno, la
  // griglia genera z-fighting e "taglia" a scacchiera il percorso disegnato
  // (visibile soprattutto in vista 3D inclinata). Disabilitando qui il depth
  // test la griglia resta sempre sullo sfondo e il disegno vero, tracciato
  // subito dopo con lo z-buffer riattivato, la ricopre sempre correttamente.
  glDisable(GL_DEPTH_TEST);
  DrawAxes(sizeX, sizeY, FZoom);
  glEnable(GL_DEPTH_TEST);

  // Chiamata alla routine di disegno binario ottimizzata precedentemente creata
  label38.caption:='Last row:'+inttostr(DrawGCodeCompiled(programData, travelShow, percentage));

end;

procedure TForm1.MenuItem17Click(Sender: TObject);
var
  a:integer;
  pxx:POperazione;
begin
  if not ConfirmDiscardChanges('Save changes before creating a new project?') then exit;
  for a:=0 to opList.Count-1 do
  begin
    pxx:=opList.Items[a];
    FreeOperazione(pxx);
  end;
  opList.Clear;
  ListBoxAggiusta;
  nomeFile:='';
  ProjectComment:='';
  saved:=true;
end;

procedure TForm1.MenuItem2Click(Sender: TObject);
var
  LoadedVersionMajor, LoadedVersionMinor: Word;
begin
  OpenDialog1.Filter := 'TTCAM Project(*.ttcam)|*.ttcam|';
  if openDialog1.Execute then
  begin
    if fileExists(openDialog1.FileName) then
    begin
      try
        CaricaListaOperazioni(opList,openDialog1.FileName,LoadedVersionMajor,LoadedVersionMinor,ProjectComment);
        ListBoxAggiusta;
        nomeFile:=openDialog1.FileName;
      except
        showmessage('Error file loading');
      end;
    end
    else
    begin
      showmessage('file does not exist');
    end;
  end;
end;

function TForm1.saveData(forceAskFileName:boolean):boolean;
var
  myquestion:TModalResult;
  a,ok:boolean;
begin
  result:=false;
  ok:=false;
  if (nomeFile<>'')and(forceAskFileName=false) then
  begin
    try
      if FileExists(nomeFile) then DeleteFile(saveDialog1.FileName);
      ok:=SalvaListaOperazioni(opList,nomeFile,ProjectComment);
    except
      showmessage('Save file failed! Choose another file name.');
      ok:=false;
    end;
  end;
  if (nomeFile='') or (ok=false)or(forceAskFileName=true) then
  begin
    if saveDialog1.Execute then
    begin
      if ExtractFileExt(saveDialog1.FileName)='' then
        saveDialog1.FileName:=saveDialog1.FileName+'.ttcam';
      ok:=true;
      if FileExists(saveDialog1.FileName) then
      begin
        myquestion := MessageDlg('File already exist. Do you want replace it?' ,mtCustom,[mbYes, mbNo], 0);
        if myquestion=mrNo then exit;
        try
          ok:=DeleteFile(saveDialog1.FileName);
        except
          showmessage('Cannot save!');
          ok:=false;
        end;
      end;
      if ok then
      begin
        ok:=false;
        try
         ok:=SalvaListaOperazioni(opList,saveDialog1.FileName,ProjectComment);
        except
        end;
      end;
    end;
  end;
  result:=ok;
end;

procedure TForm1.MenuItem3Click(Sender: TObject);
begin
  if nomeFile<>'' then saveDialog1.FileName:=nomeFile;
  saved:=saveData;
end;

function SaveString(sOut:string;FileName:string):boolean;
var
  FS: TFileStream;
  i: Integer;
  Flags: Word;
begin
  result:=false;
  Flags := fmOpenReadWrite;
  if not FileExists(FileName) then
    Flags := Flags or fmCreate;
  FS := TFileStream.Create(FileName, Flags);
  try
    FS.Position := FS.Size;  // Will be 0 if file created, end of text if not
    FS.Write(sOut[1], Length(sOut) * SizeOf(Char));
    result:=true;
  finally
    FS.Free;
  end;
end;

procedure TForm1.MenuItem4Click(Sender: TObject);
var
  kk:string;
  ok:boolean;
  exportFileName:string;
begin
  ok:=true;
  DefaultFormatSettings.LongTimeFormat := 'hhnnss';
  DefaultFormatSettings.LongDateFormat := 'ddmmmmyyyy';
  DefaultFormatSettings.ShortDateFormat := 'ddmmmmyyyy';
  savedialog1.FileName:=datetostr(Now)+'_'+Timetostr(Now)+'_';
  if savedialog1.Execute then
  begin
    // ChangeFileExt sostituisce un'eventuale estensione gia' presente (es.
    // ".ttcam", rimasta nel dialogo condiviso dall'ultimo salvataggio del
    // progetto) invece di accodare ".nc" e produrre "nome.ttcam.nc".
    exportFileName:=ChangeFileExt(savedialog1.FileName,'.nc');
    if fileexists(exportFileName) then
    begin
      ok:=deleteFile(exportFileName);
    end;
    if ok then
    begin
      ok:=SaveString(gCode,exportFileName);
    end;
    if ok=false then
    begin
      showmessage('Something went wrong. File not saved!');
    end;
  end;
end;

procedure TForm1.MenuItem5Click(Sender: TObject);
begin
  // La richiesta di salvataggio e' gestita centralmente in FormCloseQuery,
  // cosi' da coprire anche la chiusura dalla X della finestra o Alt+F4,
  // non solo questo menu.
  Form1.Close;
end;

procedure TForm1.MenuItem7Click(Sender: TObject);
begin
  form3.Show;
end;

procedure TForm1.MenuItem8Click(Sender: TObject);
begin
  form2.Show;
end;

procedure TForm1.MenuItem9Click(Sender: TObject);
begin
  saved:=savedata(true);
end;

// I progetti di esempio sono incorporati nell'eseguibile come risorse RCDATA
// (vedi project1.lpi) invece che come file .ttcam esterni sul disco: cosi'
// il programma resta autocontenuto in un unico file e gli esempi restano
// disponibili anche se distribuito senza cartella accessoria.
procedure TForm1.LoadExampleProject(const AResourceName: string);
var
  ResStream: TResourceStream;
  LoadedVersionMajor, LoadedVersionMinor: Word;
begin
  try
    ResStream:=TResourceStream.Create(HInstance, AResourceName, RT_RCDATA);
    try
      CaricaListaOperazioniStream(opList,ResStream,LoadedVersionMajor,LoadedVersionMinor,ProjectComment);
      ListBoxAggiusta;
      nomeFile:='';
      saved:=true;
    finally
      ResStream.Free;
    end;
  except
    showmessage('Error loading example project');
  end;
end;

procedure TForm1.MenuItem13Click(Sender: TObject);
begin
  LoadExampleProject('EXAMPLE1');
end;

procedure TForm1.MenuItem14Click(Sender: TObject);
begin
  LoadExampleProject('EXAMPLE2');
end;

procedure TForm1.MenuItem15Click(Sender: TObject);
begin
  LoadExampleProject('EXAMPLE3');
end;

procedure TForm1.MenuItem16Click(Sender: TObject);
begin
  LoadExampleProject('EXAMPLE4');
end;

procedure TForm1.RadioButton4Change(Sender: TObject);
begin
  if radioButton4.Checked then
  begin
    label37.Enabled:=true;
    memo2.Enabled:=true;
  end
  else
  begin
    label37.Enabled:=false;
    memo2.Enabled:=false;
  end;
end;

procedure TForm1.buttonIcon;
begin
  if op=1 then speedButton1.ImageIndex:=1 else speedButton1.ImageIndex:=0;
  if op=2 then speedButton2.ImageIndex:=3 else speedButton2.ImageIndex:=2;
  if op=3 then speedButton3.ImageIndex:=5 else speedButton3.ImageIndex:=4;
  if op=4 then speedButton4.ImageIndex:=7 else speedButton4.ImageIndex:=6;
  if op=5 then speedButton6.ImageIndex:=9 else speedButton6.ImageIndex:=8;
  if op=6 then speedButton7.ImageIndex:=11 else speedButton7.ImageIndex:=10;
  if op=7 then speedButton9.ImageIndex:=15 else speedButton9.ImageIndex:=14;
  if op=8 then speedButton8.ImageIndex:=13 else speedButton8.ImageIndex:=12;
  if op=9 then speedButton10.ImageIndex:=17 else speedButton10.ImageIndex:=16;
  if op=10 then speedButton11.ImageIndex:=19 else speedButton11.ImageIndex:=18;
  if op=11 then speedButton12.ImageIndex:=21 else speedButton12.ImageIndex:=20;
  if op=12 then speedButton13.ImageIndex:=23 else speedButton13.ImageIndex:=22;
  if op=13 then speedButton14.ImageIndex:=25 else speedButton14.ImageIndex:=24;
end;

procedure TForm1.SpeedButton10Click(Sender: TObject);
begin
  listBox1.ItemIndex:=-1;
  op:=9;buttonIcon;
  groupBox1.Caption:='Translate parameters';
  panel8.Visible:=true;
  panel9.Visible:=false;
  panel11.Visible:=false;
  button6.Enabled:=false;
  label20.Enabled:=false;
  label21.Enabled:=false;
  label22.Enabled:=false;
  label23.Enabled:=false;
  Label26.Caption:='Translate to';
  spinEdit1.Enabled:=false;
  spinEdit2.Enabled:=false;
  edit2.Visible:=false;
  edit3.Visible:=false;
  floatSpinEdit1.Visible:=true;
  floatSpinEdit2.Visible:=true;
  floatSpinEdit3.Visible:=true;
  floatSpinEdit4.Visible:=true;
  floatSpinEdit5.Visible:=true;
  floatSpinEdit1.Enabled:=true;
  floatSpinEdit2.Enabled:=true;
  floatSpinEdit3.Enabled:=false;
  floatSpinEdit4.Enabled:=false;
  floatSpinEdit5.Enabled:=false;
  edit2.Visible:=false;
  edit3.Visible:=false;
  edit4.Visible:=false;
  edit5.Visible:=false;
  edit7.Visible:=false;
  edit2.Enabled:=false;
  edit3.Enabled:=false;
  edit4.Enabled:=false;
  edit5.Enabled:=false;
  edit7.Enabled:=false;

  CommonSpinEdit1.Enabled:=false;
  CommonSpinEdit2.Enabled:=false;
  CommonSpinEdit3.Enabled:=false;
  CommonSpinEdit4.Enabled:=false;
  CommonSpinEdit5.Enabled:=false;
  CommonSpinEdit6.Enabled:=false;
  CommonSpinEdit7.Enabled:=false;
  CommonSpinEdit8.Enabled:=false;
  CommonSpinEdit9.Enabled:=false;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=false;
  CheckBox3.Enabled:=false;

  impostaTabOrder;
end;

procedure TForm1.SpeedButton11Click(Sender: TObject);
begin
  listBox1.ItemIndex:=-1;
  op:=10;buttonIcon;
  groupBox1.Caption:='Rotate parameters';
  panel8.Visible:=true;
  panel9.Visible:=false;
  panel11.Visible:=false;
  button6.Enabled:=false;
  label20.Enabled:=false;
  label21.Enabled:=false;
  label22.Enabled:=false;
  label23.Enabled:=false;
  Label26.Caption:='Rotate';
  spinEdit1.Enabled:=false;
  spinEdit2.Enabled:=false;
  edit2.Visible:=false;
  edit3.Visible:=false;
  floatSpinEdit1.Visible:=true;
  floatSpinEdit2.Visible:=true;
  floatSpinEdit3.Visible:=true;
  floatSpinEdit4.Visible:=true;
  floatSpinEdit5.Visible:=true;
  floatSpinEdit1.Enabled:=false;
  floatSpinEdit2.Enabled:=false;
  floatSpinEdit3.Enabled:=true;
  floatSpinEdit4.Enabled:=true;
  floatSpinEdit5.Enabled:=true;
  edit2.Visible:=false;
  edit3.Visible:=false;
  edit4.Visible:=false;
  edit5.Visible:=false;
  edit7.Visible:=false;
  edit2.Enabled:=false;
  edit3.Enabled:=false;
  edit4.Enabled:=false;
  edit5.Enabled:=false;
  edit7.Enabled:=false;

  CommonSpinEdit1.Enabled:=false;
  CommonSpinEdit2.Enabled:=false;
  CommonSpinEdit3.Enabled:=false;
  CommonSpinEdit4.Enabled:=false;
  CommonSpinEdit5.Enabled:=false;
  CommonSpinEdit6.Enabled:=false;
  CommonSpinEdit7.Enabled:=false;
  CommonSpinEdit8.Enabled:=false;
  CommonSpinEdit9.Enabled:=false;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=false;
  CheckBox3.Enabled:=false;

  impostaTabOrder;
end;

procedure TForm1.SpeedButton12Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  laserModeSetting(true);
  checkBox3.Checked:=true;
  checkBox3.Enabled:=false;
  Combobox3.Enabled:=false;
  CommonSpinEdit7.Enabled:=false;
  groupBox1.Caption:='Picture parameters';
  op:=11;buttonIcon;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=true;
  Label10.Visible:=true;
  Label11.Visible:=false;
  Label12.Visible:=true;
  Label13.Visible:=true;
  Label14.Visible:=true;
  Label16.Visible:=true;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=true;
  FloatSpinEdit10.Visible:=true;
  FloatSpinEdit11.Visible:=false;
  FloatSpinEdit12.Visible:=false;
  SpinEdit3.Visible:=true;
  SpinEdit4.Visible:=true;
  FloatSpinEdit9.Value:=1;
  comboBox1.Visible:=false;
  comboBox2.Visible:=false;
  comboBox4.Visible:=false;
  comboBox5.Visible:=true;
  checkBox2.Visible:=false;
  edit1.Visible:=false;
  checkBox4.Visible:=false;
  editButton1.Visible:=true;
  editButton1.Text:='';
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  a:=a+32;
  SpinEdit3.Top:=a;
  Label13.top:=a+14;
  a:=a+32;
  SpinEdit4.Top:=a;
  Label14.top:=a+14;
  a:=a+32;
  comboBox5.Top:=a+4;
  Label16.top:=a+14;
  a:=a+38;
  editButton1.Top:=a;
  Label12.top:=a+14;
  a:=a+32;
  togglebox1.visible:=false;
  groupBox3.Visible:=false;
  FloatSpinEdit9.Value:=100;
  if CommonSpinEdit4.Value>0.3 then CommonSpinEdit4.Value:=0.15;
  Label16.Caption:='Crosshatch';
  Label12.Caption:='File';
  Label7.Caption:='X';
  Label8.Caption:='Y';
  Label9.Caption:='Width';
  Label10.Caption:='Gamma';
  Label13.Caption:='Min Power';
  Label14.Caption:='Max Power';
  FloatSpinEdit10.Value:=1;
  SpinEdit3.Value:=50;
  SpinEdit4.Value:=750;
  impostaTabOrder;
  statusBar1.Panels[0].Text:='Images to laser';
end;

procedure TForm1.SpeedButton13Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  checkBox3.Checked:=false;
  laserModeSetting(false);
  groupBox1.Caption:='Sculpt parameters';
  op:=12;buttonIcon;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=true;
  Label10.Visible:=false;
  Label11.Visible:=false;
  Label12.Visible:=true;
  Label13.Visible:=false;
  Label14.Visible:=false;
  Label16.Visible:=true;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=true;
  FloatSpinEdit10.Visible:=false;
  FloatSpinEdit11.Visible:=false;
  FloatSpinEdit12.Visible:=false;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit9.Value:=1;
  comboBox1.Visible:=false;
  comboBox2.Visible:=false;
  comboBox4.Visible:=false;
  comboBox5.Visible:=false;
  checkBox2.Visible:=false;
  edit1.Visible:=false;
  checkBox4.Visible:=true;
  editButton1.Visible:=true;
  editButton1.Text:='';
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  //a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  a:=a+32;
  checkBox4.Top:=a+4;
  Label16.top:=a+14;
  a:=a+32;
  editButton1.Top:=a;
  Label12.top:=a+14;
  a:=a+38;
  togglebox1.visible:=false;
  groupBox3.Visible:=false;
  FloatSpinEdit9.Value:=100;
  Label12.Caption:='File';
  Label7.Caption:='X';
  Label8.Caption:='Y';
  Label9.Caption:='Width';
  Label16.Caption:='CrossHatch';
  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=true;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=true;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=false;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=false;
  CheckBox3.Enabled:=false;

  impostaTabOrder;
  statusBar1.Panels[0].Text:='White corresponds to ZStart. Black corresponds to ZDepth.';
end;

procedure TForm1.SpeedButton14Click(Sender: TObject);
begin
  listBox1.ItemIndex:=-1;
  op:=13;buttonIcon;
  panel11.Visible:=true;
  panel8.Visible:=false;
  panel9.Visible:=false;
  groupBox1.Caption:='Direct GCode insertion';
  CommonSpinEdit1.Enabled:=false;
  CommonSpinEdit2.Enabled:=false;
  CommonSpinEdit3.Enabled:=false;
  CommonSpinEdit4.Enabled:=false;
  CommonSpinEdit5.Enabled:=false;
  CommonSpinEdit6.Enabled:=false;
  CommonSpinEdit7.Enabled:=false;
  CommonSpinEdit8.Enabled:=false;
  CommonSpinEdit9.Enabled:=false;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=false;
  CheckBox3.Enabled:=false;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  laserModeSetting(true);
  groupBox1.Caption:='Rect parameters';
  op:=1;buttonIcon;
  editButton1.Visible:=false;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=true;
  Label10.Visible:=true;
  Label11.Visible:=true;
  Label12.Visible:=false;
  Label13.Visible:=false;
  Label14.Visible:=true;
  Label16.Visible:=true;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=true;
  FloatSpinEdit10.Visible:=true;
  FloatSpinEdit11.Visible:=true;
  FloatSpinEdit12.Visible:=true;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit9.Value:=0;
  FloatSpinEdit10.Value:=0;
  FloatSpinEdit11.Value:=0;
  FloatSpinEdit12.Value:=0;
  togglebox1.Visible:=true;
  comboBox1.Visible:=false;
  comboBox2.Visible:=true;
  comboBox4.Visible:=false;
  comboBox5.Visible:=false;
  checkBox2.Visible:=false;
  checkBox4.Visible:=false;
  edit1.Visible:=false;
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  a:=a+32;
  FloatSpinEdit11.Top:=a;
  Label11.top:=a+14;
  Label11.Caption:='Radius';
  a:=a+32;
  FloatSpinEdit12.Top:=a;
  Label16.top:=a+14;
  a:=a+32;
  comboBox2.Top:=a;
  Label14.top:=a+14;
  a:=a+34;
  togglebox1.Top:=a;
  togglebox1.Checked:=false;
  a:=a+32;
  groupBox3.Top:=a;
  groupBox3.Visible:=false;
  FloatSpinEdit10.Enabled:=true;
  if CommonSpinEdit4.Value<1 then CommonSpinEdit4.Value:=3;
  Label7.Caption:='X';
  Label8.Caption:='Y';
  Label9.Caption:='Width';
  Label10.Caption:='Height';
  Label14.Caption:='Compensation';
  Label16.Caption:='Thickness';
  FloatSpinEdit11.Enabled:=true;
  FloatSpinEdit12.Enabled:=true;

  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=true;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=true;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=true;
  CommonSpinEdit10.Enabled:=true;
  Combobox3.Enabled:=true;
  CheckBox3.Enabled:=true;

  impostaTabOrder;
end;

procedure TForm1.SpeedButton2Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  laserModeSetting(true);
  groupBox1.Caption:='Circle parameters';
  op:=2;buttonIcon;
  editButton1.Visible:=false;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=false;
  Label10.Visible:=false;
  Label11.Visible:=true;
  Label12.Visible:=false;
  Label13.Visible:=false;
  Label14.Visible:=true;
  Label16.Visible:=true;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=false;
  FloatSpinEdit10.Visible:=false;
  FloatSpinEdit11.Visible:=true;
  FloatSpinEdit12.Visible:=true;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit9.Value:=0;
  FloatSpinEdit10.Value:=0;
  FloatSpinEdit11.Value:=0;
  FloatSpinEdit12.Value:=0;
  togglebox1.Visible:=true;
  comboBox1.Visible:=false;
  comboBox2.Visible:=true;
  comboBox4.Visible:=false;
  comboBox5.Visible:=false;
  checkBox2.Visible:=false;
  checkBox4.Visible:=false;
  edit1.Visible:=false;
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  //a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  //a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  a:=a+32;
  FloatSpinEdit11.Top:=a;
  Label11.top:=a+14;
  Label11.Caption:='Radius';
  a:=a+32;
  FloatSpinEdit12.Top:=a;
  Label16.top:=a+14;
  a:=a+32;
  comboBox2.Top:=a;
  Label14.top:=a+14;
  a:=a+34;
  togglebox1.Top:=a;
  togglebox1.Checked:=false;
  a:=a+32;
  groupBox3.Top:=a;
  groupBox3.Visible:=false;
  FloatSpinEdit10.Enabled:=true;
  if CommonSpinEdit4.Value<1 then CommonSpinEdit4.Value:=3;
  Label7.Caption:='X';
  Label8.Caption:='Y';
  Label14.Caption:='Compensation';
  Label16.Caption:='Thickness';
  FloatSpinEdit11.Enabled:=true;
  FloatSpinEdit12.Enabled:=true;

  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=true;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=true;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=true;
  CommonSpinEdit10.Enabled:=true;
  Combobox3.Enabled:=true;
  CheckBox3.Enabled:=true;

  impostaTabOrder;
end;

procedure TForm1.SpeedButton3Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  checkBox3.Enabled:=true;;
  laserModeSetting(true);
  groupBox1.Caption:='Text parameters';
  op:=3;buttonIcon;
  editButton1.Visible:=false;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=false;
  Label10.Visible:=false;
  Label11.Visible:=true;
  Label12.Visible:=true;
  Label13.Visible:=true;
  Label14.Visible:=false;
  Label16.Visible:=false;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=false;
  FloatSpinEdit10.Visible:=false;
  FloatSpinEdit11.Visible:=true;
  FloatSpinEdit12.Visible:=false;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit11.Value:=10;
  comboBox1.Visible:=true;
  comboBox2.Visible:=false;
  comboBox4.Visible:=false;
  comboBox5.Visible:=false;
  checkBox2.Visible:=false;
  checkBox4.Visible:=false;
  edit1.Visible:=true;
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  //a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  //a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  a:=a+32;
  FloatSpinEdit11.Top:=a;
  Label11.top:=a+14;
  a:=a+32;
  edit1.Top:=a;
  Label12.top:=a+14;
  a:=a+32;
  comboBox1.Top:=a;
  Label13.top:=a+14;
  togglebox1.visible:=false;
  groupBox3.Visible:=false;
  if CommonSpinEdit4.Value<1 then CommonSpinEdit4.Value:=2;
  Label11.Caption:='Size';
  Label12.Caption:='Text';
  Label13.Caption:='Font';
  Label7.Caption:='X';
  Label8.Caption:='Y';
  FloatSpinEdit11.Enabled:=true;

  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=true;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=true;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=false;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=true;

  impostaTabOrder;
end;

procedure TForm1.SpeedButton4Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  laserModeSetting(true);
  groupBox1.Caption:='PCB parameters';
  op:=4;buttonIcon;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=true;
  Label10.Visible:=true;
  Label11.Visible:=true;
  Label12.Visible:=true;
  Label13.Visible:=true;
  Label14.Visible:=true;
  Label16.Visible:=false;
  Label17.Visible:=true;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=true;
  FloatSpinEdit10.Visible:=true;
  FloatSpinEdit11.Visible:=true;
  FloatSpinEdit12.Visible:=true;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit9.Value:=96;
  FloatSpinEdit10.Value:=0;
  FloatSpinEdit11.Value:=1.2;
  FloatSpinEdit12.Value:=0;
  comboBox1.Visible:=false;
  comboBox2.Visible:=false;
  comboBox4.Visible:=false;
  comboBox5.Visible:=false;
  checkBox2.Visible:=true;
  checkBox4.Visible:=true;
  edit1.Visible:=false;
  editButton1.Visible:=true;
  editButton1.Text:='';
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  a:=a+32;
  checkbox4.Top:=a+7;
  Label14.top:=a+14;
  a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  a:=a+32;
  checkbox2.Top:=a+7;
  Label17.top:=a+14;
  a:=a+32;
  FloatSpinEdit11.Top:=a;
  Label11.top:=a+14;
  a:=a+32;
  FloatSpinEdit12.Top:=a;
  Label13.top:=a+14;
  a:=a+32;
  editButton1.Top:=a;
  Label12.top:=a+14;
  togglebox1.visible:=false;
  groupBox3.Visible:=false;
  Label12.Caption:='File';
  Label7.Caption:='X';
  Label8.Caption:='Y';
  Label9.Caption:='DPI';
  Label10.Caption:='Expand Traces';
  Label11.Caption:='Max Holes dia';
  Label14.Caption:='Traces';
  Label17.Caption:='Auto Hole (red pads)';
  Label13.Caption:='Holes Depth';
  if CommonSpinEdit4.Value>0.3 then CommonSpinEdit4.Value:=0.15;
  FloatSpinEdit11.enabled:=checkbox2.Checked;
  FloatSpinEdit12.enabled:=checkbox2.Checked;
  FloatSpinEdit10.Enabled:=checkbox4.Checked;
  if CheckBox2.Checked=false then checkBox4.Checked:=true;
  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=false;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=checkBox3.Checked;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=false;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=false;
  CheckBox3.Enabled:=true;

  impostaTabOrder;
  statusBar1.Panels[0].Text:='Copper traces must be black RGB(0,0,0), holes full red RGB(255,0,0), not covered area full white RGB(255,255,255)';
end;


procedure TForm1.GLboxResize(Sender: TObject);
begin
  if GLBox.Height = 0 then exit;

  glViewport(0, 0, GLBox.Width, GLBox.Height);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;

  // Imposta una proiezione prospettica o ortogonale
  // Esempio ortogonale: i limiti -1..1 mappano perfettamente la nostra scalatura 1.8
  glOrtho(-1, 1, -1, 1, -10, 10);

  glMatrixMode(GL_MODELVIEW);
end;

procedure TForm1.GLboxPaint(Sender: TObject);
begin
  glClearColor(0, 0, 0, 1.0);
  glLoadIdentity;
  glScalef(0.8, 0.8, 0.8);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity;
  DrawGCodeAutoCenteredCompiled(gCodeCompiled,false,panel5.Width,panel5.Height,travelShow,trackBar1.Position / 1000);
  GLBox.SwapBuffers;
end;

procedure EspandiStringaNumerica(const AInput: string;Numbers:pointer);
type
  TIntegerArray = array of Integer;
var
  AResult:^TIntegerArray;
  Parts, SubParts: TStringList;
  I, J, StartNum, EndNum: Integer;
begin
  AResult:=Numbers;
  // Inizializza la lista per dividere i valori separati da virgola
  Parts := TStringList.Create;
  SubParts := TStringList.Create;
  try
    Parts.CommaText := AInput; // Divide la stringa principale alle virgole
    SetLength(AResult^, 0);      // Azzera l'array di output

    for I := 0 to Parts.Count - 1 do
    begin
      // Controlla se la parte contiene un trattino (es. '2-8')
      if Pos('-', Parts[I]) > 0 then
      begin
        SubParts.Delimiter := '-';
        SubParts.StrictDelimiter := True;
        SubParts.DelimitedText := Parts[I];

        if SubParts.Count = 2 then
        begin
          // Estrae i limiti dell'intervallo
          try
            StartNum := StrToInt(SubParts[0]);
            EndNum := StrToInt(SubParts[1]);
          except
            SetLength(AResult^, 0);
            exit;
          end;
          // Inserisce tutti i numeri nell'intervallo nell'array
          for J := StartNum to EndNum do
          begin
            SetLength(AResult^, Length(AResult^) + 1);
            AResult^[High(AResult^)] := J;
          end;
        end;
      end
      else
      begin
        // Se è un numero singolo, lo aggiunge direttamente
        SetLength(AResult^, Length(AResult^) + 1);
        try
          AResult^[High(AResult^)] := StrToInt(Parts[I]);
        except
          SetLength(AResult^, 0);
          exit;
        end;
      end;
    end;
  finally
    Parts.Free;
    SubParts.Free;
  end;
end;

function TForm1.errorMessages(pxx:POperazione):string;
  function opType(op:integer):string;
  begin
    if op=1  then result:='Rectangle section';
    if op=2  then result:='Circle section';
    if op=3  then result:='Text section';
    if op=4  then result:='PCB section';
    if op=5  then result:='Line section';
    if op=6  then result:='SVG section';
    if op=7  then result:='Allen Screw section';
    if op=8  then result:='Pattern section';
    if op=9  then result:='Translate section';
    if op=10 then result:='Rotate section';
  end;
var
  ss:array [0..12] of string;
  a,b:integer;
  Numbers:array of integer;
  tt:integer;
begin
  for a:=0 to high(ss) do ss[a]:='';
  for b := 1 to high(ss) do
  begin
    if pxx^.op=b then
    begin
      if not (pxx^.op in [8,9,10]) then
      begin
        if (pxx^.laserMode=false) and (pxx^.ZDepth<=0) then ss[b]:=ss[b]+'Z depth must be specified'+#10;
      end;
    end;
  end;
  if pxx^.op=1 then
  begin
    if (pxx^.specific[2]*2>pxx^.specific[0])or(pxx^.specific[2]*2>pxx^.specific[1]) then ss[1]:=ss[1]+'Radius too big related to width or height'+#10;
    if (pxx^.specific[0]<=0)or(pxx^.specific[1]<=0) then ss[1]:=ss[1]+'Width and height must be bigger than 0'+#10;
    if (pxx^.specific[4]<0) then ss[1]:=ss[1]+'Thickness cannot be negative'+#10;
    if (pxx^.ToolDia<=0)and(pxx^.specific[4]>0) then ss[1]:=ss[1]+'When thickness is bigger than 0 tool diameter must be bigger than 0'+#10;
  end;
  if pxx^.op=2 then
  begin
    if (pxx^.specific[0]<=0) then ss[2]:=ss[2]+'Radius must be bigger than 0'+#10;
    if (pxx^.specific[4]<0) then ss[2]:=ss[2]+'Thickness cannot be negative'+#10;
    if (pxx^.ToolDia<=0)and(pxx^.specific[4]>0) then ss[2]:=ss[2]+'When thickness is bigger than 0 tool diameter must be bigger than 0'+#10;
  end;
  if pxx^.op=3 then
  begin
    if (pxx^.text='') then ss[3]:=ss[3]+'Text must be specified'+#10;
    if (pxx^.fontName='') then ss[3]:=ss[3]+'Font name must be specified'+#10;
  end;
  if pxx^.op=4 then
  begin
    if pxx^.specific[0]<=0 then ss[4]:=ss[4]+'DPI value must be specified with a > 0 value'+#10;
    if pxx^.specificBool[0] then
    begin
      if pxx^.specific[2]=0 then ss[4]:=ss[4]+'Holes max diameter must be specified'+#10;
      if pxx^.specific[3]=0 then ss[4]:=ss[4]+'Holes depth must be specified'+#10;
    end;
    if (pxx^.laserMode=true)  and (round(pxx^.ZStep)<=0) then ss[4]:=ss[4]+'Number f passes must be an integer > 0'+#10;
    if (fileExists(pxx^.filename)=false) and not(Assigned(pxx^.FileData) and (pxx^.FileData.Size>0)) then ss[4]:=ss[4]+'File does not exist'+#10;
  end;
  if pxx^.op=5 then
  begin
    if (pxx^.X=pxx^.specific[0])and(pxx^.Y=pxx^.specific[1]) then ss[5]:=ss[5]+'Line length must be bigger than 0'+#10;
    if (pxx^.ToolDia<=0)and(pxx^.specific[4]>0) then ss[5]:=ss[5]+'When thickness is bigger than 0 tool diameter must be bigger than 0'+#10;
  end;
  if pxx^.op=6 then
  begin
    if (fileExists(pxx^.filename)=false) and not(Assigned(pxx^.FileData) and (pxx^.FileData.Size>0)) then ss[6]:=ss[6]+'File does not exist'+#10;
  end;
  if pxx^.op=7 then
  begin
    if (pxx^.specific[0]<pxx^.specific[2]) then ss[7]:=ss[7]+'DiameterMajor must be bigger than DiameterMinor'+#10;
    if (pxx^.specific[0]<=0) then ss[7]:=ss[7]+'DiameterMajor must be bigger than 0'+#10;
    if (pxx^.specific[2]<=0) then ss[7]:=ss[7]+'DiameterMinor must be bigger than 0'+#10;
    if (pxx^.specific[1]>pxx^.ZDepth) then ss[7]:=ss[7]+'DiameterMajor must be minor than ZDepth'+#10;
    if (pxx^.ToolDia<=0) then ss[7]:=ss[7]+'Tool diameter must be bigger than 0'+#10;
  end;
  if (pxx^.op>=8)and(pxx^.op<=10) then
  begin
    EspandiStringaNumerica(pxx^.specificText[2],@Numbers);
    if length(Numbers)=0 then ss[8]:=ss[8]+'Features to be applied the pattern are not specified'+#10;
    for b:=0 to length(Numbers)-1 do
    begin
      tt:=opList.Count;
      if (Numbers[b]>opList.Count-1)or(Numbers[b]<1) then ss[pxx^.op]:=ss[pxx^.op]+'OpList N.'+inttostr(Numbers[b])+' does not exist'+#10;
      if (Numbers[b]>pxx^.listPosition) then ss[pxx^.op]:=ss[pxx^.op]+'You may refer only to upper features'+#10;
    end;
  end;
  for b := 1 to high(ss) do
  begin
    if ss[b]<>'' then ss[b]:='--- '+opType(b)+' ---N.'+inttostr(pxx^.listPosition+1)+#10+ss[b];
  end;
  result:='';
  for a:=0 to high(ss) do result:=result+ss[a];
  if result<>'' then result:=leftStr(result,length(result)-1);
end;

function createGCode(pxx:POperazione; g_path:string):string;
var
  ZStart,ZDepth,ZStep:double;
  GCodeOptions:TGCodeOptions;
  Compensazione:byte;
  aa,bb:double;
  TransformationMatrix:TTransformationMatrix;
  P: TGCodeParams;
  tempGCode:string;
begin
  result:=pxx^.result;
  if pxx^.laserMode then
  begin
    zStart:=0;
    ZDepth:=0.1;
    ZStep:=0.1;
  end
  else
  begin
    zStart:=pxx^.ZStart;
    ZDepth:=pxx^.ZDepth;
    ZStep:=pxx^.ZStep;
  end;
  GCodeOptions.XStart:=pxx^.X;
  GCodeOptions.YStart:=pxx^.Y;
  GCodeOptions.XYFeedRate:=pxx^.HFeed;
  GCodeOptions.ZStep:=ZStep;
  GCodeOptions.ZDepth:=ZDepth;
  GCodeOptions.ToolDiameter:=pxx^.ToolDia;
  GCodeOptions.ZSafe:=5;
  GCodeOptions.ZFeedRate:=pxx^.ZFeed;
  GCodeOptions.ZStart:=ZStart;
  GCodeOptions.SpindleSpeed:=pxx^.Spindle;
  GCodeOptions.Direction:=pxx^.direction;
  GCodeOptions.MaxRampAngle:=pxx^.maxRamp;
  GCodeOptions.RapidFeedRate:=pxx^.RapidFeed;
  if ZStep=0 then ZStep:=abs(ZDepth);
  if pxx^.op=1 then
  begin
    if pxx^.enabled and (pxx^.result='') then result:=GeneraGCodeRettangoloElicoidale(pxx^.X,pxx^.Y,pxx^.specific[0],pxx^.specific[1],pxx^.specific[2],pxx^.ToolDia,pxx^.HFeed,pxx^.ZFeed,pxx^.Spindle,ZStep,pxx^.maxRamp,ZStart,ZDepth,5,
                                                      round(pxx^.specific[3]),pxx^.direction,pxx^.specific[4],pxx^.finishAllowance,false,pxx^.TransformationMatrix);
    if pxx^.laserMode then result:=ConvertCNCToLaserMultiPass(result,pxx^.Spindle,true,round(pxx^.ZStep),pxx^.HFeed,pxx^.RapidFeed);
  end;
  if pxx^.op=2 then
  begin
    if pxx^.enabled and (pxx^.result='') then  result:=GeneraGCodeCerchioSvuotamentoElicoidale(pxx^.X,pxx^.Y,pxx^.specific[0],pxx^.ToolDia,pxx^.HFeed,pxx^.ZFeed,pxx^.Spindle,ZStep,pxx^.maxRamp,ZStart,ZDepth,5,
                                                       round(pxx^.specific[3]),pxx^.direction,pxx^.specific[4],pxx^.finishAllowance,false,pxx^.TransformationMatrix);
    if pxx^.laserMode then result:=ConvertCNCToLaserMultiPass(result,pxx^.Spindle,true,round(pxx^.ZStep),pxx^.HFeed,pxx^.RapidFeed);
  end;
  if pxx^.op=3 then
  begin
    GCodeOptions.ScaleFactor:=pxx^.specific[0];
    if pxx^.enabled and (pxx^.result='') then  result:=GenerateVectorTextGCode(pxx^.text,g_path+pxx^.fontName,GCodeOptions);
    if pxx^.laserMode then result:=ConvertCNCToLaserMultiPass(result,pxx^.Spindle,true,round(pxx^.ZStep),pxx^.HFeed,pxx^.RapidFeed);
  end;
  if pxx^.op=4 then
  begin
    if pxx^.specific[0]>0 then
    begin
      aa:=25.4/pxx^.specific[0];
      if pxx^.enabled and (pxx^.result='') then
      begin
        ZDepth:=-abs(ZDepth);
        pxx^.specific[3]:=-abs(pxx^.specific[3]);
        if (pxx^.specificBool[0]) then bb:=pxx^.specific[2] else bb:=0;
        if (pxx^.specificBool[0]) then result:=TrasformaGCode(ConvertPcbToDrillGCode(pxx^.FileData,aa,round(pxx^.ZFeed),5,pxx^.specific[3],bb),pxx^.X,pxx^.Y,0,0,0);
        if (pxx^.specific[1]>0)and(pxx^.specificBool[1]) then  result:= result+TrasformaGCode(ConvertPcbToIncisioneGCodeAdattiva(pxx^.FileData,aa,round(pxx^.HFeed),5,ZDepth,pxx^.ToolDia,bb,pxx^.specific[1]),pxx^.X,pxx^.Y,0,0,0);
        if (pxx^.specific[1]=0)and(pxx^.specificBool[1]) then  result:= result+TrasformaGCode(ConvertPcbToIncisioneGCode(pxx^.FileData,aa,round(pxx^.HFeed),5,ZDepth,pxx^.ToolDia,bb),pxx^.X,pxx^.Y,0,0,0);
        if (pxx^.laserMode)and(result<>'') then result:=ConvertCNCToLaserMultiPass(result,pxx^.Spindle,true,round(pxx^.ZStep),pxx^.HFeed,pxx^.RapidFeed);
      end;
    end;
  end;
  if pxx^.op=5 then
  begin
    TransformationMatrix.a:=1;
    TransformationMatrix.b:=0;
    TransformationMatrix.c:=0;
    TransformationMatrix.d:=1;
    TransformationMatrix.e:=0;
    TransformationMatrix.f:=0;
    if pxx^.enabled and (pxx^.result='') then result:=GeneraGCodeRettaCentrataRampa(pxx^.X,pxx^.Y,pxx^.specific[0],pxx^.specific[1],pxx^.ToolDia,pxx^.HFeed,pxx^.ZFeed,pxx^.Spindle,ZStep,pxx^.maxRamp,ZStart,ZDepth,5,0,pxx^.direction,pxx^.specific[4],pxx^.finishAllowance,TransformationMatrix);
    if pxx^.laserMode then result:=ConvertCNCToLaserMultiPass(result,pxx^.Spindle,true,round(pxx^.ZStep),pxx^.HFeed,pxx^.RapidFeed);
  end;
  if pxx^.op=6 then
  begin
    if pxx^.enabled and (pxx^.result='')and(pxx^.specificInteger[1]=0) then result:=TrasformaGCode(ConvertSvgToVectorGCode(pxx^.FileData,round(pxx^.HFeed),round(pxx^.ZFeed),5,ZStart,ZDepth,ZStep,pxx^.ToolDia,pxx^.specificInteger[0],0,0,pxx^.specific[0],true,pxx^.direction=0,pxx^.finishAllowance),pxx^.X,pxx^.Y,0,0,0);
    if pxx^.enabled and (pxx^.result='')and(pxx^.specificInteger[1]=1) then result:=TrasformaGCode(ConvertSvgToVectorGCode(pxx^.FileData,round(pxx^.HFeed),round(pxx^.ZFeed),5,ZStart,ZDepth,ZStep,pxx^.ToolDia,pxx^.specificInteger[0],0,0,pxx^.specific[0],true,pxx^.direction=0,pxx^.finishAllowance,false),pxx^.X,pxx^.Y,0,0,0);
    if pxx^.enabled and (pxx^.result='')and(pxx^.specificInteger[1]=2) then result:=TrasformaGCode(ConvertSvgToVectorGCodeClipper(pxx^.FileData,round(pxx^.HFeed),round(pxx^.ZFeed),5,ZStart,ZDepth,ZStep,pxx^.ToolDia,pxx^.specificInteger[0],0,0,pxx^.specific[0],true,pxx^.direction=0,pxx^.finishAllowance),pxx^.X,pxx^.Y,0,0,0);
    if pxx^.laserMode then result:=ConvertCNCToLaserMultiPass(result,pxx^.Spindle,true,round(pxx^.ZStep),pxx^.HFeed,pxx^.RapidFeed);
  end;
  if pxx^.op=7 then
  begin
    if pxx^.enabled and (pxx^.result='') then result:=GenerateCounterboreGCode(GCodeOptions,pxx^.specific[0],pxx^.specific[1],pxx^.specific[2]);
    if pxx^.laserMode then result:=ConvertCNCToLaserMultiPass(result,pxx^.Spindle,true,round(pxx^.ZStep),pxx^.HFeed,pxx^.RapidFeed);
  end;
  if pxx^.op=11 then
  begin
    if pxx^.enabled and (pxx^.result='') then
    begin
      Form1.ShowProgressDialog('Generating Picture toolpath');
      try
//        tempGCode:=GeneraGCodeGrigliaTest(10, 1000, 10.0, 2.0, 0.08, 3500.0, 5000.0, True);
        if pxx^.specificInteger[0]=0 then tempGCode:=GeneraGCodeLaser(pxx^.FileData,pxx^.specificInteger[2],pxx^.specificInteger[1],pxx^.specific[0],pxx^.ToolDia,pxx^.HFeed,pxx^.RapidFeed,false,round(pxx^.ZStep),pxx^.specific[1],@Form1.HeavyOpProgress);
        if pxx^.specificInteger[0]=1 then tempGCode:=GeneraGCodeLaserCrosshatch(pxx^.FileData,pxx^.specificInteger[2],pxx^.specificInteger[1],pxx^.specific[0],pxx^.ToolDia,pxx^.HFeed,pxx^.RapidFeed,false,round(pxx^.ZStep),45,pxx^.specific[1],@Form1.HeavyOpProgress);
        if pxx^.specificInteger[0]=2 then tempGCode:=GeneraGCodeLaserCrosshatch(pxx^.FileData,pxx^.specificInteger[2],pxx^.specificInteger[1],pxx^.specific[0],pxx^.ToolDia,pxx^.HFeed,pxx^.RapidFeed,false,round(pxx^.ZStep),0,pxx^.specific[1],@Form1.HeavyOpProgress);
        Form1.ShowProgressDialog('Finalizing Picture toolpath');
        result:=TrasformaGCode(tempGCode,pxx^.X,pxx^.Y,0,0,0,@Form1.HeavyOpProgress);
      finally
        Form1.HideProgressDialog;
      end;
    end;
  end;
  if pxx^.op=12 then
  begin
    P.FileData:=pxx^.FileData;
    P.MaxDepthStepMM:=pxx^.ZStep;
    P.ZWhiteMM:=-abs(pxx^.ZStart);
    P.ZBlackMM:=-abs(pxx^.ZDepth);
    P.ToolDiameterMM:=pxx^.ToolDia;
    P.RapidFeedRate:=pxx^.RapidFeed;
    P.SafeZ:=5;
    P.WidthMM:=pxx^.specific[0];
    P.XYFeedRate:=pxx^.HFeed;
    P.ZFeedRate:=pxx^.ZFeed;
    P.StepoverRatio:=0.4;
    P.CrossHatch:=pxx^.specificBool[0];
    if pxx^.enabled and (pxx^.result='') then
    begin
      //P.FileName:=ResolveOperationFile(pxx,IsTempFile);
      Form1.ShowProgressDialog('Generating Sculpt toolpath');
      try
        tempGCode:=ExportImageToGCode(P,@Form1.HeavyOpProgress);
        Form1.ShowProgressDialog('Finalizing Sculpt toolpath');
        result:=TrasformaGCode(tempGCode,pxx^.X,pxx^.Y,0,0,0,@Form1.HeavyOpProgress);
      finally
        Form1.HideProgressDialog;
      end;
      //if IsTempFile then DeleteFile(P.FileName);
    end;
  end;
  if pxx^.op=13 then
  begin
   if pos(#10,pxx^.specificText[0])<length(pxx^.specificText[0]) then pxx^.specificText[0]:=pxx^.specificText[0]+#13+#10;
   if pxx^.enabled then result:=pxx^.specificText[0];
  end;
end;

function TForm1.sostituisciRisolvi(N:integer;pqq:POperazione;tx:string):double;
begin
  try
    tx:=stringReplace(tx,'N',inttostr(N),[rfReplaceAll]);
    tx:=stringReplace(tx,'X',floattostr(pqq^.X),[rfReplaceAll]);
    tx:=stringReplace(tx,'Y',floattostr(pqq^.Y),[rfReplaceAll]);
    result:=strtofloat(risolvi(tx));
    if (isNaN(result))or(IsInfinite(result)) then result:=NaN;
  except
    result:=NaN;
  end;
end;

function TForm1.ListBoxAggiusta:Boolean;
var
  a,b:integer;
  pxx:^TOperazione;
  s,t:string;
  selected:integer;
  errors:string;
  Numbers:array of integer;
  N:integer;
  dx,dy,rd,rx,ry:double;
  ok:boolean;
  pqq:POperazione;
  NError,FeatureError:integer;
begin
  result:=true;
  selected:=listBox1.ItemIndex;
  s:='';
  for a := 0 to opList.Count-1 do
  begin
    pxx:=opList.Items[a];
    s:=errorMessages(pxx);
    if s<>'' then
    begin
      showMessage(s);
      exit(false);
    end;
  end;
  listBox1.Clear;
  for a := 0 to opList.Count-1 do
  begin
    pxx:=opList.Items[a];
    //op:=pxx^.op;
    if pxx^.ZStep=0 then pxx^.ZStep:=pxx^.ZDepth;
    if pxx^.op=1 then listBox1.Items.Append(inttostr(a+1)+' RoundSquare');
    if pxx^.op=2 then listBox1.Items.Append(inttostr(a+1)+' Circle');
    if pxx^.op=3 then listBox1.Items.Append(inttostr(a+1)+' Text');
    if pxx^.op=4 then listBox1.Items.Append(inttostr(a+1)+' Pcb');
    if pxx^.op=5 then listBox1.Items.Append(inttostr(a+1)+' Line');
    if pxx^.op=6 then listBox1.Items.Append(inttostr(a+1)+' SVG');
    if pxx^.op=7 then listBox1.Items.Append(inttostr(a+1)+' Allen Screw');
    if pxx^.op=8 then listBox1.Items.Append(inttostr(a+1)+' Pattern');
    if pxx^.op=9 then listBox1.Items.Append(inttostr(a+1)+' Translation');
    if pxx^.op=10 then listBox1.Items.Append(inttostr(a+1)+' Rotation');
    if pxx^.op=11 then listBox1.Items.Append(inttostr(a+1)+' Picture');
    if pxx^.op=12 then listBox1.Items.Append(inttostr(a+1)+' Sculpt');
    if pxx^.op=13 then listBox1.Items.Append(inttostr(a+1)+' GCode');

    if (pxx^.op<=7)or(pxx^.op=11)or(pxx^.op=12)or(pxx^.op=13) then pxx^.result:=createGCode(pxx,g_path);
    if (pxx^.op=8)and(pxx^.result='') then
    begin
      EspandiStringaNumerica(pxx^.specificText[2],@Numbers);
      t:='';
      ok:=true;
      for b:= 0 to length(Numbers)-1 do
      begin
        for N:=pxx^.specificInteger[0] to pxx^.specificInteger[1] do
        begin
          pqq:=opList.Items[Numbers[b]-1];
          dx:=0;dy:=0;
          rd:=0;rx:=0;ry:=0;
          if pxx^.specificText[0]<>'' then
          begin
            dx:=sostituisciRisolvi(N,pqq,pxx^.specificText[0]);
            if IsNaN(dx) then ok:=false;
          end;
          if ok and (pxx^.specificText[1]<>'') then
          begin
            dy:=sostituisciRisolvi(N,pqq,pxx^.specificText[1]);
            if IsNaN(dy) then ok:=false;
          end;
          if ok and (pxx^.specificText[3]<>'') then
          begin
            rd:=sostituisciRisolvi(N,pqq,pxx^.specificText[3]);
            if IsNaN(rd) then ok:=false;
          end;
          if ok and (pxx^.specificText[4]<>'') then
          begin
            rx:=sostituisciRisolvi(N,pqq,pxx^.specificText[4]);
            if IsNaN(rx) then ok:=false;
          end;
          if ok and (pxx^.specificText[5]<>'') then
          begin
            ry:=sostituisciRisolvi(N,pqq,pxx^.specificText[5]);
            if IsNaN(ry) then ok:=false;
          end;
          if ok then
          begin
            t:=t+TrasformaGCode(pqq^.result,dx,dy,rd,rx,ry);
          end
          else
          begin
            NError:=N;FeatureError:=Numbers[b];
            break;
          end;
        end;
        if not ok then break;
      end;
      if ok then
      begin
        pxx^.result:=t;
      end
      else
      begin
        showmessage('Found error resolving formulas when N='+inttostr(NError)+' and feature='+inttostr(FeatureError)+'.');
      end;
    end;
    if (pxx^.op=9)and(pxx^.result='') then
    begin
      EspandiStringaNumerica(pxx^.specificText[2],@Numbers);
      for b:= 0 to length(Numbers)-1 do
      begin
        pqq:=opList.Items[Numbers[b]-1];
        dx:=pxx^.specific[0];
        dy:=pxx^.specific[1];
        pxx^.result:=pxx^.result+TrasformaGCode(pqq^.result,dx,dy,0,0,0);
      end;
    end;
    if (pxx^.op=10)and(pxx^.result='') then
    begin
      EspandiStringaNumerica(pxx^.specificText[2],@Numbers);
      for b:= 0 to length(Numbers)-1 do
      begin
        pqq:=opList.Items[Numbers[b]-1];
        rd:=pxx^.specific[0];
        rx:=pxx^.specific[1];
        ry:=pxx^.specific[1];
        pxx^.result:=pxx^.result+TrasformaGCode(pqq^.result,0,0,rd,rx,ry);
      end;
    end;
    if pxx^.enabled and (pxx^.result<>'') then S:=S+pxx^.result;
  end;
  gCode:=S;
  if Length(gCode)>2000000 then
  begin
    ShowProgressDialog('Compiling G-Code');
    try
      gCodeCompiled:=CompileGCode(gCode,@HeavyOpProgress);
    finally
      HideProgressDialog;
    end;
  end
  else
    gCodeCompiled:=CompileGCode(gCode);
  if length(gCodeCompiled)>0 then DrawGCodeAutoCenteredCompiled(gCodeCompiled,true,panel5.Width,panel5.Height,travelShow,trackBar1.Position / 1000) else GLbox.SwapBuffers;
  GLbox.swapBuffers;
  GCodeEditor.Testo.Text:=S;
  if selected<listBox1.Items.Count then
  begin
    listBox1.ItemIndex:=selected;
    Button5.Enabled:=true;
    Button6.Enabled:=true;
  end;
end;

procedure TForm1.aggiorna(pxx:POperazione);
var
  a:integer;

  procedure chiediSeAggiornareFile;
  var
    datiPresenti:boolean=false;
  begin
    if pxx^.FileData<>nil then
      if pxx^.FileData.Size>0 then datiPresenti:=true;
    if datiPresenti then
    begin
      if editButton1.Text<>'' then
      begin
        if MessageDlg('Do you want to update file in this project?', mtConfirmation, [mbYes, mbNo], 0)=mrYes then SetOperationFile(pxx,editButton1.Text);
      end;
    end
    else
    begin
      SetOperationFile(pxx,editButton1.Text);
    end;
  end;
begin
  pxx^.op:=op;
  pxx^.RapidFeed:=CommonSpinEdit1.Value;;
  pxx^.HFeed:=CommonSpinEdit2.Value;
  pxx^.ZFeed:=CommonSpinEdit3.Value;
  pxx^.ToolDia:=CommonSpinEdit4.Value;
  pxx^.ZDepth:=CommonSpinEdit5.Value;
  pxx^.ZStep:=CommonSpinEdit6.Value;
  pxx^.Spindle:=round(CommonSpinEdit7.Value);
  pxx^.X:=floatSpinEdit7.Value;
  pxx^.Y:=floatSpinEdit8.Value;
  pxx^.enabled:=CheckBox1.Checked;
  pxx^.laserMode:=checkbox3.Checked;
  pxx^.direction:=ComboBox3.ItemIndex;
  pxx^.ZStart:=CommonSpinEdit8.Value;
  pxx^.finishAllowance:=CommonSpinEdit9.Value;
  pxx^.maxRamp:=CommonSpinEdit10.Value;
  setLength(pxx^.specific,6);
  setLength(pxx^.specificBool,6);
  setLength(pxx^.specificInteger,6);
  setLength(pxx^.specificText,6);
  for a:=0 to length(pxx^.specific)-1 do
  begin
    pxx^.specific[a]:=0;
    pxx^.specificBool[a]:=false;
    pxx^.specificInteger[a]:=0;
    pxx^.specificText[a]:='';
  end;
  if op=1 then
  begin
    pxx^.specific[0]:=floatSpinEdit9.Value;;
    pxx^.specific[1]:=floatSpinEdit10.Value;
    pxx^.specific[2]:=floatSpinEdit11.Value;
    pxx^.specific[3]:=combobox2.ItemIndex;
    pxx^.specific[4]:=floatSpinEdit12.Value;
    pxx^.TransformationMatrix.a:=transformationMatrix1.Value;
    pxx^.TransformationMatrix.c:=transformationMatrix2.Value;
    pxx^.TransformationMatrix.e:=transformationMatrix3.Value;
    pxx^.TransformationMatrix.b:=transformationMatrix4.Value;
    pxx^.TransformationMatrix.d:=transformationMatrix5.Value;
    pxx^.TransformationMatrix.f:=transformationMatrix6.Value;
  end;
  if op=2 then
  begin
    pxx^.specific[0]:=floatSpinEdit11.Value;
    pxx^.specific[3]:=combobox2.ItemIndex;
    pxx^.specific[4]:=floatSpinEdit12.Value;
    pxx^.TransformationMatrix.a:=transformationMatrix1.Value;
    pxx^.TransformationMatrix.c:=transformationMatrix2.Value;
    pxx^.TransformationMatrix.e:=transformationMatrix3.Value;
    pxx^.TransformationMatrix.b:=transformationMatrix4.Value;
    pxx^.TransformationMatrix.d:=transformationMatrix5.Value;
    pxx^.TransformationMatrix.f:=transformationMatrix6.Value;
  end;
  if pxx^.op=3 then
  begin
    pxx^.specific[0]:=floatSpinEdit11.Value;
    pxx^.text:=edit1.Text;
    pxx^.fontName:=comboBox1.Text;
  end;
  if pxx^.op=4 then
  begin
    chiediSeAggiornareFile;
    pxx^.specific[0]:=floatSpinEdit9.Value;      //DPI
    pxx^.specific[1]:=floatSpinEdit10.Value;     //Allargamento tracce
    pxx^.specific[2]:=floatSpinEdit11.Value;     //Diametro foro
    pxx^.specific[3]:=floatSpinEdit12.Value;     //Profondità foratura
    pxx^.specificBool[0]:=checkBox2.Checked;
    pxx^.specificBool[1]:=checkBox4.Checked;
  end;
  if op=5 then
  begin
    pxx^.specific[0]:=floatSpinEdit9.Value;;
    pxx^.specific[1]:=floatSpinEdit10.Value;
    pxx^.specific[2]:=floatSpinEdit9.Value;
    pxx^.specific[4]:=floatSpinEdit12.Value;
  end;
  if pxx^.op=6 then
  begin
    chiediSeAggiornareFile;
    pxx^.specific[0]:=floatSpinEdit9.Value;
    pxx^.specificInteger[0]:=combobox2.ItemIndex;
    pxx^.specificInteger[1]:=combobox4.ItemIndex;
  end;
  if pxx^.op=7 then
  begin
    pxx^.specific[0]:=floatSpinEdit9.Value;;
    pxx^.specific[1]:=floatSpinEdit10.Value;
    pxx^.specific[2]:=floatSpinEdit11.Value;
  end;
  if pxx^.op=8 then
  begin
    pxx^.specificInteger[0]:=spinEdit1.Value;;
    pxx^.specificInteger[1]:=spinEdit2.Value;
    pxx^.specificText[0]:=edit2.Text;
    pxx^.specificText[1]:=edit3.Text;
    pxx^.specificText[2]:=edit6.Text;
    pxx^.specificText[3]:=edit4.Text;
    pxx^.specificText[4]:=edit5.Text;
    pxx^.specificText[5]:=edit7.Text;
  end;
  if pxx^.op=9 then
  begin
    pxx^.specific[0]:=floatSpinEdit1.Value;
    pxx^.specific[1]:=floatSpinEdit2.Value;
    pxx^.specificText[2]:=edit6.Text;
  end;
  if pxx^.op=10 then
  begin
    pxx^.specific[0]:=floatSpinEdit3.Value;
    pxx^.specific[1]:=floatSpinEdit4.Value;
    pxx^.specific[2]:=floatSpinEdit5.Value;
    pxx^.specificText[2]:=edit6.Text;
  end;
  if pxx^.op=11 then
  begin
    chiediSeAggiornareFile;
    pxx^.specific[0]:=floatSpinEdit9.Value;
    pxx^.specific[1]:=floatSpinEdit10.Value;
    pxx^.specificInteger[0]:=abs(comboBox5.ItemIndex);
    pxx^.specificInteger[1]:=min(abs(SpinEdit3.Value),abs(SpinEdit4.Value));
    pxx^.specificInteger[2]:=max(abs(SpinEdit4.Value),pxx^.specificInteger[1]);
  end;
  if pxx^.op=12 then
  begin
    chiediSeAggiornareFile;
    pxx^.specific[0]:=floatSpinEdit9.Value;
    pxx^.specificBool[0]:=checkBox4.Checked;
  end;
  if (pxx^.op=13) then
  begin
    if radioButton1.Checked then pxx^.specificInteger[0]:=1;
    if radioButton2.Checked then pxx^.specificInteger[0]:=2;
    if radioButton3.Checked then pxx^.specificInteger[0]:=3;
    if radioButton4.Checked then pxx^.specificInteger[0]:=4;
    if pxx^.specificInteger[0]=1 then pxx^.specificText[0]:='M5'+#13+#10+'G0 Z5'+#13+#10+'G0 X0 Y0'+#13+#10;
    if pxx^.specificInteger[0]=2 then pxx^.specificText[0]:='M5'+#13+#10+'M0'+#13+#10;
    if pxx^.specificInteger[0]=3 then pxx^.specificText[0]:='M5'+#13+#10+'M1'+#13+#10;
    if pxx^.specificInteger[0]=4 then pxx^.specificText[0]:=memo2.Text;
  end;end;

procedure TForm1.impostaTabOrder;
var
  a:integer=1;
begin
  scrollBox1.TabOrder:=a;inc(a);
  if panel8.Visible then
  begin
    if spinEdit1.Visible and spinEdit1.Enabled then begin spinEdit1.TabOrder:=a;inc(a);end;
    if spinEdit2.Visible and spinEdit2.Enabled then begin spinEdit2.TabOrder:=a;inc(a);end;
    if edit6.Visible and edit6.Enabled then begin edit6.TabOrder:=a;inc(a);end;
    if edit2.Visible and edit2.Enabled then begin edit2.TabOrder:=a;inc(a);end;
    if edit3.Visible and edit3.Enabled then begin edit3.TabOrder:=a;inc(a);end;
    if edit4.Visible and edit4.Enabled then begin edit4.TabOrder:=a;inc(a);end;
    if edit5.Visible and edit5.Enabled then begin edit5.TabOrder:=a;inc(a);end;
    if edit7.Visible and edit7.Enabled then begin edit7.TabOrder:=a;inc(a);end;
    if floatSpinEdit1.Visible and floatSpinEdit1.Enabled then begin floatSpinEdit1.TabOrder:=a;inc(a);end;
    if floatSpinEdit2.Visible and floatSpinEdit2.Enabled then begin floatSpinEdit2.TabOrder:=a;inc(a);end;
    if floatSpinEdit3.Visible and floatSpinEdit3.Enabled then begin floatSpinEdit3.TabOrder:=a;inc(a);end;
    if floatSpinEdit4.Visible and floatSpinEdit4.Enabled then begin floatSpinEdit4.TabOrder:=a;inc(a);end;
    if floatSpinEdit5.Visible and floatSpinEdit5.Enabled then begin floatSpinEdit5.TabOrder:=a;inc(a);end;
  end;
  if panel9.Visible then
  begin
    if floatSpinEdit7.Visible and floatSpinEdit7.Enabled then begin floatSpinEdit7.TabOrder:=a;inc(a);end;
    if floatSpinEdit8.Visible and floatSpinEdit8.Enabled then begin floatSpinEdit8.TabOrder:=a;inc(a);end;
    if floatSpinEdit9.Visible and floatSpinEdit9.Enabled then begin floatSpinEdit9.TabOrder:=a;inc(a);end;
    if checkBox4.Visible and checkBox4.Enabled then begin checkBox4.TabOrder:=a;inc(a);end;
    if floatSpinEdit10.Visible and floatSpinEdit10.Enabled then begin floatSpinEdit10.TabOrder:=a;inc(a);end;
    if checkBox2.Visible and checkBox2.Enabled then begin checkBox2.TabOrder:=a;inc(a);end;
    if floatSpinEdit11.Visible and floatSpinEdit11.Enabled then begin floatSpinEdit11.TabOrder:=a;inc(a);end;
    if floatSpinEdit12.Visible and floatSpinEdit12.Enabled then begin floatSpinEdit12.TabOrder:=a;inc(a);end;
    if edit1.Visible and edit1.Enabled then begin edit1.TabOrder:=a;inc(a);end;
    if comboBox1.Visible and comboBox1.Enabled then begin comboBox1.TabOrder:=a;inc(a);end;
    if comboBox2.Visible and comboBox2.Enabled then begin comboBox2.TabOrder:=a;inc(a);end;
    if editButton1.Visible and editButton1.Enabled then begin editButton1.TabOrder:=a;inc(a);end;
  end;
  scrollBox2.TabOrder:=a;inc(a);
  if commonSpinEdit1.Visible and commonSpinEdit1.Enabled then begin commonSpinEdit1.TabOrder:=a;inc(a);end;
  if commonSpinEdit2.Visible and commonSpinEdit2.Enabled then begin commonSpinEdit2.TabOrder:=a;inc(a);end;
  if commonSpinEdit3.Visible and commonSpinEdit3.Enabled then begin commonSpinEdit3.TabOrder:=a;inc(a);end;
  if commonSpinEdit4.Visible and commonSpinEdit4.Enabled then begin commonSpinEdit4.TabOrder:=a;inc(a);end;
  if commonSpinEdit9.Visible and commonSpinEdit9.Enabled then begin commonSpinEdit9.TabOrder:=a;inc(a);end;
  if commonSpinEdit10.Visible and commonSpinEdit10.Enabled then begin commonSpinEdit10.TabOrder:=a;inc(a);end;
  if commonSpinEdit8.Visible and commonSpinEdit8.Enabled then begin commonSpinEdit8.TabOrder:=a;inc(a);end;
  if commonSpinEdit5.Visible and commonSpinEdit5.Enabled then begin commonSpinEdit5.TabOrder:=a;inc(a);end;
  if commonSpinEdit6.Visible and commonSpinEdit6.Enabled then begin commonSpinEdit6.TabOrder:=a;inc(a);end;
  if commonSpinEdit7.Visible and commonSpinEdit7.Enabled then begin commonSpinEdit7.TabOrder:=a;inc(a);end;
  if comboBox3.Visible and comboBox3.Enabled then begin comboBox3.TabOrder:=a;inc(a);end;
  if checkBox3.Visible and checkBox3.Enabled then begin checkBox3.TabOrder:=a;inc(a);end;
  if checkBox1.Visible and checkBox1.Enabled then begin checkBox1.TabOrder:=a;inc(a);end;
end;

procedure TForm1.SpinEdit3EditingDone(Sender: TObject);
begin
  if op=11 then
  begin
    SpinEdit4.MinValue:=SpinEdit3.Value;
  end;
end;

procedure TForm1.SpinEdit4EditingDone(Sender: TObject);
begin
  if op=11 then
  begin
    SpinEdit3.MaxValue:=SpinEdit4.Value;
  end;
end;

procedure TForm1.ToggleBox1Change(Sender: TObject);
begin
  groupBox3.Visible:=ToggleBox1.Checked;
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  pxx:^TOperazione;
  a:integer;
  errors:string;
begin
  NewOperazione(pxx);
  aggiorna(pxx);
  opList.Add(pxx);
  pxx^.listPosition:=opList.Count-1;
  errors:=errorMessages(pxx);
  if errors='' then
  begin
    pxx^.result:='';
    a:=opList.Count;
    if not ListBoxAggiusta then
    begin
      opList.Remove(pxx);
      a:=opList.Count;
      FreeOperazione(pxx);
    end
    else
    begin
      saved:=false;
      listBox1.ItemIndex:=listBox1.Items.Count-1;
    end;
  end
  else
  begin
    opList.Remove(pxx);
    FreeOperazione(pxx);
    showmessage(errors);
  end;
end;

procedure TForm1.Button5Click(Sender: TObject);
var
  a:integer;
  pxx:^TOperazione;
begin
  a:=listBox1.ItemIndex;
  if a>-1 then
  begin
    pxx:=opList.Items[a];
    FreeOperazione(pxx);
    listBox1.Items.Delete(a);
    opList.Delete(a);
    saved:=false
  end;
  ListBoxAggiusta;
  Button5.Enabled:=false;
end;

procedure TForm1.Button6Click(Sender: TObject);
var
  a,b:integer;
  pxx,pqq:^TOperazione;
  pTmp:POperazione;
  errors:string;
begin
  a:=listBox1.ItemIndex;
  if a>-1 then
  begin
    pxx:=opList.Items[a];
    NewOperazione(pTmp);
    pTmp^.listPosition:=pxx^.listPosition;
    // Riporta sul nuovo record il file gia' incorporato: se il campo File non viene toccato
    // e il percorso originale non e' piu' raggiungibile, i dati non vanno persi (SetOperationFile,
    // chiamata da aggiorna, li conserva quando AFileName coincide col vecchio pTmp^.filename).
    pTmp^.filename:=pxx^.filename;
    if Assigned(pxx^.FileData) and (pxx^.FileData.Size>0) then
    begin
      pTmp^.FileData:=TMemoryStream.Create;
      pxx^.FileData.Position:=0;
      pTmp^.FileData.CopyFrom(pxx^.FileData,pxx^.FileData.Size);
      pxx^.FileData.Position:=0;
      pTmp^.FileData.Position:=0;
    end;
    aggiorna(pTmp);
    errors:=errorMessages(pTmp);
    if errors='' then
    begin
      opList.Items[a]:=pTmp;
      FreeOperazione(pxx);
      pTmp^.result:='';
      for b:=a+1 to opList.Count-1 do
      begin
        pqq:=opList.Items[b];
        if (pqq^.op>=8)and(pqq^.op<=11) then
        begin
          if PosWholeWord(inttostr(a+1),pqq^.specificText[2])>0 then
          begin
            pqq^.result:='';  //Se un modificatore si riferisce a questa feature, viene ridisegnato anche il modificatore
          end;
        end;
      end;
      ListBoxAggiusta;
      saved:=false;
    end
    else
    begin
      FreeOperazione(pTmp);
      showmessage(errors);
    end;
  end;
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
var
  a:integer;
  pxx:^TOperazione;
begin
  a:=listBox1.ItemIndex;
  if a>-1 then
  begin
    pxx:=opList.Items[a];
    pxx^.enabled:=checkbox1.Checked;
    listbox1.OnSelectionChange:=nil;
    ListBoxAggiusta;
    listbox1.OnSelectionChange:=@ListBox1SelectionChange;
  end;
end;

procedure TForm1.CheckBox2Change(Sender: TObject);
begin
  if op=4 then
  begin
    FloatSpinEdit11.enabled:=checkbox2.Checked;
    FloatSpinEdit12.enabled:=checkbox2.Checked;
    if CheckBox2.Checked=false then checkBox4.Checked:=true;
    impostaTabOrder;
  end;
end;

procedure TForm1.CheckBox3Change(Sender: TObject);
begin
 if CheckBox3.Checked then
 begin
   CommonSpinEdit5.Enabled:=false;
   label6.Caption:='Number of passes';
   label19.Caption:='Laser power';
   if CommonSpinEdit4.Value>0.3 then CommonSpinEdit4.Value:=0.15;
   CommonSpinEdit3.Enabled:=false;
   CommonSpinEdit9.Enabled:=false;
   CommonSpinEdit10.Enabled:=false;
   CommonSpinEdit8.Enabled:=false;
   CommonSpinEdit5.Enabled:=false;
   CommonSpinEdit6.Enabled:=true;
 end
 else
 begin
   CommonSpinEdit5.Enabled:=true;
   label6.Caption:='Z Step';
   label19.Caption:='Spindle speed';
   CommonSpinEdit3.Enabled:=true;
   CommonSpinEdit9.Enabled:=true;
   CommonSpinEdit10.Enabled:=true;
   CommonSpinEdit8.Enabled:=true;
   CommonSpinEdit5.Enabled:=true;
   if op=4 then CommonSpinEdit6.Enabled:=false;
 end;
end;

procedure TForm1.CheckBox4Change(Sender: TObject);
begin
  if op=4 then
  begin
    FloatSpinEdit10.Enabled:=checkBox4.Checked;
    if CheckBox4.Checked=false then checkBox2.Checked:=true;
  end;
end;

procedure TForm1.EditButton1ButtonClick(Sender: TObject);
begin
  if (op=4)or(op=11)or(op=12) then OpenDialog1.Filter := 'PNG Image (*.png)|*.png;*.PNG|' + 'BMP Image (*.bmp)|*.bmp|'+ 'JPG Image (*.jpg)|*.jpg|';
  if op=6 then OpenDialog1.Filter := 'SVG Image (*.svg)|*.svg|';
  if openDialog1.Execute then editButton1.Text:=openDialog1.FileName;
end;

function FormatByteSize(ABytes: Int64): string;
begin
  if ABytes >= 1024*1024 then
    Result:=Format('%.2f MB',[ABytes/(1024*1024)])
  else if ABytes >= 1024 then
    Result:=Format('%.1f KB',[ABytes/1024])
  else
    Result:=Format('%d bytes',[ABytes]);
end;

type
  { fpvectorial's SVG reader splits a compound path (multiple M..Z subpaths in one
    "d" attribute, typically used to cut a hole) into separate sibling TPath entities,
    and its default renderer (TFPVCanvasRenderer) fills each one solid - so holes
    appear solid black instead of transparent. This renderer overrides only the path
    fill step with an even-odd XOR fill (reusing fpvectorial's own scanline
    intersection routine), so nested/overlapping same-fill paths correctly punch a
    hole; the stroke/border drawing and every other entity type (rect, circle,
    ellipse, text, ...) is left to the inherited renderer, unchanged. }
  THoleAwareSvgRenderer = class(TFPVCanvasRenderer)
  public
    procedure TPath_Render(var ARenderInfo: TvRenderInfo; ADoDraw: Boolean; APath: TPath); override;
  end;

procedure THoleAwareSvgRenderer.TPath_Render(var ARenderInfo: TvRenderInfo; ADoDraw: Boolean; APath: TPath);
var
  ACanvas: TCanvas;
  IntPts: TPointsArray;
  PolyStarts: TIntegerDynArray;
  Pts2D: T2DPointsArray;
  Inters: T2DPointsArray;
  j, y, x1, x2, MinY, MaxY: Integer;
  OrigStyle: TBrushStyle;
begin
  if ADoDraw and (APath.Brush.Style=bsSolid) then
  begin
    ACanvas:=TCanvas(ARenderInfo.Canvas);
    ConvertPathToPolygons(APath,ARenderInfo.DestX,ARenderInfo.DestY,ARenderInfo.MulX,ARenderInfo.MulY,IntPts,PolyStarts);
    if Length(IntPts)>2 then
    begin
      SetLength(Pts2D,Length(IntPts));
      MinY:=MaxInt;
      MaxY:=-MaxInt;
      for j:=0 to High(IntPts) do
      begin
        Pts2D[j]:=Point2D(IntPts[j].X,IntPts[j].Y);
        if IntPts[j].Y<MinY then MinY:=IntPts[j].Y;
        if IntPts[j].Y>MaxY then MaxY:=IntPts[j].Y;
      end;
      ACanvas.Pen.Mode:=pmXor;
      ACanvas.Pen.Style:=psSolid;
      ACanvas.Pen.Color:=clWhite;
      ACanvas.Pen.Width:=1;
      for y:=MinY to MaxY do
      begin
        Inters:=GetLinePolygonIntersectionPoints(y,Pts2D,PolyStarts,false);
        j:=0;
        while j<High(Inters) do
        begin
          x1:=Round(Inters[j].X);
          x2:=Round(Inters[j+1].X);
          if x2>=x1 then ACanvas.Line(x1,y,x2+1,y);
          inc(j,2);
        end;
      end;
      ACanvas.Pen.Mode:=pmCopy;
    end;
  end;

  // Let the inherited renderer draw the border/stroke, with the (already handled) fill
  // suppressed so it does not also solid-fill the path itself.
  OrigStyle:=APath.Brush.Style;
  APath.Brush.Style:=bsClear;
  try
    inherited TPath_Render(ARenderInfo,ADoDraw,APath);
  finally
    APath.Brush.Style:=OrigStyle;
  end;
end;

procedure TForm1.ShowImagePreview(const pxx: POperazione);
var
  PrevForm: TForm;
  Img: TImage;
  TopPanel: TPanel;
  BtnExport: TButton;
  InfoLabel: TLabel;
  Ext: string;
  InfoText: string;
  Doc: TvVectorialDocument;
  Page: TvVectorialPage;
  Scale: Double;
  WPx, HPx, MaxDim: Integer;
begin
  Ext:=LowerCase(ExtractFileExt(pxx^.filename));
  PreviewExportFile:='';
  PreviewExportStream:=pxx^.FileData;
  PreviewExportName:=ExtractFileName(pxx^.filename);
  PrevForm:=TForm.Create(nil);
  try
    PrevForm.Caption:='File preview - '+ExtractFileName(pxx^.FileName);
    PrevForm.Position:=poScreenCenter;
    PrevForm.Width:=700;
    PrevForm.Height:=550;
    PrevForm.Color:=clWhite;

    TopPanel:=TPanel.Create(PrevForm);
    TopPanel.Parent:=PrevForm;
    TopPanel.Align:=alTop;
    TopPanel.Height:=36;
    TopPanel.Color:=clWindow;
    //TopPanel.BevelOuter:=bvNone;

    BtnExport:=TButton.Create(PrevForm);
    BtnExport.Parent:=TopPanel;
    BtnExport.Caption:='Export...';
    BtnExport.Width:=100;
    BtnExport.Top:=4;
    BtnExport.Left:=8;
    BtnExport.OnClick:=@BtnExportPreviewClick;
    pxx^.FileData.Position:=0;
    Img:=TImage.Create(PrevForm);
    Img.Parent:=PrevForm;
    Img.Align:=alClient;
    Img.Proportional:=true;
    Img.Stretch:=true;
    Img.Center:=true;
    InfoText:='';
    if Ext ='.svg' then
    begin
      Doc:=TvVectorialDocument.Create;
      try
        Doc.SetRenderer(THoleAwareSvgRenderer.Create);
        Doc.ReadFromStream(pxx^.FileData,vfSVG);
        if (Doc.Width>0) and (Doc.Height>0) then
        begin
          Page:=Doc.GetPageAsVectorial(0);
          MaxDim:=1600;
          if Doc.Width>=Doc.Height then Scale:=MaxDim/Doc.Width
          else Scale:=MaxDim/Doc.Height;
          WPx:=Round(Doc.Width*Scale);
          HPx:=Round(Doc.Height*Scale);
          Img.Picture.Bitmap.SetSize(WPx,HPx);
          Img.Picture.Bitmap.Canvas.Brush.Color:=clWhite;
          Img.Picture.Bitmap.Canvas.FillRect(0,0,WPx,HPx);
          Page.Render(Img.Picture.Bitmap.Canvas,0,0,Scale,Scale);
        end;
        InfoText:=Format('%.1f x %.1f mm (vector) - %s',[Doc.Width,Doc.Height,FormatByteSize(pxx^.FileData.Size)]);
      finally
        Doc.Free;
      end;
    end
    else
    begin
      Img.Picture.LoadFromStream(pxx^.FileData);
      InfoText:=Format('%d x %d px - %s',[Img.Picture.Width,Img.Picture.Height,FormatByteSize(pxx^.FileData.Size)]);
    end;

    InfoLabel:=TLabel.Create(TopPanel);
    InfoLabel.Parent:=TopPanel;
    InfoLabel.Font.Style:=[fsBold];
    InfoLabel.AutoSize:=false;
    InfoLabel.Caption:=InfoText;
    InfoLabel.Left:=BtnExport.Left+BtnExport.Width+6;
    InfoLabel.Top:=4;

    PrevForm.Canvas.Font.Assign(InfoLabel.Font);
    InfoLabel.Width:=PrevForm.Canvas.TextWidth(InfoText);
    InfoLabel.Height:=PrevForm.Canvas.TextHeight(InfoText);

    PrevForm.ShowModal;
  finally
    PrevForm.Free;
  end;
end;

procedure TForm1.ShowImagePreview(const AFile: string; ABytes: Int64);
var
  PrevForm: TForm;
  Img: TImage;
  TopPanel: TPanel;
  BtnExport: TButton;
  InfoPanel: TPanel;
  InfoLabel: TLabel;
  Ext: string;
  InfoText: string;
  Doc: TvVectorialDocument;
  Page: TvVectorialPage;
  Scale: Double;
  WPx, HPx, MaxDim: Integer;
begin
  Ext:=LowerCase(ExtractFileExt(AFile));
  PreviewExportFile:=AFile;
  PreviewExportStream:=nil;
  PreviewExportName:=ExtractFileName(AFile);
  PrevForm:=TForm.Create(nil);
  try
    PrevForm.Caption:='File preview - '+ExtractFileName(AFile);
    PrevForm.Position:=poScreenCenter;
    PrevForm.Width:=700;
    PrevForm.Height:=550;
    PrevForm.Color:=clWhite;

    TopPanel:=TPanel.Create(PrevForm);
    TopPanel.Parent:=PrevForm;
    TopPanel.Align:=alTop;
    TopPanel.Height:=36;
    TopPanel.BevelOuter:=bvNone;

    BtnExport:=TButton.Create(PrevForm);
    BtnExport.Parent:=TopPanel;
    BtnExport.Caption:='Export...';
    BtnExport.Width:=100;
    BtnExport.Top:=4;
    BtnExport.Left:=8;
    BtnExport.OnClick:=@BtnExportPreviewClick;

    Img:=TImage.Create(PrevForm);
    Img.Parent:=PrevForm;
    Img.Align:=alClient;
    Img.Proportional:=true;
    Img.Stretch:=true;
    Img.Center:=true;

    InfoText:='';
    if Ext='.svg' then
    begin
      Doc:=TvVectorialDocument.Create;
      try
        Doc.SetRenderer(THoleAwareSvgRenderer.Create);
        Doc.ReadFromFile(AFile);
        if (Doc.Width>0) and (Doc.Height>0) then
        begin
          Page:=Doc.GetPageAsVectorial(0);
          MaxDim:=1600;
          if Doc.Width>=Doc.Height then Scale:=MaxDim/Doc.Width
          else Scale:=MaxDim/Doc.Height;
          WPx:=Round(Doc.Width*Scale);
          HPx:=Round(Doc.Height*Scale);
          Img.Picture.Bitmap.SetSize(WPx,HPx);
          Img.Picture.Bitmap.Canvas.Brush.Color:=clWhite;
          Img.Picture.Bitmap.Canvas.FillRect(0,0,WPx,HPx);
          Page.Render(Img.Picture.Bitmap.Canvas,0,0,Scale,Scale);
        end;
        InfoText:=Format('%.1f x %.1f mm (vector) - %s',[Doc.Width,Doc.Height,FormatByteSize(ABytes)]);
      finally
        Doc.Free;
      end;
    end
    else
    begin
      Img.Picture.LoadFromFile(AFile);
      InfoText:=Format('%d x %d px - %s',[Img.Picture.Width,Img.Picture.Height,FormatByteSize(ABytes)]);
    end;

    InfoPanel:=TPanel.Create(PrevForm);
    InfoPanel.Parent:=PrevForm;
    InfoPanel.BevelOuter:=bvNone;
    InfoPanel.Color:=clBlack;
    InfoPanel.Anchors:=[akRight,akBottom];

    InfoLabel:=TLabel.Create(InfoPanel);
    InfoLabel.Parent:=InfoPanel;
    InfoLabel.Font.Color:=clWhite;
    InfoLabel.Font.Style:=[fsBold];
    InfoLabel.AutoSize:=false;
    InfoLabel.Caption:=InfoText;
    InfoLabel.Left:=6;
    InfoLabel.Top:=4;

    PrevForm.Canvas.Font.Assign(InfoLabel.Font);
    InfoLabel.Width:=PrevForm.Canvas.TextWidth(InfoText);
    InfoLabel.Height:=PrevForm.Canvas.TextHeight(InfoText);

    InfoPanel.Width:=InfoLabel.Width+12;
    InfoPanel.Height:=InfoLabel.Height+8;
    InfoPanel.Left:=PrevForm.ClientWidth-InfoPanel.Width-10;
    InfoPanel.Top:=PrevForm.ClientHeight-InfoPanel.Height-10;

    PrevForm.ShowModal;
  finally
    PrevForm.Free;
  end;
end;

procedure TForm1.BtnExportPreviewClick(Sender: TObject);
var
  SaveDlg: TSaveDialog;
  Ext: string;
  SrcStream, DstStream: TFileStream;
  SavedPos: Int64;
begin
  if not Assigned(PreviewExportStream) and ((PreviewExportFile='') or not FileExists(PreviewExportFile)) then
  begin
    ShowMessage('File not available for export.');
    Exit;
  end;
  SaveDlg:=TSaveDialog.Create(nil);
  try
    if Assigned(PreviewExportStream) then
      Ext:=ExtractFileExt(PreviewExportName)
    else
      Ext:=ExtractFileExt(PreviewExportFile);
    SaveDlg.FileName:=PreviewExportName;
    if Ext<>'' then
    begin
      SaveDlg.DefaultExt:=Copy(Ext,2,MaxInt);
      SaveDlg.Filter:=Format('%s Files|*%s|All Files|*.*',[UpperCase(SaveDlg.DefaultExt),Ext]);
    end;
    if SaveDlg.Execute then
    begin
      if (Ext<>'') and (ExtractFileExt(SaveDlg.FileName)='') then
        SaveDlg.FileName:=SaveDlg.FileName+Ext;
      try
        if Assigned(PreviewExportStream) then
        begin
          SavedPos:=PreviewExportStream.Position;
          try
            PreviewExportStream.Position:=0;
            DstStream:=TFileStream.Create(SaveDlg.FileName,fmCreate);
            try
              DstStream.CopyFrom(PreviewExportStream,PreviewExportStream.Size);
            finally
              DstStream.Free;
            end;
          finally
            PreviewExportStream.Position:=SavedPos;
          end;
        end
        else
        begin
          SrcStream:=TFileStream.Create(PreviewExportFile,fmOpenRead or fmShareDenyWrite);
          try
            DstStream:=TFileStream.Create(SaveDlg.FileName,fmCreate);
            try
              DstStream.CopyFrom(SrcStream,0);
            finally
              DstStream.Free;
            end;
          finally
            SrcStream.Free;
          end;
        end;
      except
        ShowMessage('Export failed.');
      end;
    end;
  finally
    SaveDlg.Free;
  end;
end;

procedure TForm1.ShowProgressDialog(const ACaption: string);
begin
  if not Assigned(ProgressDlg) then
  begin
    ProgressDlg:=TForm.Create(Self);
    ProgressDlg.BorderStyle:=bsDialog;
    ProgressDlg.Position:=poDesigned;
    ProgressDlg.Width:=360;
    ProgressDlg.Height:=110;
    // Senza queste due righe il window manager tratta la finestra di
    // avanzamento come una seconda applicazione indipendente: le compare
    // una voce propria (con icona generica, non quella del programma) nella
    // barra delle applicazioni invece di restare associata alla finestra
    // principale.
    ProgressDlg.Icon:=Application.Icon;
    ProgressDlg.ShowInTaskBar:=stNever;
    ProgressDlg.PopupParent:=Self;

    ProgressLabelDlg:=TLabel.Create(ProgressDlg);
    ProgressLabelDlg.Parent:=ProgressDlg;
    ProgressLabelDlg.Left:=12;
    ProgressLabelDlg.Top:=12;

    ProgressBarDlg:=TProgressBar.Create(ProgressDlg);
    ProgressBarDlg.Parent:=ProgressDlg;
    ProgressBarDlg.Left:=12;
    ProgressBarDlg.Top:=40;
    ProgressBarDlg.Width:=ProgressDlg.ClientWidth-24;
    ProgressBarDlg.Anchors:=[akLeft,akTop,akRight];
    ProgressBarDlg.Min:=0;
    ProgressBarDlg.Max:=100;
  end;
  ProgressDlg.Caption:=ACaption;
  ProgressLabelDlg.Caption:=ACaption+'...';
  ProgressBarDlg.Position:=0;
  ProgressDlg.Left:=Self.Left+(Self.Width-ProgressDlg.Width) div 2;
  ProgressDlg.Top:=Self.Top+(Self.Height-ProgressDlg.Height) div 2;
  ProgressDlg.Show;
  Application.ProcessMessages;
end;

procedure TForm1.HideProgressDialog;
begin
  if Assigned(ProgressDlg) then
  begin
    ProgressDlg.Hide;
  end;
end;

procedure TForm1.HeavyOpProgress(Percent: Integer);
begin
  if not Assigned(ProgressDlg) then Exit;
  ProgressBarDlg.Position:=Percent;
  ProgressLabelDlg.Caption:=Format('%s... %d%%',[ProgressDlg.Caption,Percent]);
  Application.ProcessMessages;
end;

procedure TForm1.MenuItem10Click(Sender: TObject);
var
  pxx: POperazione;
  IsTempFile: boolean;
  Bytes: Int64;
  SR: TSearchRec;
begin
  if not (op in [4,6,11,12]) then
  begin
    ShowMessage('View Resource is only available for the PCB, SVG, Picture and Sculpt features.');
    Exit;
  end;
  IsTempFile:=false;
  pxx:=nil;
  if (listBox1.ItemIndex>-1) and (opList.Items[listBox1.ItemIndex]<>nil) then
  begin
    pxx:=opList.Items[listBox1.ItemIndex];
  end;
  if pxx<>nil then
  begin
    try
      ShowImagePreview(pxx);
    except
      ShowMessage('Cannot show this picture');
    end;
  end;
end;

procedure TForm1.MenuItem11Click(Sender: TObject);
var
  CommentForm: TForm;
  Memo: TMemo;
  BtnPanel: TPanel;
  BtnOK, BtnCancel: TButton;
begin
  CommentForm:=TForm.Create(nil);
  try
    CommentForm.Caption:='Project comment';
    CommentForm.Position:=poScreenCenter;
    CommentForm.Width:=500;
    CommentForm.Height:=350;

    BtnPanel:=TPanel.Create(CommentForm);
    BtnPanel.Parent:=CommentForm;
    BtnPanel.Align:=alBottom;
    BtnPanel.Height:=44;
    BtnPanel.BevelOuter:=bvNone;

    BtnCancel:=TButton.Create(CommentForm);
    BtnCancel.Parent:=BtnPanel;
    BtnCancel.Caption:='Cancel';
    BtnCancel.ModalResult:=mrCancel;
    BtnCancel.Width:=80;
    BtnCancel.Top:=8;
    BtnCancel.Left:=BtnPanel.Width-BtnCancel.Width-10;
    BtnCancel.Anchors:=[akRight,akTop];

    BtnOK:=TButton.Create(CommentForm);
    BtnOK.Parent:=BtnPanel;
    BtnOK.Caption:='OK';
    BtnOK.ModalResult:=mrOK;
    BtnOK.Width:=80;
    BtnOK.Top:=8;
    BtnOK.Left:=BtnCancel.Left-BtnOK.Width-8;
    BtnOK.Anchors:=[akRight,akTop];

    Memo:=TMemo.Create(CommentForm);
    Memo.Parent:=CommentForm;
    Memo.Align:=alClient;
    Memo.ScrollBars:=ssVertical;
    Memo.Text:=ProjectComment;

    CommentForm.ActiveControl:=Memo;

    if CommentForm.ShowModal=mrOK then
    begin
      ProjectComment:=Memo.Text;
      saved:=false;
    end;
  finally
    CommentForm.Free;
  end;
end;

// Restituisce true se si puo' procedere (progetto gia' salvato, oppure l'utente ha
// salvato o scelto di scartare le modifiche); false se l'utente ha annullato.
// Condivisa tra la chiusura dell'applicazione (FormCloseQuery) e le azioni che
// sostituiscono il progetto corrente (es. New Project).
function TForm1.ConfirmDiscardChanges(const AQuestion: string): boolean;
var
  myquestion:TModalResult;
begin
  if saved then
  begin
    result:=true;
    exit;
  end;
  myquestion := MessageDlg(AQuestion ,mtCustom,[mbYes, mbNo, mbCancel], 0);
  case myquestion of
    mrYes: begin saved:=saveData; result:=saved; end;
    mrNo:  result:=true;
  else
    result:=false; // mrCancel
  end;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose:=ConfirmDiscardChanges('Save changes before closing?');
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  a:integer;
  pxx:^TOperazione;
begin
  fontList.Free;
  for a:= 0 to opList.Count-1 do
  begin
    pxx:=opList.Items[a];
    FreeOperazione(pxx);
  end;
  opList.Free;
end;

procedure TForm1.glBOXMouseWheelUp(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
    FZoom := FZoom * 1.1; // Ingrandisce
    if FZoom > 100.0 then FZoom := 100.0;
    Handled := True;
    glBOX.Invalidate;
end;

procedure TForm1.glBOXMouseWheelDown(Sender: TObject; Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
    FZoom := FZoom / 1.1; // Rimpicciolisce
    if FZoom < 0.01 then FZoom := 0.01;
    Handled := True;
    glBOX.Invalidate;
end;

procedure TForm1.glBOXMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  deltaX_px, deltaY_px: Integer;
  currentWidthWorld, currentHeightWorld: Double;
begin
  statusBar1.Panels[0].Text:='Wheel to zoom, central button to pan,  to rotate, double left click to reset view';
  if FIsPanning then
  begin
    deltaX_px := X - FLastMouseX;
    deltaY_px := FLastMouseY - Y; // Invertito per coordinate OpenGL

    // Calcoliamo quanto spazio del G-Code è visibile ADESSO sullo schermo.
    // Dimensione base del pezzo divisa per lo zoom corrente.
    currentWidthWorld := ((maxX - minX) * 1.2) / FZoom;
    currentHeightWorld := ((maxY - minY) * 1.2) / FZoom;

    // Spostiamo il CENTRO della telecamera.
    // Se la direzione è invertita rispetto alla mano, cambia il "-" in "+"
    FCenterX := FCenterX - (deltaX_px * (currentWidthWorld / glBOX.Width));
    FCenterY := FCenterY - (deltaY_px * (currentHeightWorld / glBOX.Height));

    glBOX.Invalidate;
  end;
  if FIsRotating then
  begin
    deltaX_px := X - FLastMouseX;
    deltaY_px := FLastMouseY - Y; // Invertito per coordinate OpenGL
    FAngleX:=FAngleX+deltaY_px*0.5;
    FAngleZ:=FAngleZ+deltaX_px*0.5;
    //form1.Caption:=floattostr(FAngleX)+'  '+floattostr(FAngleZ);
    glBOX.Invalidate;
  end;
  FLastMouseX := X;
  FLastMouseY := Y;
end;

procedure TForm1.glBOXMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FLastMouseX := X;
  FLastMouseY := Y;
  if Button = mbMiddle then
  begin
    FIsPanning := True;
    glBOX.Cursor := crHandPoint; // Opzionale: cambia il cursore in una manina
  end;
  if Button = mbRight then
  begin
    FIsPanning := false;
    FIsRotating:= true;
  end;
end;

procedure TForm1.glBOXMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbMiddle then
  begin
    FIsPanning := False;
    glBOX.Cursor := crDefault; // Ripristina il cursore standard
  end;
  if Button = mbRight then
  begin
    FIsRotating:= false;
  end;
end;

procedure TForm1.ResetView;
begin
  FZoom := 1.0;
  FCenterX := 0.0;
  FCenterY := 0.0;
  FAngleX:=0;
  FAngleY:=0;
  FAngleZ:=0;
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity;
  DrawGCodeAutoCenteredCompiled(gCodeCompiled,true,panel5.Width,panel5.Height,travelShow,trackBar1.Position / 1000);
  GLBox.SwapBuffers;
end;

procedure TForm1.SpeedButton5Click(Sender: TObject);
begin
  travelShow:=not travelShow;
  if travelShow then SpeedButton5.ImageIndex:=0 else SpeedButton5.ImageIndex:=1;
  glBox.Invalidate;
end;

procedure TForm1.laserModeSetting(onOff:boolean);
begin
 if onOff then
 begin
  if checkBox3.Enabled=false then
  begin
    checkBox3.Checked:=laserTmp;
    checkBox3.Enabled:=true;
  end;
 end
 else
 begin
   if checkBox3.Enabled=true then
   begin
     laserTmp:=checkBox3.Checked;
     checkBox3.Checked:=false;
     checkBox3.Enabled:=false;
   end;
 end;
end;

procedure TForm1.SpeedButton6Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  laserModeSetting(true);
  groupBox1.Caption:='Line parameters';
  op:=5;buttonIcon;
  editButton1.Visible:=false;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=true;
  Label10.Visible:=true;
  Label11.Visible:=false;
  Label12.Visible:=false;
  Label13.Visible:=false;
  Label14.Visible:=false;
  Label16.Visible:=true;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=true;
  FloatSpinEdit10.Visible:=true;
  FloatSpinEdit11.Visible:=false;
  FloatSpinEdit12.Visible:=true;
  FloatSpinEdit12.Enabled:=true;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit9.Value:=0;
  FloatSpinEdit10.Value:=0;
  FloatSpinEdit12.Value:=0;
  comboBox1.Visible:=false;
  comboBox2.Visible:=false;
  comboBox4.Visible:=false;
  comboBox5.Visible:=false;
  checkBox2.Visible:=false;
  checkBox4.Visible:=false;
  edit1.Visible:=false;
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  //a:=a+32;
  //FloatSpinEdit11.Top:=a;
  //Label11.top:=a+14;
  //Label11.Caption:='Radius';
  togglebox1.visible:=false;
  groupBox3.Visible:=false;
  a:=a+32;
  FloatSpinEdit12.Top:=a;
  Label16.top:=a+14;
  //a:=a+32;
  //comboBox2.Top:=a;
  //Label14.top:=a+14;
 if CommonSpinEdit4.Value<1 then CommonSpinEdit4.Value:=3;
  Label7.Caption:='X1';
  Label8.Caption:='Y1';
  Label9.Caption:='X2';
  Label10.Caption:='Y2';
  Label16.Caption:='Thickness';

  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=true;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=true;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=true;
  CommonSpinEdit10.Enabled:=true;
  Combobox3.Enabled:=true;
  CheckBox3.Enabled:=true;

  impostaTabOrder;
end;

procedure TForm1.SpeedButton7Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  laserModeSetting(true);
  groupBox1.Caption:='SVG parameters';
  op:=6;buttonIcon;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=true;
  Label10.Visible:=false;
  Label11.Visible:=false;
  Label12.Visible:=true;
  Label13.Visible:=false;
  Label14.Visible:=true;
  Label16.Visible:=true;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=true;
  FloatSpinEdit10.Visible:=false;
  FloatSpinEdit11.Visible:=false;
  FloatSpinEdit12.Visible:=false;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit9.Value:=1;
  comboBox1.Visible:=false;
  comboBox2.Visible:=true;
  comboBox4.Visible:=true;
  comboBox5.Visible:=false;
  checkBox2.Visible:=false;
  edit1.Visible:=false;
  checkBox4.Visible:=false;
  editButton1.Visible:=true;
  editButton1.Text:='';
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  //a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  //a:=a+32;
  //FloatSpinEdit11.Top:=a;
  //Label11.top:=a+14;
  a:=a+32;
  comboBox2.Top:=a;
  Label14.top:=a+14;
  a:=a+32;
  Combobox4.Top:=a;
  Label16.top:=a+14;
  a:=a+32;
  editButton1.Top:=a;
  Label12.top:=a+14;
  a:=a+38;
  togglebox1.visible:=false;
  groupBox3.Visible:=false;
 if CommonSpinEdit4.Value<1 then CommonSpinEdit4.Value:=3;
  Label12.Caption:='File';
  Label7.Caption:='X';
  Label8.Caption:='Y';
  Label9.Caption:='Scale factor';
  Label14.Caption:='Compensation';
  Label16.Caption:='Engraving mode';

  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=true;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=true;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=true;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=true;
  CheckBox3.Enabled:=true;

  impostaTabOrder;
  statusBar1.Panels[0].Text:='Engraving area must be filled with full black (fill="black" attribute)';
end;

procedure TForm1.SpeedButton8Click(Sender: TObject);
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  op:=8;buttonIcon;
  panel8.Visible:=true;
  panel9.Visible:=false;
  panel11.Visible:=false;
  groupBox1.Caption:='Pattern parameters';
  label20.Enabled:=true;
  label21.Enabled:=true;
  label22.Enabled:=true;
  label23.Enabled:=true;
  Label26.Caption:='Formulas';
  spinEdit1.Enabled:=true;
  spinEdit2.Enabled:=true;
  floatSpinEdit1.Visible:=false;
  floatSpinEdit2.Visible:=false;
  floatSpinEdit3.Visible:=false;
  floatSpinEdit4.Visible:=false;
  floatSpinEdit5.Visible:=false;
  edit2.Visible:=true;
  edit3.Visible:=true;
  edit4.Visible:=true;
  edit5.Visible:=true;
  edit7.Visible:=true;
  edit2.Enabled:=true;
  edit3.Enabled:=true;
  edit4.Enabled:=true;
  edit5.Enabled:=true;
  edit7.Enabled:=true;

  CommonSpinEdit1.Enabled:=false;
  CommonSpinEdit2.Enabled:=false;
  CommonSpinEdit3.Enabled:=false;
  CommonSpinEdit4.Enabled:=false;
  CommonSpinEdit5.Enabled:=false;
  CommonSpinEdit6.Enabled:=false;
  CommonSpinEdit7.Enabled:=false;
  CommonSpinEdit8.Enabled:=false;
  CommonSpinEdit9.Enabled:=false;
  CommonSpinEdit10.Enabled:=false;
  Combobox3.Enabled:=false;
  CheckBox3.Enabled:=false;

  impostaTabOrder;
end;

procedure TForm1.SpeedButton9Click(Sender: TObject);
var
  a:integer=5;
begin
  listBox1.ItemIndex:=-1;
  button6.Enabled:=false;
  panel8.Visible:=false;
  panel9.Visible:=true;
  panel11.Visible:=false;
  laserModeSetting(false);
  groupBox1.Caption:='Allen Screw parameters';
  op:=7;buttonIcon;
  editButton1.Visible:=false;
  Label7.Visible:=true;
  Label8.Visible:=true;
  Label9.Visible:=true;
  Label10.Visible:=true;
  Label11.Visible:=true;
  Label12.Visible:=false;
  Label13.Visible:=false;
  Label14.Visible:=false;
  Label16.Visible:=false;
  Label17.Visible:=false;
  FloatSpinEdit7.Visible:=true;
  FloatSpinEdit8.Visible:=true;
  FloatSpinEdit9.Visible:=true;
  FloatSpinEdit10.Visible:=true;
  FloatSpinEdit11.Visible:=true;
  FloatSpinEdit12.Visible:=false;
  SpinEdit3.Visible:=false;
  SpinEdit4.Visible:=false;
  FloatSpinEdit9.Value:=0;
  FloatSpinEdit10.Value:=0;
  FloatSpinEdit11.Value:=0;
  comboBox1.Visible:=false;
  comboBox2.Visible:=false;
  comboBox5.Visible:=false;
  checkBox2.Visible:=false;
  checkBox4.Visible:=false;
  edit1.Visible:=false;
  FloatSpinEdit7.Top:=a;
  Label7.top:=a+14;
  a:=a+32;
  FloatSpinEdit8.Top:=a;
  Label8.top:=a+14;
  a:=a+32;
  FloatSpinEdit9.Top:=a;
  Label9.top:=a+14;
  a:=a+32;
  FloatSpinEdit10.Top:=a;
  Label10.top:=a+14;
  a:=a+32;
  FloatSpinEdit11.Top:=a;
  Label11.top:=a+14;
  FloatSpinEdit10.Enabled:=true;
 if CommonSpinEdit4.Value<1 then CommonSpinEdit4.Value:=3;
  Label11.Caption:='DiameterMinor';
  togglebox1.visible:=false;
  groupBox3.Visible:=false;
  Label7.Caption:='X Center';
  Label8.Caption:='Y Center';
  Label9.Caption:='DiameterMajor';
  Label10.Caption:='DepthMajor';
  FloatSpinEdit11.Enabled:=true;

  CommonSpinEdit1.Enabled:=true;
  CommonSpinEdit2.Enabled:=true;
  CommonSpinEdit3.Enabled:=true;
  CommonSpinEdit4.Enabled:=true;
  CommonSpinEdit5.Enabled:=true;
  CommonSpinEdit6.Enabled:=true;
  CommonSpinEdit7.Enabled:=true;
  CommonSpinEdit8.Enabled:=true;
  CommonSpinEdit9.Enabled:=true;
  CommonSpinEdit10.Enabled:=true;
  Combobox3.Enabled:=true;
  CheckBox3.Enabled:=false;

  impostaTabOrder;
end;

procedure TForm1.TrackBar1Change(Sender: TObject);
begin
  glBox.Invalidate;
end;

procedure TForm1.glBOXDblClick(Sender: TObject);
begin
  ResetView;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  Info : TSearchRec;
begin
  // Il rendering dei tooltip (THintWindow) sotto il widgetset GTK2 di questo
  // sistema va in crash nativo (SIGSEGV in gdk_gc_get_values, vedi bug1.txt/
  // bug2.txt) sia durante operazioni pesanti che nel normale ciclo di eventi:
  // non e' un problema recuperabile con un try/except (crash nativo, non
  // un'eccezione Pascal). Disabilitando gli hint a livello applicativo si
  // evita del tutto la creazione della finestra di tooltip.
  Application.ShowHint:=False;
  saved:=true;
  nomeFile:='';
  ProjectComment:='';
  PreviewExportFile:='';
  PreviewExportStream:=nil;
  PreviewExportName:='';
  laserTmp:=false;
  travelShow:=true;
  FZoom := 1.0; // Zoom nominale (100%)
  FCenterX := 0.0;
  FCenterY := 0.0;
  FIsPanning := False;  gCode:='';
  opList:=TList.Create;
  g_path := ExtractFilePath(Application.ExeName);
  fontList:=TStringList.Create;
  if FindFirst(g_path + '*.ttf', faAnyFile, Info)=0 then begin
    repeat
      fontList.Add(info.Name);
    until FindNext(Info) <> 0;
  end;
  comboBox1.Items.Assign(fontList);
  FindClose(Info);
  GLbox:= TOpenGLControl.Create(Form1);
  GLbox.AutoResizeViewport:= true;
  GLBox.Parent := panel5;
  GLBox.MultiSampling:= 4;
  GLBox.Align := alClient;
  GLBox.OnPaint := @GLboxPaint;
  GLBox.OnResize:=@GLboxResize;
  GLBox.OnMouseWheelUp:=@glBOXMouseWheelUp;
  GLBox.OnMouseWheelDown:=@glBOXMouseWheelDown;
  GLBox.OnMouseMove:=@glBOXMouseMove;
  GLBox.OnMouseUp:=@glBOXMouseUp;
  GLBox.OnMouseDown:=@glBOXMouseDown;
  GLBox.OnDblClick:=@glBOXDblClick;
  GLBox.invalidate;
  GCodeEditor := TGrandeEditorTesto.Create(Self);
  GCodeEditor.Parent := Panel6;
  GCodeEditor.Align := alClient;
  GCodeEditor.ReadOnly:=true;
  GCodeEditor.WordWrap:=false;
  GCodeEditor.UseUTF8:=false;
  GCodeEditor.EnableRichText:=false;
  SpeedButton1Click(nil);
end;

procedure TForm1.FormResize(Sender: TObject);
begin

end;

procedure TForm1.slezionatoElemento;
var
  a:integer;
  pxx:^TOperazione;
begin
  a:=listBox1.ItemIndex;
  if a>-1 then
  begin
    selezionato:=a;
    pxx:=opList.Items[a];
    CommonSpinEdit1.Value:=pxx^.RapidFeed;
    CommonSpinEdit2.Value:=pxx^.HFeed;
    CommonSpinEdit3.Value:=pxx^.ZFeed;
    CommonSpinEdit4.Value:=pxx^.ToolDia;
    CommonSpinEdit5.Value:=pxx^.ZDepth;
    CommonSpinEdit6.Value:=pxx^.ZStep;
    CommonSpinEdit7.Value:=pxx^.Spindle;
    CommonSpinEdit8.Value:=pxx^.ZStart;
    CommonSpinEdit9.Value:=pxx^.finishAllowance;
    CommonSpinEdit10.Value:=pxx^.maxRamp;
    floatSpinEdit7.Value:=pxx^.X;
    floatSpinEdit8.Value:=pxx^.Y;
    checkbox3.Checked:=pxx^.laserMode;
    comboBox3.ItemIndex:=pxx^.direction;
    checkBox1.OnChange:=nil;
    checkBox1.Checked:=pxx^.enabled;
    checkBox1.OnChange:=@CheckBox1Change;
    if pxx^.op=1 then
    begin
      SpeedButton1Click(nil);
      floatSpinEdit9.Value:=pxx^.specific[0];
      floatSpinEdit10.Value:=pxx^.specific[1];
      floatSpinEdit11.Value:=pxx^.specific[2];
      ComboBox2.ItemIndex:=round(pxx^.specific[3]);
      floatSpinEdit12.Value:=pxx^.specific[4];
      transformationMatrix1.Value:=pxx^.TransformationMatrix.a;
      transformationMatrix2.Value:=pxx^.TransformationMatrix.c;
      transformationMatrix3.Value:=pxx^.TransformationMatrix.e;
      transformationMatrix4.Value:=pxx^.TransformationMatrix.b;
      transformationMatrix5.Value:=pxx^.TransformationMatrix.d;
      transformationMatrix6.Value:=pxx^.TransformationMatrix.f;
      if (pxx^.TransformationMatrix.a<>1)or(pxx^.TransformationMatrix.b<>0)or(pxx^.TransformationMatrix.c<>0)or
         (pxx^.TransformationMatrix.d<>1)or(pxx^.TransformationMatrix.e<>0)or(pxx^.TransformationMatrix.f<>0)then toggleBox1.Checked:=true;
    end;
    if pxx^.op=2 then
    begin
      SpeedButton2Click(nil);
      floatSpinEdit11.Value:=pxx^.specific[0];
      ComboBox2.ItemIndex:=round(pxx^.specific[3]);
      floatSpinEdit12.Value:=pxx^.specific[4];
      transformationMatrix1.Value:=pxx^.TransformationMatrix.a;
      transformationMatrix2.Value:=pxx^.TransformationMatrix.c;
      transformationMatrix3.Value:=pxx^.TransformationMatrix.e;
      transformationMatrix4.Value:=pxx^.TransformationMatrix.b;
      transformationMatrix5.Value:=pxx^.TransformationMatrix.d;
      transformationMatrix6.Value:=pxx^.TransformationMatrix.f;
      if (pxx^.TransformationMatrix.a<>1)or(pxx^.TransformationMatrix.b<>0)or(pxx^.TransformationMatrix.c<>0)or
         (pxx^.TransformationMatrix.d<>1)or(pxx^.TransformationMatrix.e<>0)or(pxx^.TransformationMatrix.f<>0)then toggleBox1.Checked:=true;
    end;
    if pxx^.op=3 then
    begin
      SpeedButton3Click(nil);
      floatSpinEdit11.Value:=pxx^.specific[0];
      edit1.Text:=pxx^.text;
      comboBox1.text:=pxx^.fontName;
    end;
    if pxx^.op=4 then
    begin
      SpeedButton4Click(nil);
      floatSpinEdit9.Value:=pxx^.specific[0];
      floatSpinEdit10.Value:=pxx^.specific[1];
      floatSpinEdit11.Value:=pxx^.specific[2];
      floatSpinEdit12.Value:=pxx^.specific[3];
      checkBox2.Checked:=pxx^.specificBool[0];
      checkBox4.Checked:=pxx^.specificBool[1];
      editButton1.Text:=pxx^.filename;
    end;
    if pxx^.op=5 then
    begin
      SpeedButton6Click(nil);
      floatSpinEdit9.Value:=pxx^.specific[0];
      floatSpinEdit10.Value:=pxx^.specific[1];
      floatSpinEdit12.Value:=pxx^.specific[4];
    end;
    if pxx^.op=6 then
    begin
      SpeedButton7Click(nil);
      editButton1.Text:=pxx^.filename;
      floatSpinEdit9.Value:=pxx^.specific[0];
      combobox2.ItemIndex:=pxx^.specificInteger[0];
      combobox4.ItemIndex:=pxx^.specificInteger[1];
    end;
    if pxx^.op=7 then
    begin
      SpeedButton9Click(nil);
      floatSpinEdit9.Value:=pxx^.specific[0];
      floatSpinEdit10.Value:=pxx^.specific[1];
      floatSpinEdit11.Value:=pxx^.specific[2];
    end;
    if pxx^.op=8 then
    begin
      SpeedButton8Click(nil);
      spinEdit1.Value:=pxx^.specificInteger[0];
      spinEdit2.Value:=pxx^.specificInteger[1];
      edit2.Text:=pxx^.specificText[0];
      edit3.Text:=pxx^.specificText[1];
      edit6.Text:=pxx^.specificText[2];
      edit4.Text:=pxx^.specificText[3];
      edit5.Text:=pxx^.specificText[4];
      edit7.Text:=pxx^.specificText[5];
    end;
    if pxx^.op=9 then
    begin
      SpeedButton10Click(nil);
      floatSpinEdit1.Value:=pxx^.specific[0];
      floatSpinEdit2.Value:=pxx^.specific[1];
      edit6.Text:=pxx^.specificText[2];
    end;
    if pxx^.op=10 then
    begin
      SpeedButton11Click(nil);
      floatSpinEdit3.Value:=pxx^.specific[0];
      floatSpinEdit4.Value:=pxx^.specific[1];
      floatSpinEdit5.Value:=pxx^.specific[2];
      edit6.Text:=pxx^.specificText[2];
    end;
    if pxx^.op=11 then
    begin
      SpeedButton12Click(nil);
      editButton1.Text:=pxx^.filename;
      comboBox5.ItemIndex:=pxx^.specificInteger[0];
      floatSpinEdit9.Value:=pxx^.specific[0];
      floatSpinEdit10.Value:=pxx^.specific[1];
      SpinEdit3.Value:=pxx^.specificInteger[1];
      SpinEdit4.Value:=pxx^.specificInteger[2];
    end;
    if pxx^.op=12 then
    begin
      SpeedButton13Click(nil);
      editButton1.Text:=pxx^.filename;
      floatSpinEdit9.Value:=pxx^.specific[0];
      checkBox4.Checked:=pxx^.specificBool[0];
    end;
    if pxx^.op=13 then
    begin
      SpeedButton14Click(nil);
      if pxx^.specificInteger[0]=1 then radioButton1.Checked:=true;
      if pxx^.specificInteger[0]=2 then radioButton2.Checked:=true;
      if pxx^.specificInteger[0]=3 then radioButton3.Checked:=true;
      if pxx^.specificInteger[0]=4 then radioButton4.Checked:=true;
      if pxx^.specificInteger[0]=4 then memo2.Text:=pxx^.specificText[0];
      if pxx^.specificInteger[0]<>4 then memo2.Text:='';
    end;
    Button5.Enabled:=true;
    Button6.Enabled:=true;
  end
  else
  begin
    Button5.Enabled:=false;
    Button6.Enabled:=false;
  end;
  listBox1.ItemIndex:=a; //Perchè all'interno di SpeedButtonXClick viene rimosso
end;

procedure TForm1.ListBox1Click(Sender: TObject);
begin
  slezionatoElemento;
end;

procedure TForm1.ListBox1SelectionChange(Sender: TObject; User: boolean);
begin
  //slezionatoElemento;
end;

end.

