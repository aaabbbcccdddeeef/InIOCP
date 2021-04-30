(*
 * iocp ����˸����׽��ַ�װ
 *)
unit iocp_sockets;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes, System.SysUtils, Datasnap.DBClient,
  Datasnap.Provider, System.Variants, System.DateUtils, {$ELSE}
  Windows, Classes, SysUtils, DBClient,
  Provider, Variants, DateUtils, {$ENDIF}
  iocp_base, iocp_zlib, iocp_api,
  iocp_Winsock2, iocp_wsExt, iocp_utils,
  iocp_baseObjs, iocp_objPools, iocp_senders,
  iocp_receivers, iocp_msgPacks, iocp_log,
  http_objects, iocp_WsJSON;

type

  // ================== �����׽��� �� ======================

  TRawSocket = class(TObject)
  private
    FConnected: Boolean;       // �Ƿ�����
    FErrorCode: Integer;       // �쳣����
    FPeerIP: AnsiString;       // IP
    FPeerIPPort: AnsiString;   // IP+Port
    FPeerPort: Integer;        // Port
    FSocket: TSocket;          // �׽���
    procedure InternalClose;    
  protected
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); virtual;
    procedure SetPeerAddr(const Addr: PSockAddrIn);
  public
    constructor Create(AddSocket: Boolean);
    destructor Destroy; override;
    procedure Close; virtual;    
  public
    property Connected: Boolean read FConnected;
    property ErrorCode: Integer read FErrorCode;
    property PeerIP: AnsiString read FPeerIP;
    property PeerPort: Integer read FPeerPort;
    property PeerIPPort: AnsiString read FPeerIPPort;
    property Socket: TSocket read FSocket;
  public
    class function GetPeerIP(const Addr: PSockAddrIn): AnsiString;
  end;

  // ================== �����׽��� �� ======================

  TListenSocket = class(TRawSocket)
  public
    function Bind(Port: Integer; const Addr: String = ''): Boolean;
    function StartListen: Boolean;
  end;

  // ================== AcceptEx Ͷ���׽��� ======================

  TAcceptSocket = class(TRawSocket)
  private
    FListenSocket: TSocket;    // �����׽���
    FIOData: TPerIOData;       // �ڴ��
    FByteCount: Cardinal;      // Ͷ����
  public
    constructor Create(ListenSocket: TSocket);
    destructor Destroy; override;
    function AcceptEx: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure NewSocket; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function SetOption: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
  end;

  // ================== ҵ��ִ��ģ����� ======================

  TBaseSocket   = class;
  TStreamSocket = class;
  TIOCPSocket   = class;
  THttpSocket   = class;
  TWebSocket    = class;

  TBaseWorker = class(TObject)
  protected
    FServer: TObject;           // TInIOCPServer ������
    FGlobalLock: TThreadLock;   // ȫ����
    FThreadIdx: Integer;        // ���
  protected
    procedure Execute(const ASocket: TIOCPSocket); virtual; abstract;
    procedure StreamExecute(const ASocket: TStreamSocket); virtual; abstract;
    procedure HttpExecute(const ASocket: THttpSocket); virtual; abstract;
    procedure WebSocketExecute(const ASocket: TWebSocket); virtual; abstract;
  public
    property GlobalLock: TThreadLock read FGlobalLock; // ������ҵ���ʱ��
    property ThreadIdx: Integer read FThreadIdx;
  end;

  // ================== Socket ���� ======================
  // FState ״̬��
  // 1. ���� = 0���ر� = 9
  // 2. ռ�� = 1��TransmitFile ʱ +1���κ��쳣�� +1
  //    ������ֵ=1,2������ֵ��Ϊ�쳣��
  // 3. ���Թرգ�����=0��TransmitFile=2������Ŀ��У�������ֱ�ӹر�
  // 4. ����������=0 -> �ɹ�

  TBaseSocket = class(TRawSocket)
  private
    FLinkNode: PLinkRec;       // ��Ӧ�ͻ��˳ص� PLinkRec���������

    FRecvBuf: PPerIOData;      // �����õ����ݰ�
    FSender: TBaseTaskSender;  // ���ݷ����������ã�

    FObjPool: TIOCPSocketPool; // �����
    FServer: TObject;          // TInIOCPServer ������
    FWorker: TBaseWorker;      // ҵ��ִ���ߣ����ã�

    FRefCount: Integer;        // ������
    FState: Integer;           // ״̬��ԭ�Ӳ���������
    FTickCount: Cardinal;      // �ͻ��˷��ʺ�����
    FUseTransObj: Boolean;     // ʹ�� TTransmitObject ����

    FData: Pointer;            // ��������ݣ����û���չ

    function CheckDelayed(ATickCount: Cardinal): Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetActive: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetBufferPool: TIODataPool; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetReference: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function GetSocketState: Boolean; {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure InternalRecv;
    procedure OnSendError(IOType: TIODataType; ErrorCode: Integer);
  protected
    FBackground: Boolean;      // ��ִ̨��״̬
    FByteCount: Cardinal;      // �����ֽ���
    FLinkSocket: TBaseSocket;  // ��ִ̨��ʱ���������������
    FCompleted: Boolean;       // �������/����ҵ��

    {$IFDEF TRANSMIT_FILE}     // TransmitFile ����ģʽ
    FTask: TTransmitObject;    // ��������������
    FTaskExists: Boolean;      // ��������
    procedure FreeTransmitRes; // �ͷ� TransmitFile ����Դ
    procedure InterTransmit;   // ��������
    procedure InterFreeRes; virtual; abstract; // �ͷŷ�����Դ
    {$ENDIF}

    procedure ClearResources; virtual; abstract;
    procedure Clone(Source: TBaseSocket);  // ��¡��ת����Դ��
    procedure DoWork(AWorker: TBaseWorker; ASender: TBaseTaskSender);  // ҵ���̵߳������
    procedure BackgroundExecute; virtual;  // ��ִ̨��
    procedure ExecuteWork; virtual; abstract;  // �������
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); override;
    procedure InterCloseSocket(Sender: TObject); virtual;
    procedure InternalPush(AData: PPerIOData); // �������
    procedure MarkIODataBuf(AData: PPerIOData); virtual;
    procedure SocketError(IOType: TIODataType); virtual;

    // �������·�������ֹ��Ӧ�ò㱻����
    function CheckTimeOut(NowTickCount, TimeoutInteval: Cardinal): Boolean;  // ��ʱ���
    function Lock(PushMode: Boolean): Integer;  // ����ǰ����
    function GetObjectState(const Group: string; AdminType: Boolean): Boolean; virtual;  // ȡ������״̬

    procedure CopyResources(AMaster: TBaseSocket); virtual; // ���̨��Դ
    procedure PostRecv; virtual;  // Ͷ�ݽ���
    procedure PostEvent(IOKind: TIODataType); virtual; abstract; // Ͷ���¼�
    procedure TryClose;  // ���Թر�
  public
    constructor Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec); virtual;
    destructor Destroy; override;
    procedure Close; override;  // �ر�
  public
    property Active: Boolean read GetActive;
    property Background: Boolean read FBackground;  // ��ִ̨��ģʽ
    property BufferPool: TIODataPool read GetBufferPool;
    property ByteCount: Cardinal read FByteCount;
    property Completed: Boolean read FCompleted;
    property LinkNode: PLinkRec read FLinkNode;
    property ObjPool: TIOCPSocketPool read FObjPool;
    property RecvBuf: PPerIOData read FRecvBuf;
    property Reference: Boolean read GetReference;
    property Sender: TBaseTaskSender read FSender;
    property SocketState: Boolean read GetSocketState;
    property Worker: TBaseWorker read FWorker;
  public
    // ���� Data���û�������չ
    property Data: Pointer read FData write FData;
  end;

  TBaseSocketClass = class of TBaseSocket;

  // ================== ԭʼ������ Socket ==================

  TStreamSocket = class(TBaseSocket)
  private
    FClientId: TNameString;    // �ͻ��� id
    FRole: TClientRole;        // Ȩ��
  protected
    function GetObjectState(const Group: string; AdminType: Boolean): Boolean; override;  // ȡ������״̬
    {$IFDEF TRANSMIT_FILE}
    procedure InterFreeRes; override;
    {$ENDIF}
    procedure ClearResources; override;
    procedure ExecuteWork; override;
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); override;
    procedure PostEvent(IOKind: TIODataType); override;
  public
    procedure SendData(const Data: PAnsiChar; Size: Cardinal); overload;
    procedure SendData(const Msg: String); overload;
    procedure SendData(Handle: THandle); overload;
    procedure SendData(Stream: TStream); overload;
    procedure SendDataVar(Data: Variant);
  public
    property ClientId: TNameString read FClientId write FClientId;
    property Role: TClientRole read FRole write FRole;  // ��ɫ/Ȩ��
  end;

  // ================== C/S ģʽҵ���� ==================

  // 1. ����˽��յ�������

  TReceiveParams = class(TReceivePack)
  private
    FSocket: TIOCPSocket;     // ����
    FMsgHead: PMsgHead;       // Э��ͷλ��
    function GetLogName: string;
  protected
    procedure SetUniqueMsgId;
  public
    constructor Create(AOwner: TIOCPSocket); overload;
    procedure CreateAttachment(const ALocalPath: string); override;
  public
    property LogName: string read GetLogName;
    property MsgHead: PMsgHead read FMsgHead;
    property Socket: TIOCPSocket read FSocket;
  end;

  // 2. �������ͻ��˵�����

  TReturnResult = class(TBaseMessage)
  private
    FSocket: TIOCPSocket;     // ����
    FSender: TBaseTaskSender; // ��������
  public
    constructor Create(AOwner: TIOCPSocket; AInitialize: Boolean = True);
    procedure LoadFromFile(const AFileName: String; ServerMode: Boolean = False); override;
    // ����˹�����������
    procedure LoadFromCDSVariant(const ACDSAry: array of TClientDataSet;
                                 const ATableNames: array of String); override;
    procedure LoadFromVariant(const AProviders: array of TDataSetProvider;
                              const ATableNames: array of String); override;
  public
    property Socket: TIOCPSocket read FSocket;
    // ����Э��ͷ����
    property Action: TActionType read FAction;
    property ActResult: TActionResult read FActResult write FActResult;
    property Offset: TFileSize read FOffset;
    property OffsetEnd: TFileSize read FOffsetEnd;
  end;

  TIOCPSocket = class(TBaseSocket)
  private
    FReceiver: TServerReceiver; // ���ݽ�����
    FParams: TReceiveParams;    // ���յ�����Ϣ����������
    FResult: TReturnResult;     // ���ص�����
    FEnvir: PEnvironmentVar;    // ����������Ϣ
    FAction: TActionType;       // �ڲ��¼�
    FSessionId: Cardinal;       // �Ի�ƾ֤ id

    function CheckMsgHead(InBuf: PAnsiChar): Boolean;
    function CreateSession: Cardinal;
    function GetRole: TClientRole;
    function GetLogName: string;
    function SessionValid(ASession: Cardinal): Boolean;
    function GetUserGroup: string;

    procedure CreateResources;
    procedure HandleDataPack;
    procedure ReturnHead(ActResult: TActionResult);
    procedure ReturnMessage(ActResult: TActionResult; const ErrMsg: String = '');
    procedure ReturnResult;
    procedure SetLogoutState;
  protected
    // ȡ������״̬
    function GetObjectState(const Group: string; AdminType: Boolean): Boolean; override;
    {$IFDEF TRANSMIT_FILE}
    procedure InterFreeRes; override;
    {$ENDIF}
    procedure ClearResources; override;
    procedure CopyResources(AMaster: TBaseSocket); override;
    procedure BackgroundExecute; override;
    procedure ExecuteWork; override;  // �������
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); override;
    procedure InterCloseSocket(Sender: TObject); override;
    procedure PostEvent(IOKind: TIODataType); override;
    procedure SetLogState(AEnvir: PEnvironmentVar);  // ҵ��ģ�����
    procedure SocketError(IOType: TIODataType); override;
  public
    destructor Destroy; override;
  public
    property Action: TActionType read FAction;
    property Envir: PEnvironmentVar read FEnvir;
    property LoginName: string read GetLogName;
    property Params: TReceiveParams read FParams;
    property Result: TReturnResult read FResult;
    property Role: TClientRole read GetRole;  // ��ɫ/Ȩ��    
    property SessionId: Cardinal read FSessionId;
    property UserGroup: string read GetUserGroup;
  end;

  // ================== Http Э�� Socket ==================

  TRequestObject = class(THttpRequest);

  TResponseObject = class(THttpResponse);

  THttpSocket = class(TBaseSocket)
  private
    FRequest: THttpRequest;    // http ����
    FResponse: THttpResponse;    // http Ӧ��
    FStream: TFileStream;      // �����ļ�����
    FKeepAlive: Boolean;       // ��������
    function GetSessionId: AnsiString;
    procedure UpgradeSocket(SocketPool: TIOCPSocketPool);
    procedure DecodeHttpRequest;
  protected
    {$IFDEF TRANSMIT_FILE}
    procedure InterFreeRes; override;
    {$ENDIF}
    procedure ClearResources; override;
    procedure ExecuteWork; override;
    procedure PostEvent(IOKind: TIODataType); override;  // Ͷ���¼�
    procedure SocketError(IOType: TIODataType); override;
  public
    destructor Destroy; override;
    // �ļ�������
    procedure CreateStream(const FileName: String);
    procedure WriteStream(Data: PAnsiChar; DataLength: Integer);
    procedure CloseStream;
  public
    property Request: THttpRequest read FRequest;
    property Response: THttpResponse read FResponse;
    property SessionId: AnsiString read GetSessionId;
  end;

  // ================== WebSocket �� ==================

  // . �յ��� JSON ��Ϣ
  
  TReceiveJSON = class(TSendJSON)
  private
    FSocket: TWebSocket;
  public
    constructor Create(AOwner: TWebSocket);
  public
    property Socket: TWebSocket read FSocket;
  end;

  // . �����ص� JSON ��Ϣ

  TResultJSON = class(TSendJSON)
  private
    FSocket: TWebSocket;
  public
    constructor Create(AOwner: TWebSocket);
  public
    property Socket: TWebSocket read FSocket;
  end;
  
  TWebSocket = class(TBaseSocket)
  private
    FReceiver: TWSServerReceiver;  // ���ݽ�����
    FJSON: TReceiveJSON;       // �յ��� JSON ����
    FResult: TResultJSON;      // Ҫ���ص� JSON ����
    FMsgType: TWSMsgType;      // ��������
    FOpCode: TWSOpCode;        // WebSocket ��������
    FRole: TClientRole;        // �ͻ�Ȩ�ޣ�Ԥ�裩
    FUserGroup: TNameString;   // �û�����
    FUserName: TNameString;    // �û����ƣ�Ԥ�裩
  protected
    FInData: PAnsiChar;        // �����յ�����������λ��
    FMsgSize: UInt64;          // ��ǰ��Ϣ�յ����ۼƳ���
    FFrameSize: UInt64;        // ��ǰ֡����
    FFrameRecvSize: UInt64;    // �����յ������ݳ���
    procedure SetProps(AOpCode: TWSOpCode; AMsgType: TWSMsgType;
                       AData: Pointer; AFrameSize: Int64; ARecvSize: Cardinal);
  protected
    function GetObjectState(const Group: string; AdminType: Boolean): Boolean; override;  // ȡ������״̬
    procedure ClearOwnerMark;
    procedure ClearResources; override;
    procedure CopyResources(AMaster: TBaseSocket); override;
    procedure BackgroundExecute; override;
    procedure ExecuteWork; override;
    procedure InternalPong;
    procedure PostEvent(IOKind: TIODataType); override;
  public
    constructor Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec); override;
    destructor Destroy; override;

    procedure SendData(const Data: PAnsiChar; Size: Cardinal); overload;
    procedure SendData(const Msg: String); overload;
    procedure SendData(Handle: THandle); overload;
    procedure SendData(Stream: TStream); overload;
    procedure SendDataVar(Data: Variant); 

    procedure SendResult(UTF8CharSet: Boolean = False);
  public
    property InData: PAnsiChar read FInData;  // raw
    property FrameRecvSize: UInt64 read FFrameRecvSize; // raw
    property FrameSize: UInt64 read FFrameSize; // raw
    property MsgSize: UInt64 read FMsgSize; // raw

    property JSON: TReceiveJSON read FJSON; // JSON
    property Result: TResultJSON read FResult; // JSON
  public
    property MsgType: TWSMsgType read FMsgType; // ��������
    property OpCode: TWSOpCode read FOpCode;  // WebSocket ����
  public
    property Role: TClientRole read FRole write FRole;
    property UserGroup: TNameString read FUserGroup write FUserGroup;
    property UserName: TNameString read FUserName write FUserName;
  end;

  // ================== TSocketBroker �����׽��� ==================

  TSocketBroker = class;

  TAcceptBroker = procedure(Sender: TSocketBroker; const Host: AnsiString;
                            Port: Integer; var Accept: Boolean) of object;

  TBindIPEvent  = procedure(Sender: TSocketBroker; const Data: PAnsiChar;
                            DataSize: Cardinal) of object;

  TForwardDataEvent = procedure(Sender: TSocketBroker; const Data: PAnsiChar;
                                DataSize: Cardinal; Direction: Integer) of object;

  TOuterPingEvent = TBindIPEvent;

  TSocketBroker = class(TBaseSocket)
  private
    FAction: Integer;          // ��ʼ��
    FBroker: TObject;          // �������
    FCmdConnect: Boolean;      // HTTP ����ģʽ

    FDualBuf: PPerIOData;      // �����׽��ֵĽ����ڴ��
    FDualConnected: Boolean;   // �����׽�������״̬
    FDualSocket: TSocket;      // �������׽���

    FRecvState: Integer;       // ����״̬
    FSocketType: TSocketBrokerType;  // ����
    FTargetHost: AnsiString;   // ������������ַ
    FTargetPort: Integer;      // �����ķ������˿�

    FOnBind: TBindIPEvent;     // ���¼�
    FOnBeforeForward: TForwardDataEvent;  // ת��ǰ�¼�

    // �µ�Ͷ�ŷ���
    procedure BrokerPostRecv(ASocket: TSocket; AData: PPerIOData; ACheckState: Boolean = True);
    // HTTP Э��İ�
    procedure HttpBindOuter(Connection: TSocketBroker; const Data: PAnsiChar; DataSize: Cardinal);
  protected
    FBrokerId: AnsiString;     // �����ķ������ Id
    procedure ClearResources; override;
    procedure ExecuteWork; override;
    procedure IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer = nil); override;
    procedure InterCloseSocket(Sender: TObject); override;
    procedure MarkIODataBuf(AData: PPerIOData); override;
    procedure PostEvent(IOKind: TIODataType); override; // Ͷ���¼�����ɾ�����ܾ����񡢳�ʱ        
  protected
    procedure AssociateInner(InnerBroker: TSocketBroker);
    procedure SendInnerFlag;
    procedure SetConnection(AServer: TObject; Connection: TSocket);
  public
    procedure CreateBroker(const AServer: AnsiString; APort: Integer);  // �������м�
  end;

