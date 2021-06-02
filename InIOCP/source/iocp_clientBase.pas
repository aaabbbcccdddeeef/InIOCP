(*
 * InIOCP �ͻ������ӡ������̡߳������̡߳�Ͷ���߳� ��
 *   TInConnection��TInWSConnection �� TBaseConnection �̳�
 *   TInStreamConnection δʵ��
 *)
unit iocp_clientBase;

interface

{$I in_iocp.inc}

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes, System.SysUtils, Vcl.ExtCtrls, {$ELSE}
  Windows, Classes, SysUtils, ExtCtrls, {$ENDIF}
  iocp_base, iocp_baseObjs, iocp_Winsock2, iocp_utils, iocp_wsExt,
  iocp_lists, iocp_msgPacks, iocp_WsJSON, iocp_api,
  iocp_senders, iocp_receivers;

type

  // �̻߳���
  TBaseSendThread = class;
  TBaseRecvThread = class;
  TBasePostThread = class;

  // ��Ϣ�շ��¼�
  TRecvSendEvent = procedure(Sender: TObject; MsgId: TIOCPMsgId;
                             TotalSize, CurrentSize: TFileSize) of object;

  // �쳣�¼�
  TExceptEvent = procedure(Sender: TObject; const Msg: string) of object;

  TBaseConnection = class(TComponent)
  private
    FAutoConnected: Boolean;   // �Ƿ��Զ�����
    FLocalPath: String;        // �����ļ��ı��ش��·��
    FURL: String;              // ������Դ
    FServerAddr: String;       // ��������ַ
    FServerPort: Word;         // ����˿�

    FAfterConnect: TNotifyEvent;     // ���Ӻ�
    FAfterDisconnect: TNotifyEvent;  // �Ͽ���
    FBeforeConnect: TNotifyEvent;    // ����ǰ
    FBeforeDisconnect: TNotifyEvent; // �Ͽ�ǰ

    FOnDataReceive: TRecvSendEvent;  // ��Ϣ�����¼�
    FOnDataSend: TRecvSendEvent;     // ��Ϣ�����¼�
    FOnError: TExceptEvent;          // �쳣�¼�

    function GetActive: Boolean;
    function GetURL: String;

    procedure CreateTimer;
    procedure Disconnect;

    procedure InternalOpen;
    procedure InternalClose;
    procedure SetActive(Value: Boolean);
    procedure TimerEvent(Sender: TObject);
  protected
    FSendThread: TBaseSendThread;  // �����߳�
    FRecvThread: TBaseRecvThread;  // �����߳�
    FPostThread: TBasePostThread;  // Ͷ���߳�

    FSocket: TSocket;          // �׽���
    FTimer: TTimer;            // ��ʱ��

    FActive: Boolean;          // ����/����״̬
    FErrorcode: Integer;       // �쳣����
    FInitFlag: AnsiString;     // ��ʼ������˵��ַ���
    FInMainThread: Boolean;    // �������߳�
    FRecvCount: Cardinal;      // �յ�����
    FSendCount: Cardinal;      // ��������
    procedure Loaded; override;
  protected
    procedure DoClientError;
    procedure DoServerError; virtual; abstract;
    procedure InterBeforeConnect; virtual; abstract;
    procedure InterAfterConnect; virtual; abstract;  // �����ʼ����Դ
    procedure InterAfterDisconnect; virtual; abstract;  // �����ͷ���Դ
    procedure RecvMsgProgress; virtual;
    procedure SendMsgProgress; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  protected    
    property URL: String read GetURL write FURL;
  public
    property Errorcode: Integer read FErrorcode;
    property PostThread: TBasePostThread read FPostThread;
    property RecvCount: Cardinal read FRecvCount;
    property SendCount: Cardinal read FSendCount;
    property SendThread: TBaseSendThread read FSendThread;
    property Socket: TSocket read FSocket;
  published
    property Active: Boolean read GetActive write SetActive default False;
    property AutoConnected: Boolean read FAutoConnected write FAutoConnected default False;
    property LocalPath: string read FLocalPath write FLocalPath;
    property ServerAddr: string read FServerAddr write FServerAddr;
    property ServerPort: Word read FServerPort write FServerPort default DEFAULT_SVC_PORT;
  published
    property AfterConnect: TNotifyEvent read FAfterConnect write FAfterConnect;
    property AfterDisconnect: TNotifyEvent read FAfterDisconnect write FAfterDisconnect;
    property BeforeConnect: TNotifyEvent read FBeforeConnect write FBeforeConnect;
    property BeforeDisconnect: TNotifyEvent read FBeforeDisconnect write FBeforeDisconnect;

    property OnDataReceive: TRecvSendEvent read FOnDataReceive write FOnDataReceive;
    property OnDataSend: TRecvSendEvent read FOnDataSend write FOnDataSend;
    property OnError: TExceptEvent read FOnError write FOnError;
  end;

  // =================== �����߳� �� ===================

  // ��Ϣ�������
  TMsgIdArray = array of TIOCPMsgId;

  TBaseSendThread = class(TCycleThread)
  private
    FLock: TThreadLock;        // �߳���
    FMsgList: TInList;         // ������Ϣ���б�
    FCancelIds: TMsgIdArray;   // �ֿ鴫��ʱ��ȡ������Ϣ�������
    FEventMode: Boolean;       // �ȴ��¼�ģʽ
    
    FGetFeedback: Integer;     // �յ�����������
    FWaitState: Integer;       // �ȴ�����״̬
    FWaitSemaphore: THandle;   // �ȴ��������������źŵ�

    function ClearList: Integer;
    function GetCount: Integer;
    function GetWork: Boolean;

    procedure AddCancelMsgId(MsgId: TIOCPMsgId);
    procedure ClearCancelMsgId(MsgId: TIOCPMsgId);
  protected
    FConnection: TBaseConnection; // ����
    FPostThread: TBasePostThread; // �ύ�߳�

    FSender: TClientTaskSender;   // ��Ϣ������
    FSendMsg: TBasePackObject;    // ��ǰ������Ϣ

    FSendCount: TFileSize;        // ��ǰ������
    FTotalSize: TFileSize;        // ��ǰ��Ϣ�ܳ���

    function GetWorkState: Boolean;
    function InCancelArray(MsgId: TIOCPMsgId): Boolean;

    procedure AfterWork; override;
    procedure DoThreadMethod; override;

    procedure IniWaitState;
    procedure KeepWaiting;
    procedure WaitForFeedback;

    procedure OnDataSend(Msg: TBasePackObject; Part: TMessagePart; OutSize: Integer);
    procedure OnSendError(IOType: TIODataType; ErrorCode: Integer);
  protected
    function ChunkRequest(Msg: TBasePackObject): Boolean; virtual;
    procedure InterSendMsg(RecvThread: TBaseRecvThread); virtual; abstract;
  public
    constructor Create(AConnection: TBaseConnection; EventMode: Boolean);
    procedure AddWork(Msg: TBasePackObject); virtual;
    procedure CancelWork(MsgId: TIOCPMsgId);
    procedure ClearAllWorks(var ACount: Integer);
    procedure ServerFeedback(Accept: Boolean = False); virtual;
  public
    property Count: Integer read GetCount;
  end;

  // ================= ���ͽ�����߳� �� ===============
  // ������յ�����Ϣ���б���һ����Ӧ�ò�

  TBasePostThread = class(TCycleThread)
  protected
    FConnection: TBaseConnection;  // ����
    FSendThread: TBaseSendThread;  // �����߳�
    FLock: TThreadLock;            // �߳���
    FMsgList: TInList;             // �յ�����Ϣ�б�
    FSendMsg: TBasePackObject;     // �����̵߳ĵ�ǰ��Ϣ
    procedure AfterWork; override;
    procedure DoThreadMethod; override;
    procedure SetSendMsg(Msg: TBasePackObject);
  protected
    procedure HandleMessage(Msg: TBasePackObject); virtual; abstract;  // ����ʵ��
  public
    constructor Create(AConnection: TBaseConnection);
    procedure Add(Msg: TBasePackObject); virtual;
  end;

  // =================== �����߳� �� ===================

  TBaseRecvThread = class(TThread)
  protected
    FConnection: TBaseConnection; // ����
    FOverlapped: TOverlapped;     // �ص��ṹ
    FRecvBuf: TWsaBuf;            // ���ջ���

    FReceiver: TBaseReceiver;     // ���ݽ�����
    FRecvMsg: TBasePackObject;    // ��ǰ�Ľ�����Ϣ

    FRecvCount: TFileSize;        // ��ǰ������
    FTotalSize: TFileSize;        // ��ǰ��Ϣ�ܳ���
  protected
    procedure Execute; override;
    procedure HandleDataPacket; virtual;  // ������Ϣ����
    procedure OnCreateMsgObject(Msg: TBasePackObject);
    procedure OnDataReceive(Msg: TBasePackObject; Part: TMessagePart; RecvCount: Cardinal); virtual;
    procedure OnRecvError(Msg: TBasePackObject; ErrorCode: Integer);
  public
    constructor Create(AConnection: TBaseConnection; AReceiver: TBaseReceiver);
    procedure Stop;
  end;

