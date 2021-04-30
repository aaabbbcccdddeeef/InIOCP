unit frmNoneCertifyServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, iocp_managers, iocp_server, StdCtrls, iocp_clients, iocp_sockets,
  iocp_clientBase;

type
  TFormNoneCertifyServer = class(TForm)
    InIOCPServer1: TInIOCPServer;
    InFileManager1: TInFileManager;
    Memo1: TMemo;
    btnStart: TButton;
    btnStop: TButton;
    Button3: TButton;
    Button4: TButton;
    btnConnect: TButton;
    InFileClient1: TInFileClient;
    InConnection1: TInConnection;
    procedure FormCreate(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
    procedure InFileManager1BeforeUpload(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure Button3Click(Sender: TObject);
    procedure InFileManager1BeforeDownload(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure Button4Click(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure InConnection1AfterConnect(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormNoneCertifyServer: TFormNoneCertifyServer;

implementation

uses
  iocp_log, iocp_base, iocp_varis, iocp_utils;

{$R *.dfm}

procedure TFormNoneCertifyServer.btnConnectClick(Sender: TObject);
begin
  InConnection1.Active := not InConnection1.Active; 
end;

procedure TFormNoneCertifyServer.btnStartClick(Sender: TObject);
begin
  iocp_log.TLogThread.InitLog;     // ������־
  InIOCPServer1.Active := True;    // ��������
end;

procedure TFormNoneCertifyServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False; // ֹͣ����
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormNoneCertifyServer.Button3Click(Sender: TObject);
begin
  // ���� S_DownloadFile
  // ����һ��������
  InFileClient1.Upload('Upload_file.txt');

  // �����������Լ���������������˷������
{  with TMessagePack.Create(InFileClient1) do
  begin
    AsString['path'] := 'none_certify';
    LoadFromFile('Upload_file.txt');  // ������ FileName :=
    Post(atFileUpload);
  end;  }
end;

procedure TFormNoneCertifyServer.Button4Click(Sender: TObject);
begin
  // ���� S_DownloadFile
  // ����һ�������٣����浽·�� InConnection1.LocalPath
  InFileClient1.Download('S_DownloadFile.7z');

  // �����������Լ���������������˷������
{  with TMessagePack.Create(InFileClient1) do
  begin
    AsString['path'] := 'none_certify';  // �����·��
    LocalPath := 'temp\';  // ���ش��·��
    FileName := 'S_DownloadFile.7z';
    Post(atFileDownload);
  end; }
end;

procedure TFormNoneCertifyServer.FormCreate(Sender: TObject);
begin
  // ׼������·��
  FAppDir := ExtractFilePath(Application.ExeName);

  // �ͻ������ݴ��·��
  iocp_Varis.gUserDataPath := FAppDir + 'none_certify\';

  MyCreateDir(FAppDir + 'log');    // ��Ŀ¼
  MyCreateDir(iocp_Varis.gUserDataPath);   // ��Ŀ¼

end;

procedure TFormNoneCertifyServer.InConnection1AfterConnect(Sender: TObject);
begin
  if InConnection1.Active then
    btnConnect.Caption := '�Ͽ�'
  else
    btnConnect.Caption := '����';    
end;

procedure TFormNoneCertifyServer.InFileManager1BeforeDownload(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ���ļ���������
  if (Params.AsString['path'] = '') then  // û��·��
    InFileManager1.OpenLocalFile(Result, 'none_certify\' + Params.FileName)
  else
    InFileManager1.OpenLocalFile(Result, Params.AsString['path'] + '\' + Params.FileName);
end;

procedure TFormNoneCertifyServer.InFileManager1BeforeUpload(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ���ļ������ϴ��������¼������ InFileManager1.CreateNewFile()
  // ��û�е�¼�������·�����
  if (Params.AsString['path'] = '') then
    Params.CreateAttachment('none_certify\')   
  else
    Params.CreateAttachment(Params.AsString['path'] + '\');  // �ͻ���ָ����·��  
end;

procedure TFormNoneCertifyServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

end.
