(*
 * iocp c/s Э��ͻ��������
 *)
unit iocp_clients;

interface

{$I in_iocp.inc}

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes, System.SysUtils, Vcl.ExtCtrls,
  System.Variants, Data.DB, Datasnap.DSIntf, Datasnap.DBClient, VCL.Forms, {$ELSE}
  Windows, Classes, SysUtils, ExtCtrls, Variants, DB, DSIntf, DBClient, Forms, {$ENDIF}
  iocp_zlib, iocp_Winsock2, iocp_base, iocp_utils, iocp_lists, iocp_senders,
  iocp_receivers, iocp_clientBase, iocp_baseObjs, iocp_msgPacks;
//  MidasLib;    // ʹ��ʱ��ӵ�Ԫ���� MidasLib��

type

  // ============= IOCP �ͻ��� �� =============

  TSendThread = class;
  TRecvThread = class;
  TPostThread = class;

  TClientParams = class;
  TResultParams = class;
  TInBaseClient = class;

  // ============ C/S Э��ͻ������� ============

  // ���������¼�
  TAddWorkEvent = procedure(Sender: TObject; Msg: TClientParams) of object;

  // ���������¼�
  TPassvieEvent = procedure(Sender: TObject; Msg: TResultParams) of object;

  // ��������¼�
  TReturnEvent  = procedure(Sender: TObject; Result: TResultParams) of object;

  TInConnection = class(TBaseConnection)
  private
    FActResult: TActionResult; // �������������
    FCancelCount: Integer;     // ȡ��������
    FMaxChunkSize: Integer;    // ������ÿ������䳤��

    FErrorMsg: String;         // ������쳣��Ϣ
    FUserGroup: string;        // �û����飨������ã�
    FUserName: string;         // ��¼���û�����������ã�

    FReuseSessionId: Boolean;  // ƾ֤���ã�������ʱ,�´����¼��
    FRole: TClientRole;        // Ȩ��
    FSessionId: Cardinal;      // ƾ֤/�Ի��� ID

    // ======================

    FOnAddWork: TAddWorkEvent;       // ���������¼�
    FOnReceiveMsg: TPassvieEvent;    // ����������Ϣ�¼�
    FOnReturnResult: TReturnEvent;   // ������ֵ�¼�
  private
    function GetLogined: Boolean;
    procedure ShowServerError(Msg: TResultParams);
    procedure HandleMsgHead(Result: TResultParams);
    procedure HandleFeedback(Result: TResultParams);
    procedure HandlePushedMsg(Msg: TResultParams);
    procedure SetMaxChunkSize(Value: Integer);
  protected
    procedure DoServerError; override;
    procedure InterBeforeConnect; override;
    procedure InterAfterConnect; override;  // ��ʼ����Դ
    procedure InterAfterDisconnect; override;  // �ͷ���Դ
  public
    constructor Create(AOwner: TComponent); override;
    procedure CancelAllWorks;                 // ȡ��ȫ������
    procedure CancelWork(MsgId: TIOCPMsgId);  // ȡ������
  public
    property ActResult: TActionResult read FActResult;
    property CancelCount: Integer read FCancelCount;
    property Logined: Boolean read GetLogined;
    property SessionId: Cardinal read FSessionId;
    property UserGroup: string read FUserGroup;
    property UserName: string read FUserName;
  published
    property MaxChunkSize: Integer read FMaxChunkSize write SetMaxChunkSize default MAX_CHUNK_SIZE;
    property ReuseSessionId: Boolean read FReuseSessionId write FReuseSessionId default False;
  published
    property OnAddWork: TAddWorkEvent read FOnAddWork write FOnAddWork;
    property OnReceiveMsg: TPassvieEvent read FOnReceiveMsg write FOnReceiveMsg; // ���ձ�����Ϣ/������Ϣ�¼�
    property OnReturnResult: TReturnEvent read FOnReturnResult write FOnReturnResult;
  end;

  // ============ �ͻ����յ������ݰ�/������ ============

  TResultParams = class(TReceivePack)
  protected
    procedure CreateAttachment(const ALocalPath: string); override;
  public
    property PeerIPPort;
  end;

  // ============ TInBaseClient ����Ϣ�� ============

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
    // �ͻ��˳����������ԣ���д��
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

  TMessagePack = class(TClientParams)
  private
    procedure InternalPost(AAction: TActionType);
    procedure InitMessage(AConnection: TInConnection);
  public
    constructor Create(AOwner: TInConnection); overload;
    constructor Create(AOwner: TInBaseClient); overload;
    procedure Post(AAction: TActionType);  // ���� Post ����
  end;

  // ============ �ͻ������ ���� ============

  // �о��ļ��¼�
  TListFileEvent = procedure(Sender: TObject; ActResult: TActionResult;
                             No: Integer; Result: TCustomPack) of object;

  TInBaseClient = class(TComponent)
  private
    FConnection: TInConnection;    // �ͻ�������
    FFileList: TStrings;           // ��ѯ�ļ����б�
    FParams: TClientParams;        // ��������Ϣ������Ҫֱ��ʹ�ã�
    FOnListFiles: TListFileEvent;  // ��������Ϣ�ļ�
    FOnReturnResult: TReturnEvent; // ������ֵ�¼�
    function CheckState(CheckLogIn: Boolean = True): Boolean;
    function GetParams: TClientParams;
    procedure InternalPost(Action: TActionType = atUnknown);
    procedure ListReturnFiles(Result: TResultParams);
    procedure SetConnection(const Value: TInConnection);
  protected
    procedure HandleFeedback(Result: TResultParams); virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  protected
    property Connection: TInConnection read FConnection write SetConnection;
    property Params: TClientParams read GetParams;
    property OnListFiles: TListFileEvent read FOnListFiles write FOnListFiles;
  public
    destructor Destroy; override;
  published
    property OnReturnResult: TReturnEvent read FOnReturnResult write FOnReturnResult;
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
    FGroup: string;       // ����
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
    procedure Register(const AGroup, AUserName, APassword: string; Role: TClientRole = crClient);
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
    property OnListFiles;
  end;

  // ============ �ļ�����ͻ��� ============

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
    property OnListFiles;
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
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
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

  TAfterLoadData = procedure(DataSet: TClientDataSet; const TableName: String) of object;

  TInDBQueryClient = class(TDBBaseClientObject)
  private
    FClientDataSet: TClientDataSet;  // �������ݼ�
    FSubClientDataSets: TList;       // �����ӱ�
    FTableNames: TStrings;           // Ҫ���µ�Զ�̱���
    FReadOnly: Boolean;              // �Ƿ�ֻ��
    FAfterLoadData: TAfterLoadData;  // װ�����ݺ��¼�
    procedure LoadFromAttachment(Result: TResultParams);
    procedure LoadFromField(Result: TBasePack; Action: TActionType);
  protected
    procedure HandleFeedback(Result: TResultParams); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddClientDataSet(AClientDataSet: TClientDataSet);
    procedure ApplyUpdates;
    procedure ClearClientDataSets;
    procedure ExecQuery(Action: TActionType = atDBExecQuery);
    procedure LoadFromFile(const FileName: String);
  public
    property ReadOnly: Boolean read FReadOnly;
  published
    property AfterLoadData: TAfterLoadData read FAfterLoadData write FAfterLoadData;  
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

  TSendThread = class(TBaseSendThread)
  private
    FMsgPack: TClientParams;   // ��ǰ������Ϣ��
  protected
    function ChunkRequest(Msg: TBasePackObject): Boolean; override;
    procedure InterSendMsg(RecvThread: TBaseRecvThread); override;
  public
    procedure AddWork(Msg: TBasePackObject); override;
    procedure ServerFeedback(Accept: Boolean); override;
  end;

  // =================== Ͷ�Ž�����߳� �� ===================
  // ������յ�����Ϣ���б���һ����Ӧ�ò�

  TPostThread = class(TBasePostThread)
  private
    FMsg: TResultParams;       // ���б�ȡ������Ϣ
    FMsgEx: TResultParams;     // �ȴ��������ͽ������Ϣ
    procedure DoInMainThread;
  protected
    procedure HandleMessage(Msg: TBasePackObject); override;
  public
    procedure Add(Msg: TBasePackObject); override;  
  end;

  // =================== �����߳� �� ===================

  TRecvThread = class(TBaseRecvThread)
  protected
    procedure HandleDataPacket; override; // �����յ������ݰ�
    procedure OnDataReceive(Msg: TBasePackObject; Part: TMessagePart; RecvCount: Cardinal); override;
  public
    constructor Create(AConnection: TInConnection);
    procedure Reset;
    procedure SetLocalPath(const Path: string);    
  end;

