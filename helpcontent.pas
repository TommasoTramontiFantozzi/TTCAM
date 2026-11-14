unit helpContent;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  grandeeditortesto;

type

  { TForm3 }

  TForm3 = class(TForm)
    Button1: TButton;
    Panel1: TPanel;
    Panel2: TPanel;
    procedure Button1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private
    Editor:Tgrandeeditortesto;
  public

  end;

var
  Form3: TForm3;

implementation

{$R *.lfm}

{ TForm3 }

function ResourceToString(const ResName: string): string;
var
  ResStream: TResourceStream;
  StrStream: TStringStream;
begin
  Result := '';
  try
    // Load the resource from the compiled executable
    ResStream := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
    try
      // Use TStringStream to easily read into a string
      StrStream := TStringStream.Create('');
      try
        StrStream.CopyFrom(ResStream, ResStream.Size);
        Result := StrStream.DataString;
      finally
        StrStream.Free;
      end;
    finally
      ResStream.Free;
    end;
  except
    on E: Exception do
      // Handle missing resource or read errors
      raise Exception.Create('Failed to load resource: ' + E.Message);
  end;
end;


procedure TForm3.FormCreate(Sender: TObject);
begin
  Editor:=Tgrandeeditortesto.Create(Panel1);
  Editor.Parent:=Panel1;
  Editor.Align:=alClient;
  Editor.WordWrap:=true;
  Editor.LinkColor:=clGrayText;
  //Editor.ReadOnly:=true;
  Editor.EnableRichText:=false;
  Editor.UseUTF8:=true;
  Editor.Testo.Text:=ResourceToString('ISTRUZIONI');
  Editor.EnableRichText:=true;
end;

procedure TForm3.Button1Click(Sender: TObject);
begin
 Editor.EnableRichText:=not Editor.EnableRichText;
end;

procedure TForm3.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Editor.Free;
end;

end.

