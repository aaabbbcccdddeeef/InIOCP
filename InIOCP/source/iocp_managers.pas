(*
 * ����˸��ֹ�������Ԫ
 *)
unit iocp_managers;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes, System.SysUtils, {$ELSE}
  Windows, Classes, SysUtils, {$ENDIF}
  iocp_winSock2, iocp_base, iocp_log, iocp_baseObjs,
  iocp_objPools, iocp_lists, iocp_sockets, iocp_msgPacks,
  iocp_utils, iocp_baseModule, http_base, http_objects;

type

  // C/S ģʽ�����¼�
  TRequestEvent = procedure(Sender: TObject;
                            Params: TReceiveParams;
                            Result: TReturnResult) of object;

  // =================== �û������������� ===================

  // �û���¼������������Ϣ

  TWorkEnvironment = class(TStringHash)
  private
    function Logined(const UserName: String): Boolean; overload;
    function Logined(const UserName: String; var Socket: TObject): Boolean; overload;
  protected
    procedure FreeItemData(Item: PHashItem); override;
  public
    constructor Create;
    destructor Destroy; override;
  end;
  
  // ================== ������ ���� ======================

  // ���Ӹ����¼�
  TAttachmentEvent = procedure(Sender: TObject; Params: TReceiveParams) of object;

  TBaseManager = class(TComponent)
  protected    
    FServer: TObject;  // TInIOCPServer ������
  private
    FOnAttachBegin: TAttachmentEvent;  // ׼�����ո���
    FOnAttachFinish: TAttachmentEvent; // �����������
    function GetGlobalLock: TThreadLock; {$IFDEF USE_INLINE} inline; {$ENDIF}
  protected
    procedure Execute(Socket: TIOCPSocket); virtual; abstract;
  protected
    property OnAttachBegin: TAttachmentEvent read FOnAttachBegin write FOnAttachBegin;
    property OnAttachFinish: TAttachmentEvent read FOnAttachFinish write FOnAttachFinish;
  public
    procedure AddToBackground(Socket: TBaseSocket);  // ��ִ̨��
    procedure Wakeup(Socket: TBaseSocket);  // ��ִ̨����Ϻ󣬻��ѿͻ���
  public
    property GlobalLock: TThreadLock read GetGlobalLock;
  end;

  // ================== ��������� �� ======================

  TDataInEvent   = procedure(Socket: TStreamSocket; const Data: PAnsiChar; Size: Cardinal; var Completed: Boolean) of object;
  TCopyDataEvent = procedure(Socket: TStreamSocket; const ABuffers: PAnsiChar) of object;

  TInStreamManager = class(TBaseManager)
  private
    FClientId: string;         // �����ҵĿͻ���
    FOnReceive: TDataInEvent;  // �����������¼�
    function CheckState(const AClientId: String; var ASocket: TStreamSocket): Boolean; overload;
    procedure CallbackMethod(ObjType: TObjectType; var FromObject: Pointer;
                             const Data: TObject; var CancelScan: Boolean);
    procedure InterPushText(AOwner, ATarget: TStreamSocket; const AText: AnsiString = '');
  protected
    procedure Execute(Socket: TIOCPSocket); override;
  public
    function Logined(const AClientId: String): Boolean;
    function GetClientData(const AClientId: String; ABuffers: PAnsiChar; AEvent: TCopyDataEvent): Boolean;
    procedure Broadcast(AOwner: TStreamSocket; const AText: string = '');
    procedure SendTo(AOwner: TStreamSocket; const AToClient: string; const AText: string = '');
  published
    property OnReceive: TDataInEvent read FOnReceive write FOnReceive;
  end;

  // ================== �ͻ��˹��� �� ======================

  // �����û����ơ�Ȩ�ޣ���ѯ... ...

  TInClientManager = class(TBaseManager)
  private
    FClientList: TWorkEnvironment;    // �ͻ��˹��������б�
    FOnLogin: TRequestEvent;          // ��¼�¼�
    FOnLogout: TRequestEvent;         // �ǳ��¼�
    FOnDelete: TRequestEvent;         // ɾ���ͻ���
    FOnModify: TRequestEvent;         // �޸Ŀͻ���
    FOnRegister: TRequestEvent;       // ע��ͻ���
    FOnQueryState: TRequestEvent;     // ��ѯ�ͻ���״̬
    procedure CopyClientInf(ObjType: TObjectType; var Buffer: Pointer;
                            const Data: TObject; var CancelScan: Boolean);
    procedure GetClients(Result: TReturnResult);
    procedure GetConnectedClients(Result: TReturnResult);
    procedure GetLoginedClients(Result: TReturnResult);
  protected
    procedure Execute(Socket: TIOCPSocket); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    procedure Clear;
    procedure Add(IOCPSocket: TIOCPSocket; ClientRole: TClientRole = crClient);
    procedure Disconnect(const UserName: String);
    procedure GetClientState(const UserName: String; Result: TReturnResult);
    procedure RemoveClient(const UserName: string);
  public
    function Logined(const UserName: String): Boolean; overload;
    function Logined(const UserName: String; var Socket: TIOCPSocket): Boolean; overload;
  published
    property OnDelete: TRequestEvent read FOnDelete write FOnDelete;
    property OnModify: TRequestEvent read FOnModify write FOnModify;
    property OnLogin: TRequestEvent read FOnLogin write FOnLogin;
    property OnLogout: TRequestEvent read FOnLogout write FOnLogout;
    property OnRegister: TRequestEvent read FOnRegister write FOnRegister;
    property OnQueryState: TRequestEvent read FOnQueryState write FOnQueryState;
  end;

  // ================== ��Ϣ������ ======================

  TInMessageManager = class(TBaseManager)
  private
    FMsgWriter: TMessageWriter;  // ��Ϣ��д��
    FOnBroadcast: TRequestEvent; // �㲥
    FOnGet: TRequestEvent;       // ȡ������Ϣ
    FOnListFiles: TRequestEvent; // ȡ������Ϣ�ļ��б�
    FOnPush: TRequestEvent;      // ����
    FOnReceive: TRequestEvent;   // �յ���Ϣ
    procedure InterCopyPush(ASource, ATarget: TIOCPSocket; AResult: TReturnResult;
                            AToSockets: TInList = nil; CastType: TBroadcastType = btUnknown);
    procedure InterPushMsg(ASource, ATarget: TIOCPSocket; AToSockets: TInList = nil;
                           CastType: TBroadcastType = btUnknown);
    procedure InterPushResultMsg(Socket: TIOCPSocket; Result: TReturnResult;
                                 UserNameList: AnsiString);
    procedure InterSavePushMsg(AOwner: TIOCPSocket; PushMsg: TInList; UserNameList: AnsiString);
  protected
    procedure Execute(Socket: TIOCPSocket); override;
  public
    destructor Destroy; override;
    procedure CreateMsgWriter(SurportHttp: Boolean);

    // �㲥����Ȩ������
    procedure Broadcast(AMsg: TReceiveParams); overload;
    procedure Broadcast(AMsg: TReturnResult); overload;
    procedure Broadcast(AOwner: TIOCPSocket; const AMsg: String); overload;

    // ������Ϣ��ָ���ͻ��ˣ���Ȩ�����ƣ�AUserNameListΪ��ʱ�㲥��
    procedure PushMsg(AMsg: TReceiveParams; const AUserNameList: String = ''); overload;
    procedure PushMsg(AMsg: TReturnResult; const AUserNameList: String = ''); overload;
    procedure PushMsg(AOwner: TIOCPSocket; const AMsg: String; const AUserNameList: String = ''); overload;

    // ������Ϣ��ȫ������Ա
    procedure PushToAdmin(AMsg: TReceiveParams); overload;
    procedure PushToAdmin(AMsg: TReturnResult); overload;
    procedure PushToAdmin(AOwner: TIOCPSocket; const AMsg: String); overload;

    // ��д������Ϣ�ļ�
    procedure ReadMsgFile(Params: TReceiveParams; Result: TReturnResult);
    procedure SaveMsgFile(Params: TReceiveParams; IODataSource: Boolean = True);
  published
    property OnBroadcast: TRequestEvent read FOnBroadcast write FOnBroadcast;
    property OnGet: TRequestEvent read FOnGet write FOnGet;
    property OnListFiles: TRequestEvent read FOnListFiles write FOnListFiles;
    property OnPush: TRequestEvent read FOnPush write FOnPush;
    property OnReceive: TRequestEvent read FOnReceive write FOnReceive;
  end;

  // ================== �ļ������� ======================

  TFileUpDownEvent = procedure(Sender: TObject; Params: TReceiveParams;
                               Document: TIOCPDocument) of object;

  TInFileManager = class(TBaseManager)
  private
    FAfterDownload: TFileUpDownEvent;  // �ļ��������
    FAfterUpload: TFileUpDownEvent;    // �ļ��ϴ����
    FBeforeUpload: TRequestEvent;      // �ϴ��ļ�
    FBeforeDownload: TRequestEvent;    // �����ļ�
    
    FOnDeleteDir: TRequestEvent;       // ɾ��Ŀ¼
    FOnDeleteFile: TRequestEvent;      // ɾ���ļ�
    FOnMakeDir: TRequestEvent;         // �½�Ŀ¼
    FOnQueryFiles: TRequestEvent;      // ��ѯĿ¼���ļ�
    FOnRenameDir: TRequestEvent;       // ������Ŀ¼
    FOnRenameFile: TRequestEvent;      // �������ļ�
    FOnSetWorkDir: TRequestEvent;      // ���õ�ǰĿ¼
  protected
    procedure Execute(Socket: TIOCPSocket); override;
  public
    procedure CreateNewFile(Params: TReceiveParams);
    procedure ListFiles(Params: TReceiveParams; Result: TReturnResult; MsgFiles: Boolean = False); overload;
    procedure ListFiles(Result: TResultJSON; const Path: String); overload;
    procedure MakeDir(Params: TReceiveParams; Result: TReturnResult; const Path: String);
    procedure OpenLocalFile(Result: TReturnResult; const FileName: String = '');
    procedure SetWorkDir(Result: TReturnResult; const Dir: String);
  published
    property AfterDownload: TFileUpDownEvent read FAfterDownload write FAfterDownload;
    property AfterUpload: TFileUpDownEvent read FAfterUpload write FAfterUpload;
    property BeforeUpload: TRequestEvent read FBeforeUpload write FBeforeUpload;
    property BeforeDownload: TRequestEvent read FBeforeDownload write FBeforeDownload;
  published
    property OnDeleteDir: TRequestEvent read FOnDeleteDir write FOnDeleteDir;
    property OnDeleteFile: TRequestEvent read FOnDeleteFile write FOnDeleteFile;
    property OnMakeDir: TRequestEvent read FOnMakeDir write FOnMakeDir;
    property OnQueryFiles: TRequestEvent read FOnQueryFiles write FOnQueryFiles;
    property OnRenameDir: TRequestEvent read FOnRenameDir write FOnRenameDir;
    property OnRenameFile: TRequestEvent read FOnRenameFile write FOnRenameFile;
    property OnSetWorkDir: TRequestEvent read FOnSetWorkDir write FOnSetWorkDir;
  end;

  // ================== ���ݿ������ ======================

  TInDatabaseManager = class(TBaseManager)
  private
    // ֧�ֶ�����ݿ�ģ��
    FDataModuleList: TInStringList;    // ���ݿ�ģ���
    function GetDataModuleCount: Integer;
    procedure DBConnect(Socket: TIOCPSocket);
    procedure GetDBConnections(Socket: TIOCPSocket);
  protected
    procedure Execute(Socket: TIOCPSocket); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    procedure Clear;
    procedure AddDataModule(ADataModule: TDataModuleClass; const ADescription: String);
    procedure GetDataModuleState(Index: Integer; var AClassName, ADescription: String; var ARunning: Boolean);
    procedure RemoveDataModule(Index: Integer);
    procedure ReplaceDataModule(Index: Integer; ADataModule: TDataModuleClass; const ADescription: String);
  public
    property DataModuleList: TInStringList read FDataModuleList;
    property DataModuleCount: Integer read GetDataModuleCount;
  end;

  // ================== �Զ�������� ======================

  TInCustomManager = class(TBaseManager)
  private
    FFunctions: TInStringList;    // �����б�
    FOnReceive: TRequestEvent;    // �����¼�
  protected
    procedure Execute(Socket: TIOCPSocket); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property OnReceive: TRequestEvent read FOnReceive write FOnReceive;
  published
    property OnAttachBegin;
    property OnAttachFinish;
  end;

  // ================== Զ�̺����� ======================

  TInRemoteFunctionGroup = class(TBaseManager)
  private
    FFuncGroupName: String;              // ����������
    FCustomManager: TInCustomManager;    // �Զ�����Ϣ����
    FOnExecute: TRequestEvent;           // ִ�з���
    procedure SetCustomManager(const Value: TInCustomManager);
  protected
    procedure Execute(Socket: TIOCPSocket); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  published
    property CustomManager: TInCustomManager read FCustomManager write SetCustomManager;
    property FunctionGroupName: String read FFuncGroupName write FFuncGroupName;
    property OnExecute: TRequestEvent read FOnExecute write FOnExecute;
  end;

  // ================== WebSocket ���� �� ======================

  TWebSocketEvent = procedure(Sender: TObject; Socket: TWebSocket) of object;

  TInWebSocketManager = class(TBaseManager)
  private
    FJSONLength: Integer;           // JSON ����
    FUserName: string;              // Ҫ���ҵ���
    FOnReceive: TWebSocketEvent;    // �����¼�
    FOnUpgrade: TOnUpgradeEvent;    // ����Ϊ WebSocket �¼�
    procedure CallbackMethod(ObjType: TObjectType; var FromObject: Pointer;
                             const Data: TObject; var CancelScan: Boolean);
    procedure InterPushMsg(Source, Target: TWebSocket); overload;
    procedure InterPushMsg(Socket: TWebSocket; OpCode: TWSOpCode;
                           const Text: AnsiString = ''; const Group: AnsiString = ''); overload;
  protected
    procedure Execute(Socket: TIOCPSocket); override;
  public
    procedure Broadcast(Socket: TWebSocket); overload;
    procedure Broadcast(const Group, Text: string; OpCode: TWSOpCode = ocText); overload;

    procedure Delete(Admin: TWebSocket; const ToUser: String);
    procedure GetUserList(Socket: TWebSocket);

    procedure SendTo(Socket: TWebSocket; const ToUser: string); overload;
    procedure SendTo(const ToUser, Text: string); overload;

    function Logined(const UserName: String; var Socket: TWebSocket): Boolean; overload;
    function Logined(const UserName: String): Boolean; overload;
  published
    property OnReceive: TWebSocketEvent read FOnReceive write FOnReceive;
    property OnUpgrade: TOnUpgradeEvent read FOnUpgrade write FOnUpgrade;
  end;

  // ================== Http ���� ======================

  TInHttpDataProvider = class(THttpDataProvider)
  private
    FRootDirectory: String;          // http �����Ŀ¼
    FWebSocketManager: TInWebSocketManager;  // WebSocket ����
    function GetGlobalLock: TThreadLock;
    procedure SetWebSocketManager(const Value: TInWebSocketManager);
  protected
    procedure Execute(Socket: THttpSocket);
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure UpdateServer;
  published
    property RootDirectory: String read FRootDirectory write FRootDirectory;
    property WebSocketManager: TInWebSocketManager read FWebSocketManager write SetWebSocketManager;
  public
    property GlobalLock: TThreadLock read GetGlobalLock;
  end;

  // ================== ������������ ======================

  // TInIOCPBroker �� TSocketBroker ���ʵ�ַ������

  TInIOCPBroker = class;

  // Ͷ���ڲ����ӵ��߳�
  TPostSocketThread = class(TThread)
  private
    FOwner: TInIOCPBroker;        // ����
  protected
    procedure Execute; override;
  end;

  // �ⲿ��������Ϣ
  TBrokenOptions = class(TPersistent)
  private
    FOwner: TInIOCPBroker;        // ����
    function GetServerAddr: string;
    function GetServerPort: Word;
    procedure CheckServerPort(const AServerAddr: string; AServerPort: Word);
    procedure SetServerAddr(const Value: string);
    procedure SetServerPort(const Value: Word);
  public
    constructor Create(AOwner: TInIOCPBroker);
  published
    property ServerAddr: string read GetServerAddr write SetServerAddr;
    property ServerPort: Word read GetServerPort write SetServerPort default 80;
  end;

  // �ⲿ��������Ϣ
  TProxyOptions = class(TBrokenOptions)
  private
    function GetConnectionCount: Word;
    procedure SetConnectionCount(const Value: Word);
  published
    property ConnectionCount: Word read GetConnectionCount write SetConnectionCount default 50;
  end;
  
  TInIOCPBroker = class(TBaseManager)
  private
    FReverseBrokers: TStrings;      // ��������б�
    FProtocol: TTransportProtocol;  // ����Э��
    FProxyType: TProxyType;         // ��������/����λ��

    FOuterServer: TProxyOptions;    // �ⲿ������Ϣ
    FInnerServer: TBrokenOptions;   // �ڲ�Ĭ�Ϸ�����

    FBrokerId: string;              // �����������־��Id��
    FDefaultInnerAddr: String;      // �ڲ�Ĭ�ϵķ�����
    FDefaultInnerPort: Word;        // �ڲ�Ĭ�ϵķ���˿�

    FServerAddr: String;            // �ⲿ��������ַ
    FServerPort: Word;              // �ⲿ�˿�
    FConnectionCount: Integer;      // ԤͶ�ŵ�������
    FCreateCount: Integer;          // ����������
    FThread: TPostSocketThread;     // Ͷ���߳�

    FOnAccept: TAcceptBroker;       // �ж��Ƿ��������
    FOnBind: TBindIPEvent;          // �󶨷�����
    FOnBeforeForwardData: TForwardDataEvent;  // ת��ǰ�¼�
    
    function GetReverseMode: Boolean;
    procedure PostConnectionsEx;
    procedure PostConnections;
    procedure InterConnectOuter(ACount: Integer);
  protected
    procedure AddConnection(Broker: TSocketBroker; const InnerId: String);
    procedure BindInnerBroker(Connection: TSocketBroker; const Data: PAnsiChar; DataSize: Cardinal);
    procedure CheckServerPort(const AServerAddr: string; AServerPort: Word);
    procedure IncOuterConnection;
    procedure Prepare;
    procedure Stop;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  public
    property ReverseMode: Boolean read GetReverseMode;
    property DefaultInnerAddr: string read FDefaultInnerAddr;
    property DefaultInnerPort: Word read FDefaultInnerPort;
    property ServerAddr: string read FServerAddr;
    property ServerPort: Word read FServerPort;
  published
    property BrokerId: string read FBrokerId write FBrokerId;
    property Protocol: TTransportProtocol read FProtocol write FProtocol default tpNone;
    property InnerServer: TBrokenOptions read FInnerServer write FInnerServer;
    property OuterServer: TProxyOptions read FOuterServer write FOuterServer;
    property ProxyType: TProxyType read FProxyType write FProxyType default ptDefault;
  published
    property OnAccept: TAcceptBroker read FOnAccept write FOnAccept;
    property OnBind: TBindIPEvent read FOnBind write FOnBind;
    property OnBeforeForwardData: TForwardDataEvent read FOnBeforeForwardData write FOnBeforeForwardData;
  end;

  // ================== ҵ��ģ������� ======================
  // v2.0 �� iocp_server ��Ԫ��������Ԫ��
  // �����ع������� Execute ������

  TBusiWorker = class(TBaseWorker)
  private
    FDMArray: array of TInIOCPDataModule; // ��ģ���飨֧�ֶ��֣�
    FDMList: TInStringList;  // ��ģע������ã�
    FDMCount: Integer;       // ��ģ����
    FDataModule: TInIOCPDataModule; // ��ǰ��ģ
    function GetDataModule(Index: Integer): TInIOCPDataModule;
    procedure SetConnection(Index: Integer);
    procedure SetDefaultDataModule;
  protected
    procedure Execute(const Socket: TIOCPSocket); override;
    procedure StreamExecute(const Socket: TStreamSocket); override;
    procedure HttpExecute(const Socket: THttpSocket); override;
    procedure WebSocketExecute(const Socket: TWebSocket); override;
  public
    constructor Create(AServer: TObject; AThreadIdx: Integer);
    destructor Destroy; override;
    procedure AddDataModule(Index: Integer);
    procedure CreateDataModules;
    procedure RemoveDataModule(Index: Integer);
  public
    property DataModule: TInIOCPDataModule read FDataModule;
    property DataModules[Index: Integer]: TInIOCPDataModule read GetDataModule;
  end;
  