const
  ERR_SEND_DATA   = -1;    // �ͻ��ˣ������쳣
  ERR_USER_CANCEL = -2;    // �ͻ��ˣ��û�ȡ������
  ERR_NO_ANWSER   = -3;    // �ͻ��ˣ���������Ӧ��.
  ERR_CHECK_CODE  = -4;    // �ͻ��ˣ������쳣.

implementation

{ TBaseConnection }

constructor TBaseConnection.Create(AOwner: TComponent);
begin
  inherited;
  FSocket := INVALID_SOCKET;  // ��Ч Socket
  FServerPort := DEFAULT_SVC_PORT;  // Ĭ�϶˿�
end;

procedure TBaseConnection.CreateTimer;
begin
  // ����ʱ��(�ر������ã�
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 50;
  FTimer.OnTimer := TimerEvent;
end;

destructor TBaseConnection.Destroy;
begin
  SetActive(False);
  inherited;
end;

procedure TBaseConnection.Disconnect;
begin
  // ���Թرտͻ���
  if Assigned(FTimer) then
    FTimer.Enabled := True;
end;

procedure TBaseConnection.DoClientError;
begin
  // ���������쳣 -> �Ͽ�
  try
    if Assigned(OnError) then
      case FErrorCode of
        ERR_SEND_DATA:
          OnError(Self, '�����쳣.');
        ERR_USER_CANCEL:
          OnError(Self, '�û�ȡ������.');
        ERR_NO_ANWSER:
          OnError(Self, '��������Ӧ��.');
        ERR_CHECK_CODE:
          OnError(Self, '���������쳣.');        
        else
          OnError(Self, GetWSAErrorMessage(FErrorCode));
      end;
  finally
    Disconnect;  // �Զ��Ͽ�
  end;
