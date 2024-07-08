unit uHelpers;

interface

uses
  System.SysUtils;

const
  RESET = #27'[0m';
  GREEN = #27'[32m';
  YELLOW = #27'[33m';
  RED = #27'[31m';
  BLUE = #27'[34m';
  CYAN = #27'[36m';
  MAGENTA = #27'[35m';

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

procedure ShowProgressBar(Progress, Total: Integer);
const
  BarWidth = 50;
var
  Pos: Integer;
  Percent: Double;
begin
  Percent := (Progress / Total) * 100;
  Pos := Round(BarWidth * (Progress / Total));
  Write('[');
  Write(StringOfChar('=', Pos));
  if Pos < BarWidth then
    Write('>');
  Write(StringOfChar(' ', BarWidth - Pos));
  Write('] ');
  Write(Format('%3d%%', [Round(Percent)]));
  Write(#13);
  if Progress = Total then
    Writeln;
end;

end.

