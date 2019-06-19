unit frmInIOCPRegister;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, iocp_clients;

type
  TFormInIOCPRegister = class(TForm)
    btnRegister: TButton;
    ledtUserCode: TLabeledEdit;
    ledtAddUser: TLabeledEdit;
    ledtPassword: TLabeledEdit;
    ledtRole: TLabeledEdit;
    btnClose: TButton;
    Label1: TLabel;
    Label2: TLabel;
    procedure btnRegisterClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    FConnection: TInConnection;
  end;

implementation

uses
  iocp_base;

{$R *.dfm}

procedure TFormInIOCPRegister.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TFormInIOCPRegister.btnRegisterClick(Sender: TObject);
begin
{
 ����ˣ�
[USER_REGISTER]
// _UserName -> �ֶ� act_executor
// _ToUser   -> �ֶ� user_name
INSERT INTO tbl_users
 (user_code, user_name, user_password, user_level, act_executor, user_register_time) VALUES
 (:user_code, :_ToUser, :user_password, :user_level, :_UserName, DATETIME('now'))
}

  // TInCertifyClient.Register �Ĳ��������࣬���� TMessagePack

  with TMessagePack.Create(FConnection) do  // �ڲ����Զ����� UserName
  begin
    AsString['user_code'] := ledtUserCode.Text;  // ����ֵ...
    ToUser := ledtAddUser.Text;  // = AsString['_ToUser']
    AsString['user_password'] := ledtPassword.Text;
    AsInteger['user_level'] := StrToInt(ledtRole.Text);
    Post(atUserRegister);
  end;

end;

end.
