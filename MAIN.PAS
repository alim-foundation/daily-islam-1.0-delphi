unit Main;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, Htmlview, ExtCtrls, SpeedBar, StdCtrls, RXCtrls,
  ToolEdit, Grids, EPStdCmp, Menus, VCLUtils, MaxMin, StStrS, Database,
  EPGfxCmp, TimerLst, StDate, Placemnt, PGDsgFrm, PGSubCls;

type
  TAppMode = (amNormal, amScreenSaver);
  TfrmMain = class(TForm)
    pmMain: TPopupMenu;
    pnlMainContainer: TPanel;
    vwrData: THTMLViewer;
    tmrMain: TRxTimerList;
    tmeSaverBounceEvent: TRxTimerEvent;
    tmeSaverRandomMoveEvent: TRxTimerEvent;
    pmiMainConfigure: TMenuItem;
    pmiMainStartScrnSaver: TMenuItem;
    pmiMainBreak1: TMenuItem;
    frmPlacement: TFormPlacement;
    cbarMain: TPGCaptionBar;
    PGCaptionBarGlyph1: TPGCaptionBarGlyph;
    PGCaptionBarSystemButton1: TPGCaptionBarSystemButton;
    PGCaptionBarButton1: TPGCaptionBarButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure pmMainPopup(Sender: TObject);
    procedure AnotherRandomLibItemClick(Sender: TObject);
    procedure AnotherRandomSubjItemClick(Sender: TObject);
    procedure tmeSaverBounceEventTimer(Sender: TObject);
    procedure tmeSaverRandomMoveEventTimer(Sender: TObject);
    procedure pmiMainConfigureClick(Sender: TObject);
    procedure pmiMainStartScrnSaverClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
  private
    FAppLocation : String;
    FDatabase : TDailyIslamDB;
    FDisplayItem : TItemDisplayInfo;
    FBeforeSaverModeRect : TRect;
    FAppMode : TAppMode;
    FCursorStartPos : TPoint;

    procedure DeactivateScrnSaver(var Msg : TMsg; var Handled : boolean);
    procedure DisplayModified;
    procedure SetAppMode(AMode : TAppMode);
  public
    procedure LoadText(Display : TItemDisplayInfo);
    procedure LoadRandomText(strLibName : String);
    property Database : TDailyIslamDB read FDatabase;
    property AppMode : TAppMode read FAppMode write SetAppMode;
  end;

const
  AppIsScreenSaver : Boolean = False;
var
  frmMain: TfrmMain;

implementation

{$R *.DFM}

uses MdString, Prefs;

var
  XSpeed, YSpeed : Integer;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  szBuf : array[0..255] of Char;
  strDBFName : String;
begin
  GetProfileString('DailyIslam', 'AppDir', '', szBuf, 255);
  FAppLocation := StrPas(szBuf);
  if Length(FAppLocation) = 0 then
    raise Exception.Create('DailyIslam application directory not specified in WIN.INI, please run Setup again.');

  strDBFName := AddBackSlashS(FAppLocation)+'DLYISLAM.DAT';
  if not FileExists(strDBFName) then
    raise Exception.CreateFmt('DailyIslam datafile %s not found, please run Setup again.', [strDBFName]);

  FDatabase := TDailyIslamDB.Create;
  FDatabase.ImportFromFile(strDBFName);
  PGCaptionBarSystemButton1.BevelWidth := 1;

  LoadRandomText('');

  if AppIsScreenSaver then
    AppMode := amScreenSaver
  else
    AppMode := amNormal;
end;

procedure TfrmMain.FormActivate(Sender: TObject);
const
  FirstTime : Boolean = True;
begin
  if FirstTime then begin
    DisplayModified;
    { tmrMain.Active := True; }
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FDatabase.Free;
end;

procedure TfrmMain.DeactivateScrnSaver(var Msg : TMsg; var Handled : boolean);
var
  done : boolean;
