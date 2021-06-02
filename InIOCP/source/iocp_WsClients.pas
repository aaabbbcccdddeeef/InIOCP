(*
 * InIOCP WebSocket Э��ͻ��˵�Ԫ
 *
 *)
unit iocp_wsClients;

interface

{$I in_iocp.inc}

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes, System.SysUtils, Vcl.ExtCtrls,
  System.Variants, Datasnap.DSIntf, Datasnap.DBClient, {$ELSE}
  Windows, Classes, SysUtils, ExtCtrls,
  Variants, DSIntf, DBClient, {$ENDIF}
  iocp_Winsock2, iocp_base, iocp_lists, iocp_senders,
  iocp_receivers, iocp_baseObjs, iocp_utils, iocp_wsExt,
  iocp_msgPacks, iocp_clientBase, iocp_WsJSON;

type

  // ============ WebSocket �ͻ��� �� ============

  TSendThread  = class;
  TRecvThread  = class;
  TPostThread  = class;

  TJSONMessage = class;
  TJSONResult  = class;

  // ============ �ͻ������� ============

  // ���������¼�
  TAddWorkEvent = procedure(Sender: TObject; Msg: TJSONMessage) of object;
  
  // ���ձ�׼ WebSocket �����¼�������Ϣ��װ��
  TReceiveData  = procedure(Sender: TObject; const Msg: String) of object;

  // �������յ� JSON
  TPassvieEvent = procedure(Sender: TObject; Msg: TJSONResult) of object;

  // ��������¼�
  TReturnEvent  = procedure(Sender: TObject; Result: TJSONResult) of object;

  TInWSConnection = class(TBaseConnection)
  private
    FMasking: Boolean;         // ʹ������
    FJSON: TJSONMessage;       // ���� JSON ��Ϣ

    FOnAddWork: TAddWorkEvent;     // ���������¼�
    FOnReceiveData: TReceiveData;  // �յ��޷�װ������
    FOnReceiveMsg: TPassvieEvent;  // ����������Ϣ�¼�
    FOnReturnResult: TReturnEvent; // ������ֵ�¼�
  private
    function GetJSON: TJSONMessage;
    procedure HandlePushedData(Stream: TMemoryStream);
    procedure HandlePushedMsg(Msg: TJSONResult);
    procedure HandleReturnMsg(Result: TJSONResult);
    procedure ReceiveAttachment;
  protected
    procedure InterBeforeConnect; override;
    procedure InterAfterConnect; override;  // ��ʼ����Դ
    procedure InterAfterDisconnect; override;  // �ͷ���Դ
  public
    constructor Create(AOwner: TComponent); override;
  public
    property JSON: TJSONMessage read GetJSON;
  published
    property Masking: Boolean read FMasking write FMasking default False;
    property URL;
  published
    property OnAddWork: TAddWorkEvent read FOnAddWork write FOnAddWork;
    property OnReceiveData: TReceiveData read FOnReceiveData write FOnReceiveData;  // ������Ϣ
    property OnReceiveMsg: TPassvieEvent read FOnReceiveMsg write FOnReceiveMsg;
    property OnReturnResult: TReturnEvent read FOnReturnResult write FOnReturnResult;
  end;

  // ============ �û����͵� JSON ��Ϣ�� ============

  TJSONMessage = class(TSendJSON)
  public
    constructor Create(AOwner: TInWSConnection);
    procedure Post;
    procedure SetRemoteTable(DataSet: TClientDataSet; const TableName: String);
  end;

  // ============ �ͻ����յ��� JSON ��Ϣ�� ============

  TJSONResult = class(TBaseJSON)
  protected
    FOpCode: TWSOpCode;         // �������ͣ��رգ�
    FMsgType: TWSMsgType;       // ��������
    FStream: TMemoryStream;     // �� InIOCP-JSON ��ԭʼ������
  public
    destructor Destroy; override;
    property MsgType: TWSMsgType read FMsgType;
  end;

  // =================== �����߳� �� ===================

  TSendThread = class(TBaseSendThread)
  private
    FMsgPack: TJSONMessage;   // ��ǰ������Ϣ��
  protected
    procedure InterSendMsg(RecvThread: TBaseRecvThread); override;
  public
    procedure AddWork(Msg: TBasePackObject); override;
  end;

  // =================== ���ͽ�����߳� �� ===================
  // ������յ�����Ϣ���б���һ����Ӧ�ò�

  TPostThread = class(TBasePostThread)
  private
    FMsg: TJSONResult;         // ���б�ȡ������Ϣ
    procedure DoInMainThread;
  protected
    procedure HandleMessage(Msg: TBasePackObject); override;
  end;

  // =================== �����߳� �� ===================

  TRecvThread = class(TBaseRecvThread)
  private
    procedure CheckUpgradeState(Buf: PAnsiChar; Len: Integer);
    procedure OnAttachment(Msg: TBaseJSON);
  protected
    procedure HandleDataPacket; override; // �����յ������ݰ�
    procedure OnDataReceive(Msg: TBasePackObject; Part: TMessagePart; RecvCount: Cardinal); override;
  public
    constructor Create(AConnection: TInWSConnection);
  end;

