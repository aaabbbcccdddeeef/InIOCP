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
    procedure InIOCPDataModuleApplyUpdates(AParams: TReceiveParams;
      AResult: TReturnResult; out ErrorCount: Integer);
    procedure InIOCPDataModuleExecQuery(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleExecSQL(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleExecStoredProcedure(AParams: TReceiveParams;
      AResult: TReturnResult);
    procedure InIOCPDataModuleWebSocketQuery(Sender: TObject;
      JSON: TReceiveJSON; Result: TResultJSON);
    procedure InIOCPDataModuleWebSocketUpdates(Sender: TObject;
      JSON: TReceiveJSON; Result: TResultJSON);
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

procedure TdmInIOCPTest.InIOCPDataModuleApplyUpdates(AParams: TReceiveParams;
  AResult: TReturnResult; out ErrorCount: Integer);
begin
  // �� DataSetPrivoder.Delta ����

  if not FConnection.InTransaction then
    FConnection.BeginTrans;

  try
    try
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
      
    finally
      if ErrorCount = 0 then
      begin
        CommitTransaction;
        AResult.ActResult := arOK;
      end else
      begin
        if FConnection.InTransaction then
          FConnection.RollbackTrans;
        AResult.ActResult := arFail;
        AResult.AsInteger['ErrorCount'] := ErrorCount;
      end;
    end;
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
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

procedure TdmInIOCPTest.InIOCPDataModuleExecQuery(AParams: TReceiveParams;
  AResult: TReturnResult);
var
  SQLName: String;
begin
  // ��ѯ����
  // �������쳣����

  // �ú�ִ̨�в�ѯ��������������Ϣ���ͻ��ˣ�
  
  if (AParams.Socket.Background = False) then
  begin
    AResult.ActResult := arOK;
    AddToBackGround(AParams.Socket);  // �����ִ̨��
    Exit;
  end;

  if not FConnection.InTransaction then
    FConnection.BeginTrans;

  // 2.0 Ԥ���� SQL��SQLName ����
  //     ���ҷ��������Ϊ SQLName �� SQL ��䣬ִ��
  //     Ҫ�Ϳͻ��˵��������

  SQLName := AParams.SQLName;
  if (SQLName = '') then  // ���� SQL��δ�ؾ��� SELECT-SQL��
    with FQuery do
    begin
      SQL.Clear;
      SQL.Add(AParams.SQL);
      Active := True;
    end
  else
  if (SQLName <> FCurrentSQLName) then
  begin
    FCurrentSQLName := SQLName;
    with FQuery do
    begin
      SQL.Clear;
      SQL.Add(InSQLManager1.GetSQL(SQLName));
      Active := True;
    end;
  end;

  // LoadFromVariant �Ľ���
  //  ������[���ݼ�a, ���ݼ�b, ���ݼ�c], ['���ݱ�a', '���ݱ�b', '���ݱ�c'])
  //  1. ���ݱ�n �� ���ݼ�n ��Ӧ�����ݱ�����
  //  2. ���������ݱ�ʱ�� 2 ��������Ϊ [] �������Ϊ��
  //  3. ����ж�����ݼ�����һ��Ϊ����

  // ��װ�����ݡ��ٱ��棬��� AResult��

  AResult.LoadFromVariant([DataSetProvider1], ['tbl_xzqh']);  // [] �� [''] ��Ϊֻ��
  AResult.SaveToFile('data\background.dat');  // ��Ҫ��д�ļ���ͻ���Զ����Clear��

  // Ҳ������ VariantToStream(DataSetProvider1.Data, TFileStream) ���浽�ļ���
  // �ͻ������غ��� TClientDataSet.LoadFromFile() ��ʾ

  FQuery.Active := False;   // �ر�

  // ע�⣬Ҫ������Ϣ���ͻ��ˣ��ͻ������� AsString['data_file']��
  //   ����ʱ�����ļ������������
  AResult.AsString['data_file'] := 'background.dat';
  AResult.ActResult := arOK;

  Wakeup(AResult.Socket);

end;

procedure TdmInIOCPTest.InIOCPDataModuleExecSQL(AParams: TReceiveParams;
  AResult: TReturnResult);
var
  SQLName: string;
begin
  // ִ�� SQL
  // �������쳣����
  if not FConnection.InTransaction then
    FConnection.BeginTrans;

  try

    // ȡ SQL
    SQLName := AParams.SQLName;
    if (SQLName = '') then  // �� SQL
      FExecSQL.CommandText := AParams.SQL
    else
    if (SQLName <> FCurrentSQLName) then  // ������
    begin
      FCurrentSQLName := SQLName;
      FExecSQL.CommandText := InSQLManager1.GetSQL(SQLName);
    end;

    if not AParams.HasParams then  // �ͻ����趨��û�в�����
    begin
      FExecSQL.Execute;  // ֱ��ִ��
    end else
      with FExecSQL do
      begin  // ������ֵ
        Parameters.ParamByName('picutre').LoadFromStream(AParams.AsStream['picture'], ftBlob);
        Parameters.ParamByName('code').Value := AParams.AsString['code'];
        Execute;
      end;

    CommitTransaction;
    AResult.ActResult := arOK;  // ִ�гɹ� arOK
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleExecStoredProcedure(
  AParams: TReceiveParams; AResult: TReturnResult);
begin
  // ִ�д洢����
  try
    // ���Ǵ洢�������ƣ�
    // ProcedureName := AParams.StoredProcName;
    // ����TInDBQueryClient.ExecStoredProc
    //     TInDBSQLClient.ExecStoredProc

    // �����������ݼ���
    // AResult.LoadFromVariant(DataSetProvider1.Data);

    if AParams.StoredProcName = 'ExecuteStoredProc2' then  // ���Դ洢���̣�����δʵ�֣�
      InIOCPDataModuleExecQuery(AParams, AResult)     // ����һ�����ݼ�
    else
      AResult.ActResult := arOK;
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleWebSocketQuery(Sender: TObject;
  JSON: TReceiveJSON; Result: TResultJSON);
var
  Stream: TStream;
begin
  // �ú�ִ̨��
  if (JSON.Socket.Background = False) then
   begin
     // �����ִ̨��
     AddToBackground(JSON.Socket);  // ��ǰ

     JSON.Socket.SendResult;  // Ҫ��ʽ���ͽ����C/Sģʽ���ã�
   end else
   begin
     // ��ʽִ��...���������ѣ�
     try
       FQuery.SQL.Clear;
       FQuery.SQL.Add('Select * from tbl_xzqh');
       FQuery.Active := True;

       Stream := VariantToStream(DataSetProvider1.Data, False, 'temp\_query_result.dat'); // ��ѹ�����ͻ���ֱ�Ӷ��룩
       Stream.Free;
     finally
       FQuery.Active := False;
     end;

     Result.S['_tableName'] := 'tbl_xzqh';  // ���ݱ�����
     Result.S['_dataFile'] := '_query_result.dat';  // �����ļ����Ƹ��ͻ���

     Wakeup(JSON.Socket);  // ���� Result �� JSON.Socket
   end;
end;

procedure TdmInIOCPTest.InIOCPDataModuleWebSocketUpdates(Sender: TObject;
  JSON: TReceiveJSON; Result: TResultJSON);
var
  ErrorCount: Integer;
begin
  if not FConnection.InTransaction then
    FConnection.BeginTrans;
  try
    try
      // _delta �ǿͻ��˴������ı������
      DataSetProvider1.ApplyUpdates(JSON.V['_delta'], 0, ErrorCount);
    finally
      if ErrorCount = 0 then
      begin
        CommitTransaction;
        Result.S['result'] := '���³ɹ�.';
      end else
      begin
        if FConnection.InTransaction then
          FConnection.RollbackTrans;
        Result.S['result'] := '����ʧ��.';
      end;
    end;
  except
    if FConnection.InTransaction then
      FConnection.RollbackTrans;
    Raise;    // �������쳣����Ҫ Raise
  end;
end;

end.