end;

function TBaseConnection.GetActive: Boolean;
begin
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then
    Result := FActive
  else
    Result := (FSocket <> INVALID_SOCKET) and FActive;
end;

function TBaseConnection.GetURL: String;
begin
  if (FURL = '') or (FURL = '/') then
    Result := '/'
  else
  if (FURL[1] <> '/') then
    Result := '/' + FURL
  else
    Result := FURL;
end;

procedure TBaseConnection.InternalClose;
begin
  // �Ͽ�����
  if Assigned(FBeforeDisConnect) and not (csDestroying in ComponentState) then
    FBeforeDisConnect(Self);

  if (FSocket <> INVALID_SOCKET) then
  begin
    // �ر� Socket
    FActive := False;
    try
      iocp_Winsock2.ShutDown(FSocket, SD_BOTH);
      iocp_Winsock2.CloseSocket(FSocket);
    finally
      FSocket := INVALID_SOCKET;
    end;

    // �Ͽ����ͷ�������Դ
    InterAfterDisconnect;

    // �ͷŽ����߳�
    if Assigned(FRecvThread) then
    begin
      FRecvThread.Stop;  // 100 ������˳�
      FRecvThread := nil;
    end;

    // �ͷ�Ͷ���߳�
    if Assigned(FPostThread) then
    begin
      FPostThread.Stop;
      FPostThread := nil;
    end;

    // �ͷŷ����߳�
    if Assigned(FSendThread) then
    begin
      FSendThread.ServerFeedback;
      FSendThread.Stop;
      FSendThread := nil;
    end;

    // �ͷŶ�ʱ��
    if Assigned(FTimer) then
    begin
      FTimer.Free;
      FTimer := nil;
    end;
  end;

  if Assigned(FAfterDisconnect) and not (csDestroying in ComponentState) then
    FAfterDisconnect(Self);