implementation

uses
  iocp_server, http_base, http_utils, iocp_threads, iocp_managers;

type
  THeadMessage   = class(TBaseMessage);
  TIOCPBrokerRef = class(TInIOCPBroker);

{ TRawSocket }

procedure TRawSocket.Close;
begin
  if FConnected then
    InternalClose;  // �ر�
end;

constructor TRawSocket.Create(AddSocket: Boolean);
begin
  inherited Create;
  if AddSocket then  // ��һ�� Socket
    IniSocket(nil, iocp_utils.CreateSocket);
end;

destructor TRawSocket.Destroy;
begin
  if FConnected then
    InternalClose; // �ر�
  inherited;
end;

class function TRawSocket.GetPeerIP(const Addr: PSockAddrIn): AnsiString;
begin
  // ȡIP
  Result := iocp_Winsock2.inet_ntoa(Addr^.sin_addr);
end;

procedure TRawSocket.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  // ���� Socket
  FSocket := ASocket;
  FConnected := FSocket <> INVALID_SOCKET;
end;

procedure TRawSocket.InternalClose;
begin
  // �ر� Socket
  try
    if (FSocket > 0) then  // ��ִ̨��ʱΪ 0
    begin
      iocp_Winsock2.Shutdown(FSocket, SD_BOTH);
      iocp_Winsock2.CloseSocket(FSocket);
      FSocket := INVALID_SOCKET;
    end;
  finally
    FConnected := False;
  end;
end;

procedure TRawSocket.SetPeerAddr(const Addr: PSockAddrIn);
begin
  // �ӵ�ַ��Ϣȡ IP��Port
  FPeerIP := iocp_Winsock2.inet_ntoa(Addr^.sin_addr);
  FPeerPort := iocp_Winsock2.htons(Addr^.sin_port);  // ת��
  FPeerIPPort := FPeerIP + ':' + IntToStr(FPeerPort);
end;

{ TListenSocket }

function TListenSocket.Bind(Port: Integer; const Addr: String): Boolean;
var
  SockAddr: TSockAddrIn;
begin
  // �󶨵�ַ
  // htonl(INADDR_ANY); ���κε�ַ������������ϼ���
  FillChar(SockAddr, SizeOf(TSockAddr), 0);

  SockAddr.sin_family := AF_INET;
  SockAddr.sin_port := htons(Port);
  SockAddr.sin_addr.S_addr := inet_addr(PAnsiChar(ResolveHostIP(Addr)));

  if (iocp_Winsock2.bind(FSocket, TSockAddr(SockAddr), SizeOf(TSockAddr)) <> 0) then
  begin
    Result := False;
    FErrorCode := WSAGetLastError;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TListenSocket.Bind->Error:' + IntToStr(FErrorCode));
    {$ENDIF}
  end else
  begin
    Result := True;
    FErrorCode := 0;
  end;
end;

function TListenSocket.StartListen: Boolean;
begin
  // ����
  if (iocp_Winsock2.listen(FSocket, MaxInt) <> 0) then
  begin
    Result := False;
    FErrorCode := WSAGetLastError;
    {$IFDEF DEBUG_MODE}  
    iocp_log.WriteLog('TListenSocket.StartListen->Error:' + IntToStr(FErrorCode));
    {$ENDIF}
  end else
  begin
    Result := True;
    FErrorCode := 0;
  end;
end;

{ TAcceptSocket }

function TAcceptSocket.AcceptEx: Boolean;
begin
  // Ͷ�� AcceptEx ����
  FillChar(FIOData.Overlapped, SizeOf(TOverlapped), 0);

  FIOData.Owner := Self;       // ����
  FIOData.IOType := ioAccept;  // ������
  FByteCount := 0;

  Result := gAcceptEx(FListenSocket, FSocket,
                      Pointer(FIOData.Data.buf), 0,   // �� 0�����ȴ���һ������
                      ADDRESS_SIZE_16, ADDRESS_SIZE_16,
                      FByteCount, @FIOData.Overlapped);

  if Result then
    FErrorCode := 0
  else begin
    FErrorCode := WSAGetLastError;
    Result := FErrorCode = WSA_IO_PENDING;
    {$IFDEF DEBUG_MODE}
    if (Result = False) then
      iocp_log.WriteLog('TAcceptSocket.AcceptEx->Error:' + IntToStr(FErrorCode));
    {$ENDIF}
  end;
end;

constructor TAcceptSocket.Create(ListenSocket: TSocket);
begin
  inherited Create(True);
  // �½� AcceptEx �õ� Socket
  FListenSocket := ListenSocket;
  GetMem(FIOData.Data.buf, ADDRESS_SIZE_16 * 2);  // ����һ���ڴ�
  FIOData.Data.len := ADDRESS_SIZE_16 * 2;
  FIOData.Node := nil;  // ��
end;

destructor TAcceptSocket.Destroy;
begin
  FreeMem(FIOData.Data.buf);  // �ͷ��ڴ��
  inherited;
end;

procedure TAcceptSocket.NewSocket;
begin
  // �½� Socket
  FSocket := iocp_utils.CreateSocket;
end;

function TAcceptSocket.SetOption: Boolean;
begin
  // ���� FListenSocket �����Ե� FSocket
  Result := iocp_Winsock2.setsockopt(FSocket, SOL_SOCKET,
                 SO_UPDATE_ACCEPT_CONTEXT, PAnsiChar(@FListenSocket),
                 SizeOf(TSocket)) <> SOCKET_ERROR;
end;

