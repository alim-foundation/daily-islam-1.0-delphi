unit Database;

interface

uses Classes, SysUtils, Graphics, StColl, StDict, MdString, ReadFile;

const
  MAX_LINE_SIZE = 4096; { maximum length of a single import line }
type
{   Logical Structure of containers
    TDailyIslamDB
      +-- TLibrary 1
            +-- TSubject 1
                  +-- TTextItem 1
                  +-- TTextItem 2
            +-- TSubject 2
                  +-- TTextItem 1
                  +-- TTextItem 2
                  +-- TTextItem 3
                  +-- TTextItem 4
            +-- TSubject 1
                  +-- TTextItem 1
      +-- TLibrary 2
            +-- TSubject x
                  +-- TTextItem x
                  +-- TTextItem y
            +-- TSubject y
                  +-- TTextItem x
                  +-- TTextItem y
                  +-- TTextItem z
                  +-- TTextItem a
            +-- TSubject z
                  +-- TTextItem z
  }

  TTextItem = class;     { lowest level object }
  TSubject = class;      { container of one or more TTextItem instances }
  TLibrary = class;      { container of one or more TSubject instances }
  TDailyIslamDB = class; { container of one or more TLibrary instances }

  TTextItem = class
  private
    FSource : PChar;
    FText : PChar;

    procedure SetSource(const pszSource : PChar);
    procedure SetText(const pszText : PChar);
  public
    constructor Create;
    destructor Destroy; override;
    property Source : PChar read FSource write SetSource;
    property Text : PChar read FText write SetText;
  end;

  TNamedCollection = class(TStCollection)
  protected
    FCollectionName : String;
    FStyle : TStringList;
    FParentStyle : Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property Name : String read FCollectionName write FCollectionName;
    property Style : TStringList read FStyle;
    property ParentStyle : Boolean read FParentStyle write FParentStyle;
  end;

  TItemDisplayInfo =
    record
      TextItem : TTextItem;
      Lib : TLibrary;
      Subject : TSubject;
      Style : TStringList;
    end;

  TSubject = class(TNamedCollection)   { collection of TTextItem instances }
  protected
    FParent : TLibrary;
  public
    constructor Create(AParent : TLibrary);
    function PickRandomItem : TItemDisplayInfo;

    property Parent : TLibrary read FParent;
  end;

  TLibrary = class(TNamedCollection)   { collection of TSubject instances }
  protected
    FItemIs : String;
    FParent : TDailyIslamDB;

    function GetSubject(Index : Integer) : TSubject;
  public
    constructor Create(AParent : TDailyIslamDB);

    function PickRandomItem : TItemDisplayInfo;
    property ItemIs : String read FItemIs write FItemIs;
    property Parent : TDailyIslamDB read FParent;
    property Subjects[Index : Integer] : TSubject read GetSubject;
  end;

  TDailyIslamDB = class(TStCollection)    { collection of TLibary instances }
  protected
    FGlobalTextStyle : TStringList;
    FDailyPrayerFmt : TStringList;
    FMonthlyPrayerFmt : TStringList;
    FMultiDayPrayerRowFmt : TStringList;

    function GetLibrary(Index : Integer) : TLibrary;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ImportFromFile(const strFilename : String);

    function FindLibrary(const strLibName : String; var FoundIndex : Integer) : TLibrary;
    function PickRandomItemFromLib(const strLibName : String) : TItemDisplayInfo;

    property GlobalStyle : TStringList read FGlobalTextStyle;
    property DailyPrayerFmt : TStringList read FDailyPrayerFmt;
    property MonthlyPrayerFmt : TStringList read FMonthlyPrayerFmt;
    property MultiDayPrayerRowFmt : TStringList read FMultiDayPrayerRowFmt;
    property Libraries[Index : Integer] : TLibrary read GetLibrary;
  end;

implementation

uses StStrS;

constructor TTextItem.Create;
begin
  inherited Create;
end;

destructor TTextItem.Destroy;
begin
  StrDispose(FText);
  StrDispose(FSource);
  inherited Destroy;
end;

procedure TTextItem.SetSource(const pszSource : PChar);
begin
  StrDispose(FSource);
  FSource := StrNew(pszSource);
end;