end;

procedure TBaseConnection.InternalOpen;
begin
  // ���� WSASocket�����ӵ�������
  if Assigned(FBeforeConnect) and not (csDestroying in ComponentState) then
    FBeforeConnect(Self);

  FActive := False;
  if (FSocket = INVALID_SOCKET) then
  begin
    // ׼�� FInitFlag
    InterBeforeConnect;

    // �� Socket
    FSocket := iocp_Winsock2.WSASocket(AF_INET, SOCK_STREAM,
                                       IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);

    if iocp_utils.ConnectSocket(FSocket, FServerAddr, FServerPort) then  // ���ӳɹ�
    begin
      // ��ʱ��
      CreateTimer;

      // ����
      iocp_wsExt.SetKeepAlive(FSocket);

      if (FInitFlag <> '') then  // ���Ϳͻ��˱�־ FInitFlag�������ת��/׼����Դ
        iocp_Winsock2.Send(FSocket, FInitFlag[1], Length(FInitFlag), 0);

      // ���ӣ�������Դ���ύ�߳������ཨ��
      InterAfterConnect;

      FSendThread.FPostThread := FPostThread;
      FPostThread.FSendThread := FSendThread;

      FActive := True;  // ����
      FRecvCount := 0;  // ������
      FSendCount := 0;  // ������
    end else
      try
        iocp_Winsock2.ShutDown(FSocket, SD_BOTH);
        iocp_Winsock2.CloseSocket(FSocket);
      finally
        FSocket := INVALID_SOCKET;
      end;
  end;

  if not (csDestroying in ComponentState) then
    if FActive then
    begin
      if Assigned(FAfterConnect) then
        FAfterConnect(Self);
    end else
    if Assigned(FOnError) then
      FOnError(Self, '�޷����ӵ�������.');

end;

procedure TBaseConnection.Loaded;
begin
  inherited;
  // ������ʱ FActive = True��װ�غ� -> ����
  if FActive and not (csDesigning in ComponentState) then
    InternalOpen;
end;

procedure TBaseConnection.RecvMsgProgress;
begin
  // ��ʾ���ս���
  if Assigned(FOnDataReceive) then
    try
      FOnDataReceive(Self, FRecvThread.FRecvMsg.MsgId,
                     FRecvThread.FTotalSize, FRecvThread.FRecvCount);
    except
      raise;
    end;
end;

procedure TBaseConnection.SendMsgProgress;
begin
  // ��ʾ���ͽ��̣����塢������һ�� 100%��
  if Assigned(FOnDataSend) then
    try
      FOnDataSend(Self, FSendThread.FSendMsg.MsgId,
                  FSendThread.FTotalSize, FSendThread.FSendCount);
    except
      raise;
    end;
end;

procedure TBaseConnection.SetActive(Value: Boolean);
begin
  if Value <> FActive then
    if (csDesigning in ComponentState) or (csLoading in ComponentState) then
      FActive := Value
    else
    if Value and not FActive then
      InternalOpen
    else
    if not Value and FActive then
    begin
      if FInMainThread then  // �������߳�����
        FTimer.Enabled := True
      else
        InternalClose;
    end;
end;

procedure TBaseConnection.TimerEvent(Sender: TObject);
begin
  FTimer.Enabled := False;
  InternalClose;  // �Ͽ�����
end;

{ TBaseSendThread }

procedure TBaseSendThread.AddCancelMsgId(MsgId: TIOCPMsgId);
var
  i: Integer;
  Exists: Boolean;