{ TBaseSocket }

constructor TBaseSocket.Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec);
begin
  inherited Create(False);
  // FSocket �ɿͻ��˽���ʱ����
  //   ����TInIOCPServer.AcceptClient
  //       TIOCPSocketPool.CreateObjData
  FObjPool := AObjPool;
  FLinkNode := ALinkNode;
  FUseTransObj := True;  
end;

procedure TBaseSocket.BackgroundExecute;
begin
  // Empty
end;

function TBaseSocket.CheckDelayed(ATickCount: Cardinal): Boolean;
begin
  // ȡ������ʱ��Ĳ�
  if (ATickCount >= FTickCount) then
    Result := ATickCount - FTickCount <= 3000
  else
    Result := High(Cardinal) - ATickCount + FTickCount <= 3000;
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then  // TransmitFile û������
    Result := Result and (FTask.Exists = False);
  {$ENDIF}
end;

function TBaseSocket.CheckTimeOut(NowTickCount, TimeoutInteval: Cardinal): Boolean;
  function GetTickCountDiff: Boolean;
  begin
    if (NowTickCount >= FTickCount) then
      Result := NowTickCount - FTickCount >= TimeoutInteval
    else
      Result := High(Cardinal) - FTickCount + NowTickCount >= TimeoutInteval;
  end;
begin
  // ��ʱ���
  if (FTickCount = 0) then  // Ͷ�ż��Ͽ���=0
  begin
    Inc(FTickCount);
    Result := False;
  end else
    Result := GetTickCountDiff;
end;

procedure TBaseSocket.Clone(Source: TBaseSocket);
begin
  // ����任���� Source ���׽��ֵ���Դת�Ƶ��¶���
  // �� TIOCPSocketPool �������ã���ֹ�����Ϊ��ʱ

  // ת�� Source ���׽��֡���ַ
  IniSocket(Source.FServer, Source.FSocket, Source.FData);

  FPeerIP := Source.FPeerIP;
  FPeerPort := Source.FPeerPort;
  FPeerIPPort := Source.FPeerIPPort;

  // ��� Source ����Դֵ
  // Source.FServer ���䣬�ͷ�ʱҪ��飺TBaseSocket.Destroy
  Source.FData := nil;
  
  Source.FPeerIP := '';
  Source.FPeerPort := 0;
  Source.FPeerIPPort := '';

  Source.FConnected := False;
  Source.FSocket := INVALID_SOCKET;
   
  // δ�� FTask  
end;

procedure TBaseSocket.Close;
begin
  // �ر�
  ClearResources;  // ֻ�����Դ
  inherited;
end;

procedure TBaseSocket.CopyResources(AMaster: TBaseSocket);
begin
  FByteCount := 0;      // �յ��ֽ���
  FLinkSocket := AMaster;  // ��������
  FState := 0;  // ����æ
  
  AMaster.FBackground := True;  // ��̨ģʽ
  // ת�壺FPeerIP �����¼���ƣ����Ժ�̨ Socket û̫������
//  FPeerIP := AMaster.FPeerIP;
  FPeerIPPort := AMaster.FPeerIPPort;
  FPeerPort := AMaster.FPeerPort;
end;

destructor TBaseSocket.Destroy;
begin
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then
    FTask.Free;
  {$ENDIF}
  if TInIOCPServer(FServer).Active and Assigned(FRecvBuf) then
  begin
    BufferPool.Push(FRecvBuf^.Node);  // �����ڴ��
    FRecvBuf := Nil;
  end;
  inherited;
end;

procedure TBaseSocket.DoWork(AWorker: TBaseWorker; ASender: TBaseTaskSender);
begin
  // ��ʼ��
  // ����������� FWorker��FSender Ϊ Nil

  if Assigned(FLinkSocket) then  // ��̨״̬
  begin
    FBackground := True;  // ��ִ̨��
    FCompleted := True;   // �������
    FErrorCode := 0;      // ���쳣
    FWorker := AWorker;   // ִ����
    FSender := nil;       // ������
    BackgroundExecute;    // ��ִ̨��
  end else
  begin

    {$IFDEF TRANSMIT_FILE}
    if FUseTransObj then
    begin
      if (Assigned(FTask) = False) then
      begin
        FTask := TTransmitObject.Create(Self); // TransmitFile ����
        FTask.OnError := OnSendError;
      end;
      FTask.Socket := FSocket;
      FTaskExists := False; // ����
    end;
    {$ENDIF}
  
    FErrorCode := 0;      // ���쳣
    FByteCount := FRecvBuf^.Overlapped.InternalHigh;  // �յ��ֽ���
    FBackground := False;

    FWorker := AWorker;   // ִ����
    FSender := ASender;   // ������

    FSender.Owner := Self;
    FSender.Socket := FSocket;
    FSender.OnError := OnSendError;

    // ִ������
    ExecuteWork;
  end;
end;

{$IFDEF TRANSMIT_FILE}
procedure TBaseSocket.FreeTransmitRes;
begin
  // �����̵߳��ã�TransmitFile �������
  if FTask.SendDone then    // FState=2 -> �����������쳣
    if (InterlockedDecrement(FState) = 1) then  // FState=2 -> �����������쳣
      InterFreeRes // ������ʵ�֣���ʽ�ͷŷ�����Դ���ж��Ƿ����Ͷ�� WSARecv��
    else
      InterCloseSocket(Self);
end;
{$ENDIF}

function TBaseSocket.GetActive: Boolean;
begin
  // ����ǰȡ��ʼ��״̬�����չ����ݣ�
  Result := (iocp_api.InterlockedCompareExchange(Integer(FByteCount), 0, 0) > 0);
end;

function TBaseSocket.GetBufferPool: TIODataPool;
begin
  // ȡ�ڴ��
  Result := TInIOCPServer(FServer).IODataPool;
end;

function TBaseSocket.GetObjectState(const Group: string; AdminType: Boolean): Boolean;
begin
  Result := False;  // ����������
end;

function TBaseSocket.GetReference: Boolean;
begin
  // ����ʱ���ã�ҵ������ FRecvBuf^.RefCount��
  Result := InterlockedIncrement(FRefCount) = 1;
end;

function TBaseSocket.GetSocketState: Boolean;
begin
  // ȡ״̬, FState = 1 ˵������
  Result := iocp_api.InterlockedCompareExchange(FState, 1, 1) = 1;
end;

procedure TBaseSocket.InternalPush(AData: PPerIOData);
var
  ByteCount, Flags: Cardinal;
begin
  // ������Ϣ�������̵߳��ã�
  //  AData��TPushMessage.FPushBuf

  // ���ص��ṹ
  FillChar(AData^.Overlapped, SizeOf(TOverlapped), 0);

  FErrorCode := 0;
  FRefCount := 0;  // AData:Socket = 1:n
  FTickCount := GetTickCount;  // +

  ByteCount := 0;
  Flags := 0;

  if (InterlockedDecrement(FState) <> 0) then
    InterCloseSocket(Self)
  else
    if (iocp_Winsock2.WSASend(FSocket, @(AData^.Data), 1, ByteCount,
        Flags, LPWSAOVERLAPPED(@AData^.Overlapped), nil) = SOCKET_ERROR) then
    begin
      FErrorCode := WSAGetLastError;
      if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      begin
        SocketError(AData^.IOType);
        InterCloseSocket(Self);  // �ر�
      end else
        FErrorCode := 0;
    end;

end;

procedure TBaseSocket.InternalRecv;
var
  ByteCount, Flags: DWORD;
begin
  // �����������һ�����ݰ����պ��ύ���յ�����

  // ���ص��ṹ
  FillChar(FRecvBuf^.Overlapped, SizeOf(TOverlapped), 0);

  FRecvBuf^.Owner := Self;  // ����
  FRecvBuf^.IOType := ioReceive;  // iocp_server ���ж���
  FRecvBuf^.Data.len := IO_BUFFER_SIZE; // �ָ�

  ByteCount := 0;
  Flags := 0;

  // ����ʱ FState=1�������κ�ֵ��˵���������쳣��
  // FState-��FState <> 0 -> �쳣�ı���״̬���رգ�

  if (InterlockedDecrement(FState) <> 0) then
    InterCloseSocket(Self)
  else  // FRecvBuf^.Overlapped �� TPerIOData ͬ��ַ
    if (iocp_Winsock2.WSARecv(FSocket, @(FRecvBuf^.Data), 1, ByteCount,
        Flags, LPWSAOVERLAPPED(@FRecvBuf^.Overlapped), nil) = SOCKET_ERROR) then
    begin
      FErrorCode := WSAGetLastError;
      if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      begin
        SocketError(ioReceive);
        InterCloseSocket(Self);  // �ر�
      end else
        FErrorCode := 0;
    end;

end;

function TBaseSocket.Lock(PushMode: Boolean): Integer;
const
  SOCKET_STATE_IDLE  = 0;  // ����
  SOCKET_STATE_BUSY  = 1;  // ����
  SOCKET_STATE_TRANS = 2;  // TransmitFile ���� 
begin
  // ����ǰ����
  //  ״̬ FState = 0 -> 1, ���ϴ�������� -> �ɹ���
  //  �Ժ��� Socket �ڲ����κ��쳣�� FState+
  case iocp_api.InterlockedCompareExchange(FState, 1, 0) of  // ����ԭֵ

    SOCKET_STATE_IDLE: begin
      if PushMode then   // ����ģʽ
      begin
        if FCompleted then
          Result := SOCKET_LOCK_OK
        else
          Result := SOCKET_LOCK_FAIL;
      end else
      begin
        // ҵ���߳�ģʽ������TWorkThread.HandleIOData
        Result := SOCKET_LOCK_OK;     // ��������
      end;
      if (Result = SOCKET_LOCK_FAIL) then // ҵ��δ��ɣ�������
        if (InterlockedDecrement(FState) <> 0) then
          InterCloseSocket(Self);
    end;

    SOCKET_STATE_BUSY:
      Result := SOCKET_LOCK_FAIL;     // ����

    SOCKET_STATE_TRANS:
      if FUseTransObj then
        Result := SOCKET_LOCK_FAIL    // ����
      else
        Result := SOCKET_LOCK_CLOSE;  // �쳣

    else
      Result := SOCKET_LOCK_CLOSE;    // �ѹرջ������쳣
  end;
end;

procedure TBaseSocket.MarkIODataBuf(AData: PPerIOData);
begin
  // ��
end;

procedure TBaseSocket.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  inherited;
  FServer := AServer;// ����������ǰ��
  FData := AData;    // ��չ����

  // ��������ڴ�飨�ͷ�ʱ���գ�
  if (FRecvBuf = nil) then
    FRecvBuf := BufferPool.Pop^.Data; // �� FServer ��ֵ��

  FByteCount := 0;    // �������ݳ���
  FCompleted := True; // �ȴ�����
  FErrorCode := 0;    // ���쳣
  FState := 9;        // ��Ч״̬��Ͷ�� Recv ������ʽʹ��
  FTickCount := 0;    // 0����ֹ�����Ϊ��ʱ������TOptimizeThread
end;

procedure TBaseSocket.InterCloseSocket(Sender: TObject);
begin
  // �ڲ��رգ��ύ�� FServer �Ĺر��̴߳���
  InterlockedExchange(Integer(FByteCount), 0); // ������������
  InterlockedExchange(FState, 9);  // ��Ч״̬
  TInIOCPServer(FServer).CloseSocket(Self);  // �ùر��̣߳������ظ��رգ�
end;

{$IFDEF TRANSMIT_FILE}
procedure TBaseSocket.InterTransmit;
begin
  if FTask.Exists then
  begin
    FTaskExists := True;
    InterlockedIncrement(FState);  // FState+������ʱ=2
    FTask.TransmitFile;
  end;
end;
{$ENDIF}

procedure TBaseSocket.OnSendError(IOType: TIODataType; ErrorCode: Integer);
begin
  // �������쳣�Ļص�����
  //   ����TBaseSocket.DoWork��TBaseTaskObject.Send...
  FErrorCode := ErrorCode;
  InterlockedIncrement(FState);  // FState+
  SocketError(IOType);
end;

procedure TBaseSocket.PostRecv;
begin
  // Ͷ�Ž��ջ���
  //  ACompleted: �Ƿ�׼����ɣ�������������Ϣ
  //   ����TInIOCPServer.AcceptClient��THttpSocket.ExecuteWork
  FState := 1;  // �跱æ
  InternalRecv; // Ͷ��ʱ FState-
