unit uLogger;

interface

uses
  uHelpers,
  System.SysUtils;

type
  TLogger = class
  private
    FInfo   : Boolean;
    FDebug  : Boolean;
    FError  : Boolean;
    FWarning: Boolean;
    procedure SetInfo(Value: Boolean);
    procedure SetDebug(Value: Boolean);
    procedure SetError(Value: Boolean);
    procedure SetWarning(Value: Boolean);
    function GetInfo: Boolean;
    function GetDebug: Boolean;
    function GetError: Boolean;
    function GetWarning: Boolean;
  public
    constructor Create(AInfo, ADebug, AError, AWarning: Boolean); // Constructor with parameters
    property Info: Boolean read GetInfo write SetInfo;
    property Debug: Boolean read GetDebug write SetDebug;
    property Error: Boolean read GetError write SetError;
    property Warning: Boolean read GetWarning write SetWarning;

    procedure LogInfo(const DateTimeText, MessageText: string);
    procedure LogError(const DateTimeText, MessageText: string);
    procedure LogDebug(const DateTimeText, MessageText: string);
    procedure LogWarning(const DateTimeText, MessageText: string);

  end;

implementation

{ TLogSettings }
constructor TLogger.Create(AInfo, ADebug, AError, AWarning: Boolean);
  begin
    FInfo    := AInfo;
    FDebug   := ADebug;
    FError   := AError;
    FWarning := AWarning;
  end;

function TLogger.GetInfo: Boolean;
  begin
    Result := FInfo;
  end;

function TLogger.GetDebug: Boolean;
  begin
    Result := FDebug;
  end;

function TLogger.GetError: Boolean;
  begin
    Result := FError;
  end;

function TLogger.GetWarning: Boolean;
  begin
    Result := FWarning;
  end;

procedure TLogger.SetInfo(Value: Boolean);
  begin
    FInfo := Value;
  end;

procedure TLogger.SetDebug(Value: Boolean);
  begin
    FDebug := Value;
  end;

procedure TLogger.SetError(Value: Boolean);
  begin
    FError := Value;
  end;

procedure TLogger.SetWarning(Value: Boolean);
  begin
    FWarning := Value;
  end;

procedure TLogger.LogInfo(const DateTimeText, MessageText: string);
  begin
    if FInfo then
    begin
      WriteColoredLine(DateTimeText, MessageText, LIGHT_BLUE, BRIGHT_CYAN)
    end;
  end;

procedure TLogger.LogError(const DateTimeText, MessageText: string);
  begin
    if FError then
    begin
      WriteColoredLine(DateTimeText, MessageText, LIGHT_BLUE, BRIGHT_RED)
    end;
  end;

procedure TLogger.LogDebug(const DateTimeText, MessageText: string);
  begin
    if FDebug then
    begin
      WriteColoredLine(DateTimeText, MessageText, LIGHT_BLUE, WHITE)
    end;
  end;

procedure TLogger.LogWarning(const DateTimeText, MessageText: string);
  begin
    if FWarning then
    begin
      WriteColoredLine(DateTimeText, MessageText, LIGHT_BLUE, YELLOW);
    end;
  end;

end.
