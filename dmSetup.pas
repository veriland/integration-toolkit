unit dmSetup;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Stan.Intf, FireDAC.Phys, FireDAC.Phys.MSSQL, FireDAC.Phys.ODBCBase,
  FireDAC.Phys.ODBC, FireDAC.DApt, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.VCLUI.Wait, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, Data.DB, FireDAC.Comp.DataSet;

type
  TdmSetupDb = class(TDataModule)
    FDConnection: TFDConnection;
    FDQuery: TFDQuery;
  private
    { Private declarations }
  public
    { Public declarations }
    function ObjectExists(const Schema, ObjectName, ObjectType: string): Boolean;
    procedure ExecuteSQL(const SQLText: string);
  end;

var
  dmSetupDb: TdmSetupDb;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

function TdmSetupDb.ObjectExists(const Schema, ObjectName, ObjectType: string): Boolean;
begin
  FDQuery.SQL.Text := 'SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID(:Schema) AND name = :ObjectName AND type = :ObjectType';
  FDQuery.Params[0].AsString := Schema;
  FDQuery.Params[1].AsString := ObjectName;
  FDQuery.Params[2].AsString := ObjectType;
  FDQuery.Open;
  Result := not FDQuery.IsEmpty;
  FDQuery.Close;
end;

procedure TdmSetupDb.ExecuteSQL(const SQLText: string);
begin
  FDQuery.SQL.Text := SQLText;
  FDQuery.ExecSQL;
end;

end.