implementation

uses
  http_base, iocp_api, iocp_wsExt;

{ TInConnection }

procedure TInConnection.CancelAllWorks;
begin
  // ȡ��ȫ������
  if Assigned(FSendThread) then
  begin
    FSendThread.ClearAllWorks(FCancelCount);
    FSendThread.Activate;
    if Assigned(OnError) then
      OnError(Self, 'ȡ�� ' + IntToStr(FCancelCount) + ' ������.');
  end;
end;

procedure TInConnection.CancelWork(MsgId: TIOCPMsgId);
begin
  // ȡ��ָ����Ϣ�ŵ�����
  if Assigned(FSendThread) and (MsgId > 0) then
  begin
    FSendThread.CancelWork(MsgId);
    if Assigned(OnError) then
      OnError(Self, 'ȡ��������Ϣ��־: ' + IntToStr(MsgId));
  end;
end;

constructor TInConnection.Create(AOwner: TComponent);
begin
  inherited;
  FMaxChunkSize := MAX_CHUNK_SIZE;
  FReuseSessionId := False;
end;

procedure TInConnection.DoServerError;
begin
  // �յ��쳣���ݣ������쳣
  try
    if Assigned(OnError) then
      case FActResult of
        arOutDate:
          OnError(Self, '��������ƾ֤/��֤����.');
        arDeleted:
          OnError(Self, '����������ǰ�û�������Աɾ�����Ͽ�����.');
        arRefuse:
          OnError(Self, '���������ܾ����񣬶Ͽ�����.');
        arTimeOut:
          OnError(Self, '����������ʱ�˳����Ͽ�����.');
        arErrAnalyse:
          OnError(Self, '�����������������쳣.');
        arErrBusy:
          OnError(Self, '��������ϵͳ��æ����������.');
        arErrHash:
          OnError(Self, '��������У���쳣.');
        arErrHashEx:
          OnError(Self, '�ͻ��ˣ�У���쳣.');
        arErrInit:  // �յ��쳣����
          OnError(Self, '�ͻ��ˣ����ճ�ʼ���쳣���Ͽ�����.');
        arErrPush:
          OnError(Self, '��������������Ϣ�쳣.');
        arErrUser:  // ������ SessionId �ķ���
          OnError(Self, '��������δ��¼��Ƿ��û�.');
        arErrWork:  // �����ִ�������쳣
          OnError(Self, '��������' + FErrorMsg);
      end;
  finally
    if (FActResult in [arDeleted, arRefuse, arTimeOut, arErrInit]) then
      FTimer.Enabled := True;  // �Զ��Ͽ�
  end;