end;

procedure TBaseSocket.SocketError(IOType: TIODataType);
const
  PROCEDURE_NAMES: array[ioReceive..ioTimeOut] of string = (
                   'Post WSARecv->', 'TransmitFile->',
                   'Post WSASend->', 'InternalPush->',
                   'InternalPush->', 'InternalPush->');
begin
  // д�쳣��־
  if Assigned(FWorker) then  // �����ʹ���Ͷ�ţ�û�� FWorker
    iocp_log.WriteLog(PROCEDURE_NAMES[IOType] + PeerIPPort +
                      ',Error:' + IntToStr(FErrorCode) +
                      ',BusiThread:' + IntToStr(FWorker.ThreadIdx));
end;

procedure TBaseSocket.TryClose;
begin
  // ���Թر�
  // FState+, ԭֵ: 0,2,3... <> 1 -> �ر�
  if (InterlockedIncrement(FState) in [1, 3]) then // <> 2
    InterCloseSocket(Self)
  else
  if (FState = 8) then
    InterCloseSocket(Self);
end;

{ TStreamSocket }

procedure TStreamSocket.ClearResources;
begin
  FByteCount := 0;  // ��ֹ����ʱ��������Ϣ
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then
    FTask.FreeResources(True);
  {$ENDIF}
end;

procedure TStreamSocket.ExecuteWork;
begin
  try
    FTickCount := GetTickCount;
    FWorker.StreamExecute(Self);  // �°��ù�����ִ��
  finally
    {$IFDEF TRANSMIT_FILE}
    if (FTaskExists = False) then {$ENDIF}
      InternalRecv;  // ��������
  end;
end;

function TStreamSocket.GetObjectState(const Group: string; AdminType: Boolean): Boolean;
begin
  // ȡ״̬���Ƿ���Խ�������
  // 1. �Ѿ����չ�����; 2. �й���ԱȨ��
  Result := (FByteCount > 0) and ((AdminType = False) or (FRole >= crAdmin));
end;

procedure TStreamSocket.IniSocket(AServer: TObject; ASocket: TSocket;
  AData: Pointer);
begin
  inherited;
  FClientId := '';
  FRole := crUnknown;
end;

procedure TStreamSocket.PostEvent(IOKind: TIODataType);
begin
  // Empty
end;

{$IFDEF TRANSMIT_FILE}
procedure TStreamSocket.InterFreeRes;
begin
  // �ͷ� TransmitFile �ķ�����Դ������Ͷ�Ž��գ�
  try
    ClearResources;
  finally
    InternalRecv;
  end;
end;
{$ENDIF}

procedure TStreamSocket.SendData(const Data: PAnsiChar; Size: Cardinal);
var
  Buf: PAnsiChar;
begin
  // �����ڴ�����ݣ����� Data��
  if Assigned(Data) and (Size > 0) then
  begin
    GetMem(Buf, Size);
    System.Move(Data^, Buf^, Size);
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Buf, Size);
    InterTransmit;
    {$ELSE}
    FSender.Send(Buf, Size);
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendData(const Msg: String);
begin
  // �����ı�
  if (Msg <> '') then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Msg);
    InterTransmit;
    {$ELSE}
    FSender.Send(Msg);
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendData(Handle: THandle);
begin
  // �����ļ� handle���Զ��رգ�
  if (Handle > 0) and (Handle <> INVALID_HANDLE_VALUE) then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Handle, GetFileSize64(Handle));
    InterTransmit;
    {$ELSE}
    FSender.Send(Handle, GetFileSize64(Handle));
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendData(Stream: TStream);
begin
  // ���������ݣ��Զ��ͷţ�
  if Assigned(Stream) then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTask(Stream, Stream.Size);
    InterTransmit;
    {$ELSE}
    FSender.Send(Stream, Stream.Size, True);
    {$ENDIF}
  end;
end;

procedure TStreamSocket.SendDataVar(Data: Variant);
begin
  // ���Ϳɱ���������
  if (VarIsNull(Data) = False) then
  begin
    {$IFDEF TRANSMIT_FILE}
    FTask.SetTaskVar(Data);
    InterTransmit;
    {$ELSE}
    FSender.SendVar(Data);
    {$ENDIF}
  end;
end;

{ TReceiveParams }

constructor TReceiveParams.Create(AOwner: TIOCPSocket);
begin
  inherited Create;
  FSocket := AOwner;
end;

procedure TReceiveParams.CreateAttachment(const ALocalPath: string);
begin
  // ���ļ��������ո���
  inherited;
  if Error then  // ���ִ���
  begin
    FSocket.FResult.ActResult := arFail;
    FSocket.FResult.Msg := GetSysErrorMessage();
  end else
  begin
    FSocket.FAction := atAfterReceive; // ����ʱִ���¼�
    FSocket.FResult.FActResult := arAccept;  // �����ϴ�
    FSocket.FReceiver.Completed := False;  // �������ո���

    // ���������ض�����ļ���Ϣ
    if (FAction in FILE_CHUNK_ACTIONS) then
    begin
      FSocket.FResult.FOffset := FOffset;  // ����Ҫ���½��գ�FOffset ���޸�
      FSocket.FResult.SetFileName(ExtractFileName(Attachment.FileName));  // �ļ�ͬ��ʱ���ı�
      FSocket.FResult.SetDirectory(EncryptString(ExtractFilePath(Attachment.FileName))); // ���ܷ�����ļ�
      FSocket.FResult.SetAttachFileName(GetAttachFileName);  // �ͻ��˵��ļ�ȫ��
    end;

    // ���� URL��·��Ӧ�ÿ��Թ�����
    if Assigned(TInIOCPServer(FSocket.FServer).HttpDataProvider) then
      SetURL(ChangeSlash(Attachment.FileName));
  end;
end;

function TReceiveParams.GetLogName: string;
begin
  // ȡ��¼ʱ������
  Result := FSocket.GetLogName;
end;

procedure TReceiveParams.SetUniqueMsgId;
begin
  // ����������Ϣ�� MsgId
  //   ������Ϣ���÷�������Ψһ MsgId
  //   �޸Ļ���� MsgId
  //   ��Ҫ�� FResult.FMsgId������ͻ��˰ѷ��ͷ�������������Ϣ����
  FMsgHead^.MsgId := TSystemGlobalLock.GetMsgId;
end;

{ TReturnResult }

constructor TReturnResult.Create(AOwner: TIOCPSocket; AInitialize: Boolean);
begin
  inherited Create(nil);  // Owner �� nil
  FSocket := AOwner;
  PeerIPPort := FSocket.PeerIPPort;
  if AInitialize then
  begin
    FOwner := AOwner.Params.FOwner; // ��Ӧ�ͻ������
    SetHeadMsg(AOwner.Params.FMsgHead, True);
  end;
end;

procedure TReturnResult.LoadFromFile(const AFileName: String; ServerMode: Boolean);
begin
  inherited;  // ���̴��ļ����ȴ�����
  if Error then
  begin
    FActResult := arFail;
    FOffset := 0;
    FOffsetEnd := 0;
  end else
  begin
    FActResult := arOK;
    if (FAction = atFileDownChunk) then  // �ϵ�����
    begin
      FOffset := FSocket.FParams.FOffset;  // ����λ��
      AdjustTransmitRange(FSocket.FParams.FOffsetEnd);  // ��������, =�ͻ��� FMaxChunkSize
      SetDirectory(EncryptString(ExtractFilePath(AFileName)));  // ���ؼ��ܵ�·��
    end;
  end;
end;

procedure TReturnResult.LoadFromCDSVariant(
  const ACDSAry: array of TClientDataSet;
  const ATableNames: array of String);
begin
  inherited; // ֱ�ӵ���
end;

procedure TReturnResult.LoadFromVariant(
  const AProviders: array of TDataSetProvider;
  const ATableNames: array of String);
begin
  inherited; // ֱ�ӵ���
end;

{ TIOCPSocket }

procedure TIOCPSocket.BackgroundExecute;
begin
  // ֱ�ӽ���Ӧ�ò�
  // ��̨�߳�ֻ��ִ������������Ϣ���޷���������
  try
    FTickCount := GetTickCount;
    FWorker.Execute(Self);
  except
    {$IFDEF DEBUG_MODE}
    on E: Exception do
      iocp_log.WriteLog('TIOCPSocket.BackgroundExecute->' + E.Message);
    {$ENDIF}
  end;
end;

function TIOCPSocket.CheckMsgHead(InBuf: PAnsiChar): Boolean;
  function CheckLogState: TActionResult;
  begin
    // ����¼״̬
    if (FParams.Action = atUserLogin) then
      Result := arOK       // ͨ��
    else
    if (FParams.SessionId = 0) then
      Result := arErrUser  // �ͻ���ȱ�� SessionId, ���Ƿ��û�
    else
    if (FParams.SessionId = FSessionId) then
      Result := arOK       // ͨ��
    else
    if SessionValid(FParams.SessionId) then
      Result := arOK       // ͨ��
    else
      Result := arOutDate; // ƾ֤����
  end;
begin
  // ����һ�������ݰ�����Ч�ԡ��û���¼״̬�������� http Э�飩
  if (FByteCount < IOCP_SOCKET_SIZE) or  // ����̫��
     (MatchSocketType(InBuf, IOCP_SOCKET_FLAG) = False) then // C/S ��־����
  begin
    // �رշ���
    InterCloseSocket(Self);
    Result := False;
  end else
  begin
    Result := True;
    FAction := atUnknown;  // �ڲ��¼������ڸ������䣩
    FResult.FSender := FSender;  // ������

    // �ȸ���Э��ͷ
    FParams.FMsgHead := PMsgHead(InBuf + IOCP_SOCKET_FLEN); // ����ʱ��
    FParams.SetHeadMsg(FParams.FMsgHead);
    FResult.SetHeadMsg(FParams.FMsgHead, True);

    if (FParams.Action = atUnknown) then  // 1. ��Ӧ����
      FReceiver.Completed := True
    else begin
      // 2. ����¼״̬
      if Assigned(TInIOCPServer(FServer).ClientManager) then
        FResult.ActResult := CheckLogState
      else begin
        // ���¼��Ҳ���� SessionId
        FResult.ActResult := arOK;
        FSessionId := CreateSession;
        FResult.FSessionId := FSessionId;
      end;
      if (FResult.ActResult in [arOffline, arOutDate]) then
        FReceiver.Completed := True  // 3. �������
      else // 4. ׼������
        FReceiver.Prepare(InBuf, FByteCount);
    end;
  end;
end;

procedure TIOCPSocket.ClearResources;
begin
  // �����Դ
  if Assigned(FResult) then
    FReceiver.Clear;
  if Assigned(FParams) then
    FParams.Clear;
  if Assigned(FResult) then
    FResult.Clear;
  SetLogoutState;     // �ǳ�
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then  
    FTask.FreeResources(False);  // ���� FResult.Clear �ͷ�
  {$ENDIF}
end;

procedure TIOCPSocket.CopyResources(AMaster: TBaseSocket);
begin
  // ���Ʋ�����������ݣ�׼��Ͷ���̨�߳�
  inherited;
  CreateResources;  // �½���Դ
  FParams.Initialize(TIOCPSocket(AMaster).FParams);    // �����ֶ�
  FResult.Initialize(TIOCPSocket(AMaster).FResult);    // �����ֶ�
  FPeerIP := TIOCPSocket(AMaster).LoginName;           // ת�壺����ʱҪ��
end;

procedure TIOCPSocket.CreateResources;
begin
  // ����Դ�����ա��������/���������ݽ�����
  if (FReceiver = nil) then
  begin
    FParams := TReceiveParams.Create(Self);  // ��ǰ
    FResult := TReturnResult.Create(Self, False);
    FReceiver := TServerReceiver.Create(FParams); // �ں�
  end else
  if FReceiver.Completed then
  begin
    FParams.Clear;
    FResult.Clear;
  end;
end;

function TIOCPSocket.CreateSession: Cardinal;
var
  NowTime: TDateTime;
  Certify: TCertifyNumber;
  LHour, LMinute, LSecond, LMilliSecond: Word;