implementation

uses
  iocp_Varis, iocp_server, iocp_threads, iocp_WsJSON, iocp_wsExt;

type

  TIOCPServerRef    = class(TInIOCPServer);
  TBaseSocketRef    = class(TBaseSocket);
  TReceiveParamsRef = class(TReceiveParams);
  TReturnResultRef  = class(TReturnResult);
  TIOCPSocketRef    = class(TIOCPSocket);
  TSocketBrokerRef  = class(TSocketBroker);
  TWebSocketRef     = class(TWebSocket);
  
{ TWorkEnvironment }

function TWorkEnvironment.Logined(const UserName: String): Boolean;
begin
  Result := ValueOf(UserName) <> Nil;
end;

constructor TWorkEnvironment.Create;
begin
  inherited Create;
end;

destructor TWorkEnvironment.Destroy;
begin
  inherited;
end;

procedure TWorkEnvironment.FreeItemData(Item: PHashItem);
begin
  Dispose(PEnvironmentVar(Item^.Value));
end;

function TWorkEnvironment.Logined(const UserName: String; var Socket: TObject): Boolean;
var
  Item: PEnvironmentVar;
begin
  Item := ValueOf(UserName);
  if Assigned(Item) then
  begin
    Socket := TObject(Item^.BaseInf.Socket);
    Result := Assigned(Socket);         // �������� Nil
  end else
  begin
    Socket := Nil;
    Result := False;
  end;
end;

{ TBaseManager }

procedure TBaseManager.AddToBackground(Socket: TBaseSocket);
var
 NewSocket: TBaseSocketRef;
begin
  // �������Ϊ��ִ̨�У����¼���ҵ���̣߳�
  if (Socket.Background = False) and (
     (Socket.ClassType = TIOCPSocket) or (Socket.ClassType = TWebSocket)) then
  begin
    NewSocket := Socket.ObjPool.Pop^.Data;
    NewSocket.IniSocket(FServer, 0);  // ʵ�����׽��� FSocket ����
    NewSocket.CopyResources(Socket);
    TInIOCPServer(FServer).BusiWorkMgr.AddWork(NewSocket);
  end;
end;

function TBaseManager.GetGlobalLock: TThreadLock;
begin
  // ȡȫ����
  if Assigned(FServer) then
    Result := TInIOCPServer(FServer).GlobalLock
  else
    Result := Nil;
end;

procedure TBaseManager.Wakeup(Socket: TBaseSocket);
begin
  // ��ִ̨����ϣ����ѿͻ��ˣ�����Ҫ�� UserName ��
  if Assigned(Socket) and Socket.Background then
    try
      if (Socket is TIOCPSocket) and
         Assigned(TInIOCPServer(FServer).MessageManager) then
        TInIOCPServer(FServer).MessageManager.InterPushResultMsg(
                               TIOCPSocket(TBaseSocketRef(Socket).FLinkSocket),
                               TIOCPSocket(Socket).Result, Socket.PeerIP) // PeerIP ת��Ϊ�û�����
      else
      if (Socket is TWebSocket) then
        TInIOCPServer(FServer).HttpDataProvider.WebSocketManager.SendTo(
                               TWebSocket(Socket), Socket.PeerIP); // PeerIP ת��Ϊ�û�����
    finally
      TBaseSocketRef(Socket).InterCloseSocket(Socket);
    end;
end;

{ TInStreamManager }

procedure TInStreamManager.Broadcast(AOwner: TStreamSocket; const AText: string);
begin
  if Assigned(FServer) then
    InterPushText(AOwner, nil, AText);