end;

function TInConnection.GetLogined: Boolean;
begin
  Result := FActive and (FSessionId > 0);
end;

procedure TInConnection.InterAfterConnect;
begin
  // �Ѿ����ӳɹ�

  // ���������̣߳���ǰ��
  FSendThread := TSendThread.Create(Self, True);
  FSendThread.Resume;

  // �ύ��Ϣ�߳�
  FPostThread := TPostThread.Create(Self);
  FPostThread.Resume;

  // ���������̣߳��ں�
  FRecvThread := TRecvThread.Create(Self);
  FRecvThread.Resume;
end;

procedure TInConnection.InterAfterDisconnect;
begin
  // �����Զ��ͷŸ��߳�
  // �����ӣ�����ƾ֤���´����¼
  if not FReuseSessionId then
  begin
    FSessionId := 0;
    FRole := crUnknown;
  end;
end;

procedure TInConnection.InterBeforeConnect;
begin
  FInitFlag := IOCP_SOCKET_FLAG; // �ͻ��˱�־
end;

procedure TInConnection.HandleFeedback(Result: TResultParams);
begin
  // ������������ص���Ϣ
  HandleMsgHead(Result);
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, Result);
end;

procedure TInConnection.HandleMsgHead(Result: TResultParams);
begin
  // �����¼���ǳ����
  case Result.Action of
    atUserLogin: begin  // SessionId > 0 ���ɹ�
      FSessionId := Result.SessionId;
      FRole := Result.Role;
    end;
    atUserLogout:  // �ǳ������� FSessionId
      InterAfterDisconnect;
  end;
end;

procedure TInConnection.HandlePushedMsg(Msg: TResultParams);
begin
  // �ӵ�������Ϣ�������յ������ͻ�����Ϣ��
  if Assigned(FOnReceiveMsg) then
    FOnReceiveMsg(Self, Msg);
end;

procedure TInConnection.SetMaxChunkSize(Value: Integer);
begin
  if (Value >= MAX_CHUNK_SIZE div 4) and (Value <= MAX_CHUNK_SIZE * 2) then
    FMaxChunkSize := Value
  else
    FMaxChunkSize := MAX_CHUNK_SIZE;
end;

procedure TInConnection.ShowServerError(Msg: TResultParams);
begin
  FActResult := Msg.ActResult;
  FErrorMsg := Msg.Msg;
  DoServerError;
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
      Msg.LoadFromFile(InfFileName);

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
  InfFileName := FConnection.LocalPath + GetFileName + '.download';
  Msg := TCustomPack.Create;

  try
    Msg.LoadFromFile(InfFileName);

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
    Msg.LoadFromFile(InfFileName);

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

  if (FAction = atFileUpChunk) then
    MsgFileName := FAttachFileName + '.upload'
  else
  if (LocalPath <> '') then  // ��Դ�ļ��ı���·��
    MsgFileName := AddBackslash(LocalPath) + FileName + '.download'
  else
    MsgFileName := AddBackslash(FConnection.LocalPath) + FileName + '.download';

  if FileExists(MsgFileName) then
  begin
    Msg := TCustomPack.Create;
    try
      Msg.LoadFromFile(MsgFileName);
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

