unit dmMain;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Comp.Client,
  FireDAC.Comp.DataSet,
  FireDAC.Phys.MSSQL,
  FireDAC.Phys.MSSQLDef,
  FireDAC.VCLUI.Wait,
  Data.DB,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  FireDAC.Phys.ODBCBase,
  uHelpers;

type
  TColumnConfig = record
    ColumnName: string;
    Padding: Integer;
    PaddingDirection: string; // 'Left' or 'Right'
  end;

  TDataModuleMain = class(TDataModule)
    FDConnection: TFDConnection;
    FDQueryMain: TFDQuery;
    FDQueryCheck: TFDQuery;
    FDPhysMSSQLDriverLink: TFDPhysMSSQLDriverLink;
  private
    { Private declarations }
  public
    { Public declarations }
    procedure ExtractAndSaveData(const DriverID, Server, Database, UserName, Password, ColumnConfigFile, SQLQueryFile, OutputFilePrefix, MappingFile, JourType, GroupColumn, GroupQueryFile, OutputPath, DateStr: string; SkipJournal: Boolean);
  end;

var
  DataModuleMain: TDataModuleMain;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

// Color constants
const RESET = #27'[0m';

const RED = #27'[31m';

const GREEN = #27'[32m';

const YELLOW = #27'[33m';

const BLUE = #27'[34m';

const MAGENTA = #27'[35m';

const CYAN = #27'[36m';

procedure ReadColumnConfig(const FileName: string; var ColumnConfigs: TArray<TColumnConfig>);
  var
    ConfigList: TStringList;
    Line      : string;
    Parts     : TArray<string>;
    I         : Integer;
  begin
    ConfigList := TStringList.Create;
    try
      ConfigList.LoadFromFile(FileName);
      SetLength(ColumnConfigs, ConfigList.Count);
      for I := 0 to ConfigList.Count - 1 do
      begin
        Line  := ConfigList[ I ];
        Parts := Line.Split([ ',' ]);
        if Length(Parts) = 3 then
        begin
          ColumnConfigs[ I ].ColumnName       := Parts[ 0 ].Trim;
          ColumnConfigs[ I ].Padding          := StrToInt(Parts[ 1 ].Trim);
          ColumnConfigs[ I ].PaddingDirection := Parts[ 2 ].Trim;
        end;
      end;
    finally
      ConfigList.Free;
    end;
  end;

function ReadSQLQuery(const FileName: string): string;
  var
    QueryList: TStringList;
  begin
    QueryList := TStringList.Create;
    try
      QueryList.LoadFromFile(FileName);
      Result := QueryList.Text;
    finally
      QueryList.Free;
    end;
  end;




procedure ReadMapping(const FileName: string; var MappingColumns: TArray<string>);
  var
    MappingList: TStringList;
    I          : Integer;
  begin
    MappingList := TStringList.Create;
    try
      MappingList.LoadFromFile(FileName);
      SetLength(MappingColumns, MappingList.Count);
      for I := 0 to MappingList.Count - 1 do
      begin
        MappingColumns[ I ] := MappingList[ I ].Trim;
      end;
    finally
      MappingList.Free;
    end;
  end;

function PadValue(const Value: string; const Padding: Integer; const Direction: string): string;
begin
  // Trim the value if it exceeds the padding length
  if Length(Value) > Padding then
    Result := Copy(Value, 1, Padding)
  else if Direction.ToLower = 'left' then
    Result := Value.PadRight(Padding)
  else
    Result := Value.PadLeft(Padding);
end;

procedure ExecuteQueryInBatches(const Query: TFDQuery; const SQL: string; const BatchSize: Integer; const ColumnConfigs: TArray<TColumnConfig>; const MappingColumns: TArray<string>; var IDList, NewAssetList: TStringList);
var
  TotalRecords, StartRow, EndRow: Integer;
  ColumnValue, IDValue, RecordLine: string;
