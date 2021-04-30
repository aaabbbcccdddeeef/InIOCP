unit frmInIOCPDbSvrClientBackground;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, iocp_base, iocp_clients, iocp_msgPacks, StdCtrls, DB, DBClient,
  Grids, DBGrids, ExtCtrls, iocp_wsClients;

type
  TFormInIOCPDbSvrClientBg = class(TForm)
    Memo1: TMemo;
    InConnection1: TInConnection;
    InCertifyClient1: TInCertifyClient;
    btnLogin: TButton;
    edtLoginUser: TEdit;
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnLogout: TButton;
    btnDBUpdate: TButton;
    btnDBQuery2: TButton;
    btnDBQuery: TButton;
    DataSource1: TDataSource;
    ClientDataSet1: TClientDataSet;
    InDBConnection1: TInDBConnection;
    InDBQueryClient1: TInDBQueryClient;
    InDBSQLClient1: TInDBSQLClient;
    btnQueryDBConnections: TButton;
    btnSetDBConnection: TButton;
    DBGrid1: TDBGrid;
    ComboBox1: TComboBox;
    Image1: TImage;
    edtIP: TEdit;
    edtPort: TEdit;
    Button1: TButton;
    InWSConnection1: TInWSConnection;
    Button2: TButton;
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure btnLogoutClick(Sender: TObject);
    procedure btnQueryDBConnectionsClick(Sender: TObject);
    procedure btnSetDBConnectionClick(Sender: TObject);
    procedure InDBConnection1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure ComboBox1Change(Sender: TObject);
    procedure btnDBQueryClick(Sender: TObject);
    procedure btnDBUpdateClick(Sender: TObject);
    procedure InDBSQLClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InDBQueryClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure ClientDataSet1AfterScroll(DataSet: TDataSet);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure InConnection1ReceiveMsg(Sender: TObject; Message: TResultParams);
    procedure InConnection1ReturnResult(Sender: TObject; Result: TResultParams);
    procedure btnDBQuery2Click(Sender: TObject);
    procedure InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
    procedure InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
    procedure InWSConnection1Error(Sender: TObject; const Msg: string);
    procedure Button2Click(Sender: TObject);
    procedure InDBQueryClient1AfterLoadData(DataSet: TClientDataSet;
      const TableName: string);
  private
    { Private declarations }
    FUpdateTable: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPDbSvrClientBg: TFormInIOCPDbSvrClientBg;

implementation

uses
  MidasLib, jpeg, iocp_utils;
  
{$R *.dfm}

procedure TFormInIOCPDbSvrClientBg.Button1Click(Sender: TObject);
begin
//  InDBQueryClient1.LoadFromFile('data\background.dat');
end;

procedure TFormInIOCPDbSvrClientBg.Button2Click(Sender: TObject);
begin
  // WebSocket Э�����Զ�����ݱ�
  with InWSConnection1.JSON do
  begin
    Action := 990;

    SetRemoteTable(ClientDataSet1, FUpdateTable); // ����Ҫ���µ����ݱ�������Ѿ��رգ�

    // �� Variant ���ͣ��Զ�ѹ���������ȡ V['_delta'] ���£��Զ���ѹ
    V['_delta'] := ClientDataSet1.Delta;
    Post;
  end;
end;

procedure TFormInIOCPDbSvrClientBg.btnConnectClick(Sender: TObject);
begin
  InConnection1.ServerAddr := edtIP.Text;
  InConnection1.ServerPort := StrToInt(edtPort.Text);
  InConnection1.Active := True;

  InWSConnection1.ServerAddr := edtIP.Text;
  InWSConnection1.ServerPort := StrToInt(edtPort.Text);
  InWSConnection1.Active := True;
end;

procedure TFormInIOCPDbSvrClientBg.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
  InWSConnection1.Active := False;
end;

procedure TFormInIOCPDbSvrClientBg.btnLoginClick(Sender: TObject);
begin
  InCertifyClient1.UserName := edtLoginUser.Text;
  InCertifyClient1.Password := 'pppp';
  InCertifyClient1.Login;

  // WebSocket ��¼
  with InWSConnection1.JSON do
  begin
    Action := 1;
    S['_userName'] := 'user_aaa';
    Post;
  end;

end;

procedure TFormInIOCPDbSvrClientBg.btnLogoutClick(Sender: TObject);
begin
  InCertifyClient1.Logout;
  InWSConnection1.Active := False;  
end;

procedure TFormInIOCPDbSvrClientBg.btnQueryDBConnectionsClick(Sender: TObject);
begin
  // ��ѯ��ģ��(���ݿ���������ֻ��һ����ģʱĬ��ʹ�õ�һ��)
  InDBConnection1.GetConnections;
