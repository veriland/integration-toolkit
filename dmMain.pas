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
  uHelpers,
  uLogger;

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
    constructor Create(AOwner: TComponent; const LogLevel: string); reintroduce;
    procedure ExtractAndSaveData(const DriverID, Server, Database, UserName, Password, ColumnConfigFile, SQLQueryFile, OutputFilePrefix, MappingFile, JourType,
      GroupColumn, GroupQueryFile, OutputPath, DateStr: string; SkipJournal: Boolean);
  end;

var
  DataModuleMain: TDataModuleMain;
  Logger        : TLogger;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

constructor TDataModuleMain.Create(AOwner: TComponent; const LogLevel: string);
begin
  inherited Create(AOwner);  // Call the inherited constructor

  // Initialize the Logger based on LogLevel or any other custom logic
  if LogLevel.ToLower = 'debug' then
  begin
    Logger := TLogger.Create(true, true, true, true);
  end
  else if LogLevel.ToLower = 'warning' then
  begin
    Logger := TLogger.Create(true, false, true, true);
  end
  else if LogLevel.ToLower = 'info' then
  begin
    Logger := TLogger.Create(true, false, true, false);
  end
  else
  begin
    Logger := TLogger.Create(false, false, true, false);
  end;
end;

/// <summary>
/// Reads the column configuration from the specified file and populates the given array of column configurations.
/// </summary>
/// <param name="FileName">The name of the file to read the column configuration from.</param>
/// <param name="ColumnConfigs">The array of column configurations to populate.</param>
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

/// <summary>
/// Reads the SQL query from the specified file.
/// </summary>
/// <param name="FileName">The path of the file containing the SQL query.</param>
/// <returns>The SQL query as a string.</returns>
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

procedure ExecuteQueryInBatches(const Query: TFDQuery; const SQL: string; const BatchSize: Integer; const ColumnConfigs: TArray<TColumnConfig>;
  const MappingColumns: TArray<string>; var IDList, NewAssetList: TStringList);
  var
    TotalRecords, StartRow, EndRow  : Integer;
    ColumnValue, IDValue, RecordLine: string;
  begin
    // Count total records
    Query.SQL.Text := 'SELECT COUNT(*) AS TotalCount FROM (' + SQL + ') AS T';
    Query.Open;
    TotalRecords := Query.FieldByName('TotalCount').AsInteger;
    Query.Close;

    StartRow := 1;
    EndRow   := BatchSize;

    while StartRow <= TotalRecords do
    begin
      Query.SQL.Text := 'WITH CTE AS (' + SQL + '), NumberedRows AS (' + 'SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum FROM CTE' + ') ' +
        'SELECT * FROM NumberedRows WHERE RowNum BETWEEN :StartRow AND :EndRow';
      Query.ParamByName('StartRow').AsInteger := StartRow;
      Query.ParamByName('EndRow').AsInteger   := EndRow;
      Query.Open;

      while not Query.Eof do
      begin
        RecordLine := '';
        IDValue    := '';
        for var I  := 0 to Length(ColumnConfigs) - 1 do
        begin
          ColumnValue := Query.FieldByName(ColumnConfigs[ I ].ColumnName).AsString;
          RecordLine  := RecordLine + PadValue(ColumnValue, ColumnConfigs[ I ].Padding, ColumnConfigs[ I ].PaddingDirection);
        end;

        // Concatenate values of columns specified in the mapping file
        IDValue   := '';
        for var J := 0 to Length(MappingColumns) - 1 do
        begin
          ColumnValue := Query.FieldByName(MappingColumns[ J ]).AsString;
          IDValue     := IDValue + ColumnValue;
        end;

        IDList.Add(IDValue);
        NewAssetList.Add(RecordLine);

        Query.Next;
      end;

      Query.Close;
      StartRow := EndRow + 1;
      EndRow   := StartRow + BatchSize - 1;
    end;
  end;

function GetFieldValuesAsString(Query: TFDQuery; const ColumnConfigs: TArray<TColumnConfig>; const MappingColumns: TArray<string>): string;
  var
    I           : Integer;
    FieldValue  : string;
    ColumnConfig: TColumnConfig;
  begin
    Result := '';
    for I  := 0 to Length(ColumnConfigs) - 1 do
    begin
      ColumnConfig := ColumnConfigs[ I ];
      FieldValue   := Query.FieldByName(ColumnConfig.ColumnName).AsString;
      if ColumnConfig.PaddingDirection = 'left' then
        FieldValue := FieldValue.PadLeft(ColumnConfig.Padding)
      else
        FieldValue := FieldValue.PadRight(ColumnConfig.Padding);
      Result       := Result + FieldValue;
    end;
  end;

{ TDataModuleMain }