begin
  // �����ȡ������Ϣ��� MsgId
  Exists := False;
  if (FCancelIds <> nil) then
    for i := 0 to High(FCancelIds) do
      if (FCancelIds[i] = MsgId) then
      begin
        Exists := True;
        Break;
      end;
  if (Exists = False) then
  begin
    SetLength(FCancelIds, Length(FCancelIds) + 1);
    FCancelIds[High(FCancelIds)] := MsgId;
  end;
end;

procedure TBaseSendThread.AddWork(Msg: TBasePackObject);
begin
  FLock.Acquire;
  try
    FMsgList.Add(Msg);
  finally
    FLock.Release;
  end;
  Activate;  // �����߳�
end;

procedure TBaseSendThread.AfterWork;
begin
  inherited;
  // �ͷ���Դ
  CloseHandle(FWaitSemaphore);
  ClearList;
  FLock.Free;
  FMsgList.Free;
  FSender.Free;
end;

procedure TBaseSendThread.CancelWork(MsgId: TIOCPMsgId);
var
  i, k: Integer;
  Msg: TBasePackObject;
begin
  // ȡ�����ͣ���� = MsgId
  FLock.Acquire;
  try
    if Assigned(FSendMsg) and
      ChunkRequest(FSendMsg) and (FSendMsg.MsgId = MsgId) then
    begin
      FSender.Stoped := True;
      ServerFeedback;
    end else
    begin
      k := FMsgList.Count;
      for i := 0 to k - 1 do
      begin
        Msg := TBasePackObject(FMsgList.PopFirst);
        if (Msg.MsgId = MsgId) then
          Msg.Free
        else  // ���¼���
          FMsgList.Add(Msg);
      end;
      if (k = FMsgList.Count) then  // ����������
        AddCancelMsgId(MsgId);
    end;
  finally
    FLock.Release;
  end;
end;

function TBaseSendThread.ChunkRequest(Msg: TBasePackObject): Boolean;
begin
  Result := False;
end;

procedure TBaseSendThread.ClearAllWorks(var ACount: Integer);
begin
  // ��մ�����Ϣ
  FLock.Acquire;
  try
    ACount := ClearList;  // ȡ������
  finally
    FLock.Release;
  end;
end;

procedure TBaseSendThread.ClearCancelMsgId(MsgId: TIOCPMsgId);
var
  i: Integer;
begin
  // ��������ڵ���Ϣ��� MsgId
  if (FCancelIds <> nil) then
    for i := 0 to High(FCancelIds) do
      if (FCancelIds[i] = MsgId) then
      begin
        FCancelIds[i] := 0;  // ���
        Break;
      end;
end;

function TBaseSendThread.ClearList: Integer;
var
  i: Integer;
begin
  // �ͷ��б��ȫ����Ϣ�����������
  Result := FMsgList.Count;
  for i := 0 to Result - 1 do
    TBasePackObject(FMsgList.PopFirst).Free;
end;

constructor TBaseSendThread.Create(AConnection: TBaseConnection; EventMode: Boolean);
begin
  inherited Create(True);  // �����źŵ�
  FConnection := AConnection;
  FEventMode := EventMode;

  FLock := TThreadLock.Create; // ��
  FMsgList := TInList.Create;  // ���������
  FSender := TClientTaskSender.Create;   // ��������

  FSender.Socket := FConnection.FSocket; // �����׽���
  FSender.OnDataSend := OnDataSend;      // �����¼�
  FSender.OnError := OnSendError;        // �����쳣�¼�

  // �źŵ�
  FWaitSemaphore := CreateSemaphore(Nil, 0, 1, Nil);
end;

procedure TBaseSendThread.DoThreadMethod;
  function NoServerFeedback: Boolean;
  begin
    {$IFDEF ANDROID_MODE}
    FLock.Acquire;
    try
      Dec(FGetFeedback);
      Result := (FGetFeedback < 0);
    finally
      FLock.Release;
    end;
    {$ELSE}
    Result := (InterlockedDecrement(FGetFeedback) < 0);
    {$ENDIF}
  end;