procedure TTextItem.SetText(const pszText : PChar);
begin
  StrDispose(FText);
  FText := StrNew(pszText);
end;

{--------------------------------------------------------------------}

procedure DisposeOfObject(Data : Pointer); far;
begin
  TObject(Data).Free;
end;

constructor TNamedCollection.Create;
const
  nCreateCount : Integer = 0;
begin
  inherited Create(16);
  Inc(nCreateCount);
  FCollectionName := 'Default'+IntToStr(nCreateCount);
  FStyle := TStringList.Create;
  FParentStyle := True;
  DisposeData := DisposeOfObject;
end;

destructor TNamedCollection.Destroy;
begin
  FStyle.Free;
  inherited Destroy;
end;

{--------------------------------------------------------------------}

constructor TSubject.Create(AParent : TLibrary);
begin
  inherited Create;
  FParent := AParent;
end;

function TSubject.PickRandomItem : TItemDisplayInfo;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Count <= 0 then
    Exit;

  Result.Lib := Parent;
  Result.Subject := Self;
  Result.TextItem := TTextItem(Items[Random(Count)]);

  { see whose formatting style we're going to use }
  if Self.ParentStyle and Parent.ParentStyle then
    Result.Style := Parent.Parent.GlobalStyle
  else if Self.ParentStyle and not Parent.ParentStyle then
    Result.Style := Parent.Style
  else
    Result.Style := Self.Style;
end;

{--------------------------------------------------------------------}

constructor TLibrary.Create(AParent : TDailyIslamDB);
begin
  inherited Create;
  FParent := AParent;
end;

function TLibrary.GetSubject(Index : Integer) : TSubject;
begin
  Result := TSubject(Items[Index]);
end;

function TLibrary.PickRandomItem : TItemDisplayInfo;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Count <= 0 then
    Exit;

  Result := Subjects[Random(Count)].PickRandomItem;
end;
{--------------------------------------------------------------------}

type
  TExpectLine = (elMetaCmd, elCompleteTextItem, elStyle);
  TDatabaseReader = class(TControlFileReader)
  protected
    FDatabase : TDailyIslamDB;
    FCurLibrary : TLibrary;
    FCurSubject : TSubject;
    FExpectLine : TExpectLine;

    procedure OnCmd(strCmd, strParams : String); override;
    procedure OnData(pszLine : PChar); override;
  public
    procedure Process; override;
    property Database : TDailyIslamDB read FDatabase write FDatabase;
  end;

  procedure TDatabaseReader.OnData(pszLine : PChar);
  const
    szSrcDelim : PChar = ' --> ';
  var
    NewItem : TTextItem;
    pchSourcePos : PChar;
    strSource : String;
  begin
    case FExpectLine of
      elMetaCmd :
        raise Exception.CreateFmt('Expecting a metacmd at line %d', [FLineNumber]);

      elCompleteTextItem : begin
          if FCurSubject = Nil then
            raise Exception.CreateFmt('Adding text to non-existant subject at line %d', [FLineNumber]);

          { find source }
          pchSourcePos := StrPos(pszLine, szSrcDelim);
          if pchSourcePos <> Nil then begin
            pchSourcePos[0] := #0;   { end the szStrBuf string where delim was found }
            pchSourcePos := pchSourcePos + StrLen(szSrcDelim);  { get real position of source string }
            strSource := StrPas(pchSourcePos);
          end;

          NewItem := TTextItem.Create;
          NewItem.Source := pchSourcePos;
          NewItem.Text := pszLine;
          FCurSubject.Insert(NewItem);
        end;

     elStyle : begin
          if FCurSubject <> nil then
            FCurSubject.Style.Add(StrPas(pszLine))
          else if FCurLibrary <> nil then
            FCurLibrary.Style.Add(StrPas(pszLine))
          else
            FDatabase.GlobalStyle.Add(StrPas(pszLine));
        end;

     else
       raise Exception.CreateFmt('Unknown expected line type %d at line %d', [Ord(FExpectLine), FLineNumber]);
    end;
  end;

  procedure TDatabaseReader.OnCmd(strCmd, strParams : String);
  begin
    if CompareText(strCmd, 'Library') = 0 then begin
      if FDatabase = nil then
        raise Exception.CreateFmt('Can not add library without FLibraries at line %d', [FLineNumber]);
      if strParams = '' then
        raise Exception.CreateFmt('Cmd %s given with no parameters at line %d', [strCmd, FLineNumber]);

      FCurLibrary := TLibrary.Create(FDatabase);
      if WordCountS(strParams, ':') = 1 then begin
        FCurLibrary.Name := strParams;
        FCurLibrary.ItemIs := strParams;
      end else begin
        FCurLibrary.Name := ExtractWordS(1, strParams, ':');
        FCurLibrary.ItemIs := ExtractWordS(2, strParams, ':');
      end;

      FDatabase.Insert(FCurLibrary);
      FCurSubject := Nil;
      FExpectLine := elMetaCmd;
    end else if CompareText(strCmd, 'Subject') = 0 then begin
      if FCurLibrary = nil then
        raise Exception.CreateFmt('Subject can not be added without library at line %d.', [FLineNumber]);

      if strParams = '' then
        raise Exception.CreateFmt('Cmd %s given with no parameters at line %d', [strCmd, FLineNumber]);

      FCurSubject := TSubject.Create(FCurLibrary);
      FCurSubject.Name := strParams;
      FCurLibrary.Insert(FCurSubject);
      FExpectLine := elCompleteTextItem;
    end else if CompareText(strCmd, 'Style') = 0 then begin
      if FCurSubject <> nil then begin
        FCurSubject.ParentStyle := False;
        FCurSubject.Style.Clear;
      end else if FCurLibrary <> nil then begin
        FCurLibrary.ParentStyle := False;
        FCurLibrary.Style.Clear;
      end else
        FDatabase.GlobalStyle.Clear;
      FExpectLine := elStyle;
    end else if CompareText(strCmd, 'EndStyle') = 0 then begin
      FExpectLine := elCompleteTextItem;
    end else
      raise Exception.CreateFmt('Unknown Cmd %s', [strCmd]);
  end;

  procedure TDatabaseReader.Process;
  begin
    FExpectLine := elMetaCmd;
    inherited Process;
  end;

{--------------------------------------------------------------------}

constructor TDailyIslamDB.Create;
begin
  inherited Create(16);
  FGlobalTextStyle := TStringList.Create;
  FDailyPrayerFmt := TStringList.Create;
  FMonthlyPrayerFmt := TStringList.Create;
  FMultiDayPrayerRowFmt := TStringList.Create;
  DisposeData := DisposeOfObject;

  FGlobalTextStyle.Add('$text<p align=right>-- <i>$textSource');
end;

destructor TDailyIslamDB.Destroy;
begin
  FGlobalTextStyle.Free;
  FDailyPrayerFmt.Free;
  FMonthlyPrayerFmt.Free;
  FMultiDayPrayerRowFmt.Free;
  inherited Destroy;
end;

function TDailyIslamDB.GetLibrary(Index : Integer) : TLibrary;
begin
  Result := TLibrary(Items[Index]);
end;

function TDailyIslamDB.FindLibrary(const strLibName : String; var FoundIndex : Integer) : TLibrary;
var
  nIdx : Integer;
begin
  Result := Nil;
  FoundIndex := -1;
  if Count <= 0 then
    Exit;

  for nIdx := 0 to Count-1 do
    if CompareText(TLibrary(Items[nIdx]).Name, strLibName) = 0 then begin
      FoundIndex := nIdx;
      Result := TLibrary(Items[nIdx]);
      Exit;
    end;
end;

function TDailyIslamDB.PickRandomItemFromLib(const strLibName : String) : TItemDisplayInfo;
var
  Lib : TLibrary;
  LibIdx : Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Count <= 0 then
    Exit;

  if Length(strLibName) = 0 then
    Lib := Items[Random(Count)]
  else
    Lib := FindLibrary(strLibName, LibIdx);

  if Lib <> nil then
    Result := Lib.PickRandomItem;
end;

procedure TDailyIslamDB.ImportFromFile(const strFilename : String);
var
  Reader : TDatabaseReader;
begin
  Clear;

  Reader := TDatabaseReader.Create;
  try
    Reader.Database := Self;
    Reader.FileName := strFilename;
    Reader.Process;
  finally
    Reader.Free;
  end;
end;

end.