begin
  // Count total records
  Query.SQL.Text := 'SELECT COUNT(*) AS TotalCount FROM (' + SQL + ') AS T';
  Query.Open;
  TotalRecords := Query.FieldByName('TotalCount').AsInteger;
  Query.Close;

  StartRow := 1;
  EndRow := BatchSize;

  while StartRow <= TotalRecords do
  begin
    Query.SQL.Text := 'WITH CTE AS (' + SQL +
                      '), NumberedRows AS (' +
                      'SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum FROM CTE' +
                      ') ' +
                      'SELECT * FROM NumberedRows WHERE RowNum BETWEEN :StartRow AND :EndRow';
    Query.ParamByName('StartRow').AsInteger := StartRow;
    Query.ParamByName('EndRow').AsInteger := EndRow;
    Query.Open;

    while not Query.Eof do
    begin
      RecordLine := '';
      IDValue := '';
      for var I := 0 to Length(ColumnConfigs) - 1 do
      begin
        ColumnValue := Query.FieldByName(ColumnConfigs[I].ColumnName).AsString;
        RecordLine := RecordLine + PadValue(ColumnValue, ColumnConfigs[I].Padding, ColumnConfigs[I].PaddingDirection);
      end;

      // Concatenate values of columns specified in the mapping file
      IDValue := '';
      for var J := 0 to Length(MappingColumns) - 1 do
      begin
        ColumnValue := Query.FieldByName(MappingColumns[J]).AsString;
        IDValue := IDValue + ColumnValue;
      end;

      IDList.Add(IDValue);
      NewAssetList.Add(RecordLine);

      Query.Next;
    end;

    Query.Close;
    StartRow := EndRow + 1;
    EndRow := StartRow + BatchSize - 1;
  end;
end;

function GetFieldValuesAsString(Query: TFDQuery; const ColumnConfigs: TArray<TColumnConfig>; const MappingColumns: TArray<string>): string;
var
  I: Integer;
  FieldValue: string;
  ColumnConfig: TColumnConfig;
begin
  Result := '';
  for I := 0 to Length(ColumnConfigs) - 1 do
  begin
    ColumnConfig := ColumnConfigs[I];
    FieldValue := Query.FieldByName(ColumnConfig.ColumnName).AsString;
    if ColumnConfig.PaddingDirection = 'left' then
      FieldValue := FieldValue.PadLeft(ColumnConfig.Padding)
    else
      FieldValue := FieldValue.PadRight(ColumnConfig.Padding);
    Result := Result + FieldValue;
  end;
end;

procedure TDataModuleMain.ExtractAndSaveData(const DriverID, Server, Database, UserName, Password, ColumnConfigFile, SQLQueryFile, OutputFilePrefix, MappingFile, JourType, GroupColumn, GroupQueryFile, OutputPath, DateStr: string; SkipJournal: Boolean);
var
  AssetList, NewAssetList: TStringList;
  CurrentDate: TDateTime;
  ColumnConfigs: TArray<TColumnConfig>;
  MappingColumns: TArray<string>;
  IDList, InsertBatchList, GroupList: TStringList;
  GroupQuery: string;
  // BatchSize,
  CheckBatchSize, I, TotalRecords, ProcessedRecords: Integer;
  OutputFileName: string;
  GroupDict: TObjectDictionary<string, TStringList>;

  function GenerateIDValue(Query: TFDQuery; MappingColumns: TArray<string>): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to High(MappingColumns) do
      Result := Result + Query.FieldByName(MappingColumns[I]).AsString;
  end;

  procedure SaveGroupedFiles;
  var
    GroupName: string;
    GroupFileName: string;
    GroupRecords: TStringList;
  begin
    for GroupName in GroupDict.Keys do
    begin
      GroupRecords := GroupDict.Items[GroupName];
      GroupFileName := TPath.Combine(OutputPath, OutputFilePrefix + '-' + GroupName + '-' + DateStr + '.txt');
      WriteColoredLine(GetTimestamp, 'Saving records to grouped file: ' + GroupFileName, BLUE, GREEN);
      GroupRecords.SaveToFile(GroupFileName);
      WriteColoredLine(GetTimestamp, 'Records saved to grouped file: ' + GroupFileName, BLUE, GREEN);
    end;
  end;

