unit frmInIOCPWebSocketMsgClient;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, iocp_base, iocp_wsClients, iocp_clientBase;

type
  TFormInIOCPWsJSONMsgClient = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    Timer1: TTimer;                         
    Panel1: TPanel;
    chkShowMsgs: TCheckBox;
    lbEditGroup: TLabeledEdit;
    InWSConnection1: TInWSConnection;
    Button2: TButton;
    procedure Button1Click(Sender: TObject);
    procedure InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
    procedure InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
    procedure Timer1Timer(Sender: TObject);
    procedure InWSConnection1AfterConnect(Sender: TObject);
    procedure InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
    procedure Button2Click(Sender: TObject);
  private
    { Private declarations }
    FCount: Integer;
  public
    { Public declarations }
  end;

var
  FormInIOCPWsJSONMsgClient: TFormInIOCPWsJSONMsgClient;

implementation

{$R *.dfm}

procedure TFormInIOCPWsJSONMsgClient.Button1Click(Sender: TObject);
begin
  InWSConnection1.ServerAddr := '127.0.0.1'; // 'localhost';
  InWSConnection1.ServerPort := 8090; // '12302';
  InWSConnection1.Active := not InWSConnection1.Active;
  Timer1.Enabled := not Timer1.Enabled;
end;

procedure TFormInIOCPWsJSONMsgClient.Button2Click(Sender: TObject);
begin
  // �����Ƕ��� WebSocket Э��
  InWSConnection1.ServerAddr := '127.0.0.1'; // 'localhost';
  InWSConnection1.ServerPort := 8090; // '12302';
  InWSConnection1.Active := not InWSConnection1.Active;
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1AfterConnect(
  Sender: TObject);
begin
  if InWSConnection1.Active then
  begin
    Memo1.Lines.Clear;
    Button1.Caption := 'ֹͣ';
  end else
    Button1.Caption := '�㲥';
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
begin
  // �յ���׼ WebSocket ����Ϣ���������գ������������Ϣ��
  if chkShowMsgs.Checked then
    Memo1.Lines.Add('�յ�:' + Msg);
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
begin
  // �յ� InIOCP-JSON ��Ϣ���������գ�
  if chkShowMsgs.Checked then
    Memo1.Lines.Add('�յ�:' + Msg.S['group'] + ',' + Msg.S['msg']);
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
begin
  // ������Ϣ���յ�����˵ķ�����Ϣ���������գ�
end;

procedure TFormInIOCPWsJSONMsgClient.Timer1Timer(Sender: TObject);
const
  TEXT_MSG = 'AFSFSFLSLFSLFLLLSSLDKDFKDFDSLFKDSKFSLFDKSFLKSLFSLFLSFDSFSLFS';
begin
  Timer1.Enabled := False;
  try
    Inc(FCount);
    if (FCount > Length(TEXT_MSG)) then
      FCount := 1;
    with InWSConnection1.JSON do
    begin
      Action := 33;  // ������� InIOCPWebSocketJSON������ͬʱ���Թ㲥 �� ���ݿ��ѯ
      S['group'] := lbEditGroup.Text;  // ���飨Ⱥ��
      S['user'] := 'user_' + IntToHex(Integer(InWSConnection1), 4);
      S['msg'] := '�㲥��Ϣ,"����:+"' + Copy(Text_msg, 1, FCount);
      Memo1.Lines.Add(Text);  // �°�� Text ����Ϊ��д
      Post;
    end;
  finally
    Timer1.Enabled := True;
  end;
end;

end.