implementation

uses
  http_base;

{ TInWSConnection }

constructor TInWSConnection.Create(AOwner: TComponent);
begin
  inherited;
end;

function TInWSConnection.GetJSON: TJSONMessage;
begin
  if FActive then
  begin
    if (FJSON = nil) then
      FJSON := TJSONMessage.Create(Self);
    Result := FJSON;
  end else
    Result := nil;
end;

procedure TInWSConnection.HandlePushedData(Stream: TMemoryStream);
var
  Msg: AnsiString;
begin
  // ��ʾδ��װ������
  if Assigned(FOnReceiveData) then
  begin
    SetString(Msg, PAnsiChar(Stream.Memory), Stream.Size);
    Msg := System.Utf8ToAnsi(Msg);
    FOnReceiveData(Self, Msg);
  end;
end;

procedure TInWSConnection.HandlePushedMsg(Msg: TJSONResult);
begin
  // ���������յ� JSON ��Ϣ
  if Assigned(FOnReceiveMsg) then
    FOnReceiveMsg(Self, Msg);
end;

procedure TInWSConnection.HandleReturnMsg(Result: TJSONResult);
begin
  // �������˷����� JSON ��Ϣ
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, Result);
end;

procedure TInWSConnection.InterAfterConnect;
begin
  // �Ѿ����ӳɹ�
  // ���������̣߳���ǰ��
  FSendThread := TSendThread.Create(Self, False);
  FSendThread.Resume;

  // �ύ��Ϣ�߳�
  FPostThread := TPostThread.Create(Self);
  FPostThread.Resume;

  // ���������̣߳��ں�
  FRecvThread := TRecvThread.Create(Self);
  FRecvThread.Resume;
end;

procedure TInWSConnection.InterAfterDisconnect;
begin
  // �ͷ���Դ: Empty
end;

procedure TInWSConnection.InterBeforeConnect;
begin
  // WebSocket ��������
  FInitFlag := 'GET ' + URL + ' HTTP/1.1'#13#10 +
               'Host: ' + ServerAddr + #13#10 +  // http.sys ����� Host
               'Connection: Upgrade'#13#10 +
               'Upgrade: WebSocket'#13#10 +
               'Sec-WebSocket-Key: w4v7O6xFTi36lq3RNcgctw=='#13#10 +  // �ͻ��˲���ⷵ��KEY���ù̶�ֵ
               'Sec-WebSocket-Version: 13'#13#10 +
               'Origin: InIOCP-WebSocket'#13#10#13#10;
end;

procedure TInWSConnection.ReceiveAttachment;
begin
  // �и�������׼������
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, TRecvThread(FRecvThread).FRecvMsg as TJSONResult);
end;

{ TJSONMessage }

constructor TJSONMessage.Create(AOwner: TInWSConnection);
var
  ErrMsg: String;
begin
  if (AOwner = nil) then  // ����Ϊ nil
    ErrMsg := '��Ϣ Owner ����Ϊ��.'
  else
  if not AOwner.Active then
    ErrMsg := '���� AOwner ������.';

  if (ErrMsg = '') then
    inherited Create(AOwner)
  else
  if Assigned(AOwner.OnError) then
    AOwner.OnError(Self, ErrMsg)
  else
    raise Exception.Create(ErrMsg);

end;

procedure TJSONMessage.Post;
var
  Connection: TInWSConnection;
begin
  Connection := TInWSConnection(FOwner);
  if Assigned(Connection) then
    try
      Connection.FSendThread.AddWork(Self); // �ύ��Ϣ
    finally
      if (Self = Connection.FJSON) then
        Connection.FJSON := nil;  // �� nil
    end;
end;

procedure TJSONMessage.SetRemoteTable(DataSet: TClientDataSet; const TableName: String);
begin
  DataSet.SetOptionalParam(szTABLE_NAME, TableName, True); // �������ݱ�
end;

{ TJSONResult }

destructor TJSONResult.Destroy;
begin
  if Assigned(FStream) then
    FStream.Free;  
  inherited;
end;

{ TSendThread }