//constructor TDataModuleMain.Create(AOwner: TComponent; LogLevel: string);
//  begin
//    if LogLevel.ToLower = 'debug' then
//      begin
//        Logger := TLogger.Create(true, true, true, true);
//      end
//    else if LogLevel.ToLower = 'warning' then
//      begin
//        Logger := TLogger.Create(true, false, true, true);
//      end
//    else if LogLevel.ToLower = 'info' then
//      begin
//        Logger := TLogger.Create(true, false, true, false);
//      end
//    else
//      begin
//        Logger := TLogger.Create(false, false, true, false);
//      end;
//  end;

procedure TDataModuleMain.ExtractAndSaveData(const DriverID, Server, Database, UserName, Password, ColumnConfigFile, SQLQueryFile, OutputFilePrefix,
  MappingFile, JourType, GroupColumn, GroupQueryFile, OutputPath, DateStr: string; SkipJournal: Boolean);
  var
    AssetList, NewAssetList                          : TStringList;
    CurrentDate                                      : TDateTime;
    ColumnConfigs                                    : TArray<TColumnConfig>;
    MappingColumns                                   : TArray<string>;
    IDList, InsertBatchList, GroupList               : TStringList;
    CheckBatchSize, I, TotalRecords, ProcessedRecords: Integer;
    OutputFileName, RecordID, MainSQLQuery           : string;
    GroupDict                                        : TObjectDictionary<string, TStringList>;

    /// <summary>
    /// Saves the grouped files.
    /// </summary>
    procedure SaveGroupedFiles;
      var
        GroupName    : string;
        GroupFileName: string;
        GroupRecords : TStringList;
      begin
        for GroupName in GroupDict.Keys do
        begin
          GroupRecords  := GroupDict.Items[ GroupName ];
          GroupFileName := TPath.Combine(OutputPath, OutputFilePrefix + '-' + GroupName + '-' + DateStr + '.txt');
          Logger.LogInfo(GetTimestamp, 'Saving records to grouped file: ' + GroupFileName);
          GroupRecords.SaveToFile(GroupFileName);
          Logger.LogInfo(GetTimestamp, 'Records saved to grouped file: ' + GroupFileName);
        end;
      end;

  begin
    AssetList       := TStringList.Create;
    NewAssetList    := TStringList.Create;
    IDList          := TStringList.Create;
    InsertBatchList := TStringList.Create;
    GroupList       := TStringList.Create;
    GroupDict       := TObjectDictionary<string, TStringList>.Create([ doOwnsValues ]);
    try
      CurrentDate    := Now; // Initialize CurrentDate
      CheckBatchSize := 100; // Initialize CheckBatchSize

      // Load column configurations
      Logger.LogDebug(GetTimestamp, 'Loading column configurations...');
      ReadColumnConfig(ColumnConfigFile, ColumnConfigs);
      Logger.LogDebug(GetTimestamp, 'Column configurations loaded.');

      // Load mapping columns
      Logger.LogDebug(GetTimestamp, 'Loading mapping columns...');
      ReadMapping(MappingFile, MappingColumns);
      Logger.LogDebug(GetTimestamp, 'Mapping columns loaded.');

      // Setup the FireDAC connection
      Logger.LogDebug(GetTimestamp, 'Setting up the database connection...');
      FDConnection.Params.DriverID := DriverID;
      FDConnection.Params.Add('Server=' + Server);
      FDConnection.Params.Database := Database;
      FDConnection.Params.UserName := UserName;
      FDConnection.Params.Password := Password;
      FDConnection.Open;
      Logger.LogDebug(GetTimestamp, 'Database connection established.');

      // Prepare the main SQL query with a WHERE clause if SkipJournal is False
      MainSQLQuery := ReadSQLQuery(SQLQueryFile);

      if not SkipJournal then
      begin
        MainSQLQuery := MainSQLQuery + ' WHERE NOT EXISTS (' + 'SELECT 1 FROM agresso.exportjournal ej WHERE ej.JourTransId = ' +
          GenerateIDColumns(MappingColumns) + ')';
      end;

      // Calculate TotalRecords
      FDQueryMain.SQL.Text := 'SELECT COUNT(*) AS TotalCount FROM (' + MainSQLQuery + ') AS T';
      FDQueryMain.Open;
      TotalRecords := FDQueryMain.FieldByName('TotalCount').AsInteger;
      FDQueryMain.Close;

      Logger.LogInfo(GetTimestamp, 'Total records to process: ' + IntToStr(TotalRecords));

      Logger.LogDebug(GetTimestamp, 'Processing records...');

      ProcessedRecords     := 0;
      FDQueryMain.SQL.Text := MainSQLQuery;
      FDQueryMain.Open;

      while not FDQueryMain.Eof do
      begin
        RecordID := GenerateIDValue(FDQueryMain, MappingColumns);

        // Since filtering is done in the SQL query, no need to check here
        NewAssetList.Add(GetFieldValuesAsString(FDQueryMain, ColumnConfigs, MappingColumns));
        IDList.Add(RecordID);

        // Group records if GroupColumn is provided
        if not GroupColumn.IsEmpty then
        begin
          var
          GroupName := FDQueryMain.FieldByName(GroupColumn).AsString;
          if not GroupDict.ContainsKey(GroupName) then
            GroupDict.Add(GroupName, TStringList.Create);
          GroupDict[ GroupName ].Add(GetFieldValuesAsString(FDQueryMain, ColumnConfigs, MappingColumns));
        end;

        FDQueryMain.Next;
        Inc(ProcessedRecords);
        ShowProgressBar(ProcessedRecords, TotalRecords);
      end;
      FDQueryMain.Close;

      // Saves new records to an output file.
      // If the NewAssetList contains any records, it checks if the GroupColumn is empty.
      // If the GroupColumn is empty, it saves the new records to an output file with a timestamp in the filename.
      // If the GroupColumn is not empty, it calls the SaveGroupedFiles procedure.
      // If the NewAssetList is empty, it logs a warning message indicating that there are no records to save.
      if NewAssetList.Count > 0 then
      begin
        if GroupColumn.IsEmpty then
        begin
          OutputFileName := TPath.Combine(OutputPath, OutputFilePrefix + '-' + DateStr + '.txt');
          Logger.LogInfo(GetTimestamp, 'Saving new records to output file: ' + OutputFileName);
          AssetList.Assign(NewAssetList);
          AssetList.SaveToFile(OutputFileName);
          Logger.LogInfo(GetTimestamp, 'New records saved to output file: ' + OutputFileName);
        end else begin
          SaveGroupedFiles;
        end;
      end else begin
        Logger.LogWarning(GetTimestamp, 'No records to save.');
      end;

      // Insert journal entries if SkipJournal is False
      if not SkipJournal and (ProcessedRecords > 0) then
      begin
        Logger.LogDebug(GetTimestamp, 'Inserting new records into journal...');
        FDConnection.StartTransaction;

        try
          InsertBatchList.Clear;
          InsertBatchList.QuoteChar := ' ';
          InsertBatchList.Delimiter := ',';

          // This code block iterates through the IDList and inserts batch records into the agresso.exportjournal table.
          // Each batch consists of multiple records, and the batch size is determined by the CheckBatchSize variable.
          // The IDList contains the IDs to be inserted, CurrentDate represents the current date, and JourType represents the type of journal.
          // The InsertBatchList is used to store the values for each batch before inserting them into the table.
          // The SQL statement is dynamically constructed using the values from InsertBatchList and executed using FDQueryMain.ExecSQL.
          // After each batch is inserted, the InsertBatchList is cleared for the next batch.
          for I := 0 to IDList.Count - 1 do
          begin
            InsertBatchList.Add('(' + QuotedStr(IDList[ I ]) + ', ' + QuotedStr(FormatDateTime('yyyy-mm-dd', CurrentDate)) + ', ' + QuotedStr(JourType) + ')');
            if (I mod CheckBatchSize = 0) and (I > 0) then
            begin
              FDQueryMain.SQL.Text := 'INSERT INTO agresso.exportjournal (JourTransId, TransDate, JourType) VALUES ' + InsertBatchList.DelimitedText;
              Logger.LogDebug(GetTimestamp, 'Executing SQL: ' + FDQueryMain.SQL.Text);
              FDQueryMain.ExecSQL;
              InsertBatchList.Clear;
            end;
          end;

          // Inserts the batch list into the 'agresso.exportjournal' table.
          //
          // If the batch list is not empty, the function constructs an SQL statement to insert the batch list into the table.
          // The constructed SQL statement is then executed using the FDQueryMain component.
          if InsertBatchList.Count > 0 then
          begin
            FDQueryMain.SQL.Text := 'INSERT INTO agresso.exportjournal (JourTransId, TransDate, JourType) VALUES ' + InsertBatchList.DelimitedText;
            Logger.LogDebug(GetTimestamp, 'Executing SQL: ' + FDQueryMain.SQL.Text);
            FDQueryMain.ExecSQL;
          end;

          FDConnection.Commit;
          Logger.LogDebug(GetTimestamp, 'Journal is updated with the new records');
        except
          on E: Exception do
          begin
            FDConnection.Rollback;
            Logger.LogError(GetTimestamp, 'Error inserting records, transaction rolled back: ' + E.Message);
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
      Logger.LogInfo(GetTimestamp, 'Operation completed.');
    end;
  end;

end.