constructor TMessagePack.Create(AOwner: TInConnection);
begin
  if (AOwner = nil) then  // ����Ϊ nil
    raise Exception.Create('Owner ����Ϊ��.');
  inherited Create(AOwner);
  InitMessage(TInConnection(AOwner));
end;

constructor TMessagePack.Create(AOwner: TInBaseClient);
begin
  if (AOwner = nil) then  // ����Ϊ nil
    raise Exception.Create('Owner ����Ϊ��.');
  inherited Create(AOwner);
  if (AOwner is TDBBaseClientObject) then
    TDBBaseClientObject(AOwner).UpdateInConnection;
  InitMessage(TInBaseClient(AOwner).FConnection);
end;

procedure TMessagePack.InitMessage(AConnection: TInConnection);
begin
  FConnection := AConnection;
  if not FConnection.Active and FConnection.AutoConnected then
    FConnection.Active := True;
  SetUserGroup(FConnection.FUserGroup); // Ĭ�ϼ������
  SetUserName(FConnection.FUserName);   // Ĭ�ϼ����û���
end;

procedure TMessagePack.InternalPost(AAction: TActionType);
var
  sErrMsg: string;
begin
  // �ύ��Ϣ
  if Assigned(FConnection.FSendThread) then
  begin
    FAction := AAction; // ����
    if (FAction in [atTextPush, atTextBroadcast]) and (Size > BROADCAST_MAX_SIZE) then
      sErrMsg := '���͵���Ϣ̫��.'
    else
    if Error then
      sErrMsg := '���ñ����쳣.'
    else  // ����Ϣ�������߳�
      FConnection.FSendThread.AddWork(Self);
  end else
    sErrMsg := 'δ���ӵ�������.';

  if (sErrMsg <> '') then
  try
    if Assigned(FConnection.OnError) then
      FConnection.OnError(Self, sErrMsg)
    else
      raise Exception.Create(sErrMsg);
  finally
    Free;
  end;
end;

procedure TMessagePack.Post(AAction: TActionType);
begin
  if (AAction = atUserLogin) then  // ��¼���������ӵ��û���Ϣ
  begin
    FConnection.FUserGroup := GetUserGroup;
    FConnection.FUserName := GetUserName;
  end;
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
    if FConnection.AutoConnected then
      FConnection.Active := True;
    if not FConnection.Active then
      Error := '�������ӷ�����ʧ��.';
  end else
  if CheckLogIn and not FConnection.Logined then
    Error := '���󣺿ͻ���δ��¼.';

  if (Error = '') then
    Result := not CheckLogIn or FConnection.Logined
  else begin
    Result := False;
    if Assigned(FParams) then
      FreeAndNil(FParams);
    if Assigned(FConnection.OnError) then
      FConnection.OnError(Self, Error)
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
  if Assigned(FConnection) and
    (FParams.FConnection <> FConnection) then
  begin
    FParams.FConnection := FConnection;
    FParams.FSessionId := FConnection.FSessionId;
    FParams.UserGroup := FConnection.FUserGroup; // Ĭ�ϼ������
    FParams.UserName := FConnection.FUserName;   // Ĭ�ϼ����û���
  end;
  Result := FParams;
end;

procedure TInBaseClient.HandleFeedback(Result: TResultParams);
begin
  // ������������ص���Ϣ
  if Assigned(FOnReturnResult) then
    FOnReturnResult(Self, Result);
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
    try  // �г��ļ���һ���ļ�һ����¼
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
      if Assigned(FConnection.OnError) then
        FConnection.OnError(Self, 'TInBaseClient.ListReturnFiles���������쳣.');
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
    Result := FConnection.FActive and (FConnection.FSessionId > 0)
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
        FOnCertify(Self, atUserLogin, FConnection.Logined);
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
      if Assigned(FConnection.OnError) then
        FConnection.OnError(Self, 'TInCertifyClient.InterListClients, ' + E.Message);
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
    Params.UserGroup := FGroup;
    FParams.UserName := FUserName;
    FParams.Password := FPassword;
    FParams.ReuseSessionId := FConnection.ReuseSessionId;

    // �������ӵ��û���Ϣ
    FConnection.FUserGroup := FGroup;
    FConnection.FUserName := FUserName;  

    InternalPost(atUserLogin);
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

