program GenerateFile;

uses
  System.SysUtils,
  Winapi.Windows,
  System.IOUtils,
  dmMain in 'dmMain.pas' {DataModuleMain},
  uHelpers in 'uHelpers.pas',
  uLogger in 'uLogger.pas';

// Add this line

procedure ShowUsage;
  begin
    Writeln('Usage: GenerateFile --driver <DriverID> --server <Server> --database <Database> --username <UserName> --password <Password> --config <ColumnConfigFile> --query <SQLQueryFile> --out <OutputFilePrefix> --map <MappingFile> --outputpath <OutputPath> [--groupresults <ColumnName>] [--groupquery <GroupQueryFile>] [--skipjournal]');
    Writeln;
    Writeln('Parameters:');
    Writeln('  --driver       : The database driver ID (e.g., MSSQL)');
    Writeln('  --server       : The server name or IP address');
    Writeln('  --database     : The database name');
    Writeln('  --username     : The database user name');
    Writeln('  --password     : The database user password');
    Writeln('  --config       : Path to the column configuration file');
    Writeln('  --query        : Path to the SQL query file');
    Writeln('  --out          : Output file prefix');
    Writeln('  --map          : Path to the mapping file');
    Writeln('  --outputpath   : Path to the directory where output files will be saved');
    Writeln('  --groupresults : (Optional) Column name to group results');
    Writeln('  --groupquery   : (Optional) Path to the group query file');
    Writeln('  --skipjournal  : (Optional) Skip checking the exportjournal table');
    Writeln('  --loglevel     : (Optional) Log level; Debug | Warning (default) | Info');
    Halt(1);
  end;

function GetParamValue(const ParamName: string): string;
  var
    I: Integer;
  begin
    Result := '';
    for I  := 1 to ParamCount do
    begin
      if LowerCase(ParamStr(I)) = LowerCase(ParamName) then
      begin
        if I < ParamCount then
        begin
          Result := ParamStr(I + 1);
          Exit;
        end;
      end;
    end;
  end;

function HasParam(const ParamName: string): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I  := 1 to ParamCount do
    begin
      if LowerCase(ParamStr(I)) = LowerCase(ParamName) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;

procedure EnableVirtualTerminalProcessing;
  const
    ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;
  var
    hOut  : THandle;
    dwMode: DWORD;
  begin
    hOut := GetStdHandle(STD_OUTPUT_HANDLE);
    if hOut = INVALID_HANDLE_VALUE then
      Exit;

    if not GetConsoleMode(hOut, dwMode) then
      Exit;

    dwMode := dwMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    SetConsoleMode(hOut, dwMode);
  end;

var
  LogLevel, DriverID, Server, Database, UserName, Password, ColumnConfigFile, SQLQueryFile, OutputFilePrefix, MappingFile, OutputPath, GroupColumn,
    GroupQueryFile : string;
  SkipJournal      : Boolean;
  CurrentDate      : TDateTime;
  DateStr, JourType: string;

begin
  try
    EnableVirtualTerminalProcessing;

    if ParamCount < 20 then
    begin
      ShowUsage;
    end;

    DriverID         := GetParamValue('--driver');
    Server           := GetParamValue('--server');
    Database         := GetParamValue('--database');
    UserName         := GetParamValue('--username');
    Password         := GetParamValue('--password');
    ColumnConfigFile := GetParamValue('--config');
    SQLQueryFile     := GetParamValue('--query');
    OutputFilePrefix := GetParamValue('--out');
    MappingFile      := GetParamValue('--map');
    OutputPath       := GetParamValue('--outputpath');
    GroupColumn      := GetParamValue('--groupresults'); // Optional parameter
    GroupQueryFile   := GetParamValue('--groupquery');   // Optional parameter
    SkipJournal      := HasParam('--skipjournal');
    LogLevel         := GetParamValue('--loglevel');
    JourType         := OutputFilePrefix; // Assuming the out parameter is the journal type

    if DriverID.IsEmpty or Server.IsEmpty or Database.IsEmpty or UserName.IsEmpty or Password.IsEmpty or ColumnConfigFile.IsEmpty or SQLQueryFile.IsEmpty or
      OutputFilePrefix.IsEmpty or MappingFile.IsEmpty or OutputPath.IsEmpty then
    begin
      ShowUsage;
    end;

    if LogLevel.IsEmpty then
    begin
      LogLevel := 'warning';
    end;

    // Ensure the output path exists
    if not TDirectory.Exists(OutputPath) then
    begin
      TDirectory.CreateDirectory(OutputPath);
    end;

    // Generate the date string
    CurrentDate := Now;
    DateStr     := FormatDateTime('yymmdd', CurrentDate);

    // Initialize the DataModule
    DataModuleMain := TDataModuleMain.Create(nil, LogLevel);
    try
      DataModuleMain.ExtractAndSaveData(DriverID, Server, Database, UserName, Password, ColumnConfigFile, SQLQueryFile, OutputFilePrefix, MappingFile, JourType,
        GroupColumn, GroupQueryFile, OutputPath, DateStr, SkipJournal);
    finally
      DataModuleMain.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
