unit frmInIOCPClient;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes,
  Graphics, Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  iocp_base, iocp_msgPacks, iocp_clients;

type                                       
  TFormInIOCPClient = class(TForm)
    InConnection1: TInConnection;
    InMessageClient1: TInMessageClient;
    btnInOut: TButton;
    InCertifyClient1: TInCertifyClient;
    Memo1: TMemo;
    btnLogin2: TButton;
    lbEditIP: TLabeledEdit;
    lbEditPort: TLabeledEdit;
    InFileClient1: TInFileClient;
    procedure FormCreate(Sender: TObject);
    procedure btnInOutClick(Sender: TObject);
    procedure InConnection1ReturnResult(Sender: TObject; Result: TResultParams);
    procedure InCertifyClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InMessageClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure InConnection1ReceiveMsg(Sender: TObject; Message: TResultParams);
    procedure btnLogin2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure InFileClient1ReturnResult(Sender: TObject; Result: TResultParams);
  private
    { Private declarations }
    FLastMsgId: UInt64;
    procedure ListOfflineMsgs(Result: TResultParams);
    procedure SetInConnectionHost;
  public
    { Public declarations }
  end;

var
  FormInIOCPClient: TFormInIOCPClient;

implementation

uses
  iocp_varis, iocp_utils;

{$R *.dfm}

procedure TFormInIOCPClient.btnInOutClick(Sender: TObject);
begin
  // ���� 1��
  // TMessagePack ������Ϊ InConnection1��
  // �� InConnection1.OnReturnResult �������

  SetInConnectionHost;

{  if InConnection1.Logined then
    TMessagePack.Create(InConnection1).Post(atUserLogout)
  else
    with TMessagePack.Create(InConnection1) do
    begin
      UserName := 'aaa';
      Password := 'aaa';
      Post(atUserLogin);
    end;           }

  // ���� 2���� InCertifyClient1.OnReturnResult �������
  if InConnection1.Logined then
    InCertifyClient1.Logout
  else
    with InCertifyClient1 do
    begin
      Group := 'Group_a';  // ����
      UserName := 'aaa';
      Password := 'aaa';
      Login;
    end;
end;

procedure TFormInIOCPClient.btnLogin2Click(Sender: TObject);
begin
  SetInConnectionHost;
  if InConnection1.Logined then
    InCertifyClient1.Logout
  else
    with InCertifyClient1 do
    begin
      Group := 'Group_a';  // ����
      UserName := 'bbb';
      Password := 'bbb';
      Login;
    end;
end;

procedure TFormInIOCPClient.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  if InConnection1.Logined then
    InCertifyClient1.Logout;
end;

procedure TFormInIOCPClient.FormCreate(Sender: TObject);
begin
  InConnection1.LocalPath := gAppPath + 'data\data_client';  // ����Ŀ¼
  CreateDir(InConnection1.LocalPath);
end;

procedure TFormInIOCPClient.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  // ��¼���ǳ�������� OnReturnResult ֮ǰִ�У�
  //   ������ OnReturnResult ���жϿͻ���״̬
  case Action of
    atUserLogin:
      if ActResult then
      begin
        btnInOut.Caption := '�ǳ�';
        btnLogin2.Caption := '�ǳ�2';
      end;
    atUserLogout: begin
      btnInOut.Caption := '��¼';
      btnLogin2.Caption := '��¼2';
    end;

    else
      { ���������� } ;
  end;
end;

procedure TFormInIOCPClient.InCertifyClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.Action of
    atUserLogin: begin
      Memo1.Lines.Add(Result.Msg);
      if (Result.ActResult = arOK) then
        InMessageClient1.GetOfflineMsgs; // ȡ������Ϣ
      end;
    atUserLogout: begin
      Memo1.Lines.Add(Result.Msg);
      InConnection1.Active := False;
    end;
  end;
end;

procedure TFormInIOCPClient.InConnection1Error(Sender: TObject;
  const Msg: string);
begin
  Memo1.lines.Add(Msg);
end;

