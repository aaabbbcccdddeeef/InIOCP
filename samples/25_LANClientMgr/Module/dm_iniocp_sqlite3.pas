unit dm_iniocp_sqlite3;

interface

uses
  // ʹ��ʱ��ӵ�Ԫ���� MidasLib��
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, DB, DBClient, Provider,
  iocp_baseModule, iocp_base, iocp_objPools, iocp_sockets,
  iocp_sqlMgr, http_base, http_objects, iocp_WsJSON, MidasLib,
  // ʹ�� ZeosDBO ���� SQLite3
  ZAbstractRODataset, ZAbstractDataset, ZDataset, ZConnection,
  ZSqlUpdate, ZDbcIntfs;

type

  // ���ݿ����
  // �� iocp_baseModule.TInIOCPDataModule �̳��½�

  // �������ݿ���¼����԰�����
  //   OnApplyUpdates��OnExecQuery��OnExecSQL��OnExecStoredProcedure
  //   OnHttpExecQuery��OnHttpExecSQL

  TdmInIOCPSQLite3 = class(TInIOCPDataModule)
    DataSetProvider1: TDataSetProvider;
    InSQLManager1: TInSQLManager;
    procedure InIOCPDataModuleCreate(Sender: TObject);
    procedure InIOCPDataModuleDestroy(Sender: TObject);
    procedure InIOCPDataModuleApplyUpdates(AParams: TReceiveParams;
      AResult: TReturnResult; out ErrorCount: Integer);
    procedure InIOCPDataModuleExecQuery(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleExecSQL(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleExecStoredProcedure(AParams: TReceiveParams;
      AResult: TReturnResult);
  private
    { Private declarations }
    FConnection: TZConnection;
    FQuery, FQueryUsers: TZQuery;
    FQueryLogin: TZQuery;
    FQueryUserInfo: TZQuery;
    FExecSQL: TZQuery;
    FCurrentSQLName: String;
    procedure InterExecQuery(AQuery: TZQuery);
    procedure InterExecSQL(AExecSQL: TZQuery);
    procedure CommitTrans;
    procedure RollbackTrans;
    procedure StartTrans;
  public
    { Public declarations }
    // �����û�����ķ���
    procedure DeleteUser(AParams: TReceiveParams; AResult: TReturnResult);
    procedure ModifyUser(AParams: TReceiveParams; AResult: TReturnResult);
    procedure QueryUser(AParams: TReceiveParams; AResult: TReturnResult);
    procedure RegisterUser(AParams: TReceiveParams; AResult: TReturnResult);
    procedure UserLogin(AParams: TReceiveParams; AResult: TReturnResult);
    procedure UserLogout(AParams: TReceiveParams; AResult: TReturnResult);
  end;

implementation

uses
  iocp_Varis, iocp_baseObjs, iocp_utils;

var
  FSQLite3Lock: TThreadLock = nil;

{$R *.dfm}

procedure TdmInIOCPSQLite3.CommitTrans;
begin
  if FConnection.InTransaction then
    FConnection.Commit;
end;

procedure TdmInIOCPSQLite3.RollbackTrans;
begin
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

procedure TdmInIOCPSQLite3.StartTrans;
begin
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

procedure TdmInIOCPSQLite3.InterExecQuery(AQuery: TZQuery);
begin
  // SQLite3 ��ռ���񣬲�ѯ��ֱ�ӻع�
  FSQLite3Lock.Acquire;
  try
    try
      if not FConnection.InTransaction then
        FConnection.StartTransaction;
      AQuery.Active := True;
      FConnection.Commit;
    finally
      FSQLite3Lock.Release;
    end;
  except
    Raise;
  end;
end;

procedure TdmInIOCPSQLite3.InterExecSQL(AExecSQL: TZQuery);
begin
  // SQLite3 ��ռ�����ύ����������
  FSQLite3Lock.Acquire;
  try
    try
      if not FConnection.InTransaction then
        FConnection.StartTransaction;
      AExecSQL.ExecSQL;
      FConnection.Commit; 
    except
      if FConnection.InTransaction then
        FConnection.Rollback;
      Raise;
    end;
  finally
    FSQLite3Lock.Release;
  end;
end;

// ========================

procedure TdmInIOCPSQLite3.InIOCPDataModuleCreate(Sender: TObject);
begin
  inherited;

  // �� InSQLManager1.SQLs װ�� SQL ��Դ�ļ����ı��ļ���
  if FileExists('sql\���ݿ����.sql') then
    InSQLManager1.SQLs.LoadFromFile('sql\���ݿ����.sql');

  // �� ZeroLib ���� SQLite3 ���ݿ⣬�ں����ݱ�:
  (* CREATE TABLE tbl_users (
       USER_CODE CHAR(6) NOT NULL UNIQUE,
       USER_NAME VARCHAR(20) NOT NULL PRIMARY KEY,
       USER_PASSWORD CHAR(10) NOT NULL,
       USER_LEVEL INTEGER NOT NULL,
       USER_REAL_NAME VARCHAR(20),
       USER_TELEPHONE VARCHAR(30),
       USER_LOGIN_TIME TIMESTAMP,
       USER_LOGOUT_TIME TIMESTAMP,
       ACT_EXECUTOR VARCHAR(20) )  *)

  FConnection := TZConnection.Create(Self);
  FConnection.AutoCommit := False;
  FConnection.Database := 'data\app_data.qdb';
  FConnection.LoginPrompt := False;
  FConnection.Protocol := 'sqlite-3';
  FConnection.TransactIsolationLevel := tiReadCommitted;

  FQuery := TZQuery.Create(Self);    // ͨ�õĲ�ѯ
  FExecSQL := TZQuery.Create(Self);  // ͨ�õ�ִ�� SQL

  FQueryUsers := TZQuery.Create(Self); // ��ѯ�û��б�
  FQueryLogin := TZQuery.Create(Self); // ��ѯ��¼�ʺ�����
  FQueryUserInfo := TZQuery.Create(Self); // ��ѯ�û��Ƿ����

  FQuery.Connection := FConnection;
  FExecSQL.Connection := FConnection;

  FQueryUsers.Connection := FConnection;
  FQueryLogin.Connection := FConnection;
  FQueryUserInfo.Connection := FConnection;
  
  // SQL �̶���Ԥ�裡
  FQueryUsers.SQL.Text := InSQLManager1.GetSQL('USER_QUERY_ALL');  // ���ִ�Сд
  FQueryLogin.SQL.Text := InSQLManager1.GetSQL('USER_LOGIN');
  FQueryUserInfo.SQL.Text := InSQLManager1.GetSQL('USER_QUERY_INFO');
  
  // �Զ����� SQL ����
  FQuery.ParamCheck := True;
  FExecSQL.ParamCheck := True;

  DataSetProvider1.DataSet := FQuery;
  FConnection.Connected := True;
end;

procedure TdmInIOCPSQLite3.InIOCPDataModuleDestroy(Sender: TObject);
begin
  inherited;
  FQuery.Free;
  FExecSQL.Free;
  FQueryUsers.Free;
  FQueryLogin.Free;  
  FQueryUserInfo.Free;
  FConnection.Free;
end;

procedure TdmInIOCPSQLite3.InIOCPDataModuleApplyUpdates(AParams: TReceiveParams;
      AResult: TReturnResult; out ErrorCount: Integer);
begin
  // �� DataSetPrivoder.Delta ����
  FSQLite3Lock.Acquire;
  try
    try
      StartTrans;
      
      // �°�ı䣺
      //   1. ��һ���ֶ�Ϊ�û����� _UserName��
      //   2. �Ժ��ֶ�Ϊ Delta ���ݣ������ж����������ֻ��һ����

      // �ο���TBaseMessage.LoadFromVariant
      //  Params.Fields[0]���û��� _UserName
      //  Params.Fields[1].Name���ֶ����ƣ���Ӧ���ݱ�����
      //  Params.Fields[1].AsVariant��Delta ����

      // ִ�и���ĸ��·���
      // ��һ�� TDataSetProvider ���£�������ֻ��һ��
      InterApplyUpdates([DataSetProvider1], AParams, ErrorCount);
    except
      RollbackTrans;
      Raise;    // �������쳣����Ҫ Raise
    end;
  finally
    if ErrorCount = 0 then
    begin
      CommitTrans;
      AResult.ActResult := arOK;
    end else
    begin
      RollbackTrans;
      AResult.ActResult := arFail;
      AResult.AsInteger['ErrorCount'] := ErrorCount;
    end;
    FSQLite3Lock.Release;
  end;
  
end;

procedure TdmInIOCPSQLite3.InIOCPDataModuleExecQuery(AParams: TReceiveParams; AResult: TReturnResult);
var
  SQLName: String;
begin
  // ��ѯ����
  // �������쳣����

  // 2.0 Ԥ���� SQL��SQLName ����
  //     ���ҷ��������Ϊ SQLName �� SQL ��䣬ִ��
  //     Ҫ�Ϳͻ��˵��������

  SQLName := AParams.SQLName;
  if (SQLName = '') then  // ���� SQL��δ�ؾ��� SELECT-SQL��
    with FQuery do
    begin
      SQL.Clear;
      SQL.Add(AParams.SQL);
    end
  else
  if (SQLName <> FCurrentSQLName) then
  begin
    FCurrentSQLName := SQLName;
    with FQuery do
    begin
      SQL.Clear;
      SQL.Add(InSQLManager1.GetSQL(SQLName));
    end;
  end;

  InterExecQuery(FQuery);

  // LoadFromVariant �Ľ���
  //  ������[���ݼ�a, ���ݼ�b, ���ݼ�c], ['���ݱ�a', '���ݱ�b', '���ݱ�c'])
  //  1. ���ݱ�n �� ���ݼ�n ��Ӧ�����ݱ�����
  //  2. ���������ݱ�ʱ�� 2 ��������Ϊ [] �������Ϊ��
  //  3. ����ж�����ݼ�����һ��Ϊ����

  AResult.LoadFromVariant([DataSetProvider1], ['tbl_xzqh']);  // [] �� [''] ��Ϊֻ��
  AResult.ActResult := arOK;

  FQuery.Active := False;   // �ر�
end;

procedure TdmInIOCPSQLite3.InIOCPDataModuleExecSQL(AParams: TReceiveParams; AResult: TReturnResult);
var
  i: Integer;
  SQLName: string;
begin
  // ִ�� SQL
  // �������쳣����
  try
    // ȡ SQL ����
    SQLName := AParams.SQLName;

    if (SQLName = '') then  // �� SQL �ı�
      FExecSQL.SQL.Text := AParams.SQL
    else
    if (SQLName <> FCurrentSQLName) then  // �� SQL ����
    begin
      FCurrentSQLName := SQLName;
      FExecSQL.SQL.Text := InSQLManager1.GetSQL(SQLName);
    end;

    if AParams.HasParams then  // �ͻ����趨�в���
      for i := 0 to FExecSQL.Params.Count - 1 do  // ������ BLOB
        with FExecSQL.Params[i] do
          Value := AParams.AsString[Name];

    InterExecSQL(FExecSQL);   // ��ռִ��

    AResult.ActResult := arOK;  // ִ�гɹ� arOK
  except
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

procedure TdmInIOCPSQLite3.InIOCPDataModuleExecStoredProcedure(
  AParams: TReceiveParams; AResult: TReturnResult);
begin
  // ִ�д洢����
  try
    // ���Ǵ洢�������ƣ�
    // ProcedureName := AParams.StoredProcName;
    // ����TInDBQueryClient.ExecStoredProc
    //     TInDBSQLClient.ExecStoredProc

    // �����������ݼ���
    // AResult.LoadFromVariant([DataSetProvider1], ['tbl_xzqh']);

    if AParams.StoredProcName = 'ExecuteStoredProc2' then  // ���Դ洢���̣�����δʵ�֣�
      InIOCPDataModuleExecQuery(AParams, AResult)  // ����һ�����ݼ�
    else
      AResult.ActResult := arOK;
  except
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

procedure TdmInIOCPSQLite3.DeleteUser(AParams: TReceiveParams; AResult: TReturnResult);
begin
  // [USER_LOGOUT]
  // ɾ�� ToUser������ UserName
  try
    FExecSQL.SQL.Text := InSQLManager1.GetSQL('USER_DELETE');
    FExecSQL.ParamByName('USER_NAME').AsString := AParams.ToUser;

    // ��ռִ��
    InterExecSQL(FExecSQL);

    AResult.ActResult := arOK;
  except
    on E: Exception do  // Ҫ�����
    begin
      AResult.ActResult := arFail;
      AResult.Msg := E.Message;
    end;
  end;
end;

procedure TdmInIOCPSQLite3.ModifyUser(AParams: TReceiveParams; AResult: TReturnResult);
var
  i: Integer;
begin
  // [USER_MODIFY]
  // �޸��û���Ϣ
  try
    FExecSQL.SQL.Text := InSQLManager1.GetSQL('USER_MODIFY');

    for i := 0 to FExecSQL.Params.Count - 1 do
      with FExecSQL.Params[i] do
        Value := AParams.AsString[Name];

    // ��ռִ��
    InterExecSQL(FExecSQL);

    AResult.ActResult := arOK;  // ����
  except
    on E: Exception do  // Ҫ�����
    begin
      AResult.ActResult := arFail;
      AResult.Msg := E.Message;
    end;
  end;
end;

procedure TdmInIOCPSQLite3.UserLogin(AParams: TReceiveParams; AResult: TReturnResult);
begin
  // [USER_LOGIN]
  // ��¼ʱ AParams.UserName ���û���
  try
    FQueryLogin.ParamByName('USER_NAME').AsString := AParams.UserName;
    FQueryLogin.ParamByName('USER_PASSWORD').AsString := AParams.Password;

    // ��ռ��ѯ
    InterExecQuery(FQueryLogin);

    if FQueryLogin.Eof then
    begin
      FQueryLogin.Active := False;
      AResult.ActResult := arFail; // ʧ��
    end else
    begin
      AResult.Role := TClientRole(FQueryLogin.FieldByName('USER_LEVEL').AsInteger);
      FQueryLogin.Active := False;

      // �����¼ʱ�䵽���ݿ�
      FExecSQL.SQL.Text := InSQLManager1.GetSQL('USER_LOGIN_UPDATE');
      FExecSQL.ParamByName('USER_NAME').AsString := AParams.UserName;

      InterExecSQL(FExecSQL);

      AResult.ActResult := arOK;  // ����
    end;
  except
    on E: Exception do  // Ҫ�����
    begin
      AResult.ActResult := arFail;
      AResult.Msg := E.Message;
    end;
  end;
end;

procedure TdmInIOCPSQLite3.UserLogout(AParams: TReceiveParams; AResult: TReturnResult);
begin
  // [USER_LOGOUT]
  // �ǳ�
  try
    FExecSQL.SQL.Text := InSQLManager1.GetSQL('USER_LOGOUT');
    FExecSQL.ParamByName('USER_NAME').AsString := AParams.UserName;

    // ��ռִ��
    InterExecSQL(FExecSQL);
  except
    on E: Exception do  // Ҫ�����
    begin
      AResult.ActResult := arFail;
      AResult.Msg := E.Message;
    end;
  end;
end;

procedure TdmInIOCPSQLite3.QueryUser(AParams: TReceiveParams; AResult: TReturnResult);
begin
  // [USER_QUERY_INFO]
  // ��ѯ�û� ToUser �Ƿ����
  try
    FQueryUserInfo.ParamByName('USER_NAME').AsString := AParams.ToUser;

    // ��ռ��ѯ
    InterExecQuery(FQueryUserInfo);

    if FQueryUserInfo.Eof then
      AResult.ActResult := arFail
    else begin
      AResult.Role := TClientRole(FQueryUserInfo.FieldByName('USER_LEVEL').AsInteger);
      AResult.ActResult := arOK;  // ����
    end;

    FQueryUserInfo.Active := False;
  except
    on E: Exception do  // Ҫ�����
    begin
      AResult.ActResult := arFail;
      AResult.Msg := E.Message;
    end;
  end;
end;

procedure TdmInIOCPSQLite3.RegisterUser(AParams: TReceiveParams; AResult: TReturnResult);
var
  i: Integer;
begin
  // [USER_REGISTER]
  // ע�����û�
  try
    FExecSQL.SQL.Text := InSQLManager1.GetSQL('USER_REGISTER');

    for i := 0 to FExecSQL.Params.Count - 1 do
      with FExecSQL.Params[i] do
        Value := AParams.AsString[Name];

    InterExecSQL(FExecSQL);  // ��ռִ��

    AResult.ActResult := arOK;  // ִ�гɹ� arOK
  except
    on E: Exception do  // Ҫ�����
    begin
      AResult.ActResult := arFail;
      AResult.Msg := E.Message;
    end;
  end;
end;

initialization
  FSQLite3Lock := TThreadLock.Create;  // SQLite3 �Ƕ�ռд���ݿ�


finalization
  FSQLite3Lock.Free;

end.
