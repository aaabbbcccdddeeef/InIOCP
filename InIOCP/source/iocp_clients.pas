(*
 * iocp c/s ����ͻ��˶�����
 *)
unit iocp_clients;

interface

{$I in_iocp.inc}

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes, System.SysUtils, Vcl.ExtCtrls, System.Variants,
  Data.DB, Datasnap.DSIntf, Datasnap.DBClient, VCL.Forms, {$ELSE}
  Windows, Classes, SysUtils, ExtCtrls, Variants, DB, DSIntf, DBClient, Forms, {$ENDIF}
  iocp_Winsock2, iocp_base, iocp_utils, iocp_lists, iocp_senders, iocp_receivers,
  iocp_baseObjs, iocp_msgPacks, MidasLib;    // ʹ��ʱ��ӵ�Ԫ���� MidasLib��

type

  // =================== IOCP �ͻ��� �� ===================

  TSendThread = class;

  TRecvThread = class;

  TPostThread = class;

  TClientParams = class;

  TResultParams = class;

  // ============ �ͻ������ ���� ============
  // ����ֱ��ʹ��

  // ���������¼�
  TPassvieEvent = procedure(Sender: TObject; Message: TResultParams) of object;

  // ��������¼�
  TReturnEvent = procedure(Sender: TObject; Result: TResultParams) of object;

  TBaseClientObject = class(TComponent)
  protected
    FOnReceiveMsg: TPassvieEvent;   // ����������Ϣ�¼�
    FOnReturnResult: TReturnEvent;  // ������ֵ�¼�
    procedure HandleFeedback(Result: TResultParams); virtual;
    procedure HandlePushedMsg(Msg: TResultParams); virtual;
  published
    property OnReturnResult: TReturnEvent read FOnReturnResult write FOnReturnResult;
  end;

  // ============ �ͻ������� ============

  // ���������¼�
  TAddWorkEvent = procedure(Sender: TObject; Msg: TClientParams) of object;

  // ��Ϣ�շ��¼�
  TRecvSendEvent = procedure(Sender: TObject; MsgId: TIOCPMsgId; MsgSize, CurrentSize: TFileSize) of object;

  // �쳣�¼�
  TConnectionError = procedure(Sender: TObject; const Msg: string) of object;

  TInConnection = class(TBaseClientObject)
  private
    FSocket: TSocket;          // �׽���
    FTimer: TTimer;            // ��ʱ��

    FSendThread: TSendThread;  // �����߳�
    FRecvThread: TRecvThread;  // �����߳�
    FPostThread: TPostThread;  // Ͷ���߳�

    FRecvCount: Cardinal;      // ���յ�
    FSendCount: Cardinal;      // ������

    FLocalPath: string;        // �����ļ��ı��ش��·��
    FUserName: string;         // ��¼���û�����������ã�
    FServerAddr: string;       // ��������ַ
    FServerPort: Word;         // ����˿�

    FActive: Boolean;          // ����/����״̬
    FActResult: TActionResult; // �������������
    FAutoConnected: Boolean;   // �Ƿ��Զ�����
    FCancelCount: Integer;     // ȡ��������
    FLogined: Boolean;         // ��¼״̬
    FMaxChunkSize: Integer;    // ������ÿ������䳤��

    FErrorcode: Integer;       // �쳣����
    FErrMsg: string;           // �쳣��Ϣ

    FReuseSessionId: Boolean;  // ƾ֤���ã�������ʱ,�´����¼��
    FRole: TClientRole;        // Ȩ��
    FSessionId: Cardinal;      // ƾ֤/�Ի��� ID
  private
    FAfterConnect: TNotifyEvent;     // ���Ӻ�
    FAfterDisconnect: TNotifyEvent;  // �Ͽ���
    FBeforeConnect: TNotifyEvent;    // ����ǰ
    FBeforeDisconnect: TNotifyEvent; // �Ͽ�ǰ
    FOnAddWork: TAddWorkEvent;       // ���������¼�
    FOnDataReceive: TRecvSendEvent;  // ��Ϣ�����¼�
    FOnDataSend: TRecvSendEvent;     // ��Ϣ�����¼�
    FOnError: TConnectionError;      // �쳣�¼�
  private
    function GetActive: Boolean;
    procedure CreateTimer;
    procedure DoServerError(Result: TResultParams);
    procedure DoThreadFatalError;
    procedure HandleMsgHead(Result: TResultParams);
    procedure InternalOpen;
    procedure InternalClose;
    procedure ReceiveProgress;
    procedure SendProgress;
    procedure SetActive(Value: Boolean);
    procedure SetMaxChunkSize(Value: Integer);
    procedure TimerEvent(Sender: TObject);
    procedure TryDisconnect;
  protected
    procedure HandleFeedback(Result: TResultParams); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CancelAllWorks;                 // ȡ��ȫ������
    procedure CancelWork(MsgId: TIOCPMsgId);  // ȡ������
    procedure PauseWork(MsgId: TIOCPMsgId);   // ��ͣ����
  public
    property ActResult: TActionResult read FActResult;
    property CancelCount: Integer read FCancelCount;
    property Errorcode: Integer read FErrorcode;
    property Logined: Boolean read FLogined;
    property RecvCount: Cardinal read FRecvCount;
    property SendCount: Cardinal read FSendCount;
    property SessionId: Cardinal read FSessionId;
    property Socket: TSocket read FSocket;
    property UserName: string read FUserName;
  published
    property Active: Boolean read GetActive write SetActive default False;
    property AutoConnected: Boolean read FAutoConnected write FAutoConnected default False;
    property LocalPath: string read FLocalPath write FLocalPath;
    property MaxChunkSize: Integer read FMaxChunkSize write SetMaxChunkSize default MAX_CHUNK_SIZE;
    property ReuseSessionId: Boolean read FReuseSessionId write FReuseSessionId default False;
    property ServerAddr: string read FServerAddr write FServerAddr;
    property ServerPort: Word read FServerPort write FServerPort default DEFAULT_SVC_PORT;
  published
    property AfterConnect: TNotifyEvent read FAfterConnect write FAfterConnect;
    property AfterDisconnect: TNotifyEvent read FAfterDisconnect write FAfterDisconnect;
    property BeforeConnect: TNotifyEvent read FBeforeConnect write FBeforeConnect;
    property BeforeDisconnect: TNotifyEvent read FBeforeDisconnect write FBeforeDisconnect;
    property OnAddWork: TAddWorkEvent read FOnAddWork write FOnAddWork;
    
    // ���ձ�����Ϣ/������Ϣ�¼�
    property OnReceiveMsg: TPassvieEvent read FOnReceiveMsg write FOnReceiveMsg;
    property OnDataReceive: TRecvSendEvent read FOnDataReceive write FOnDataReceive;
    property OnDataSend: TRecvSendEvent read FOnDataSend write FOnDataSend;
    property OnError: TConnectionError read FOnError write FOnError;
  end;

  // ============ �ͻ����յ������ݰ�/������ ============

  TResultParams = class(TReceivePack)
  protected
    procedure CreateAttachment(const ALocalPath: string); override;
  end;

  // ============ TInBaseClient ���õ���Ϣ�� ============

  TClientParams = class(TBaseMessage)
  private
    FConnection: TInConnection;  // ����
    FState: TMessagePackState;   // ״̬
  protected
    function ReadDownloadInf(AResult: TResultParams): Boolean;
    function ReadUploadInf(AResult: TResultParams): Boolean;
    procedure CreateStreams(ClearList: Boolean = True); override;
    procedure ModifyMessageId;
    procedure OpenLocalFile; override;
  public
    // Э��ͷ����
    property Action: TActionType read FAction;
    property ActResult: TActionResult read FActResult;
    property AttachSize: TFileSize read FAttachSize;
    property CheckType: TDataCheckType read FCheckType write FCheckType;  // ��д
    property DataSize: Cardinal read FDataSize;
    property MsgId: TIOCPMsgId read FMsgId write FMsgId;  // �û������޸�
    property Owner: TMessageOwner read FOwner;
    property SessionId: Cardinal read FSessionId;
    property Target: TActionTarget read FTarget;
    property VarCount: Cardinal read FVarCount;
    property ZipLevel: TZipLevel read FZipLevel write FZipLevel;
  public
    // �����������ԣ���д��
    property Connection: Integer read GetConnection write SetConnection;
    property Directory: string read GetDirectory write SetDirectory;
    property FileName: string read GetFileName write SetFileName;
    property FunctionGroup: string read GetFunctionGroup write SetFunctionGroup;
    property FunctionIndex: Integer read GetFunctionIndex write SetFunctionIndex;
    property HasParams: Boolean read GetHasParams write SetHasParams;
    property LocalPath: string read GetLocalPath write SetLocalPath;
    property NewFileName: string read GetNewFileName write SetNewFileName;
    property Password: string read GetPassword write SetPassword;
    property ReuseSessionId: Boolean read GetReuseSessionId write SetReuseSessionId;
    property StoredProcName: string read GetStoredProcName write SetStoredProcName;
    property SQL: string read GetSQL write SetSQL;
    property SQLName: string read GetSQLName write SetSQLName;
  end;

  // ============ �û����ɶ��巢�͵���Ϣ�� ============
  // ���� Post ����

  TMessagePack = class(TClientParams)
  private
    FThread: TSendThread;         // �����߳�
    procedure InternalPost(AAction: TActionType);
  public
    constructor Create(AOwner: TBaseClientObject);
    procedure Post(AAction: TActionType);
  end;

  // ============ �ͻ������ ���� ============

  // �о��ļ��¼�
  TListFileEvent = procedure(Sender: TObject; ActResult: TActionResult;
                             No: Integer; Result: TCustomPack) of object;

  TInBaseClient = class(TBaseClientObject)
  private
    FFileList: TStrings;          // ��ѯ�ļ����б�
    FParams: TClientParams;       // ��������Ϣ������Ҫֱ��ʹ�ã�
    function CheckState(CheckLogIn: Boolean = True): Boolean;
    function GetParams: TClientParams;
    procedure InternalPost(Action: TActionType = atUnknown);
    procedure ListReturnFiles(Result: TResultParams);
    procedure SetConnection(const Value: TInConnection);
  protected
    FConnection: TInConnection;   // �ͻ�������
    FOnListFiles: TListFileEvent; // ��������Ϣ�ļ�
  protected
    property Connection: TInConnection read FConnection write SetConnection;
    property Params: TClientParams read GetParams;
  public
    destructor Destroy; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  end;

  // ============ ��Ӧ����ͻ��� ============

  TInEchoClient = class(TInBaseClient)
  public
    procedure Post;
  published
    property Connection;
  end;

  // ============ ��֤����ͻ��� ============

  // ��֤����¼�
  TCertifyEvent = procedure(Sender: TObject; Action: TActionType; ActResult: Boolean) of object;

  // �оٿͻ����¼�
  TListClientsEvent = procedure(Sender: TObject; Count, No: Cardinal; const Client: PClientInfo) of object;

  TInCertifyClient = class(TInBaseClient)
  private
    FGroup: string;       // ���飨δ�ã�
    FUserName: string;    // ����
    FPassword: string;    // ����
  private
    FOnCertify: TCertifyEvent;  // ��֤����¼/�ǳ����¼�
    FOnListClients: TListClientsEvent;  // ��ʾ�ͻ�����Ϣ
    function GetLogined: Boolean;
    procedure InterListClients(Result: TResultParams);
    procedure SetPassword(const Value: string);
    procedure SetUserName(const Value: string);
  protected
    procedure HandleMsgHead(Result: TResultParams);
    procedure HandleFeedback(Result: TResultParams); override;
  public
    procedure Register(const AUserName, APassword: string; Role: TClientRole = crClient);
    procedure GetUserState(const AUserName: string);
    procedure Modify(const AUserName, ANewPassword: string; Role: TClientRole = crClient);
    procedure Delete(const AUserName: string);
    procedure QueryClients;
    procedure Login;
    procedure Logout;
  public
    property Logined: Boolean read GetLogined;
  published
    property Connection;
    property Group: string read FGroup write FGroup;
    property UserName: string read FUserName write SetUserName;
    property Password: string read FPassword write SetPassword;
  published
    property OnCertify: TCertifyEvent read FOnCertify write FOnCertify;
    property OnListClients: TListClientsEvent read FOnListClients write FOnListClients;
  end;

  // ============ ��Ϣ����ͻ��� ============

  TInMessageClient = class(TInBaseClient)
  protected
    procedure HandleFeedback(Result: TResultParams); override;
  public
    procedure Broadcast(const Msg: string);
    procedure GetOfflineMsgs;
    procedure GetMsgFiles(FileList: TStrings = nil);
    procedure SendMsg(const Msg: string; const ToUserName: string = '');
  published
    property Connection;
    property OnListFiles: TListFileEvent read FOnListFiles write FOnListFiles;
  end;

  // ============ �ļ�����ͻ��� ============
  // 2.0 δʵ���ļ����ʹ���

  TInFileClient = class(TInBaseClient)
  protected
    procedure HandleFeedback(Result: TResultParams); override;
  public
    procedure SetDir(const Directory: string);
    procedure ListFiles(FileList: TStrings = nil);
    procedure Delete(const AFileName: string);
    procedure Download(const AFileName: string);
    procedure Rename(const AFileName, ANewFileName: string);
    procedure Upload(const AFileName: string); overload;
    procedure Share(const AFileName, AUserNameList: string);
  published
    property Connection;
    property OnListFiles: TListFileEvent read FOnListFiles write FOnListFiles;
  end;

  // ============ ���ݿ����ӿͻ��� ============

  TInDBConnection = class(TInBaseClient)
  private
    FConnectionIndex: Integer;   // ���ӱ��
  public
    procedure GetConnections;
    procedure Connect(ANo: Cardinal);
  published
    property Connection;
    property ConnectionIndex: Integer read FConnectionIndex write FConnectionIndex;
  end;

  // ============ ���ݿ�ͻ��� ���� ============

  TDBBaseClientObject = class(TInBaseClient)
  private
    FDBConnection: TInDBConnection;  // ���ݿ�����
    procedure SetDBConnection(const Value: TInDBConnection);
    procedure UpdateInConnection;
  public
    procedure ExecStoredProc(const ProcName: string);
  public
    property Params;
  published
    property DBConnection: TInDBConnection read FDBConnection write SetDBConnection;
  end;

  // ============ SQL ����ͻ��� ============

  TInDBSQLClient = class(TDBBaseClientObject)
  public
    procedure ExecSQL;
  end;

  // ============ ���ݲ�ѯ�ͻ��� �� ============

  TInDBQueryClient = class(TDBBaseClientObject)
  private
    FClientDataSet: TClientDataSet;  // �������ݼ�
    FSubClientDataSets: TList;  // �����ӱ�
    FTableNames: TStrings; // Ҫ���µ�Զ�̱���
    FReadOnly: Boolean;    // �Ƿ�ֻ��
  protected
    procedure HandleFeedback(Result: TResultParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddClientDataSets(AClientDataSet: TClientDataSet);
    procedure ApplyUpdates;
    procedure ClearClientDataSets;
    procedure ExecQuery;
  public
    property ReadOnly: Boolean read FReadOnly;
  published
    property ClientDataSet: TClientDataSet read FClientDataSet write FClientDataSet;
  end;

  // ============ �Զ�����Ϣ�ͻ��� ============

  TInCustomClient = class(TInBaseClient)
  public
    procedure Post;
  public
    property Params;
  published
    property Connection;
  end;

  // ============ Զ�̺����ͻ��� ============

  TInFunctionClient = class(TInBaseClient)
  public
    procedure Call(const GroupName: string; FunctionNo: Integer);
  public
    property Params;
  published
    property Connection;
  end;

  // =================== �����߳� �� ===================

  TMsgIdArray = array of TIOCPMsgId;

  TSendThread = class(TCycleThread)
  private
    FConnection: TInConnection; // ����
    FLock: TThreadLock;         // �߳���
    FSender: TClientTaskSender; // ��Ϣ������

    FCancelIds: TMsgIdArray;    // ��ȡ������Ϣ�������
    FMsgList: TInList;          // ������Ϣ���б�
    FMsgPack: TClientParams;    // ��ǰ������Ϣ��

    FMsgId: TFileSize;          // ��ǰ��Ϣ Id
    FTotalSize: TFileSize;      // ��ǰ��Ϣ�ܳ���
    FCurrentSize: TFileSize;    // ��ǰ������

    FGetFeedback: Integer;      // �յ�����������
    FWaitState: Integer;        // �ȴ�����״̬
    FWaitSemaphore: THandle;    // �ȴ��������������źŵ�

    function GetCount: Integer;
    function GetWork: Boolean;
    function GetWorkState: Boolean;
    function InCancelArray(MsgId: TIOCPMsgId): Boolean;
    procedure AddCancelMsgId(MsgId: TIOCPMsgId);
    procedure ClearMsgList;
    procedure KeepWaiting;
    procedure IniWaitState;
    procedure InternalSend;
    procedure OnDataSend(DataType: TMessageDataType; OutSize: Integer);
    procedure OnSendError(Sender: TObject);
    procedure ServerReturn;
    procedure WaitForFeedback;
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AConnection: TInConnection);
    procedure AddWork(Msg: TClientParams);
    procedure CancelWork(MsgId: TIOCPMsgId);
    procedure ClearAllWorks(var ACount: Integer);
  public
    property Count: Integer read GetCount;
  end;

  // =================== ���ͽ�����߳� �� ===================
  // ������յ�����Ϣ���б���һ����Ӧ�ò�

  TPostThread = class(TCycleThread)
  private
    FConnection: TInConnection; // ����
    FLock: TThreadLock;         // �߳���

    FResults: TInList;          // �յ�����Ϣ�б�
    FResult: TResultParams;     // �յ��ĵ�ǰ��Ϣ
    FResultEx: TResultParams;   // �ȴ��������ͽ������Ϣ

    FMsgPack: TClientParams;    // ��ǰ������Ϣ
    FOwner: TBaseClientObject;  // ��ǰ������Ϣ������

    procedure ExecInMainThread;
    procedure HandleMessage(Result: TReceivePack);
  protected
    procedure AfterWork; override;
    procedure DoMethod; override;
  public
    constructor Create(AConnection: TInConnection);
    procedure Add(Result: TReceivePack);
    procedure SetMsgPack(AMsgPack: TClientParams);
  end;

  // =================== �����߳� �� ===================

  TRecvThread = class(TThread)
  private
    FConnection: TInConnection; // ����
    FRecvBuf: TWsaBuf;          // ���ջ���
    FOverlapped: TOverlapped;   // �ص��ṹ

    FReceiver: TClientReceiver; // ���ݽ�����
    FRecvMsg: TReceivePack;     // ��ǰ��Ϣ

    FMsgId: TFileSize;          // ��ǰ��Ϣ Id
    FTotalSize: TFileSize;      // ��ǰ��Ϣ����
    FCurrentSize: TFileSize;    // ��ǰ��Ϣ�յ��ĳ���

    procedure HandleDataPacket; // �����յ������ݰ�
    procedure OnDataReceive(Result: TReceivePack; DataType: TMessageDataType;
                            ReceiveCount: TFileSize; AttachFinished: Boolean);
    procedure OnError(Result: TReceivePack);
  protected
    procedure Execute; override;
  public
    constructor Create(AConnection: TInConnection);
    procedure Stop;
  end;

