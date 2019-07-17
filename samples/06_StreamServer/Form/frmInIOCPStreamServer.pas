unit frmInIOCPStreamServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, iocp_sockets, iocp_server, fmIOCPSvrInfo, iocp_managers;

type
  TFormInIOCPStreamServer = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    btnStart: TButton;
    btnStop: TButton;
    Edit1: TEdit;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    InStreamManager1: TInStreamManager;
    procedure FormCreate(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure InIOCPServer1DataSend(Sender: TBaseSocket; Size: Cardinal);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
    procedure InIOCPServer1Connect(Sender: TObject; Socket: TBaseSocket);
    procedure InIOCPServer1Disconnect(Sender: TObject; Socket: TBaseSocket);
    procedure InStreamManager1Receive(Socket: TStreamSocket;
      const Data: PAnsiChar; Size: Cardinal);
    procedure InIOCPServer1DataReceive(Sender: TBaseSocket; Size: Cardinal);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPStreamServer: TFormInIOCPStreamServer;

implementation

uses
  iocp_log, iocp_utils, iocp_base, iocp_msgPacks, http_utils;
  
{$R *.dfm}

procedure TFormInIOCPStreamServer.btnStartClick(Sender: TObject);
begin
//  Memo1.Lines.Clear;
  iocp_log.TLogThread.InitLog;              // ������־
  InIOCPServer1.ServerAddr := Edit1.Text;     // ��ַ
  InIOCPServer1.Active := True;               // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);     // ��ʼͳ��
end;

procedure TFormInIOCPStreamServer.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;          // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPStreamServer.FormCreate(Sender: TObject);
begin
  // ����·��
//  Edit1.Text := GetLocalIp;
  FAppDir := ExtractFilePath(Application.ExeName);     
  MyCreateDir(FAppDir + 'log');
end;

procedure TFormInIOCPStreamServer.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPStreamServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  Memo1.Lines.Add('ip: ' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('port: ' + IntToStr(InIOCPServer1.ServerPort));
end;

procedure TFormInIOCPStreamServer.InIOCPServer1Connect(Sender: TObject;
  Socket: TBaseSocket);
begin
  // Socket ���룬������Ͷ�Ž������ݣ�����ʹ�� Socket.Close ��ֹ����;
end;

procedure TFormInIOCPStreamServer.InIOCPServer1DataReceive(Sender: TBaseSocket;
  Size: Cardinal);
begin
  // ������յ�����
  // 1. �ش�������°���������������� TInStreamManager��
  //    �� TInStreamManager.OnReceive �д����յ�������
  // 2. �� TWorkThread.ExecIOEvent ���ã�δ������
  //    �̰߳�ȫ���ϸ���˵��Ҫ�������̵߳��κοؼ���
end;

procedure TFormInIOCPStreamServer.InIOCPServer1DataSend(Sender: TBaseSocket;
  Size: Cardinal);
begin
  // ����˷�������
  // �� TWorkThread.ExecIOEvent ���ã�δ������
  //    �̰߳�ȫ���ϸ���˵��Ҫ�������̵߳��κοؼ���
end;

procedure TFormInIOCPStreamServer.InIOCPServer1Disconnect(Sender: TObject;
  Socket: TBaseSocket);
begin
  // Socket �������ر�
end;

procedure TFormInIOCPStreamServer.InStreamManager1Receive(Socket: TStreamSocket;
  const Data: PAnsiChar; Size: Cardinal);
var
  S: String;
  i: Integer;
//  Stream: TFileStream;
begin
  // �ش�������°���������������� TInStreamManager���ڱ��¼������յ�������

  // �յ�һ�����ݰ���δ�ؽ�����ϣ�
  // Socket: �� TStreamSocket!
  //   Data: ����
  //   Size�����ݳ���

  // ������תΪ String ��ʾ
  SetString(S, Data, Size);
  memo1.lines.Add(S);

  // ���ݿ�ͷΪ �ͻ���Id
  if (Socket.ClientId = '') then  // δ�Ǽǿͻ��� Id
  begin
    i := Pos(':', S);
    if (i > 0) then
      Socket.ClientId := Copy(S, 1, i - 1);
    if (Socket.ClientId = 'ADMIN') and (Socket.Role = crUnknown) then
      Socket.Role := crAdmin;
  end;

  // �ͻ���һ��Ҫ�ܽ��շ���˵�������Ϣ������������Ϣ����

  // �ͻ��������� TIdTCPClient������������Ҫ֧����Э��
  //   TIdTCPClient ��ֱ��֧�ֱ���������Ϣ�����ӵĿͻ����޷�������ʾ
  
{  if (Socket.Role = crAdmin) then  // �� Indy TCP Client �ĸ�ʽ������Ϣ
    InStreamManager1.Broadcast(Socket, '123 GET_STATE'#13#10)  // �㲥���ռ��ͻ�����Ϣ
  else
    InStreamManager1.SendTo(Socket, 'ADMIN', '123 GET_STATE'#13#10); // ����״̬��Ϣ������� }

  // �����Ȱ��豸�����������ݱ��浽 Socket.Data ��
  Socket.SendData('123 RETURN OK'#13#10);

  // �ж��ַ�ʽ�������ݸ��ͻ���

  // 1. �����ڴ��
//  Socket.SendData(Data, Size);

  // 2. �����ı�
//  Socket.SendData('Test Text ����');

  // 3. ����һ���ļ���retrun_stream.txt ������ html��������ͷ+���ݣ�
{  Stream := TFileStream.Create('retrun_stream.txt', fmShareDenyWrite);  // Ҫ��������������
  Socket.SendData(Stream);   // �Զ��ͷ� Stream  }

  // 4. ֱ�Ӵ��ļ����� Handle(�����)
//  Socket.SendData(InternalOpenFile('retrun_stream.txt'));

  // 5. ����һ�� Variant
//  Socket.SendDataVar(Value);  

end;

end.