begin
  // ����һ����¼ƾ֤����Ч��Ϊ SESSION_TIMEOUT ����
  //   �ṹ��(�������� + ��Ч����) xor ��
  NowTime := Now();

  DecodeTime(NowTime, LHour, LMinute, LSecond, LMilliSecond);

  Certify.DayCount := Trunc(NowTime - 43000);  // ��������
  Certify.Timeout := LHour * 60 + LMinute + SESSION_TIMEOUT;

  if (Certify.Timeout >= 1440) then  // ����һ��ķ�����
  begin
    Inc(Certify.DayCount);  // ��һ��
    Dec(Certify.Timeout, 1440);
  end;

  Result := Certify.Session xor Cardinal($AB12);
end;

destructor TIOCPSocket.Destroy;
begin
  // �ͷ���Դ
  if Assigned(FReceiver) then
  begin
    FReceiver.Free;
    FReceiver := Nil;
  end;
  if Assigned(FParams) then
  begin
    FParams.Free;
    FParams := Nil;
  end;
  if Assigned(FResult) then
  begin
    FResult.Free;
    FResult := Nil;
  end;
  inherited;
end;

procedure TIOCPSocket.ExecuteWork;
const
  IO_FIRST_PACKET = True;  // �����ݰ�
  IO_SUBSEQUENCE  = False; // �������ݰ�
begin
  // �������ݿ� FRecvBuf ������

  {$IFNDEF DELPHI_7}
  {$REGION '+ ��������'}
  {$ENDIF}

  // 1 ����Դ
  CreateResources;

  // 1.1 ��������
  FTickCount := GetTickCount;

  case FReceiver.Completed of
    IO_FIRST_PACKET:  // 1.2 �����ݰ��������Ч�� �� �û���¼״̬
      if (CheckMsgHead(FRecvBuf^.Data.buf) = False) then
        Exit;
    IO_SUBSEQUENCE:   // 1.3 ���պ������ݰ�
      FReceiver.Receive(FRecvBuf^.Data.buf, FByteCount);
  end;

  // 1.4 ����򸽼�������Ͼ�����Ӧ�ò�
  FCompleted := FReceiver.Completed and (FReceiver.Cancel = False);

  {$IFNDEF DELPHI_7}
  {$ENDREGION}

  {$REGION '+ ����Ӧ�ò�'}
  {$ENDIF}

  // 2. ����Ӧ�ò�
  try
    if FCompleted then   // ������ϡ��ļ�Э��
      if FReceiver.CheckPassed then // У��ɹ�
        HandleDataPack  // 2.1 ����ҵ��
      else
        ReturnMessage(arErrHash);  // 2.2 У����󣬷�����
  finally
    // 2.3 ����Ͷ�� WSARecv���������ݣ�
    {$IFDEF TRANSMIT_FILE}  // ���ܷ����ɹ�����������ǰ��
    if (FTaskExists = False) then {$ENDIF}
      InternalRecv;
  end;

  {$IFNDEF DELPHI_7}
  {$ENDREGION}
  {$ENDIF}

end;

function TIOCPSocket.GetObjectState(const Group: string; AdminType: Boolean): Boolean;
begin
  // ȡ״̬���Ƿ���Խ�������
  // ͬ���顢�Ѿ����չ����ݣ��й���ԱȨ��
  Result := (FByteCount > 0) and (GetUserGroup = Group) and
           ((AdminType = False) or (GetRole >= crAdmin));
end;

function TIOCPSocket.GetLogName: string;
begin
  if Assigned(FEnvir) then
    Result := FEnvir^.BaseInf.Name
  else
    Result := '';
end;

function TIOCPSocket.GetRole: TClientRole;
begin
  if Assigned(FEnvir) then
    Result := Envir^.BaseInf.Role
  else
    Result := crUnknown;
end;

function TIOCPSocket.GetUserGroup: string;
begin
  if Assigned(FEnvir) then
    Result := Envir^.BaseInf.Group
  else
    Result := '<NULL_GROUP>';  // �������ƣ���Ч����
end;

procedure TIOCPSocket.HandleDataPack;
begin
  // ִ�пͻ�������

  // 1. ��Ӧ -> ֱ�ӷ���Э��ͷ
  if (FParams.Action = atUnknown) then
    ReturnHead(arOK)
  else

  // 2. δ��¼������˲��رգ����Ի����� -> ����Э��ͷ
  if (FResult.ActResult in [arErrUser, arOutDate]) then
    ReturnMessage(FResult.ActResult)
  else

  // 3. ���������쳣
  if FParams.Error then
    ReturnMessage(arErrAnalyse)
  else begin

    // 4. ����Ӧ�ò�ִ������
    try
      FWorker.Execute(Self);
    except
      on E: Exception do  // 4.1 �쳣 -> ����
      begin
        ReturnMessage(arErrWork, E.Message);
        Exit;  // 4.2 ����
      end;
    end;

    try
      // 5. ����+����������� -> ���
      FReceiver.OwnerClear;

      // 6. �Ƿ��û����������Ҫ�ر�
      if (FResult.ActResult = arErrUser) then
        InterlockedIncrement(FState);  // FState+

      // 7. ���ͽ����
      ReturnResult;

      {$IFNDEF TRANSMIT_FILE}
      // 7.1 ��������¼�������δ�رգ�
      if Assigned(FResult.Attachment) then
      begin
        FAction := atAfterSend;
        FWorker.Execute(Self);
      end;
      {$ENDIF}
    finally
      {$IFNDEF TRANSMIT_FILE}
      if (FReceiver.Complete = False) then  // ����δ�������
        FAction := atAfterReceive;  // �ָ�
      if Assigned(FResult.Attachment) then
        FResult.Clear;
      {$ENDIF}
    end;

  end;

end;

procedure TIOCPSocket.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  inherited;
  FSessionId := 0; // ��ʼƾ֤
end;

procedure TIOCPSocket.InterCloseSocket(Sender: TObject);
begin
  // �����û����������ƣ����� OnDisconnect ʹ��
  if Assigned(FParams) then
  begin
    if (FParams.FAction <> atUserLogout) then
      FResult.FAction := atDisconnect;
    if Assigned(FEnvir) then
      FResult.UserName := FEnvir^.BaseInf.Name;
  end;
  inherited;
end;

{$IFDEF TRANSMIT_FILE}
procedure TIOCPSocket.InterFreeRes;
begin
  // �ͷ� TransmitFile �ķ�����Դ
  try
    try
      if Assigned(FResult.Attachment) then  // �����������
      begin
        FAction := atAfterSend;
        FWorker.Execute(Self);
      end;
    finally
      if (FReceiver.Completed = False) then  // ����δ�������
        FAction := atAfterReceive;  // �ָ�
      FResult.NilStreams(True);     // �ͷŷ�����Դ
      FTask.FreeResources(False);   // False -> �������ͷ�
    end;
  finally  // ����Ͷ�� Recv
    InternalRecv;
  end;
end;
{$ENDIF}

procedure TIOCPSocket.PostEvent(IOKind: TIODataType);
var
  Msg: TPushMessage;
begin
  // Ͷ���¼�����ɾ�����ܾ����񡢳�ʱ    
  // ���졢����һ��Э��ͷ��Ϣ�����Լ���
  //   C/S ���� IOKind ֻ�� ioDelete��ioRefuse��ioTimeOut��
  //  ������Ϣ�ã�Push(ATarget: TBaseSocket; UseUniqueMsgId: Boolean);
  //  ͬʱ���� HTTP ����ʱ������ THttpSocket ���� arRefuse��δת����Դ��

  // 3 ���ڻ����ȡ����ʱ
  if (IOKind = ioTimeOut) and CheckDelayed(GetTickCount) then
    Exit;

  Msg := TPushMessage.Create(Self, IOKind, IOCP_SOCKET_SIZE);

  case IOKind of
    ioDelete:
      THeadMessage.CreateHead(Msg.PushBuf^.Data.buf, arDeleted);
    ioRefuse: 
      THeadMessage.CreateHead(Msg.PushBuf^.Data.buf, arRefuse);
    ioTimeOut:
      THeadMessage.CreateHead(Msg.PushBuf^.Data.buf, arTimeOut);
  end;

  // ���������б����������߳�
  TInIOCPServer(FServer).PushManager.AddWork(Msg);
end;

procedure TIOCPSocket.SetLogoutState;
begin
  // ���ùرա��ǳ�״̬
  FByteCount := 0;  // ��ֹ����ʱ��������Ϣ
  FBackground := False;
  FLinkSocket := nil;
  FSessionId := 0;
  if Assigned(FEnvir) then
    if FEnvir^.ReuseSession then  // �����ӶϿ������� FData ��Ҫ��Ϣ
    begin
      FEnvir^.BaseInf.Socket := 0;
      FEnvir^.BaseInf.LogoutTime := Now();
    end else
      try  // �ͷŵ�¼��Ϣ
        TInIOCPServer(FServer).ClientManager.RemoveClient(FEnvir^.BaseInf.Name);
      finally
        FEnvir := Nil;
      end;
end;

procedure TIOCPSocket.ReturnHead(ActResult: TActionResult);
begin
  // ����Э��ͷ���ͻ��ˣ���Ӧ��������Ϣ��
  //   ��ʽ��IOCP_HEAD_FLAG + TMsgHead

  // ����Э��ͷ��Ϣ
  FResult.FDataSize := 0;
  FResult.FAttachSize := 0;
  FResult.FActResult := ActResult;

  if (FResult.FAction = atUnknown) then  // ��Ӧ
    FResult.FVarCount := FObjPool.UsedCount // ���ؿͻ�����
  else
    FResult.FVarCount := 0;

  // ֱ��д�� FSender �ķ��ͻ���
  FResult.LoadHead(FSender.Data);

  // ����
  FSender.SendBuffers;
end;

procedure TIOCPSocket.ReturnMessage(ActResult: TActionResult; const ErrMsg: String);
begin
  // ����Э��ͷ���ͻ���

  FParams.Clear;
  FResult.Clear;
  
  if (ErrMsg <> '') then
  begin
    FResult.Msg := ErrMsg;
    FResult.ActResult := ActResult;
    ReturnResult;
  end else
    ReturnHead(ActResult);

  case ActResult of
    arOffline:
      iocp_log.WriteLog(Self.ClassName + '->�ͻ���δ��¼.');
    arOutDate:
      iocp_log.WriteLog(Self.ClassName + '->ƾ֤/��֤����.');
    arErrAnalyse:
      iocp_log.WriteLog(Self.ClassName + '->���������쳣.');
    arErrHash:
      iocp_log.WriteLog(Self.ClassName + '->У���쳣��');
    arErrWork:
      iocp_log.WriteLog(Self.ClassName + '->ִ���쳣, ' + ErrMsg);
  end;

end;

procedure TIOCPSocket.ReturnResult;
  procedure SendMsgHeader;
  begin
    // ����Э��ͷ��������
    FResult.LoadHead(FSender.Data);
    FSender.SendBuffers;
  end;
  procedure SendMsgEntity;
  begin
    // ��������������
    {$IFDEF TRANSMIT_FILE}
    // ��������������
    FTask.SetTask(FResult.FMain, FResult.FDataSize);
    {$ELSE}
    FSender.Send(FResult.FMain, FResult.FDataSize, False);  // ���ر���Դ
    {$ENDIF}
  end;
  procedure SendMsgAttachment;
  begin
    // ���͸�������
    {$IFDEF TRANSMIT_FILE}
    // ���ø���������
    if (FResult.FAction = atFileDownChunk) then
      FTask.SetTask(FResult.FAttachment, FResult.FAttachSize,
                    FResult.FOffset, FResult.FOffsetEnd)
    else
      FTask.SetTask(FResult.FAttachment, FResult.FAttachSize);
    {$ELSE}
    if (FResult.FAction = atFileDownChunk) then  // ���ر���Դ
      FSender.Send(FResult.FAttachment, FResult.FAttachSize,
                   FResult.FOffset, FResult.FOffsetEnd, False)
    else
      FSender.Send(FResult.FAttachment, FResult.FAttachSize, False);
    {$ENDIF}
  end;