implementation

uses
  http_base, iocp_api, iocp_wsExt;

// var
//  ExtrMsg: TStrings;
//  FDebug: TStrings;
//  FStream: TMemoryStream;

{ TBaseClientObject }

procedure TBaseClientObject.HandleFeedback(Result: TResultParams);
begin
  // ������������ص���Ϣ
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, Result);
end;

procedure TBaseClientObject.HandlePushedMsg(Msg: TResultParams);
begin
  // �ӵ�������Ϣ�������յ������ͻ�����Ϣ��
  if Assigned(FOnReceiveMsg) then
    FOnReceiveMsg(Self, Msg);
end;

{ TInConnection }

procedure TInConnection.CancelAllWorks;
begin
  // ȡ��ȫ������
  if Assigned(FSendThread) then
  begin
    FSendThread.ClearAllWorks(FCancelCount);
    FSendThread.Activate;
    if Assigned(FOnError) then
      FOnError(Self, 'ȡ�� ' + IntToStr(FCancelCount) + ' ������.');
  end;
end;

procedure TInConnection.CancelWork(MsgId: TIOCPMsgId);
begin
  // ȡ��ָ����Ϣ�ŵ�����
  if Assigned(FSendThread) and (MsgId > 0) then
  begin
    FSendThread.CancelWork(MsgId);  // �ҷ����߳�
    if Assigned(FOnError) then
      FOnError(Self, 'ȡ��������Ϣ��־: ' + IntToStr(MsgId));
  end;
end;

constructor TInConnection.Create(AOwner: TComponent);
begin
  inherited;
  IniDateTimeFormat;

  FAutoConnected := False;  // ���Զ�����
  FMaxChunkSize := MAX_CHUNK_SIZE;
  FReuseSessionId := False;

  FSessionId := INI_SESSION_ID;  // ��ʼƾ֤
  FServerPort := DEFAULT_SVC_PORT;
  FSocket := INVALID_SOCKET;  // ��Ч Socket
end;

procedure TInConnection.CreateTimer;
begin
  // ����ʱ��
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 80;
  FTimer.OnTimer := TimerEvent;
end;