begin
  AssetList := TStringList.Create;
  NewAssetList := TStringList.Create;
  IDList := TStringList.Create;
  InsertBatchList := TStringList.Create;
  GroupList := TStringList.Create;
  GroupDict := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  try
    CurrentDate := Now; // Initialize CurrentDate
    CheckBatchSize := 100; // Initialize CheckBatchSize

    WriteColoredLine(GetTimestamp, 'Loading column configurations...', BLUE, GREEN);
    // Load column configurations
    ReadColumnConfig(ColumnConfigFile, ColumnConfigs);
    WriteColoredLine(GetTimestamp, 'Column configurations loaded.', BLUE, GREEN);

    WriteColoredLine(GetTimestamp, 'Loading mapping columns...', BLUE, GREEN);
    // Load mapping columns
    ReadMapping(MappingFile, MappingColumns);
    WriteColoredLine(GetTimestamp, 'Mapping columns loaded.', BLUE, GREEN);

    WriteColoredLine(GetTimestamp, 'Setting up the database connection...', BLUE, GREEN);
    // Setup the FireDAC connection
    FDConnection.Params.DriverID := DriverID;
    FDConnection.Params.Add('Server=' + Server);
    FDConnection.Params.Database := Database;
    FDConnection.Params.UserName := UserName;
    FDConnection.Params.Password := Password;
    FDConnection.Open;
    WriteColoredLine(GetTimestamp, 'Database connection established.', BLUE, GREEN);

    // Fetch group values if GroupQueryFile is provided
    if not GroupQueryFile.IsEmpty then
    begin
      WriteColoredLine(GetTimestamp, 'Fetching group values...', BLUE, GREEN);
      GroupQuery := ReadSQLQuery(GroupQueryFile);
      FDQueryMain.SQL.Text := GroupQuery;
      FDQueryMain.Open;
      while not FDQueryMain.Eof do
      begin
        GroupList.Add(FDQueryMain.FieldByName(GroupColumn).AsString);
        FDQueryMain.Next;
      end;
      FDQueryMain.Close;
      WriteColoredLine(GetTimestamp, 'Group values fetched.', BLUE, GREEN);
    end;

    WriteColoredLine(GetTimestamp, 'Processing records in batches...', BLUE, GREEN);
//    BatchSize := 100; // Adjust as necessary

    // Count total records
    FDQueryMain.SQL.Text := 'SELECT COUNT(*) AS TotalCount FROM (' + ReadSQLQuery(SQLQueryFile) + ') AS T';
    FDQueryMain.Open;
    TotalRecords := FDQueryMain.FieldByName('TotalCount').AsInteger;
    FDQueryMain.Close;
    WriteColoredLine(GetTimestamp, 'Total records to process: ' + IntToStr(TotalRecords), BLUE, GREEN);

    ProcessedRecords := 0;

    // Execute the query in batches and collect records
    WriteColoredLine(GetTimestamp, 'Executing main query...', BLUE, GREEN);
    FDQueryMain.SQL.Text := ReadSQLQuery(SQLQueryFile);
    FDQueryMain.Open;
    while not FDQueryMain.Eof do
    begin
      NewAssetList.Add(GetFieldValuesAsString(FDQueryMain, ColumnConfigs, MappingColumns));
      IDList.Add(GenerateIDValue(FDQueryMain, MappingColumns));

      // Group records if GroupColumn is provided
      if not GroupColumn.IsEmpty then
      begin
        var GroupName := FDQueryMain.FieldByName(GroupColumn).AsString;
        if not GroupDict.ContainsKey(GroupName) then
          GroupDict.Add(GroupName, TStringList.Create);
        GroupDict[GroupName].Add(GetFieldValuesAsString(FDQueryMain, ColumnConfigs, MappingColumns));
      end;

      FDQueryMain.Next;
      Inc(ProcessedRecords);
      ShowProgressBar(ProcessedRecords, TotalRecords);