begin
  // ȡ�������� -> ����
  while not Terminated and FConnection.FActive and GetWork() do
    try
      try
        FPostThread.SetSendMsg(FSendMsg);
        InterSendMsg(FConnection.FRecvThread);  // �����෢��
      finally
        FLock.Acquire;
        try
          FreeAndNil(FSendMsg);  // ��Ҫ�������ͷ�
        finally
          FLock.Release;
        end;
        if FEventMode and NoServerFeedback() then // �ȴ��¼�ģʽ, ��������Ӧ��
        begin
          FConnection.FErrorcode := ERR_NO_ANWSER;
          Synchronize(FConnection.DoClientError);
        end;
      end;
    except
      on E: Exception do
      begin
        FConnection.FErrorcode := GetLastError;
        Synchronize(FConnection.DoClientError);
      end;
    end;
end;

function TBaseSendThread.GetCount: Integer;
begin
  // ȡ������
  FLock.Acquire;
  try
    Result := FMsgList.Count;
  finally
    FLock.Release;
  end;
end;

function TBaseSendThread.GetWork: Boolean;
begin
  // ���б���ȡһ����Ϣ
  FLock.Acquire;
  try
    if Terminated or (FMsgList.Count = 0) then
    begin
      FSendMsg := nil;
      Result := False;
    end else
    begin
      FSendMsg := TBasePackObject(FMsgList.PopFirst);  // ȡ����
      FSender.Stoped := False;
      Result := True;
    end;
  finally
    FLock.Release;
  end;
end;

function TBaseSendThread.GetWorkState: Boolean;
begin
  // ȡ����״̬���̡߳�������δֹͣ
  FLock.Acquire;
  try
    Result := (Terminated = False) and (FSender.Stoped = False);
  finally
    FLock.Release;
  end;
end;

function TBaseSendThread.InCancelArray(MsgId: TIOCPMsgId): Boolean;
var
  i: Integer;
begin
  // ����Ƿ�Ҫֹͣ
  FLock.Acquire;
  try
    Result := False;
    if (FCancelIds <> nil) then
      for i := 0 to High(FCancelIds) do
        if (FCancelIds[i] = MsgId) then
        begin
          Result := True;
          Break;
        end;
  finally
    FLock.Release;
  end;
end;

procedure TBaseSendThread.IniWaitState;
begin
  // ��ʼ���ȴ�״̬
  {$IFDEF ANDROID_MODE}
  FLock.Acquire;
  try
    FGetFeedback := 0;
    FWaitState := 0;
  finally
    FLock.Release;
  end;
  {$ELSE}
  InterlockedExchange(FGetFeedback, 0); // δ�յ�����
  InterlockedExchange(FWaitState, 0); // ״̬=0
  {$ENDIF}
end;

procedure TBaseSendThread.KeepWaiting;
begin
  // �����ȴ�: FWaitState = 1 -> +1
  {$IFDEF ANDROID_MODE}
  FLock.Acquire;
  try
    Inc(FGetFeedback);
    if (FWaitState = 2) then
    begin
      FWaitState := 1;
      ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // ����
    end;
  finally
    FLock.Release;
  end;
  {$ELSE}
  InterlockedIncrement(FGetFeedback); // �յ�����
  if (iocp_api.InterlockedCompareExchange(FWaitState, 2, 1) = 1) then  // ״̬+
    ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // ����
  {$ENDIF}
end;

procedure TBaseSendThread.OnDataSend(Msg: TBasePackObject; Part: TMessagePart; OutSize: Integer);
begin
  // ��ʾ���ͽ���
  Inc(FSendCount, OutSize);
  Synchronize(FConnection.SendMsgProgress);
end;

procedure TBaseSendThread.OnSendError(IOType: TIODataType; ErrorCode: Integer);
begin
  // �������쳣
  if (GetWorkState = False) then  
    ServerFeedback;  // ���Եȴ�
  FConnection.FErrorcode := ErrorCode;
  Synchronize(FConnection.DoClientError); // �߳�ͬ��
end;