procedure TInCertifyClient.Register(const AGroup, AUserName, APassword: string; Role: TClientRole);
begin
  // ע���û�������Ա��
  if CheckState() and (FConnection.FRole >= crAdmin) and (FConnection.FRole >= Role) then
  begin
    Params.ToUser := AUserName;  // 2.0 �� ToUser
    FParams.UserGroup := AGroup;
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

procedure TDBBaseClientObject.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = FDBConnection) and (Operation = opRemove) then
    FDBConnection := nil;  // ������ TInDBConnection �����ɾ��
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

procedure TInDBQueryClient.AddClientDataSet(AClientDataSet: TClientDataSet);
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

procedure TInDBQueryClient.ExecQuery(Action: TActionType = atDBExecQuery);
begin
  // SQL ��ֵʱ�Ѿ��ж� Action ���ͣ�����THeaderPack.SetSQL
  if (Action in [atDBExecQuery, atDBExecStoredProc]) then
  begin
    UpdateInConnection;  // ���� FConnection
    if CheckState() and Assigned(FParams) then
    begin
      FParams.FTarget := FDBConnection.FConnectionIndex;  // ��Ӧ����ģ���
      if (Action <> atDBExecStoredProc) then
        InternalPost(Action)
      else
        InternalPost(FParams.Action);
    end;
  end;
end;

procedure TInDBQueryClient.HandleFeedback(Result: TResultParams);
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
          if Assigned(FClientDataSet) then
            if Assigned(Result.Attachment) then
              LoadFromAttachment(Result)
            else
            if (Result.VarCount > 0) and
              (Integer(Result.VarCount) = Result.AsInteger['__VarCount']) then
              LoadFromField(Result, Result.Action);
        atDBApplyUpdates:    // 3. ����
          MergeChangeDataSets;  // �ϲ����صĸ�������
      end;
  finally
    inherited HandleFeedback(Result);
  end;
end;

procedure TInDBQueryClient.LoadFromAttachment(Result: TResultParams);
var
  MsgPack: TBasePack;
  FileName: String;
begin
  // ���븽���������ݼ���Ϣ

  // �ȹرո�����
  FileName := Result.Attachment.FileName;
  Result.Attachment.Close;

  // ���븽����
  MsgPack := TBasePack.Create;
  
  try
    MsgPack.LoadFromFile(FileName);
    LoadFromField(MsgPack, Result.Action);
  finally
    MsgPack.Free;
  end;
end;

procedure TInDBQueryClient.LoadFromFile(const FileName: String);
var
  Data: TResultParams;
begin
  // ���ļ���������
  Data := TResultParams.Create;
  try
    Data.LoadFromFile(FileName);
    LoadFromField(Data, Data.Action);
  finally
    Data.Free;
  end;
end;

procedure TInDBQueryClient.LoadFromField(Result: TBasePack; Action: TActionType);
var
  i, k: Integer;
  XDataSet: TClientDataSet;
  DataField: TVarField;
  NoTableName: Boolean;
begin
  // װ�ز�ѯ���

  // Result ���ܰ���������ݼ�
  FTableNames.Clear;
    
  k := -1;
  FReadOnly := (Action = atDBExecStoredProc); // �Ƿ�ֻ��

  for i := 0 to Result.Count - 1 do // ���� AsInteger['__Variable_Count']
  begin
    DataField := Result.Fields[i];  // ȡ�ֶ� 1,2,3
    if (DataField.VarType = etVariant) then
    begin
      Inc(k);
      if (k = 0) then  // �����ݱ�
        XDataSet := FClientDataSet
      else
        XDataSet := FSubClientDataSets[k - 1];

      XDataSet.DisableControls;
      try
        FTableNames.Add(DataField.Name);  // �������ݱ�����
        XDataSet.Data := DataField.AsVariant;  // ���ݸ�ֵ
        NoTableName := (Pos('__@DATASET', DataField.Name) = 1);
        if NoTableName then  // ���ܸ��µ�
          XDataSet.ReadOnly := True
        else
          XDataSet.ReadOnly := FReadOnly;  // �Ƿ�ֻ��
      finally
        XDataSet.EnableControls;
      end;

      // ִ��װ�غ��¼�
      if Assigned(FAfterLoadData) then
        if NoTableName then
          FAfterLoadData(XDataSet, '')
        else
          FAfterLoadData(XDataSet, DataField.Name);
    end;
  end;
end;

procedure TInDBQueryClient.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (AComponent = FClientDataSet) and (Operation = opRemove) then
    FClientDataSet := nil;  // ������ FClientDataSet �����ɾ��
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

{ TSendThread }

