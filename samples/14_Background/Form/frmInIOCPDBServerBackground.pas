unit frmInIOCPDBServerBackground;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_base, iocp_clients, iocp_server,
  iocp_sockets, iocp_managers, iocp_msgPacks, http_objects;

type
  TFormInIOCPDBServerBGThread = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    btnStart: TButton;
    btnStop: TButton;
    InClientManager1: TInClientManager;
    InDatabaseManager1: TInDatabaseManager;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    InMessageManager1: TInMessageManager;
    InFileManager1: TInFileManager;
    InHttpDataProvider1: TInHttpDataProvider;
    InWebSocketManager1: TInWebSocketManager;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure InClientManager1Login(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure FormCreate(Sender: TObject);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
    procedure InMessageManager1ListFiles(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InFileManager1BeforeDownload(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InWebSocketManager1Receive(Sender: TObject; Socket: TWebSocket);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPDBServerBGThread: TFormInIOCPDBServerBGThread;

implementation

uses
  iocp_log, iocp_varis, iocp_utils, dm_iniocp_test;

{$R *.dfm}

procedure TFormInIOCPDBServerBGThread.btnStartClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  
  iocp_log.TLogThread.InitLog;  // ������־

  // ע����ģ�ࣨ���Զ��֡�������ݿ����ӣ�
  InDatabaseManager1.AddDataModule(TdmInIOCPTest, 'Access-��������');
//  InDatabaseManager1.AddDataModule(TdmFirebird, 'Firebird-�豸');
//  InDatabaseManager1.AddDataModule(TdmFirebird2, 'Firebird-������Դ');

  InIOCPServer1.Active := True; // ��������
  FrameIOCPSvrInfo1.Start(InIOCPServer1);  // ��ʼͳ��
end;

procedure TFormInIOCPDBServerBGThread.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False;   // ֹͣ����
  FrameIOCPSvrInfo1.Stop;          // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPDBServerBGThread.FormCreate(Sender: TObject);
begin
  // ׼������·��
  FAppDir := ExtractFilePath(Application.ExeName);

  // �ͻ������ݴ��·����2.0�����ƣ�
  iocp_Varis.gUserDataPath := FAppDir + 'data\';

  MyCreateDir(FAppDir + 'log');    // ��Ŀ¼
  MyCreateDir(FAppDir + 'temp');   // ��Ŀ¼
  MyCreateDir(iocp_Varis.gUserDataPath);  // ��Ŀ¼
end;

procedure TFormInIOCPDBServerBGThread.InClientManager1Login(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  if (Params.Password <> '') then
  begin
    Result.Role := crAdmin;   // ���� crAdmin Ȩ�ޣ��ܹ㲥
    Result.ActResult := arOK;
    // �Ǽ����ԡ������û����ƹ���·��
    InClientManager1.Add(Params.Socket, crAdmin);
  end else
    Result.ActResult := arFail;
end;

procedure TFormInIOCPDBServerBGThread.InFileManager1BeforeDownload(
  Sender: TObject; Params: TReceiveParams; Result: TReturnResult);
begin
  // �ͻ������ز�ѯ���
  InFileManager1.OpenLocalFile(Result, 'data\' + Params.FileName);  // �ϸ���˵Ӧ�򿪹���·�����ļ�
  Result.ActResult := arOK;
end;

procedure TFormInIOCPDBServerBGThread.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPDBServerBGThread.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  Memo1.Lines.Add('server ip: ' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('port: ' + IntToStr(InIOCPServer1.ServerPort));
end;

procedure TFormInIOCPDBServerBGThread.InMessageManager1ListFiles(
  Sender: TObject; Params: TReceiveParams; Result: TReturnResult);
begin
  // ��ο� ��-25 �ķ��� InFileManager1QueryFiles��
  
  // 1��Ĭ����� Params.Socket.Background = False, ��ִ̨��ʱΪ True��
  // 2������һ������������Ͷ�ŵ���ִ̨�У��磺InFileManager1.AddToBackground()��
  // 3����̨�߳�Ҳִ�б��������� Params.Socket.Background = True������ʱҪ Wakeup �ͻ��ˣ�
  // 4����ִ̨��ʱ����ֱ�ӷ��� Result��ֻ�����ͣ�����һ����������Result ����̫��

  // TWebSocket ͬ��֧�ֺ�ִ̨�У�
  // �°汾�� TInIOCPDataModule �������������� AddToBackground��Wakeup��
  // �ο�������������������ʵ�ֺ�ִ̨�С�

end;

procedure TFormInIOCPDBServerBGThread.InWebSocketManager1Receive(
  Sender: TObject; Socket: TWebSocket);
begin
  // ����TdmInIOCPTest.InIOCPDataModuleWebSocketQuery
  if Socket.MsgType = mtJSON then
    case Socket.JSON.Action of
      1:  // ע��
        Socket.UserName := Socket.JSON.S['_userName'];  // ����������

      999:         // ���ݲ�ѯ����
        if Socket.JSON.S['_dataFile'] = '' then
          TBusiWorker(Sender).DataModule.WebSocketQuery(Socket.JSON, Socket.Result)
        else begin   // ���ز�ѯ���
          Socket.Result.S['_tableName'] := Socket.JSON.S['_tableName'];
          Socket.Result.S['_dataFile'] := Socket.JSON.S['_dataFile'];
          Socket.Result.Attachment := TFileStream.Create('temp\' + Socket.JSON.S['_dataFile'], fmShareDenyWrite);
          Socket.SendResult;  // ��Ĭ���ַ������� UTF-8
        end;

      990: begin // �������ݱ�
        TBusiWorker(Sender).DataModule.WebSocketUpdates(Socket.JSON, Socket.Result);
        Socket.SendResult;
      end;
    end;
end;

end.
