unit frmInIOCPMsgServer;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls, fmIOCPSvrInfo,
  iocp_server, http_objects, iocp_msgPacks, iocp_managers, iocp_sockets;

type
  TFormInIOCPMsgServer = class(TForm)
    InIOCPServer1: TInIOCPServer;
    InFileManager1: TInFileManager;
    InClientManager1: TInClientManager;
    InMessageManager1: TInMessageManager;
    InDatabaseManager1: TInDatabaseManager;
    InHttpDataProvider1: TInHttpDataProvider;
    btnStart: TButton;
    btnStop: TButton;
    FrameIOCPSvrInfo1: TFrameIOCPSvrInfo;
    Memo1: TMemo;
    lbEditIP: TLabeledEdit;
    lbEditPort: TLabeledEdit;
    Button1: TButton;
    procedure btnStartClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure InIOCPServer1AfterOpen(Sender: TObject);
    procedure InHttpDataProvider1Get(Sender: TObject; Request: THttpRequest;
      Respone: THttpRespone);
    procedure InClientManager1Delete(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InClientManager1Login(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InClientManager1QueryState(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InIOCPServer1Disconnect(Sender: TObject; Socket: TBaseSocket);
    procedure InClientManager1Modify(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InClientManager1Register(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InClientManager1Logout(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InMessageManager1Get(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InMessageManager1Broadcast(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InMessageManager1ListFiles(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InMessageManager1Push(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InMessageManager1Receive(Sender: TObject; Params: TReceiveParams;
      Result: TReturnResult);
    procedure InFileManager1AfterDownload(Sender: TObject;
      Params: TReceiveParams; Document: TIOCPDocument);
    procedure InFileManager1AfterUpload(Sender: TObject; Params: TReceiveParams;
      Document: TIOCPDocument);
    procedure InFileManager1BeforeUpload(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
    procedure InFileManager1BeforeDownload(Sender: TObject;
      Params: TReceiveParams; Result: TReturnResult);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormInIOCPMsgServer: TFormInIOCPMsgServer;

implementation

uses
  iocp_varis, iocp_log, iocp_base, iocp_utils,
  dm_iniocp_sqlite3;

{$R *.dfm}

procedure TFormInIOCPMsgServer.btnStartClick(Sender: TObject);
begin
  if InIOCPServer1.Active then
  begin
    InIOCPServer1.Active := False;  // ���������Զ����ע����ģ��Ϣ
    FrameIOCPSvrInfo1.Stop;  // ͳ��ģ��
    iocp_log.TLogThread.StopLog;
  end else
  begin
    iocp_log.TLogThread.InitLog('log');  // ������־��д��־��iocp_log.WriteLog()
    InDatabaseManager1.AddDataModule(TdmInIOCPSQLite3, '�ͻ�������');  // ע����ģ

    InIOCPServer1.ServerAddr := lbEditIP.Text;
    InIOCPServer1.ServerPort := StrToInt(lbEditPort.Text);

    InIOCPServer1.Active := True;  // ��������
    FrameIOCPSvrInfo1.Start(InIOCPServer1);  // ͳ��ģ��
  end;
end;

procedure TFormInIOCPMsgServer.FormCreate(Sender: TObject);
begin
  gUserDataPath := gAppPath + 'data\data_server\';
  MyCreateDir(gAppPath + 'log');  // ��־Ŀ¼
  MyCreateDir(gAppPath + 'SQL');  // SQL Ŀ¼
  MyCreateDir(gUserDataPath);     // ������û�����Ŀ¼
end;

procedure TFormInIOCPMsgServer.InClientManager1Delete(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // Sender �� TBusiWorker���� DataModule ����������ʱע��� TdmInIOCPSQLite3 ��ʵ��
  // ɾ���û�

  Result.UserName := Params.UserName;
  if (Params.ToUser <> Params.LogName) then  // LogName �ǵ�¼ʱ�����ƣ�Params.LogName = Params.Socket.LogName
  begin
    // ��ѯ��ɾ�����û� ToUser ��Ȩ��
    TdmInIOCPSQLite3(TBusiWorker(Sender).DataModule).QueryUser(Params, Result);

    if (Result.ActResult <> arOK) then
    begin
      Result.Msg := '�û� ' + Params.ToUser + ' ������.';
    end else
    if (TIOCPSocket(Params.Socket).Role > Result.Role) then // ��Ȩ��
    begin
      TdmInIOCPSQLite3(TBusiWorker(Sender).DataModule).DeleteUser(Params, Result);

      if (Result.ActResult = arOK) then  // �����ݱ�ɾ���ɹ�
      begin
        InClientManager1.Disconnect(Params.ToUser);  // �Ͽ��ͻ���
        Result.Msg := 'ɾ���û��ɹ�: ' + Params.ToUser;
      end;
    end else
    begin
      Result.ActResult := arFail;
      Result.Msg := 'ɾ���û�, Ȩ�޲���.';
    end;
  end else
  begin
    Result.ActResult := arFail;
    Result.Msg := '����ɾ���Լ�.';
  end;

  // ���͸����Լ����ȫ������Ա
  InMessageManager1.PushToAdmin(Result);
  
end;

procedure TFormInIOCPMsgServer.InClientManager1Login(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // Sender �� TBusiWorker���� DataModule ����������ʱע��� TdmInIOCPSQLite3 ��ʵ��
  // ��¼
  
  // ȡ�û���Ϣ�����ͻ��˺��ļ������ݿ����.SQL"�� [USER_LOGIN]
  TdmInIOCPSQLite3(TBusiWorker(Sender).DataModule).UserLogin(Params, Result);

  if (Result.ActResult = arOK) then  // �û�����
  begin
    Result.Msg := 'Login OK';
    Result.UserName := Params.UserName;
    Result.AsDateTime['action_time'] := Now;

    // �Ǽ���Ϣ��ǰ���� Role
    // �����¼�����û�������·����ע��ʱ��������Ϣ�� Socket.Evir
    //   Params.UserName �ᱻ���浽 Socket.LogName ��
    InClientManager1.Add(Params.Socket, Result.Role);  // �û���ͳһ��ΪСд��

    // ���͸����Լ����ȫ������Ա
    InMessageManager1.PushToAdmin(Result);

    // ����ԱȨ��ʱ������ֱ�ӹ㲥��������������
//    InMessageManager1.Broadcast(Result);  // ��Ȩ������
  end else
  begin
    Result.Msg := 'Login Fail';
    // Result.ActResult ���� arErrUser ��Ͽ�����
  end;
end;

procedure TFormInIOCPMsgServer.InClientManager1Logout(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // Sender �� TBusiWorker���� DataModule ����������ʱע��� TdmInIOCPSQLite3 ��ʵ��
  // �ǳ�
  
  if (Params.UserName = Params.LogName) then  // LogName �ǵ�¼ʱ������
  begin
    // ���µǳ�ʱ�䣬���ͻ��˺��ļ������ݿ����.SQL"�� [USER_LOGOUT]
    TdmInIOCPSQLite3(TBusiWorker(Sender).DataModule).UserLogout(Params, Result);

    if (Result.ActResult = arOK) then
    begin
      // ����ͻ����������Ϣ
      Result.Msg := 'User Logout.';
      Result.UserName := Params.UserName;
      Result.AsDateTime['action_time'] := Now;

      // ���͸����Լ����ȫ������Ա
      InMessageManager1.PushToAdmin(Result);

      // ����ԱȨ��ʱ������ֱ�ӹ㲥��������������
//      InMessageManager1.Broadcast(Result);  // ��Ȩ������
    end;
  end else
  begin
    // �����ǿͻ��˲���ֵ�ô�
    Result.ActResult := arFail;
    Result.Msg := '�ͻ����������¼�����Ʋ�ͬ.';
  end;

end;

procedure TFormInIOCPMsgServer.InClientManager1Modify(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �޸ģ�δ���Ȩ�ޣ�
  
  // ���ͻ��˺��ļ������ݿ����.SQL"�� [USER_MODIFY]
  TdmInIOCPSQLite3(TBusiWorker(Sender).DataModule).ModifyUser(Params, Result);

  Result.UserName := Params.UserName;
  if Result.ActResult = arOK  then
    Result.Msg := '�޸��û���Ϣ�ɹ�: ' + Params.ToUser;

  // ���͸����Լ����ȫ������Ա
  InMessageManager1.PushToAdmin(Result);
  
end;

procedure TFormInIOCPMsgServer.InClientManager1QueryState(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ��ѯ Params.ToUser ��״̬����ѯ��������̸ı䣩

  // �ȼ�� Params.ToUser �Ƿ���ڣ��ټ���Ƿ��¼
  TdmInIOCPSQLite3(TBusiWorker(Sender).DataModule).QueryUser(Params, Result);
  if (Result.ActResult = arOK) then
    InClientManager1.GetClientState(Params.ToUser, Result);
end;

procedure TFormInIOCPMsgServer.InClientManager1Register(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ע�����û� Params.ToUser �����ݿ⣨δ���ӵ�¼��

  // �û�������Ŀ¼Ϊ iocp_varis.gUserDataPath��Ҫ�����½�
  // �û� Params.ToUser ���ļ�Ŀ¼���ٽ�������Ŀ¼��
  //   1. ToUser\Data: �����Ҫ�ļ�
  //   2. ToUser\Msg:  ���������Ϣ�ļ�
  //   3. ToUser\Temp: ��Ż�������ʱ�ļ�
  //  ���������ļ�

  if (TIOCPSocket(Params.Socket).Role >= crAdmin) then // Ȩ������
  begin
    // ���ͻ��˺��ļ������ݿ����.SQL"�� [USER_REGISTER]
    TdmInIOCPSQLite3(TBusiWorker(Sender).DataModule).RegisterUser(Params, Result);

    Result.UserName := Params.UserName;

    if (Result.ActResult = arOK) then
    begin
      MyCreateDir(iocp_varis.gUserDataPath + Params.ToUser + '\data');
      MyCreateDir(iocp_varis.gUserDataPath + Params.ToUser + '\msg');
      MyCreateDir(iocp_varis.gUserDataPath + Params.ToUser + '\temp');
      Result.Msg := 'ע���û��ɹ�: ' + Params.ToUser;
    end;
  end else
  begin
    Result.ActResult := arFail;
    Result.Msg := 'ע���û�, ' + Params.UserName + 'Ȩ�޲���.';
  end;

  // ���͸����Լ����ȫ������Ա
  InMessageManager1.PushToAdmin(Result);
  
end;

procedure TFormInIOCPMsgServer.InFileManager1AfterDownload(Sender: TObject;
  Params: TReceiveParams; Document: TIOCPDocument);
begin
  // �ļ�������ϴ������¼�
end;

procedure TFormInIOCPMsgServer.InFileManager1AfterUpload(Sender: TObject;
  Params: TReceiveParams; Document: TIOCPDocument);
begin
  // �ļ��ϴ���ϴ������¼���Ҫע���ļ���·����ȫ����
  // �°�������ͷ�����ToUser �������б�ֱ�ӵ��ü���.
  if (Params.Action = atFileUpShare) and (Params.ToUser <> '') then
    InMessageManager1.PushMsg(Params, Params.ToUser);  // ���ѻ򱣴浽�����ļ�
end;

procedure TFormInIOCPMsgServer.InFileManager1BeforeDownload(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ���ļ����Ա�����
  if Params.Action = atFileDownShare then  // ���ع����ļ�
    InFileManager1.OpenLocalFile(Result, 'data\public_temp\' + Params.FileName)
  else
    InFileManager1.OpenLocalFile(Result, 'bin\' + Params.FileName);  // �ϸ���˵Ӧ�򿪹���·�����ļ�
  Result.Msg := '�����ļ�';
end;

procedure TFormInIOCPMsgServer.InFileManager1BeforeUpload(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // Ҫ�ϴ��ļ����Ƚ��ļ���
  // Ҳ����ʹ�����ַ������գ�
  // Params.CreateAttachment('���·��');

  // ������Ϣʱ����������ļ���·�������漰��ȫ����
  //   ���� atFileShare ʱ��һ�����õ���ʱ·������ļ�

  if Params.Action = atFileUpShare then
    Params.CreateAttachment('data\public_temp\')
  else
    InFileManager1.CreateNewFile(Params);

  Result.Msg := '�ϴ��ļ���' + Params.Attachment.FileName;
// Ĭ�Ϸ��ؽ����Result.ActResult := arAccept; 
  
  Memo1.Lines.Add('�ϴ��ļ���' + Params.Attachment.FileName);
    
end;

procedure TFormInIOCPMsgServer.InHttpDataProvider1Get(Sender: TObject;
  Request: THttpRequest; Respone: THttpRespone);
begin
  // HTTP ���񣬷�����Ϣ��
  Respone.SetContent('InIOCP HTTP Server v2.5 IS RUNING!');
end;

procedure TFormInIOCPMsgServer.InIOCPServer1AfterOpen(Sender: TObject);
begin
  btnStart.Enabled := not InIOCPServer1.Active;
  btnStop.Enabled := not btnStart.Enabled;
end;

procedure TFormInIOCPMsgServer.InIOCPServer1Disconnect(Sender: TObject; Socket: TBaseSocket);
var
  Result: TReturnResult;
begin
  // Socket �������رգ�����δ��¼�����Եǳ����µĹر�
  if (Socket is TIOCPSocket) then
  begin
    Result := TIOCPSocket(Socket).Result;
    if Assigned(Result) and (Result.Action <> atUserLogout) then  // ���ǵǳ��Ĺر�
    begin
      Result.Msg := '�Ͽ�����';
      InMessageManager1.Broadcast(Result);  // ���ƽ�����㲥
    end;
  end;
end;

procedure TFormInIOCPMsgServer.InMessageManager1Broadcast(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �㲥��������Ϣ��ȫ���ͻ��ˣ������Լ�����Ȩ��
  Result.UserName := Params.UserName;
  Result.Msg := '�㲥��Ϣ���ѷ���.';
  Result.ActResult := arOK;

  // 3 �ֹ㲥������
  InMessageManager1.Broadcast(Params);
//  InMessageManager1.Broadcast(Result);
//  InMessageManager1.Broadcast(Params.Socket, '�㲥����˵��ı�');

end;

procedure TFormInIOCPMsgServer.InMessageManager1Get(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // ��������Ϣ�������������ظ��ͻ���
  InMessageManager1.ReadMsgFile(Params, Result);
end;

procedure TFormInIOCPMsgServer.InMessageManager1ListFiles(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �г�������Ϣ�ļ�����
  InFileManager1.ListFiles(Params, Result, True);
end;

procedure TFormInIOCPMsgServer.InMessageManager1Push(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
//var
//  oSocket: TIOCPSocket;
begin
  // ������Ϣ�������ͻ���: ToUser��TargetUser

  // 1�����͸����ͻ��ˣ�ToUserֻ����һ���ͻ������ƣ�

  // 1.1 �����ȱ��浽��Ϣ�ļ�
  // InMessageManager1.SaveMsgFile(Params);

  // 1.2 ���ͻ����Ƿ�����
{  Result.UserName := Params.UserName;

  if InClientManager1.Logined(Params.ToUser, oSocket) then
  begin
    InMessageManager1.PushMsg(Params);
    Result.ActResult := arOK;
    Result.Msg := '��������Ϣ: ' + Params.ToUser;
  end else
  begin
    Result.ActResult := arOffline;  // �Է�����
    Result.Msg := '�û�����: ' + Params.ToUser;
  end;    }

  // 2����������ؿͻ��˵�����״̬������ֱ��������

  // 2.1 ���͸� ToUser������ͻ�����","��";"�ָ���
  InMessageManager1.PushMsg(Params, Params.ToUser);  // ȱ�ڶ�����ʱΪ�㲥

  // 2.2 �ڶ������ͷ���
//  InMessageManager1.PushMsg(Params.Socket, '���ͷ���˵���Ϣ', Params.ToUser);  // ȱ��������ʱΪ�㲥

  // ���������Ͷ�����
  if (Result.ActResult = arOK) then
    Result.Msg := 'Ͷ��������Ϣ�ɹ�.'
  else
    Result.Msg := 'Ͷ��������Ϣʧ��.';

  // 2.3 ���������ͷ���
//  InMessageManager1.PushMsg(Result, Params.ToUser);  // ȱ�ڶ�����ʱΪ�㲥

end;

procedure TFormInIOCPMsgServer.InMessageManager1Receive(Sender: TObject;
  Params: TReceiveParams; Result: TReturnResult);
begin
  // �յ��ͻ��˷�������ͨ��Ϣ
  if (Params.Msg = 'DISCONNECT') then  // �Ͽ�ָ���ͻ���
  begin
    InClientManager1.Disconnect(Params.ToUser);
    Result.UserName := Params.UserName;
    Result.Msg := '���ͶϿ���������.';
    Result.ActResult := arOK;
  end;
end;

end.
