(*
 *  �������ݵ�ר�õ�Ԫ
 *
 *  C/S��WebSocket ģʽ���ݽ�����
 *)
unit iocp_receivers;

interface

{$I in_iocp.inc}        // ģʽ����

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes, System.SysUtils, {$ELSE}
  Windows, Classes, SysUtils, {$ENDIF}
  iocp_base, iocp_md5, iocp_mmHash,
  iocp_msgPacks, iocp_WsJSON;

type

  // ============ ���ݽ����� ���� =============

  TBaseReceiver = class(TObject)
  protected
    FBuffer: PAnsiChar;         // �����ڴ��
    FBufSize: Cardinal;         // δ��������ݳ���

    FRecvCount: TFileSize;      // ÿ��Ϣ�յ����ֽ���
    FCancel: Boolean;           // ȡ��������������WS��
    FCheckPassed: Boolean;      // У��ɹ���������WS��
    FCompleted: Boolean;        // �����ȫ���������
    FErrorCode: Integer;        // �쳣����
    procedure IncBufferPos(Offset: Cardinal); {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure InterInit(ACancel, ACompleted: Boolean); {$IFDEF USE_INLINE} inline; {$ENDIF}
    procedure SetCompleted(const Value: Boolean); 
  public
    constructor Create;
    procedure Clear; virtual;
    procedure Prepare(const AData: PAnsiChar; const ASize: Cardinal); virtual; abstract;
    procedure Receive(const AData: PAnsiChar; const ASize: Cardinal); virtual; abstract;
    procedure Reset; virtual;   // ����
  public
    property CheckPassed: Boolean read FCheckPassed;
    property Completed: Boolean read FCompleted write SetCompleted;
    property ErrorCode: Integer read FErrorCode;
    property RecvCount: TFileSize read FRecvCount;
  end;

  // ============ C/S ģʽ���ݽ����� ���� =============

  TCSBaseReceiver = class(TBaseReceiver)
  private
    FMsgPack: TReceivePack;     // ��ǰ���յ���Ϣ
    FCheckCode: TIOCPHashCode;  // ����У����
    FCheckCode2: TIOCPHashCode; // ����У����
    FMainLackSize: Cardinal;    // ����Ƿȱ�����ݳ���
    FAttachLackSize: TFilesize; // ����Ƿȱ�����ݳ���
    FReadHead: Boolean;         // �Ѿ���ȡЭ��ͷ��Ϣ
    procedure ExtractMessage;
    procedure VerifyMainStream;
    procedure VerifyAttachmentStream;
    procedure UZipPretreatMainStream;
    procedure UZipTreatAttachmentStream;
  protected
    procedure IncRecvCount(RecvCount, DataType: Cardinal); virtual; 
    procedure RecvSubqueueData; virtual;
    procedure ReceiveMainFinish; virtual;
    procedure ReceiveAttachmentFinish; virtual;
    procedure WriteMainStream(ByteCount: Cardinal); virtual;
    procedure WriteAttachmentStream(ByteCount: Cardinal); virtual;
  protected
    procedure CreateAttachment; virtual; abstract;
    procedure GetCheckCodes; virtual; abstract;
  public
    procedure Clear; override;
    procedure Reset; override;
    procedure OwnerClear;
  public
    property Cancel: Boolean read FCancel;
    property MsgPack: TReceivePack read FMsgPack;
  end;       

  // ============ ��������ݽ����� �� =============
  // ����򸽼����ݽ������ -> ����Ӧ�ò�

  TServerReceiver = class(TCSBaseReceiver)
  protected
    procedure IncRecvCount(RecvCount, DataType: Cardinal); override;
  protected
    procedure CreateAttachment; override;
    procedure GetCheckCodes; override;
  public
    constructor Create(AMsgPack: TReceivePack);
    procedure Prepare(const AData: PAnsiChar; const ASize: Cardinal); override;
    procedure Receive(const AData: PAnsiChar; const ASize: Cardinal); override;
  end;

  // ============ �ͻ������ݽ����� �� =============
  // ����ͬʱ�յ�������Ϣ��������Ϣ��һ����Ϣ����������Ͷ�ŵ�Ӧ�ò㣬
  // ���ݰ�����������Ϣʱ������Э��ͷ��У���뱻�۶ϡ�

  // Э��ͷ�ռ�
  TMsgHeadBuffers = array[0..IOCP_SOCKET_SIZE - 1] of AnsiChar;

  // ������Ϣ�¼�
  TRecvMsgEvent = procedure(Msg: TBasePackObject; Part: TMessagePart;
                            RecvCount: Cardinal) of object;

  // �ύ��Ϣ�¼�
  TPostMsgEvent = procedure(Msg: TBasePackObject) of object;

  // �½���Ϣ�¼�
  TCreateMsgEvent = procedure(Msg: TBasePackObject) of object;

  // �����쳣�¼�
  TRecvErrorEvent = procedure(Msg: TBasePackObject; ErrorCode: Integer) of object;

  TClientReceiver = class(TCSBaseReceiver)
  private
    // ���۶ϵ�Э��ͷ
    FHeadBuffers: TMsgHeadBuffers;
    FHeadLackSize: Cardinal;  // Э���ȱ�����ݳ���

    FHashCode: PAnsiChar;     // ��дУ�����ַ
    FCodeLackSize: Cardinal;  // У�����ȱ�ٳ���
    FLocalPath: string;       // �������·��

    FOnError: TRecvErrorEvent;  // �쳣�¼�
    FOnNewMsg: TCreateMsgEvent; // ����Ϣ�����¼�
    FOnPost: TPostMsgEvent;     // �ύ��Ϣ�¼�
    FOnReceive: TRecvMsgEvent;  // ������Ϣ�¼�

    procedure ScanRecvBuffers;
    procedure WriteHashCode(ByteCount: Cardinal);
  protected
    procedure IncRecvCount(RecvCount, DataType: Cardinal); override;
    procedure ReceiveMainFinish; override;
    procedure ReceiveAttachmentFinish; override;
    procedure WriteAttachmentStream(ByteCount: Cardinal); override;
  protected
    procedure CreateAttachment; override;
    procedure GetCheckCodes; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure PostMessage;
    procedure Prepare(const AData: PAnsiChar; const ASize: Cardinal); override;
    procedure Receive(const AData: PAnsiChar; const ASize: Cardinal); override;
  public
    property Completed: Boolean read FCompleted;
    property LocalPath: String read FLocalPath write FLocalPath;

    property OnError: TRecvErrorEvent read FOnError write FOnError;
    property OnNewMsg: TCreateMsgEvent read FOnNewMsg write FOnNewMsg;
    property OnPost: TPostMsgEvent read FOnPost write FOnPost;
    property OnReceive: TRecvMsgEvent read FOnReceive write FOnReceive;
  end;

  // ============ WebSocket ���ݽ����� =============

{ byte: 0               1               2               3
   bit: 7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0 7 6 5 4 3 2 1 0
       +-+-+-+-+-------+-+-------------+-------------------------------+
       |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
       |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
       |N|V|V|V|       |S|             |   (if payload len==126/127)   |
       | |1|2|3|       |K|             |                               |
       +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
       |     Extended payload length continued, if payload len == 127  |
       + - - - - - - - - - - - - - - - +-------------------------------+
       |                               |Masking-key, if MASK set to 1  |
       +-------------------------------+-------------------------------+
       | Masking-key (continued)       |          Payload Data...      |
       +-------------------------------- - - - - - - - - - - - - - - - + }

  // ע��WebSocket ֧�ֶ�֡������֡�Ѿ�֧�ִ����ݴ��䣬
  //    ����֡���ݣ���ÿ֡��Сʱ�����ӽ���ĸ����ԣ���������Ƚ����á�
  // һ�������ж�֡ʱ��������ֻ���յ�֡���ͻ���ȫ�����մ���

  TWSBaseReceiver = class(TBaseReceiver)
  private
    FOwner: TObject;           // ������Socket�����ӣ�

    FHeader: TWebSocketFrame;  // �۶ϵ�Э��ͷ
    FHeadAddr: PAnsiChar;      // д�� FFrameHeader ��λ��
    FLackSize: Cardinal;       // ֡���ݲ���ĳ���

    FData: PAnsiChar;          // ���ݿ�ʼλ��
    FFrameSize: UInt64;        // ��ǰ֡���ݴ�С
    FFrameRecvSize: UInt64;    // ��ǰ֡�ۼ��յ�����

    FLastFrame: Boolean;       // ���һ֡
    FOpCode: TWSOpCode;        // ��������
    FMsgType: TWSMsgType;      // ��ǰ���ڴ�����Ϣ����

    FMask: TWSMask;            // ����
    FMaskBit: PByte;           // ����ָʾλ��
    FMaskExists: Boolean;      // �з�����

    FJSON: TBaseJSON;          // JSON���ͻ���Ϊ TJSONResult
    FStream: TMemoryStream;    // ԭʼ/JSON ������

    function  CheckInIOCPFlag(ABuf: PAnsiChar; ASize: Integer): TWSMsgType; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function  GetContentSize(InSize: Cardinal): Integer; {$IFDEF USE_INLINE} inline; {$ENDIF}
    function  GetFrameSize(Byte2: Byte): Cardinal; {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure ExtractFrame(ABuf: PAnsiChar; ASize: Integer; RecvData: Boolean);
    procedure IncRecvCount(RecvCount: Cardinal); {$IFDEF USE_INLINE} inline; {$ENDIF}

    procedure ScanRecvWSBuffers;
  protected
    procedure InitResources(ASize: Cardinal); virtual; abstract;
    procedure InterReceiveData(ASize: Cardinal); virtual; abstract;
    procedure SaveRemainData; virtual; abstract;
    procedure WriteStream(ASize: Cardinal); virtual;abstract;
  public
    constructor Create(AConnection: TObject; AJSON: TBaseJSON);
    destructor Destroy; override;
    procedure Clear; override;
    procedure Prepare(const AData: PAnsiChar; const ASize: Cardinal); override;
  public
    property JSON: TBaseJSON read FJSON;
    property OpCode: TWSOpCode read FOpCode;
  end;

  // ============ WebSocket ��������ݽ����� =============

  // ����չ����Ϣ�����浽������

  TWSServerReceiver = class(TWSBaseReceiver)
  private
    procedure UnMarkData(ASize: Cardinal);
  protected
    procedure InitResources(ASize: Cardinal); override;
    procedure InterReceiveData(ASize: Cardinal); override;
    procedure SaveRemainData; override;
    procedure WriteStream(ASize: Cardinal); override;
  public
    procedure ClearMask(var Data: PAnsiChar; Overlapped: POverlapped);
    procedure Receive(const AData: PAnsiChar; const ASize: Cardinal); override;
  end;

  // ============ WebSocket �ͻ������ݽ����� =============

  // ׼�����ո����¼�
  TAttachmentEvent = procedure(Msg: TBaseJSON) of object;

  // �������չ����Ϣ��������

  TWSClientReceiver = class(TWSBaseReceiver)
  private
    FOnError: TRecvErrorEvent;  // �쳣�¼�
    FOnNewMsg: TCreateMsgEvent; // ����Ϣ�����¼�
    FOnPost: TPostMsgEvent;     // �ύ��Ϣ�¼�
    FOnReceive: TRecvMsgEvent;  // ������Ϣ�¼�
    FOnAttachment: TAttachmentEvent; // �����¼�
    procedure PostJSON(AOpCode: TWSOpCode; AMsgType: TWSMsgType; AStream: TMemoryStream);
  protected
    procedure InitResources(ASize: Cardinal); override;
    procedure InterReceiveData(ASize: Cardinal); override;
    procedure SaveRemainData; override;
    procedure WriteStream(ASize: Cardinal); override;
  public
    destructor Destroy; override;
    procedure Receive(const AData: PAnsiChar; const ASize: Cardinal); override;
  public
    property OnAttachment: TAttachmentEvent read FOnAttachment write FOnAttachment;
    property OnError: TRecvErrorEvent read FOnError write FOnError;
    property OnNewMsg: TCreateMsgEvent read FOnNewMsg write FOnNewMsg;
    property OnPost: TPostMsgEvent read FOnPost write FOnPost;
    property OnReceive: TRecvMsgEvent read FOnReceive write FOnReceive;
  end;

implementation

uses
  iocp_zlib, iocp_utils, iocp_sockets,
  iocp_clientBase, iocp_clients, iocp_wsClients;

type
  TIOCPDocumentRef = class(TIOCPDocument);
  TResultParamsRef = class(TResultParams);
  TServerWebSocket = class(TWebSocket);
  TJSONResultRef   = class(TJSONResult);
  
{ TBaseReceiver }

procedure TBaseReceiver.Clear;
begin
  InterInit(False, True);
end;

constructor TBaseReceiver.Create;
begin
  inherited;
  FCheckPassed := True;
  FCompleted := True;
end;

procedure TBaseReceiver.IncBufferPos(Offset: Cardinal);
begin
  Inc(FBuffer, Offset);  // �ڴ��ַǰ��
  Dec(FBufSize, Offset); // δ��������ݼ���
  Inc(FRecvCount, Offset);  // ����+
end;

procedure TBaseReceiver.InterInit(ACancel, ACompleted: Boolean);
begin
  FCancel := ACancel;
  FCheckPassed := True;
  FCompleted := ACompleted;
  FErrorCode := 0;
end;

procedure TBaseReceiver.Reset;
begin
  InterInit(True, True);
end;

procedure TBaseReceiver.SetCompleted(const Value: Boolean);
begin
  InterInit(False, Value);
end;

{ TCSBaseReceiver }

procedure TCSBaseReceiver.Clear;
begin
  inherited;
  FMsgPack.Clear;
end;

procedure TCSBaseReceiver.ExtractMessage;
begin
  // ��ȡһ����Ϣ
  //   ReadHead: ҪȡЭ����Ϣ
  //       ��ʽ��IOCP_SOCKET_FLAG + TMsgHead + [Hash + Hash] + [Data]
  // ������Ϣ���ܴ�������������Ϣ�ĸ������ڴ����ݰ�

  // 1. ȡЭ����Ϣ
  if FReadHead then  // ȡЭ����Ϣ
  begin
    FMsgPack.SetHeadMsg(PMsgHead(FBuffer + IOCP_SOCKET_FLEN));
    IncBufferPos(IOCP_SOCKET_SIZE);  // �� Hash λ��
    FReadHead := False;
  end;

  // 1.1 ȡ���ȣ���ǰ
  FCompleted := False;  // δ���
  FMainLackSize := FMsgPack.DataSize;
  FAttachLackSize := FMsgPack.AttachSize;

  if (FBufSize = 0) then  // ֻ��Э��ͷ
    IncRecvCount(0, 1)
  else  // 1.2 ȡУ����
    case FMsgPack.CheckType of
      ctMurmurHash:
        GetCheckCodes;
      ctMD5:
        GetCheckCodes;
    end;

  // 2. ������������
  if (FMainLackSize = 0) then
    ReceiveMainFinish   // �������
  else begin
    // ׼���ռ�
    FMsgPack.Main.Initialize(FMainLackSize);
    if (FBufSize > 0) then  // ������
      if (FBufSize > FMainLackSize) then // �ж����Ϣ������˲�����֣�
        WriteMainStream(FMainLackSize)
      else
        WriteMainStream(FBufSize);
  end;

end;

procedure TCSBaseReceiver.IncRecvCount(RecvCount, DataType: Cardinal);
begin
  // �յ�һ�����ݣ�����ͳ������
  IncBufferPos(RecvCount);  // �ƽ�
  case DataType of // Ƿȱ����-
    1: Dec(FMainLackSize, RecvCount);
    2: Dec(FAttachLackSize, RecvCount);
  end;
end;

procedure TCSBaseReceiver.OwnerClear;
begin
  // ��� FMsgObj ����
  if (FMainLackSize = 0) and (FAttachLackSize = 0) then
    FMsgPack.Clear;
end;

procedure TCSBaseReceiver.ReceiveAttachmentFinish;
begin
  // �������ݽ������
  // 1. У������
  if (FMsgPack.CheckType > ctNone) then
    VerifyAttachmentStream
  else  // ����У��
    FCheckPassed := True;
  // 2. ��ѹ��������������������
  if FCheckPassed and Assigned(FMsgPack.Attachment) then
    UZipTreatAttachmentStream;   // �������
end;

procedure TCSBaseReceiver.ReceiveMainFinish;
begin
  // �������ݽ�����ϣ�����ֻ��Э��ͷ��
  // 1. У�����壻 2. ��ѹ������������ 3. ����д����

  if (FMsgPack.DataSize = 0) then
    FCheckPassed := True
  else begin
    // 1. У������
    if (FMsgPack.CheckType > ctNone) then
      VerifyMainStream
    else  // ����У��
      FCheckPassed := True;

    // 2. ��ѹ����������������
    if FCheckPassed then
    begin
      UZipPretreatMainStream;  // ��ѹԤ����
      if (FMsgPack.VarCount > 0) then  // ��������
        FMsgPack.Initialize(FMsgPack.Main);
    end;
  end;

  // 3. ����������д����
  if FCheckPassed and (FMsgPack.AttachSize > 0) then
  begin
    CreateAttachment;  // ����˲��Զ���������
    if (FBufSize > 0) and Assigned(FMsgPack.Attachment) then // дʣ������
      if (FBufSize <= FMsgPack.AttachSize) then
        WriteAttachmentStream(FBufSize)
      else
        WriteAttachmentStream(FMsgPack.AttachSize);
  end;

end;

procedure TCSBaseReceiver.RecvSubqueueData;
begin
  // ���պ�������

  // 1. д������
  if (FMainLackSize > 0) then
    if (FBufSize <= FMainLackSize) then   // 1.1 δ�������
      WriteMainStream(FBufSize)
    else  // 1.2 ̫����ֻд���岿��
      WriteMainStream(FMainLackSize);

  // 2. д������
  if (FBufSize > 0) and (FAttachLackSize > 0) then
    if (FBufSize <= FAttachLackSize) then // 2.1 ����δ����
      WriteAttachmentStream(FBufSize)
    else  // 2.2 ̫����ֻд��������
      WriteAttachmentStream(FAttachLackSize);

  // ���� FBufSize > 0
end;

procedure TCSBaseReceiver.Reset;
begin
  inherited;
  // ȡ�������ý�����
  FMsgPack.Cancel;
  FMainLackSize := 0;
  FAttachLackSize := 0;
end;

procedure TCSBaseReceiver.UZipTreatAttachmentStream;
var
  OldFileName, RealFileName: String;
  mStream: TIOCPDocument;
begin
  // ��ѹ��������
  
  // 1. �ļ�δѹ�� -> ��Ϊԭ��������ʧ�ܣ�
  // 2. ��ѹ������ѹ�����ļ� -> ��Ϊԭ��

  // TIOCPDocument �ļ������رգ������ͷţ�����ʹ�� TIOCPDocument.FileName

  // �������������δ��ȫ������ϣ�ֻ�򵥹رգ�
  if (FMsgPack.Action in FILE_CHUNK_ACTIONS) and
     (FMsgPack.OffsetEnd + 1 < FMsgPack.Attachment.OriginSize) then
  begin
    FMsgPack.Attachment.Close; // ֻ�رգ�OriginSize ����
    Exit;
  end;

  OldFileName := FMsgPack.Attachment.FileName;
  RealFileName := ExtractFilePath(OldFileName) + FMsgPack.FileName;

  if (FMsgPack.ZipLevel = zcNone) then
  begin
    // ֱ�ӹرա�����
    FMsgPack.Attachment.Close;
    TIOCPDocumentRef(FMsgPack.Attachment).RenameDoc(RealFileName);
  end else
  begin
    // �Ƚ�ѹ�������ļ����ٸ���
    mStream := TIOCPDocument.Create(OldFileName + '_UNZIP', True);
    try
      try
        FMsgPack.Attachment.Position := 0;
        iocp_zlib.ZDecompressStream(FMsgPack.Attachment, mStream);
      finally
        FMsgPack.Attachment.Close(True); // �رգ�ͬʱɾ���ļ�
        TIOCPDocumentRef(mStream).RenameDoc(RealFileName);  // �Զ��ر�, ����
        TIOCPDocumentRef(FMsgPack.Attachment).FFileName := RealFileName; // ֱ�Ӹ���
        mStream.Free;  // �ͷ�
      end;
    except
      FErrorCode := GetLastError;
    end;
  end;

end;

procedure TCSBaseReceiver.UZipPretreatMainStream;
var
  NewBuffers: Pointer;
  NewSize: Integer;
begin
  // ��ѹ��Ԥ����������
  //   ���ݱ���ѹ�� NewBuffers��NewBuffers �ҵ� FMsgObj.Main ��
  if (FMsgPack.ZipLevel = zcNone) then
    FMsgPack.Main.Position := 0
  else
    try
      try
        iocp_zlib.ZDecompress(FMsgPack.Main.Memory, FMsgPack.DataSize,
                              NewBuffers, NewSize, FMsgPack.DataSize);
      finally
        FMsgPack.Main.SetMemory(NewBuffers, NewSize);
      end;
    except
      FErrorCode := GetLastError;
    end;
end;

procedure TCSBaseReceiver.VerifyAttachmentStream;
begin
  // ��鸽��У����
  case FMsgPack.CheckType of
    ctMurmurHash:  // MurmurHash
      if (FMsgPack.Action in FILE_CHUNK_ACTIONS) then  // ���һ�η�Χ�� Hash
        FCheckPassed := (FCheckCode2.MurmurHash =
                         iocp_mmHash.MurmurHashPart64(FMsgPack.Attachment.Handle,
                                                      FMsgPack.Offset, FMsgPack.AttachSize))
      else  // ��������ļ��� Hash
        FCheckPassed := (FCheckCode2.MurmurHash =
                         iocp_mmHash.MurmurHash64(FMsgPack.Attachment.Handle));
    ctMD5:  // MD5
      if (FMsgPack.Action in FILE_CHUNK_ACTIONS) then // ���һ�η�Χ�� MD5
        FCheckPassed := MD5MatchEx(@FCheckCode2.MD5Code,
                                   iocp_md5.MD5Part(FMsgPack.Attachment.Handle,
                                                    FMsgPack.Offset, FMsgPack.AttachSize))
      else  // ��������ļ��� MD5
        FCheckPassed := MD5MatchEx(@FCheckCode2.MD5Code,
                                   iocp_md5.MD5File(FMsgPack.Attachment.Handle));
    else
      FCheckPassed := True;
  end;
end;

procedure TCSBaseReceiver.VerifyMainStream;
begin
  // �������У����
  case FMsgPack.CheckType of
    ctMurmurHash:  // MurmurHash
      FCheckPassed := (FCheckCode.MurmurHash =
                         iocp_mmHash.MurmurHash64(FMsgPack.Main.Memory, FMsgPack.DataSize));
    ctMD5:  // MD5
      FCheckPassed := MD5MatchEx(@FCheckCode.MD5Code,
                        iocp_md5.MD5Buffer(FMsgPack.Main.Memory, FMsgPack.DataSize));
    else
      FCheckPassed := True;
  end;   
end;

procedure TCSBaseReceiver.WriteAttachmentStream(ByteCount: Cardinal);
begin
  // д���ݵ�����
  if Assigned(FMsgPack.Attachment) then
  begin
    FMsgPack.Attachment.Write(FBuffer^, ByteCount);
    IncRecvCount(ByteCount, 2); 
    if FCompleted then  // ������� -> У�顢��ѹ
      ReceiveAttachmentFinish;
  end else
    IncRecvCount(ByteCount, 2);
end;

procedure TCSBaseReceiver.WriteMainStream(ByteCount: Cardinal);
begin
  // д���ݵ����壨��д�룬���ƽ���
  FMsgPack.Main.Write(FBuffer^, ByteCount);
  IncRecvCount(ByteCount, 1);  // �ƽ�
  if (FMainLackSize = 0) then  // ���
    ReceiveMainFinish;
end;

{ TServerReceiver }

constructor TServerReceiver.Create(AMsgPack: TReceivePack);
begin
  inherited Create;
  FMsgPack := AMsgPack;
end;

procedure TServerReceiver.CreateAttachment;
begin
  // ��Ӧ�ò㽨����
end;

procedure TServerReceiver.GetCheckCodes;
begin
  // ȡУ���룺
  //   ��ʽ��IOCP_HEAD_FLAG + TMsgHead + [У���� + У����] + [��������]
  //     ����TBaseMessage.GetCheckCode
  case FMsgPack.CheckType of
    ctMurmurHash: begin  // MurmurHash=64λ
      if (FMsgPack.DataSize > 0) then   // ����У����
      begin
        FCheckCode.MurmurHash := PMurmurHash(FBuffer)^;
        IncBufferPos(HASH_CODE_SIZE);
      end;
      if (FMsgPack.AttachSize > 0) then // ����У����
      begin
        FCheckCode2.MurmurHash := PMurmurHash(FBuffer)^;
        IncBufferPos(HASH_CODE_SIZE);
      end;
    end;
    ctMD5: begin  // MD5=128λ
      if (FMsgPack.DataSize > 0) then   // ����У����
      begin
        FCheckCode.MD5Code := PMD5Digest(FBuffer)^;
        IncBufferPos(HASH_CODE_SIZE * 2);
      end;
      if (FMsgPack.AttachSize > 0) then // ����У����
      begin
        FCheckCode2.MD5Code := PMD5Digest(FBuffer)^;
        IncBufferPos(HASH_CODE_SIZE * 2);
      end;
    end;
  end;
end;

procedure TServerReceiver.IncRecvCount(RecvCount, DataType: Cardinal);
begin
  inherited;
  // ������� �� ������� ������Ӧ�ò�
  case DataType of
    1: FCompleted := (FMainLackSize = 0);
    2: FCompleted := (FAttachLackSize = 0);
  end;
end;

procedure TServerReceiver.Prepare(const AData: PAnsiChar; const ASize: Cardinal);
begin
  // ���������ݰ���׼����Դ
  //   ֻ��һ�����壬�������ݲ��ڵ�ǰ���ݰ�!
  FBuffer := AData;
  FBufSize := ASize;

  FCancel := False;
  FReadHead := False; // ����ǰ�Ѷ�ȡЭ����Ϣ
  IncBufferPos(IOCP_SOCKET_SIZE);  // �������ݴ�

  ExtractMessage;  // ��ȡ��Ϣ
end;

procedure TServerReceiver.Receive(const AData: PAnsiChar; const ASize: Cardinal);
begin
  // ���պ�������
  //  �ͻ��˷��͸���ʱҪ��������͸������ݲ������һ��
  FBuffer := AData;
  FBufSize := ASize;
  if (ASize = IOCP_CANCEL_LENGTH) and MatchSocketType(FBuffer, IOCP_SOCKET_CANCEL) then
    Reset
  else
    RecvSubqueueData;
end;

{ TClientReceiver }

constructor TClientReceiver.Create;
begin
  inherited;
  FMsgPack := TResultParams.Create;  // �Ƚ�һ��
end;

procedure TClientReceiver.CreateAttachment;
begin
  // �Զ���������
  TResultParamsRef(FMsgPack).CreateAttachment(FLocalPath);
end;

destructor TClientReceiver.Destroy;
begin
  if Assigned(FMsgPack) then
    FMsgPack.Free;
  inherited;
end;

procedure TClientReceiver.GetCheckCodes;
  procedure WriteMurmurHash(Hash: PIOCPHashCode);
  begin
    if (FBufSize >= HASH_CODE_SIZE) then  // ���ݹ���
    begin
      Hash^.MurmurHash := PMurmurHash(FBuffer)^;
      IncBufferPos(HASH_CODE_SIZE);
    end else
    begin
      // ���ݲ����������۶ϣ�
      FCodeLackSize := HASH_CODE_SIZE; // �����ֽ���
      FHashCode := @Hash^.MurmurHash;  // ����дУ����ĵ�ַ
      if (FBufSize > 0) then
        WriteHashCode(FBufSize);
    end;
  end;
  procedure WriteMD5(MD5: PIOCPHashCode);
  begin
    if (FBufSize >= HASH_CODE_SIZE * 2) then // ���ݹ���
    begin
      MD5^.MD5Code := PMD5Digest(FBuffer)^;
      IncBufferPos(HASH_CODE_SIZE * 2);
    end else
    begin
      // ���ݲ����������۶ϣ�
      FCodeLackSize := HASH_CODE_SIZE * 2;
      FHashCode := @MD5^.MD5Code;
      if (FBufSize > 0) then
        WriteHashCode(FBufSize);
    end;
  end;
begin
  // ȡУ���룺
  //   ����������Ϣ�͹㲥��Ϣ������У���뱻�۶�
  if (FBufSize > 0) then
    case FMsgPack.CheckType of
      ctMurmurHash: begin  // MurmurHash=64λ
        if (FMsgPack.DataSize > 0) then    // ����У����
          WriteMurmurHash(@FCheckCode);
        if (FBufSize > 0) and (FMsgPack.AttachSize > 0) then  // ����У����
          WriteMurmurHash(@FCheckCode2);
      end;
      ctMD5: begin  // MD5=128λ
        if (FMsgPack.DataSize > 0) then    // ����У����
          WriteMD5(@FCheckCode);
        if (FBufSize > 0) and (FMsgPack.AttachSize > 0) then  // ����У����
          WriteMD5(@FCheckCode2);
      end;
    end;
end;

procedure TClientReceiver.IncRecvCount(RecvCount, DataType: Cardinal);
begin
  inherited;
  // ���������ӣ�����+����ȫ������� -> Ӧ�ò�
  FCompleted := (FMainLackSize = 0) and (FAttachLackSize = 0);
end;

procedure TClientReceiver.PostMessage;
begin
  // ����Ϣ����Ͷ���߳�
  try
    FOnPost(FMsgPack);
  finally
    FReadHead := True;  // Ҫ���¶�Э��ͷ��
    FRecvCount := 0;    // ���ճ�������
    FMsgPack := TResultParams.Create; // ��������
    if Assigned(FOnNewMsg) then
      FOnNewMsg(FMsgPack);  // ����Ϣ�¼�
  end;
end;

procedure TClientReceiver.Prepare(const AData: PAnsiChar; const ASize: Cardinal);
begin
  FBuffer := AData;
  FBufSize := ASize;

  FCancel := False;
  FHeadLackSize := 0;  // Э��ͷδ�۶�
  FHashCode := nil;    // У����δ�۶�
  FReadHead := True;   // ȡЭ����Ϣ���

  ScanRecvBuffers;     // ɨ����ȡ��Ϣ
end;

procedure TClientReceiver.Receive(const AData: PAnsiChar; const ASize: Cardinal);
begin
  // ���պ������ݣ����浽��
  //   ����ͬʱ��������͸������ݣ�Ҳ���ܰ���������Ϣ
  FBuffer := AData;
  FBufSize := ASize;

  // 1. ���������Ϣ���۶�
  //    1.1 Э��ͷ���۶ϣ�1.2 У���뱻�۶�

  if (FHeadLackSize > 0) then  // 1.1 Э��ͷ���۶�
  begin
    if (FBufSize >= FHeadLackSize) then
    begin
      // ���ݹ�����׼��Э��ͷ��Ϣ
      System.Move(AData^, FHeadBuffers[IOCP_SOCKET_SIZE - FHeadLackSize], FHeadLackSize);

      FMsgPack.SetHeadMsg(PMsgHead(@FHeadBuffers[IOCP_SOCKET_FLEN]));
      IncBufferPos(FHeadLackSize);  // �� Hash λ��

      FReadHead := False;  // �����ٴζ�Э��ͷ
      FHeadLackSize := 0;

      ScanRecvBuffers;  // ɨ�衢��ȡ��Ϣ
    end else
    begin
      // ���ݲ�����
      System.Move(AData^, FHeadBuffers[IOCP_SOCKET_SIZE - FHeadLackSize], FBufSize);
      Dec(FHeadLackSize, FBufSize);  // �ȼ�
      IncBufferPos(FBufSize); // �ƽ� -> FBufSize = 0
    end;
  end else
  if Assigned(FHashCode) then  // 1.2 У���뱻�۶�
  begin
    if (FBufSize >= FCodeLackSize) then
      WriteHashCode(FCodeLackSize)
    else
      WriteHashCode(FBufSize);
  end;

  // 2. Э��ͷ + У���봦�����
  if (FHeadLackSize = 0) and (FHashCode = nil) then
  begin
    // 2.1 ���պ�̻򸽼�����
    if (FBufSize > 0) then
      RecvSubqueueData;
    // 2.2 ������ȡ��Ϣ
    if (FBufSize > 0) then
      ScanRecvBuffers;
  end;
end;

procedure TClientReceiver.ReceiveAttachmentFinish;
begin
  inherited;
  try
    if (FCheckPassed = False) and Assigned(FOnError) then
      FOnError(FMsgPack, ERR_CHECK_CODE) // У���쳣 -> ���
    else
    if Assigned(FOnReceive) then  // ���ý����¼�
      FOnReceive(FMsgPack, mdtAttachment, 0); // 0 ��ʾ����
  finally
    PostMessage;  // ȫ��������ϣ�Ͷ��
  end;
end;

procedure TClientReceiver.ReceiveMainFinish;
begin
  inherited;
  // �������������ݡ����ͱ�����ŵ��� FOnReceive
  try
    if (FCheckPassed = False) and Assigned(FOnError) then
      FOnError(FMsgPack, ERR_CHECK_CODE)  // У���쳣 -> ���
    else
    if Assigned(FOnReceive) then  // ���ý����¼�
      FOnReceive(FMsgPack, mdtEntity, FRecvCount);
  finally
    if (FCheckPassed = False) or (FMsgPack.AttachSize = 0) then
      PostMessage;  // ����������ϣ�Ͷ��
  end;
end;

procedure TClientReceiver.ScanRecvBuffers;
begin
  // ���������ݰ���׼����Դ
  //   ��ʽ��IOCP_SOCKET_FLAG + TMsgHead + [Hash + Hash] + [Data]
  //   1. �ͻ��˿����ж����Ϣ���������ģ���Ҫ�ֽ⣡
  //   2. ����Ϣʱ��Э��ͷ���ܱ��۶�

  // �����ȡ��Ϣ
  while (FReadHead = False) and (FBufSize > 0) or (FBufSize >= IOCP_SOCKET_SIZE) do
    ExtractMessage; 

  // ����ʣ�࣬ӦС�� IOCP_SOCKET_SIZE
  if (FBufSize > 0) then
  begin
    // ʣ�೤�� < Э��ͷ����, ���۶ϣ�
    // ����ʣ�����ݵ� FHeadBuffers���´�ƴ������
    FCompleted := False;
    FHeadLackSize := IOCP_SOCKET_SIZE - FBufSize;  // ȱ���ֽ���
    System.Move(FBuffer^, FHeadBuffers[0], FBufSize);
    IncBufferPos(FBufSize);
  end;
end;

procedure TClientReceiver.WriteAttachmentStream(ByteCount: Cardinal);
begin
  // ByteCount����ǰ�յ��ֽ���
  if Assigned(FOnReceive) then  // ���ý����¼�
    FOnReceive(FMsgPack, mdtAttachment, FRecvCount);
  inherited;  // ���ܽ�����ϣ������� POST    
end;

procedure TClientReceiver.WriteHashCode(ByteCount: Cardinal);
begin
  // У���뱻�۶ϣ��ȱ����յ��Ĳ���
  System.Move(FBuffer^, FHashCode^, ByteCount);
  IncBufferPos(ByteCount);     // �ƽ�
  Inc(FHashCode, ByteCount);   // �ƽ����´�д��λ��
  Dec(FCodeLackSize, ByteCount);  // �����ֽ���-
  if (FCodeLackSize = 0) then  // д��У����
    FHashCode := nil;
end;

{ TWSBaseReceiver }

function TWSBaseReceiver.CheckInIOCPFlag(ABuf: PAnsiChar; ASize: Integer): TWSMsgType;
begin
  // �����չ�� INIOCP_JSON_FLAG
  if (ABuf = nil) then
    Result := mtDefault
  else
  if (ASize >= INIOCP_JSON_FLAG_LEN) and
     (PInIOCPJSONField(ABuf)^ = INIOCP_JSON_FLAG) then
    Result := mtJSON
  else
    Result := mtDefault;
end;

procedure TWSBaseReceiver.Clear;
begin
  // ����յ�����Ϣ 
  FData := nil;
  FFrameSize := 0;
  FFrameRecvSize := 0;
  if Assigned(FStream) and (FStream.Size > 0) then
    FStream.Clear;
  inherited;
end;

constructor TWSBaseReceiver.Create(AConnection: TObject; AJSON: TBaseJSON);
begin
  inherited Create;
  FOwner := AConnection;
  FJSON := AJSON;
end;

destructor TWSBaseReceiver.Destroy;
begin
  Clear;
  if Assigned(FStream) then
    FStream.Free;
  inherited;
end;

procedure TWSBaseReceiver.ExtractFrame(ABuf: PAnsiChar; ASize: Integer; RecvData: Boolean);
var
  i: Integer;
  iByte: Byte;
  OffSet: Integer;

  procedure _MovePos(Step: Integer);
  begin
    Inc(ABuf, Step);
    Dec(ASize, Step);  // ���� < 0
    Inc(OffSet, Step);
  end;

begin
  // ��֡�ṹȡ��Ϣ
  // �������֡�������Ȳ��� ASize >= 2

  OffSet := 0;
  FFrameRecvSize := 0;  // ��ǰ֡������=0

  // 1. �� 1 �ֽ�

  // �Ƿ�Ϊĩ֡
  iByte := PByte(ABuf)^;
  FLastFrame := (iByte shr 7 > 0);

  // ��������������λ RSV1��RSV2��RSV3

  // ȡ��������
  iByte := (iByte and $0F);
  if (TWSOpCode(iByte) in TWSOpCodeSet) then
    FOpCode := TWSOpCode(iByte)
  else
    FOpCode := ocClose;  // �����쳣���رգ�

  // 2. �� 2 �ֽ�
  _MovePos(1);

  // ����λ��
  FMaskBit := PByte(ABuf);
  iByte := PByte(ABuf)^;

  // �Ƿ�����룺��λ���ͻ�����
  FMaskExists := (iByte shr 7 > 0);

  // ֡���ȣ���7λ
  FFrameSize := (iByte and $7F);

  // 3. ȡ֡����
  _MovePos(1);     // ���� 3 �ֽ�

  case FFrameSize of
    126: begin     // <= max(UInt16)��ǰ2�ֽ� -> ����
      FFrameSize := 0;
      if (ASize >= 2) then
      begin
        TByteAry(@FFrameSize)[1] := TByteAry(ABuf)[0];
        TByteAry(@FFrameSize)[0] := TByteAry(ABuf)[1];
      end;
      _MovePos(2); // ����
    end;
    127: begin     // <= max(UInt64)����ǰ8�ֽ� -> ����
      FFrameSize := 0;
      if (ASize >= 8) then
        for i := 0 to 7 do
          TByteAry(@FFrameSize)[7 - i] := TByteAry(ABuf)[i];
      _MovePos(8); // ����
    end;
  end;

  // 4. ȡ���루��4�ֽڣ��ͻ����ޣ�
  if FMaskExists then  // �����
  begin
    if (ASize >= 4) then
      FMask := PWSMask(ABuf)^;
    _MovePos(4);   // ����
  end;

  // 5. ��������
  //    ASize = 0 -> �����ս���
  //    ASize > 0 -> ���������
  if RecvData and (ASize >= 0) then
  begin
    IncBufferPos(OffSet);  // �ƶ� FBuffer
    InterReceiveData(ASize);  // ��������
  end;

end;

function TWSBaseReceiver.GetContentSize(InSize: Cardinal): Integer;
begin
  // �ж�Ҫд�����ĳ���
  if (InSize = 0) then
    Result := 0
  else
  if (FFrameRecvSize + InSize <= FFrameSize) then
    Result := InSize
  else
    Result := FFrameSize - FFrameRecvSize;
end;

function TWSBaseReceiver.GetFrameSize(Byte2: Byte): Cardinal;
begin
  // ���֡�����ĳ���
  //   �ͻ��ˣ�Close/Ping/Pong ������ 2 �ֽڣ���Сֵ��
  case (Byte2 and $7F) of
    126: Result := 4;
    127: Result := 10;
    else Result := 2;
  end;
end;

procedure TWSBaseReceiver.IncRecvCount(RecvCount: Cardinal);
begin
  Inc(FFrameRecvSize, RecvCount);  // ���ճ���+
  FCompleted := FLastFrame and (FFrameRecvSize = FFrameSize);  // �Ƿ�������
end;

procedure TWSBaseReceiver.Prepare(const AData: PAnsiChar; const ASize: Cardinal);
begin
  FBuffer := AData;
  FBufSize := ASize;
  ScanRecvWSBuffers;  // ɨ�����
end;

procedure TWSBaseReceiver.ScanRecvWSBuffers;
begin
  // ���������ݰ�
  //   1. ���տ�ʱ�����ж����Ϣ��Ҫ�ֽ⣡
  //   2. ����Ϣʱ��Э��ͷ���ܱ��۶�

  if Assigned(FHeadAddr) then   // ��ƴ������ȡ֡��Ϣ
  begin
    ExtractFrame(@FHeader[0], FHeadAddr - PAnsiChar(@FHeader[0]), False);  // ���ݸչ���
    InterReceiveData(FBufSize); // ����ǰ֡���ݣ��Զ�ȡ GetContentSize(FBufSize)
    FHeadAddr := nil;
  end;
     
  while (FBufSize >= 2) and (FBufSize >= GetFrameSize(Byte((FBuffer + 1)^))) do
    ExtractFrame(FBuffer, FBufSize, True);

  if (FBufSize > 0) then  // ����һ��Ϣ������
    SaveRemainData;
end;

{ TWSServerReceiver }

procedure TWSServerReceiver.ClearMask(var Data: PAnsiChar; Overlapped: POverlapped);
var
  i: Integer;
  Buf: PAnsiChar;
begin
  // �޸���Ϣ���Ա㷢�ظ��ͻ��˻�㲥
  //  �������ָʾ�����룬����ǰ��
  if FMaskExists and Assigned(FMaskBit) then
  begin
    FData := Data; // Data �� TWSData.Data
    Buf := PAnsiChar(FData - 4);
    for i := 1 to FFrameRecvSize do
    begin
      Buf^ := FData^;
      Inc(Buf); Inc(FData);
    end;

    // ��������־
    FMaskBit^ := FMaskBit^ and Byte($7F);
    FMaskBit := nil;

    Dec(Overlapped^.InternalHigh, 4);
    Dec(Data, 4);    
  end;
end;

procedure TWSServerReceiver.InitResources(ASize: Cardinal);
begin
  // ��ʼ����Դ��
  //  JSON ��־�������������� Socket ����

  FData := FBuffer;  // ���ݿ�ʼλ��
  if (FOpCode = ocText) then  // ��� JSON ��־������TBaseJSON.SaveToStream
    FMsgType := CheckInIOCPFlag(FBuffer, ASize);

  case FMsgType of
    mtDefault:      // ����������
      TServerWebSocket(FOwner).SetProps(FOpCode, mtDefault, Pointer(FData),
                                        FFrameSize, ASize);

    mtJSON: begin   // JSON ��Ϣ
      if (Assigned(FStream) = False) then
        FStream := TMemoryStream.Create;
      FStream.Size := FFrameSize; // �к���֡ʱд��ʱ�Զ�����
      TServerWebSocket(FOwner).SetProps(FOpCode, mtJSON,
                                        Pointer(FData), 0, 0);
    end;
    
    mtAttachment:
      TServerWebSocket(FOwner).SetProps(FOpCode, mtAttachment,
                                        Pointer(FData), 0, 0);
  end;
end;

procedure TWSServerReceiver.InterReceiveData(ASize: Cardinal);
var
  RecvCount: Cardinal;
begin
  // ׼����������
  RecvCount := GetContentSize(ASize);  // ȡ��Ч����
  try
    // ������ -> ����
    if (RecvCount > 0) then
      UnMarkData(RecvCount);
    // ׼����Դ
    InitResources(RecvCount);
    // ���浽��
    if (RecvCount > 0) then
      WriteStream(RecvCount);
  finally
    // ����ƽ�
    if (RecvCount > 0) then
      IncBufferPos(RecvCount);
  end;
end;

procedure TWSServerReceiver.Receive(const AData: PAnsiChar; const ASize: Cardinal);
var
  RecvCount: Integer;
begin
  // ���պ�������

  FBuffer := AData;
  FBufSize := ASize;
  FData := FBuffer;  // ���ݿ�ʼλ��

  // 1. ����ǰ֡�Ľ���
  if (FFrameRecvSize < FFrameSize) then  // FLackSize > 0 ʱ  FFrameSize = 0
  begin
    RecvCount := GetContentSize(FBufSize);
    UnMarkData(RecvCount);   // ���루����ˣ�
    WriteStream(RecvCount);  // ���浽��
    IncBufferPos(RecvCount); // ǰ��
  end;

  // 2. ʣ�����������һ��Ϣ��
  if (FBufSize > 0) then
    SaveRemainData;
    
end;

procedure TWSServerReceiver.SaveRemainData;
begin
  // ����ʣ�����ݣ��´ν��գ�������
  // �ͻ��˷������ʱ��΢ͣ�٣�������ʣ��
end;

procedure TWSServerReceiver.UnMarkData(ASize: Cardinal);
var
  i: Integer;
  p: PByte;
begin
  // ������ -> xor ����
  if (ASize > 0) and FMaskExists then
  begin
    p := PByte(FBuffer);
    for i := FFrameRecvSize to FFrameRecvSize + ASize - 1 do
    begin
      p^ := p^ xor FMask[i mod 4];
      Inc(p);
    end;
  end;
end;

procedure TWSServerReceiver.WriteStream(ASize: Cardinal);
begin
  // �������ݵ���

  // ������+
  IncRecvCount(ASize);

  // 1. д������
  case FMsgType of
    mtDefault:     // ���� mtDefault ����Ϣ����
      Inc(TServerWebSocket(FOwner).FMsgSize, ASize);
    mtJSON:        // ��չ�� JSON ��Ϣ
      FStream.Write(FBuffer^, ASize);
    mtAttachment:  // ������
      if Assigned(FJSON.Attachment) then
        FJSON.Attachment.Write(FBuffer^, ASize);
  end;

  // 2. �������
  if FCompleted then
    case FMsgType of
      mtJSON: begin  // JSON ��Ϣ
        FJSON.Initialize(FStream, True);  // ת�� JSON, ͬʱ��� FStream
        if FJSON.HasAttachment then // ������
          FMsgType := mtAttachment  // �´�Ϊ������
        else
          FMsgType := mtDefault;
      end;
      mtAttachment:  // ������
        FMsgType := mtDefault;  // �´�Ϊ mtDefault
    end;
    
end;     

{ TWSClientReceiver }

destructor TWSClientReceiver.Destroy;
begin
  if Assigned(FJSON) then
    FJSON.Free;
  inherited;
end;

procedure TWSClientReceiver.InitResources(ASize: Cardinal);
begin
  // ׼��������
  //   JSON������չ�����ݾ����浽������
  if (Assigned(FStream) = False) then
    FStream := TMemoryStream.Create;
end;

procedure TWSClientReceiver.InterReceiveData(ASize: Cardinal);
var
  RecvCount: Cardinal;          
begin
  // ׼����������
  RecvCount := GetContentSize(ASize);  // ȡ��Ч����
  try
    // ׼����Դ
    InitResources(RecvCount);
    // ���浽��
    WriteStream(RecvCount);
  finally
    // ����ƽ�
    if (RecvCount > 0) then
      IncBufferPos(RecvCount);
  end;
end;

procedure TWSClientReceiver.PostJSON(AOpCode: TWSOpCode;
  AMsgType: TWSMsgType; AStream: TMemoryStream);
begin
  // Ͷ�� JSON ��Ϣ
  with TJSONResultRef(FJSON) do
  begin
    FOpCode := AOpCode;
    FMsgType := AMsgType;
    FStream := AStream;
  end;
  try
    FOnPost(FJSON);  // Ͷ�� FJSON
  finally
    FJSON := TJSONResult.Create(FOwner);  // �½�
    if Assigned(AStream) then  // Stream �Ѿ�Ͷ��
      FStream := TMemoryStream.Create;  // �½�
    if Assigned(FOnNewMsg) then
      FOnNewMsg(FJSON);  // ����Ϣ�¼�
  end;
end;

procedure TWSClientReceiver.Receive(const AData: PAnsiChar; const ASize: Cardinal);
var
  RecvCount: Integer;
begin
  // ���պ�������

  FBuffer := AData;
  FBufSize := ASize;

  // 1. ����ǰ֡�Ľ���
  if (FFrameRecvSize < FFrameSize) then  // FLackSize > 0 ʱ  FFrameSize = 0
  begin
    RecvCount := GetContentSize(FBufSize);
    WriteStream(RecvCount);  // ���浽��
    IncBufferPos(RecvCount); // ǰ��
  end;

  // 2. ����ʣ������

  // 2.1 ����֡�����۶�����
  // ���⣺�ͻ��˽��յ�������Ϣʱ��֡�����ᱻ�۶Ϸֿ�

  if (FBufSize > 0) and (FLackSize > 0) then
  begin
    if (FLackSize = 9) then  // ת�壬��֡�ĵڶ��ֽ�
    begin
      FHeader[1] := FBuffer^;
      FLackSize := GetFrameSize(Byte(FHeader[1])) - 2;  // ��ȡ
      IncBufferPos(1);
    end;

    // ���� ocClose��ocPing��ocPong -> RecvCount = 0
    if (FBufSize < FLackSize) then
      RecvCount := FBufSize
    else
      RecvCount := FLackSize;

    if (RecvCount > 0) then
    begin
      System.Move(FBuffer^, FHeadAddr^, RecvCount);
      IncBufferPos(RecvCount);
      Inc(FHeadAddr, RecvCount);
      Dec(FLackSize, RecvCount);
    end;
  end;

  // 3. ֡����������������ȡ����
  if (FLackSize = 0) then
    ScanRecvWSBuffers;

end;

procedure TWSClientReceiver.SaveRemainData;
var
  i: Integer;
begin
  // ������������ 2 �ֽڣ�ocClose��ocPing��ocPong��
  // ����ʱ�������ݵ� FHeader���´�ƴ��

  if (FBufSize = 1) then
  begin
    FHeader[0] := FBuffer^;
    FHeadAddr := @FHeader[2];  // ��3�ֽ�λ�ã��� TWSClientReceiver.Receive
    FLackSize := 9;  // ת�壬 �ٵڶ��ֽ�
  end else
  begin
    for i := 0 to FBufSize - 1 do
      FHeader[i] := (FBuffer + i)^;
    // ����ĳ���
    FLackSize := GetFrameSize(Byte(FHeader[1])) - FBufSize;
    if (FLackSize > 0) then
      FHeadAddr := @FHeader[FBufSize]
    else begin  // ֡������������ȡ��Ϣ
      ExtractFrame(PAnsiChar(@FHeader[0]), FBufSize, False);
      FCompleted := FFrameSize = 0;  // ocClose��ocPing�� ocPong
    end;
  end;

  if (FLackSize > 0) then
  begin
    FFrameSize := 0;
    FFrameRecvSize := 0;
    FCompleted := False;
  end;

  FBufSize := 0;
    
end;

procedure TWSClientReceiver.WriteStream(ASize: Cardinal);
begin
  // 1. ������+
  IncRecvCount(ASize);

  // 2. ���浽����FMsgTypeδ֪��
  if (ASize > 0) then
    if Assigned(FJSON.Attachment) then  // ����
    begin
      FJSON.Attachment.Write(FBuffer^, ASize);
      FOnReceive(FJSON, mdtAttachment, ASize);  // �����Ľ��ս���
    end else // �ı���Ϣ��δ֪��InIOCP-JSON��
      FStream.Write(FBuffer^, ASize);

  // 5. �������
  if FCompleted then
  begin
    // ����
    FFrameSize := 0;
    FFrameRecvSize := 0;

    // �����������
    if (FMsgType <> mtAttachment) then    
      FMsgType := CheckInIOCPFlag(PAnsiChar(FStream.Memory), FStream.Size);

    case FMsgType of
      mtDefault:
        if (FOpCode <= ocClose) then
          PostJSON(FOpCode, mtDefault, FStream);  // ͬʱͶ�� FStream

      mtJSON: begin
        FJSON.Initialize(FStream, True);  // ת�� JSON, ͬʱ��� FStream
        if FJSON.HasAttachment then  // ͬ��
        begin
          FMsgType := mtAttachment;  // �´�Ϊ������
          if Assigned(FOnAttachment) then
            FOnAttachment(FJSON);    // �������ж��Ƿ�����ļ���
        end else  // ֱ��Ͷ��
        begin
          FMsgType := mtDefault;  // �´�Ϊ mtDefault
          PostJSON(FOpCode, mtJSON, nil);
        end;
      end;

      mtAttachment: begin
        FMsgType := mtDefault;   // �´�Ϊ mtDefault
        if Assigned(FJSON.Attachment) then
          FJSON.Attachment.Position := 0;
        PostJSON(FOpCode, mtAttachment, nil);  // Ͷ�Ÿ���
      end;
    end;

  end;

end;

end.

