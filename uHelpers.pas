unit uHelpers;

interface

uses
  System.Classes,
  System.SysUtils,
  FireDAC.Comp.Client;

const
  RESET = #27'[0m'; // Resets all attributes

  BLACK   = #27'[30m'; // Standard black
  RED     = #27'[31m'; // Standard red
  GREEN   = #27'[32m'; // Standard green
  YELLOW  = #27'[33m'; // Standard yellow
  BLUE    = #27'[34m'; // Standard blue
  MAGENTA = #27'[35m'; // Standard magenta
  CYAN    = #27'[36m'; // Standard cyan
  WHITE   = #27'[37m'; // Standard white

  BRIGHT_BLACK   = #27'[90m'; // Bright black (gray)
  BRIGHT_RED     = #27'[91m'; // Bright red
  BRIGHT_GREEN   = #27'[92m'; // Bright green
  BRIGHT_YELLOW  = #27'[93m'; // Bright yellow
  LIGHT_BLUE     = #27'[94m'; // Bright blue (light blue)
  BRIGHT_MAGENTA = #27'[95m'; // Bright magenta
  BRIGHT_CYAN    = #27'[96m'; // Bright cyan
  BRIGHT_WHITE   = #27'[97m'; // Bright white (light gray)

  // Background colors
  BG_BLACK   = #27'[40m'; // Black background
  BG_RED     = #27'[41m'; // Red background
  BG_GREEN   = #27'[42m'; // Green background
  BG_YELLOW  = #27'[43m'; // Yellow background
  BG_BLUE    = #27'[44m'; // Blue background
  BG_MAGENTA = #27'[45m'; // Magenta background
  BG_CYAN    = #27'[46m'; // Cyan background
  BG_WHITE   = #27'[47m'; // White background

  BG_BRIGHT_BLACK   = #27'[100m'; // Bright black background (gray)
  BG_BRIGHT_RED     = #27'[101m'; // Bright red background
  BG_BRIGHT_GREEN   = #27'[102m'; // Bright green background
  BG_BRIGHT_YELLOW  = #27'[103m'; // Bright yellow background
  BG_BRIGHT_BLUE    = #27'[104m'; // Bright blue background
  BG_BRIGHT_MAGENTA = #27'[105m'; // Bright magenta background
  BG_BRIGHT_CYAN    = #27'[106m'; // Bright cyan background
  BG_BRIGHT_WHITE   = #27'[107m'; // Bright white background (light gray)

function PadValue(const Value: string; const Padding: Integer; const Direction: string): string;
function GenerateIDColumns(MappingColumns: TArray<string>): string;
function GenerateIDValue(Query: TFDQuery; MappingColumns: TArray<string>): string;
function GetTimestamp: string;
procedure WriteColoredText(const Text, ColorCode: string);
procedure WriteColoredLine(const DateTimeText, MessageText: string; DateTimeColor, MessageColor: string);
procedure ShowProgressBar(Progress, Total: Integer);

implementation

function GetTimestamp: string;
  begin
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
  end;

procedure WriteColoredText(const Text, ColorCode: string);
  begin
    Write(ColorCode + Text + RESET);
  end;

procedure WriteColoredLine(const DateTimeText, MessageText: string; DateTimeColor, MessageColor: string);
  begin
    Writeln(DateTimeColor + DateTimeText + RESET + ' | ' + MessageColor + MessageText + RESET);
  end;

/// <summary>
/// Displays a progress bar indicating the progress of a task.
/// </summary>
/// <param name="Progress">The current progress of the task.</param>
/// <param name="Total">The total progress of the task.</param>
procedure ShowProgressBar(Progress, Total: Integer);
  const
    BarWidth = 50;
  var
    Pos    : Integer;
    Percent: Double;
  begin
    Percent := (Progress / Total) * 100;
    Pos     := Round(BarWidth * (Progress / Total));
    Write('[');
    Write(StringOfChar('=', Pos));
    if Pos < BarWidth then
      Write('>');
    Write(StringOfChar(' ', BarWidth - Pos));
    Write('] ');
    Write(Format('%3d%%', [ Round(Percent) ]));
    Write(#13);
    if Progress = Total then
      Writeln;
  end;

/// <summary>
/// Pads the given value with a specified number of characters in the specified direction.
/// </summary>
/// <param name="Value">The value to be padded.</param>
/// <param name="Padding">The number of characters to pad.</param>
/// <param name="Direction">The direction in which to pad the value. Possible values are 'Left' or 'Right'.</param>
/// <returns>The padded value.</returns>
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

/// <summary>
/// Generates a string by joining the elements of the given array using the '+' separator.
/// </summary>
/// <param name="MappingColumns">An array of strings representing the mapping columns.</param>
/// <returns>A string containing the joined elements of the array.</returns>
function GenerateIDColumns(MappingColumns: TArray<string>): string;
  begin
    Result := String.Join('+', MappingColumns);
  end;

/// <summary>
/// Generates an ID value based on the given query and mapping columns.
/// </summary>
/// <param name="Query">The TFDQuery object used to execute the query.</param>
/// <param name="MappingColumns">An array of strings representing the mapping columns.</param>
/// <returns>A string representing the generated ID value.</returns>
function GenerateIDValue(Query: TFDQuery; MappingColumns: TArray<string>): string;
  var
    I: Integer;
  begin
    Result   := '';
    for I    := 0 to High(MappingColumns) do
      Result := Result + Query.FieldByName(MappingColumns[ I ]).AsString;
  end;

end.