procedure TSendThread.AddWork(Msg: TBasePackObject);
begin
  // ����Ϣ�������б�
  if Assigned(TInWSConnection(FConnection).FOnAddWork) then
    TInWSConnection(FConnection).FOnAddWork(Self, TJSONMessage(Msg));
  inherited;
end;

procedure TSendThread.InterSendMsg(RecvThread: TBaseRecvThread);
begin
  // ִ�з�������, �����˷������ƣ�����˿����������Ͷ�����ݣ����ܵȴ�
  //   ����TReturnResult.ReturnResult��TDataReceiver.Prepare
  FMsgPack := TJSONMessage(FSendMsg);
  FSender.Owner := FMsgPack;  // ����
  FTotalSize := FMsgPack.Size;
  FMsgPack.InternalSend(FSender, TInWSConnection(FConnection).FMasking);
end;

{ TPostThread }

procedure TPostThread.DoInMainThread;
var
  AConnection: TInWSConnection;
begin
  // �������̣߳�����Ϣ�ύ������
  // ���ܴ�����Ϣ�����б��û��Ͽ�����ʱҪ�ı�Ͽ�ģʽ
  AConnection := TInWSConnection(FConnection);
  AConnection.FInMainThread := True;  // �������߳�
  try
    try
      if (FMsg.FOpCode = ocClose) then
        AConnection.FTimer.Enabled := True
      else
      if Assigned(FMsg.FStream) then  // δ��װ������
        AConnection.HandlePushedData(FMsg.FStream)
      else
      if (FMsg.Owner <> AConnection) then  // ����������Ϣ
        AConnection.HandlePushedMsg(FMsg)
      else
        AConnection.HandleReturnMsg(FMsg);  // ����˷������Լ�����Ϣ
     finally
       FMsg.Free;  // ͬʱ�ͷ� FStream
       AConnection.FInMainThread := False;
    end;
  except
    on E: Exception do
    begin
      AConnection.FErrorcode := GetLastError;
      AConnection.DoClientError;  // �����̣߳�ֱ�ӵ���
    end;
  end;
end;

procedure TPostThread.HandleMessage(Msg: TBasePackObject);
begin
  FMsg := TJSONResult(Msg);     // TJSONResult
  Synchronize(DoInMainThread);  // ����ҵ���
end;

{ TRecvThread }

procedure TRecvThread.CheckUpgradeState(Buf: PAnsiChar; Len: Integer);
begin
  // �������������򻯣������ AcceptKey�����ܳ��־ܾ�����ķ�����
  if not MatchSocketType(Buf, 'HTTP/1.1 101') then  // google ����ͬ��HTTP_VER + HTTP_STATES_100[1]
  begin
    TInWSConnection(FConnection).FActive := False;  // ֱ�Ӹ�ֵ
    TInWSConnection(FConnection).FTimer.Enabled := True;
  end;
end;

constructor TRecvThread.Create(AConnection: TInWSConnection);
var
  AReceiver: TWSClientReceiver;
begin
  FRecvMsg := TJSONResult.Create(AConnection);  // ����Ϣ
  AReceiver := TWSClientReceiver.Create(AConnection, TJSONResult(FRecvMsg));

  AReceiver.OnNewMsg := OnCreateMsgObject;
  AReceiver.OnPost := AConnection.PostThread.Add;
  AReceiver.OnReceive := OnDataReceive;
  AReceiver.OnAttachment := OnAttachment;
  AReceiver.OnError := OnRecvError;

  inherited Create(AConnection, AReceiver);
end;

procedure TRecvThread.HandleDataPacket;
begin
  inherited;
  // ������յ������ݰ�
  if FReceiver.Completed then  // 1. �װ�����
  begin
    if MatchSocketType(FRecvBuf.buf, HTTP_VER) then  // HTTP ��Ϣ
      CheckUpgradeState(FRecvBuf.buf, FOverlapped.InternalHigh)
    else
      FReceiver.Prepare(FRecvBuf.buf, FOverlapped.InternalHigh);  // ����
  end else
  begin
    // 2. ��������
    FReceiver.Receive(FRecvBuf.buf, FOverlapped.InternalHigh);
  end;

end;

procedure TRecvThread.OnAttachment(Msg: TBaseJSON);
begin
  // �и�������ͬ�����ÿͻ����ж��Ƿ����
  TJSONResult(FRecvMsg).FMsgType := mtJSON;
  Synchronize(TInWSConnection(FConnection).ReceiveAttachment);
end;

procedure TRecvThread.OnDataReceive(Msg: TBasePackObject; Part: TMessagePart; RecvCount: Cardinal);
begin
  if (FTotalSize = 0) then
    FTotalSize := Msg.Size;
  Inc(FRecvCount, RecvCount);
  inherited;
end; 

end.

