unit frmInIOCPAdmin;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ActnList, iocp_clients, iocp_base, ComCtrls;

type
  TFormInIOCPAdmin = class(TForm)
    InCertifyClient1: TInCertifyClient;
    InConnection1: TInConnection;
    InMessageClient1: TInMessageClient;                
    btnLogin: TButton;
    btnBroacast: TButton;
    btnCapScreen: TButton;
    btnDisconnect: TButton;
    btnClose: TButton;
    ActionList1: TActionList;
    actLogin: TAction;
    actBroadcast: TAction;
    actTransmitFile: TAction;
    actDisconnect: TAction;
    actLogout: TAction;
    actClose: TAction;
    btnRegister: TButton;
    btnModify: TButton;
    actRegister: TAction;
    actModify: TAction;
    actSendMsg: TAction;
    btnSendMsg: TButton;
    lvClientView: TListView;
    pgcInfo: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    Memo1: TMemo;
    Button1: TButton;
    actBackground: TAction;
    procedure FormCreate(Sender: TObject);
    procedure InCertifyClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure actLoginExecute(Sender: TObject);
    procedure actLogoutExecute(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure actBroadcastExecute(Sender: TObject);
    procedure actTransmitFileExecute(Sender: TObject);
    procedure actDisconnectExecute(Sender: TObject);
    procedure actCloseUpdate(Sender: TObject);
    procedure actCloseExecute(Sender: TObject);
    procedure InCertifyClient1ListClients(Sender: TObject; Count, No: Cardinal;
      const Client: PClientInfo);
    procedure InConnection1ReceiveMsg(Sender: TObject; Msg: TResultParams);
    procedure actRegisterExecute(Sender: TObject);
    procedure InConnection1ReturnResult(Sender: TObject; Result: TResultParams);
    procedure actModifyExecute(Sender: TObject);
    procedure actSendMsgExecute(Sender: TObject);
    procedure actBackgroundExecute(Sender: TObject);
  private
    { Private declarations }
    function FindClientItem(const ClientName: String): TListItem;
    procedure AddMemoMessage(Msg: TResultParams); 
    procedure AddClientItem(Msg: TResultParams); overload;
    procedure AddClientItem(No: Integer; Info: PClientInfo); overload;
    procedure UpdateClientItem(Item: TListItem; Msg: TResultParams; Login: Boolean);
  public
    { Public declarations }
  end;

var
  FormInIOCPAdmin: TFormInIOCPAdmin;

implementation

uses
  iocp_varis, iocp_utils, frmInIOCPLogin, frmInIOCPRegister;

var
  FormInIOCPLogin: TFormInIOCPLogin = nil;

{$R *.dfm}

procedure TFormInIOCPAdmin.actBackgroundExecute(Sender: TObject);
begin
  // ������ú�̨�߳�ִ�У���Ϻ�������Ϣ���ͻ�������һ���ļ����������г��ļ��Ľ����
  // �����ͻ��� TFormInIOCPAdmin.InConnection1ReceiveMsg������� InFileManager1QueryFiles
  with TMessagePack.Create(InConnection1) do
  begin
    Msg := '�г��ļ�������ܺ�ʱ��';
    Post(atFileList);  // �г��ļ�
  end;
end;

procedure TFormInIOCPAdmin.actBroadcastExecute(Sender: TObject);
begin
  // �㲥���������͸��Լ�
  // ���ȵ�¼��ͨ�ͻ���
  with TMessagePack.Create(InConnection1) do
  begin
    Msg := '�㲥һ����ϢAAA';
    Post(atTextBroadcast);  // �㲥
  end;
end;

procedure TFormInIOCPAdmin.actTransmitFileExecute(Sender: TObject);
begin
  // �ϴ��ļ�ĳ�ͻ���
  // ���ÿͻ��� aaa ���ߡ����ߣ��۲�ͻ�����Ϣ
   
  with TMessagePack.Create(InConnection1) do
  begin
    Msg := '����������ļ������±��ص���Ӧ�ļ�.';
    ToUser := 'aaa,bbb';  // ���� aaa,bbb ��������ļ�
    LoadFromFile('bin\sqlite3-w64.dll');
    Post(atFileUpShare);  // ������Է�
  end;

  // ���ط���˵��ļ�
  // ��Ĭ�ϵĴ��·����InConnection1.LocalPath��
{  with TMessagePack.Create(InConnection1) do
  begin
    FileName := 'sqlite3-w64.dll';  // ����λ���ڷ���˽���
    LocalPath := 'temp';   // ָ����ʱ�Ĵ��·��, �°�����
    Post(atFileDownload);  // ����
  end;

  // �ϵ��ϴ�
  with TMessagePack.Create(InConnection1) do
  begin
    LoadFromFile('F:\Backup\MSOffice2003.7z');
    Post(atFileUpChunk); 
  end;   }

end;

procedure TFormInIOCPAdmin.actCloseExecute(Sender: TObject);
begin
  if InConnection1.Logined then
    InCertifyClient1.Logout;
  if InConnection1.Active then
    InConnection1.Active := False;
  Close;
end;

procedure TFormInIOCPAdmin.actCloseUpdate(Sender: TObject);
begin
  if InConnection1.Logined then
    btnLogin.Action := actLogout   // �ǳ�
  else
    btnLogin.Action := actLogin;   // ��¼

  actRegister.Enabled := InConnection1.Logined;
  actBroadcast.Enabled := InConnection1.Logined;
  actTransmitFile.Enabled := InConnection1.Logined;
  actModify.Enabled := InConnection1.Logined;
  actSendMsg.Enabled := InConnection1.Logined;
  actDisconnect.Enabled := InConnection1.Logined;
  actBackground.Enabled := InConnection1.Logined;
  
end;

procedure TFormInIOCPAdmin.actDisconnectExecute(Sender: TObject);
begin
  // �Ͽ����޶�Ӧ�Ĳ��� TActionType��
  // ���Է�һ����ͨ�ı���Ϣ������ˣ�����˸�����Ϣ�����ж��ض��ͻ���
  with TMessagePack.Create(InConnection1) do
  begin
    Msg := 'DISCONNECT';  // �Ͽ�
    ToUser := 'aaa';      // �Ͽ� aaa
    Post(atTextSend);     // �����ı���Ϣ
  end;
end;

procedure TFormInIOCPAdmin.actLoginExecute(Sender: TObject);
begin
  // ��¼
  FormInIOCPLogin := TFormInIOCPLogin.Create(Self);
  with FormInIOCPLogin do
  begin
    FConnection := InConnection1;
    FCertifyClient := InCertifyClient1;
    ShowModal;
    if InConnection1.Logined then
    begin
      lvClientView.Items.Clear;  // ����ͻ����б�
      InCertifyClient1.QueryClients;  // ��ѯȫ�����ӹ��Ŀͻ���
    end;
    Free;
  end;
end;

procedure TFormInIOCPAdmin.actLogoutExecute(Sender: TObject);
begin
  // �ǳ�
  lvClientView.Items.Clear;
  InCertifyClient1.Logout;  // ����� SQL ���� [USER_LOGOUT]
end;

procedure TFormInIOCPAdmin.actModifyExecute(Sender: TObject);
begin
  // ����˻����¼�û���Ȩ�ޣ�Ȩ�޴����ɾ��

{  with TMessagePack.Create(InConnection1) do
  begin
    ToUser := 'ADDNEW';  // Ҫ�޸ĵ��û� = TargetUser
    AsString['user_password'] := 'aaa';
    AsInteger['user_level'] := 1;
    AsString['user_real_name'] := 'ʵ��';
    AsString['user_telephone'] := '01023456789';
    Post(atUserModify);  // �޸�
  end;   }

  // ע�⣺UserName �ǵ�¼�û���������ɾ���Լ�
  with TMessagePack.Create(InConnection1) do
  begin
    ToUser := 'ADDNEW';  // Ҫɾ�����û� = TargetUser
    Post(atUserDelete);  // ɾ��
  end;

end;

procedure TFormInIOCPAdmin.actRegisterExecute(Sender: TObject);
begin
  // ע��
  pgcInfo.ActivePageIndex := 1;
  with TFormInIOCPRegister.Create(Self) do
  begin
    FConnection := InConnection1;
    ShowModal;
    Free;
  end;
end;

procedure TFormInIOCPAdmin.actSendMsgExecute(Sender: TObject);
begin
  // ���ȵ�¼��ͨ�ͻ���
  with TMessagePack.Create(InConnection1) do
  begin
    ToUser := 'aaa,bbb';  // Ŀ���û� = TargetUser���������͸����û�: aaa,bbb,ccc
    Msg := '����һ����Ϣ';
    Post(atTextPush); // �ύ
  end;
end;

procedure TFormInIOCPAdmin.AddClientItem(Msg: TResultParams);
var
  Item: TListItem;
begin
  // �ͻ��˵�¼��������Ϣ
  Item := lvClientView.Items.Add;
  Item.Caption := IntToStr(Item.Index + 1);
  Item.SubItems.Add(Msg.UserGroup + ':' + Msg.UserName);
  Item.SubItems.Add(Msg.PeerIPPort);
  Item.SubItems.Add(IntToStr(Integer(Msg.Role)));
  Item.SubItems.Add(DateTimeToStr(Msg.AsDateTime['action_time']));
  Item.SubItems.Add('-');
end;

procedure TFormInIOCPAdmin.AddClientItem(No: Integer; Info: PClientInfo);
var
  Item: TListItem;
begin
  // ��ѯ�ͻ��ˣ�������Ϣ���� TClientInfo��
  Item := lvClientView.Items.Add;
  Item.Caption := IntToStr(No);
  Item.SubItems.Add(Info^.Group + ':' + Info^.Name);
  Item.SubItems.Add(Info^.PeerIPPort);
  Item.SubItems.Add(IntToStr(Integer(Info^.Role)));
  Item.SubItems.Add(DateTimeToStr(Info^.LoginTime));
  if (Info^.LogoutTime = 0) then
    Item.SubItems.Add('-')
  else
    Item.SubItems.Add(DateTimeToStr(Info^.LogoutTime));
end;

procedure TFormInIOCPAdmin.AddMemoMessage(Msg: TResultParams);
begin
  Memo1.Lines.Add(DateTimeToStr(Now) + '>' +
                  Msg.PeerIPPort + ',' + Msg.UserName + ',' + Msg.Msg);
end;

function TFormInIOCPAdmin.FindClientItem(const ClientName: String): TListItem;
var
  i: Integer;
begin
  for i := 0 to lvClientView.Items.Count - 1 do
  begin
    Result := lvClientView.Items[i];
    if (Result.SubItems[0] = ClientName) then  // �ҵ��ͻ���
      Exit;  // ����
  end;
  Result := Nil;
end;

procedure TFormInIOCPAdmin.FormCreate(Sender: TObject);
begin
  InConnection1.LocalPath := gAppPath + 'data\data_admin';  // �ļ����·��
  CreateDir(InConnection1.LocalPath);
end;

procedure TFormInIOCPAdmin.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  if not InConnection1.Logined then // ��ʱ Action = atUserLogout and ActResult = True
    InConnection1.Active := False;  // ͬʱ�Ͽ�
end;

procedure TFormInIOCPAdmin.InCertifyClient1ListClients(Sender: TObject; Count,
  No: Cardinal; const Client: PClientInfo);
var
  Item: TListItem;
begin
  // �г�ȫ�����ӹ��Ŀͻ�����Ϣ
  if (Client^.LogoutTime = 0) then  // �����ѵ�¼�Ŀͻ���
  begin
    Item := FindClientItem(Client^.Group + ':' + Client^.Name);
    if Assigned(Item) then  // ���¿ͻ�����Ϣ
      Item.Caption := IntToStr(No)
    else  // ����ͻ�����Ϣ���� TClientInfo��
      AddClientItem(No, Client);
  end;
end;

procedure TFormInIOCPAdmin.InCertifyClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ���� InCertifyClient1 �Ĳ������
  case Result.Action of
    atUserLogin: begin
      if InConnection1.Logined then
        FormInIOCPLogin.Close;
      AddMemoMessage(Result);
    end;
    atUserQuery:
      { ���� OnListClients ���г��ͻ��� } ;
  end;
end;

procedure TFormInIOCPAdmin.InConnection1ReceiveMsg(Sender: TObject; Msg: TResultParams);
var
  Item: TListItem;
begin
  // �ͻ��˵�¼ʱ�������Ҫ�����㹻�����Ϣ
  case Msg.Action of
    atUserLogin: begin
      Item := FindClientItem(Msg.UserGroup + ':' + Msg.UserName);
      if Assigned(Item) then
        UpdateClientItem(Item, Msg, True)
      else
        AddClientItem(Msg);
    end;
    atUserLogout: begin
      Item := FindClientItem(Msg.UserGroup + ':' + Msg.UserName);
      if Assigned(Item) then
        UpdateClientItem(Item, Msg, False);
      // Ҳ����������б����²�ѯ����գ����ӳ٣�
      // lvClientView.Items.Clear;  // ����ͻ����б�
      // InCertifyClient1.QueryClients;   // ��ѯȫ�������ӵĿͻ���
    end;
    atFileList: begin
      Memo1.Lines.Add('������ú�ִ̨�У����ѿͻ����ˣ������ڴ����ط���˵Ľ��.');
      with TMessagePack.Create(InConnection1) do
      begin
        LocalPath := 'temp';  // ��ʱ���ļ����·��
        FileName := 'sqlite���п�.txt';  // ���غ�ִ̨�еĽ���ļ�!
        Post(atFileDownload);
      end;
    end;
  end;
  // ����ͻ��˻ memo
  AddMemoMessage(Msg);
end;

procedure TFormInIOCPAdmin.InConnection1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ����ͻ��˻ memo
  AddMemoMessage(Result);
end;

procedure TFormInIOCPAdmin.UpdateClientItem(Item: TListItem; Msg: TResultParams; Login: Boolean);
begin
  // ���¿ͻ�����Ϣ
  if Login then  // ��¼
  begin
    Item.SubItems[1] := Msg.PeerIPPort;
    Item.SubItems[2] := IntToStr(Integer(Msg.Role));
    Item.SubItems[3] := DateTimeToStr(Msg.AsDateTime['action_time']);
    Item.SubItems[4] := '-';
  end else
    Item.SubItems[4] := DateTimeToStr(Msg.AsDateTime['action_time']);
end;

end.