destructor TInConnection.Destroy;
begin
  SetActive(False);
  inherited;
end;

procedure TInConnection.DoServerError(Result: TResultParams);
begin
  // �յ��쳣���ݣ������쳣
  //  �������̵߳���ִ�У���ʱͨѶ�������ģ�
  try
    FActResult := Result.ActResult;
    if Assigned(FOnError) then
      case FActResult of
        arOutDate:
          FOnError(Self, '��������ƾ֤/��֤����.');
        arDeleted:
          FOnError(Self, '����������ǰ�û�������Աɾ�����Ͽ�����.');
        arRefuse:
          FOnError(Self, '���������ܾ����񣬶Ͽ�����.');
        arTimeOut:
          FOnError(Self, '����������ʱ�˳����Ͽ�����.');
        arErrAnalyse:
          FOnError(Self, '�����������������쳣.');
        arErrBusy:
          FOnError(Self, '��������ϵͳ��æ����������.');
        arErrHash:
          FOnError(Self, '��������У���쳣.');
        arErrHashEx:
          FOnError(Self, '�ͻ��ˣ�У���쳣.');
        arErrInit:  // �յ��쳣����
          FOnError(Self, '�ͻ��ˣ����ճ�ʼ���쳣���Ͽ�����.');
        arErrPush:
          FOnError(Self, '��������������Ϣ�쳣.');
        arErrUser:  // ������ SessionId �ķ���
          FOnError(Self, '���������û�δ��¼��Ƿ�.');
        arErrWork:  // �����ִ�������쳣
          FOnError(Self, '��������' + Result.Msg);
      end;
  finally
    if (FActResult in [arDeleted, arRefuse, arTimeOut, arErrInit]) then
      FTimer.Enabled := True;  // �Զ��Ͽ�
  end;
end;

procedure TInConnection.DoThreadFatalError;
begin
  // �շ�ʱ���������쳣/ֹͣ
  try
    if Assigned(FOnError) then
      if (FActResult = arErrNoAnswer) then
        FOnError(Self, '�ͻ��ˣ���������Ӧ��.')
      else
      if (FErrorCode > 0) then
        FOnError(Self, '�ͻ��ˣ�' + GetWSAErrorMessage(FErrorCode))
      else
      if (FErrorCode = -1) then
        FOnError(Self, '�ͻ��ˣ������쳣.')
      else
      if (FErrorCode = -2) then  // �������
        FOnError(Self, '�ͻ��ˣ��û�ȡ������.')
      else
        FOnError(Self, '�ͻ��ˣ�' + FErrMsg);
  finally
    if not FSendThread.FSender.Stoped then
      FTimer.Enabled := True;  // �Զ��Ͽ�
  end;
end;

function TInConnection.GetActive: Boolean;
begin
  if (csDesigning in ComponentState) or (csLoading in ComponentState) then
    Result := FActive
  else
    Result := (FSocket <> INVALID_SOCKET) and FActive;
end;

procedure TInConnection.HandleFeedback(Result: TResultParams);
begin
  HandleMsgHead(Result);
  inherited;
end;

procedure TInConnection.HandleMsgHead(Result: TResultParams);
begin
  // �����¼���ǳ����
  case Result.Action of
    atUserLogin:
      begin  // SessionId > 0 ���ɹ�
        FSessionId := Result.SessionId;
        FLogined := (FSessionId > INI_SESSION_ID);
        FRole := Result.Role;
      end;
    atUserLogout:
      begin
      // �����ӣ�����ƾ֤ʱ -> ���� FSessionId
        FLogined := False;
        if not FReuseSessionId then
        begin
          FSessionId := INI_SESSION_ID;
          FRole := crUnknown;
        end;
      end;
  end;
end;

procedure TInConnection.InternalClose;
begin
  // �Ͽ�����
  if Assigned(FBeforeDisConnect) then
    FBeforeDisConnect(Self);

  if (FSocket <> INVALID_SOCKET) then
  begin
    // �ر� Socket
    ShutDown(FSocket, SD_BOTH);
    CloseSocket(FSocket);

    FLogined := False;
    FSocket := INVALID_SOCKET;

    if FActive then
    begin
      FActive := False;

      // �����ӣ�����ƾ֤���´����¼
      if not FReuseSessionId then
        FSessionId := INI_SESSION_ID;

      // �ͷŽ����߳�
      if Assigned(FRecvThread) then
      begin
        FRecvThread.Terminate;  // 100 ������˳�
        FRecvThread := nil;
      end;

      // Ͷ���߳�
      if Assigned(FPostThread) then
      begin
        FPostThread.Stop;
        FPostThread := nil;
      end;

      // �ͷŷ����߳�
      if Assigned(FSendThread) then
      begin
        FSendThread.Stop;
        FSendThread.FSender.Stoped := True;
        FSendThread.ServerReturn;
        FSendThread := nil;
      end;

      // �ͷŶ�ʱ��
      if Assigned(FTimer) then
      begin
        FTimer.Free;
        FTimer := nil;
      end;
    end;
  end;

  if not (csDestroying in ComponentState) then
    if Assigned(FAfterDisconnect) then
      FAfterDisconnect(Self);
end;

procedure TInConnection.InternalOpen;
begin
  // ���� WSASocket�����ӵ�������
  if Assigned(FBeforeConnect) then
    FBeforeConnect(Self);

  if (FSocket = INVALID_SOCKET) then
  begin
    // �½� Socket
    FSocket := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);

    // ��������
    FActive := iocp_utils.ConnectSocket(FSocket, FServerAddr, FServerPort);

    if FActive then  // ���ӳɹ�
    begin
      // ��ʱ��
      CreateTimer;

      // ����
      iocp_wsExt.SetKeepAlive(FSocket);

      // ���̷��� IOCP_SOCKET_FLAG�������תΪ TIOCPSocet
      iocp_Winsock2.Send(FSocket, IOCP_SOCKET_FLAG[1], IOCP_SOCKET_FLEN, 0);

      // �շ���
      FRecvCount := 0;
      FSendCount := 0;

      // Ͷ���߳�
      FPostThread := TPostThread.Create(Self);

      // �շ��߳�
      FSendThread := TSendThread.Create(Self);
      FRecvThread := TRecvThread.Create(Self);

      FPostThread.Resume;
      FSendThread.Resume;
      FRecvThread.Resume;
    end else
    begin
      ShutDown(FSocket, SD_BOTH);
      CloseSocket(FSocket);
      FSocket := INVALID_SOCKET;
    end;
  end;

  if FActive and Assigned(FAfterConnect) then
    FAfterConnect(Self)
  else
  if not FActive and Assigned(FOnError) then
    FOnError(Self, '�޷����ӵ�������.');

end;

procedure TInConnection.Loaded;
begin
  inherited;
  // װ�غ�FActive -> ��
  if FActive and not (csDesigning in ComponentState) then
    InternalOpen;
end;

procedure TInConnection.PauseWork(MsgId: TIOCPMsgId);
begin
  // ��ͣ����
  CancelWork(MsgId);  // ��ʵ���Ե���ͣ������ȡ��
end;

procedure TInConnection.ReceiveProgress;
begin
  // ��ʾ���ս���
  if Assigned(FOnDataReceive) then
    FOnDataReceive(Self, FRecvThread.FMsgId,
                   FRecvThread.FTotalSize, FRecvThread.FCurrentSize);
end;

procedure TInConnection.SendProgress;
begin
  // ��ʾ���ͽ��̣����塢������һ�� 100%��
  if Assigned(FOnDataSend) then  // �� FMsgSize
    FOnDataSend(Self, FSendThread.FMsgId,
                FSendThread.FTotalSize, FSendThread.FCurrentSize);
end;

procedure TInConnection.SetActive(Value: Boolean);
begin
  if Value <> FActive then
  begin
    if (csDesigning in ComponentState) or (csLoading in ComponentState) then
      FActive := Value
    else
    if Value and not FActive then
      InternalOpen
    else
    if not Value and FActive then
      InternalClose;
  end;
end;

procedure TInConnection.SetMaxChunkSize(Value: Integer);
begin
  if (Value >= MAX_CHUNK_SIZE div 4) and (Value <= MAX_CHUNK_SIZE * 2) then
    FMaxChunkSize := Value
  else
    FMaxChunkSize := MAX_CHUNK_SIZE;
end;

procedure TInConnection.TimerEvent(Sender: TObject);
begin
  // ��ɾ������ʱ���ܾ�����ȴ���
  FTimer.Enabled := False;
  InternalClose;  // �Ͽ�����
end;

procedure TInConnection.TryDisconnect;
begin
  // �������ر�ʱ�����Թرտͻ���
  if Assigned(FTimer) then
  begin
    FTimer.OnTimer := TimerEvent;
    FTimer.Enabled := True;
  end;
end;

{ TResultParams }

procedure TResultParams.CreateAttachment(const ALocalPath: string);
var
  Msg: TCustomPack;
  InfFileName: string;
begin
  // �ȼ�鱾�������ļ�(�汾��ͬ��ɾ��)
  if (FAction = atFileDownChunk) then
  begin
    // ��������Ϣ�ļ�
    InfFileName := ALocalPath + GetFileName + '.download';
    Msg := TCustomPack.Create;

    try
      Msg.Initialize(InfFileName);

      if (Msg.Count = 2) { ��ʼֻ�� 2 ���ֶ� } or (
         (Msg.AsInt64['_FileSize'] <> GetFileSize) or
         (Msg.AsCardinal['_modifyLow'] <> AsCardinal['_modifyLow']) or
         (Msg.AsCardinal['_modifyHigh'] <> AsCardinal['_modifyHigh'])) then
      begin
        if (Msg.Count >= 5) then  // �����ļ��ĳ��ȡ��޸�ʱ��ı�
        begin
          FOffset := 0;  // �� 0 ��ʼ��������
          FOffsetEnd := 0;  // 0 ����
          DeleteFile(ALocalPath + GetFileName);  // ɾ���ļ�
        end;

        Msg.AsInt64['_FileSize'] := GetFileSize;
        Msg.AsCardinal['_modifyLow'] := AsCardinal['_modifyLow'];
        Msg.AsCardinal['_modifyHigh'] := AsCardinal['_modifyHigh'];

        // �����ļ�
        Msg.SaveToFile(InfFileName);
      end;
    finally
      Msg.Free;
    end;
  end;
  inherited; // ִ�и������
end;

{ TClientParams }

function TClientParams.ReadDownloadInf(AResult: TResultParams): Boolean;
var
  Msg: TCustomPack;
  InfFileName: string;