//      if ProcessedRecords mod BatchSize = 0 then
//        FDQueryMain.Next;
    end;
    FDQueryMain.Close;
    WriteColoredLine(GetTimestamp, 'Total records processed: ' + IntToStr(ProcessedRecords), BLUE, GREEN);

    // Save the records to files
    if ProcessedRecords > 0 then
    begin
      if GroupColumn.IsEmpty then
      begin
        OutputFileName := TPath.Combine(OutputPath, OutputFilePrefix + '-' + DateStr + '.txt');
        WriteColoredLine(GetTimestamp, 'Saving new records to output file: ' + OutputFileName, BLUE, GREEN);
        AssetList.Assign(NewAssetList);
        AssetList.SaveToFile(OutputFileName);
        WriteColoredLine(GetTimestamp, 'New records saved to output file: ' + OutputFileName, BLUE, GREEN);
      end
      else
      begin
        SaveGroupedFiles;
      end;
    end
    else
    begin
      WriteColoredLine(GetTimestamp, 'No records to save.', BLUE, YELLOW);
    end;

    // Insert journal entries
    if not SkipJournal and (ProcessedRecords > 0) then
    begin
      WriteColoredLine(GetTimestamp, 'Inserting new records into agresso.exportjournal table in batches...', BLUE, GREEN);
      FDConnection.StartTransaction;
      try
        InsertBatchList.Clear;
        InsertBatchList.QuoteChar := ' ';
        InsertBatchList.Delimiter := ',';
        for I := 0 to IDList.Count - 1 do
        begin
          InsertBatchList.Add('(' + QuotedStr(IDList[I]) + ', ' + QuotedStr(FormatDateTime('yyyy-mm-dd', CurrentDate)) + ', ' + QuotedStr(JourType) + ')');
          if (I mod CheckBatchSize = 0) and (I > 0) then
          begin
            FDQueryMain.SQL.Text := 'INSERT INTO agresso.exportjournal (JourTransId, TransDate, JourType) VALUES ' + InsertBatchList.DelimitedText;
            WriteColoredLine(GetTimestamp, 'Executing SQL: ' + FDQueryMain.SQL.Text, BLUE, GREEN);  // Add detailed logging
            FDQueryMain.ExecSQL;
            InsertBatchList.Clear;
          end;
        end;

        if InsertBatchList.Count > 0 then
        begin
          FDQueryMain.SQL.Text := 'INSERT INTO agresso.exportjournal (JourTransId, TransDate, JourType) VALUES ' + InsertBatchList.DelimitedText;
          WriteColoredLine(GetTimestamp, 'Executing SQL: ' + FDQueryMain.SQL.Text, BLUE, GREEN);  // Add detailed logging
          FDQueryMain.ExecSQL;
        end;

        FDConnection.Commit;
        WriteColoredLine(GetTimestamp, 'New records inserted into agresso.exportjournal table.', BLUE, GREEN);
      except
        on E: Exception do
        begin
          FDConnection.Rollback;
          WriteColoredLine(GetTimestamp, 'Error inserting records, transaction rolled back: ' + E.Message, BLUE, RED);
        end;
      end;
    end;

  finally
    FDConnection.Close;
    AssetList.Free;
    NewAssetList.Free;
    IDList.Free;
    InsertBatchList.Free;
    GroupList.Free;
    GroupDict.Free;
    WriteColoredLine(GetTimestamp, 'Operation completed.', BLUE, GREEN);
  end;
end;

end.