begin
  {if Msg.message = WM_MOUSEMOVE then
    done := (Abs(LOWORD(Msg.lParam) - FCursorStartPos.x) > 5) or
            (Abs(HIWORD(Msg.lParam) - FCursorStartPos.y) > 5)
  else}
    done := (Msg.message = WM_KEYDOWN)     or (Msg.message = WM_KEYUP)       or
            (Msg.message = WM_SYSKEYDOWN)  or (Msg.message = WM_SYSKEYUP)    or
            (Msg.message = WM_ACTIVATE)    or (Msg.message = WM_NCACTIVATE)  or
            (Msg.message = WM_ACTIVATEAPP) or (Msg.message = WM_LBUTTONDOWN) or
            (Msg.message = WM_RBUTTONDOWN) or (Msg.message = WM_MBUTTONDOWN);
  if done then begin
    if AppIsScreenSaver then
      Close
    else begin
      SetBounds(FBeforeSaverModeRect.Left, FBeforeSaverModeRect.Top,
                FBeforeSaverModeRect.Right-FBeforeSaverModeRect.Left,
                FBeforeSaverModeRect.Bottom-FBeforeSaverModeRect.Top);
      AppMode := amNormal;
    end;
  end;
end;

procedure TfrmMain.DisplayModified;
const
  MinWinHeight = 50;
var
  OptimalSize : LongInt;
begin
  OptimalSize := Max(vwrData.MaxVertPixels+3, MinWinHeight);
  if FAppMode = amScreenSaver then
    pnlMainContainer.Height := OptimalSize
  else
    ClientHeight := OptimalSize+7;
end;

procedure TfrmMain.SetAppMode(AMode : TAppMode);
begin
  FAppMode := AMode;
  case FAppMode of
    amNormal : begin
        BorderStyle := bsSizeable;
        pnlMainContainer.Align := alClient;
        tmeSaverBounceEvent.Enabled := False;
        tmeSaverRandomMoveEvent.Enabled := False;
        Application.OnMessage := Nil;
      end;

    amScreenSaver : begin
        { setup the window first }
        FBeforeSaverModeRect := BoundsRect;
        BorderStyle := bsNone;
        pnlMainContainer.Align := alNone;
        SetBounds(0, 0, Screen.Width, Screen.Height);

        { now setup the saver }
        GetCursorPos(FCursorStartPos);
        Application.OnMessage := DeactivateScrnSaver;

        XSpeed := Trunc(SaverInfo.SaverSpeed * 1.5);
        YSpeed := SaverInfo.SaverSpeed * 1;

        tmeSaverBounceEvent.Enabled := False;
        tmeSaverRandomMoveEvent.Enabled := False;

        tmeSaverBounceEvent.Enabled := SaverInfo.SaverType = ssBounce;
        tmeSaverRandomMoveEvent.Enabled := SaverInfo.SaverType = ssRandomPosition;

        { setup current location from which moves will occur }
        pnlMainContainer.left := Max(random(width) - pnlMainContainer.width, 0);
        pnlMainContainer.top := Max(random(height) - pnlMainContainer.height, 0);
      end;
  end;
  DisplayModified;
end;

procedure TfrmMain.LoadText(Display : TItemDisplayInfo);
var
  szStyleFmt : array[0..8192] of Char;
begin
  FDisplayItem := Display;

  if FDisplayItem.TextItem = nil then
    raise Exception.Create('Nothing to display in LoadText');

  { now copy the format into our working buffer }
  StrCopy(szStyleFmt, FDisplayItem.Style.GetText);

  ReplaceAppVarsInZ(szStyleFmt, FAppLocation);
  ReplaceWithStr(szStyleFmt, '${itemLibrary}', FDisplayItem.Lib.Name);
  ReplaceWithStr(szStyleFmt, '${itemSubject}', FDisplayItem.Subject.Name);
  if FDisplayItem.TextItem.Text <> Nil then
    Replace(szStyleFmt, '${itemText}', FDisplayItem.TextItem.Text);
  if FDisplayItem.TextItem.Source <> Nil then
    Replace(szStyleFmt, '${itemSource}', FDisplayItem.TextItem.Source);

  vwrData.LoadFromBuffer(szStyleFmt, StrLen(szStyleFmt));
  DisplayModified;
end;

procedure TfrmMain.LoadRandomText(strLibName : String);
begin
  LoadText(FDatabase.PickRandomItemFromLib(strLibName));
end;

procedure TfrmMain.pmMainPopup(Sender: TObject);
const
  FixedMenuItems = 3;