procedure TSendThread.AddWork(Msg: TBasePackObject);
var
  CSMsg: TClientParams;
begin
  // ����Ϣ�������б�

  // Msg �Ƕ�̬���ɣ������ظ�Ͷ��
  CSMsg := TClientParams(Msg);

  if (CSMsg.FAction in FILE_CHUNK_ACTIONS) then  // �������޸� MsgId
    CSMsg.ModifyMessageId;

  if Assigned(TInConnection(FConnection).FOnAddWork) then
    TInConnection(FConnection).FOnAddWork(Self, CSMsg);

  inherited;
end;

function TSendThread.ChunkRequest(Msg: TBasePackObject): Boolean;
begin
  Result := (TClientParams(Msg).Action in [atFileDownChunk, atFileUpChunk]);
end;

procedure TSendThread.InterSendMsg(RecvThread: TBaseRecvThread);
  procedure SendMsgHeader;
  begin
    IniWaitState;  // ׼���ȴ�

    // ������Ϣ�ܳ���
    FTotalSize := FMsgPack.GetMsgSize;

    // �ϵ�����ʱҪ��λ��
    if (FMsgPack.FAction in FILE_CHUNK_ACTIONS) then
      FSendCount := FMsgPack.FOffset
    else
      FSendCount := 0;

    // ����Э��ͷ+У����+�ļ�����
    FMsgPack.LoadHead(FSender.Data);

    FSender.MsgPart := mdtHead;  // ��Ϣͷ
    FSender.SendBuffers;
  end;
  procedure SendMsgEntity;
  begin
    FSender.MsgPart := mdtEntity;  // ��Ϣʵ��
    FSender.Send(FMsgPack.FMain, FMsgPack.FDataSize, False);  // ���ͷ���Դ
  end;
  procedure SendMsgAttachment;
  begin
    // ���͸�������(���ر���Դ)
    IniWaitState;  // ׼���ȴ�
    FSender.MsgPart := mdtAttachment;  // ��Ϣ����
    if (FMsgPack.FAction = atFileUpChunk) then  // �ϵ�����
      FSender.Send(FMsgPack.FAttachment, FMsgPack.FAttachSize,
                   FMsgPack.FOffset, FMsgPack.FOffsetEnd, False)
    else
      FSender.Send(FMsgPack.FAttachment, FMsgPack.FAttachSize, False);
  end;
begin
  // ִ�з�������, �����˷�������
  //   ����TReturnResult.ReturnResult��TDataReceiver.Prepare

  FMsgPack := TClientParams(FSendMsg);
  FMsgPack.FSessionId := TInConnection(FConnection).FSessionId; // ��¼ƾ֤
  FSender.Owner := FMsgPack;  // ����

  // 1. ����·��
  if (FMsgPack.LocalPath <> '') then
    TRecvThread(RecvThread).SetLocalPath(AddBackslash(FMsgPack.LocalPath))
  else
    TRecvThread(RecvThread).SetLocalPath(AddBackslash(FConnection.LocalPath));

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
end;

procedure TSendThread.ServerFeedback(Accept: Boolean);
begin
  // ��Ϊ�Ƕ��̣߳�Ҫ�ȸ�ֵ arAccept�����źţ�
  // ���򣬿��ܷ����߳� FMsgPack.FActResult = arUnknown
  if Accept then
    FMsgPack.FActResult := arAccept;
  inherited;
end;

{ TPostThread }

procedure TPostThread.Add(Msg: TBasePackObject);
var
  XMsg: TResultParams;
begin
  // Msg���� TResultParams
  // ��һ����Ϣ���б������߳�

  // 1. ��鸽���������
  XMsg := TResultParams(Msg);

  if (XMsg.ActResult = arAccept) then // ��������������
  begin
    FMsgEx := XMsg;  // �ȱ��淴�����
    FSendThread.ServerFeedback(True); // ���� -> ���͸���
  end else
  begin
    // 2. Ͷ�����̶߳���
    // ������ʱ��δ��¼�����������յ��㲥��Ϣ��
    // ��ʱ FSendThread.FMsgPack=nil��һ��Ͷ��
    FLock.Acquire;
    try
      if Assigned(FMsgEx) and
        (FMsgEx.FMsgId = XMsg.MsgId) then // ���͸�����ķ���
      begin
        XMsg.Free;      // �ͷŸ����ϴ�����������ݣ�
        XMsg := FMsgEx; // ʹ�������ķ�����Ϣ�������ݣ�
        FMsgEx.FActResult := arOK;  // �޸Ľ�� -> �ɹ�
        FMsgEx := nil;  // ��������
      end;
      // �����б�
      FMsgList.Add(XMsg);
    finally
      FLock.Release;
    end;

    Activate;  // ����
  end;
