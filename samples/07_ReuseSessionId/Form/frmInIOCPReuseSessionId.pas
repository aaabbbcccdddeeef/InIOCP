unit frmInIOCPReuseSessionId;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_base, iocp_clients, iocp_server,
  iocp_sockets, iocp_managers, iocp_clientBase;

type
  TFormInIOCPReuseSessionId = class(TForm)
    Memo1: TMemo;
    InIOCPServer1: TInIOCPServer;
    InConnection1: TInConnection;
    btnStart: TButton;
    btnStop: TButton;
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnSend: TButton;
    InMessageManager1: TInMessageManager;
    InMessageClient1: TInMessageClient;
    EditTarget: TEdit;
    btnBroad: TButton;
    InClientManager1: TInClientManager;
    InCertifyClient1: TInCertifyClient;
    btnLogin: TButton;
    btnLogout: TButton;
    EditUserName: TEdit;
    edtPort: TEdit;
    lbl1: TLabel;
    btnQuery: TButton;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    Button1: TButton;
    InEchoClient1: TInEchoClient;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure btnSendClick(Sender: TObject);
    procedure btnBroadClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure InClientManager1Login(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure FormCreate(Sender: TObject);
    procedure InMessageClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure btnLogoutClick(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure InMessageManager1Receive(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure EditUserNameDblClick(Sender: TObject);
    procedure btnQueryClick(Sender: TObject);
    procedure InCertifyClient1ListClients(Sender: TObject; Count, No: Cardinal;
      Client: PClientInfo);
    procedure InMessageManager1Push(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InMessageManager1Broadcast(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure Button1Click(Sender: TObject);
    procedure InEchoClient1ReturnResult(Sender: TObject; Result: TResultParams);
    procedure InConnection1ReceiveMsg(Sender: TObject; Msg: TResultParams);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InIOCPServer1AfterClose(Sender: TObject);
  private
    { Private declarations }
    FAppDir: String;
  public
    { Public declarations }
  end;

var
  FormInIOCPReuseSessionId: TFormInIOCPReuseSessionId;
  InstanceCount: Integer = 0;
  
implementation

uses
  iocp_log, iocp_varis, iocp_utils;

{$R *.dfm}

procedure TFormInIOCPReuseSessionId.btnBroadClick(Sender: TObject);
begin
  // ����ԱȨ�޲��ܹ㲥
  InMessageClient1.Broadcast('�㲥��Ϣ, aaa, bbb');
end;

procedure TFormInIOCPReuseSessionId.btnConnectClick(Sender: TObject);
begin
  // ע�⣺
  //  InConnection1.AutoConnect := True;
  //  InConnection1.ReuseSession := True;
  InConnection1.Active := True;
end;

procedure TFormInIOCPReuseSessionId.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
end;

procedure TFormInIOCPReuseSessionId.btnLoginClick(Sender: TObject);
begin
  // ���� Session��
  //   InConnection1.ReuseSession := True;
  InCertifyClient1.Group := 'aaa';
  InCertifyClient1.UserName := EditUserName.Text;
  InCertifyClient1.Password := 'AAABBB';
  InCertifyClient1.Login;
end;

procedure TFormInIOCPReuseSessionId.btnLogoutClick(Sender: TObject);
begin
  // InConnection1.ReuseSession := True;
  //   -> �ǳ����� InConnection1.Session

  // 30�������ٴ����Ӻ������µ�¼������ֱ�ӷ�����Ϣ��...

  InCertifyClient1.Logout;
end;

procedure TFormInIOCPReuseSessionId.btnSendClick(Sender: TObject);
begin
  // ����ǰҪ�ȵ�¼
  //   �������б���������໥֮�����Ϣ����
  if EditTarget.Text <> '' then
    InMessageClient1.SendMsg('����Ϣ�� ' + EditTarget.Text, EditTarget.Text)
  else
    InMessageClient1.SendMsg('����Ϣ������ˣ������壩');
end;

procedure TFormInIOCPReuseSessionId.btnStartClick(Sender: TObject);
begin
  Memo1.Lines.Clear;
  iocp_log.TLogThread.InitLog;              // ������־

  InIOCPServer1.ServerPort := StrToInt(edtPort.Text);
  InIOCPServer1.Active := True;               // ��������

  FrameIOCPSvrInfo1.Start(InIOCPServer1);     // ��ʼͳ��
end;

procedure TFormInIOCPReuseSessionId.btnStopClick(Sender: TObject);
begin
  InIOCPServer1.Active := False; // ֹͣ����
  FrameIOCPSvrInfo1.Stop;        // ֹͣͳ��
  iocp_log.TLogThread.StopLog;   // ֹͣ��־
end;

procedure TFormInIOCPReuseSessionId.Button1Click(Sender: TObject);
begin
  InEchoClient1.Post;  // ����һ�·������ķ�Ӧ
end;

procedure TFormInIOCPReuseSessionId.btnQueryClick(Sender: TObject);
begin
  // ��ѯȫ�����ӵĿͻ��ˣ�����δ��¼��
  //   �� InCertifyClient1ListClients �����ؽ��
  InCertifyClient1.QueryClients;
end;

procedure TFormInIOCPReuseSessionId.EditUserNameDblClick(Sender: TObject);
begin
  EditUserName.Text := 'USER_B';
end;

procedure TFormInIOCPReuseSessionId.FormCreate(Sender: TObject);
begin
  if (InstanceCount = 1) then
  begin
    btnStart.Enabled := False;
    btnStop.Enabled := False;
    EditUserName.Text := 'USER_B';
    EditTarget.Text := 'USER_A';
  end;
  
  // ׼������·��
  FAppDir := ExtractFilePath(Application.ExeName);

  // �ͻ������ݴ��·����2.0�����ƣ�
  iocp_Varis.gUserDataPath := FAppDir + 'client_data\';

  MyCreateDir(FAppDir + 'log');    // ��Ŀ¼
  MyCreateDir(FAppDir + 'temp');   // ��Ŀ¼

  // �����Ե��û�·��
  MyCreateDir(iocp_Varis.gUserDataPath);  // ��Ŀ¼

  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\data');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\msg');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_a\temp');

  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\data');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\msg');
  MyCreateDir(iocp_Varis.gUserDataPath + 'user_b\temp');

end;

procedure TFormInIOCPReuseSessionId.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  case Action of
    atUserLogin:       // ��¼
      if ActResult then
      begin
        Memo1.Lines.Add('��¼�ɹ���30 ������ Session ��Ч����Ͽ�, ����->����,');
        Memo1.Lines.Add('����ÿ�����Ӻ󶼵�¼��')
      end else
        Memo1.Lines.Add('��¼ʧ��');
    atUserLogout:      // �ǳ�
      if ActResult then
        Memo1.Lines.Add('�ǳ��ɹ�')
      else
        Memo1.Lines.Add('�ǳ�ʧ��');
  end;
end;

procedure TFormInIOCPReuseSessionId.InCertifyClient1ListClients(Sender: TObject;
  Count, No: Cardinal; Client: PClientInfo);
begin
  // �ڴ��г���ѯ���Ŀͻ�����Ϣ
  //  Client^.Socket = 0 ��Ϊ�����ӿͻ���
  if Client^.Socket = 0 then
    memo1.Lines.Add(IntToStr(No) + '/' + IntToStr(Count) + ', ' +
             Client^.Group + ':' + Client^.Name + '  ->  ' +
             IntToStr(Cardinal(Client^.Socket)) + '(������)')
  else
    memo1.Lines.Add(IntToStr(No) + '/' + IntToStr(Count) + ', ' +
             Client^.Group + ':' + Client^.Name + '  ->  ' +
             IntToStr(Cardinal(Client^.Socket)));
end;

procedure TFormInIOCPReuseSessionId.InClientManager1Login(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  if (Params.Password <> '') then
  begin
    Result.Role := crAdmin;  // 2.0 �ģ����� crAdmin Ȩ�ޣ��ܹ㲥
    Result.ActResult := arOK;
    // �Ǽ�����, �Զ������û�����·����ע��ʱ����
    InClientManager1.Add(Params.Socket, crAdmin);
  end else
    Result.ActResult := arFail;
end;

procedure TFormInIOCPReuseSessionId.InConnection1Error(Sender: TObject; const Msg: string);
begin
  Memo1.Lines.Add(Msg);  // ��ʾ�쳣��ʾ
end;

procedure TFormInIOCPReuseSessionId.InConnection1ReceiveMsg(Sender: TObject;
  Msg: TResultParams);
begin
  // �յ������ͻ���������Ϣ���������գ�
  Memo1.Lines.Add(InConnection1.UserName + ' �յ� ' + IntToStr(UInt64(Msg.Owner)) + ' ����Ϣ��' + Msg.Msg);
end;

procedure TFormInIOCPReuseSessionId.InEchoClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // �յ���Ӧ�ķ���, Result.VarCount ��������
  Memo1.Lines.Add('����������, �ͻ���������=' + IntToStr(Result.VarCount));
end;

procedure TFormInIOCPReuseSessionId.InIOCPServer1AfterClose(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
end;

procedure TFormInIOCPReuseSessionId.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := InIOCPServer1.Active;
  Memo1.Lines.Add('ip: ' + InIOCPServer1.ServerAddr);
  Memo1.Lines.Add('port: ' + IntToStr(InIOCPServer1.ServerPort));
end;

procedure TFormInIOCPReuseSessionId.InMessageClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // �����������¼�
  case Result.ActResult of
    arOK:
      Memo1.Lines.Add('��Ϣ���ͳɹ�.');
    arOffline:
      Memo1.Lines.Add('�������Է�����.');
    arOutDate:
      Memo1.Lines.Add('ƾ֤���ڣ������µ�¼.');
  end;
end;

procedure TFormInIOCPReuseSessionId.InMessageManager1Broadcast(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �㲥��������Ϣ��ȫ�����߿ͻ���
  InMessageManager1.Broadcast(Params);
  Result.ActResult := arOK;
end;

procedure TFormInIOCPReuseSessionId.InMessageManager1Push(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ������Ϣ�������ͻ���: ToUser��TargetUser
  if (Params.ToUser <> '') then
  begin
    InMessageManager1.PushMsg(Params, Params.ToUser);
    Result.Msg := '������Ϣ�ɹ���Ͷ��';
  end else
    Result.Msg := '��ϢδͶ��';
end;

procedure TFormInIOCPReuseSessionId.InMessageManager1Receive(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  Memo1.Lines.Add('���������յ���Ϣ ' + Params.Msg);
  Result.ActResult := arOK;
end;

end.
