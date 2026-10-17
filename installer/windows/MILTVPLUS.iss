#define MyAppName "MILTVPLUS"
#define MyAppPublisher "MILTVPLUS"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\\..\\build\\windows\\x64\\runner\\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\\..\\dist"
#endif

[Setup]
AppId={{B3E5A2C1-4F76-4E7D-9B18-2C7A8D5F3106}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\\MILTVPLUS
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
OutputDir={#OutputDir}
OutputBaseFilename=MILTVPLUS-Setup-v{#AppVersion}-Windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\\miltv_plus.exe
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\\MILTVPLUS"; Filename: "{app}\\miltv_plus.exe"
Name: "{autodesktop}\\MILTVPLUS"; Filename: "{app}\\miltv_plus.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\\miltv_plus.exe"; Description: "Launch MILTVPLUS"; Flags: postinstall nowait skipifsilent
