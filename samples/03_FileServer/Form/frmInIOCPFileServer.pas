unit frmInIOCPFileServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_base, iocp_clients, iocp_server,
  iocp_sockets, iocp_managers, iocp_msgPacks;

type
  TFormInIOCPFileServer = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    btnStart: TButton;
    btnStop: TButton;
    InClientManager1: TInClientManager;
    InFileManager1: TInFileManager;
    InMessageManager1: TInMessageManager;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure InClientManager1Login(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure FormCreate(Sender: TObject);
    procedure InFileManager1BeforeDownload(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InFileManager1BeforeUpload(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InFileManager1QueryFiles(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InFileManager1AfterDownload(Sender: TObject;
      Params: TReceiveParams; Document: TIOCPDocument);
    procedure InFileManager1AfterUpload(Sender: TObject; Params: TReceiveParams;
      Document: TIOCPDocument);
    procedure InFileManager1DeleteFile(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InFileManager1RenameFile(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InFileManager1SetWorkDir(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPFileServer: TFormInIOCPFileServer;

implementation

uses
  iocp_log, iocp_varis, iocp_utils;

{$R *.dfm}

procedure TFormInIOCPFileServer.btnStartClick(Sender: TObject);
begin
  // ע��InFileManager1.ShareStream = True ���Թ��������ļ���
  Memo1.Lines.Clear;
  iocp_log.TLogThread.InitLog;              // ������־
  InIOCPServer1.Active := True;               // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);     // ��ʼͳ��
end;

procedure TFormInIOCPFileServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;          // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPFileServer.FormCreate(Sender: TObject);
begin
  // ׼������·��
  FAppDir := ExtractFilePath(Application.ExeName);
  iocp_utils.IniDateTimeFormat;    // ��������ʱ���ʽ
    
  // �ͻ������ݴ��·����2.0�����ƣ�
  iocp_Varis.gUserDataPath := FAppDir + 'client_data\';

  MyCreateDir(FAppDir + 'log');    // ��Ŀ¼
  MyCreateDir(FAppDir + 'temp');   // ��Ŀ¼

  // �����Ե��û�·��
  MyCreateDir(iocp_Varis.gUserDataPath);  // ��Ŀ¼

  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\data');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\msg');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\temp');

  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\data');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\msg');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\temp');

end;

procedure TFormInIOCPFileServer.InClientManager1Login(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  if (Params.Password <> '') then 
  begin
    Result.Role := crAdmin;     // ���Թ㲥Ҫ�õ�Ȩ�ޣ�2.0�ģ�
    Result.ActResult := arOK;

    // �Ǽ�����, �Զ������û�����·����ע��ʱ����
    InClientManager1.Add(Params.Socket, crAdmin);

    // ��������ϢʱҪ���루���ļ�������
  end else
    Result.ActResult := arFail;
end;

procedure TFormInIOCPFileServer.InFileManager1AfterDownload(Sender: TObject;
  Params: TReceiveParams; Document: TIOCPDocument);
begin
  memo1.Lines.Add('������ϣ�' + ExtractFileName(Document.FileName));
end;

procedure TFormInIOCPFileServer.InFileManager1AfterUpload(Sender: TObject;
  Params: TReceiveParams; Document: TIOCPDocument);
begin
  // �ϴ��ļ����
  //   Sender: TBusiWorker
  //   Socket��TIOCPSocket
  // Document��TIOCPDocument

  //   �������ϴ���ʽ��atFileUpload��atFileSendTo
  //   ��� Document.UserName ��Ϊ�գ�
  //  ��˵���ǻ����ļ���Ҫ֪ͨ�Է����ػ򱣴���Ϣ���Է���¼ʱ��ȡ��

  memo1.Lines.Add('�ϴ���ϣ�' + ExtractFileName(Document.FileName));

  // �°�������ͷ�����ToUser �������б�ֱ�ӵ��ü��ɣ�
  if (Params.ToUser <> '') then  // �������ļ���֪ͨ ToUser ����
    InMessageManager1.PushMsg(Params, Params.ToUser);  // ���ѻ򱣴浽�����ļ�

end;

procedure TFormInIOCPFileServer.InFileManager1BeforeDownload(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �����ļ���Ҫʹ�����·����
  if (Params.Action = atFileDownChunk) then
  begin
    // �������ش��ļ�
    memo1.Lines.Add('׼�����أ���������' + 'F:\Backup\jdk-8u77-windows-i586.exe');  // F:\Backup\Ghost\WIN-7-20190228.GHO
    InFileManager1.OpenLocalFile(Result, 'F:\Backup\jdk-8u77-windows-i586.exe'); // F:\Backup\Ghost\WIN-7-20190228.GHO
  end else
  begin
    memo1.Lines.Add('׼�����أ�' + 'F:\Backup\jdk-8u77-windows-i586.exe'); // gUserDataPath + Params.FileName);
    InFileManager1.OpenLocalFile(Result, 'F:\Backup\jdk-8u77-windows-i586.exe');
  end;
end;

procedure TFormInIOCPFileServer.InFileManager1BeforeUpload(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �ϴ��ļ������û�����·����
  //   2.0 ���ڲ��Զ��ж��ļ��Ƿ���ڣ�������һ���ļ���
  Memo1.Lines.Add('׼���ϴ�: ' + Params.FileName);

  // ������¼������ʹ�����ַ������գ�
  // Params.CreateAttachment('���·��');
 
  InFileManager1.CreateNewFile(Params);
end;

procedure TFormInIOCPFileServer.InFileManager1DeleteFile(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ����ɾ���ļ���Ӧ�ڿͻ�����ȷ��
  if DeleteFile(Params.Socket.Envir^.WorkDir + Params.FileName) then
    Result.ActResult := arOK
  else
    Result.ActResult := arFail;
end;

procedure TFormInIOCPFileServer.InFileManager1QueryFiles(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ��ѯ��ǰ����Ŀ¼�µ��ļ�
  InFileManager1.ListFiles(Params, Result);
end;

procedure TFormInIOCPFileServer.InFileManager1RenameFile(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �Ĺ���Ŀ¼�µ��ļ���
  if RenameFile(Params.Socket.Envir^.WorkDir + Params.FileName,
                Params.Socket.Envir^.WorkDir + Params.NewFileName) then
    Result.ActResult := arOK
  else
    Result.ActResult := arFail;
end;

procedure TFormInIOCPFileServer.InFileManager1SetWorkDir(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ���ù���Ŀ¼�����ܳ�������Ĺ���Ŀ¼��Χ��
//  if True then
    InFileManager1.SetWorkDir(Result, Params.Directory);  // 2.0 ����
//  else
//    Result.ActResult := arFail;
end;

procedure TFormInIOCPFileServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPFileServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  memo1.Lines.Add('IP:' + InIOCPServer1.ServerAddr);
  memo1.Lines.Add('Port:' + IntToStr(InIOCPServer1.ServerPort));
end;

end.