begin
  // CreateStream ǰ��ȡ�ϵ�������Ϣ

  // ���·����FConnection.FLocalPath
  InfFileName := FConnection.FLocalPath + GetFileName + '.download';
  Msg := TCustomPack.Create;

  try
    Msg.Initialize(InfFileName);

    if (Msg.Count = 0) then
    begin
      FOffset := 0;  // λ��
      FOffsetEnd := FConnection.FMaxChunkSize;  // �鳤��
      Msg.AsInt64['_MsgId'] := FMsgId;  // ��Ϣ��־
      Msg.AsInt64['_Offset'] := FOffset;  // �����λ��
      Result := True;
    end else
    begin
      if (AResult = nil) then  // ȡ����λ��
      begin
        FMsgId := Msg.AsInt64['_MsgId'];  // ��Ϣ��־
        FOffset := Msg.AsInt64['_Offset'];
      end else
      begin  // ����˷���
        if (AResult.FOffsetEnd = 0) then
          FOffset := 0 // ���¿�ʼ
        else
          FOffset := AResult.FOffsetEnd + 1; // λ���ƽ�
        FMsgId := AResult.MsgId;  // ��Ϣ��־
        Msg.AsInt64['_Offset'] := FOffset;
        Msg.AsString['_Directory'] := AResult.GetDirectory;
      end;

      // ÿ�鳤��(����˻�У��)�������·�������ܣ�
      FOffsetEnd := FConnection.FMaxChunkSize;
      SetDirectory(Msg.AsString['_Directory']);

      Result := (FOffset < Msg.AsInt64['_FileSize']); // >= ʱ�������
    end;

    if Result then  // ���洫����Ϣ
      Msg.SaveToFile(InfFileName)
    else  // �Ѿ��������
      DeleteFile(InfFileName);

  finally
    Msg.Free;
  end;

end;

function TClientParams.ReadUploadInf(AResult: TResultParams): Boolean;
var
  Msg: TCustomPack;
  InfFileName: string;
begin
  // ��/�½��ϵ��ϴ���Ϣ��ÿ���ϴ�һ�飩

  InfFileName := FAttachFileName + '.upload';
  Msg := TCustomPack.Create;

  try
    // ��������Դ
    Msg.Initialize(InfFileName);

    if (Msg.Count = 0) or // ����Դ����һ�Σ�
       (Msg.AsInt64['_FileSize'] <> AsInt64['_FileSize']) or
       (Msg.AsCardinal['_modifyLow'] <> AsCardinal['_modifyLow']) or
       (Msg.AsCardinal['_modifyHigh'] <> AsCardinal['_modifyHigh']) then
    begin
      // ����Դ �� �ļ����޸Ĺ�
      FOffset := 0;  // λ��
      Msg.AsInt64['_MsgId'] := FMsgId;
      Msg.AsInt64['_Offset'] := FOffset;  // �� 0 ��ʼ
      Msg.AsInt64['_FileSize'] := AsInt64['_FileSize'];
      Msg.AsCardinal['_modifyLow'] := AsCardinal['_modifyLow'];
      Msg.AsCardinal['_modifyHigh'] := AsCardinal['_modifyHigh'];
    end else
    if (AResult = nil) then  // ������Դ
    begin
      FMsgId := Msg.AsInt64['_MsgId'];
      FOffset := Msg.AsInt64['_Offset'];
    end else
    begin
      FMsgId := AResult.FMsgId;
      if (AResult.FOffset <> Msg.AsInt64['_Offset']) then  // λ�Ʋ���
        FOffset := 0  // ���¿�ʼ
      else
        FOffset := AResult.FOffsetEnd + 1; // �ƽ�����һ��
    end;

    // ���䷶Χ��FOffset...EOF
    Result := (FOffset < FAttachSize); // δ�������

    if Result then  // �������
    begin
      if Assigned(AResult) then  // �������˷�����Ϣ
      begin
        Msg.AsInt64['_Offset'] := FOffset;  // ���������λ�ƣ�δ��ɣ�
        Msg.AsString['_Directory'] := AResult.GetDirectory;  // ������ļ������ܣ�
        Msg.AsString['_FileName'] := AResult.GetFileName; // ������ļ���
      end else  // ��һ�� Directory Ϊ��
      if (FOffset = 0) then
        Msg.AsString['_FileName'] := GetFileName;

      // ����˵�·�������ܣ����ļ�
      SetDirectory(Msg.AsString['_Directory']);
      SetFileName(Msg.AsString['_FileName']); // ����
        
      // �����ļ����ƣ�����ʱ�ã�
      SetAttachFileName(FAttachFileName);

      // �������䷶Χ��Ҫ����FOffset��
      AdjustTransmitRange(FConnection.FMaxChunkSize - 1);  // 0..64k
    end;

    if Result then
      Msg.SaveToFile(InfFileName)
    else
      DeleteFile(InfFileName);  // ������ϣ�ɾ����Դ

  finally
    Msg.Free;
  end;

end;

procedure TClientParams.CreateStreams(ClearList: Boolean);
begin
  // ��顢�����ϵ����ط�Χ
  if (FState = msDefault) and (FAction = atFileDownChunk) then
    ReadDownloadInf(nil);
  inherited;
end;

procedure TClientParams.ModifyMessageId;
var
  Msg: TCustomPack;
  MsgFileName: string;
begin
  // ʹ��������Ϣ�ļ��� MsgId
  if (FAction = atFileDownChunk) then
    MsgFileName := FileName + '.download'
  else
    MsgFileName := FAttachFileName + '.upload';

  if FileExists(MsgFileName) then
  begin
    Msg := TCustomPack.Create;
    try
      Msg.Initialize(MsgFileName);
      FMsgId := Msg.AsInt64['_msgId'];
    finally
      Msg.Free;
    end;
  end;
end;

procedure TClientParams.OpenLocalFile;
begin
  inherited; // �ȴ��ļ�
  if (FState = msDefault) and (FAction = atFileUpChunk) then
    ReadUploadInf(nil);
end;

{ TMessagePack }

constructor TMessagePack.Create(AOwner: TBaseClientObject);
begin
  if (AOwner = nil) then  // ����Ϊ nil
    raise Exception.Create('��Ϣ Owner ����Ϊ��.');
  inherited Create(AOwner);
  if (AOwner is TInConnection) then
    FConnection := TInConnection(AOwner)
  else begin
    if (AOwner is TDBBaseClientObject) then
      TDBBaseClientObject(AOwner).UpdateInConnection;
    FConnection := TInBaseClient(AOwner).FConnection;
  end;
  if Assigned(FConnection) then
  begin
    if not FConnection.FActive and FConnection.FAutoConnected then
      FConnection.InternalOpen;
    SetUserName(FConnection.FUserName);  // Ĭ�ϼ����û���
    FThread := FConnection.FSendThread;
  end;
end;

procedure TMessagePack.InternalPost(AAction: TActionType);
var
  sErrMsg: string;
begin
  // �ύ��Ϣ
  if Assigned(FThread) then
  begin
    FAction := AAction; // ����
    if (FAction in [atTextPush, atTextBroadcast]) and (Size > BROADCAST_MAX_SIZE) then
      sErrMsg := '���͵���Ϣ̫��.'
    else
    if Error then
      sErrMsg := '���ñ����쳣.'
    else
      FThread.AddWork(Self); // ����Ϣ�������߳�
  end else
    sErrMsg := 'δ���ӵ�������.';

  if (sErrMsg <> '') then
  try
    if Assigned(FConnection.FOnError) then
      FConnection.FOnError(Self, sErrMsg)
    else
      raise Exception.Create(sErrMsg);
  finally
    Free;
  end;
end;

procedure TMessagePack.Post(AAction: TActionType);
begin
  if (AAction = atUserLogin) then  // ��¼
    FConnection.FUserName := UserName;
  InternalPost(AAction);  // �ύ��Ϣ
end;

{ TInBaseClient }

function TInBaseClient.CheckState(CheckLogIn: Boolean): Boolean;
var
  Error: string;
begin
  // ������״̬
  if Assigned(Params) and Params.Error then  // �쳣
    Error := '�������ñ����쳣.'
  else
  if not Assigned(FConnection) then
    Error := '����δָ���ͻ�������.'
  else
  if not FConnection.Active then
  begin
    if FConnection.FAutoConnected then
      FConnection.InternalOpen;
    if not FConnection.Active then
      Error := '�������ӷ�����ʧ��.';
  end else
  if CheckLogIn and (FConnection.FSessionId = 0) then
    Error := '���󣺿ͻ���δ��¼.';

  if (Error = '') then
    Result := not CheckLogIn or (FConnection.FSessionId > 0)
  else begin
    Result := False;
    if Assigned(FParams) then
      FreeAndNil(FParams);
    if Assigned(FConnection.FOnError) then
      FConnection.FOnError(Self, Error)
    else
      raise Exception.Create(Error);
  end;

end;

destructor TInBaseClient.Destroy;
begin
  if Assigned(FParams) then
    FParams.Free;
  inherited;
end;

function TInBaseClient.GetParams: TClientParams;
begin
  // ��̬��һ����Ϣ�������ͺ��� FParams = nil
  //    ��һ�ε���ʱҪ���� Params ��ʵ������Ҫ�� FParams��
  if not Assigned(FParams) then
    FParams := TClientParams.Create(Self);
  if Assigned(FConnection) then
  begin
    FParams.FConnection := FConnection;
    FParams.FSessionId := FConnection.FSessionId;
    FParams.UserName := FConnection.FUserName;  // Ĭ�ϼ����û���
  end;
  Result := FParams;
end;

procedure TInBaseClient.InternalPost(Action: TActionType);
begin
  // ����Ϣ�������߳�
  if Assigned(FParams) then
  try
    FParams.FAction := Action;  // ���ò���
    FConnection.FSendThread.AddWork(FParams);
  finally
    FParams := Nil;  // ���
  end;
end;

procedure TInBaseClient.ListReturnFiles(Result: TResultParams);
var
  i: Integer;
  RecValues: TBasePack;
begin
  // �г��ļ�����
  case Result.ActResult of
    arFail:        // Ŀ¼������
      if Assigned(FOnListFiles) then
        FOnListFiles(Self, arFail, 0, Nil);
    arEmpty:       // Ŀ¼Ϊ��
      if Assigned(FOnListFiles) then
        FOnListFiles(Self, arEmpty, 0, Nil);
  else
    try          // �г��ļ���һ���ļ�һ����¼
      try
        for i := 1 to Result.Count do
        begin
          RecValues := Result.AsRecord[IntToStr(i)];
          if Assigned(RecValues) then
            try
              if Assigned(FFileList) then // ���浽�б�
                FFileList.Add(TCustomPack(RecValues).AsString['name'])
              else
              if Assigned(FOnListFiles) then
                FOnListFiles(Self, arExists, i, TCustomPack(RecValues));
            finally
              RecValues.Free;
            end;
        end;
      finally
        if Assigned(FFileList) then
          FFileList := nil;
      end;
    except
      if Assigned(FConnection.FOnError) then
        FConnection.FOnError(Self, 'TInBaseClient.ListReturnFiles���������쳣.');
    end;
  end;