var
  Idx : Integer;
  Lib : TLibrary;
  Subject : TSubject;
  Submenu, MI : TMenuItem;
  Caption : String;
begin
  if FDatabase.Count <= 0 then
    Exit;

  while pmMain.Items.Count > FixedMenuItems do
    pmMain.Items[0].Free;

  for Idx := 0 to FDatabase.Count-1 do begin
    Lib := FDatabase.Libraries[Idx];

    FmtStr(Caption, 'Another %s', [Lib.ItemIs]);
    MI := TMenuItem.Create(Self);
    MI.Caption := Caption;
    MI.OnClick := AnotherRandomLibItemClick;
    MI.Tag := LongInt(Lib);
    pmMain.Items.Insert(pmMain.Items.Count-FixedMenuItems, MI);
  end;

  if FDisplayItem.Lib <> Nil then
    if FDisplayItem.Lib.Count > 1 then begin
      pmMain.Items.Insert(pmMain.Items.Count-FixedMenuItems, NewLine);

      FmtStr(Caption, 'Another %s in current subject', [FDisplayItem.Lib.ItemIs]);
      MI := TMenuItem.Create(Self);
      MI.Caption := Caption;
      MI.OnClick := AnotherRandomSubjItemClick;
      MI.Tag := LongInt(FDisplayItem.Subject);
      pmMain.Items.Insert(pmMain.Items.Count-FixedMenuItems, MI);

      FmtStr(Caption, 'Another %s in particular subject', [FDisplayItem.Lib.ItemIs]);
      Submenu := TMenuItem.Create(Self);
      Submenu.Caption := Caption;
      pmMain.Items.Insert(pmMain.Items.Count-FixedMenuItems, Submenu);

      for Idx := 0 to FDisplayItem.Lib.Count-1 do begin
        Subject := FDisplayItem.Lib.Subjects[Idx];

        MI := TMenuItem.Create(Self);
        MI.Caption := Subject.Name;
        MI.OnClick := AnotherRandomSubjItemClick;
        MI.Tag := LongInt(Subject);
        Submenu.Add(MI);
      end;
    end;
end;

procedure TfrmMain.AnotherRandomLibItemClick(Sender: TObject);
var
  Lib : TLibrary;
begin
  Lib := TLibrary((Sender as TMenuItem).Tag);
  LoadText(Lib.PickRandomItem);
end;

procedure TfrmMain.AnotherRandomSubjItemClick(Sender: TObject);
var
  Subject : TSubject;
begin
  Subject := TSubject((Sender as TMenuItem).Tag);
  LoadText(Subject.PickRandomItem);
end;

procedure TfrmMain.tmeSaverBounceEventTimer(Sender: TObject);
begin
  pnlMainContainer.top := pnlMainContainer.top + YSpeed;
  pnlMainContainer.left := pnlMainContainer.left + XSpeed;

  if pnlMainContainer.top <= 0 then
    YSpeed := 0 - YSpeed;
  if pnlMainContainer.left <= 0 then
    XSpeed := 0 - XSpeed;
  if pnlMainContainer.top >= height - pnlMainContainer.height then
    YSpeed := 0 - YSpeed;
  if pnlMainContainer.left >= width - pnlMainContainer.width then
    XSpeed := 0 - XSpeed;
end;

procedure TfrmMain.tmeSaverRandomMoveEventTimer(Sender: TObject);
const
  Before : TStTime = -1;
var
  Start, Elapsed : TStTime;
begin
  if Before = -1 then
    Before := CurrentTime;

  Start := CurrentTime;
  Elapsed := Start - Before;
  if Elapsed < 0 then
    Inc(Elapsed, SecondsInDay);

  if Elapsed > SaverInfo.SaverSpeed then begin
    pnlMainContainer.left := Max(random(width) - pnlMainContainer.width, 0);
    pnlMainContainer.top := Max(random(height) - pnlMainContainer.height, 0);
    Before := Start;
  end;
end;

procedure TfrmMain.pmiMainConfigureClick(Sender: TObject);
begin
  frmPrefs.ShowModal;
end;

procedure TfrmMain.pmiMainStartScrnSaverClick(Sender: TObject);
begin
  AppMode := amScreenSaver;
end;

end.