end;

procedure TFormInIOCPDbSvrClientBg.btnDBQuery2Click(Sender: TObject);
begin
  // �� WebSocket Э���ѯ���ݣ�������ú�ִ̨�У�
  // ����TFormInIOCPDBServerBGThread.InWebSocketManager1Receive
  with TJSONMessage.Create(InWSConnection1) do
  begin
    Action := 999;  // ����˺�ִ̨��
    S['MSG'] := '����˺�ִ̨��';
    Post;
  end;
end;

procedure TFormInIOCPDbSvrClientBg.btnDBQueryClick(Sender: TObject);
begin
  // ��ѯ���ݿ⣬�����ʹ�ú�ִ̨�У�����
  //  ��ģ��Ԫ TdmInIOCPTest.InIOCPDataModuleExecQuery
  //  �ͻ��� TFormInIOCPDbSvrClientBg.InConnection1ReceiveMsg
  with InDBQueryClient1 do
  begin
    // ִ�з��������Ϊ Select_tbl_xzqh �� SQL ����
    //   ��Ȼ����ֱ�Ӵ� SQL �������sql\TdmInIOCPTest.sql
    Params.SQLName := 'Select_tbl_xzqh';  // ���ִ�Сд������TInSQLManager.GetSQL
    ExecQuery;  // �°�ȡ������
  end;
end;

procedure TFormInIOCPDbSvrClientBg.btnDBUpdateClick(Sender: TObject);
begin
  // C/S Э�飺����Զ�����ݱ�
  InDBQueryClient1.ApplyUpdates;
end;

procedure TFormInIOCPDbSvrClientBg.btnSetDBConnectionClick(Sender: TObject);
begin
  // ���ӵ�ָ����ŵ����ݿ�����, ֻ��һ����ģʱ���Բ�������
  if ComboBox1.ItemIndex > -1 then
    InDBConnection1.Connect(ComboBox1.ItemIndex);
end;

procedure TFormInIOCPDbSvrClientBg.ClientDataSet1AfterScroll(DataSet: TDataSet);
var
  Field: TField;
  Stream: TMemoryStream;
  JpegPic: TJpegImage;
begin
  if ClientDataSet1.Active then
  begin
    Field := ClientDataSet1.FieldByName('picture');
    if Field.IsNull then
      Image1.Picture.Graphic := nil
    else begin
      Stream := TMemoryStream.Create;
      JpegPic := TJpegImage.Create;
      try
        TBlobField(Field).SaveToStream(Stream);
        Stream.Position := 0;           // ����
        JpegPic.LoadFromStream(Stream);
        Image1.Picture.Graphic := JpegPic;
      finally
        JpegPic.Free;
        Stream.Free;
      end;
    end;
  end;
end;

procedure TFormInIOCPDbSvrClientBg.ComboBox1Change(Sender: TObject);
begin
  if ComboBox1.ItemIndex > -1 then
    btnSetDBConnection.Enabled := True;
end;

procedure TFormInIOCPDbSvrClientBg.FormCreate(Sender: TObject);
begin
  edtIP.Text := '127.0.0.1';    // GetLocalIP();   
  MyCreateDir(InConnection1.LocalPath); // �����ļ����·��
end;

procedure TFormInIOCPDbSvrClientBg.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  case Action of
    atUserLogin:       // ��¼
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + '��¼�ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + '��¼ʧ��');
    atUserLogout:      // �ǳ�
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + '�ǳ��ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + '�ǳ�ʧ��');
  end;
end;

procedure TFormInIOCPDbSvrClientBg.InConnection1Error(Sender: TObject; const Msg: string);
begin
  Memo1.Lines.Add(Msg);
end;

procedure TFormInIOCPDbSvrClientBg.InConnection1ReceiveMsg(Sender: TObject;
  Message: TResultParams);
begin
  // �����ʹ�ú�̨�������ݲ�ѯ����ɺ��ѿͻ��ˣ�����
  //   ��ģ��Ԫ TdmInIOCPTest.InIOCPDataModuleExecQuery
  if (Message.AsString['data_file'] <> '') then  // ���������ļ�
    with TMessagePack.Create(InConnection1) do // �������¼������� InConnection1 
    begin
      LocalPath := 'temp';   // ��ŵ���ʱ·��
      FileName := Message.AsString['data_file'];  // �ļ���
      Post(atFileDownload);  // ����
    end;
end;

