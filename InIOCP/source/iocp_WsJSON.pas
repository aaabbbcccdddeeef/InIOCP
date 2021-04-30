(*
 * iocp WebSocket ������Ϣ JSON ��װ��Ԫ
 *)
unit iocp_WsJSON;

interface

{$I in_iocp.inc}

uses
  {$IFDEF DELPHI_XE7UP}
  Winapi.Windows, System.Classes,
  System.SysUtils, System.Variants, Data.DB, {$ELSE}
  Windows, Classes, SysUtils, Variants, DB, {$ENDIF}
  iocp_base, iocp_senders, iocp_msgPacks;

type

  // ˵�������Ǽ򵥵� JSON ��װ��ֻ֧�ֵ���¼��

  TCustomJSON = class(TBasePack)
  private
    FText: AnsiString;         // JSON �ı�  
    function GetAsRecord(const Index: String): TCustomJSON;
    function GetJSONText: AnsiString;
    procedure SetAsRecord(const Index: String; const Value: TCustomJSON);
    procedure SetJSONText(const Value: AnsiString);
    procedure WriteToBuffers(var JSON: AnsiString; WriteExtra: Boolean);
  protected
    // ������ƵĺϷ���
    procedure CheckFieldName(const Value: AnsiString); override;
    // ˢ�� FText
    procedure InterRefresh; override;  
    // ����������ڴ���
    procedure SaveToMemStream(Stream: TMemoryStream; WriteExtra: Boolean); override;
    // ɨ���ڴ�飬��������
    procedure ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal; ReadExtra: Boolean); override;
    // д�����ֶ�
    procedure WriteSystemInfo(var Buffer: PAnsiChar); virtual;
  public
    procedure Clear; override;
  public
    property B[const Name: String]: Boolean read GetAsBoolean write SetAsBoolean;
    property D[const Name: String]: TDateTime read GetAsDateTime write SetAsDateTime;
    property F[const Name: String]: Double read GetAsFloat write SetAsFloat;
    property I[const Name: String]: Integer read GetAsInteger write SetAsInteger;
    property I64[const Name: String]: Int64 read GetAsInt64 write SetAsInt64;
    property R[const Name: String]: TCustomJSON read GetAsRecord write SetAsRecord;  // ��¼
    property S[const Name: String]: String read GetAsString write SetAsString;
    property V[const Name: String]: Variant read GetAsVariant write SetAsVariant;  // �䳤
    property Text: AnsiString read GetJSONText write SetJSONText;  // ��Ϊ��д 
  end;

  TBaseJSON = class(TCustomJSON)
  protected
    FAttachment: TStream;      // ������
    FMsgId: Int64;             // ��ϢId    
  private
    function GetAction: Integer;
    function GetHasAttachment: Boolean;
    procedure SetAction(const Value: Integer);
    procedure SetAttachment(const Value: TStream);
  protected
    // ɨ���ڴ�飬��������
    procedure ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal; ReadExtra: Boolean); override;
    // д�����ֶ�
    procedure WriteSystemInfo(var Buffer: PAnsiChar); override;
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
    procedure Close; virtual;
  public
    // Ԥ������
    property Action: Integer read GetAction write SetAction;
    property Attachment: TStream read FAttachment write SetAttachment;
    property HasAttachment: Boolean read GetHasAttachment;
    property MsgId: Int64 read FMsgId;
  end;

  // �����õ� JSON ��Ϣ
  
  TSendJSON = class(TBaseJSON)
  protected
    FDataSet: TDataSet;        // Ҫ���͵����ݼ�����������
    FFrameSize: Int64;         // ֡����
    FServerMode: Boolean;      // �����ʹ��
  private
    procedure InterSendDataSet(ASender: TBaseTaskSender);
    procedure SetDataSet(Value: TDataset);
  protected
    procedure InternalSend(ASender: TBaseTaskSender; AMasking: Boolean);
  protected
    property DataSet: TDataSet read FDataSet write SetDataSet;  // ����˹���
  public
    procedure Close; override;
  end;

implementation

uses
  iocp_Winsock2, iocp_lists, http_utils, iocp_utils;
  
{ TCustomJSON }