end;

procedure TInBaseClient.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = FConnection) and (Operation = opRemove) then
    FConnection := nil;  // ������ TInConnection �����ɾ��
end;

procedure TInBaseClient.SetConnection(const Value: TInConnection);
begin
  // �����������
  if Assigned(FConnection) then
    FConnection.RemoveFreeNotification(Self);
  FConnection := Value; // ��ֵ
  if Assigned(FConnection) then
    FConnection.FreeNotification(Self);
end;

{ TInEchoClient }

procedure TInEchoClient.Post;
begin
  // ��Ӧ, ���õ�¼
  if CheckState(False) and Assigned(Params) then
    InternalPost;
end;

{ TInCertifyClient }

procedure TInCertifyClient.Delete(const AUserName: string);
begin
  // ɾ���û�
  if CheckState() then
  begin
    Params.ToUser := AUserName;  // ��ɾ���û�
    InternalPost(atUserDelete);  // ɾ���û�
  end;
end;

function TInCertifyClient.GetLogined: Boolean;
begin
  // ȡ��¼״̬
  if Assigned(FConnection) then
    Result := FConnection.FLogined
  else
    Result := False;
end;

procedure TInCertifyClient.GetUserState(const AUserName: string);
begin
  // ��ѯ�û�״̬
  if CheckState() then
  begin
    Params.ToUser := AUserName; // 2.0 ��
    InternalPost(atUserState);
  end;
end;

procedure TInCertifyClient.HandleMsgHead(Result: TResultParams);
begin
  // �����¼���ǳ����
  FConnection.HandleMsgHead(Result);
  case Result.Action of
    atUserLogin:   // SessionId > 0 ���ɹ�
      if Assigned(FOnCertify) then
        FOnCertify(Self, atUserLogin, FConnection.FLogined);
    atUserLogout:
      if Assigned(FOnCertify) then
        FOnCertify(Self, atUserLogout, True);
  end;
end;

procedure TInCertifyClient.InterListClients(Result: TResultParams);
var
  i, k, iCount: Integer;
  Buf, Buf2: TMemBuffer;
begin
  // �г��ͻ�����Ϣ
  try
    // TMemoryStream(Stream).SaveToFile('clients.txt');
    for i := 1 to Result.AsInteger['group'] do
    begin
      // ������ TMemBuffer
      Buf := Result.AsBuffer['list_' + IntToStr(i)];
      iCount := Result.AsInteger['count_' + IntToStr(i)];
      if Assigned(Buf) then
        try
          Buf2 := Buf;
          for k := 1 to iCount do  // �����ڴ��
          begin
            FOnListClients(Self, iCount, k, PClientInfo(Buf2));
            Inc(PAnsiChar(Buf2), CLIENT_DATA_SIZE);
          end;
        finally
          FreeBuffer(Buf);  // Ҫ��ʽ�ͷ�
        end;
    end;
  except
    on E: Exception do
    begin
      if Assigned(FConnection.FOnError) then
        FConnection.FOnError(Self, 'TInCertifyClient.InterListClients, ' + E.Message);
    end;
  end;
end;

procedure TInCertifyClient.HandleFeedback(Result: TResultParams);
begin
  try
    case Result.Action of
      atUserLogin, atUserLogout:  // 1. �����¼���ǳ�
        HandleMsgHead(Result);
      atUserQuery:  // 2. ��ʾ���߿ͻ��ĵĲ�ѯ���
        if Assigned(FOnListClients) then
          InterListClients(Result);
    end;
  finally
    inherited HandleFeedback(Result);
  end;
end;

procedure TInCertifyClient.Login;
begin
  // ��¼
  if CheckState(False) then  // ���ü���¼״̬
  begin
    Params.UserName := FUserName;
    FParams.Password := FPassword;
    FParams.ReuseSessionId := FConnection.ReuseSessionId;
    FConnection.FUserName := FUserName;  // ����
    InternalPost(atUserLogin);
    ;
  end;
end;

procedure TInCertifyClient.Logout;
begin
  // �ǳ�
  if CheckState() and Assigned(Params) then
  begin
    FConnection.FSendThread.ClearAllWorks(FConnection.FCancelCount); // ���������
    InternalPost(atUserLogout);
  end;
end;

procedure TInCertifyClient.Modify(const AUserName, ANewPassword: string; Role: TClientRole);
begin
  // �޸��û����롢��ɫ
  if CheckState() and (FConnection.FRole >= Role) then
  begin
    Params.ToUser := AUserName;  // ���޸ĵ��û�
    FParams.Password := ANewPassword;
    FParams.Role := Role;
    InternalPost(atUserModify);
  end;
end;

procedure TInCertifyClient.QueryClients;
begin
  // ��ѯȫ�����߿ͻ���
  if CheckState() and Assigned(Params) then
    InternalPost(atUserQuery);
end;

procedure TInCertifyClient.Register(const AUserName, APassword: string; Role: TClientRole);
begin
  // ע���û�������Ա��
  if CheckState() and (FConnection.FRole >= crAdmin) and (FConnection.FRole >= Role) then
  begin
    Params.ToUser := AUserName;  // 2.0 �� ToUser
    FParams.Password := APassword;
    FParams.Role := Role;
    InternalPost(atUserRegister);
  end;
end;

procedure TInCertifyClient.SetPassword(const Value: string);
begin
  if not Logined and (Value <> FPassword) then
    FPassword := Value;
end;

procedure TInCertifyClient.SetUserName(const Value: string);
begin
  if not Logined and (Value <> FPassword) then
    FUserName := Value;
end;

{ TInMessageClient }

procedure TInMessageClient.Broadcast(const Msg: string);
begin
  // ����Ա�㲥��������Ϣ��ȫ�����߿ͻ��ˣ�
  if CheckState() and (FConnection.FRole >= crAdmin) then
  begin
    Params.Msg := Msg;
    FParams.Role := FConnection.FRole;
    if (FParams.Size <= BROADCAST_MAX_SIZE) then
      InternalPost(atTextBroadcast)
    else begin
      FParams.Clear;
      raise Exception.Create('���͵���Ϣ̫��.');
    end;
  end;
end;

procedure TInMessageClient.GetOfflineMsgs;
begin
  // ȡ������Ϣ
  if CheckState() and Assigned(Params) then
    InternalPost(atTextGetMsg);
end;

procedure TInMessageClient.GetMsgFiles(FileList: TStrings);
begin
  // ��ѯ����˵�������Ϣ�ļ�
  if CheckState() and Assigned(Params) then
  begin
    if Assigned(FileList) then
      FFileList := FileList;
    InternalPost(atTextFileList);
  end;
end;

procedure TInMessageClient.HandleFeedback(Result: TResultParams);
begin
  // ����������Ϣ�ļ�
  try
    if (Result.Action = atTextFileList) then  // �г��ļ�����
      ListReturnFiles(Result);
  finally
    inherited HandleFeedback(Result);
  end;
end;

procedure TInMessageClient.SendMsg(const Msg, ToUserName: string);
begin
  // �����ı�
  if CheckState() then
    if (ToUserName = '') then   // ���͵�������
    begin
      Params.Msg := Msg;
      InternalPost(atTextSend); // �򵥷���
    end else
    begin
      Params.Msg := Msg;
      FParams.ToUser := ToUserName; // ���͸�ĳ�û�
      if (FParams.Size <= BROADCAST_MAX_SIZE) then
        InternalPost(atTextPush)
      else begin
        FParams.Clear;
        raise Exception.Create('���͵���Ϣ̫��.');
      end;
    end;
end;

{ TInFileClient }

procedure TInFileClient.Delete(const AFileName: string);
begin
  // ɾ��������û���ǰ·�����ļ���Ӧ���ⲿ��ȷ�ϣ�
  if CheckState() then
  begin
    Params.FileName := AFileName;
    InternalPost(atFileDelete);
  end;
end;

procedure TInFileClient.Download(const AFileName: string);
begin
  // �����ļ�
  if CheckState() then
  begin
    Params.FileName := AFileName;
    InternalPost(atFileDownload);
  end;
end;

procedure TInFileClient.HandleFeedback(Result: TResultParams);
begin
  // �����ļ���ѯ���
  try
    if (Result.Action = atFileList) then  // �г��ļ�����
      ListReturnFiles(Result);
  finally
    inherited HandleFeedback(Result);
  end;
end;

procedure TInFileClient.ListFiles(FileList: TStrings);
begin
  // ��ѯ��������ǰĿ¼���ļ�
  if CheckState() and Assigned(Params) then
  begin
    if Assigned(FileList) then
      FFileList := FileList;
    InternalPost(atFileList);
  end;
end;

procedure TInFileClient.Rename(const AFileName, ANewFileName: string);
begin
  // ������ļ�����
  if CheckState() then
  begin
    Params.FileName := AFileName;
    FParams.NewFileName := ANewFileName;
    InternalPost(atFileRename);
  end;
end;

procedure TInFileClient.SetDir(const Directory: string);
begin
  // ���ÿͻ����ڷ������Ĺ���Ŀ¼
  if CheckState() and (Directory <> '') then
  begin
    Params.Directory := Directory;
    InternalPost(atFileSetDir);
  end;
end;

procedure TInFileClient.Share(const AFileName, AUserNameList: string);
begin
  // �ϴ�������˹�����ʱ·���������ĵ�
  if CheckState() then
  begin
    Params.FileName := AFileName;
    FParams.ToUser := AUserNameList;
    InternalPost(atFileUpShare);
  end;
end;

procedure TInFileClient.Upload(const AFileName: string);
begin
  // �ϴ������ļ� AFileName ��������
  if CheckState() and FileExists(AFileName) then
  begin
    Params.LoadFromFile(AFileName);
    InternalPost(atFileUpload);
  end;
end;

{ TInDBConnection }

procedure TInDBConnection.Connect(ANo: Cardinal);
begin
  // ���ӵ����Ϊ ANo �����ݿ�
  if CheckState() then
  begin
    Params.FTarget := ANo;
    FConnectionIndex := ANo;  // ����
    InternalPost(atDBConnect);
  end;
end;

procedure TInDBConnection.GetConnections;
begin
  // ��ѯ������������������/��ģʵ����
  if CheckState() and Assigned(Params) then
    InternalPost(atDBGetConns);
end;

{ TDBBaseClientObject }

procedure TDBBaseClientObject.ExecStoredProc(const ProcName: string);
begin
  // ִ�д洢����
  //   TInDBQueryClient �����ص����ݼ���TInDBSQLClient ������
  if CheckState() then
  begin
    Params.StoredProcName := ProcName;
    FParams.FTarget := FDBConnection.FConnectionIndex;  // ��Ӧ����ģ���
    InternalPost(atDBExecStoredProc);
  end;
end;