begin
  // ���ͽ�����ͻ��ˣ���������ֱ�ӷ���
  //  �������� TIOCPDocument����Ҫ�ã������ͷ�
  //   ����TIOCPSocket.HandleDataPack; TClientParams.InternalSend

  // FSender.Socket��Owner �Ѿ�����

  try
    // 1. ׼��������
    FResult.CreateStreams;

    if (FResult.Error = False) then
    begin
      // 2. ��Э��ͷ
      SendMsgHeader;

      // 3. �������ݣ��ڴ�����
      if (FResult.FDataSize > 0) then
        SendMsgEntity;

      // 4. ���͸�������
      if (FResult.FAttachSize > 0) then
        SendMsgAttachment;
    end;
  finally
    {$IFDEF TRANSMIT_FILE}
    InterTransmit;
    {$ELSE}
    FResult.NilStreams(False);  // 5. ��գ��ݲ��ͷŸ�����
    {$ENDIF}
  end;

end;

procedure TIOCPSocket.SocketError(IOType: TIODataType);
begin                             
  // �����շ��쳣
  if (IOType in [ioDelete, ioPush, ioRefuse]) then  // ����
    FResult.ActResult := arErrPush;
  inherited;
end;

procedure TIOCPSocket.SetLogState(AEnvir: PEnvironmentVar);
begin
  // ���õ�¼/�ǳ���Ϣ
  if (AEnvir = nil) then  // �ǳ�
  begin
    SetLogoutState;
    FResult.FSessionId := FSessionId;
    FResult.ActResult := arLogout;  // ���� arOffline
    if Assigned(FEnvir) then  // �������� Socket
      FEnvir := nil;
  end else
  begin
    FSessionId := CreateSession;  // �ؽ��Ի���
    FResult.FSessionId := FSessionId;
    FResult.ActResult := arOK;
    FEnvir := AEnvir;
  end;
end;

function TIOCPSocket.SessionValid(ASession: Cardinal): Boolean;
var
  NowTime: TDateTime;
  Certify: TCertifyNumber;
  LHour, LMinute, LSecond, LMilliSecond: Word;  
begin
  // ���ƾ֤�Ƿ���ȷ��û��ʱ
  //   �ṹ��(�������� + ��Ч����) xor ��
  NowTime := Now();

  DecodeTime(NowTime, LHour, LMinute, LSecond, LMilliSecond);

  LMinute := LHour * 60 + LMinute;  // ��ʱ���
  LSecond :=  Trunc(NowTime - 43000);  // ��ʱ���
  Certify.Session := ASession xor Cardinal($AB12);

  Result := (Certify.DayCount = LSecond) and (Certify.Timeout > LMinute) or
            (Certify.DayCount = LSecond + 1) and (Certify.Timeout > (1440 - LMinute));

  if Result then
    FSessionId := Certify.Session;
end;

{ THttpSocket }

procedure THttpSocket.ClearResources;
begin
  // �����Դ
  CloseStream;
  if Assigned(FRequest) then
    FRequest.Clear;
  if Assigned(FResponse) then
    FResponse.Clear;
  {$IFDEF TRANSMIT_FILE}
  if Assigned(FTask) then
    FTask.FreeResources(False);  // ���� FResult.Clear �ͷ�
  {$ENDIF}    
end;

procedure THttpSocket.CloseStream;
begin
  if Assigned(FStream) then
  begin
    FStream.Free;
    FStream := Nil;
  end;
end;

procedure THttpSocket.CreateStream(const FileName: String);
begin
  // ���ļ���
  FStream := TFileStream.Create(FileName, fmCreate or fmOpenWrite);
end;

procedure THttpSocket.DecodeHttpRequest;
begin
  // ����������루�����ݰ���
  //   ��ҵ���߳̽� FRequest��FResponse���ӿ�����ٶ�
  if (FRequest = nil) then
    FRequest := THttpRequest.Create(TInIOCPServer(FServer).HttpDataProvider, Self); // http ����
  if (FResponse = nil) then
    FResponse := THttpResponse.Create(TInIOCPServer(FServer).HttpDataProvider, Self); // http Ӧ��
  // ����ʱ�䡢HTTP �������
  FTickCount := GetTickCount;
  TRequestObject(FRequest).Decode(FSender, FResponse, FRecvBuf);
end;

destructor THttpSocket.Destroy;
begin
  CloseStream;
  if Assigned(FRequest) then
  begin
    FRequest.Free;
    FRequest := Nil;
  end;
  if Assigned(FResponse) then
  begin
    FResponse.Free;
    FResponse := Nil;
  end;
  inherited;
end;

procedure THttpSocket.ExecuteWork;
begin
  // ִ�� Http ����
  try
    // 1. ʹ�� C/S Э��ʱ��Ҫת��Ϊ TIOCPSocket
    if (FTickCount = 0) and (FByteCount = IOCP_SOCKET_FLEN) and
      MatchSocketType(FRecvBuf^.Data.Buf, IOCP_SOCKET_FLAG) then
    begin
      UpgradeSocket(TInIOCPServer(FServer).IOCPSocketPool);
      Exit;  // ����
    end;

    // 2. �Ƿ��ṩ HTTP ����
    if (Assigned(TInIOCPServer(FServer).HttpDataProvider) = False) then
    begin
      InterCloseSocket(Self);
      Exit;
    end;

    // 2. �������
    DecodeHttpRequest;

    // 3. ������� WebSocket
    if (FRequest.UpgradeState > 0) then
    begin
      if FRequest.Accepted then  // ����Ϊ WebSocket�����ܷ��� THttpSocket ��
      begin
        TResponseObject(FResponse).Upgrade;
        UpgradeSocket(TInIOCPServer(FServer).WebSocketPool);
      end else  // �������������ر�
        InterCloseSocket(Self);
      Exit;     // ����
    end;

    // 4. ִ��ҵ��
    FCompleted := FRequest.Completed;   // �Ƿ�������
    FResponse.StatusCode := FRequest.StatusCode;

    if FCompleted and FRequest.Accepted and (FRequest.StatusCode < 400) then
      FWorker.HttpExecute(Self);

    // 5. ����Ƿ�Ҫ��������
    if not FRequest.Accepted or FRequest.Attacked then // ������
      FKeepAlive := False
    else
      if FCompleted or (FResponse.StatusCode >= 400) then  // ������ϻ��쳣
      begin
        // �Ƿ񱣴�����
        FKeepAlive := FResponse.KeepAlive;

        // 6. �������ݸ��ͻ���
        TResponseObject(FResponse).SendWork;

        if {$IFNDEF TRANSMIT_FILE} FKeepAlive {$ELSE}
           (FTaskExists = False) {$ENDIF} then // 7. ����Դ��׼���´�����
          ClearResources;
      end else
        FKeepAlive := True;   // δ��ɣ������ܹر�

    // 8. ����Ͷ�Ż�ر�
    if FKeepAlive and (FErrorCode = 0) then  // ����Ͷ��
    begin
      {$IFDEF TRANSMIT_FILE}
      if (FTaskExists = False) then {$ENDIF}
        InternalRecv;
    end else
      InterCloseSocket(Self);  // �ر�ʱ����Դ
                 
  except
    InterCloseSocket(Self);  // �쳣�ر�
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('THttpSocket.ExecuteHttpWork->' + GetSysErrorMessage);
    {$ENDIF}
  end;

end;

function THttpSocket.GetSessionId: AnsiString;
begin
  if Assigned(FRequest) then
    Result := FRequest.SessionId;
end;

{$IFDEF TRANSMIT_FILE}
procedure THttpSocket.InterFreeRes;
begin
  // ������ϣ��ͷ� TransmitFile �ķ�����Դ
  try
    ClearResources;
  finally
    if FKeepAlive and (FErrorCode = 0) then  // ����Ͷ��
      InternalRecv
    else
      InterCloseSocket(Self);
  end;
end;
{$ENDIF}

procedure THttpSocket.PostEvent(IOKind: TIODataType);
const
  REQUEST_NOT_ACCEPTABLE = HTTP_VER + ' 406 Not Acceptable';
        REQUEST_TIME_OUT = HTTP_VER + ' 408 Request Time-out';
var
  Msg: TPushMessage;
  ResponseMsg: AnsiString;
begin
  // ���졢����һ����Ϣͷ�����Լ���
  //   HTTP ����ֻ�� arRefuse��arTimeOut

  // TransmitFile ������� 3 ���ڻ����ȡ����ʱ
  if (IOKind = ioTimeOut) and CheckDelayed(GetTickCount) then
    Exit;

  if (IOKind = ioRefuse) then
    ResponseMsg := REQUEST_NOT_ACCEPTABLE + STR_CRLF +
                    'Server: ' + HTTP_SERVER_NAME + STR_CRLF +
                   'Date: ' + GetHttpGMTDateTime + STR_CRLF +
                   'Content-Length: 0' + STR_CRLF +
                   'Connection: Close' + STR_CRLF2
  else
    ResponseMsg := REQUEST_TIME_OUT + STR_CRLF +
                   'Server: ' + HTTP_SERVER_NAME + STR_CRLF +
                   'Date: ' + GetHttpGMTDateTime + STR_CRLF +
                   'Content-Length: 0' + STR_CRLF +
                   'Connection: Close' + STR_CRLF2;

  Msg := TPushMessage.Create(Self, IOKind, Length(ResponseMsg));

  System.Move(ResponseMsg[1], Msg.PushBuf^.Data.buf^, Msg.PushBuf^.Data.len);

  // ���������б������߳�
  TInIOCPServer(FServer).PushManager.AddWork(Msg);

end;

procedure THttpSocket.SocketError(IOType: TIODataType);
begin
  // �����շ��쳣
  if Assigned(FResponse) then      // ����ʱ = Nil
    FResponse.StatusCode := 500;   // 500: Internal Server Error
  inherited;
end;

procedure THttpSocket.UpgradeSocket(SocketPool: TIOCPSocketPool);
var
  oSocket: TBaseSocket;
begin
  // �� THttpSocket ת��Ϊ TIOCPSocket �� TWebSocket
  try
    oSocket := TBaseSocket(SocketPool.Clone(Self));  // δ�� FTask��
    oSocket.PostRecv;  // Ͷ��
  finally
    InterCloseSocket(Self);  // �ر�����
  end;
end;

procedure THttpSocket.WriteStream(Data: PAnsiChar; DataLength: Integer);
begin
  // �������ݵ��ļ���
  if Assigned(FStream) then
    FStream.Write(Data^, DataLength);
end;

{ TReceiveJSON }

constructor TReceiveJSON.Create(AOwner: TWebSocket);
begin
  inherited Create(AOwner);
  FSocket := AOwner;
end;

{ TResultJSON }

constructor TResultJSON.Create(AOwner: TWebSocket);
begin
  inherited Create(AOwner);
  FSocket := AOwner;
end;

{ TWebSocket }

procedure TWebSocket.BackgroundExecute;
begin
  // ��ִ̨��
  try
    FTickCount := GetTickCount;
    FWorker.WebSocketExecute(Self);
  except
    {$IFDEF DEBUG_MODE}
    on E: Exception do
      iocp_log.WriteLog('TWebSocket.BackgroundExecute->' + E.Message);
    {$ENDIF}
  end;
end;

procedure TWebSocket.ClearOwnerMark;
var
  p: PAnsiChar;
begin
  // ������롢������=0
  if Assigned(FInData) then  // FBackground = False
  begin
    FReceiver.ClearMask(FInData, @FRecvBuf^.Overlapped);
    if (FMsgType = mtJSON) then  // ��� Owner,  ��Ϊ 0����ʾ����ˣ�
    begin
      p := FInData;
      Inc(p, Length(INIOCP_JSON_FLAG));
      if SearchInBuffer(p, FRecvBuf^.Overlapped.InternalHigh, '"__MSG_OWNER":') then // ���ִ�Сд
        while (p^ <> AnsiChar(',')) do
        begin
          p^ := AnsiChar('0');
          Inc(p);
        end;
    end;
  end;
end;

procedure TWebSocket.ClearResources;
begin
  FByteCount := 0;  // ��ֹ����ʱ��������Ϣ
  FUserGroup := '';
  FUserName := '';
  FRole := crUnknown;
  FJSON.Clear;
  FResult.Clear;
  FReceiver.Clear;
end;

procedure TWebSocket.CopyResources(AMaster: TBaseSocket);
var
  Master: TWebSocket;
begin
  // ���Ʋ�����������ݣ�׼��Ͷ���̨�߳�
  inherited;
  Master := TWebSocket(AMaster);

  FMsgType := Master.FMsgType;
  FMsgSize := Master.FMsgSize;
  FOpCode := Master.FOpCode;
  FRole := Master.FRole;
  FPeerIP := Master.UserName;  // ����ʱҪ�ã�ת��

  FJSON.Initialize(Master.FJSON);    // �����ֶ�
  FResult.Initialize(Master.FResult);    // �����ֶ�
