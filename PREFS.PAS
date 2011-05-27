unit Prefs;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, RXSpin, EPGfxCmp, ExtCtrls, Nicetabs, RXSlider,
  Buttons;

type
  TScreenSaver = (ssBounce, ssRandomPosition);
  TScreenSaverInfo =
    record
      SaverSpeed : Integer;           { set in preferences }
      SaverType : TScreenSaver;  { set in preferences }
    end;

  TPrefsPage = (ppGeneral, ppScreenSaver);
  TfrmPrefs = class(TForm)
    tabPages: TNiceTab;
    nbkPages: TNiceNotebook;
    brdGeneral: TEPBorder;
    lblChangePrompt: TLabel;
    spnAutoChangeMinutes: TRxSpinEdit;
    brdShowItemTypes: TEPBorder;
    cbxShowItemTypes: TComboBox;
    rgpSaverStyle: TRadioGroup;
    gbxSpeed: TGroupBox;
    sldSpeed: TRxSlider;
    lblSpeedSlow: TLabel;
    lblSpeedFast: TLabel;
    pnlButtons: TPanel;
    btnOk: TBitBtn;
    btnCancel: TBitBtn;
    procedure tabPagesClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    { Private declarations }
    procedure SetPage(APage : TPrefsPage);
    procedure TransferData(ASave : Boolean);
  public
    property Page : TPrefsPage write SetPage;
  end;

procedure ReadConfigData;

var
  frmPrefs: TfrmPrefs;
  SaverInfo : TScreenSaverInfo;

implementation

uses Main;

{$R *.DFM}

procedure ReadConfigData;
begin
  SaverInfo.SaverType := TScreenSaver(GetProfileInt('DailyIslam', 'SSType', Ord(ssBounce)));
  SaverInfo.SaverSpeed := GetProfileInt('DailyIslam', 'SSSpeed', 1);
end;

procedure TfrmPrefs.FormCreate(Sender: TObject);
begin
  Page := ppScreenSaver;
  TransferData(False);
end;

procedure TfrmPrefs.TransferData(ASave : Boolean);
var
  szBuf : array[0..10] of Char;
begin
  if ASave then begin
    SaverInfo.SaverType := TScreenSaver(rgpSaverStyle.ItemIndex);
    SaverInfo.SaverSpeed := sldSpeed.Value;
    if SaverInfo.SaverType = ssRandomPosition then
      SaverInfo.SaverSpeed := sldSpeed.MaxValue - sldSpeed.Value;

    WriteProfileString('DailyIslam', 'SSType', StrPCopy(szBuf, IntToStr(Ord(SaverInfo.SaverType))));
    WriteProfileString('DailyIslam', 'SSSpeed', StrPCopy(szBuf, IntToStr(SaverInfo.SaverSpeed)));
  end else begin
    rgpSaverStyle.ItemIndex := Ord(SaverInfo.SaverType);
    sldSpeed.Value := SaverInfo.SaverSpeed;
    if SaverInfo.SaverType = ssRandomPosition then
      sldSpeed.Value := Abs(SaverInfo.SaverSpeed - sldSpeed.MaxValue);
  end;
end;

procedure TfrmPrefs.SetPage(APage : TPrefsPage);
begin
  tabPages.TabIndex := Ord(APage);
  nbkPages.ActivePageIndex := Ord(APage);
end;

procedure TfrmPrefs.tabPagesClick(Sender: TObject);
begin
  Page := TPrefsPage(tabPages.TabIndex);
end;

procedure TfrmPrefs.btnOkClick(Sender: TObject);
begin
  TransferData(True);
  Close;
end;

procedure TfrmPrefs.btnCancelClick(Sender: TObject);
begin
  Close;
end;

end.