procedure TDBBaseClientObject.SetDBConnection(const Value: TInDBConnection);
begin
  if (FDBConnection <> Value) then
  begin
    FDBConnection := Value;
    UpdateInConnection;
  end;
end;

procedure TDBBaseClientObject.UpdateInConnection;
begin
  if Assigned(FDBConnection) then
    FConnection := FDBConnection.FConnection
  else
    FConnection := nil;
end;

{ TInDBSQLClient }

procedure TInDBSQLClient.ExecSQL;
begin
  // ִ�� SQL
  UpdateInConnection;  // ���� FConnection
  if CheckState() and Assigned(Params) then
  begin
    FParams.FTarget := FDBConnection.FConnectionIndex;  // ��Ӧ����ģ���
    InternalPost(atDBExecSQL);
  end;
end;

{ TInDBQueryClient }

procedure TInDBQueryClient.AddClientDataSets(AClientDataSet: TClientDataSet);
begin
  // �����ӱ� TClientDataSet
  if FSubClientDataSets.IndexOf(AClientDataSet) = -1 then
    FSubClientDataSets.Add(AClientDataSet);
end;

procedure TInDBQueryClient.ApplyUpdates;
var
  i, k: Integer;
  oDataSet: TClientDataSet;
begin
  // ����ȫ�����ݱ��������ӱ�
  UpdateInConnection;  // ���� FConnection
  if CheckState() and (FReadOnly = False) then
  begin
    k := 0;
    for i := 0 to FTableNames.Count - 1 do
    begin
      if (i = 0) then
        oDataSet := FClientDataSet
      else
        oDataSet := TClientDataSet(FSubClientDataSets[i - 1]);

      if (oDataSet.Changecount > 0) then  // �޸Ĺ������� Delta
      begin
        Inc(k);
        oDataSet.SetOptionalParam(szTABLE_NAME, FTableNames[i], True);
        FParams.AsVariant[FTableNames[i]] := oDataSet.Delta;
      end else  // ���� NULL �ֶ�
        FParams.AsVariant[FTableNames[i]] := Null;
    end;
    if (k > 0) then  // �����ݱ��޸Ĺ�
      InternalPost(atDBApplyUpdates);
  end;
end;

procedure TInDBQueryClient.ClearClientDataSets;
begin
  // ��������ݱ�
  FSubClientDataSets.Clear;
end;

constructor TInDBQueryClient.Create(AOwner: TComponent);
begin
  inherited;
  FSubClientDataSets := TList.Create;
  FTableNames := TStringList.Create;
end;

destructor TInDBQueryClient.Destroy;
begin
  FSubClientDataSets.Free;
  FTableNames.Free;
  inherited;
end;

procedure TInDBQueryClient.ExecQuery;
begin
  // SQL ��ֵʱ�Ѿ��ж� Action ���ͣ�����THeaderPack.SetSQL
  UpdateInConnection;  // ���� FConnection
  if CheckState() and Assigned(FParams) then
  begin
    FParams.FTarget := FDBConnection.FConnectionIndex;  // ��Ӧ����ģ���
    if (FParams.SQLName <> '') then  // ������ SQLName
      InternalPost(atDBExecQuery)
    else
      InternalPost(FParams.Action);
  end;
end;

procedure TInDBQueryClient.HandleFeedback(Result: TResultParams);

  procedure LoadResultDataSets;
  var
    i: Integer;
    XDataSet: TClientDataSet;
    DataField: TVarField;
  begin
    // װ�ز�ѯ���
    
    // �Ƿ�ֻ��
    FReadOnly := Result.Action = atDBExecStoredProc;

    // Result ���ܰ���������ݼ����ֶΣ�1,2,3

    FTableNames.Clear;
    for i := 0 to Result.VarCount - 1 do
    begin
      if (i = 0) then  // �����ݱ�
        XDataSet := FClientDataSet
      else
        XDataSet := FSubClientDataSets[i - 1];

      XDataSet.DisableControls;
      try
        DataField := Result.Fields[i];  // ȡ�ֶ� 1,2,3
        FTableNames.Add(DataField.Name);  // �������ݱ�����

        XDataSet.Data := DataField.AsVariant;  // ���ݸ�ֵ
        XDataSet.ReadOnly := FReadOnly;
      finally
        XDataSet.EnableControls;
      end;
    end;
  end;

  procedure MergeChangeDataSets;
  var
    i: Integer;
  begin
    // �ϲ����صĸ�������
    if (FClientDataSet.ChangeCount > 0) then
      FClientDataSet.MergeChangeLog;
    for i := 0 to FSubClientDataSets.Count - 1 do
      with TClientDataSet(FSubClientDataSets[i]) do
        if (ChangeCount > 0) then
          MergeChangeLog;
  end;

begin
  try
    if (Result.ActResult = arOK) then
      case Result.Action of
        atDBExecQuery,       // 1. ��ѯ����
        atDBExecStoredProc:  // 2. �洢���̷��ؽ��
          if Assigned(FClientDataSet) and (Result.VarCount > 0) and
            (Integer(Result.VarCount) = FSubClientDataSets.Count + 1) then
            LoadResultDataSets;
        atDBApplyUpdates:    // 3. ����
          MergeChangeDataSets;  // �ϲ����صĸ�������
      end;
  finally
    inherited HandleFeedback(Result);
  end;
end;

{ TInCustomClient }

procedure TInCustomClient.Post;
begin
  // �����Զ�����Ϣ
  if CheckState() and Assigned(FParams) then
    InternalPost(atCustomAction);
end;

{ TInFunctionClient }

procedure TInFunctionClient.Call(const GroupName: string; FunctionNo: Integer);
begin
  // ����Զ�̺����� GroupName �ĵ� FunctionNo ������
  //   ����TInCustomManager.Execute
  if CheckState() then
  begin
    Params.FunctionGroup := GroupName;
    FParams.FunctionIndex := FunctionNo;
    InternalPost(atCallFunction);
  end;
end;

// ================== �����߳� ==================

{ TSendThread }

procedure TSendThread.AddCancelMsgId(MsgId: TIOCPMsgId);
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

procedure TSendThread.AddWork(Msg: TClientParams);

  procedure ClearArrayMsgId;
  var
    i: Integer;
  begin
    // ������������ڵ���Ϣ��� MsgId
    if (FCancelIds <> nil) then
      for i := 0 to High(FCancelIds) do
        if (FCancelIds[i] = Msg.MsgId) then
        begin
          FCancelIds[i] := 0;  // �������
          Break;
        end;
  end;

begin
  // ����Ϣ�������б�

  //   Msg �Ƕ�̬���ɣ������ظ�Ͷ��
  if (Msg.FAction in FILE_CHUNK_ACTIONS) then
    Msg.ModifyMessageId;  // �������޸� MsgId

  if Assigned(FConnection.FOnAddWork) then
    FConnection.FOnAddWork(Self, Msg);

  FLock.Acquire;
  try
    if (Msg.FState = msDefault) then
      ClearArrayMsgId;
    FMsgList.Add(Msg);
  finally
    FLock.Release;
  end;

  Activate;  // �����߳�
end;

procedure TSendThread.AfterWork;
begin
  // ֹͣ�̣߳��ͷ���Դ
  SetLength(FCancelIds, 0);
  CloseHandle(FWaitSemaphore);
  ClearMsgList;
  FMsgList.Free;
  FLock.Free;
  FSender.Free;
end;

constructor TSendThread.Create(AConnection: TInConnection);
begin
  inherited Create;
  // �źŵ�
  FWaitSemaphore := CreateSemaphore(Nil, 0, 1, Nil);

  FConnection := AConnection;
  FLock := TThreadLock.Create; // ��
  FMsgList := TInList.Create;  // ���������

  FSender := TClientTaskSender.Create;   // ��������
  FSender.Socket := FConnection.Socket;  // �����׽���

  FSender.AfterSend := OnDataSend;  // �����¼�
  FSender.OnError := OnSendError;  // �����쳣�¼�
end;

procedure TSendThread.CancelWork(MsgId: TIOCPMsgId);
var
  i: Integer;
  Msg: TClientParams;
begin
  // ȡ�����ͱ��Ϊ MsgId ����Ϣ
  FLock.Acquire;
  try
    // 1. �� MsgId ��������
    AddCancelMsgId(MsgId);

    // 2. �����б����Ϣ
    for i := 0 to FMsgList.Count - 1 do
    begin
      Msg := FMsgList.Items[i];
      if (Msg.FMsgId = MsgId) then
      begin
        Msg.FState := msCancel;
        Break;
      end;
    end;
    
    // 3. ���ڷ��͵���Ϣ���ϵ㴫��ʱ�ٷ���ʱȡ����
    // ���ش��ļ�ʱ������˲��Ϸ������ݣ��ͻ���ֻ�ܶϿ�����
    if Assigned(FMsgPack) and (FMsgPack.FMsgId = MsgId) then
    begin
      FMsgPack.FState := msCancel;
      if not (FMsgPack.Action in FILE_CHUNK_ACTIONS) then
      begin
        FSender.Stoped := True;
        ServerReturn;
      end;
    end;

  finally
    FLock.Release;
  end;

end;

procedure TSendThread.ClearAllWorks(var ACount: Integer);
begin
  // ����մ�����Ϣ����Ӱ��������ݣ�
  FLock.Acquire;
  try
    ACount := FMsgList.Count;  // ȡ����
    if Assigned(FMsgPack) then
    begin
      Inc(ACount);
      FMsgPack.FState := msCancel;
      FSender.Stoped := True;  // ֹͣ
      ServerReturn;  // ���Եȴ�
    end;
    ClearMsgList;
  finally
    FLock.Release;
  end;
end;

procedure TSendThread.ClearMsgList;
var
  i: Integer;
begin
  // �ͷ��б��ȫ����Ϣ
  for i := 0 to FMsgList.Count - 1 do
    TClientParams(FMsgList.PopFirst).Free;
  if Assigned(FMsgPack) then
    FMsgPack.Free;
end;

procedure TSendThread.DoMethod;
begin
  // ѭ��ִ������

  // ����������״̬
  InterlockedExchange(FGetFeedback, 1);

  // δֹͣ��ȡ����ɹ� -> ����
  while not Terminated and
        FConnection.FActive and GetWork() do
    try
      InternalSend;  // ����
    except
      on E: Exception do
      begin
        FConnection.FErrMsg := E.Message;
        FConnection.FErrorcode := GetLastError;
        Synchronize(FConnection.DoThreadFatalError);
      end;
    end;

  // ����Ƿ��з�����FGetFeedback > 0
  if (InterlockedDecrement(FGetFeedback) < 0) then  // �������Ӧ��
  begin
    FConnection.FActResult := arErrNoAnswer;
    Synchronize(FConnection.DoThreadFatalError);  // ���� Synchronize����ͬ�̣߳�
  end;