procedure TBaseSendThread.ServerFeedback(Accept: Boolean);
begin
  // ���������� �� ���Եȴ�
  //  1. ȡ��������յ�����
  //  2. �յ���������δ�ȴ�
  //   �����̵߳ĵ���ִ���Ⱥ�ȷ���������Ѿ���������δִ�е��ȴ����
  {$IFDEF ANDROID_MODE}
  FLock.Acquire;
  try
    Inc(FGetFeedback);    // +1
    Dec(FWaitState);      // 0->-1
    if (FWaitState = 0) then
      ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // �ź���+1
  finally
    FLock.Release;
  end;
  {$ELSE}
  InterlockedIncrement(FGetFeedback); // �յ����� +
  if (InterlockedDecrement(FWaitState) = 0) then
    ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // �ź���+1
  {$ENDIF}
end;

procedure TBaseSendThread.WaitForFeedback;
  {$IFDEF ANDROID_MODE}
  function LockedGetWaitState(IncOper: Boolean): Integer;
  begin
    FLock.Acquire;
    try
      if IncOper then  // +
        Inc(FWaitState)  // 1: δ�������ȴ�; 0���Ѿ��յ�����
      else  // -
        Dec(FWaitState);
      Result := FWaitState;
    finally
      FLock.Release;
    end;
  end;
  {$ENDIF}
begin
  // �ȷ������������� WAIT_MILLISECONDS ����
  {$IFDEF ANDROID_MODE}
  if (LockedGetWaitState(True) = 1) then
    repeat
      WaitForSingleObject(FWaitSemaphore, WAIT_MILLISECONDS);
    until (LockedGetWaitState(False) <= 0);
  {$ELSE}
  if (InterlockedIncrement(FWaitState) = 1) then
    repeat
      WaitForSingleObject(FWaitSemaphore, WAIT_MILLISECONDS);
    until (InterlockedDecrement(FWaitState) <= 0);
  {$ENDIF}
end;

{ TBasePostThread }

procedure TBasePostThread.Add(Msg: TBasePackObject);
begin
  // ������Ϣ���б�
  FLock.Acquire;
  try
    FMsgList.Add(Msg);
  finally
    FLock.Release;
  end;
  Activate;  // ����
end;

procedure TBasePostThread.AfterWork;
var
  i: Integer;
begin
  // �����Ϣ
  for i := 0 to FMsgList.Count - 1 do
    TBasePackObject(FMsgList.PopFirst).Free;
  FLock.Free;
  FMsgList.Free;
  inherited;
end;

constructor TBasePostThread.Create(AConnection: TBaseConnection);
begin
  inherited Create(True);      // �����źŵ�
  FConnection := AConnection;
  FLock := TThreadLock.Create; // ��
  FMsgList := TInList.Create;  // �յ�����Ϣ�б�
end;

procedure TBasePostThread.DoThreadMethod;
var
  Msg: TBasePackObject;
begin
  // ѭ�������յ�����Ϣ
  while (Terminated = False) do
  begin
    FLock.Acquire;
    try
      Msg := TBasePackObject(FMsgList.PopFirst);  // ȡ����һ��
    finally
      FLock.Release;
    end;
    if not Assigned(Msg) then  // ����
      Break;
    if FSendThread.InCancelArray(Msg.MsgId) then  // �����û�ȡ��
    begin
      Msg.Free;
      FSendThread.ServerFeedback;
    end else
      HandleMessage(Msg);  // ����ҵ���
  end;
end;

procedure TBasePostThread.SetSendMsg(Msg: TBasePackObject);
begin
  FLock.Acquire;
  try
    FSendMsg := Msg;
  finally
    FLock.Release;
  end;
end;

{ TBaseRecvThread }

// �� WSARecv �ص������������ݣ�Ч�ʸ�

procedure WorkerRoutine(const dwError, cbTransferred: DWORD;
  const lpOverlapped: POverlapped; const dwFlags: DWORD); stdcall;
var
  Thread: TBaseRecvThread;
  Connection: TBaseConnection;
  ByteCount, Flags: DWORD;
  ErrorCode: Cardinal;