procedure TFormInIOCPDbSvrClientBg.InConnection1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ����TFormInIOCPDBServerBGThread.InFileManager1BeforeDownload
  if Result.Action = atFileDownload then  // �ɹ����ز�ѯ�������ʾ
    if Result.ActResult = arOK then
      InDBQueryClient1.LoadFromFile('temp\' + Result.FileName);  // װ��
end;

procedure TFormInIOCPDbSvrClientBg.InDBConnection1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.Action of
    atDBGetConns:        // ��ѯ����
      case Result.ActResult of
        arExists: begin  // �����ݿ�����
          ComboBox1.Items.DelimitedText := Result.AsString['dmCount'];
          Memo1.Lines.Add('���������� = ' + IntToStr(ComboBox1.Items.Count));
        end;
        arMissing:      // û��
          { empty } ;
      end;
    atDBConnect:        // ��������
      case Result.ActResult of
        arOK:
          Memo1.Lines.Add('�����������ӳɹ�.');
        arFail:
          Memo1.Lines.Add('������������ʧ�ܣ�');        
      end;
  end;

end;

procedure TFormInIOCPDbSvrClientBg.InDBQueryClient1AfterLoadData(
  DataSet: TClientDataSet; const TableName: string);
begin
  // �����Ѿ�װ�ص� DataSet�����ݼ��϶�Ӧ�ı�����Ϊ TableName
  // ���¼��� OnReturnResult ֮ǰִ��
end;

procedure TFormInIOCPDbSvrClientBg.InDBQueryClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ��ѯ�����·��ؽ��
  case Result.Action of
    atDBExecQuery,
    atDBExecStoredProc:
      if Result.ActResult = arOK then
      begin
        ClientDataSet1AfterScroll(nil);
        Memo1.Lines.Add('��ѯ/ִ�гɹ���');
      end else
        Memo1.Lines.Add('��ѯ/ִ��ʧ��:' + Result.Msg);
    atDBApplyUpdates:
      if Result.ActResult = arOK then
        Memo1.Lines.Add('Զ�̸��³ɹ�.')
      else
        Memo1.Lines.Add('Զ�̸���ʧ��:' + Result.Msg);
  end;
end;

procedure TFormInIOCPDbSvrClientBg.InDBSQLClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ִ�� SQL ���ؽ��
  case Result.Action of
    atDBExecSQL:
      case Result.ActResult of
        arOK:
          Memo1.Lines.Add('Զ�̸��³ɹ�.');
        arFail:
          Memo1.Lines.Add('Զ�̸���ʧ��:' + Result.Msg);
      end;
    atDBExecStoredProc:
      case Result.ActResult of
        arOK:
          Memo1.Lines.Add('ִ�д洢���̳ɹ�.');
        arFail:
          Memo1.Lines.Add('ִ�д洢����ʧ��:' + Result.Msg);
      end;
  end;
end;

procedure TFormInIOCPDbSvrClientBg.InWSConnection1Error(Sender: TObject;
  const Msg: string);
begin
  Memo1.Lines.Add(Msg);
end;

procedure TFormInIOCPDbSvrClientBg.InWSConnection1ReceiveMsg(Sender: TObject;
  Msg: TJSONResult);
begin
  // �յ�������Ϣ������TdmInIOCPTest.InIOCPDataModuleWebSocketQuery
  if Msg.MsgType = mtJSON then
    if (Msg.Action = 999) and (Msg.S['_dataFile'] <> '') then  // �����ļ���
      with InWSConnection1.JSON do
      begin
        Action := 999;
        S['_tableName'] := Msg.S['_tableName'];  // ���ݱ�����
        S['_dataFile'] := Msg.S['_dataFile'];  // �����ļ�����
        Post;
      end;
end;

procedure TFormInIOCPDbSvrClientBg.InWSConnection1ReturnResult(Sender: TObject;
  Result: TJSONResult);
begin
  if (Result.Action = 990) then  // �������
  begin
    ClientDataSet1.MergeChangeLog;  // �ϲ�����
    Memo1.Lines.Add('WebSocket���£�' + Result.S['result']);
  end else
  if (Result.Action = 999) then
    case Result.MsgType of
      mtJSON:
        if (Result.S['_tableName'] = 'tbl_xzqh') then  // ���ز�ѯ�����
        begin
          if Result.HasAttachment then  // �и�����������
            Result.Attachment := TFileStream.Create('temp\_query_down.dat', fmCreate);
        end;
      mtAttachment:
        if Assigned(Result.Attachment) then
        begin
          FUpdateTable := Result.S['_tableName'];
          ClientDataSet1.LoadFromStream(Result.Attachment); // ������δ�ͷţ��ڲ��Զ��ͷţ�
          Memo1.Lines.Add('����װ�غ�ִ̨�еĲ�ѯ��� ' + Result.S['_dataFile']);
        end;
    end;
end;

end.