procedure TFormInIOCPClient.InConnection1ReceiveMsg(Sender: TObject; Message: TResultParams);
begin
  // �յ������ͻ��˵�������Ϣ
  // �ڷ����ʹ�� InMessageManager1.Broadcast()��PushMsg() ����
  // Msg.Action��Mag.ActResult �����˷�������һ��   
  Memo1.lines.Add('�յ�������Ϣ��' +
    Message.PeerIPPort + ', �û���' + Message.UserName + ', ��Ϣ��' +  Message.Msg);

 if Message.Action = atFileUpShare then // Ҫ���ع����ļ�
   with TMessagePack.Create(InFileClient1) do
   begin
     FileName := Message.FileName; // ������ļ���
     LocalPath := 'temp';      // ���ش�ŵ� temp Ŀ¼
     Post(atFileDownShare);
   end;

end;

procedure TFormInIOCPClient.InConnection1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.Action of
    atUserLogin: begin
      Memo1.Lines.Add(Result.Msg);
      if (Result.ActResult = arOK) then
      begin
        btnInOut.Caption := '�ǳ�';
        btnLogin2.Caption := '�ǳ�2';
        InMessageClient1.GetOfflineMsgs; // ȡ������Ϣ
      end;
    end;

    atUserLogout: begin
      Memo1.Lines.Add(Result.Msg);
      InConnection1.Active := False;
      btnInOut.Caption := '��¼';
      btnLogin2.Caption := '��¼2';
    end;

    else
      { ����������� } ;
  end;
end;

procedure TFormInIOCPClient.InFileClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  if Result.Action = atFileUpShare then 
    if Result.ActResult = arOK then
      Memo1.Lines.Add('�ļ��������');
end;

procedure TFormInIOCPClient.InMessageClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.Action of
    atTextGetMsg:  // ������Ϣ
      ListOfflineMsgs(Result);
  end;
end;

procedure TFormInIOCPClient.ListOfflineMsgs(Result: TResultParams);
var
  i, k: Integer;
  PackMsg: TReceivePack;  // ������Ϣ��
  Reader: TMessageReader;  // ������Ϣ�Ķ���
begin
  // === ����������Ϣ ===
  
  if not Assigned(Result.Attachment) then
    Exit;

  // �и�����������������Ϣ��������
  Memo1.Lines.Add('������Ϣ: ' + Result.Msg);

  PackMsg := TReceivePack.Create;
  Reader := TMessageReader.Create;

  try
    // ��ʱ Attachment �Ѿ��رգ���δ�ͷ�
    // ���ļ������������Ϣ�ļ� -> Count = 0
    Reader.Open(Result.Attachment.FileName);

    // �����ǰ��������� MsgId ���浽���̣�
    // ��¼ǰ���벢���� LastMsgId = ???��������
    // ��Ϣ�ļ��ж����� LastMsgId �����Ϣ��

    for i := 0 to Reader.Count - 1 do
    begin
      if Reader.Extract(PackMsg, FLastMsgId) then  // ������ LastMsgId �����Ϣ
      begin
        for k := 0 to PackMsg.Count - 1 do  // �����ֶ�
          with PackMsg.Fields[k] do
            Memo1.Lines.Add(Name + '=' + AsString);

        if PackMsg.Action = atFileUpShare then  // ����ǹ����ļ���������
        begin
          Memo1.Lines.Add('�����ļ�:' + PackMsg.FileName);
          with TMessagePack.Create(InFileClient1) do
          begin
            FileName := PackMsg.FileName;
            LocalPath := 'temp';   // ��ŵ� temp Ŀ¼
            Post(atFileDownShare); // ���ع����ļ�
          end;
        end;

      end;
    end;

    // ����������Ϣ��
    if PackMsg.MsgId > FLastMsgId then
    begin
      FLastMsgId := PackMsg.MsgId;
      with TStringList.Create do
        try
          Add(IntToStr(FLastMsgId));
          SaveToFile('data\MaxMsgId.ini');
        finally
          Free;
        end;
    end;

  finally
    PackMsg.Free;
    Reader.Free;
  end;
end;

procedure TFormInIOCPClient.SetInConnectionHost;
begin
  if not InConnection1.Active then
  begin
    InConnection1.ServerAddr := lbEditIP.Text;
    InConnection1.ServerPort := StrToInt(lbEditPort.Text);
  end;
end;

end.
