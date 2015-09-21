unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Grids, TlHelp32, ShellApi,
  IdBaseComponent, IdComponent, IdRawBase, IdRawClient, IdIcmpClient, System.SyncObjs, IniFiles,
  EComponent, Vcl.ShellAnimations, Vcl.XPMan, IdTCPConnection, IdTCPClient,
  IdHTTP, Vcl.ExtCtrls, System.Generics.Collections;

const
  ZVersion = 5;

type
tEventListener = procedure(event: integer);cdecl;
tClientListener = procedure(ztype: PAnsiChar; value: PAnsiChar);cdecl;
tServerListener = procedure(id: integer; added: boolean);cdecl;
tServerListenerName = procedure(id: integer; value: PAnsiChar);cdecl;
tServerListenerAttr = procedure(id: integer; name: PAnsiChar; value: PAnsiChar);cdecl;
tServerListenerCap = procedure(id: integer; cap0: integer; cap1: integer);cdecl;
tServerListenerState = procedure(id: integer; value: integer);cdecl;
tServerListenerPlayers = procedure(id: integer; value: integer);cdecl;
tServerListenerAddr = procedure(id: integer; ip: PAnsiChar; port: integer);cdecl;
tZMessageListener = procedure(msg: PAnsiChar);cdecl;
tVersionListener = procedure(version: integer);cdecl;

  TServer = class
    public
      row:integer;
      name:string;
      state:integer;
      map,mode,pb:string;
      players,max_players:integer;
      ip:string;
      port:integer;
  end;

  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    serverlist: TStringGrid;
    Button2: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Pinger: TIdIcmpClient;
    XPManifest1: TXPManifest;
    UpdateTimer: TTimer;
    Button3: TButton;
    PingTimer: TTimer;
    Button4: TButton;
    Button5: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure UpdateTimerTimer(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure serverlistClick(Sender: TObject);
    procedure PingTimerTimer(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  DllHandle:THandle;
  serv: integer;
  mutex:TMutex;
  servers: TObjectDictionary<integer, TServer>;
  in_serverlist:bool;

implementation

var
ZLO_Init:procedure(); cdecl;
//Events
ZLO_SetEventListener:procedure(l: tEventListener); cdecl;
ZLO_SetClientListener:procedure(l: tClientListener); cdecl;
ZLO_SetServerListener:procedure(l: tServerListener); cdecl;
ZLO_SetServerListenerName:procedure(l: tServerListenerName); cdecl;
ZLO_SetServerListenerAttr:procedure(l: tServerListenerAttr); cdecl;
ZLO_SetServerListenerCap:procedure(l: tServerListenerCap); cdecl;
ZLO_SetServerListenerState:procedure(l: tServerListenerState); cdecl;
ZLO_SetServerListenerPlayers:procedure(l: tServerListenerPlayers); cdecl;
ZLO_SetServerListenerAddr:procedure(l: tServerListenerAddr); cdecl;
ZLO_SetZMessageListener:procedure(l: tZMessageListener); cdecl;
ZLO_SetVersionListener:procedure(l: tVersionListener); cdecl;
//Client
ZLO_ConnectMClient:function():boolean; cdecl;
ZLO_AuthClient:procedure(mail,pass:PAnsiChar); cdecl;
ZLO_GetServerList:procedure(); cdecl;
ZLO_SelectServer:procedure(id: integer); cdecl;
ZLO_RunMulti:function(): integer; cdecl;
ZLO_RunSingle:function(): integer; cdecl;
//
ZLO_GetVersion:procedure(launcher: integer); cdecl;
ZLO_Close:procedure(); cdecl;

{$R *.dfm}

function MapName(m:string):string;
begin
if m='MP_001' then
result:='Grand Bazaar'
else if m='MP_003' then
result:='Teheran Highway'
else if m='MP_007' then
result:='Caspian Border'
else if m='MP_011' then
result:='Seine Crossing'
else if m='MP_012' then
result:='Operation Firestorm'
else if m='MP_013' then
result:='Damavand Peak'
else if m='MP_017' then
result:='Noshahar Canals'
else if m='MP_018' then
result:='Kharg Island'
else if m='MP_Subway' then
result:='Operation Metro'
else if m='XP1_001' then
result:='Strike at Karkand'
else if m='XP1_002' then
result:='Gulf of Oman'
else if m='XP1_003' then
result:='Sharqi Peninsula'
else if m='XP1_004' then
result:='Wake Island'
else if m='XP2_Factory' then
result:='Scrapmetal'
else if m='XP2_Office' then
result:='Operation 925'
else if m='XP2_Palace' then
result:='Donya Fortress'
else if m='XP2_Skybar' then
result:='Ziba Tower'
else if m='XP3_Desert' then
result:='Bandar Desert'
else if m='XP3_Alborz' then
result:='Alborz Mountains'
else if m='XP3_Shield' then
result:='Armored Shield'
else if m='XP3_Valley' then
result:='Death Valley'
else if m='XP4_Quake' then
result:='Epicenter'
else if m='XP4_FD' then
result:='Markaz Monolith'
else if m='XP4_Parl' then
result:='Azadi Palace'
else if m='XP4_Rubble' then
result:='Talah Market'
else if m='XP5_001' then
result:='Operation Riverside'
else if m='XP5_002' then
result:='Nebandan Flats'
else if m='XP5_003' then
result:='Kiasar Railroad'
else if m='XP5_004' then
result:='Sabalan Pipeline'
else
result:=m;
end;

procedure ClearServers();
begin
mutex.Acquire;
form1.serverlist.RowCount:=1;
servers.Clear;
mutex.Release;
end;

procedure ReDraw;
var
i,id:integer;
begin
if in_serverlist then
exit;
i:=1;
form1.serverlist.RowCount:=servers.Count + 1;
if servers.Count>0 then
for id in servers.Keys do
begin
servers.Items[id].row:=i;
form1.serverlist.Rows[i][0]:=servers.Items[id].name;
case servers.Items[id].state of
1:form1.serverlist.Rows[i][1]:='Initializing';
130:form1.serverlist.Rows[i][1]:='Pre game';
131:form1.serverlist.Rows[i][1]:='In game';
141:form1.serverlist.Rows[i][1]:='Post game';
end;
form1.serverlist.Rows[i][2]:=servers.Items[id].map;
form1.serverlist.Rows[i][3]:=servers.Items[id].mode;
form1.serverlist.Rows[i][4]:=inttostr(servers.Items[id].players);
form1.serverlist.Rows[i][5]:=inttostr(servers.Items[id].max_players);
form1.serverlist.Rows[i][6]:=servers.Items[id].pb;
inc(i);
end;
if form1.serverlist.RowCount>1 then
form1.serverlist.FixedRows:=1;
end;

procedure EventListener(event: integer);cdecl;
begin
case event of
0:
begin
form1.Memo1.Lines.Add('Auth success');
ClearServers();
serv:=0;
form1.Button4.Enabled:=true;
form1.Button5.Enabled:=true;
in_serverlist:=false;
ZLO_GetVersion(1);
ZLO_GetServerList();
end;
1:begin form1.Memo1.Lines.Add('Auth error');form1.button1.Enabled:=true;form1.Button2.Enabled:=false;form1.Button5.Enabled:=false;end;
2:begin form1.Memo1.Lines.Add('Old Launcher.dll');form1.Button2.Enabled:=false;form1.Button5.Enabled:=false;form1.UpdateTimer.Enabled:=true;end;
3:begin
form1.Memo1.Lines.Add('Server select ok');
mutex.Acquire;
  if (serv>0) and servers.ContainsKey(serv) and (servers.Items[serv].ip<>'') then
  begin
    form1.Pinger.Host:=servers.Items[serv].ip;
    mutex.Release;
    form1.PingTimer.Enabled:=true;
  end
  else
    mutex.Release;
form1.Button2.Enabled:=true;
end;
4:begin form1.Memo1.Lines.Add('Server select not found');form1.Button2.Enabled:=false;end;
5:begin form1.Memo1.Lines.Add('Server select full');form1.Button2.Enabled:=false;end;
6:begin form1.Memo1.Lines.Add('Server select not ready');form1.Button2.Enabled:=false;end;
23:begin in_serverlist:=true;end;
24:begin in_serverlist:=false;mutex.Acquire;ReDraw;mutex.Release;end;
27:begin form1.Memo1.Lines.Add('Disconnected from master');form1.button1.Enabled:=true;form1.Button2.Enabled:=false;form1.Button5.Enabled:=false;ClearServers();end;
28:begin form1.Memo1.Lines.Add('Master timeout and disconnected');form1.button1.Enabled:=true;form1.Button2.Enabled:=false;form1.Button5.Enabled:=false;ClearServers();end;
666:begin form1.Memo1.Lines.Add('You are banned');form1.button1.Visible:=false;form1.Button2.Visible:=false;form1.Button5.Visible:=false;ClearServers();end;
else
form1.Memo1.Lines.Add('Event: ' + inttostr(event));
end
end;

procedure ClientListener(ztype: PAnsiChar; value: PAnsiChar);cdecl;
begin
form1.Memo1.Lines.Add('[' + ztype + '] ' + value);
end;

procedure ServerListener(id: integer; added: boolean);cdecl;
begin
mutex.Acquire;
if added and not servers.ContainsKey(id) then
servers.Add(id,TServer.Create())
else if servers.ContainsKey(id) then
servers.Remove(id);
ReDraw;
mutex.Release;
end;

procedure ServerListenerName(id: integer; value: PAnsiChar);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].name:=value;
if not in_serverlist then
form1.serverlist.Cols[0][servers.Items[id].row]:=value;
end;
mutex.Release;
end;

procedure ServerListenerAttr(id: integer; name: PAnsiChar; value: PAnsiChar);cdecl;
begin
if (name<>'level')and(name<>'mode')and(name<>'punkbuster') then
exit;
mutex.Acquire;
if servers.ContainsKey(id) then
begin
if name='level' then
begin
servers.Items[id].map:=MapName(value);
if not in_serverlist then
form1.serverlist.Cols[2][servers.Items[id].row]:=MapName(value);
end
else if name='mode' then
begin
servers.Items[id].mode:=value;
if not in_serverlist then
form1.serverlist.Cols[3][servers.Items[id].row]:=value;
end
else if name='punkbuster' then
begin
servers.Items[id].pb:=value;
if not in_serverlist then
form1.serverlist.Cols[6][servers.Items[id].row]:=value;
end;
end;
mutex.Release;
end;

procedure ServerListenerCap(id: integer; cap0: integer; cap1: integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].max_players:=cap0;
if not in_serverlist then
form1.serverlist.Cols[5][servers.Items[id].row]:=inttostr(cap0);
end;
mutex.Release;
end;

procedure ServerListenerState(id: integer; value: integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].state:=value;
if not in_serverlist then
case value of
1:form1.serverlist.Cols[1][servers.Items[id].row]:='Initializing';
130:form1.serverlist.Cols[1][servers.Items[id].row]:='Pre game';
131:form1.serverlist.Cols[1][servers.Items[id].row]:='In game';
141:form1.serverlist.Cols[1][servers.Items[id].row]:='Post game';
end;
end;
mutex.Release;
end;

procedure ServerListenerPlayers(id: integer; value: integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].players:=value;
if not in_serverlist then
form1.serverlist.Cols[4][servers.Items[id].row]:=inttostr(value);
end;
mutex.Release;
end;

procedure ServerListenerAddr(id: integer; ip: PAnsiChar; port:integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].ip:=ip;
servers.Items[id].port:=port;
end;
mutex.Release;
end;

procedure ZMessageListener(msg: PAnsiChar);cdecl;
begin
form1.Memo1.Lines.Add(msg);
end;

procedure VersionListener(version: integer);cdecl;
begin
if version <> ZVersion then
form1.Memo1.Lines.Add('Update launcher at http://bf3.zloemu.org/launchers');
end;

procedure InitLib();
begin
DllHandle:=LoadLibrary('Launcher.dll');
if Dllhandle<>0 then
begin
@ZLO_Init:=GetProcAddress(DllHandle, 'ZLO_Init');
//Events
@ZLO_SetEventListener:=GetProcAddress(DllHandle, 'ZLO_SetEventListener');
@ZLO_SetClientListener:=GetProcAddress(DllHandle, 'ZLO_SetClientListener');
@ZLO_SetServerListener:=GetProcAddress(DllHandle, 'ZLO_SetServerListener');
@ZLO_SetServerListenerName:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerName');
@ZLO_SetServerListenerAttr:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerAttr');
@ZLO_SetServerListenerCap:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerCap');
@ZLO_SetServerListenerState:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerState');
@ZLO_SetServerListenerPlayers:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerPlayers');
@ZLO_SetServerListenerAddr:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerAddr');
@ZLO_SetZMessageListener:=GetProcAddress(DllHandle, 'ZLO_SetZMessageListener');
@ZLO_SetVersionListener:=GetProcAddress(DllHandle, 'ZLO_SetVersionListener');
//Client
@ZLO_ConnectMClient:=GetProcAddress(DllHandle, 'ZLO_ConnectMClient');
@ZLO_AuthClient:=GetProcAddress(DllHandle, 'ZLO_AuthClient');
@ZLO_GetServerList:=GetProcAddress(DllHandle, 'ZLO_GetServerList');
@ZLO_SelectServer:=GetProcAddress(DllHandle, 'ZLO_SelectServer');
@ZLO_RunMulti:=GetProcAddress(DllHandle, 'ZLO_RunMulti');
@ZLO_RunSingle:=GetProcAddress(DllHandle, 'ZLO_RunSingle');
//
@ZLO_GetVersion:=GetProcAddress(DllHandle, 'ZLO_GetVersion');
@ZLO_Close:=GetProcAddress(DllHandle, 'ZLO_Close');
//
ZLO_Init();
ZLO_SetEventListener(@EventListener);
ZLO_SetClientListener(@ClientListener);
ZLO_SetServerListener(@ServerListener);
ZLO_SetServerListenerName(@ServerListenerName);
ZLO_SetServerListenerAttr(@ServerListenerAttr);
ZLO_SetServerListenerCap(@ServerListenerCap);
ZLO_SetServerListenerState(@ServerListenerState);
ZLO_SetServerListenerPlayers(@ServerListenerPlayers);
ZLO_SetServerListenerAddr(@ServerListenerAddr);
ZLO_SetZMessageListener(@ZMessageListener);
ZLO_SetVersionListener(@VersionListener);
serv:=0;
end
else
begin
showmessage('Some error with Launcher.dll');
Application.Terminate;
end;
end;

procedure UpdateLib();
var
Buffer: TFileStream;
HttpClient: TIdHttp;
begin
form1.Memo1.Lines.Add('Updating dll');
if DllHandle<>0 then
begin
ZLO_Close();
FreeLibrary(DllHandle);
end;
try
deletefile('Launcher.dll');
Buffer:=TFileStream.Create('Launcher.dll', fmCreate or fmShareDenyWrite);
except
begin
Buffer.Free;
form1.Memo1.Lines.Add('Error updating dll');
exit;
end;
end;
HttpClient:=TIdHttp.Create(nil);
try
HttpClient.Get('http://zloemu.org/files/bf3/Launcher.dll?d='+inttostr(random(9999999)), Buffer);
except
begin
form1.Memo1.Lines.Add('Error updating dll');
Buffer.Free;
HttpClient.Free;
exit;
end;
end;
Buffer.Free;
HttpClient.Free;
form1.Memo1.Lines.Add('Dll updated');
InitLib;
ClearServers();
if ZLO_ConnectMClient() then
begin
form1.button1.Enabled:=false;
form1.Memo1.Lines.Add('Connected to master');
ZLO_AuthClient(PAnsiChar(AnsiString(form1.edit1.Text)),PAnsiChar(AnsiString(form1.edit2.Text)));
end
else
form1.Memo1.Lines.Add('Cant connect to master');
end;

function processExists(): Boolean;
var
FSnapshotHandle: THandle;
FProcessEntry32: TProcessEntry32;
begin
FSnapshotHandle:=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
FProcessEntry32.dwSize:=SizeOf(FProcessEntry32);
result:=False;
if Process32First(FSnapshotHandle, FProcessEntry32) then
repeat
if UpperCase(ExtractFileName(FProcessEntry32.szExeFile))='BF3.EXE' then
result:=True;
until not Process32Next(FSnapshotHandle, FProcessEntry32) or result;
CloseHandle(FSnapshotHandle);
end;

procedure TForm1.Button1Click(Sender: TObject);
var
ini:tinifile;
begin
ini:=tinifile.Create(GetCurrentDir+'/Launcher.ini');
ini.WriteString('Conf','Login',edit1.Text);
ini.WriteString('Conf','Pass',edit2.Text);
ini.WriteInteger('Form','Left',form1.Left);
ini.WriteInteger('Form','Top',form1.Top);
ini.WriteInteger('Form','Height',form1.Height);
ini.WriteInteger('Form','Width',form1.Width);
ini.WriteInteger('Cols','0',serverlist.ColWidths[0]);
ini.WriteInteger('Cols','1',serverlist.ColWidths[1]);
ini.WriteInteger('Cols','2',serverlist.ColWidths[2]);
ini.WriteInteger('Cols','3',serverlist.ColWidths[3]);
ini.WriteInteger('Cols','4',serverlist.ColWidths[4]);
ini.WriteInteger('Cols','5',serverlist.ColWidths[5]);
ini.WriteInteger('Cols','6',serverlist.ColWidths[6]);
ini.Free;
ClearServers();
if ZLO_ConnectMClient() then
begin
button1.Enabled:=false;
Memo1.Clear;
Memo1.Lines.Add('Connected to master');
ZLO_AuthClient(PAnsiChar(AnsiString(edit1.Text)),PAnsiChar(AnsiString(edit2.Text)));
end
else
Memo1.Lines.Add('Cant connect to master');
end;

procedure TForm1.Button2Click(Sender: TObject);
var
z: integer;
begin
if processExists() then
begin
memo1.Lines.Add('bf3 already runned.');
exit;
end;
z:=ZLO_RunMulti();
if z <> 0 then
memo1.Lines.Add('Run error '+inttostr(z));
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
ShellExecute(0, 'open', PChar('http://zlobilling.org/services/donate-1'), '', '', SW_SHOWNORMAL);
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
ShellExecute(0, 'open', PChar('http://bf3.zloemu.org/stats'), '', '', SW_SHOWNORMAL);
end;

procedure TForm1.Button5Click(Sender: TObject);
var
z: integer;
begin
if processExists() then
begin
memo1.Lines.Add('bf3 already runned.');
exit;
end;
z:=ZLO_RunSingle();
if z <> 0 then
memo1.Lines.Add('Run error '+inttostr(z));
end;

procedure TForm1.FormCreate(Sender: TObject);
var
ini:tinifile;
begin
randomize;
servers:=TObjectDictionary<integer, TServer>.create();
mutex:=TMutex.Create();
if not fileexists('Launcher.dll') then
begin
showmessage('Launcher.dll not found');
Application.Terminate;
end;
ini:=tinifile.Create(GetCurrentDir+'/Launcher.ini');
edit1.Text:=ini.ReadString('Conf','Login','');
edit2.Text:=ini.ReadString('Conf','Pass','');
form1.Left:=ini.ReadInteger('Form','Left',0);
form1.Top:=ini.ReadInteger('Form','Top',0);
form1.Height:=ini.ReadInteger('Form','Height',347);
form1.Width:=ini.ReadInteger('Form','Width',871);
serverlist.ColWidths[0]:=ini.ReadInteger('Cols','0',189);
serverlist.ColWidths[1]:=ini.ReadInteger('Cols','1',58);
serverlist.ColWidths[2]:=ini.ReadInteger('Cols','2',134);
serverlist.ColWidths[3]:=ini.ReadInteger('Cols','3',136);
serverlist.ColWidths[4]:=ini.ReadInteger('Cols','4',49);
serverlist.ColWidths[5]:=ini.ReadInteger('Cols','5',64);
serverlist.ColWidths[6]:=ini.ReadInteger('Cols','6',49);
ini.Free;
serverlist.Rows[0][0]:='Server name';
serverlist.Rows[0][1]:='State';
serverlist.Rows[0][2]:='Map';
serverlist.Rows[0][3]:='Gametype';
serverlist.Rows[0][4]:='Players';
serverlist.Rows[0][5]:='Max players';
serverlist.Rows[0][6]:='PB';
InitLib();
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
ini:tinifile;
begin
ini:=tinifile.Create(GetCurrentDir+'/Launcher.ini');
ini.WriteString('Conf','Login',edit1.Text);
ini.WriteString('Conf','Pass',edit2.Text);
ini.WriteInteger('Form','Left',form1.Left);
ini.WriteInteger('Form','Top',form1.Top);
ini.WriteInteger('Form','Height',form1.Height);
ini.WriteInteger('Form','Width',form1.Width);
ini.WriteInteger('Cols','0',serverlist.ColWidths[0]);
ini.WriteInteger('Cols','1',serverlist.ColWidths[1]);
ini.WriteInteger('Cols','2',serverlist.ColWidths[2]);
ini.WriteInteger('Cols','3',serverlist.ColWidths[3]);
ini.WriteInteger('Cols','4',serverlist.ColWidths[4]);
ini.WriteInteger('Cols','5',serverlist.ColWidths[5]);
ini.WriteInteger('Cols','6',serverlist.ColWidths[6]);
ini.Free;
if DllHandle<>0 then
begin
ZLO_Close();
FreeLibrary(DllHandle);
end;
ClearServers;
mutex.Free;
servers.Free;
end;

procedure TForm1.serverlistClick(Sender: TObject);
var
id:integer;
begin
if (serv<=0) or not servers.ContainsKey(serv) or (servers.Items[serv].row<>serv) then
Button2.Enabled:=false;
if (serverlist.Selection.Top>0) and (servers.Count>0) then
for id in servers.Keys do
if servers.Items[id].row=serverlist.Selection.Top then
begin
serv:=id;
ZLO_SelectServer(serv);
break;
end;
end;

procedure TForm1.UpdateTimerTimer(Sender: TObject);
begin
UpdateLib;
UpdateTimer.Enabled:=false;
end;

procedure TForm1.PingTimerTimer(Sender: TObject);
begin
PingTimer.Enabled:=false;
Pinger.Ping();
case form1.Pinger.ReplyStatus.ReplyStatusType of
rsEcho:form1.memo1.Lines.Add('Ping ' + inttostr(form1.Pinger.ReplyStatus.MsRoundTripTime) + 'ms');
rsTimeOut:form1.memo1.Lines.Add('Ping timeout');
else form1.memo1.Lines.Add('Ping error');
end;
end;

end.