end;

procedure TInStreamManager.Execute(Socket: TIOCPSocket);
begin
  // Socket �� TStreamSocket
  if Assigned(FOnReceive) then
    FOnReceive(TStreamSocket(Socket),
               Socket.RecvBuf.Data.buf,
               TBaseSocket(Socket).ByteCount,
               TBaseSocketRef(Socket).FCompleted);
end;

function TInStreamManager.GetClientData(const AClientId: String;
  ABuffers: PAnsiChar; AEvent: TCopyDataEvent): Boolean;
var
  Socket: TStreamSocket;
begin
  // ���ҿͻ��� AClientId�����÷��� AEvent
  // ȡ Socket.Data������ʱ�û����壬��֪���͡���С��
  TInIOCPServer(FServer).IOCPSocketPool.Lock;
  try
    Socket := nil;
    FClientId := AClientId;  // ��������ͻ���
    TInIOCPServer(FServer).IOCPSocketPool.Scan(Pointer(Socket), CallbackMethod);
    Result := Assigned(Socket);
    if Result then
      AEvent(Socket, ABuffers);  // ���ã���֤�ڼ���״̬
  finally
    TInIOCPServer(FServer).IOCPSocketPool.UnLock;
  end;
end;

procedure TInStreamManager.InterPushText(AOwner, ATarget: TStreamSocket; const AText: AnsiString);
var
  CastType: TBroadcastType;
  Msg: TPushMessage;
begin
  // �� ATarget/ȫ���ͻ��� �����ı���Ϣ AText�������飩

  Msg := nil;
  if Assigned(ATarget) then
    CastType := btUnknown
  else
    CastType := btAllClient;
  
  case Length(AText) of
    0:
      Msg := TPushMessage.Create(AOwner.RecvBuf, CastType);
    1..IO_BUFFER_SIZE: begin
      Msg := TPushMessage.Create(AOwner.ObjPool, AOwner.BufferPool, CastType, Length(AText));
      System.Move(AText[1], Msg.PushBuf^.Data.buf^, Msg.PushBuf^.Data.len);
    end;
  end;

  // �����Լ�
  Msg.IngoreSocket := AOwner;

  if Assigned(ATarget) then  // ����Ŀ��
    Msg.Add(ATarget);

  // ����
  TInIOCPServer(FServer).PushManager.AddWork(Msg);
  
end;

procedure TInStreamManager.CallbackMethod(ObjType: TObjectType;
  var FromObject: Pointer; const Data: TObject; var CancelScan: Boolean);
begin
  // ɨ���б�Ļص��������Ѽ���
  if (TStreamSocket(Data).ClientId = FClientId) then
  begin
    FromObject := Data;
    CancelScan := True; // �˳�����
  end;
end;

function TInStreamManager.CheckState(const AClientId: String; var ASocket: TStreamSocket): Boolean;
begin
  // ���ͻ��� AClientId ״̬
  TInIOCPServer(FServer).IOCPSocketPool.Lock;
  try
    ASocket := nil;
    FClientId := AClientId;  // ��������ͻ���
    TInIOCPServer(FServer).IOCPSocketPool.Scan(Pointer(ASocket), CallbackMethod);
  finally
    Result := Assigned(ASocket);
    TInIOCPServer(FServer).IOCPSocketPool.UnLock;
  end;
end;

function TInStreamManager.Logined(const AClientId: String): Boolean;
var
  Socket: TStreamSocket;
begin
  // ���ͻ��� AClientId ״̬
  Result := Assigned(FServer) and CheckState(AClientId, Socket);
end;

procedure TInStreamManager.SendTo(AOwner: TStreamSocket; const AToClient, AText: string);
var
  Target: TStreamSocket;
begin
  // ������Ϣ�� AToClient
  if Assigned(FServer) and CheckState(AToClient, Target) then
    InterPushText(AOwner, Target, AText);
end;

{ TInClientManager }

procedure TInClientManager.Add(IOCPSocket: TIOCPSocket; ClientRole: TClientRole);
var
  Node: PEnvironmentVar;
  UserName: String;