begin
  // �������߳� ��
  // ����� lpOverlapped^.hEvent = TRecvThread

  if (dwError <> 0) then       // �����쳣����رա��Ͽ�
    lpOverlapped^.hEvent := 0  // ��Ϊ��Ч -> ���Ӽ����Ͽ�
  else
  if (cbTransferred > 0) then
  begin
    // ������
    // HTTP.SYS-WebSocket��������
    Thread := TBaseRecvThread(lpOverlapped^.hEvent);
    Connection := Thread.FConnection;

    try
      // ����һ�����ݰ�
      Thread.HandleDataPacket;
    finally
      // ����ִ�� WSARecv���ȴ�����
      FillChar(lpOverlapped^, SizeOf(TOverlapped), 0);
      lpOverlapped^.hEvent := DWORD(Thread);  // �����Լ�

      ByteCount := 0;
      Flags := 0;

      // �յ�����ʱִ�� WorkerRoutine
      if (iocp_Winsock2.WSARecv(Connection.FSocket, @Thread.FRecvBuf, 1,
          ByteCount, Flags, LPWSAOVERLAPPED(lpOverlapped), @WorkerRoutine) = SOCKET_ERROR) then
      begin
        ErrorCode := WSAGetLastError;
        if (ErrorCode <> WSA_IO_PENDING) then
        begin
          Connection.FErrorcode := ErrorCode;
          Thread.Synchronize(Connection.DoClientError); // �߳�ͬ��
        end;
      end;
    end;
  end;
end;

constructor TBaseRecvThread.Create(AConnection: TBaseConnection; AReceiver: TBaseReceiver);
begin
  inherited Create(True);
  FConnection := AConnection;
  FReceiver := AReceiver;

  // ������ջ��棨�������߳� Execute �з��䣩
  GetMem(FRecvBuf.buf, IO_BUFFER_SIZE_2);
  FRecvBuf.len := IO_BUFFER_SIZE_2;
  
  FreeOnTerminate := True;
end;

procedure TBaseRecvThread.Execute;
var
  ByteCount, Flags: DWORD;
begin
  // ִ�� WSARecv���ȴ�����
  try
    FillChar(FOverlapped, SizeOf(TOverlapped), 0);
    FOverlapped.hEvent := DWORD(Self);  // �����Լ�

    ByteCount := 0;
    Flags := 0;

    // �����ݴ���ʱ����ϵͳ�Զ�����ִ�� WorkerRoutine
    iocp_Winsock2.WSARecv(FConnection.FSocket, @FRecvBuf, 1,
                          ByteCount, Flags, @FOverlapped, @WorkerRoutine);

    while not Terminated and (FOverlapped.hEvent > 0) do
      if (SleepEx(80, True) = WAIT_IO_COMPLETION) then  // �����������ȴ�ģʽ
        { Empty } ;
  finally
    if FConnection.FActive and (FOverlapped.hEvent = 0) then
      Synchronize(FConnection.Disconnect);  // �Ͽ�
    FreeMem(FRecvBuf.buf);  // �ͷ���Դ
    FreeAndNil(FReceiver);
  end;
end;

procedure TBaseRecvThread.HandleDataPacket;
begin
  // �����ֽ�����
  Inc(FConnection.FRecvCount, FOverlapped.InternalHigh);
end;

procedure TBaseRecvThread.OnCreateMsgObject(Msg: TBasePackObject);
begin
  // ׼���µ���Ϣ
  FRecvMsg := Msg;
  FRecvCount := 0;
  FTotalSize := 0;
end;

procedure TBaseRecvThread.OnDataReceive(Msg: TBasePackObject; Part: TMessagePart; RecvCount: Cardinal);
begin
  Synchronize(FConnection.RecvMsgProgress);
end;

procedure TBaseRecvThread.OnRecvError(Msg: TBasePackObject; ErrorCode: Integer);
begin
  // ����У���쳣
  FConnection.FErrorcode := ErrorCode;
  Synchronize(FConnection.DoClientError);
end;

procedure TBaseRecvThread.Stop;
begin
  if Assigned(FReceiver) then  // �������ر�ʱ�������߳��Ѿ�ֹͣ
    Terminate;
  while Assigned(FReceiver) do
    Sleep(10);
end;

end.
