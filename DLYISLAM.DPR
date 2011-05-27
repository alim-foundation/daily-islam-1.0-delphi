program DlyIslam;

uses
  Forms,
  SysUtils,
  StStrS,
  Dialogs,
  Main in 'MAIN.PAS' {frmMain},
  Prefs in 'PREFS.PAS' {frmPrefs};

{$D SCRNSAVE DailyIslam}
{$R *.RES}

begin
  AppIsScreenSaver := JustExtensionS(Application.ExeName) = 'SCR';
  Application.Title := 'DailyIslam';

  ReadConfigData;
  Randomize;

  { don't bother creating the mainform if we're just changing settings for screen saver }
  if (not AppIsScreenSaver) or
     (AppIsScreenSaver and (UpCase(ParamStr(1)[2]) <> 'C')) then
    Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TfrmPrefs, frmPrefs);

  Application.Run;
end.