end;

constructor TWebSocket.Create(AObjPool: TIOCPSocketPool; ALinkNode: PLinkRec);
begin
  inherited;
  FUserGroup := '<NULL_GROUP>';  // ��Ч����
  FUseTransObj := False;  // ���� TransmitFile
  FJSON := TReceiveJSON.Create(Self);
  FResult := TResultJSON.Create(Self);
  FResult.FServerMode := True;  // ������ģʽ
  FReceiver := TWSServerReceiver.Create(Self, FJSON);
end;

destructor TWebSocket.Destroy;
begin
  FJSON.Free;
  FResult.Free;
  FReceiver.Free;
  inherited;
end;

procedure TWebSocket.ExecuteWork;
begin
  // �������ݣ�ִ������

  // 1. ��������
  FTickCount := GetTickCount;

  if FReceiver.Completed then  // �����ݰ�
  begin
    // ��������������
    // ���ܸı� FMsgType���� FReceiver.UnMarkData
    FMsgType := mtDefault;
    FReceiver.Prepare(FRecvBuf^.Data.buf, FByteCount);
    case FReceiver.OpCode of
      ocClose: begin
        InterCloseSocket(Self);  // �رգ�����
        Exit;
      end;
      ocPing, ocPong: begin
        InternalRecv;  // Ͷ�ţ�����
        Exit;
      end;
    end;
  end else
  begin
    // ���պ������ݰ�
    FReceiver.Receive(FRecvBuf^.Data.buf, FByteCount);
  end;

  // �Ƿ�������
  FCompleted := FReceiver.Completed;

  // 2. ����Ӧ�ò�
  // 2.1 ��׼������ÿ����һ�μ�����
  // 2.2 ��չ�Ĳ������� JSON ��Ϣ��������ϲŽ���

  try
    if (FMsgType = mtDefault) or FCompleted then
    begin
      if (FMsgType <> mtDefault) then
        FResult.Action := FJSON.Action;  // ���� Action
      FWorker.WebSocketExecute(Self);
    end;
  finally
    if FCompleted then   // �������
    begin
      case FMsgType of
        mtJSON: begin   // ��չ�� JSON
          FJSON.Clear;  // ���� Attachment
          FResult.Clear;
          FReceiver.Clear;
        end;
        mtAttachment: begin  // ��չ�ĸ�����
          FJSON.Close;  // �رո�����
          FResult.Clear;
          FReceiver.Clear;
        end;
      end;
      InternalPong;  // pong �ͻ���
    end;
    // ��������
    InternalRecv;
  end;

end;

function TWebSocket.GetObjectState(const Group: string; AdminType: Boolean): Boolean;
begin
  // ȡ״̬���Ƿ���Խ�������
  // ͬ���顢�Ѿ����չ����ݣ��й���ԱȨ��
  Result := (FByteCount > 0) and (FUserGroup = Group) and
           ((AdminType = False) or (FRole >= crAdmin));
end;

procedure TWebSocket.InternalPong;
begin
  // Ping �ͻ��ˣ����µ���Ϣ����������
  if (FBackground = False) then
  begin
    MakeFrameHeader(FSender.Data, ocPong);
    FSender.SendBuffers;
  end;
end;

procedure TWebSocket.PostEvent(IOKind: TIODataType);
begin
  // Empty
end;

procedure TWebSocket.SendData(const Msg: String);
begin
  // δ��װ�������ı�
  if (FBackground = False) and (Msg <> '') then
  begin
    FSender.OpCode := ocText;
    FSender.Send(System.AnsiToUtf8(Msg));
  end;
end;

procedure TWebSocket.SendData(const Data: PAnsiChar; Size: Cardinal);
var
  Buf: PAnsiChar;
begin
  // δ��װ�������ڴ�����ݣ����� Data��
  if (FBackground = False) and Assigned(Data) and (Size > 0) then
  begin
    GetMem(Buf, Size);
    System.Move(Data^, Buf^, Size);
    FSender.OpCode := ocBiary;
    FSender.Send(Buf, Size);
  end;
end;

procedure TWebSocket.SendData(Handle: THandle);
begin
  // δ��װ�������ļ� handle���Զ��رգ�
  if (FBackground = False) and (Handle > 0) and (Handle <> INVALID_HANDLE_VALUE) then
  begin
    FSender.OpCode := ocBiary;
    FSender.Send(Handle, GetFileSize64(Handle));
  end;
end;

procedure TWebSocket.SendData(Stream: TStream);
begin
  // δ��װ�����������ݣ��Զ��ͷţ�
  if (FBackground = False) and Assigned(Stream) then
  begin
    FSender.OpCode := ocBiary;
    FSender.Send(Stream, Stream.Size, True);
  end;
end;

procedure TWebSocket.SendDataVar(Data: Variant);
begin
  // δ��װ�����Ϳɱ���������
  if (FBackground = False) and (VarIsNull(Data) = False) then
  begin
    FSender.OpCode := ocBiary;
    FSender.SendVar(Data);
  end;
end;

procedure TWebSocket.SendResult(UTF8CharSet: Boolean);
begin
  // ���� FResult ���ͻ��ˣ�InIOCP-JSON��
  if (FBackground = False) then
  begin
    FResult.FOwner := FJSON.FOwner;
    FResult.InternalSend(FSender, False);
  end;
end;

procedure TWebSocket.SetProps(AOpCode: TWSOpCode; AMsgType: TWSMsgType;
                     AData: Pointer; AFrameSize: Int64; ARecvSize: Cardinal);
begin
  // ���£�����TWSServerReceiver.InitResources
  FMsgType := AMsgType;  // ��������
  FOpCode := AOpCode;  // ����
  FMsgSize := 0;  // ��Ϣ����
  FInData := AData; // ���õ�ַ
  FFrameSize := AFrameSize;  // ֡����
  FFrameRecvSize := ARecvSize;  // �յ�֡����
end;

{ TSocketBroker }

procedure TSocketBroker.AssociateInner(InnerBroker: TSocketBroker);
begin
  // �ⲿ�������ڲ� Socket �����������Ѿ�Ͷ�� WSARecv��
  try
    // ת����Դ
    FDualConnected := True;
    FDualSocket := InnerBroker.FSocket;
    FDualBuf := InnerBroker.FRecvBuf;
    FDualBuf^.Owner := Self;  // ������
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TSocketBroker.AssociateInner->�׽��ֹ����ɹ���' + 
                       FPeerIPPort + '<->' + InnerBroker.FPeerIPPort + '���ڣ�����');
    {$ENDIF}
  finally
    // ��� InnerBroker ��Դֵ������
    InnerBroker.FRecvBuf := nil;
    InnerBroker.FConnected := False;
    InnerBroker.FDualConnected := False;
    InnerBroker.FSocket := INVALID_SOCKET;
    InnerBroker.InterCloseSocket(InnerBroker);
  end;
end;

procedure TSocketBroker.BrokerPostRecv(ASocket: TSocket; AData: PPerIOData; ACheckState: Boolean);
var
  ByteCount, Flags: DWORD;
begin
  // Ͷ�� WSRecv: ASocket, AData

  // ����ʱ FState=1�������κ�ֵ��˵���������쳣��
  // FState = 1 -> ����������ı���״̬���رգ�

  if ACheckState and (InterlockedDecrement(FState) <> 0) then
  begin
    FErrorCode := 9;
    InterCloseSocket(Self);
  end else
  begin
    // ���ص��ṹ
    FillChar(AData^.Overlapped, SizeOf(TOverlapped), 0);

    AData^.Owner := Self;  // ����
    AData^.IOType := ioReceive;  // iocp_server ���ж���
    AData^.Data.len := IO_BUFFER_SIZE;  // ����

    ByteCount := 0;
    Flags := 0;

    if (iocp_Winsock2.WSARecv(ASocket, @(AData^.Data), 1, ByteCount,
        Flags, LPWSAOVERLAPPED(@AData^.Overlapped), nil) = SOCKET_ERROR) then
    begin
      FErrorCode := WSAGetLastError;
      if (FErrorCode <> ERROR_IO_PENDING) then  // �쳣
      begin
        SocketError(ioReceive);
        InterCloseSocket(Self);  // �ر�
      end else
        FErrorCode := 0;
    end;
  end;
end;

procedure TSocketBroker.ClearResources;
begin
  // �������δ���������ӱ��Ͽ������ⲹ������
  if TInIOCPBroker(FBroker).ReverseMode and (FSocketType = stOuterSocket) then
    TIOCPBrokerRef(FBroker).IncOuterConnection;
  if FDualConnected then  // ���Թر�
    TryClose;
end;

procedure TSocketBroker.CreateBroker(const AServer: AnsiString; APort: Integer);
begin
  // �½�һ���ڲ������м��׽��֣������ܸı�����

  if (FDualSocket <> INVALID_SOCKET) or
     (TInIOCPServer(FServer).ServerAddr = AServer) and  // �������ӵ�����������
     (TInIOCPServer(FServer).ServerPort = APort) then
    Exit;
    
  // ���׽���
  FDualSocket := iocp_utils.CreateSocket;

  if (ConnectSocket(FDualSocket, AServer, APort) = False) then  // ����
  begin
    FErrorCode := GetLastError;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TSocketBroker.CreateBroker->�����׽�������ʧ�ܣ�' +
                      AServer + ':' + IntToStr(APort) + ',' +
                      GetSysErrorMessage(FErrorCode));
    {$ENDIF}
  end else
  if TInIOCPServer(FServer).IOCPEngine.BindIoCompletionPort(FDualSocket) then  // ��
  begin
    // ��������ڴ��
    if (FDualBuf = nil) then
      FDualBuf := BufferPool.Pop^.Data;

    // Ͷ�� FDualSocket
    BrokerPostRecv(FDualSocket, FDualBuf, False);

    if (FErrorCode = 0) then  // �쳣
    begin
      FDualConnected := True;
      FTargetHost := AServer;
      FTargetPort := APort;
      if TInIOCPBroker(FBroker).ReverseMode then  // �������
      begin
        FSocketType := stDefault;  // �ı䣨�ر�ʱ���������ӣ�
        TIOCPBrokerRef(FBroker).IncOuterConnection;  // ���ⲹ������
      end;
      {$IFDEF DEBUG_MODE}
      iocp_log.WriteLog('TSocketBroker.CreateBroker->�����׽��ֹ����ɹ���' +
                        FPeerIPPort + '<->' + AServer + ':' +
                        IntToStr(APort) + '���⣬����');
      {$ENDIF}
    end;
  end else
  begin
    FErrorCode := GetLastError;
    {$IFDEF DEBUG_MODE}
    iocp_log.WriteLog('TSocketBroker.CreateBroker->�����׽��ֹ���ʧ�ܣ�' +
                      AServer + ':' + IntToStr(APort) + ',' +
                      GetSysErrorMessage(FErrorCode));
    {$ENDIF}
  end;
end;