procedure TCustomJSON.CheckFieldName(const Value: AnsiString);
var
  i: Integer;
begin
  inherited;
  for i := 1 to Length(Value) do
    if (Value[i] in ['''', '"', ':', ',', '{', '}']) then
      raise Exception.Create('�������Ʋ��Ϸ�.');
end;

procedure TCustomJSON.Clear;
begin
  inherited;
  FText := '';    
end;

function TCustomJSON.GetAsRecord(const Index: String): TCustomJSON;
var
  Stream: TStream;
begin
  // ��תΪ������תΪ TCustomJSON
  Stream := GetAsStream(Index);
  if Assigned(Stream) then
    try
      Result := TCustomJSON.Create;
      Result.Initialize(Stream);
    finally
      Stream.Free;
    end
  else
    Result := nil;
end;

function TCustomJSON.GetJSONText: AnsiString;
begin
  if (FList.Count = 0) then
    Result := '[]'
  else begin
    if (FText = '') then
      WriteToBuffers(FText, True);
    Result := FText;
  end;
end;

procedure TCustomJSON.InterRefresh;
begin
  // ���ݸı䣬ɾ�� FText
  if (FText <> '') then
    FText := '';
end;

procedure TCustomJSON.SaveToMemStream(Stream: TMemoryStream; WriteExtra: Boolean);
var
  JSON: AnsiString;
begin
  // д����
  WriteToBuffers(JSON, WriteExtra);
  Stream.Write(JSON[1], Length(JSON));
end;

procedure TCustomJSON.ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal; ReadExtra: Boolean);
  procedure ExtractStream(var Stream: TMemoryStream;
                          var p: PAnsiChar; iLen: Integer);
  begin
    // ��ȡ���ݵ���
    // ע��Stream.Position := 0;
    Stream := TMemoryStream.Create;
    Stream.Size := iLen;
    Inc(p, 2);
    System.Move(p^, Stream.Memory^, iLen);
    Inc(p, iLen);
  end;
  procedure GetFieldData(var p: PAnsiChar; var DataType: TElementType;
                         var Str: AnsiString; var Stream: TMemoryStream;
                         var VarValue: Variant);
  var
    pa: PAnsiChar;
    Len: Integer;    
  begin
    // ��ȡ�������������ֶ����ݣ���ʽ��
    //   {"Length":5,"Data":"abcde"}
    pa := nil;
    Len := 0;
    Inc(p, 8);  // �� : ǰλ�ø���

    repeat
      case p^ of
        ':':
          if (Len = 0) then  // ����λ��
            pa := p + 1
          else  // ����λ��
            if CompareBuffer(p - 9, ',"Stream":"') then  // Stream
            begin
              DataType := etStream;
              ExtractStream(Stream, p, Len);
            end else
            if CompareBuffer(p - 9, ',"Record":"') then  // JSON ��¼
            begin
              DataType := etRecord;
              ExtractStream(Stream, p, Len);
            end else
            if CompareBuffer(p - 9, ',"String":"') then  // �ַ���
            begin
              DataType := etString;
              Inc(p, 2);
              SetString(Str, p, Len);
              Inc(p, Len);
            end else
            begin  // ',"Variant":"' -- Variant ����
              DataType := etVariant;
              Inc(p, 2);
              VarValue := BufferToVariant(p, Len, True);  // �Զ���ѹ
              Inc(p, Len);
            end;

        ',': begin  // ȡ����
          SetString(Str, pa, p - pa);
          Len := StrToInt(Str);
          Inc(p, 8);
        end;
      end;

      Inc(p);
    until (p^ = '}');
  end;
  procedure AddJSONField(const AName: String; AValue: AnsiString; StringType: Boolean);
  begin
    // ����һ������/�ֶ�
    if StringType then // DateTime �� String ��ʾ
      SetAsString(AName, AValue)
    else
    if (AValue = 'True') then
      SetAsBoolean(AName, True)
    else
    if (AValue = 'False') then
      SetAsBoolean(AName, False)
    else
    if (AValue = 'Null') or (AValue = '""') or (AValue = '') then
      SetAsString(AName, '')
    else
    if (Pos('.', AValue) > 0) then  // ��ͨ����
      SetAsFloat(AName, StrToFloat(AValue))
    else
    if (Length(AValue) < 10) then  // 2147 4836 47
      SetAsInteger(AName, StrToInt(AValue))
    else
    if (AValue[1] in ['0'..'9', '-', '+']) then
      SetAsInt64(AName, StrToInt64(AValue));
  end;

var
  Level: Integer;          // ���Ų��
  DblQuo: Boolean;         // ˫����
  WaitVal: Boolean;        // �ȴ��ֶ�ֵ

  p, pEnd: PAnsiChar;
  pD, pD2: PAnsiChar;

  DataType: TElementType;  // ��������
  FldName: AnsiString;     // �ֶ�����

  FldValue: AnsiString;    // String �ֶ�ֵ
  VarValue: Variant;       // Variant �ֶ�ֵ
  Stream: TMemoryStream;   // Stream �ֶ�ֵ
  JSONRec: TCustomJSON;    // ��¼�ֶ�ֵ
begin
  // ɨ��һ���ڴ棬������ JSON �ֶΡ��ֶ�ֵ
  // ��ȫ��ֵתΪ�ַ�������֧�����飬�����쳣��

  // ɨ�跶Χ
  p := ABuffer;
  pEnd := PAnsiChar(p + ASize);

  // ���ݿ�ʼ������λ��
  pD := nil;
  pD2 := nil;

  Level   := 0;      // ���
  DblQuo  := False;
  WaitVal := False;  // �ȴ��ֶ�ֵ

  // ��������ȡ�ֶΡ�ֵ

  repeat

(*  {"Id":123,"Name":"��","Boolean":True,"Stream":Null,
     "_Variant":{"Length":5,"Data":"aaaa"},"_zzz":2345}  *)

    case p^ of  // ���������˫���ź������ƻ����ݵ�һ����
      '{':
        if (DblQuo = False) then  // ������
        begin
          Inc(Level);
          if (Level > 1) then  // �ڲ㣬��� Variant ����
          begin
            DblQuo := False;
            WaitVal := False;

            // �����ڲ������
            GetFieldData(p, DataType, FldValue, Stream, VarValue);

            case DataType of
              etString:
                SetAsString(FldName, FldValue);
              etStream:       // ������
                SetAsStream(FldName, Stream);
              etRecord: begin // ��¼����
                JSONRec := TCustomJSON.Create;
                JSONRec.Initialize(Stream);
                SetAsRecord(FldName, JSONRec);
              end;
              etVariant:      // Variant
                SetAsVariant(FldName, VarValue);
            end;

            Dec(Level);  // �����
          end;
        end;

      '"':  // ��㣺Level = 1
        if (DblQuo = False) then
          DblQuo := True
        else
        if ((p + 1)^ in [':', ',', '}']) then // ���Ž���
        begin
          DblQuo := False;
          pD2 := p;
        end;

      ':':  // ���,���ţ�"Name":��
        if (DblQuo = False) and (Level = 1) then
        begin
          WaitVal := True;
          SetString(FldName, pD, pD2 - pD);
          FldName := TrimRight(FldName);
          pD := nil;
          pD2 := nil;
        end;

      ',', '}':  // ֵ������xx,"  xx","  xx},"
        if (p^ = '}') or (p^ = ',') and ((p + 1)^ = '"') then
          if (DblQuo = False) and WaitVal then  // Length(FldName) > 0
          begin
            if (pD2 = nil) then  // ǰ��û������
            begin
              SetString(FldValue, pD, p - pD);
              AddJSONField(FldName, Trim(FldValue), False);
            end else
            begin
              SetString(FldValue, pD, pD2 - pD);
              AddJSONField(FldName, FldValue, True);  // ��Ҫ Trim(FldValue)
            end;
            pD := nil;
            pD2 := nil;
            WaitVal := False;
          end;

      else
        if (DblQuo or WaitVal) and (pD = nil) then  // ���ơ����ݿ�ʼ
          pD := p;
    end;

    Inc(p);

  until (p > pEnd);

end;

procedure TCustomJSON.SetAsRecord(const Index: String; const Value: TCustomJSON);
var
  Variable: TListVariable;
begin
  Variable.Data := Value;
  SetField(etRecord, Index, @Variable);
end;

procedure TCustomJSON.SetJSONText(const Value: AnsiString);
begin
  // �� JSON �ı���ʼ��������
  Clear;
  if (Value <> '') then
    ScanBuffers(PAnsiChar(Value), Length(Value), False);
end;

procedure TCustomJSON.WriteSystemInfo(var Buffer: PAnsiChar);
begin
  // Empty
end;

procedure TCustomJSON.WriteToBuffers(var JSON: AnsiString; WriteExtra: Boolean);
const
  BOOL_VALUES: array[Boolean] of AnsiString = ('False', 'True');
  FIELD_TYPES: array[etString..etVariant] of AnsiString = (
               ',"String":"', ',"Record":"', ',"Stream":"', ',"Variant":"');
  function SetFieldNameLength(var Addr: PAnsiChar; AName: AnsiString;
                              ASize: Integer; AType: TElementType): Integer;
  var
    S: AnsiString;
  begin
    // д���ֶγ�������
    // ���ܺ������������볤����Ϣ�����������������޷�ʶ��
    // ��ʽ��"VarName":{"Length":1234,"String":"???"}
    S := '"' + AName + '":{"Length":' + IntToStr(ASize) + FIELD_TYPES[AType];
    Result := Length(S);
    System.Move(S[1], Addr^, Result);
    Inc(Addr, Result);
  end;
var
  i: Integer;
  p: PAnsiChar;
begin
  // ������Ϣ�� JSON �ı�����֧�����飩

  // 1. JSON ���� = ÿ�ֶζ༸���ַ������� +
  //                INIOCP_JSON_HEADER + JSON_CHARSET_UTF8 + MsgOwner
  SetLength(JSON, Integer(FSize) + FList.Count * 25 + 80);
  p := PAnsiChar(JSON);

  // 2. д��־���ֶ�
  WriteSystemInfo(p);

  // 3. �����б��ֶ�
  for i := 0 to FList.Count - 1 do
    with Fields[i] do
      case VarType of
        etNull:
          VarToJSON(p, Name, 'Null', True, False, i = FList.Count - 1);
        etBoolean:
          VarToJSON(p, Name, BOOL_VALUES[AsBoolean], True, False, i = FList.Count - 1);
        etCardinal..etInt64:
          VarToJSON(p, Name, AsString, True, False, i = FList.Count - 1);
        etDateTime:  // �����ַ���
          VarToJSON(p, Name, AsString, False, False, i = FList.Count - 1);

        etString, etRecord,
        etStream, etVariant: begin  // ��������δ��

          // �����ֶ����ơ�����
          SetFieldNameLength(p, Name, Size, VarType);

          if (Size > 0) then  // ��������: "����"
            case VarType of
              etString: begin
                System.Move(AsString[1], p^, Size);  // ��������
                Inc(p, Size);  // ǰ��
              end;
              etRecord, etStream: begin  // ֱ������д�룬���ٸ��ƴ���
                TStream(DataRef).Position := 0;
                TStream(DataRef).Read(p^, Size);
                Inc(p, Size);  // ǰ��
              end;
              etVariant: begin  // ��������
                System.Move(DataRef^, p^, Size);
                Inc(p, Size);  // ǰ��
              end;
            end;

          if (i = FList.Count - 1) then
            PThrChars(p)^ := AnsiString('"}}')
          else
            PThrChars(p)^ := AnsiString('"},');

          Inc(p, 3);
        end;
      end;

  // 4. ɾ������ռ�
  Delete(JSON, p - PAnsiChar(JSON) + 1, Length(JSON));

end;

{ TBaseJSON }

procedure TBaseJSON.Close;
begin
  // �رո�����
  if Assigned(FAttachment) then
  begin
    FAttachment.Free;
    FAttachment := nil;
  end;
end;

constructor TBaseJSON.Create(AOwner: TObject);
begin
  inherited Create;
  FOwner := UInt64(AOwner);
  FMsgId := GetUTCTickCount;
end;

destructor TBaseJSON.Destroy;
begin
  Close;
  inherited;  // �Զ� Clear;
end;

function TBaseJSON.GetAction: Integer;
begin
  Result := GetAsInteger('__action');  // ��������
end;

function TBaseJSON.GetHasAttachment: Boolean;
begin
  Result := GetAsBoolean('__has_attach');  // �Ƿ������
end;

procedure TBaseJSON.ScanBuffers(ABuffer: PAnsiChar; ASize: Cardinal; ReadExtra: Boolean);
begin
  inherited;
  // �޸���Ϣ��������д��
  FOwner := GetAsInt64('__MSG_OWNER');  
end;

procedure TBaseJSON.SetAction(const Value: Integer);
begin
  SetAsInteger('__action', Value);  // ��������
end;

procedure TBaseJSON.SetAttachment(const Value: TStream);
begin
  // ���ø���������һ�� __has_attach ����
  Close;  // �ͷ����е���
  FAttachment := Value;
  SetAsBoolean('__has_attach', Assigned(FAttachment) and (FAttachment.Size > 0));
end;

procedure TBaseJSON.WriteSystemInfo(var Buffer: PAnsiChar);
var
  S: AnsiString;
begin
  // д��ϵͳ��Ϣ�ֶΣ�InIOCP ��־����������д��
  //                   {"_InIOCP_Ver":2.8,"__MSG_OWNER":12345678,
  S := INIOCP_JSON_FLAG + '"__MSG_OWNER":' + IntToStr(UInt64(FOwner)) + ',';
  System.Move(S[1], Buffer^, Length(S));
  Inc(Buffer, Length(S));
end;

{ TSendJSON }

procedure TSendJSON.Close;
begin
  inherited;
  if Assigned(FDataSet) then
    FDataSet := nil;
end;

procedure TSendJSON.InternalSend(ASender: TBaseTaskSender; AMasking: Boolean);
var
  JSON: TMemoryStream;
begin
  // ��������

  if (FList.Count = 0) then
    Exit;

  // 1. �ֶ�����ת���� JSON ��
  JSON := TMemoryStream.Create;

  SaveToStream(JSON, True);  // �Զ����������

  FFrameSize := JSON.Size;

  // 2. ����
  ASender.Masking := AMasking;  // ��������
  ASender.OpCode := ocText;  // JSON �����ı������ܸ�

  ASender.Send(JSON, FFrameSize, True);  // �Զ��ͷ�

  // 3. ���͸����������������ݼ�
  if Assigned(FAttachment) then  // 3.1 ������
    try
      FFrameSize := FAttachment.Size;  // �ı�
      if (FFrameSize = 0) then
        FAttachment.Free   // ֱ���ͷ�
      else begin
        if (FServerMode = False) then
          Sleep(10);
        ASender.OpCode := ocBiary;  // ���� ���������ƣ����ܸ�
        ASender.Send(FAttachment, FFrameSize, True);  // �Զ��ͷ�
      end;
    finally
      FAttachment := nil;  // �Ѿ��ͷ�
    end
  else
    if Assigned(FDataSet) then  // 3.2 ���ݼ�
      try
        if (FServerMode = False) then
          Sleep(10);
        InterSendDataSet(ASender);
      finally
        FDataSet.Active := False;
        FDataSet := nil;
      end;

  // ����Ͷ��ʱ������˿��ܼ�����Ϣճ����һ��Win7 64 λ���׳��֣���
  // �½����쳣�������Ϣ������
  if (FServerMode = False) then
    Sleep(10);

end;

procedure TSendJSON.InterSendDataSet(ASender: TBaseTaskSender);
  procedure MarkFrameSize(AData: PWsaBuf; AFrameSize: Integer; ALastFrame: Byte);
  var
    pb: PByte;
  begin
    // ����ˣ����� WebSocket ֡��Ϣ
    //   ���� RSV1/RSV2/RSV3
    pb := PByte(AData^.buf);
    pb^ := ALastFrame + Byte(ocBiary);  // �к��֡����λ = 0��������
    Inc(pb);

    pb^ := 126;  // �� 126���ͻ��˴� 3��4�ֽ�ȡ����
    Inc(pb);

    TByteAry(pb)[0] := TByteAry(@AFrameSize)[1];
    TByteAry(pb)[1] := TByteAry(@AFrameSize)[0];

    // �������ݳ���
    AData^.len := AFrameSize + 4;
  end;

var
  XData: PWsaBuf;  // ���ռ�

  i, k, n, m, Idx: integer;
  EmptySize, Offset: Integer;
  p: PAnsiChar;

  Desc, JSON: AnsiString;
  Names: TStringAry;
  Field: TField;

begin
  // ���ٰ����ݼ�תΪ JSON������ Blob �ֶ����ݣ�
  // ע�⣺��������������ÿ�ֶγ��Ȳ��ܳ��� IO_BUFFER_SIZE

  if not DataSet.Active or DataSet.IsEmpty then
    Exit;

  Dataset.DisableControls;
  Dataset.First;

  try
    // 1. �ȱ����ֶ����������飨�ֶ������ִ�Сд��

    n := 5;  // ������¼�� JSON ���ȣ���ʼΪ Length('["},]')
    k := Dataset.FieldCount;

    SetLength(Names, k);
    for i := 0 to k - 1 do
    begin
      Field := Dataset.Fields[i];
      if (i = 0) then
      begin
        Desc := '{"' + LowerCase(Field.FieldName) + '":"';  // ��Сд
      end else
        Desc := '","' + LowerCase(Field.FieldName) + '":"';
      Names[i] := Desc;
      Inc(n, Length(Desc) + Field.Size + 10);
    end;

    // 2. ÿ����¼תΪ JSON��������ʱ����

    XData := ASender.Data;  // �����������ռ�

    // ���鿪ʼ��֡���� 4 �ֽ�
    (XData.buf + 4)^ := AnsiChar('[');

    EmptySize := IO_BUFFER_SIZE - 5;  // �ռ䳤��
    Offset := 5;  // д��λ��

    while not Dataset.Eof do
    begin
      SetLength(JSON, n);    // Ԥ���¼�ռ�
      p := PAnsiChar(JSON);
      Idx := 0;              // ���ݵ�ʵ�ʳ���

      // ��¼ -> JSON
      for i := 0 to k - 1 do
      begin
        Field := Dataset.Fields[i];
        if (i = k - 1) then  // [{"Id":"1","Name":"��"},{"Id":"2","Name":"��"}]
          Desc := Names[i] + Field.Text + '"}'
        else
          Desc := Names[i] + Field.Text;
        m := Length(Desc);
        System.Move(Desc[1], p^, m);
        Inc(p, m);
        Inc(Idx, m);
      end;


      Inc(Idx);  // ��¼��������� , �� ]
      Delete(JSON, Idx + 1, n - Idx);   // ɾ����������

      // �ռ䲻�� -> �ȷ�������д������
      if (Idx > EmptySize) then
      begin
        MarkFrameSize(XData, Offset - 4, 0);  // ����֡��Ϣ
        ASender.SendBuffers;  // ���̷��ͣ�

        EmptySize := IO_BUFFER_SIZE - 4; // ��ԭ
        Offset := 4;  // ��ԭ
      end;
      
      // ��һ����¼
      Dataset.Next;
      
      // ���� JSON���´���ʱ����
      if Dataset.Eof then
        JSON[Idx] := AnsiChar(']')  // ������
      else
        JSON[Idx] := AnsiChar(','); // δ����

      System.Move(JSON[1], (XData.buf + Offset)^, Idx);
      Dec(EmptySize, Idx); // �ռ�-
      Inc(Offset, Idx);    // λ��+      
      
    end;

    // �������һ֡
    if (Offset > 4) then
    begin
      MarkFrameSize(XData, Offset - 4, Byte($80));  // ����֡��Ϣ
      ASender.SendBuffers;  // ���̷��ͣ�
    end;

  finally
    Dataset.EnableControls;
  end;

end;

procedure TSendJSON.SetDataSet(Value: TDataset);
begin
  Close;  // �ر����и���
  FDataSet := Value;
  SetAsBoolean('__has_attach', Assigned(Value) and Value.Active and not Value.IsEmpty);
end;

end.