end;

function TSendThread.GetCount: Integer;
begin
  // ȡ������
  FLock.Acquire;
  try
    Result := FMsgList.Count;
  finally
    FLock.Release;
  end;
end;

function TSendThread.GetWork: Boolean;
var
  i: Integer;
begin
  // ���б���ȡһ����Ϣ
  FLock.Acquire;
  try
    if Terminated or (FMsgList.Count = 0) or Assigned(FMsgPack) then
      Result := False
    else begin
      // ȡδֹͣ������
      for i := 0 to FMsgList.Count - 1 do
      begin
        FMsgPack := TClientParams(FMsgList.PopFirst);  // ����
        if (FMsgPack.FState = msCancel) or InCancelArray(FMsgPack.FMsgId) then
        begin
          FMsgPack.Free;
          FMsgPack := nil;
        end else
          Break;
      end;
      if Assigned(FMsgPack) then
      begin
        FConnection.FPostThread.SetMsgPack(FMsgPack);  // ��ǰ��Ϣ
        FSender.Stoped := False;  // �ָ�
        Result := True;
      end else
      begin
        FConnection.FPostThread.SetMsgPack(nil);
        Result := False;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

function TSendThread.GetWorkState: Boolean;
begin
  // ȡ����״̬���̡߳�������δֹͣ
  FLock.Acquire;
  try
    Result := (Terminated = False) and (FSender.Stoped = False);
  finally
    FLock.Release;
  end;
end;

function TSendThread.InCancelArray(MsgId: TIOCPMsgId): Boolean;
var
  i: Integer;
begin
  // ����Ƿ�Ҫֹͣ
  FLock.Acquire;
  try
    Result := Assigned(FMsgPack) and
             (FMsgPack.FMsgId = MsgId) and
             (FMsgPack.FState = msCancel);
    if (Result = False) and (FCancelIds <> nil) then
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

procedure TSendThread.IniWaitState;
begin
  // ��ʼ���ȴ�����
  InterlockedExchange(FGetFeedback, 0); // δ�յ�����
  InterlockedExchange(FWaitState, 0); // ״̬=0
end;

procedure TSendThread.InternalSend;

  procedure SendMsgHeader;
  begin
    IniWaitState;  // ׼���ȴ�

    // ������Ϣ�ܳ���
    FMsgId := FMsgPack.MsgId;
    FTotalSize := FMsgPack.GetMsgSize(False);

    // �ϵ�����ʱҪ��λ��
    if (FMsgPack.FAction in FILE_CHUNK_ACTIONS) then
      FCurrentSize := FMsgPack.FOffset
    else
      FCurrentSize := 0;
      
    // ����Э��ͷ+У����+�ļ�����
    FMsgPack.LoadHead(FSender.Data);

    FSender.DataType := mdtHead;  // ��Ϣͷ
    FSender.SendBuffers;
  end;

  procedure SendMsgEntity;
  begin
    FSender.DataType := mdtEntity;  // ��Ϣʵ��
    FSender.Send(FMsgPack.FMain, FMsgPack.FDataSize, False);  // ���ͷ���Դ
  end;

  procedure SendMsgAttachment;
  begin
    // ���͸�������(���ر���Դ)
    IniWaitState;  // ׼���ȴ�
    FSender.DataType := mdtAttachment;  // ��Ϣ����
    if (FMsgPack.FAction = atFileUpChunk) then  // �ϵ�����
      FSender.Send(FMsgPack.FAttachment, FMsgPack.FAttachSize,
                   FMsgPack.FOffset, FMsgPack.FOffsetEnd, False)
    else
      FSender.Send(FMsgPack.FAttachment, FMsgPack.FAttachSize, False);
  end;

begin
  // ִ�з�������, �����˷�������
  //   ����TReturnResult.ReturnResult��TDataReceiver.Prepare
  try
    FSender.Owner := FMsgPack;  // ����
    FMsgPack.FSessionId := FConnection.FSessionId; // ��¼ƾ֤

    // 1. ����·��
    if (FMsgPack.LocalPath <> '') then
      FConnection.FRecvThread.FReceiver.LocalPath := AddBackslash(FMsgPack.LocalPath)
    else
      FConnection.FRecvThread.FReceiver.LocalPath := AddBackslash(FConnection.FLocalPath);

    // 2. ׼��������
    FMsgPack.CreateStreams(False);  // ���������

    if not FMsgPack.Error then
    begin
      // 3. ��Э��ͷ
      SendMsgHeader;

      // 4. �������ݣ��ڴ�����
      if (FMsgPack.FDataSize > 0) then
        SendMsgEntity;

      // 5. �ȴ�����
      if GetWorkState then
        WaitForFeedback;

      // 6. ���͸�����
      if (FMsgPack.FAttachSize > 0) and
         (FMsgPack.FActResult = arAccept) then
      begin
        SendMsgAttachment;  // 6.1 ����
        if GetWorkState then
          WaitForFeedback;  // 6.2 �ȴ�����
      end;
    end;
  finally
    // 7. �ͷţ�
    FLock.Acquire;
    try
      FMsgPack.Free;
      FMsgPack := nil;
    finally
      FLock.Release;
    end;
  end;
end;

procedure TSendThread.KeepWaiting;
begin
  // �����ȴ�: FWaitState = 1 -> +1
  InterlockedIncrement(FGetFeedback); // �յ�����
  if (iocp_api.InterlockedCompareExchange(FWaitState, 2, 1) = 1) then  // ״̬+
    ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // ����
end;

procedure TSendThread.OnDataSend(DataType: TMessageDataType; OutSize: Integer);
begin
  // ���ݳɹ���������ʾ����
  Inc(FCurrentSize, OutSize);

  // �Ƿ���ʾ���ͽ���:
  // ֻ����Ϣͷ��û�и��������Ǹ����� -> ��ʾ
  if (DataType = mdtHead) and (FMsgPack.FDataSize = 0) and (FMsgPack.AttachSize = 0) or
     (DataType = mdtEntity) and (FMsgPack.AttachSize = 0) or
     (DataType = mdtAttachment) then
    Synchronize(FConnection.SendProgress);
end;

procedure TSendThread.OnSendError(Sender: TObject);
begin
  // �������쳣
  if (GetWorkState = False) then  // ȡ������
  begin
    ServerReturn;  // ���Եȴ�
    FConnection.FRecvThread.FReceiver.Reset;
  end;
  FConnection.FErrorcode := TClientTaskSender(Sender).ErrorCode;
  Synchronize(FConnection.DoThreadFatalError); // �߳�ͬ��
end;

procedure TSendThread.ServerReturn;
begin
  // ���������� �� ���Եȴ�
  //  1. ȡ��������յ�����
  //  2. �յ���������δ�ȴ������������ȵȴ��磩
  InterlockedIncrement(FGetFeedback); // �յ�����
  if (InterlockedDecrement(FWaitState) = 0) then  // 1->0
    ReleaseSemaphore(FWaitSemaphore, 1, Nil);  // �ź���+1
end;

procedure TSendThread.WaitForFeedback;
begin
  // �ȷ������������� WAIT_MILLISECONDS ����
  if (InterlockedIncrement(FWaitState) = 1) then
    repeat
      WaitForSingleObject(FWaitSemaphore, WAIT_MILLISECONDS);
    until (InterlockedDecrement(FWaitState) <= 0);
end;

{ TPostThread }

procedure TPostThread.Add(Result: TReceivePack);
begin
  // ��һ����Ϣ���б������߳�

  // 1. ��鸽���������
  if (Result.ActResult = arAccept) then   // ��������������
  begin
    FMsgPack.FActResult := arAccept;      // FMsgPack �ڵȴ�
    FResultEx := TResultParams(Result);   // �ȱ��淴�����
    FConnection.FSendThread.ServerReturn; // ����
  end else
  begin
    // 2. Ͷ�����̶߳���
    // ������ʱ�����������յ��㲥��Ϣ��
    // ��ʱ FMsgPack=nil��δ��¼��һ��Ͷ��
    FLock.Acquire;
    try
      if Assigned(FResultEx) and
        (FResultEx.FMsgId = Result.MsgId) then // ���͸�����ķ���
      begin
        Result.Free;         // �ͷŸ����ϴ�����������ݣ�
        Result := FResultEx; // ʹ�������ķ�����Ϣ�������ݣ�
        FResultEx.FActResult := arOK;  // �޸Ľ�� -> �ɹ�
        FResultEx := nil;    // ������
      end;
      // �����б�
      FResults.Add(Result);
    finally
      FLock.Release;
    end;

    Activate;  // ����
  end;
end;

procedure TPostThread.AfterWork;
var
  i: Integer;
begin
  // �����Ϣ
  for i := 0 to FResults.Count - 1 do
    TResultParams(FResults.PopFirst).Free;
  FLock.Free;
  FResults.Free;
  inherited;
end;

constructor TPostThread.Create(AConnection: TInConnection);
begin
  inherited Create;
  FreeOnTerminate := True;
  FConnection := AConnection;
  FLock := TThreadLock.Create; // ��
  FResults := TInList.Create;  // �յ�����Ϣ�б�
end;

procedure TPostThread.DoMethod;
var
  Result: TResultParams;
begin
  // ѭ��ȡ���������յ�����Ϣ
  while (Terminated = False) do
  begin
    FLock.Acquire;
    try
      Result := FResults.PopFirst;  // ȡ����һ��
    finally
      FLock.Release;
    end;
    if Assigned(Result) then
      HandleMessage(Result) // ������Ϣ
    else
      Break;
  end;
end;

procedure TPostThread.ExecInMainThread;
const
  SERVER_PUSH_EVENTS =[arDeleted, arRefuse { ��Ӧ�ô��� }, arTimeOut];
  SELF_ERROR_RESULTS =[arOutDate, arRefuse { c/s ģʽ���� }, arErrBusy,
                       arErrHash, arErrHashEx, arErrAnalyse, arErrPush,
                       arErrUser, arErrWork];

  function IsPushedMessage: Boolean;
  begin
    FLock.Acquire;
    try
      Result := (FOwner = nil) or (FMsgPack = nil) or
                (FResult.Owner <> LongWord(FOwner));
    finally
      FLock.Release;
    end;
  end;

  function IsFeedbackMessage: Boolean;
  begin
    FLock.Acquire;
    try
      Result := (FMsgPack <> nil) and (FMsgPack.MsgId = FResult.MsgId);
    finally
      FLock.Release;
    end;
  end;