begin
  // �Ǽ��û���¼��Ϣ

  // �����Ƕ��������µ�¼
  UserName := LowerCase(IOCPSocket.Params.UserName);  // ͳһ��Сд
  Node := FClientList.ValueOf(UserName);

  if (Assigned(Node) = False) then  // ���û���Ϣ
  begin
    // �����µ��û���Ϣ�ռ�
    Node := New(PEnvironmentVar);
    Node^.BaseInf.Group := IOCPSocket.Params.UserGroup;  // ����
    Node^.BaseInf.Name := UserName;

    // ����·����+�û���+data��
    Node^.WorkDir := AddBackslash(iocp_Varis.gUserDataPath + UserName + '\data\');
    Node^.IniDirLen := Length(Node^.WorkDir);

    // ���� Hash ��
    FClientList.Add(UserName, Node);
  end;

  Node^.BaseInf.Socket := TServerSocket(IOCPSocket); // Socket
  Node^.BaseInf.LoginTime := Now();
  Node^.BaseInf.LogoutTime := 0.0;
  Node^.BaseInf.PeerIPPort := IOCPSocket.PeerIPPort;
  Node^.BaseInf.Role := ClientRole;
  
  Node^.ReuseSession := IOCPSocket.Params.ReuseSessionId;  // �Ƿ�����ƾ֤

  // ע����Ϣ�� IOCPSocket
  TIOCPSocketRef(IOCPSocket).SetLogState(Node);
end;

procedure TInClientManager.GetClientState(const UserName: String; Result: TReturnResult);
begin
  // ��ѯ�û��ĵ�¼״̬���û���Ӧ������ QueryClients ��ѯ�����ģ�
  // ���ⲿ�ж��û��Ƿ���ڣ�arMissing
  Result.UserName := UserName;
  if FClientList.Logined(UserName) then
    Result.ActResult := arOnline
  else
    Result.ActResult := arOffline;
end;

procedure TInClientManager.Clear;
begin
  // �����¼��Ϣ
  FClientList.Clear;
end;

procedure TInClientManager.CopyClientInf(ObjType: TObjectType; var Buffer: Pointer;
                           const Data: TObject; var CancelScan: Boolean);
begin
  // ���ƿͻ���Ϣ
  if (ObjType = otEnvData) then
  begin
    // ���Ƶ�¼�ͻ�����Ϣ
    PClientInfo(Buffer)^ := PEnvironmentVar(Data)^.BaseInf;
    Inc(PAnsiChar(Buffer), CLIENT_DATA_SIZE);  // λ���ƽ�
  end else
  if (TIOCPSocket(Data).SessionId = 0) then
  begin
    with PClientInfo(Buffer)^ do
    begin
      Socket := TServerSocket(Data);
      Group := 'Unknown';  // �޷���
      Name := 'Unknown';   // δ��¼
      Role := crUnknown;
      PeerIPPort := TIOCPSocket(Data).PeerIPPort;
    end;
    Inc(PAnsiChar(Buffer), CLIENT_DATA_SIZE);  // λ���ƽ�
  end;
end;

constructor TInClientManager.Create(AOwner: TComponent);
begin
  inherited;
  FClientList := TWorkEnvironment.Create;
end;

procedure TInClientManager.Disconnect(const UserName: String);
var
  oSocket: TIOCPSocket;
begin
  // ֻ�Ͽ��ͻ��ˣ�Ҫ���ⲿɾ���˻�
  if Logined(UserName, oSocket) then
    TBaseSocketRef(oSocket).PostEvent(ioDelete);
end;

destructor TInClientManager.Destroy;
begin
  FClientList.Free;
  inherited;
end;

procedure TInClientManager.Execute(Socket: TIOCPSocket);
begin
  case Socket.Action of
    atAfterSend: begin    // ���͸������
      Socket.Result.Clear;
      Socket.Result.ActResult := arOK;
    end;

    atAfterReceive: begin // ���ո������
      Socket.Params.Clear;
      Socket.Result.ActResult := arOK;
    end;
    
    else  // ==============================
      case Socket.Params.Action of
        atUserLogin:          // ��¼
          if Assigned(FOnLogin) then
            FOnLogin(Socket.Worker, Socket.Params, Socket.Result);

        atUserLogout: begin   // �ǳ�
            if Assigned(FOnLogout) then
              FOnLogout(Socket.Worker, Socket.Params, Socket.Result);
            TIOCPSocketRef(Socket).SetLogState(Nil); // �ڲ��ǳ�
          end;

        atUserRegister:       // ע���û�
          if Assigned(FOnRegister) then
            FOnRegister(Socket.Worker, Socket.Params, Socket.Result);

        atUserModify:         // �޸�����
          if Assigned(FOnModify) then
            FOnModify(Socket.Worker, Socket.Params, Socket.Result);

        atUserDelete:         // ɾ���û�
          if Assigned(FOnDelete) then
            FOnDelete(Socket.Worker, Socket.Params, Socket.Result);

        atUserQuery:          // ��ѯ����/��¼�ͻ���
          GetClients(Socket.Result);

        atUserState:          // ��ѯ�û�״̬
          if Assigned(FOnQueryState) then
            FOnQueryState(Socket.Worker, Socket.Params, Socket.Result);
      end;
  end;
end;

procedure TInClientManager.GetClients(Result: TReturnResult);
begin
  GetLoginedClients(Result);       // ���ص�¼�Ŀͻ�����Ϣ
  GetConnectedClients(Result);     // ��������δ��¼�ͻ�����Ϣ
  Result.AsInteger['group'] := 2;  // ����
end;

procedure TInClientManager.GetConnectedClients(Result: TReturnResult);
var
  Size, Count: Integer;
  Buffer, Buffer2: TMemBuffer;
begin
  // �������ߵ�δ��¼�Ŀͻ�����Ϣ����һ�飩
  
  TInIOCPServer(FServer).IOCPSocketPool.Lock;
  try
    // �����Զ���� TMemBuffer ����
    Size := TInIOCPServer(FServer).IOCPSocketPool.UsedCount * CLIENT_DATA_SIZE;
    Buffer := GetBuffer(Size);
    Buffer2 := Buffer;

    // �����ͻ��б�������Ϣ�� Buffer
    TInIOCPServer(FServer).IOCPSocketPool.Scan(Buffer2, CopyClientInf);

    if (Buffer2 = Buffer) then
    begin
      // û�пͻ���
      Result.AsBuffer['list_1'] := nil;
      Result.AsInteger['count_1'] := 0;
      FreeBuffer(Buffer);
    end else
    begin
      Count := (PAnsiChar(Buffer2) - PAnsiChar(Buffer)) div CLIENT_DATA_SIZE;
      if (Count <> TInIOCPServer(FServer).IOCPSocketPool.UsedCount) then
      begin
        // û��ô��ͻ��ˣ�������ô��
        Size := Count * CLIENT_DATA_SIZE;
        Buffer2 := GetBuffer(Size);
        System.Move(Buffer^, Buffer2^, Size);
        FreeBuffer(Buffer);
        Buffer := Buffer2;
      end;
      Result.AsBuffer['list_1'] := Buffer;  // ��������
      Result.AsInteger['count_1'] := Count;  // ����
    end;

  finally
    TInIOCPServer(FServer).IOCPSocketPool.UnLock;
  end;
end;

procedure TInClientManager.GetLoginedClients(Result: TReturnResult);
var
  Buffer, Buffer2: TMemBuffer;
begin
  // ȡ��¼�Ŀͻ�����Ϣ���ڶ��飩
  FClientList.Lock;
  try
    // �����Զ���� TMemBuffer ����
    if (FClientList.Count = 0) then
    begin
      Result.AsBuffer['list_2'] := Nil;
      Result.AsInteger['count_2'] := 0;
    end else
    begin
      Buffer := GetBuffer(FClientList.Count * CLIENT_DATA_SIZE);
      Buffer2 := Buffer;

      // �����ͻ��б�������Ϣ�� Buffer2
      FClientList.Scan(Buffer2, CopyClientInf);

      Result.AsBuffer['list_2'] := Buffer;  // ��������
      Result.AsInteger['count_2'] := FClientList.Count;
    end;
  finally
    FClientList.UnLock;
  end;
end;

function TInClientManager.Logined(const UserName: String; var Socket: TIOCPSocket): Boolean;
begin
  if (UserName = '') then
    Result := False
  else
    Result := FClientList.Logined(LowerCase(UserName), TObject(Socket));
end;

function TInClientManager.Logined(const UserName: String): Boolean;
begin
  if (UserName = '') then
    Result := False
  else
    Result := FClientList.Logined(LowerCase(UserName));
end;

procedure TInClientManager.RemoveClient(const UserName: string);
begin
  // �ͷſͻ��˵�¼��Ϣ
  FClientList.Remove(LowerCase(UserName));
end;

{ TInMessageManager }

procedure TInMessageManager.Broadcast(AMsg: TReceiveParams);
begin
  // �㲥�յ�����Ϣ����������δ��¼�Ŀͻ��ˣ�����Ȩ������
  if (AMsg = AMsg.Socket.Params) and    // �Ǵ������Ϣ
     (AMsg.Socket.Role >= crAdmin) and  // Ȩ��>=����Ա
     (AMsg.Action <> atUserLogin) then  // ���ǵ�¼�������������룩     
    InterPushMsg(AMsg.Socket, nil, nil, btAllClient);
end;

procedure TInMessageManager.Broadcast(AMsg: TReturnResult);
begin
  // �㲥Ҫ���ص���Ϣ����������δ��¼�Ŀͻ��ˣ�����Ȩ������
  if (AMsg = AMsg.Socket.Result) and
     (AMsg.Socket.Role >= crAdmin) then
    InterCopyPush(AMsg.Socket, nil, AMsg.Socket.Result, nil, btAllClient);
end;

procedure TInMessageManager.Broadcast(AOwner: TIOCPSocket; const AMsg: String);
var
  Result: TReturnResult;
begin
  // AOwner: ����;  AMsg: ��Ϣ�ı�
  // �㲥�ı�����Ȩ������
  if Assigned(AOwner) and (AMsg <> '') then
    if (AOwner.Role >= crAdmin) then
    begin
      Result:= TReturnResult.Create(AOwner);  // �½�һ��������Ϣ��
      try
        Result.Msg := AMsg;  // ��Ϣ�ı�
        InterCopyPush(AOwner, nil, Result, nil, btAllClient);
      finally
        Result.Free;
      end;
    end else
      AOwner.Result.ActResult := arFail;
end;

procedure TInMessageManager.CreateMsgWriter(SurportHttp: Boolean);
begin
  // ��Ϣ��д�������� Http ����ʱͬʱ���渽���� URL������TMessageWriter.SaveMsg
  if (Assigned(FMsgWriter) = False) then
    FMsgWriter := TMessageWriter.Create(SurportHttp);
end;

destructor TInMessageManager.Destroy;
begin
  if Assigned(FMsgWriter) then
    FMsgWriter.Free;
  inherited;
end;

procedure TInMessageManager.Execute(Socket: TIOCPSocket);
begin
  case Socket.Action of
    atAfterSend: begin   // ���͸������
      Socket.Result.Clear;
      Socket.Result.ActResult := arOK;
    end;

    atAfterReceive: begin // ���ո������
      Socket.Params.Clear;
      Socket.Result.ActResult := arOK;
    end;

    else  // ==============================

      case Socket.Params.Action of
        atTextSend:      // �����ı���������
          if Assigned(FOnReceive) then
            FOnReceive(Socket.Worker, Socket.Params, Socket.Result);
        atTextPush:      // ������Ϣ
          if Assigned(FOnPush) then
            FOnPush(Socket.Worker, Socket.Params, Socket.Result);
        atTextBroadcast: // �㲥��Ϣ
          if Assigned(FOnBroadcast) then
            FOnBroadcast(Socket.Worker, Socket.Params, Socket.Result);
        atTextGetMsg:       // ������Ϣ
          if Assigned(FOnGet) then
            FOnGet(Socket.Worker, Socket.Params, Socket.Result);
        atTextFileList:
          if Assigned(FOnListFiles) then
            FOnListFiles(Socket.Worker, Socket.Params, Socket.Result);
      end;
  end;
end;

procedure TInMessageManager.InterCopyPush(ASource, ATarget: TIOCPSocket;
  AResult: TReturnResult; AToSockets: TInList; CastType: TBroadcastType);
var
  Msg: TPushMessage;
begin
  // ����Ҫ���ص���Ϣ�� ATarget �� AToSockets ��㲥

  // ��Ϣ̫�� -> ����
  if (AResult.Size >= BROADCAST_MAX_SIZE) then
  begin
    ASource.Result.ActResult := arFail;  // ���� AResult
    Exit;
  end;

  // ��������Ϣ
  if (CastType in [btAllClient, btAdminOnly]) then
  begin
    Msg := TPushMessage.Create(ASource.ObjPool, ASource.BufferPool, CastType);
    Msg.IngoreSocket := ASource;  // �����Լ���ע����Լ�Ҳ���յ���
    if (ASource.Background = False) then
      Msg.Group := ASource.UserGroup;  // ����
  end else
  begin
    Msg := TPushMessage.Create(ASource.ObjPool, ASource.BufferPool, btUnknown);
    if Assigned(ATarget) then
      Msg.Add(ATarget)  // ���͸� ATarget
    else
    if Assigned(AToSockets) then
      Msg.AddList(AToSockets);  // ���͸��б�����Ϊnil��
  end;

  // תΪ����д�����ͻ���
  TReturnResultRef(AResult).CreateStreams(False);
  TReturnResultRef(AResult).LoadHead(@Msg.PushBuf^.Data);  // װ�ء�����

  Msg.UpdateMsgId;  // ���µ� MsgId

  if TInIOCPServer(FServer).PushManager.AddWork(Msg) then  // ���������߳�
    ASource.Result.ActResult := arOK
  else  // ��æ��������Msg �ѱ��ͷ�
    ASource.Result.ActResult := arErrBusy;
end;

procedure TInMessageManager.InterPushMsg(ASource, ATarget: TIOCPSocket;
  AToSockets: TInList; CastType: TBroadcastType);
var
  Msg: TPushMessage;
begin
  // �����յ�����Ϣ�� ATarget �� AToSockets ��㲥

  // ��Ϣ̫�� -> ����
  if (ASource.Params.Size >= BROADCAST_MAX_SIZE) then
  begin
    ASource.Result.ActResult := arFail;
    Exit;
  end;

  // �ϴ��ļ��Ĳ�����ASource.RecvBuf ����Ϊ�ļ����ݣ�
  // Ҫ�� Params д�� ASource.RecvBuf
  if Assigned(ASource.Params.Attachment) then
    TReceiveParams(ASource.Params).Write(ASource.RecvBuf);

  // ��������Ϣ
  if (CastType in [btAllClient, btAdminOnly]) then
  begin
    Msg := TPushMessage.Create(ASource.RecvBuf, CastType);
    Msg.IngoreSocket := ASource;  // �����Լ���ע����Լ�Ҳ���յ���
    if (ASource.Background = False) then
      Msg.Group := ASource.UserGroup;  // ����
  end else
  begin
    Msg := TPushMessage.Create(ASource.RecvBuf, btUnknown);
    if Assigned(ATarget) then
      Msg.Add(ATarget)  // ���͸� ATarget
    else
      Msg.AddList(AToSockets);  // ���͸��б�����Ϊnil��
  end;

  // ���µ� MsgId
  Msg.UpdateMsgId;

  if TInIOCPServer(FServer).PushManager.AddWork(Msg) then  // ���������߳�
    ASource.Result.ActResult := arOK
  else  // ��æ��������Msg �ѱ��ͷ�
    ASource.Result.ActResult := arErrBusy;
end;

procedure TInMessageManager.InterPushResultMsg(Socket: TIOCPSocket; Result: TReturnResult; UserNameList: AnsiString);
var
  PushMsg: TPushMessage;
begin
  if (UserNameList = '')  then  // �㲥����Ȩ������
    InterCopyPush(Socket, nil, Result, nil, btAllClient)
  else
  if (Result.Size < BROADCAST_MAX_SIZE) then
  begin
    // �½�������Ϣ
    PushMsg := TPushMessage.Create(Socket.ObjPool, Socket.BufferPool, btUnknown);

    // תΪ����д�����ͻ���
    TReturnResultRef(Result).CreateStreams(False);
    TReturnResultRef(Result).LoadHead(@PushMsg.PushBuf^.Data);  // װ�ء�����

    InterSavePushMsg(Socket, PushMsg, UserNameList);
  end else
    Socket.Result.ActResult := arFail;  // ���� Result.ActResult
end;

procedure TInMessageManager.InterSavePushMsg(AOwner: TIOCPSocket;
  PushMsg: TInList; UserNameList: AnsiString);
var
  UserName: AnsiString;
  oSocket: TIOCPSocket;
begin
  // ���µ� MsgId
  TPushMessage(PushMsg).UpdateMsgId;

  while ExtractValue(UserName, UserNameList) do  // ��ȡ�û���
  begin
    if Assigned(TInIOCPServer(FServer).ClientManager) and
      TInIOCPServer(FServer).ClientManager.Logined(UserName, oSocket) then
      PushMsg.Add(oSocket)  // ���ߣ�����
    else  // ���ߣ����浽��Ϣ�ļ�
      FMsgWriter.SaveMsg(TPushMessage(PushMsg).PushBuf, UserName);
  end;

  if TInIOCPServer(FServer).PushManager.AddWork(TPushMessage(PushMsg)) then  // ���������߳�
    AOwner.Result.ActResult := arOK
  else  // ��æ��������Msg �ѱ��ͷ�
    AOwner.Result.ActResult := arErrBusy;

end;

procedure TInMessageManager.PushMsg(AMsg: TReceiveParams; const AUserNameList: String);
var
  PushMsg: TPushMessage;
begin
  // �����յ�����Ϣ�� AUserNameList
  if Assigned(AMsg) and (AMsg = AMsg.Socket.Params)then
    if (AUserNameList = '') then  // �㲥����Ȩ������
      InterPushMsg(AMsg.Socket, nil, nil, btAllClient)
    else
    if (AMsg.Size < BROADCAST_MAX_SIZE) then
    begin
      if Assigned(AMsg.Attachment) then
      begin
        // �ļ��������½�������Ϣ���� AMsg д�� PushMsg.RecvBuf
        PushMsg := TPushMessage.Create(AMsg.Socket.ObjPool,
                                       AMsg.Socket.BufferPool, btUnknown);
        AMsg.Write(PushMsg.PushBuf);
      end else  // ֱ�Ӹ����½�������Ϣ
        PushMsg := TPushMessage.Create(AMsg.Socket.RecvBuf, btUnknown);

      // ��������Ŀ�ģ�������Ϣ���ļ�  
      InterSavePushMsg(AMsg.Socket, PushMsg, AUserNameList);
    end else
      AMsg.Socket.Result.ActResult := arFail;
end;

procedure TInMessageManager.PushMsg(AMsg: TReturnResult; const AUserNameList: String);
begin
  // ����Ҫ���ص���Ϣ�� AUserNameList
  if Assigned(AMsg) and (AMsg = AMsg.Socket.Result) then
    InterPushResultMsg(AMsg.Socket, AMsg, AUserNameList);
end;

procedure TInMessageManager.PushMsg(AOwner: TIOCPSocket; const AMsg, AUserNameList: String);
var
  Result: TReturnResult;
begin
  // AOwner: ������AMsg: ��Ϣ�ı���AUserNameList: �ͻ��������б�
  // �����ı� AMsg �� AUserNameList
  if Assigned(AOwner) and (AMsg <> '') then
  begin
    Result:= TReturnResult.Create(AOwner);  // �½�һ�����ص���Ϣ
    try
      Result.Msg := AMsg;  // ��Ϣ�ı�
      InterPushResultMsg(AOwner, Result, AUserNameList);
    finally
      Result.Free;
    end;
  end;
end;

procedure TInMessageManager.PushToAdmin(AMsg: TReceiveParams);
begin
  // �����յ�����Ϣ��ȫ������Ա����Ȩ������
  if Assigned(AMsg) and (AMsg = AMsg.Socket.Params) then
    InterPushMsg(AMsg.Socket, nil, nil, btAdminOnly);
end;

procedure TInMessageManager.PushToAdmin(AMsg: TReturnResult);
begin
  // ����Ҫ���ص���Ϣ��ȫ������Ա����Ȩ������
  if Assigned(AMsg) and (AMsg = AMsg.Socket.Result) then
    InterCopyPush(AMsg.Socket, nil, AMsg, nil, btAdminOnly);
end;

procedure TInMessageManager.PushToAdmin(AOwner: TIOCPSocket; const AMsg: String);
var
  Result: TReturnResult;
begin
  // AOwner: ������AMsg: ��Ϣ�ı�
  // �����ı�������Ա����Ȩ������
  if Assigned(AOwner) and (AMsg <> '') then
  begin
    Result:= TReturnResult.Create(AOwner);  // �½�һ�����ص���Ϣ
    try
      Result.Msg := AMsg;  // ��Ϣ�ı�
      InterCopyPush(AOwner, nil, Result, nil, btAdminOnly);
    finally
      Result.Free;
    end;
  end;
end;

procedure TInMessageManager.ReadMsgFile(Params: TReceiveParams; Result: TReturnResult);
begin
  // ���û� UserName ��������Ϣ�ļ��ӵ� Result������������
  FMsgWriter.LoadMsg(Params.UserName, Result);
end;

procedure TInMessageManager.SaveMsgFile(Params: TReceiveParams; IODataSource: Boolean);
begin
  // ��ʱ ToUser ��Ϊ�գ�����Ϣ�� Params ���浽 ToUser ����Ϣ�ļ�
  TReceiveParamsRef(Params).SetUniqueMsgId;  // ʹ�÷���˵�Ψһ msgId
  if IODataSource then  // �����յ������ݿ飬���죡
    FMsgWriter.SaveMsg(Params.Socket.RecvBuf, Params.ToUser)
  else // ���������Ҫת��Ϊ�����������Ӹ����� URL
    FMsgWriter.SaveMsg(Params, Params.ToUser);
end;

{ TInFileManager }

procedure TInFileManager.CreateNewFile(Params: TReceiveParams);
begin
  // ���ļ�����׼�������ļ�
  if (Params.Action = atFileUpShare) then // ���浽��ʱ·��
    Params.CreateAttachment(iocp_varis.gUserDataPath + Params.UserName + '\temp\')
  else
    Params.CreateAttachment(iocp_varis.gUserDataPath + Params.UserName + '\data\');
end;

procedure TInFileManager.Execute(Socket: TIOCPSocket);
begin
  // ��ִ���ڲ������¼�
  //   ����˵ĸ����ȷ��ͣ����յ��ͻ��˵ĸ���

  case Socket.Action of
    atAfterSend:    // ���͸�����ϣ��ڲ��¼���
      try
        if Assigned(FAfterDownload) then
          if (Socket.Result.Action <> atFileDownChunk) or
             (Socket.Result.OffsetEnd + 1 = TIOCPDocument(Socket.Result.Attachment).OriginSize) then
            FAfterDownload(Socket.Worker, Socket.Params,
                           Socket.Result.Attachment as TIOCPDocument);
      finally
        Socket.Result.Clear;
        Socket.Result.ActResult := arOK;  // �ͻ����յ����巢�����
      end;

    atAfterReceive: // ���ո�����ϣ��ڲ��¼���������������
      try
        if Assigned(FAfterUpload) then
          if (Socket.Params.Action <> atFileUpChunk) or
             (Socket.Params.OffsetEnd + 1 = Socket.Params.Attachment.OriginSize) then
            FAfterUpload(Socket.Worker, Socket.Params, Socket.Params.Attachment);
      finally
        Socket.Params.Clear;
        Socket.Result.ActResult := arOK;
      end;

    else  // =================================

      case Socket.Params.Action of
        atFileList:         // �г��ļ�
          if Assigned(FOnQueryFiles) then
            FOnQueryFiles(Socket.Worker, Socket.Params, Socket.Result);

        atFileSetDir:       // ����·��
          if Assigned(FOnSetWorkDir) then
            FOnSetWorkDir(Socket.Worker, Socket.Params, Socket.Result);

        atFileRename:       // �������ļ�
          if Assigned(FOnRenameFile) then
            FOnRenameFile(Socket.Worker, Socket.Params, Socket.Result);

        atFileRenameDir:    // ������Ŀ¼
          if Assigned(FOnRenameDir) then
            FOnRenameDir(Socket.Worker, Socket.Params, Socket.Result);

        atFileDelete:       // ɾ���ļ�
          if Assigned(FOnDeleteFile) then
            FOnDeleteFile(Socket.Worker, Socket.Params, Socket.Result);

        atFileDeleteDir:    // ɾ��Ŀ¼
          if Assigned(FOnDeleteDir) then
            FOnDeleteDir(Socket.Worker, Socket.Params, Socket.Result);

        atFileMakeDir:      // �½�Ŀ¼
          if Assigned(FOnMakeDir) then
            FOnMakeDir(Socket.Worker, Socket.Params, Socket.Result);

        atFileDownload,     // �����ļ�
        atFileDownShare:
          if Assigned(FBeforeDownload) then
            FBeforeDownload(Socket.Worker, Socket.Params, Socket.Result);

        atFileDownChunk:    // �ϵ������ļ�
          if Assigned(FBeforeDownload) then
            if (Socket.Params.Offset = 0) then  // ����Ӧ�ò���ļ�
              FBeforeDownload(Socket.Worker, Socket.Params, Socket.Result)
            else  // ������Ӧ�ò�
              Socket.Result.LoadFromFile(DecryptString(Socket.Params.Directory) +
                                         Socket.Params.FileName, True);

        atFileUpload,
        atFileUpShare:      // �ϴ��ļ�
          if Assigned(FBeforeUpload) then
          begin
            FBeforeUpload(Socket.Worker, Socket.Params, Socket.Result);
            if Assigned(Socket.Params.Attachment) then  
              Socket.Result.ActResult := arAccept;  // �����û���Ϊ arOK, У�����
          end;

        atFileUpChunk:      // �ϵ��ϴ��ļ�
          if Assigned(FBeforeUpload) then
            if (Socket.Params.Offset = 0) then  // ����Ӧ�ò���ļ�
            begin
              FBeforeUpload(Socket.Worker, Socket.Params, Socket.Result);
              if Assigned(Socket.Params.Attachment) then
                Socket.Result.ActResult := arAccept;  // �����û���Ϊ arOK, У�����
            end else        // ������Ӧ�ò�
              Socket.Params.CreateAttachment(DecryptString(Socket.Params.Directory));
      end;
  end;
end;

procedure TInFileManager.ListFiles(Result: TResultJSON; const Path: String);
var
  i: Integer;
  SRec: TSearchRec;
  FileRec: TCustomJSON;
begin
  // ȡĿ¼ Path ���ļ��б�

  if (DirectoryExists(Path) = False) then
  begin
    Result.I['count'] := -1;  // �����Ŀ¼
    Exit;
  end;

  i := 0;
  FileRec := TCustomJSON.Create;
  FindFirst(Path + '*.*', faAnyFile, SRec);

  try
    repeat
      if (SRec.Name <> '.') and (SRec.Name <> '..') then
      begin
        Inc(i);
        FileRec.S['name'] := SRec.Name;
        FileRec.I64['size'] := SRec.Size;
        FileRec.D['CreationTime'] := FileTimeToDateTime(SRec.FindData.ftCreationTime);
        FileRec.D['LastWriteTime'] := FileTimeToDateTime(SRec.FindData.ftLastWriteTime);

        if (SRec.Attr and faDirectory) = faDirectory then
          FileRec.S['dir'] := 'Y'       // Ŀ¼
        else
          FileRec.S['dir'] := 'N';

        // ���ļ���Ϣ����һ����¼���ӵ� Result
        Result.R[IntToStr(i)] := FileRec;
      end;
    until FindNext(SRec) > 0;

    Result.I['count'] := i;  // �ļ���
  finally
    FileRec.Free;
    FindClose(SRec);
  end;
end;

procedure TInFileManager.ListFiles(Params: TReceiveParams; Result: TReturnResult; MsgFiles: Boolean);
var
  i: Integer;
  SRec: TSearchRec;
  Dir: String;
  FileRec: TCustomPack;
begin
  // ȡ�û���ǰĿ¼���ļ��б�

  // �û�Ŀ¼�ļ������
  //   1. ��Ŀ¼��Socket.Data^.WorkDir + UserName
  //   2. ��Ҫ����Ŀ¼��UserName\Data
  //   3. ������ϢĿ¼��UserName\Msg
  //   4. ��ʱ�ļ�Ŀ¼: UserName\temp

  if MsgFiles then  // ��Ϣ�ļ�·��
    Dir := iocp_varis.gUserDataPath + Params.UserName + '\msg\'
  else
    Dir := Params.Socket.Envir^.WorkDir + Params.Directory;

  if (DirectoryExists(Dir) = False) then
  begin
    Result.ActResult := arFail;        // �����Ŀ¼
    Exit;
  end;

  i := 0;
  FileRec := TCustomPack.Create;
  FindFirst(Dir + '*.*', faAnyFile, SRec);

  try
    repeat
      if (SRec.Name <> '.') and (SRec.Name <> '..') then
      begin
        Inc(i);
        FileRec.AsString['name'] := SRec.Name;
        FileRec.AsInt64['size'] := SRec.Size;
        FileRec.AsDateTime['CreationTime'] := FileTimeToDateTime(SRec.FindData.ftCreationTime);
        FileRec.AsDateTime['LastWriteTime'] := FileTimeToDateTime(SRec.FindData.ftLastWriteTime);

        if (SRec.Attr and faDirectory) = faDirectory then
          FileRec.AsString['dir'] := 'Y'       // Ŀ¼
        else
          FileRec.AsString['dir'] := 'N';

        // ���ļ���Ϣ����һ����¼���ӵ� Result
        Result.AsRecord[IntToStr(i)] := FileRec;
      end;
    until FindNext(SRec) > 0;

    if (i > 0) then
      Result.ActResult := arOK
    else
      Result.ActResult := arEmpty;      // ��Ŀ¼
          
//    Result.SaveToFile('temp\svr.txt');
  finally
    FileRec.Free;
    FindClose(SRec);
  end;
end;

procedure TInFileManager.MakeDir(Params: TReceiveParams; Result: TReturnResult; const Path: String);
var
  NewPath: String;
begin
  // �½�һ��Ŀ¼���ڹ���·������Ŀ¼�£�
  NewPath := Params.Socket.Envir^.WorkDir + Path;
  if DirectoryExists(NewPath) then
    Result.ActResult := arExists
  else begin
    MyCreateDir(NewPath);
    Result.ActResult := arOK;
  end;
end;

procedure TInFileManager.OpenLocalFile(Result: TReturnResult; const FileName: String);
begin
  if (FileName <> '') then  // �� FileName
    Result.LoadFromFile(FileName, True)
  else  // �򿪹���·���µ� Params.FileName
    Result.LoadFromFile(Result.Socket.Envir^.WorkDir +
                        Result.Socket.Params.FileName, True);
end;

procedure TInFileManager.SetWorkDir(Result: TReturnResult; const Dir: String);
  function GetParentDir(var S: String): Integer;
  var
    i, k: Integer;
  begin
    k := Length(S);
    for i := k downto 1 do
      if (i < k) and (S[i] = '\') then
      begin
        Delete(S, i + 1, 99);
        Result := i;
        Exit;
      end;
    Result := k;
  end;
var
  S: String;
  iLen: Integer;
begin
  // ���ù���·�������ܴ��̷� :
  if (Result.Socket.Envir = Nil) or (Pos(':', Dir) > 0) then
    Result.ActResult := arFail
  else begin
    // 1. ��Ŀ¼��2. ��Ŀ¼
    S := Result.Socket.Envir^.WorkDir;

    if (Dir = '..') then  // 1. ���븸Ŀ¼
    begin
      iLen := GetParentDir(S);
      if (iLen >= Result.Socket.Envir^.IniDirLen) then  // ���Ȳ�����ԭʼ��
        Result.ActResult := arOK
      else
        Result.ActResult := arFail;
    end else

    if (Pos('..', Dir) > 0) then  // �������� ..\xxx ���ַ����������ʷ�Χ ��
      Result.ActResult := arFail

    else begin
      // 2. ��Ŀ¼
      S := S + AddBackslash(Dir);
      if DirectoryExists(S) then
        Result.ActResult := arOK
      else
        Result.ActResult := arMissing;
    end;

    if (Result.ActResult = arOK) then
      Result.Socket.Envir^.WorkDir := S;
  end;
end;

{ TInDatabaseManager }

procedure TInDatabaseManager.AddDataModule(ADataModule: TDataModuleClass; const ADescription: String);
begin
  // ע������ģ��������Ψһ�ģ�
  if FDataModuleList.IndexOf(ADescription) = -1 then
  begin
    FDataModuleList.Add(ADescription, TObject(ADataModule));
    if Assigned(FServer) and Assigned(TInIOCPServer(FServer).BusiWorkMgr) then   // ����״̬����ʵ��
      TInIOCPServer(FServer).BusiWorkMgr.AddDataModule(FDataModuleList.Count - 1);
  end;
end;

procedure TInDatabaseManager.DBConnect(Socket: TIOCPSocket);
var
  DBConnection: Integer;
begin
  // ����Ҫ���ӵ�����ģ���(��: TInDBConnection.Connect)
  DBConnection := Socket.Params.Target;
  if (DBConnection >= 0) and (DBConnection < FDataModuleList.Count) then
  begin
    if Assigned(Socket.Envir) then
      Socket.Envir^.DBConnection := DBConnection;
    TBusiWorker(Socket.Worker).SetConnection(DBConnection);
    Socket.Result.ActResult := arOK;
  end else
    Socket.Result.ActResult := arFail;
end;

procedure TInDatabaseManager.Clear;
begin
  FDataModuleList.Clear;
end;

constructor TInDatabaseManager.Create(AOwner: TComponent);
begin
  inherited;
  FDataModuleList := TInStringList.Create;
end;

destructor TInDatabaseManager.Destroy;
begin
  FDataModuleList.Free;
  inherited;
end;

procedure TInDatabaseManager.Execute(Socket: TIOCPSocket);
  procedure InnerSetConnection;
  begin
    if Assigned(Socket.Envir) then  // ׼����ǰ��������ģʵ��
      if (Socket.Envir^.DBConnection <> Integer(Socket.Params.Target)) then
        Socket.Envir^.DBConnection := Socket.Params.Target;
    TBusiWorker(Socket.Worker).SetConnection(Socket.Params.Target);
  end;
begin
  // ���ݿ��������ģ��ϵ���У������������ҵ��ģ�飬���ٸ����ԡ�
  // ����ǰ�Ѿ������õ�ǰ�������ӣ�����TBusiWorker.Execute

  case Socket.Action of
    atAfterSend: begin   // ���͸������
      Socket.Result.Clear;
      Socket.Result.ActResult := arOK;
    end;

    atAfterReceive: begin // ���ո������
      Socket.Params.Clear;
      Socket.Result.ActResult := arOK;
    end;

    else  // ==============================
      case Socket.Params.Action of
        atDBGetConns:       // ��ѯ���ݿ����������һ������ģ��һ�֣��������ݿ����ӣ�
          GetDBConnections(Socket);

        atDBConnect:        // ���ݿ�����
          DBConnect(Socket);

        atDBExecQuery: begin // SELECT-SQL ��ѯ, �����ݼ�����
          InnerSetConnection;
          TBusiWorker(Socket.Worker).DataModule.ExecQuery(Socket.Params, Socket.Result);
        end;

        atDBExecSQL: begin  // ִ�� SQL
          InnerSetConnection;
          TBusiWorker(Socket.Worker).DataModule.ExecSQL(Socket.Params, Socket.Result);
        end;

        atDBExecStoredProc: begin // ִ�д洢����
          InnerSetConnection;
          TBusiWorker(Socket.Worker).DataModule.ExecStoredProcedure(Socket.Params, Socket.Result);
        end;

        atDBApplyUpdates: begin   // �޸ĵ�����
          InnerSetConnection;
          TBusiWorker(Socket.Worker).DataModule.ApplyUpdates(Socket.Params, Socket.Result);
        end;
      end;
  end;
end;

function TInDatabaseManager.GetDataModuleCount: Integer;
begin
  Result := FDataModuleList.Count;
end;

procedure TInDatabaseManager.GetDataModuleState(Index: Integer;
          var AClassName, ADescription: String; var ARunning: Boolean);
var
  Item: PStringItem;
begin
  // ȡ���Ϊ Index ����ģ״̬
  if (Index >= 0) and (Index < FDataModuleList.Count) then
  begin
    Item := FDataModuleList.Items[Index];
    AClassName := TClass(Item^.FObject).ClassName;  // ����
    ADescription := Item^.FString;    // ����
    if Assigned(FServer) and Assigned(TInIOCPServer(FServer).BusiWorkMgr) then
      ARunning := TInIOCPServer(FServer).BusiWorkMgr.DataModuleState[Index]  // ����״̬
    else
      ARunning := False;
  end else
  begin
    AClassName := '(δ֪)';
    ADescription := '(δע��)';
    ARunning := False;
  end;  
end;

procedure TInDatabaseManager.GetDBConnections(Socket: TIOCPSocket);
begin
  // ȡ��ģ�б�
  if (FDataModuleList.Count = 0) then
    Socket.Result.ActResult := arMissing
  else begin
    Socket.Result.AsString['dmCount'] := FDataModuleList.DelimitedText;
    Socket.Result.ActResult := arExists;
  end;
end;

procedure TInDatabaseManager.RemoveDataModule(Index: Integer);
begin
  // ɾ����ģ
  if Assigned(FServer) and (Index >= 0) and (Index < FDataModuleList.Count) then
    if Assigned(TInIOCPServer(FServer).BusiWorkMgr) then  // �ͷ�ʵ����������ɾ���б���Ӱ��������ģ��ţ�
      TInIOCPServer(FServer).BusiWorkMgr.RemoveDataModule(Index)
    else
      FDataModuleList.Delete(Index);    // ��������״̬��ֱ��ɾ��
end;

procedure TInDatabaseManager.ReplaceDataModule(Index: Integer;
  ADataModule: TDataModuleClass; const ADescription: String);
var
  Item: PStringItem;
begin
  // ����һ���Ѿ��ͷ�ʵ������ģ
  if (Index >= 0) and (Index < FDataModuleList.Count) then
  begin
    Item := FDataModuleList.Items[Index];
    if not Assigned(TInIOCPServer(FServer).BusiWorkMgr) then   // ������״̬
    begin
      Item^.FObject := TObject(ADataModule); // ����
      Item^.FString := ADescription;         // ����
    end else
    if not TInIOCPServer(FServer).BusiWorkMgr.DataModuleState[Index] then   // ����״̬��ʵ��δ��
    begin
      Item^.FObject := TObject(ADataModule); // ����
      Item^.FString := ADescription;         // ����
      TInIOCPServer(FServer).BusiWorkMgr.AddDataModule(Index);
    end;
  end;
end;

{ TInCustomManager }

constructor TInCustomManager.Create(AOwner: TComponent);
begin
  inherited;
  FFunctions := TInStringList.Create;
end;

destructor TInCustomManager.Destroy;
begin
  FFunctions.Free;
  inherited;
end;

procedure TInCustomManager.Execute(Socket: TIOCPSocket);
var
  FunctionGroup: TInRemoteFunctionGroup;
begin
  // ��ִ���ڲ������¼�
  // ����TInFunctionClient.Call
  //   ����˵ĸ����ȷ��ͣ����յ��ͻ��˵ĸ���
  
  case Socket.Action of
    atAfterSend:     // ���͸������
      try
        // δ����������������¼�
      finally
        Socket.Result.Clear;
        Socket.Result.ActResult := arOK;
      end;

    atAfterReceive:  // ���ո������
      try
        if Assigned(FOnAttachFinish) then
          FOnAttachFinish(Socket.Worker, Socket.Params);
      finally
        Socket.Params.Clear;
        Socket.Result.ActResult := arOK;
      end;

  else // =================================

    case Socket.Params.Action of
      atCallFunction:       // ���ң�ִ��Զ�̺�������д��
        if FFunctions.IndexOf(UpperCase(Socket.Params.FunctionGroup),
                              Pointer(FunctionGroup)) then
          FunctionGroup.Execute(Socket)
        else  // Զ�̺����鲻����
          Socket.Result.ActResult := arMissing;

      atCustomAction: begin // �Զ������
        FOnReceive(Socket.Worker, Socket.Params, Socket.Result);
        if(Socket.Params.AttachSize > 0) and
          (Assigned(Socket.Params.Attachment) = False) then // �и�����δȷ��Ҫ���ո���
          if Assigned(FOnAttachBegin) then
            FOnAttachBegin(Socket.Worker, Socket.Params);
      end;
    end;
  end;
end;

{ TInRemoteFunctionGroup }

procedure TInRemoteFunctionGroup.Execute(Socket: TIOCPSocket);
begin
  case Socket.Action of
    atAfterSend: begin   // ���͸������
      Socket.Result.Clear;
      Socket.Result.ActResult := arOK;
    end;

    atAfterReceive: begin // ���ո������
      Socket.Params.Clear;
      Socket.Result.ActResult := arOK;
    end;
    
    else  // ==============================
      if Assigned(FOnExecute) then
        FOnExecute(Socket.Worker, Socket.Params, Socket.Result);
  end;
end;

procedure TInRemoteFunctionGroup.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (operation = opRemove) and (AComponent = FCustomManager) then
    FCustomManager := nil;
end;

procedure TInRemoteFunctionGroup.SetCustomManager(const Value: TInCustomManager);
var
  i: Integer;
begin
  if Assigned(FCustomManager) then  // ɾ��
  begin
    i := FCustomManager.FFunctions.IndexOf(Self);
    if (i > -1) then
    begin
      FCustomManager.FFunctions.Delete(i);
      FCustomManager.RemoveFreeNotification(Self);
    end;
  end;

  FCustomManager := Value;

  if Assigned(FCustomManager) then
  begin
    i := FCustomManager.FFunctions.IndexOf(Self);
    if (i = -1) then
      if (FFuncGroupName <> '') then
      begin
        FCustomManager.FFunctions.Add(UpperCase(FFuncGroupName), Self);
        FCustomManager.FreeNotification(Self);
      end else
      if not (csDesigning in ComponentState) then
        raise Exception.Create('���󣺺���û�����ƣ�����Ψһ��');
  end;
end;

{ TInWebSocketManager }

procedure TInWebSocketManager.Broadcast(Socket: TWebSocket);
begin
  // �㲥 Socket �յ�����Ϣ��������Ȩ�ޣ������Ҵ�Ҷ����õ�
  InterPushMsg(Socket, nil);
end;

procedure TInWebSocketManager.Broadcast(const Group, Text: string; OpCode: TWSOpCode);
begin
  // �㲥��Ϣ Text������̫��
  //   OpCode = ocClose ʱ��ȫ���ͻ��˹ر�
  if (OpCode in [ocText, ocClose, ocPong]) then
    InterPushMsg(nil, OpCode, System.AnsiToUtf8(Text), Group);
end;

procedure TInWebSocketManager.CallbackMethod(ObjType: TObjectType;
  var FromObject: Pointer; const Data: TObject; var CancelScan: Boolean);
type
  PChars10 = ^TChars10;
  TChars10 = array[0..9] of AnsiChar;
  PChars11 = ^TChars11;
  TChars11 = array[0..11] of AnsiChar;
var
  iSize: Integer;
begin
  if (Length(FUserName) = 0) then
  begin
    // �����û��б�����д��ֵ���������´Ρ�ĩβ
    // [{"NAME":"aaa"},{"NAME":"bbb"},{"NAME":"ccc"}]
    iSize := Length(TWebSocket(Data).UserName);
    if (iSize > 0) then
    begin
      if (FJSONLength = 0) then
      begin
        PChars10(FromObject)^ := AnsiString('[{"NAME":"');
        Inc(PAnsiChar(FromObject), 10);
        Inc(FJSONLength, 10);
      end else
      begin
        PChars11(FromObject)^ := AnsiString('"},{"NAME":"');
        Inc(PAnsiChar(FromObject), 12);
        Inc(FJSONLength, 12);
      end;
      System.Move(TWebSocket(Data).UserName[1], FromObject^, iSize);
      Inc(PAnsiChar(FromObject), iSize);
      Inc(FJSONLength, iSize);
    end;
  end else
  if (TWebSocket(Data).UserName = FUserName) then  // �Ѽ���
  begin
    FromObject := Data;
    CancelScan := True; // �˳�����
  end;
end;

procedure TInWebSocketManager.Delete(Admin: TWebSocket; const ToUser: String);
var
  oSocket: TWebSocket;
begin
  // �� ToUser �߳�ȥ������һ���ر���Ϣ��
  if (Admin.Role >= crAdmin) and Logined(ToUser, oSocket) then
    InterPushMsg(oSocket, ocClose);
end;

procedure TInWebSocketManager.Execute(Socket: TIOCPSocket);
begin
  if Assigned(FOnReceive) then
    FOnReceive(Socket.Worker, TWebSocket(Socket));  // Socket ʵ������ TWebSocket
end;

procedure TInWebSocketManager.GetUserList(Socket: TWebSocket);
var
  JSON: AnsiString;
  Buffers2: Pointer;
begin
  // �����û��б�, �� JSON ���أ��ֶΣ�NAME
  Socket.ObjPool.Lock;
  try
    FJSONLength := 0; // ����
    FUserName := '';  // ���ǲ����û�
    SetLength(JSON, TInIOCPServer(FServer).WebSocketPool.UsedCount * (SizeOf(TNameString) + 12));
    Buffers2 := PAnsiChar(@JSON[1]);
    TInIOCPServer(FServer).WebSocketPool.Scan(Buffers2, CallbackMethod);
  finally
    Socket.ObjPool.UnLock;
  end;
  if (FJSONLength = 0) then  // û������
    Socket.SendData('{}')
  else begin
    PThrChars(Buffers2)^ := AnsiString('"}]');
    Inc(FJSONLength, 3);
    System.Delete(JSON, FJSONLength + 1, Length(JSON));
    Socket.SendData(JSON);
  end;
end;

procedure TInWebSocketManager.InterPushMsg(Source, Target: TWebSocket);
var
  Msg: TPushMessage;
  Stream: TMemoryStream;
begin
  // ���յ�����Ϣ���� Target ��㲥
  //   �ύ�������̣߳���֪����ʱ�������Ƿ�ɹ���

  if (Source.OpCode <> ocText) then
  begin
    Source.SendData('ֻ�������ı���Ϣ.');
    Exit;
  end;

  if (Source.Completed = False) or
     (Source.MsgSize > IO_BUFFER_SIZE - 50) or
     (Source.JSON.Size > IO_BUFFER_SIZE - 50) or
     (Source.Result.Size > IO_BUFFER_SIZE - 50) then
  begin
    Source.SendData('��Ϣδ�������ջ�̫��, ����.');
    Exit;
  end;

  if Source.Background then
  begin
    Msg := TPushMessage.Create(Source.ObjPool, Source.BufferPool, btUnknown);
    Msg.Add(Target);  // ���� Target

    Stream := TMemoryStream.Create;
    try
      Source.Result.SaveToStream(Stream, True);
      Msg.WriteWebSocketMsg(ocText, Stream.Memory, Stream.Size);
    finally
      Stream.Free;
    end;
  end else
  begin
    // ������롢����
    TWebSocketRef(Source).ClearOwnerMark;
    if Assigned(Target) then  // ���� Target
    begin
      Msg := TPushMessage.Create(Source.RecvBuf, btUnknown);
      Msg.Add(Target);  // ���� Target
    end else
    begin  // �㲥
      Msg := TPushMessage.Create(Source.RecvBuf, btAllClient);
      Msg.IngoreSocket := Source;
      Msg.Group := Source.UserGroup;  // ����
    end;
  end;

  // ���������߳�
  if TInIOCPServer(FServer).PushManager.AddWork(Msg) then
    TWebSocketRef(Source).InternalPong  // Pong �ͻ��ˣ���ʱ�����룩
  else
    Source.SendData('ϵͳ��æ, ����.'); // ��æ��������Msg �ѱ��ͷ�

end;

procedure TInWebSocketManager.InterPushMsg(Socket: TWebSocket; OpCode: TWSOpCode;
  const Text, Group: AnsiString);
var
  Msg: TPushMessage;
begin
  // �� Socket/ȫ���ͻ��� �����ı���Ϣ Text
  if (Length(Text) <= IO_BUFFER_SIZE - 70) then
  begin
    if Assigned(Socket) then // �� Socket��ioPush������δ֪ 0
    begin
      Msg := TPushMessage.Create(Socket, ioPush, 0);
      Msg.IngoreSocket := Socket;  // �����Լ�
      if (Socket.Background = False) then
        Msg.Group := Socket.UserGroup;  // ����
    end else
    begin  // �㲥
      Msg := TPushMessage.Create(TInIOCPServer(FServer).WebSocketPool,
                                 TInIOCPServer(FServer).IODataPool, btAllClient);
      Msg.IngoreSocket := nil;
      Msg.Group := Group;
    end;

    // ����֡��������OpCode�����ȣ�Length(Text)
    Msg.WriteWebSocketMsg(OpCode, PAnsiChar(Text), Length(Text));

    TInIOCPServer(FServer).PushManager.AddWork(Msg);
  end;
end;

function TInWebSocketManager.Logined(const UserName: String; var Socket: TWebSocket): Boolean;
begin
  // �����û� UserName
  // �ҵ��󱣴浽 Socket��������
  TInIOCPServer(FServer).WebSocketPool.Lock;
  try
    Socket := nil;
    FUserName := UserName;  // ������
    TInIOCPServer(FServer).WebSocketPool.Scan(Pointer(Socket), CallbackMethod);
  finally
    Result := Assigned(Socket);
    TInIOCPServer(FServer).WebSocketPool.UnLock;
  end;
end;

function TInWebSocketManager.Logined(const UserName: String): Boolean;
var
  Socket: TWebSocket;
begin
  Result := Logined(UserName, Socket);
end;

procedure TInWebSocketManager.SendTo(const ToUser, Text: string);
var
  oSocket: TWebSocket;
begin
  // ����һ����Ϣ�� ToUser��Msg����̫��
  if (Length(Text) > 0) and (Length(ToUser) > 0) and Logined(ToUser, oSocket) then
    InterPushMsg(oSocket, ocText, System.AnsiToUtf8(Text));
end;

procedure TInWebSocketManager.SendTo(Socket: TWebSocket; const ToUser: string);
var
  Target: TWebSocket;
begin
  // �� Socket ����Ϣ���� ToUser
  if Logined(ToUser, Target) then
    InterPushMsg(Socket, Target);
end;

{ TInHttpDataProvider }

procedure TInHttpDataProvider.Execute(Socket: THttpSocket);
begin
  case Socket.Request.Method of
    hmGet:
      if Assigned(FOnGet) then
        FOnGet(Socket.Worker, Socket.Request, Socket.Response);
    hmPost:  // �ϴ���ϲŵ��� Post
      if Assigned(FOnPost) and Socket.Request.Completed then
        FOnPost(Socket.Worker, Socket.Request, Socket.Response);
    hmConnect:
      { } ;
    hmDelete:
      if Assigned(FOnDelete) then
        FOnDelete(Socket.Worker, Socket.Request, Socket.Response);
    hmPut:
      if Assigned(FOnPut) then
        FOnPut(Socket.Worker, Socket.Request, Socket.Response);
    hmOptions:
      if Assigned(FOnOptions) then
        FOnOptions(Socket.Worker, Socket.Request, Socket.Response);
    hmTrace:
      if Assigned(FOnTrace) then
        FOnTrace(Socket.Worker, Socket.Request, Socket.Response);
    hmHead:  // ���� Head���Ժ���
      Socket.Response.SetHead;
  end;
end;

function TInHttpDataProvider.GetGlobalLock: TThreadLock;
begin
  // ȡȫ����
  if Assigned(FServer) then
    Result := TInIOCPServer(FServer).GlobalLock
  else
    Result := nil;
end;

procedure TInHttpDataProvider.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  // ���ʱ�յ�ɾ�������Ϣ
  if (Operation = opRemove) and (AComponent = FWebSocketManager) then
    FWebSocketManager := nil;
end;

procedure TInHttpDataProvider.SetWebSocketManager(const Value: TInWebSocketManager);
begin
  if (FWebSocketManager <> Value) then
  begin
    FWebSocketManager := Value;
    UpdateServer;
  end;
end;

procedure TInHttpDataProvider.UpdateServer;
begin
  if Assigned(FWebSocketManager) then
  begin
    FWebSocketManager.FServer := FServer;
    FOnUpgrade := FWebSocketManager.FOnUpgrade;  // �ڸ���
    if (TIOCPServerRef(FServer).FBaseMgr = nil) then // ��һ���������
      TIOCPServerRef(FServer).FBaseMgr := FWebSocketManager;      
  end;
end;

{ TPostSocketThread }

procedure TPostSocketThread.Execute;
var
  CreateCount: Integer;
  RecreateSockets: Boolean;
  oSocket: TSocketBroker;
begin
  // ����������

  while (Terminated = False) do
  begin
    // �Ƿ�Ҫ���½�
    TInIOCPServer(FOwner.FServer).GlobalLock.Acquire;
    try
      CreateCount := FOwner.FCreateCount;
      RecreateSockets := (TInIOCPServer(FOwner.FServer).IOCPSocketPool.UsedCount = 0);
      FOwner.FCreateCount := 0;
    finally
      TInIOCPServer(FOwner.FServer).GlobalLock.Release;
    end;

    if (CreateCount > 0) then // ����Ͷ������
      FOwner.InterConnectOuter(CreateCount)
    else
    if RecreateSockets then  // �ؽ�
    begin
      // �Ƚ�һ���׽��֣���������
      oSocket := TInIOCPServer(FOwner.FServer).IOCPSocketPool.Pop^.Data;
      TSocketBrokerRef(oSocket).SetConnection(FOwner.FServer, iocp_utils.CreateSocket);

      while (Terminated = False) do
        if iocp_utils.ConnectSocket(oSocket.Socket,
                                    FOwner.FServerAddr,
                                    FOwner.FServerPort) then // ����
        begin
          iocp_wsExt.SetKeepAlive(oSocket.Socket);  // ����
          TInIOCPServer(FOwner.FServer).IOCPEngine.BindIoCompletionPort(oSocket.Socket);  // ��
          TSocketBrokerRef(oSocket).SendInnerFlag;  // ���ͱ�־
          Break;
        end else
        if (Terminated = False) then
          Sleep(100);

      // ����Ͷ������
      FOwner.InterConnectOuter(FOwner.FConnectionCount - 1);
    end;

    if (Terminated = False) then
      Sleep(100); // �ȴ�
  end;

end;

{ TBrokenOptions }

procedure TBrokenOptions.CheckServerPort(const AServerAddr: string; AServerPort: Word);
begin
  if (AServerAddr = GetServerAddr) and (AServerPort = GetServerPort) then
    raise Exception.Create('�ڲ�/�ⲿ�������˿ڲ�����IOCP�����һ��.');
end;

constructor TBrokenOptions.Create(AOwner: TInIOCPBroker);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TBrokenOptions.GetServerAddr: string;
begin
  if (Self is TProxyOptions) then
    Result := FOwner.FServerAddr
  else
    Result := FOwner.FDefaultInnerAddr;
end;

function TBrokenOptions.GetServerPort: Word;
begin
  if (Self is TProxyOptions) then
    Result := FOwner.FServerPort
  else
    Result := FOwner.FDefaultInnerPort;
end;

procedure TBrokenOptions.SetServerAddr(const Value: string);
begin
  if (Self is TProxyOptions) then
    FOwner.FServerAddr := Value
  else
    FOwner.FDefaultInnerAddr := Value;
end;

procedure TBrokenOptions.SetServerPort(const Value: Word);
begin
  if (Self is TProxyOptions) then
    FOwner.FServerPort := Value
  else
    FOwner.FDefaultInnerPort := Value;
end;

{ TProxyOptions }

function TProxyOptions.GetConnectionCount: Word;
begin
  Result := FOwner.FConnectionCount;
end;

procedure TProxyOptions.SetConnectionCount(const Value: Word);
begin
  FOwner.FConnectionCount := Value;
end;

{ TInIOCPBroker }

procedure TInIOCPBroker.AddConnection(Broker: TSocketBroker; const InnerId: String);
var
  i: Integer;
  Connections: TInList;
begin
  // ���ڲ����ӵ��б��Ѿ��� IOCPSocketPool��
  //   ÿһ InnerId ��Ӧһ�����������Ӧһ����������
  GlobalLock.Acquire;
  try
    i := FReverseBrokers.IndexOf(InnerId);  // ��д
    if (i = -1) then  // �½��������б�
    begin
      Connections := TInList.Create;
      FReverseBrokers.AddObject(InnerId, Connections);
    end else
      Connections := TInList(FReverseBrokers.Objects[i]);
    Connections.Add(Broker);
  finally
    GlobalLock.Release;
  end;
end;

procedure TInIOCPBroker.BindInnerBroker(Connection: TSocketBroker;
  const Data: PAnsiChar; DataSize: Cardinal);
var
  i, k: Integer;
  oSocket: TSocketBroker;
begin
  // ���ⲿ���Ӻ��ڲ��Ĺ����������ڲ����Ӱ� BrokerId ����
  if (FProxyType = ptOuter) then
  begin
    k := 0;
    repeat
      GlobalLock.Acquire;
      try
        case FReverseBrokers.Count of
          0:
            oSocket := nil;
          1:  // �õ�һ��
            oSocket := TSocketBroker(TInList(FReverseBrokers.Objects[0]).PopFirst);
          else begin
            i := FReverseBrokers.IndexOf(TSocketBrokerRef(Connection).FBrokerId);
            if (i > -1) then
              oSocket := TSocketBroker(TInList(FReverseBrokers.Objects[i]).PopFirst)
            else
              oSocket := nil;            
          end;
        end;
      finally
        GlobalLock.Release;
      end;
      if Assigned(oSocket) then
        TSocketBrokerRef(Connection).AssociateInner(oSocket)
      else begin
        Inc(k);
        Sleep(10);
      end;
    until TInIOCPServer(FServer).Active and ((k > 100) or Assigned(oSocket));
  end;
end;

procedure TInIOCPBroker.CheckServerPort(const AServerAddr: string; AServerPort: Word);
begin
  // �����������Ķ˿ڣ����ܺ� TInIOCPServer ��һ����
  FOuterServer.CheckServerPort(AServerAddr, AServerPort);
  FInnerServer.CheckServerPort(AServerAddr, AServerPort);
end;

constructor TInIOCPBroker.Create(AOwner: TComponent);
begin
  inherited;
  FInnerServer := TBrokenOptions.Create(Self);
  FOuterServer := TProxyOptions.Create(Self);
  FConnectionCount := 50;
  FDefaultInnerPort := 80;
  FServerPort := 80;
end;

destructor TInIOCPBroker.Destroy;
var
  i: Integer;
begin
  // �ͷ���Դ
  if Assigned(FThread) then
    FThread.Terminate;
  if (FProxyType = ptOuter) and Assigned(FReverseBrokers) then
  begin
    for i := 0 to FReverseBrokers.Count - 1 do  // ��һ�ͷ�
      TInList(FReverseBrokers.Objects[i]).Free;
    FReverseBrokers.Free;
  end;
  FInnerServer.Free;
  FOuterServer.Free;
  inherited;
end;

function TInIOCPBroker.GetReverseMode: Boolean;
begin
  // �Ƿ�Ϊ����ģʽ
  Result := (FProxyType = ptDefault) and
            (FServerAddr <> '') and (FServerPort > 0);
end;

procedure TInIOCPBroker.IncOuterConnection;
begin
  // �����ڲ�����
  GlobalLock.Acquire;
  try
    if TInIOCPServer(FServer).Active then
      Inc(FCreateCount);
  finally
    GlobalLock.Release;
  end;
end;

procedure TInIOCPBroker.InterConnectOuter(ACount: Integer);
var
  i: Integer;
begin
  // ������������ӵ��ⲿ������
  for i := 0 to ACount - 1 do
    PostConnectionsEx;
end;

procedure TInIOCPBroker.PostConnections;
begin
  // ���߳̽�����
  if not Assigned(FThread) then
  begin
    if (FConnectionCount < 2) then
      FConnectionCount := 2;
    FThread := TPostSocketThread.Create(True);
    FThread.FreeOnTerminate := True;
    FThread.FOwner := Self;
    FThread.Resume;
  end;
end;

procedure TInIOCPBroker.PostConnectionsEx;
var
  lResult: Boolean;
  oSocket: TSocketBroker;
begin
  // Ͷ���������ⲿ������
  oSocket := TInIOCPServer(FServer).IOCPSocketPool.Pop^.Data;
  TSocketBrokerRef(oSocket).SetConnection(FServer, iocp_utils.CreateSocket);  // ���׽���

  if iocp_utils.ConnectSocket(oSocket.Socket, FServerAddr, FServerPort) then // ����
  begin
    iocp_wsExt.SetKeepAlive(oSocket.Socket);  // ����
    lResult := TInIOCPServer(FServer).IOCPEngine.BindIoCompletionPort(oSocket.Socket);  // ��
    if lResult then
      TSocketBrokerRef(oSocket).SendInnerFlag  // ���ͱ�־
    else
      TInIOCPServer(FServer).CloseSocket(oSocket);
  end else
    TInIOCPServer(FServer).CloseSocket(oSocket);
end;

procedure TInIOCPBroker.Prepare;
begin
  case FProxyType of
    ptDefault:  // �����ⲿ������
      if (FServerAddr <> '') and (FServerPort > 0) then
        PostConnections;
    ptOuter:    // ���ڲ������б�
      FReverseBrokers := TStringList.Create;
  end;
end;

procedure TInIOCPBroker.Stop;
begin
  // ֹͣ
  if Assigned(FThread) then
    FThread.Terminate;
  GlobalLock.Acquire;
  try
    FThread := nil;
  finally
    GlobalLock.Release;
  end;  
end;

{ TBusiWorker }

procedure TBusiWorker.AddDataModule(Index: Integer);
  function CreateNewDataModule: TInIOCPDataModule;
  begin
    Result := TDataModuleClass(FDMList.Objects[Index]).Create(TComponent(FServer));
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TBusiWorker.CreateDataModule->������ģ�ɹ�: ' + IntToStr(Index));
    {$ENDIF}
  end;
begin
  // ����״̬��ģ�����ǻ�׷�ӵ�ĩβ��
  if (Index >= 0) and (Index < FDMCount) then
  begin
    if (FDMArray[Index] = nil) then   // ���Ը���
      FDMArray[Index] := CreateNewDataModule;
  end else
  if (Index = FDMList.Count - 1) then // ������Ҫ��ע�ᵽ�б�
  begin
    FDMCount := FDMList.Count;
    SetLength(FDMArray, FDMCount);
    FDMArray[Index] := CreateNewDataModule;
  end;
end;

constructor TBusiWorker.Create(AServer: TObject; AThreadIdx: Integer);
begin
  FDataModule := nil;
  FThreadIdx := AThreadIdx;

  FServer := AServer;    // TInIOCPServer
  FGlobalLock := TInIOCPServer(FServer).GlobalLock;

  if Assigned(TInIOCPServer(FServer).DatabaseManager) then
  begin
    FDMList := TInIOCPServer(FServer).DatabaseManager.DataModuleList; // ������ģ�б�
    FDMCount := FDMList.Count;  // �ر�ʱ FDMList.Clear����ס
  end else
  begin
    FDMList := nil;
    FDMCount := 0;
  end;

  inherited Create;
end;

procedure TBusiWorker.CreateDataModules;
var
  i: Integer;
begin
  // ����ģʵ����һ��ҵ��ִ�����У�һ����ģһ��ʵ����
  if (FDMCount > 0) then
  begin
    SetLength(FDMArray, FDMCount);
    for i := 0 to FDMCount - 1 do
    begin
      FDMArray[i] := TDataModuleClass(FDMList.Objects[i]).Create(TComponent(FServer));
      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('TBusiWorker.CreateDataModule->������ģ�ɹ�: ' + IntToStr(i));
      {$ENDIF}
    end;
  end;
end;

destructor TBusiWorker.Destroy;
var
  i: Integer;
begin
  // �ͷ���ģʵ��
  for i := 0 to FDMCount - 1 do
    if Assigned(FDMArray[i]) then
    begin
      FDMArray[i].Free;
      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('TBusiWorker.Destroy->�ͷ���ģ�ɹ�: ' + IntToStr(i));
      {$ENDIF}
    end;
  SetLength(FDMArray, 0);
  inherited;
end;

procedure TBusiWorker.Execute(const Socket: TIOCPSocket);
begin
  // ���� C/S ҵ��ģ��

  // Ĭ�ϵ���������
  SetDefaultDataModule;

  with TInIOCPServer(FServer) do
    case Socket.Params.Action of
      atUserLogin..atUserState:    // �ͻ��˹���
        if Assigned(ClientManager) then
          ClientManager.Execute(Socket);

      atTextSend..atTextFileList:  // ��Ϣ����
        if Assigned(MessageManager) then
          MessageManager.Execute(Socket);

      atFileList..atFileDownShare: // �ļ�����
        if Assigned(FileManager) then
          FileManager.Execute(Socket);

      atDBGetConns..atDBApplyUpdates: // ���ݿ����
        if Assigned(DatabaseManager) and Assigned(FDataModule) then
          DatabaseManager.Execute(Socket);

      atCallFunction..atCustomAction:   // �Զ�����Ϣ
        if Assigned(CustomManager) then
          CustomManager.Execute(Socket);
    end;
end;

function TBusiWorker.GetDataModule(Index: Integer): TInIOCPDataModule;
begin
  // ȡ��ģʵ��
  if (Index >= 0) and (Index < FDMCount) then
    Result := FDMArray[Index]
  else
    Result := nil;
end;

procedure TBusiWorker.HttpExecute(const Socket: THttpSocket);
begin
  // ���� http ����ҵ��ģ��
  SetDefaultDataModule;  // Ĭ�ϵ���������
  TInIOCPServer(FServer).HttpDataProvider.Execute(Socket);
end;

procedure TBusiWorker.RemoveDataModule(Index: Integer);
begin
  // ��ɾ���������ռ䣬��ֹӰ������ʹ�õ�Ӧ��
  if (Index >= 0) and (Index < FDMCount) then
  begin
    FDMArray[Index].Free;
    FDMArray[Index] := nil;
  end;
end;

procedure TBusiWorker.SetConnection(Index: Integer);
begin
  // ���õ�ǰ��ģ
  if (Index >= 0) and (Index < FDMCount) then
    FDataModule := FDMArray[Index];
end;

procedure TBusiWorker.SetDefaultDataModule;
begin
  // ���õ�ǰ����������
  if (FDataModule = Nil) and (FDMCount > 0) then
    FDataModule := FDMArray[0];
end;

procedure TBusiWorker.StreamExecute(const Socket: TStreamSocket);
begin
  SetDefaultDataModule;  // Ĭ�ϵ���������
  TInIOCPServer(FServer).StreamManager.Execute(TIOCPSocket(Socket));
end;

procedure TBusiWorker.WebSocketExecute(const Socket: TWebSocket);
begin
  // ���� WebSocket ҵ��ģ��
  SetDefaultDataModule;  // Ĭ�ϵ���������
  with TInIOCPServer(FServer).HttpDataProvider do
    WebSocketManager.Execute(TIOCPSocket(Socket));  // ���� TIOCPSocket
end;

end.