procedure TSocketBroker.ExecuteWork;
  function CheckInnerSocket: Boolean;
  begin
    // ++�ⲿ����ģʽ���������ӣ�
    // 1���ⲿ�ͻ��ˣ����ݲ��� InIOCP_INNER_SOCKET
    // 2���ڲ��ķ������ͻ��ˣ����ݴ� InIOCP_INNER_SOCKET:InnerBrokerId
    if (PInIOCPInnerSocket(FRecvBuf^.Data.buf)^ = InIOCP_INNER_SOCKET) then
    begin
      // �����ڲ��ķ���������ӣ����浽�б��� TInIOCPBroker.BindBroker ���
      SetString(FBrokerId, FRecvBuf^.Data.buf + Length(InIOCP_INNER_SOCKET) + 1,
                           Integer(FByteCount) - Length(InIOCP_INNER_SOCKET) - 1);
      TIOCPBrokerRef(FBroker).AddConnection(Self, FBrokerId);
      Result := True;
    end else
      Result := False;  // �����ⲿ�Ŀͻ�������
  end;
  procedure ExecSocketAction;
  begin
    // �����ڲ����ӱ�־���ⲿ����
    try
      if (TInIOCPBroker(FBroker).BrokerId = '') then  // ��Ĭ�ϱ�־
        FSender.Send(InIOCP_INNER_SOCKET + ':DEFAULT')
      else  // ͬʱ���ʹ����־�������ⲿ��������
        FSender.Send(InIOCP_INNER_SOCKET + ':' + UpperCase(TInIOCPBroker(FBroker).BrokerId));
    finally
      FAction := 0;
    end;
  end;
  procedure CopyForwardData(ASocket, AToSocket: TSocket; AData: PPerIOData; MaskInt: Integer);
  begin
    // ���ܼ򵥻������ݿ飬����󲢷�ʱ AData ���ظ�Ͷ�� -> 995 �쳣
    try
      // ִ��ת��ǰ�¼���FRecvState = 1 ����= 2 ����
      if Assigned(FOnBeforeForward) then
        FOnBeforeForward(Self, AData^.Data.buf, AData^.Data.len, FRecvState);
      FSender.Socket := AToSocket;  // ���� AToSocket
      FRecvState := FRecvState and MaskInt;  // ȥ��״̬
      TServerTaskSender(FSender).CopySend(AData);  // ��������
    finally
      if (FErrorCode = 0) then
        BrokerPostRecv(ASocket, AData)  // ����Ͷ�� WSRecv
      else
        InterCloseSocket(Self);
    end;
  end;
  procedure ForwardData;
  begin
    if FCmdConnect then  // 1. Http����� Connect ������Ӧ��and (AProxyType <> ptOuter) 
    begin
      FCmdConnect := False;
      FSender.Send(HTTP_PROXY_RESPONSE);
      BrokerPostRecv(FSocket, FRecvBuf);
    end else  // 2. ת������
    if (FRecvState and $0001 = 1) then
      CopyForwardData(FSocket, FDualSocket, FRecvBuf, 2)
    else
      CopyForwardData(FDualSocket, FSocket, FDualBuf, 1);
  end;
begin
  // ִ�У�
  //   1���󶨡������������ⲿ���ݵ� FDualSocket
  //   2���Ѿ�����ʱֱ�ӷ��͵� FDualSocket

  // Ҫ�������� TInIOCPBroker.ProxyType

  FTickCount := GetTickCount;

  case TIOCPBrokerRef(FBroker).ProxyType of
    ptDefault: // Ĭ�ϴ���ģʽ
      if (FAction > 0) then  // �������, ����SendInnerFlag
      begin
        ExecSocketAction;    // ִ�в���������
        BrokerPostRecv(FSocket, FRecvBuf);  // Ͷ��
        Exit;
      end;
    ptOuter:   // �ⲿ����ģʽ
      if (FDualConnected = False) and CheckInnerSocket then  // ���ڲ�������������
      begin
        BrokerPostRecv(FSocket, FRecvBuf); // ��Ͷ��
        Exit;
      end;
  end;

  // ��ʼʱ����Э���һ�������������������ú���ɾ����

  try
    try
      if Assigned(FOnBind) then  // ��ʼʱ FOnBind <> nil
        try
          FOnBind(Self, FRecvBuf^.Data.buf, FByteCount);  // �󶨡�����
        finally
          FOnBind := nil;  // ɾ�����¼����Ժ��ٰ󶨣�
        end;
    finally
      if FDualConnected then  // ���ڴ�����������
        ForwardData       // ת������
      else
        InterCloseSocket(Self);
    end;
  except
    raise;
  end;

end;

procedure TSocketBroker.HttpBindOuter(Connection: TSocketBroker; const Data: PAnsiChar; DataSize: Cardinal);
  procedure GetConnectHost(var p: PAnsiChar);
  var
    pb: PAnsiChar;
    i: Integer;
  begin
    // ��ȡ������ַ��CONNECT xxx:443 HTTP/1.1
    Delete(FTargetHost, 1, Length(FTargetHost));

    pb := nil;
    Inc(p, 7);  // connect

    for i := 1 to FByteCount do
    begin
      if (p^ = #32) then
        if (pb = nil) then  // ��ַ��ʼ
          pb := p
        else begin  // ��ַ���������жϰ汾
          SetString(FTargetHost, pb, p - pb);
          FTargetHost := Trim(FTargetHost);
          Break;
        end;
      Inc(p);
    end;
  end;
  procedure GetHttpHost(var p: PAnsiChar);
  var
    pb: PAnsiChar;
  begin
    // ��ȡ������ַ��HOST:
    pb := nil;
    Inc(p, 4);
    repeat
      case p^ of
        ':':
          if (pb = nil) then
            pb := p + 1;
        #13: begin
          SetString(FTargetHost, pb, p - pb);
          FTargetHost := Trim(FTargetHost);
          Exit;
        end;
      end;
      Inc(p);
    until (p^ = #10);
  end;
  procedure GetUpgradeType(var p: PAnsiChar);
  var
    S: AnsiString;
    pb: PAnsiChar;
  begin
    // ��ȡ���ݳ��ȣ�UPGRADE: WebSocket
    pb := nil;
    Inc(p, 14);
    repeat
      case p^ of
        ':':
          pb := p + 1;
        #13: begin
          SetString(S, pb, p - pb);
          if (UpperCase(Trim(S)) = 'WEBSOCKET') then
            FSocketType := stWebSocket;
          Exit;
        end;
      end;
      Inc(p);
    until (p^ = #10);
  end;
  procedure ExtractHostPort;
  var
    i, j, k: Integer;
  begin
    // ���� Host��Port �� ��������־

    j := 0;
    k := 0;

    for i := 1 to Length(FTargetHost) do  // 127.0.0.1:800@DEFAULT
      case FTargetHost[i] of
        ':':
          j := i;
        '@':  // HTTP ���������չ������Ϊ������/�ֹ�˾��־
          k := i;
      end;

    if (k > 0) then  // ��������־
    begin
      if (TInIOCPBroker(FBroker).ProxyType = ptOuter) then  // �ⲿ�������
        FBrokerId := Copy(FTargetHost, k + 1, 99);
      Delete(FTargetHost, k, 99);
    end;

    if (j > 0) then  // �ڲ�����
    begin
      TryStrToInt(Copy(FTargetHost, j + 1, 99), FTargetPort);
      Delete(FTargetHost, j, 99);
    end;
    
  end;
  procedure HttpRequestDecode;
  var
    iState: Integer;
    pE, pb, p: PAnsiChar;
  begin
    // Http Э�飺��ȡ������Ϣ��Host��Upgrade

    p := FRecvBuf^.Data.buf;  // ��ʼλ��
    pE := PAnsiChar(p + FByteCount);  // ����λ��

    // 1��HTTP����Connect �������=443
    if http_utils.CompareBuffer(p, 'CONNECT', True) then
    begin
      FCmdConnect := True;
      GetConnectHost(p);  // p �ı�
      ExtractHostPort;
      Exit;
    end;

    // 2������ HTTP ����
    
    iState := 0;  // ��Ϣ״̬
    FCmdConnect := False;
    FTargetPort := 80;  // Ĭ�϶˿ڣ�����=443
    pb := nil;

    Inc(p, 12);

    repeat
      case p^ of
        #10:  // ���з�
          pb := p + 1;

        #13:  // �س���
          if (pb <> nil) then
            if (p = pb) then  // ���������Ļس����У���ͷ����
            begin
              Inc(p, 2);
              Break;
            end else
            if (p - pb >= 15) then
            begin
              if http_utils.CompareBuffer(pb, 'HOST', True) then
              begin
                Inc(iState);
                GetHttpHost(pb);
                ExtractHostPort;
              end else
              if http_utils.CompareBuffer(pb, 'UPGRADE', True) then  // WebSocket
              begin
                Inc(iState, 2);
                GetUpgradeType(pb);
              end;
            end;
      end;

      Inc(p);
    until (p >= pE) or (iState = 3);

  end;
  procedure HttpConnectHost(const AServer: AnsiString; APort: Integer);
  begin
    // Http Э�飺���ӵ���������� HOST��û��ʱ���ӵ�����ָ����
    if (FTargetHost <> '') and (FTargetPort > 0) then
      CreateBroker(FTargetHost, FTargetPort)
    else
    if (AServer <> '') and (APort > 0) then  // �ò���ָ����
      CreateBroker(AServer, APort);
  end;
var
  Accept: Boolean;
begin
  // Http Э�飺��� Connect �������������� Host

  // ��ȡ Host ��Ϣ
  HttpRequestDecode;

  // �������ӵ�����������
  if (TInIOCPServer(FServer).ServerAddr = FTargetHost) and
     (TInIOCPServer(FServer).ServerPort = FTargetPort) then
    Exit;

  Accept := True;
  if Assigned(TInIOCPBroker(FBroker).OnAccept) then  // �Ƿ���������
    TInIOCPBroker(FBroker).OnAccept(Self, FTargetHost, FTargetPort, Accept);

  if Accept then
    case TInIOCPBroker(FBroker).ProxyType of
      ptDefault:  // Ĭ�ϴ����½����ӣ�����
        HttpConnectHost(TInIOCPBroker(FBroker).InnerServer.ServerAddr,
                        TInIOCPBroker(FBroker).InnerServer.ServerPort);
      ptOuter:    // �ڲ��������ڲ����ӳ�ѡȡ��������
        TIOCPBrokerRef(FBroker).BindInnerBroker(Connection, Data, DataSize);
    end;

end;

procedure TSocketBroker.IniSocket(AServer: TObject; ASocket: TSocket; AData: Pointer);
begin
  inherited;
  FRecvState := 0;
  FTargetHost := '';
  FTargetPort := 0;
  FUseTransObj := False;  // ���� TransmitFile

  FCmdConnect := False;
  FDualConnected := False;  // Dual δ����
  FDualSocket := INVALID_SOCKET;

  // ���������
  FBroker := TInIOCPServer(FServer).IOCPBroker;
  FOnBeforeForward := TInIOCPBroker(FBroker).OnBeforeForwardData;

  case TInIOCPBroker(FBroker).ProxyType of
    ptDefault:  // ����ƽ��������¼�
      if (TInIOCPBroker(FBroker).Protocol = tpHTTP) then
        FOnBind := HttpBindOuter
      else
        FOnBind := TInIOCPBroker(FBroker).OnBind;
    ptOuter: begin
      FBrokerId := 'DEFAULT';  // Ĭ�ϵ� FBrokerId
      FOnBind := TIOCPBrokerRef(FBroker).BindInnerBroker;  // ֱ����ԣ���ʱ FCmdConnect ��Ϊ False
    end;
  end;

end;

procedure TSocketBroker.InterCloseSocket(Sender: TObject);
begin
  // �����ڴ�顢�ر� DualSocket
  if TInIOCPServer(FServer).Active and Assigned(FDualBuf) then
  begin
    BufferPool.Push(FDualBuf^.Node);
    FDualBuf := nil;
  end;
  if FDualConnected then
    try
      iocp_Winsock2.Shutdown(FDualSocket, SD_BOTH);
      iocp_Winsock2.CloseSocket(FDualSocket);
    finally
      FDualSocket := INVALID_SOCKET;
      FDualConnected := False;
    end;
  inherited;
end;

procedure TSocketBroker.MarkIODataBuf(AData: PPerIOData);
begin
  // AData �Ľ���״̬
  if (AData = FRecvBuf) then
    FRecvState := FRecvState or $0001  // Windows.InterlockedIncrement(FRecvState)
  else
    FRecvState := FRecvState or $0002; // Windows.InterlockedExchangeAdd(FRecvState, 2);
end;

procedure TSocketBroker.PostEvent(IOKind: TIODataType);
begin
  InterCloseSocket(Self);  // ֱ�ӹرգ��� TInIOCPServer.AcceptClient
end;

procedure TSocketBroker.SendInnerFlag;
begin
  // ����������ⲿ���������ӱ�־���� ExecSocketAction ִ��
  FAction := 1;  // �������
  FState := 0;   // ����
  TInIOCPServer(FServer).BusiWorkMgr.AddWork(Self);
end;

procedure TSocketBroker.SetConnection(AServer: TObject; Connection: TSocket);
begin
  // ��������ڲ��������������ⲿ������
  IniSocket(AServer, Connection);
  FSocketType := stOuterSocket;  // ���ӵ��ⲿ��
  if (TInIOCPBroker(FBroker).Protocol = tpNone) then
    FOnBind := TInIOCPBroker(FBroker).OnBind; // �󶨹����¼�
end;

end.
