program SetupDatabase;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows, // For console colouring
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys.Intf,
  FireDAC.Comp.Client,
  FireDAC.Phys,
  FireDAC.DApt,
  FireDAC.Phys.ODBCBase,
  FireDAC.Phys.ODBC,
  FireDAC.Phys.MSSQL,
  dmSetup in 'dmSetup.pas';

const
  COLOR_RESET = #27'[0m';
  COLOR_GREEN = #27'[32m';
  COLOR_YELLOW = #27'[33m';
  COLOR_BLUE = #27'[34m';
  COLOR_RED = #27'[31m';
  COLOR_GREY = #27'[37m';

var
  DriverID, Server, Database, UserName, Password, QueryFile: string;
  QueryText: TStringList;
  ObjectType, SchemaName, ObjectName, TypeCode: string;
  i: Integer;

procedure EnableVirtualTerminalProcessing;
const
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;
var
  hOut: THandle;
  dwMode: DWORD;
begin
  hOut := GetStdHandle(STD_OUTPUT_HANDLE);
  if hOut = INVALID_HANDLE_VALUE then Exit;

  if not GetConsoleMode(hOut, dwMode) then Exit;

  dwMode := dwMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING;
  SetConsoleMode(hOut, dwMode);
end;

procedure ShowUsage;
begin
  Writeln(COLOR_YELLOW + 'Usage: ' + COLOR_RESET + 'SetupDatabase --driver <DriverID> --server <Server> --database <Database> --username <UserName> --password <Password> --query <SQLQueryFile>');
end;

procedure ParseQueryFileName(const FileName: string; out ObjectType, SchemaName, ObjectName, TypeCode: string);
var
  Parts: TArray<string>;
  FileNameOnly: string;
begin
  FileNameOnly := ExtractFileName(FileName);
  Parts := FileNameOnly.Split(['_', '.']);
  if Length(Parts) >= 4 then
  begin
    ObjectType := Parts[0];
    SchemaName := Parts[1];
    ObjectName := Parts[2];

    if SameText(ObjectType, 'Function') then
      TypeCode := 'FN'
    else if SameText(ObjectType, 'Table') then
      TypeCode := 'U'
    else if SameText(ObjectType, 'Procedure') then
      TypeCode := 'P'
    else
      raise Exception.Create('Invalid object type in query file name. Expected Function, Table, or Procedure.');
  end
  else
    raise Exception.Create('Invalid query file name format. Expected format: <ObjectType>_<SchemaName>_<ObjectName>.sql');
end;

begin
  try
    EnableVirtualTerminalProcessing; // Enable ANSI escape codes for colouring the console output

    if ParamCount < 12 then
    begin
      ShowUsage;
      Exit;
    end;

    for i := 1 to ParamCount do
    begin
      if ParamStr(i) = '--driver' then
        DriverID := ParamStr(i + 1)
      else if ParamStr(i) = '--server' then
        Server := ParamStr(i + 1)
      else if ParamStr(i) = '--database' then
        Database := ParamStr(i + 1)
      else if ParamStr(i) = '--username' then
        UserName := ParamStr(i + 1)
      else if ParamStr(i) = '--password' then
        Password := ParamStr(i + 1)
      else if ParamStr(i) = '--query' then
        QueryFile := ParamStr(i + 1);
    end;

    if (DriverID = '') or (Server = '') or (Database = '') or (UserName = '') or (Password = '') or (QueryFile = '') then
    begin
      ShowUsage;
      Exit;
    end;

    // Parse the query file name
    ParseQueryFileName(QueryFile, ObjectType, SchemaName, ObjectName, TypeCode);
    Writeln(COLOR_BLUE + 'Parsed Query File:' + COLOR_RESET);
    Writeln(COLOR_GREEN + 'ObjectType=' + ObjectType + ', SchemaName=' + SchemaName + ', ObjectName=' + ObjectName + ', TypeCode=' + TypeCode + COLOR_RESET);

    // Reading SQL Query from file
    QueryText := TStringList.Create;
    try
      Writeln(COLOR_BLUE + 'Reading SQL Query from file: ' + COLOR_GREEN + QueryFile + COLOR_RESET);
      QueryText.LoadFromFile(QueryFile);

      // Setting up FireDAC connection
      dmSetupDb := TdmSetupDb.Create(nil);
      try
        Writeln(COLOR_GREY + 'Setting up FireDAC connection...' + COLOR_RESET);
        dmSetupDb.FDConnection.DriverName := DriverID;
        dmSetupDb.FDConnection.Params.Add('Server=' + Server);
        dmSetupDb.FDConnection.Params.Add('Database=' + Database);
        dmSetupDb.FDConnection.Params.Add('User_Name=' + UserName);
        dmSetupDb.FDConnection.Params.Add('Password=' + Password);
        dmSetupDb.FDConnection.LoginPrompt := False;

        dmSetupDb.FDConnection.Connected := True;
        Writeln(COLOR_GREY + 'Connected to the database.' + COLOR_RESET);

        // Check if the object exists and drop it if it does
        if dmSetupDb.ObjectExists(SchemaName, ObjectName, TypeCode) then
        begin
          Writeln(COLOR_YELLOW + Format('Object %s.%s of type %s exists. Dropping it...', [SchemaName, ObjectName, ObjectType]) + COLOR_RESET);
          dmSetupDb.ExecuteSQL(Format('DROP %s %s.%s', [ObjectType, SchemaName, ObjectName]));
          Writeln(COLOR_YELLOW + Format('Object %s.%s dropped.', [SchemaName, ObjectName]) + COLOR_RESET);
        end;

        // Execute the SQL query to create or recreate the object
        Writeln(COLOR_GREY + 'Executing SQL query...' + COLOR_RESET);
        dmSetupDb.ExecuteSQL(QueryText.Text);
        Writeln(COLOR_GREEN + 'SQL Object created or updated successfully.' + COLOR_RESET);
      finally
        dmSetupDb.Free;
      end;
    finally
      QueryText.Free;
    end;

  except
    on E: Exception do
    begin
      Writeln(COLOR_RED + E.ClassName + ': ' + E.Message + COLOR_RESET);
    end;
  end;
end.