begin
  // �������̣߳�����Ϣ�ύ������

  try

    if IsPushedMessage() then

    {$IFNDEF DELPHI_7}
    {$REGION '. ����������Ϣ'}
    {$ENDIF}

    try
      if (FResult.ActResult in SERVER_PUSH_EVENTS) then
      begin
        // 3.4 ���������͵���Ϣ
        FConnection.DoServerError(FResult);
      end else
      begin
        // 3.5 �����ͻ������͵���Ϣ
        FConnection.HandlePushedMsg(FResult);
      end;
    finally
      FResult.Free;
    end

    {$IFNDEF DELPHI_7}
    {$ENDREGION}
    {$ENDIF}

    else  // ====================================

    {$IFNDEF DELPHI_7}
    {$REGION '. �Լ������ķ�����Ϣ'}
    {$ENDIF}

    try
      // ������¼�����±��ص�ƾ֤
      if (FConnection.FSessionId <> FResult.FSessionId) then
        FConnection.FSessionId := FResult.FSessionId;

      if (FResult.ActResult in SELF_ERROR_RESULTS) then
      begin
        // 3.1 ����ִ���쳣
        FConnection.DoServerError(FResult);  // ��������
      end else
      if IsFeedbackMessage() then
      begin
        // 3.2 �����������
        FOwner.HandleFeedback(FResult); // �����ͻ���
      end else
      begin
        // 3.3 MsgId ��������޸ģ��Լ����͵���Ϣ
        FConnection.HandlePushedMsg(FResult)
      end;
    finally
      if FConnection.FActive and IsFeedbackMessage() then
        FConnection.FSendThread.ServerReturn;  // ����
      FResult.Free;
    end;

    {$IFNDEF DELPHI_7}
    {$ENDREGION}
    {$ENDIF}

  except
    on E: Exception do
    begin
      FConnection.FErrMsg := E.Message;
      FConnection.FErrorcode := GetLastError;
      FConnection.DoThreadFatalError;  // �����̣߳�ֱ�ӵ���
    end;
  end;

end;

procedure TPostThread.HandleMessage(Result: TReceivePack);
var
  StopAction, ReadInfDone: Boolean;
  Msg: TMessagePack;
begin
  // Ԥ������Ϣ
  // ���Ҫ�ύ�����߳�ִ�У�Ҫ���ϵ����������

  FResult := TResultParams(Result);
  StopAction := False;

  if FConnection.FSendThread.InCancelArray(FResult.FMsgId) then
  begin
    FResult.Free;  // �������û���ֹ
    StopAction := True;
  end else
  if (FResult.FAction in FILE_CHUNK_ACTIONS) then
  begin
    // ��������
    Msg := TMessagePack.Create(TBaseClientObject(FResult.Owner));
    Msg.FState := msAutoPost;  // �Զ��ύ

    Msg.FAction := atUnknown;  // δ֪
    Msg.FActResult := FResult.FActResult; // ���͸�����ķ������
    Msg.FCheckType := FResult.FCheckType;
    Msg.FZipLevel := FResult.FZipLevel;

    if (FResult.FAction = atFileUpChunk) then
    begin
      // �ϵ��ϴ������̴򿪱����ļ������ļ���Ϣ
      //   ����TBaseMessage.LoadFromFile��TReceiveParams.CreateAttachment
      Msg.LoadFromFile(FResult.GetAttachFileName, True);
      ReadInfDone := not Msg.Error and Msg.ReadUploadInf(FResult);
    end else
    begin
      // �ϵ����أ����������ļ�������
      // FActResult һ����������Ҳ����У���쳣
      //   ����TReturnResult.LoadFromFile��TResultParams.CreateAttachment
      Msg.FileName := FResult.FileName;
      ReadInfDone := Msg.ReadDownloadInf(FResult);
    end;

    if ReadInfDone then
      Msg.Post(FResult.FAction)
    else begin
      Msg.Free;
      FResult.Free;
      StopAction := True;
    end;
  end;

  if (StopAction = False) then
    Synchronize(ExecInMainThread)  // ����Ӧ�ò�
  else
    FConnection.FSendThread.ServerReturn;

end;

procedure TPostThread.SetMsgPack(AMsgPack: TClientParams);
begin
  // ���õ�ǰ��Ϣ������ǰ�Ѽ�����
  FLock.Acquire;
  try
    FResultEx := nil;
    FMsgPack := AMsgPack; // ��ǰ������Ϣ��
    if Assigned(FMsgPack) then
      FOwner := TBaseClientObject(FMsgPack.Owner)  // ��ǰ��Ϣ������
    else
      FOwner := nil;
  finally
    FLock.Release;
  end;
end;

// ================== �����߳� ==================

// ʹ�� WSARecv �ص�������Ч�ʸ�
procedure WorkerRoutine(const dwError, cbTransferred: DWORD;
  const lpOverlapped: POverlapped; const dwFlags: DWORD); stdcall;
var
  Thread: TRecvThread;
  Connection: TInConnection;
  ByteCount, Flags: DWORD;
  ErrorCode: Cardinal;
begin
  // �������߳� ��
  // ����� lpOverlapped^.hEvent = TInRecvThread

  Thread := TRecvThread(lpOverlapped^.hEvent);
  Connection := Thread.FConnection;

  if (dwError <> 0) or (cbTransferred = 0) then // �Ͽ����쳣
  begin
    // ����˹ر�ʱ cbTransferred = 0, Ҫ�Ͽ����ӣ�2019-02-28
    if (cbTransferred = 0) then
      Thread.Synchronize(Connection.TryDisconnect); // ͬ��
    Exit;
  end;

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
        Thread.Synchronize(Connection.DoThreadFatalError); // �߳�ͬ��
      end;
    end;
  end;
end;

{ TRecvThread }

constructor TRecvThread.Create(AConnection: TInConnection);
{ var
  i: Integer; }
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FConnection := AConnection;

  // ������ջ���
  GetMem(FRecvBuf.buf, IO_BUFFER_SIZE_2);
  FRecvBuf.len := IO_BUFFER_SIZE_2;

  // ��Ϣ�������������� TResultParams
  FReceiver := TClientReceiver.Create(TResultParams);

  FReceiver.OnError := OnError;  // У���쳣�¼�
  FReceiver.OnPost := FConnection.FPostThread.Add; // Ͷ�ŷ���
  FReceiver.OnReceive := OnDataReceive; // ���ս���

{  FDebug.LoadFromFile('recv\pn2.txt');
  FStream.LoadFromFile('recv\recv2.dat');

  for i := 0 to FDebug.Count - 1 do
  begin
    FOverlapped.InternalHigh := StrToInt(FDebug[i]);
    if FOverlapped.InternalHigh = 93 then
      FStream.Read(FRecvBuf.buf^, FOverlapped.InternalHigh)
    else
      FStream.Read(FRecvBuf.buf^, FOverlapped.InternalHigh);
    HandleDataPacket;
  end;

  ExtrMsg.SaveToFile('msg.txt');    }

end;

procedure TRecvThread.Execute;
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

    while (Terminated = False) do  // ���ϵȴ�
      if (SleepEx(100, True) = WAIT_IO_COMPLETION) then  // �����������ȴ�ģʽ
      begin
        // Empty
      end;
  finally
    FreeMem(FRecvBuf.buf);
    FReceiver.Free;
  end;

end;

procedure TRecvThread.HandleDataPacket;
begin
  // ������յ������ݰ�

  // �����ֽ�����
  Inc(FConnection.FRecvCount, FOverlapped.InternalHigh);

//  FDebug.Add(IntToStr(FOverlapped.InternalHigh));
//  FStream.Write(FRecvBuf.buf^, FOverlapped.InternalHigh);

  if FReceiver.Complete then  // 1. �װ�����
  begin
    // 1.1 ������ͬʱ���� HTTP ����ʱ�����ܷ����ܾ�������Ϣ��HTTPЭ�飩
    if MatchSocketType(FRecvBuf.buf, HTTP_VER) then
    begin
      TResultParams(FReceiver.Owner).FActResult := arRefuse;
      FConnection.DoServerError(TResultParams(FReceiver.Owner));
      Exit;
    end;

    // 1.2 C/S ģʽ����
    if (FOverlapped.InternalHigh < IOCP_SOCKET_SIZE) or  // ����̫��
      (MatchSocketType(FRecvBuf.buf, IOCP_SOCKET_FLAG) = False) then // C/S ��־����
    begin
      TResultParams(FReceiver.Owner).FActResult := arErrInit;  // ��ʼ���쳣
      FConnection.DoServerError(TResultParams(FReceiver.Owner));
      Exit;
    end;

    if (FReceiver.Owner.ActResult <> arAccept) then
      FReceiver.Prepare(FRecvBuf.buf, FOverlapped.InternalHigh)  // ׼������
    else begin
      // �ϴ�������ո������ٴ��յ�������������ϵķ���
      TResultParams(FReceiver.Owner).FActResult := arOK; // Ͷ��ʱ��Ϊ arAccept, �޸�
      FReceiver.PostMessage;  // ��ʽͶ��
    end;

  end else
  begin
    // 2. ��������
    FReceiver.Receive(FRecvBuf.buf, FOverlapped.InternalHigh);
  end;

end;

procedure TRecvThread.OnError(Result: TReceivePack);
begin
  // У���쳣
  TResultParams(Result).FActResult := arErrHashEx;
end;

procedure TRecvThread.OnDataReceive(Result: TReceivePack; DataType: TMessageDataType;
   ReceiveCount: TFileSize; AttachFinished: Boolean);
begin
  // ��ʾ���ս���
  // �����ǽ�����ϲŵ��ã�ֻһ��
  case DataType of
    mdtHead,
    mdtEntity: begin
      FRecvMsg := Result;
      FMsgId := FRecvMsg.MsgId;
      FTotalSize := FRecvMsg.GetMsgSize(True);
      FCurrentSize := ReceiveCount;

      // �л������߳�, ִ��һ��
      if (FRecvMsg.AttachSize = 0) then
        Synchronize(FConnection.ReceiveProgress);
    end;

    mdtAttachment: begin
      // �Ѿ�ȫ��������ϣ��ϵ㴫��ʱ��
      // ��Ϊ����Ϣ������������ʾ�����ݳ���δ�� = ��������
      if (FRecvMsg.Action in FILE_CHUNK_ACTIONS) then
      begin
        FCurrentSize := FRecvMsg.Offset + ReceiveCount;
      end else
      begin
        if (ReceiveCount = 0) then
          FCurrentSize := FTotalSize
        else
          FCurrentSize := ReceiveCount;
      end;

      // ������Ҫ�����ȴ����л������߳�
      FConnection.FSendThread.KeepWaiting;
      Synchronize(FConnection.ReceiveProgress);
    end;
  end;
end;

procedure TRecvThread.Stop;
begin
  inherited;
  Sleep(10);
end;

initialization
//  ExtrMsg := TStringList.Create;
//  FDebug := TStringList.Create;
//  FStream := TMemoryStream.Create;



finalization
//  FDebug.SaveToFile('msid.txt');
//  FStream.SaveToFile('recv2.dat');

// ExtrMsg.Free;
//  FStream.Free;
//  FDebug.Free;

end.

