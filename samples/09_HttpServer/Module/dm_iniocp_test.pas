unit dm_iniocp_test;

interface

uses
  // ʹ��ʱ��ӵ�Ԫ���� MidasLib��
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, DB, DBClient, Provider,
  // ADODB �ĸ߰汾�� Data.Win.ADODB
  {$IF CompilerVersion >= 32} Data.Win.ADODB, {$ELSE} ADODB, {$IFEND}
  iocp_baseModule, iocp_base, iocp_objPools, iocp_sockets,
  iocp_sqlMgr, http_base, http_objects, iocp_WsJSON, MidasLib;

type

  // ���ݿ����
  // �� iocp_baseModule.TInIOCPDataModule �̳��½�

  // �������ݿ���¼����԰�����
  //   OnApplyUpdates��OnExecQuery��OnExecSQL��OnExecStoredProcedure
  //   OnHttpExecQuery��OnHttpExecSQL

  TdmInIOCPTest = class(TInIOCPDataModule)
    DataSetProvider1: TDataSetProvider;
    InSQLManager1: TInSQLManager;
    procedure InIOCPDataModuleCreate(Sender: TObject);
    procedure InIOCPDataModuleDestroy(Sender: TObject);
    procedure InIOCPDataModuleHttpExecQuery(Sender: TObject;
      Request: THttpRequest; Response: THttpResponse);
    procedure InIOCPDataModuleHttpExecSQL(Sender: TObject;
      Request: THttpRequest; Response: THttpResponse);
  private
    { Private declarations }
    FConnection: TADOConnection;
    FQuery: TADOQuery;
    FExecSQL: TADOCommand;
    FCurrentSQLName: String;
    procedure CommitTransaction;
  public
    { Public declarations }
  end;

{ var
    dmInIOCPTest: TdmInIOCPTest; // ע��, ע�ᵽϵͳ���Զ���ʵ�� }

implementation

uses
  iocp_Varis, iocp_utils;

{$R *.dfm}

procedure TdmInIOCPTest.CommitTransaction;
begin
//  GlobalLock.Acquire;   // Ado �������
//  try
    if FConnection.InTransaction then
      FConnection.CommitTrans;
    if not FConnection.InTransaction then
      FConnection.BeginTrans;
{  finally
    GlobalLock.Release;
  end;  }
end;

procedure TdmInIOCPTest.InIOCPDataModuleCreate(Sender: TObject);
begin
  inherited;

  // �� InSQLManager1.SQLs װ�� SQL ��Դ�ļ����ı��ļ���
  InSQLManager1.SQLs.LoadFromFile('sql\' + ClassName + '.sql');

  // Ϊ������룬�°汾���� ADO ���� access ���ݿ⣨�ں������������ݱ�
  FConnection := TADOConnection.Create(Self);
  FConnection.LoginPrompt := False;

  // ע�� Access-ODBC������ ODBC ����
  if DirectoryExists('data') then
    RegMSAccessDSN('acc_db', iocp_varis.gAppPath + 'data\acc_db.mdb', 'InIOCP����')
  else  // ����Ϊ����ʱ
    RegMSAccessDSN('acc_db', iocp_varis.gAppPath + '..\00_data\acc_db.mdb', 'InIOCP����');
    
  SetMSAccessDSN(FConnection, 'acc_db');
  
  FQuery := TADOQuery.Create(Self);
  FExecSQL := TADOCommand.Create(Self);

  FQuery.Connection := FConnection;
  FExecSQL.Connection := FConnection;

  // �Զ����� SQL ����
  FQuery.ParamCheck := True;
  FExecSQL.ParamCheck := True;

  DataSetProvider1.DataSet := FQuery;
  FConnection.Connected := True;
end;

procedure TdmInIOCPTest.InIOCPDataModuleDestroy(Sender: TObject);
begin
  inherited;
  FQuery.Free;
  FExecSQL.Free;
  FConnection.Free;
end;

procedure TdmInIOCPTest.InIOCPDataModuleHttpExecQuery(Sender: TObject;
  Request: THttpRequest; Response: THttpResponse);
var
  i: Integer;
  SQLName: String;
begin
  // Http ����������ִ�� SQL ��ѯ���� Respone ���ؽ��
  with FQuery do
  try
    try

      // �� SQL ���Ʋ��Ҷ�Ӧ�� SQL �ı�
      // Http �� Request.Params û��Ԥ�� sql, sqlName ����
      SQLName := Request.Params.AsString['SQL'];

      if (FCurrentSQLName <> SQLName) then   // ���Ƹı䣬���� SQL
      begin
        SQL.Clear;
        SQL.Add(InSQLManager1.GetSQL(SQLName));
        FCurrentSQLName := SQLName;
      end;

      // ������ Request.SocketState �� Respone.SocketState
      // �������״̬�Ƿ�����, �����������ٲ�ѯ���ͣ�
      // if Request.SocketState then

      // ͨ��һ��ĸ�ֵ������
      // Select xxx from ttt where code=:code and no=:no and datetime=:datetime

      if (FCurrentSQLName = 'Select_tbl_xzqh2') then
      begin
        // �� ab.exe �󲢷�����
        Parameters.Items[0].Value := 110102;  // ������ code
        Active := True;
        // ab.exe ��֧�ַֿ鴫�䣬������ Respone.SendJSON(FQuery)
        SQLName := iocp_utils.DataSetToJSON(FQuery);
        Response.SendJSON(SQLName);
      end else
      begin
        // ������ֵ
        for i := 0 to Parameters.Count - 1 do
          Parameters.Items[i].Value := Request.Params.AsString[Parameters.Items[i].Name];

        Active := True;

        // ת��ȫ����¼Ϊ JSON���� Respone ����
        // 1. С���ݼ����ͣ�
        //     Response.SendJSON(iocp_utils.DataSetToJSON(FQuery))
        // 2. ��������ʱ�Ƽ��� Response.SendJSON(FQuery) �ֿ鷢��!
        // ����iocp_utils ��Ԫ DataSetToJSON��LargeDataSetToJSON��InterDataSetToJSON

        Response.SendJSON(FQuery);  // ��Ĭ���ַ��� gb2312
//        Response.SendJSON(FQuery, hcsUTF8);  // תΪ UTF-8 �ַ���
      end;

    finally
      Active := False;
    end;
  except
    Raise;
  end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleHttpExecSQL(Sender: TObject;
  Request: THttpRequest; Response: THttpResponse);
begin
  // Http ����������ִ�� SQL ����� Respone ���ؽ��
end;

end.
