unit svInIOCPService;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  http_objects, iocp_managers, iocp_server;

type
  TInIOCP_HTTP_Service = class(TService)
    InIOCPServer1: TInIOCPServer;
    InHttpDataProvider1: TInHttpDataProvider;
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure InHttpDataProvider1Get(Sender: TObject; Request: THttpRequest;
      Response: THttpResponse);
    procedure InHttpDataProvider1Post(Sender: TObject; Request: THttpRequest;
      Response: THttpResponse);
  private
    { Private declarations }
    FWebSitePath: String;
  public
    { Public declarations }
    function GetServiceController: TServiceController; override;
  end;

var
  InIOCP_HTTP_Service: TInIOCP_HTTP_Service;

implementation

uses
  iocp_varis, iocp_utils, iocp_log, http_base;

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  InIOCP_HTTP_Service.Controller(CtrlCode);
end;

function TInIOCP_HTTP_Service.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TInIOCP_HTTP_Service.InHttpDataProvider1Get(Sender: TObject;
  Request: THttpRequest; Response: THttpResponse);
begin
  // URIҪ����̵��ļ���Ӧ
  if Request.URI = '/' then
    Response.TransmitFile(FWebSitePath + 'index.htm')
  else  // ���ú���ʱҪ�����ж�
    Response.TransmitFile(FWebSitePath + Request.URI);
end;

procedure TInIOCP_HTTP_Service.InHttpDataProvider1Post(Sender: TObject;
  Request: THttpRequest; Response: THttpResponse);
begin
  // Post���Ѿ�������ϣ����ô��¼�
  //   ��ʱ��Request.Complete = True
  if Request.URI = '/ajax/login.htm' then  // ��̬ҳ��
  begin
    if (Request.Params.AsString['user_name'] <> '') and
      (Request.Params.AsString['user_password'] <> '') then   // ��¼�ɹ�
    begin
      Response.CreateSession;  // ���� Session��
      Response.TransmitFile(FWebSitePath + 'ajax\ajax.htm');
    end else
      Response.Redirect('ajax/login.htm');  // �ض�λ����¼ҳ��
  end else
  begin
    Response.SetContent('<html><body>In-IOCP HTTP ����<br>�ύ�ɹ���<br>');
    Response.AddContent('<a href="' + Request.URI + '">����</a><br></body></html>');
  end;
end;

procedure TInIOCP_HTTP_Service.ServiceCreate(Sender: TObject);
begin
  iocp_varis.gAppPath := ExtractFilePath(ParamStr(0));  // ����·��
  FWebSitePath := iocp_varis.gAppPath + iocp_utils.AddBackslash(InHttpDataProvider1.RootDirectory);
  iocp_utils.MyCreateDir(iocp_varis.gAppPath + 'log');  // ����־Ŀ¼
end;

procedure TInIOCP_HTTP_Service.ServiceStart(Sender: TService; var Started: Boolean);
begin
  iocp_log.TLogThread.InitLog(iocp_varis.gAppPath + 'log');  // ������־
  InIOCPServer1.Active := True;
  Started := InIOCPServer1.Active;
end;

procedure TInIOCP_HTTP_Service.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  Stopped := True;
  InIOCPServer1.Active := False;
  iocp_log.TLogThread.StopLog;
end;

end.