end;

procedure TPostThread.DoInMainThread;
const
  SERVER_PUSH_EVENTS =[arDeleted, arRefuse { ��Ӧ�ô��� }, arTimeOut];
  SELF_ERROR_RESULTS =[arOutDate, arRefuse { c/s ģʽ���� }, arErrBusy,
                       arErrHash, arErrHashEx, arErrAnalyse, arErrPush,
                       arErrUser, arErrWork];
  function IsPushedMessage: Boolean;
  begin
    FLock.Acquire;
    try
      Result := (FSendMsg = nil) or
                (FMsg.Owner <> FSendMsg.Owner) or
                (FSendMsg.MsgId <> FMsg.MsgId); // ����ǰ MsgId ���޸� 
    finally
      FLock.Release;
    end;
  end;
  function IsFeedbackMessage: Boolean;
  begin
    FLock.Acquire;
    try
      Result := (FSendMsg <> nil) and (FSendMsg.MsgId = FMsg.MsgId);
    finally
      FLock.Release;
    end;
  end;
var
  AConnection: TInConnection;
begin
  // �������̣߳�����Ϣ�ύ������
  // ���ܴ�����Ϣ�����б��û��Ͽ�����ʱҪ�ı�Ͽ�ģʽ

  AConnection := TInConnection(FConnection);
  AConnection.FInMainThread := True;  // �������߳�

  try

    if IsPushedMessage() then

      {$IFNDEF DELPHI_7}
      {$REGION '. ����������Ϣ'}
      {$ENDIF}

      try
        if (FMsg.ActResult in SERVER_PUSH_EVENTS) then
        begin
          // 1.1 ���������͵���Ϣ
          AConnection.ShowServerError(FMsg);
        end else
        begin
          // 1.2 �����ͻ������͵���Ϣ
          AConnection.HandlePushedMsg(FMsg);
        end;
      finally
        FMsg.Free;
        AConnection.FInMainThread := False;        
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
        if (AConnection.FSessionId <> FMsg.FSessionId) then
          AConnection.FSessionId := FMsg.FSessionId;
        if (FMsg.ActResult in SELF_ERROR_RESULTS) then
        begin
          // 2.1 ����ִ���쳣
          AConnection.ShowServerError(FMsg);
        end else
        if IsFeedbackMessage() then
        begin
          // 2.2 �����������
          if (FMsg.Owner = AConnection) then
            AConnection.HandleFeedback(FMsg)
          else
            TInBaseClient(FMsg.Owner).HandleFeedback(FMsg);
        end;
      finally
        FMsg.Free;
        if AConnection.FActive then  // �����ѹر�
          AConnection.FSendThread.ServerFeedback;  // ����
        AConnection.FInMainThread := False;
      end;

      {$IFNDEF DELPHI_7}
      {$ENDREGION}
      {$ENDIF}

  except
    on E: Exception do
    begin
      AConnection.FErrorcode := GetLastError;
      AConnection.DoClientError;  // �����̣߳�ֱ�ӵ���
    end;
  end;

end;

procedure TPostThread.HandleMessage(Msg: TBasePackObject);
var
  ReadInfDone: Boolean;
  NewMsg: TMessagePack;
begin
  // Msg���� TResultParams
  
  // ��ϢԤ����
  // Ҫ���ϵ����������������ύ�����߳�ִ��

  FMsg := TResultParams(Msg);

  if (FMsg.FAction in FILE_CHUNK_ACTIONS) then
  begin
    // ��������
    if (FMsg.Owner = FConnection) then
      NewMsg := TMessagePack.Create(TInConnection(FMsg.Owner))
    else
      NewMsg := TMessagePack.Create(TInBaseClient(FMsg.Owner));

    NewMsg.FAction := atUnknown;  // δ֪
    NewMsg.FActResult := FMsg.FActResult;  // ���͸�����ķ������
    NewMsg.FCheckType := FMsg.FCheckType;
    NewMsg.FState := msAutoPost;  // �Զ��ύ
    NewMsg.FZipLevel := FMsg.FZipLevel;

    if (FMsg.FAction = atFileUpChunk) then
    begin
      // �ϵ��ϴ������̴򿪱����ļ������ļ���Ϣ
      //   ����TBaseMessage.LoadFromFile��TReceiveParams.CreateAttachment
      NewMsg.LoadFromFile(FMsg.GetAttachFileName, True);
      ReadInfDone := not NewMsg.Error and NewMsg.ReadUploadInf(FMsg);
    end else
    begin
      // �ϵ����أ����������ļ�������
      // FActResult һ����������Ҳ����У���쳣
      //   ����TReturnResult.LoadFromFile��TResultParams.CreateAttachment
      NewMsg.FileName := FMsg.FileName;
      ReadInfDone := NewMsg.ReadDownloadInf(FMsg);
    end;

    if ReadInfDone then
      NewMsg.Post(FMsg.FAction)
    else  // �������
      NewMsg.Free;
  end;

  // ����ҵ���
  Synchronize(DoInMainThread);  

end;

{ TRecvThread }

constructor TRecvThread.Create(AConnection: TInConnection);
var
  AReceiver: TClientReceiver;
begin
  AReceiver := TClientReceiver.Create;
  FRecvMsg := AReceiver.MsgPack;  // ����Ϣ, TResultParams

  AReceiver.OnNewMsg := OnCreateMsgObject;
  AReceiver.OnPost := AConnection.PostThread.Add;
  AReceiver.OnReceive := OnDataReceive;
  AReceiver.OnError := OnRecvError;

  inherited Create(AConnection, AReceiver);
end;

procedure TRecvThread.HandleDataPacket;
var
  AConection: TInConnection;
  Msg: TResultParams;
begin
  inherited;
  // ������յ������ݰ����ڽ����߳��ڣ�

  AConection := TInConnection(FConnection);
  Msg := TResultParams(FRecvMsg);

  if FReceiver.Completed then  // 1. �װ�����
  begin
    // 1.1 ������ͬʱ���� HTTP ����ʱ�����ܷ����ܾ�������Ϣ��HTTPЭ�飩
    if MatchSocketType(FRecvBuf.buf, HTTP_VER) then
    begin
      AConection.FActResult := arRefuse;
      Synchronize(AConection.DoServerError);
      Exit;
    end;

    // 1.2 C/S ģʽ����
    if (FOverlapped.InternalHigh < IOCP_SOCKET_SIZE) or  // ����̫��
      (MatchSocketType(FRecvBuf.buf, IOCP_SOCKET_FLAG) = False) then // C/S ��־����
    begin
      AConection.FActResult := arErrInit;  // ��ʼ���쳣
      Synchronize(AConection.DoServerError);
      Exit;
    end;

    if (Msg.ActResult <> arAccept) then
      FReceiver.Prepare(FRecvBuf.buf, FOverlapped.InternalHigh)  // ׼������
    else begin
      // �ϴ�������ո������ٴ��յ�������������ϵķ���
      Msg.FActResult := arOK; // Ͷ��ʱ��Ϊ arAccept, �޸�
      TClientReceiver(FReceiver).PostMessage;  // ��ʽͶ��
    end;

  end else
  begin
    // 2. ��������
    FReceiver.Receive(FRecvBuf.buf, FOverlapped.InternalHigh);
  end;

end;

procedure TRecvThread.OnDataReceive(Msg: TBasePackObject; Part: TMessagePart; RecvCount: Cardinal);
var
  XMsg: TResultParams;
  ShowProg: Boolean;
begin
  // ��ʾ���ս���
  // �����ǽ�����ϲŵ��ã�ֻһ��

  // Msg ���� FRecvMsg
  XMsg := TResultParams(Msg);
  ShowProg := False;  

  case Part of
    mdtHead,
    mdtEntity: begin  // ֻ����һ��
      FTotalSize := XMsg.GetMsgSize;
      FRecvCount := RecvCount;
      ShowProg := (XMsg.AttachSize = 0); // �л������߳�, ִ��һ��
    end;
    mdtAttachment: begin
      // �Ѿ�ȫ��������ϡ�
      // �ϵ㴫��ʱ����Ϊ����Ϣ������������ʾ�����ݳ���δ�� = ��������
      if (XMsg.Action in FILE_CHUNK_ACTIONS) then
      begin
        FRecvCount := XMsg.Offset + RecvCount;
        if (RecvCount = 0) and
           (FRecvCount + TInConnection(FConnection).FMaxChunkSize >= FTotalSize) then
          FRecvCount := FTotalSize;  // �������
      end else
      begin
        if (RecvCount = 0) then
          FRecvCount := FTotalSize
        else
          FRecvCount := RecvCount;
      end;
      // ������Ҫ�����ȴ�
      TSendThread(FConnection.SendThread).KeepWaiting;
      ShowProg := True; // �л������߳�
    end;
  end;

  if ShowProg then  // ��ʾ����
    inherited;
end;

procedure TRecvThread.Reset;
begin
  // ���ý���������
  if Assigned(FReceiver) then
    FReceiver.Reset;
end;

procedure TRecvThread.SetLocalPath(const Path: string);
begin
  // ���ñ����ļ��ı���·��
  if Assigned(FReceiver) then
    TClientReceiver(FReceiver).LocalPath := Path;
end;

end.

