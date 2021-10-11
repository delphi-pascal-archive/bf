{ © 2007-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfwindow;
// Окошко и все контролы, логика GUI и сведённая сюда
// (а куда ещё? - с таким стилем только сюда) логика темы приложения.
// Должны быть доступны все юниты.
// Безусловно самая сложная и неупорядоченая часть программы

INTERFACE

procedure WinMain();

IMPLEMENTATION       

uses Windows,          
     Messages,
     CommCtrl,  
     bfatd,
     bfcompiler,
     bfgraph,
     bfhjtechnique,
     bfmethod,
     bfspecialfunc,
     bfsysutils,
     bftablefile,  
     bfderivator,
     bfdialogs;

const BF = 'bf';

// resourcestring ???
const FIRST = 'Первое приближение';
      ONEPEAK = 'Одиночный пик';
      TWOPEAK = 'Пара пиков';
      TERMINATE = 'Завершение нити';
      RUNNING = ' [Выполнение] ';
      ERROR = ' [Ошибка] ';
      PAUSED = ' [Пауза] '; 
      OPEN = 'Открыть спектр';
      SAVE = 'Сохранить спектр';
      START = ' [Подготовка] ';
 
const IDC_TABCONTROL = $1000;
      IDC_STATIC = $1001;
      IDC_BUTTON_TERMINATE = $1002;
      IDC_LTEXT_NPOINTS = $1003;
      IDC_BUTTON_COPYTOLPEAK = $1004;
      IDC_BUTTON_COPYTORPEAK = $1005;
      IDC_BUTTON_FIRST = $1006;
      IDC_LISTBOX_ONEPEAK = $1007;
      IDC_BUTTON_ONEPEAK = $1008;
      IDC_BUTTON_ONEPEAK_INFO = $1009;
      IDC_LISTBOX_TWOPEAK = $100A;
      IDC_BUTTON_TWOPEAK = $100B;
      IDC_BUTTON_TWOPEAK_INFO = $100C;

const IDM_FILE_OPEN = $100;
      IDM_FILE_SAVE = $101;  
      IDM_FILE_CLOSE = $102;

      IDM_DO1ST = $200;    
      IDM_DO1PEAK = $201;
      IDM_DO2PEAK = $202;

      IDM_HJPROPERTY = $300;
      IDM_GRAPHPROPERTY = $301;

      IDM_ABOUT = $400;
      IDM_HELP = $401;

      IDM_TERMINATE = $500;

      IDM_MODE = $1000;  
      IDM_SETSOURCESPECTRARANGE = $1001; 
      IDM_FOCUSONSOURCESPECTRA = $1002;

var hwndButtonFirst,
    hwndListbox1Peak,
    hwndButton1Peak,
    hwndButton1PeakInfo,
    hwndListbox2Peak,
    hwndButton2Peak,
    hwndButton2PeakInfo,    
    hwndButtonCopyToLeftPeak,
    hwndButtonCopyToRightPeak,
    hwndButtonTerminate,
    hwndLTextNPoints,
    HandleDlgWindow,   
    hwndTabControl,
    hwndStatic : HWND; 
    mii : MENUITEMINFO;
    Menu,
    SysMenu,
    SpectraPopupMenu : HMENU;
    IsRunningText,
    FileOpenText : PChar; 
    WindowStartRect : TRect;

const UPDRESULTS_TIMER = $FF;
      UPDRESULTS_TIMER_INTERVAL : DWORD = 1000 div 25; // Как по телевизору

procedure About();
begin
MessageBox(HandleDlgWindow, 'Учебное приложение позволяющее выполнять анализ'#13'неполностью разрешённых масс-спектров.'#13#13'Томилов А.В. '#169' 2007-2008'#13'mailto:tomilov@fizteh.org', 'О программе', MB_OK)

end { About };

procedure Help();
begin
WinExec(PChar('explorer res://' + Paramstr(0) + '/23/bf'), SW_SHOW)
//ShellExecute(HWND_DESKTOP, nil, PChar('res://' + Paramstr(0) + '/23/bf'), nil, nil, SW_SHOW)

end { Help };      

var hMathThread : THandle;

function IsThreadStarted() : BOOL;
begin        
Result:= (WaitForSingleObject(hMathThread, 0) = WAIT_TIMEOUT)

end { IsThreadStarted };

var ThreadPriority : Integer = THREAD_PRIORITY_NORMAL; 
    ID_MATH_THREAD : DWORD; // stub

procedure RunThread(f : Pointer);
begin
if (IsValidSpectra(SourceSpectra)) then SetSelectRange(SourceSpectra.x[0], SourceSpectra.x[High(SourceSpectra.x)]) { IF };
if (IsThreadStarted()) then Exit { IF };
EnableWindow(hwndButtonTerminate, TRUE);
hjd.TerminateHJ:= FALSE;
hMathThread:= CreateThread(nil, 0, f, @HandleDlgWindow, CREATE_SUSPENDED, ID_MATH_THREAD);
SetThreadPriority(hMathThread, ThreadPriority); 
ResumeThread(hMathThread);                 
PostMessage(HandleDlgWindow, WM_THREADMSG, (-4), 0) 

end { Prepare };

procedure QuitThread();
begin             
if not (IsThreadStarted()) then Exit { IF };
hjd.TerminateHJ:= TRUE; 
case WaitForSingleObject(hMathThread, 2000) of WAIT_TIMEOUT : begin
                                                              TerminateThread(hMathThread, 0);
                                                              PostMessage(HandleDlgWindow, WM_THREADMSG, (-2), 0)
                                                              end { WAIT_TIMEOUT };
                                               WAIT_OBJECT_0 : PostMessage(HandleDlgWindow, WM_THREADMSG, (-3), 0) { WAIT_OBJECT_0 }
end { CASE }
 
end { QuitThread };

procedure TimerProc(HandleWindow : HWND; msg : UINT; ID_TIMER : UINT; Time : DWORD); stdcall;
begin
case ID_TIMER of UPDRESULTS_TIMER : if (IsThreadStarted()) then if (UpdateIt()) then InvalidateRect(hwndStatic, nil, FALSE) { IF } { IF } { UPDSTATICWND_TIMER }                                      
end { CASE }                                          

end { TimerProc };

procedure ShowSheet(nItem : Integer);

var nCmdShow : Integer;

begin
TabCtrl_SetCurFocus(hwndTabControl, nItem); // для WM_NOTIFY - лишнее конечно, но что ж поделать?.. - не таскать же везде с ShowSheet её

if (nItem = 0) then begin
                    nCmdShow:= SW_SHOW;
                    SetFocus(hwndTabControl)
                    end
               else nCmdShow:= SW_HIDE { IF };
ShowWindow(hwndStatic, nCmdShow);

if (nItem = 1) then begin
                    nCmdShow:= SW_SHOW;
                    SetFocus(hwndTabControl)
                    end
               else nCmdShow:= SW_HIDE { IF };

ShowWindow(hwndButtonTerminate, nCmdShow); // Прорисовывается всё равно не первой =(
ShowWindow(hwndLTextNPoints, nCmdShow);
ShowWindow(hwndButtonCopyToLeftPeak, nCmdShow);
ShowWindow(hwndButtonCopyToRightPeak, nCmdShow);

ShowWindow(hwndButtonFirst, nCmdShow);

ShowWindow(hwndButton1Peak, nCmdShow);
//ShowWindow(hwndButton1PeakData, nCmdShow);
ShowWindow(hwndButton1PeakInfo, nCmdShow);
ShowWindow(hwndListbox1Peak, nCmdShow);

ShowWindow(hwndButton2Peak, nCmdShow);
//ShowWindow(hwndButton2PeakData, nCmdShow);
ShowWindow(hwndButton2PeakInfo, nCmdShow);
ShowWindow(hwndListbox2Peak, nCmdShow) 

end { ShowSheet };    
                       
function TabCtrl_InsertItem(hwndTabControl : HWND; iItem : Integer; sTitle : PChar) : BOOL;

var tci : TC_ITEM;

begin                          
with tci do begin
            mask:= TCIF_TEXT; 
            pszText:= sTitle;       
            Result:= (SendMessage(hwndTabControl, TCM_INSERTITEM, iItem, DWORD(@tci)) = iItem)
            end { tci }

end { TabCtrl_InsertItem };

function IsFileExist(FileName : PChar) : BOOL;

var HFindFile : THandle;
    FindData : TWin32FindData;    

begin
Result:= FALSE;
HFindFile:= FindFirstFile(FileName, FindData); 
if (HFindFile <> INVALID_HANDLE_VALUE) then begin
                                            FindClose(HFindFile);
                                            Result:= ((FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0)
                                            end { IF }

end { IsFileExist };

procedure SetGrayedPopupMenuItem(SubMenuID : DWORD; GrayIt : BOOL);

var fState : UINT;

begin
if (GrayIt) then fState:= MFS_GRAYED or MF_BYCOMMAND
            else fState:= MFS_ENABLED or MF_BYCOMMAND { IF };  

EnableMenuItem(SpectraPopupMenu, SubMenuID, fState)

end { SetGrayedPopupMenuItem };

procedure SetGrayedMenuItem(SubMenuPos, SubSubMenuPos : DWORD; GrayIt : BOOL);

var fState : UINT;
    
begin
if (GrayIt) then fState:= MFS_GRAYED or MF_BYPOSITION
            else fState:= MFS_ENABLED or MF_BYPOSITION { IF };

EnableMenuItem(GetSubMenu(Menu, SubMenuPos), SubSubMenuPos, fState)     

end { SetGrayedMenuItem };

(*
function AddListBoxLine(ID : DWORD; const S : string) : DWORD;
begin
Result:= SendDlgitemMessage(HandleDlgWindow, ID, LB_ADDSTRING, 0, DWORD(PChar(S)))

end { AddListBoxLine };        *)

procedure ResetListBox(HandleWindow : HWND);
begin
SendMessage(HandleWindow, LB_RESETCONTENT, 0, 0)

end { ResetListBox };

procedure UpdateOnePeakListBox();

var index : Integer;

begin
UpdateGraphData(TGRAPH(a1peak.td.Spectra), a1peak.td.iItem);
ResetListBox(hwndListbox1Peak);
for index:= 0 to (a1peak.td.FuncStruct.ENTIRETYSC) do SendMessage(hwndListbox1Peak, LB_INSERTSTRING, index, DWORD(PChar(a1peak.td.FuncStruct.Constants[index] + ' = ' + FloatToStr(a1peak.td.q[index].Value)))) { FOR } { WITH }

end { UpdateOnePeakListBox };

(*procedure AppendToListBox(HandleWindow : HWND; const S : string);
begin
SendMessage(HandleWindow, LB_INSERTSTRING, SendMessage(HandleWindow, LB_GETCOUNT, 0, 0), DWORD(PChar(S)))

end { AppendToListBox }; *)
                               
procedure UpdateTwoPeakListBox();
   
var index : Integer;

begin
UpdateGraphData(TGRAPH(a2peak.td.Spectra), a2peak.td.iItem);
ResetListBox(hwndListbox2Peak);                                                                                               
for index:= 0 to (a2peak.td.FuncStruct.ENTIRETYSC) do SendMessage(hwndListbox2Peak, LB_INSERTSTRING, index, DWORD(PChar(a2peak.td.FuncStruct.Constants[index] + ' = ' + FloatToStr(a2peak.td.q[index].Value)))) { FOR } { WITH }
 
(*ResetListBox(hwndListbox2Peak);
with a2peak do with index do with td do begin
                                        AppendToListBox(hwndListbox2Peak, 'noise = ' + FloatToStr(0.5*(noiser + noisel)));
                                        AppendToListBox(hwndListbox2Peak, 'amplitudel = ' + FloatToStr(q[amplitudel].Value));
                                        AppendToListBox(hwndListbox2Peak, 'resolutionl = ' + FloatToStr(q[resolutionl].Value));
                                        AppendToListBox(hwndListbox2Peak, 'massl = ' + FloatToStr(q[massl].Value));
                                        AppendToListBox(hwndListbox2Peak, 'amplituder = ' + FloatToStr(q[amplituder].Value));
                                        AppendToListBox(hwndListbox2Peak, 'resolutionr = ' + FloatToStr(q[resolutionr].Value));
                                        AppendToListBox(hwndListbox2Peak, 'massr = ' + FloatToStr(q[massr].Value))
                                        end { index } { a2peak } *)

end { UpdateTwoPeakListBox };

function OpenSpectra(const S : string) : BOOL;

var dt : Integer;
    lines : Integer; 

 procedure OpenInfo(Text : PChar); 
 begin
 if (IsWindowVisible(HandleDlgWindow)) then MessageBox(HandleDlgWindow, Text, OPEN, MB_OK or MB_ICONINFORMATION or MB_APPLMODAL) // Если при запуске с параметром, то панель в течении WM_INITDIALOG ещё не была ShowWindow(, SW_SHOWNORMAL) и окна ещё нет, поэтому соответствующие заголовки
                                       else MessageBox(HandleDlgWindow, Text, BF, MB_OK or MB_ICONINFORMATION or MB_SYSTEMMODAL) { IF };

 end { OpenInfo };

begin                  
Result:= IsFileExist(PChar(S));
if not (Result) then Exit { IF };

dt:= -GetTickCount();         
lines:= LoadTableFile(S, 2); // Берётся только одна первая колонка интенсивностей (в случае нескольких - multicolumn data в tc2d)
if (lines <> 0) then begin
                     GetTableColumn(0, FullSpectra.x); 
                     GetTableColumn(1, FullSpectra.y)
                     end { IF };
Inc(dt, GetTickCount());

if (lines <> 0) then begin
                     if not (IsSequential(FullSpectra.x)) then begin
                                                               OpenInfo('Данный файл содержит непоследовательные значения масс');
                                                               Result:= FALSE
                                                               end { IF };

                     if (IsNotPositivelyDefined(FullSpectra.x)) then begin
                                                                     OpenInfo('Данный файл содержит неположительные значения массы');
                                                                     Result:= FALSE
                                                                     end { IF };

                     if not (Result) then if (MessageBox(HandleDlgWindow, 'Продолжить обработку этого файла?', OPEN, MB_OK or MB_YESNO or MB_DEFBUTTON2 or MB_ICONQUESTION or MB_SYSTEMMODAL) = IDNO) then begin
                                                                                                                                                                                                      FullSpectra.x:= nil;
                                                                                                                                                                                                      FullSpectra.y:= nil;
                                                                                                                                                                                                      Exit
                                                                                                                                                                                                      end { IF } { IF }
                     end { IF };
Result:= TRUE; 
if (lines > 1) then begin
                    OpenInfo(PChar(IntToStr(lines) + ' отсчётов считано за ' + IntToStr(dt) + ' мс'));

                    if (IsNegativelyDefined(FullSpectra.y)) then OpenInfo(PChar('Базовая линия ' + FloatToStr(SubtractBaseLine(FullSpectra.y)) + ' вычтена')) { IF };

                    fs.iItem:= AddGraphData(TGRAPH(FullSpectra), RGB(0, 0, 0), TRUE);
                    SetWindowText(HandleDlgWindow, PChar(BF + IsRunningText + lstrcpy(FileOpenText, PChar(' - ' + S))));
                    ShowSheet(0)
                    end
               else MessageBox(HandleDlgWindow, 'Этот файл не является файлом спектра', OPEN, MB_OK or MB_ICONEXCLAMATION or MB_SYSTEMMODAL) { IF };

OptimizeZoom();
OnChangeGraphStaticState() 
                                   
end { OpenSpectra };

procedure ThreadMessageHandler(wParam : WPARAM; lParam : LPARAM);

var FileName : string;
    index : Integer;

 procedure EndOfCalc(const S : string);

 var TimeOutTxt, FCCPresent : string;

 begin
 if (lParam = 1) then TimeOutTxt:= 'Анализ окончен (таймаут)'
                 else TimeOutTxt:= 'Анализ окончен' { IF };

 if (wParam > 0) then FCCPresent:= #13'Информация: FCC=' + IntToStr(hjd.FCC)
                 else FCCPresent:= '' { IF };

 lstrcpy(IsRunningText, '');
 if (TabCtrl_GetCurFocus(hwndTabControl) = 0) then MessageBox(HandleDlgWindow, PChar(TimeOutTxt + FCCPresent), PChar(S), MB_OK or MB_ICONINFORMATION)
                                              else if (MessageBox(HandleDlgWindow, PChar(TimeOutTxt + '. Перейти на вкладку визуализации спектра?' + FCCPresent), PChar(S), MB_YESNO or MB_DEFBUTTON2 or MB_ICONQUESTION) = IDYES) then ShowSheet(0) { IF } { IF }

 end { EndOfCalc };

begin
InvalidateRect(hwndStatic, nil, FALSE);
case wParam of -5 : begin         
                    lstrcpy(IsRunningText, '');

                    UpdateOnePeakListBox();
                    UpdateTwoPeakListBox();

                    FileName:= GetCommandLine();
                    index:= Pos('" ', FileName) + 1;
                    OpenSpectra(Copy(FileName, index + 1, Length(FileName) - index))
                    end { -5 };
               -4 : begin
                    lstrcpy(IsRunningText, RUNNING) 
                    end { -4 };
               -3 : begin
                    lstrcpy(IsRunningText, '');
                    MessageBox(HandleDlgWindow, 'Работа нити прервана', TERMINATE, MB_OK or MB_ICONINFORMATION)
                    end { -3 };
               -2 : begin 
                    lstrcpy(IsRunningText, ERROR);
                    MessageBox(HandleDlgWindow, 'Работа нити прервана аварийно', TERMINATE, MB_OK or MB_ICONERROR)
                    end { -2 };
               -1 : begin    
                    lstrcpy(IsRunningText, '')
                    end { -1 };     
               00 : begin
                    EndOfCalc(FIRST);
                    UpdateOnePeakListBox()
                    end { 0 };
               01 : begin
                    EndOfCalc(ONEPEAK);
                    UpdateOnePeakListBox()
                    end { 1 };
               02 : begin
                    EndOfCalc(TWOPEAK);
                    UpdateTwoPeakListBox()
                    end { 2 }
end { CASE };
                      
EnableWindow(hwndButtonTerminate, (wParam = -4)); 
SetWindowText(HandleDlgWindow, PChar(BF + IsRunningText + FileOpenText));
OnChangeGraphStaticState() 
                
end { ThreadMessageHandler }; 

procedure GetSelectedField();      
begin                             
if (bfmethod.GetSelectedField() < 2) then MessageBox(HandleDlgWindow, 'Выбирите более одной точки', 'Выбор обрабатываемой области', MB_OK or MB_ICONERROR) { IF };
SetDlgItemText(HandleDlgWindow, IDC_LTEXT_NPOINTS, PChar('Отсчётов: ' + IntToStr(hjd.pt))); // 
OnChangeGraphStaticState() 

end { GetSelectedField };

procedure FocusOnSourceSpectra(); 
begin
bfmethod.FocusOnSourceSpectra();    
OnChangeGraphStaticState() 

end { FocusOnSourceSpectra };

procedure CloseSpectra();

var index : Integer;

begin
ClearSpectra();
ResetSelectRange(-1E10);

FullSpectra.x:= nil; // SetLength(, 0);
FullSpectra.y:= nil;
SourceSpectra.x:= nil;
SourceSpectra.y:= nil;

a1peak.td.data.x:= nil;
a1peak.td.data.y:= nil;
a2peak.td.data.x:= nil;
a2peak.td.data.y:= nil;

a1peak.td.Spectra.x:= nil;
a1peak.td.Spectra.y:= nil;
a2peak.td.Spectra.x:= nil;
a2peak.td.Spectra.y:= nil;

a2peak.noisel:= 0.0;
a2peak.noiser:= 0.0;

for index:= 0 to (a1peak.td.FuncStruct.ENTIRETYSC) do ZeroMemory(@a1peak.td.q[index], SizeOf(TQUALIFYITEM)) { FOR };
UpdateOnePeakListBox();

for index:= 0 to (a2peak.td.FuncStruct.ENTIRETYSC) do ZeroMemory(@a2peak.td.q[index], SizeOf(TQUALIFYITEM)) { FOR };
UpdateTwoPeakListBox();

lstrcpy(FileOpenText, PChar(''));
SetWindowText(hwndLTextNPoints, '');
//ResetListBox(hwndListbox1Peak);
//ResetListBox(hwndListbox2Peak);
SetWindowText(HandleDlgWindow, PChar(BF + IsRunningText))

end { CloseSpectra } ;

procedure SaveSpectra();

var S : string;

begin
S:= GetSaveTableFileName(HandleDlgWindow);
if (S = '') then Exit { IF };

SetTableColumn(0, SourceSpectra.x);
SetTableColumn(1, SourceSpectra.y);

MessageBox(HandleDlgWindow, PChar(IntToStr(SaveTableFile(S, 2)) + ' отсчётов записано в файл ' + S), SAVE, MB_OK or MB_ICONINFORMATION);

InvalidateRect(hwndStatic, nil, FALSE)

end { SaveSpectra };

procedure OnResizeProc(lParam : LPARAM);
begin 
ResizeGraphStatic(0, 21, Word(lParam), Word(lParam shr 16) - 21);
MoveWindow(hwndTabControl, 0, 0, Word(lParam), 20, TRUE)

end { OnResizeProc }; 

function SufficientRequirements(const S : string; const data : TSPECTRA) : BOOL;
begin
Result:= FALSE;
if (IsValidSpectra(FullSpectra)) then if (IsValidSpectra(data)) then Result:= TRUE
                                                                else MessageBox(HandleDlgWindow, 'Сперва выбирите область спектра для обработки', PChar(S), MB_OK or MB_ICONWARNING) { IF }
                                 else MessageBox(HandleDlgWindow, 'Сперва откройте файл спектра', PChar(S), MB_OK or MB_ICONWARNING) { IF }
 
end { SufficientRequirements };

procedure TerminateFunc();

var index : Integer;

begin
if not (IsThreadStarted()) then Exit { IF };
EnterCriticalSection(hjd.cs);
SuspendThread(hMathThread); 
lstrcpy(IsRunningText, PAUSED); 
index:= MessageBox(HandleDlgWindow, 'Прервать поиск?', 'Приостановка поиска', MB_YESNO or MB_DEFBUTTON2 or MB_ICONQUESTION);
SetWindowText(HandleDlgWindow, PChar(BF + lstrcpy(IsRunningText, RUNNING) + FileOpenText));
ResumeThread(hMathThread);
LeaveCriticalSection(hjd.cs);
if (index = IDYES) then QuitThread() { IF }

end { TerminateFunc }; 

procedure OnInitMenu();

var FLAG1, FLAG2 : BOOL;

begin                  
FLAG1:= IsValidSpectra(FullSpectra);
FLAG2:= IsThreadStarted();
SetGrayedMenuItem(0, 0, FLAG1 or FLAG2);
SetGrayedMenuItem(0, 1, not IsValidSpectra(SourceSpectra));
SetGrayedMenuItem(0, 2, not (FLAG1) or FLAG2);

SetGrayedMenuItem(2, 1, IsThreadStarted())    

end { OnInitMenu }; 

procedure Copy2LPeak();
begin
with a2peak.index do with a1peak.index do begin
                                          a2peak.noisel:= a1peak.td.q[a1peak.index.noise].Value;
                                          a2peak.td.q[a2peak.index.noise].Value:= 0.5*(a2peak.noisel + a2peak.noiser);
                                          a2peak.td.q[amplitudel].Value:= a1peak.td.q[amplitude].Value;
                                          a2peak.td.q[resolutionl].Value:= a1peak.td.q[resolution].Value;
                                          a2peak.td.q[massl].Value:= a1peak.td.q[mass].Value
                                          end { a1peak.index } { a2peak.index };

UpdateTwoPeakListBox()

end { Copy2LPeak };

procedure Copy2RPeak();
begin 
with a2peak.index do with a1peak.index do begin  
                                          a2peak.noiser:= a1peak.td.q[a1peak.index.noise].Value;
                                          a2peak.td.q[a2peak.index.noise].Value:= 0.5*(a2peak.noisel + a2peak.noiser);
                                          a2peak.td.q[amplituder].Value:= a1peak.td.q[amplitude].Value;
                                          a2peak.td.q[resolutionr].Value:= a1peak.td.q[resolution].Value;
                                          a2peak.td.q[massr].Value:= a1peak.td.q[mass].Value
                                          end { a1peak.index } { a2peak.index };

UpdateTwoPeakListBox()            

end { Copy2LPeak };
                         
procedure DoFirstOnePeakApproximation();
begin
QualifyToOnePeak();
if (SufficientRequirements(FIRST, a1peak.td.data)) then begin
                                                        DeleteAllGraph();
                                                        RunThread(@bfmethod.DoFirstApproximation)
                                                        end { IF }
                                     
end { DoFirstOnePeakApproximation };

const errmsg : array[1..4] of string = (' ограничение снизу (min) должно быть меньше начального значения (val)',
                                        ' ограничение сверху (max) должно быть больше начального значения (val)',
                                        ' начальное значение шага (step) должно быть меньше (max - min)/3',
                                        ' предельное значение шага (prec) должно быть меньше начального (step)');

procedure DoOnePeakApproximation();

var index, errcode, varindex : Integer; 

begin
//QualifyToOnePeak();
SetTaskData(a1peak.td, SourceSpectra); 
if (SufficientRequirements(ONEPEAK, a1peak.td.data)) then begin
                                                          index:= OnePeakFirstApproachErrorCode(errcode, varindex);
                                                          if (index >= 0) then MessageBox(HandleDlgWindow, PChar('Параметр ' + a1peak.td.FuncStruct.Constants[index] + ' имеет недопустимое значение на выбранном участке спектра для одиночного пика'), ERROR_, MB_OK or MB_ICONERROR)
                                                                          else if (index = -2) then begin
                                                                                                    MessageBox(HandleDlgWindow, PChar('Для параметра ' + a1peak.td.FuncStruct.Constants[varindex] + errmsg[errcode]), ERROR_, MB_OK or MB_ICONERROR)
                                                                                                    end
                                                                                               else if (index = -1) then begin
                                                                                                                         DeleteAllGraph();
                                                                                                                         RunThread(@bfmethod.DoOnePeakApproximation)
                                                                                                                         end { IF } { IF } { IF }
                                                          end { IF };

end { DoOnePeakApproximation };

(*procedure CopyToClipBoard(HandleLBWindow : HWND);

var uItem : Integer;

begin
uItem:= SendMessage(HandleLBWindow, LB_GETCURSEL, 0, 0);
hClipBoard:= GlobalAlloc(GMEM_MOVEABLE, SendMessage(HandleLBWindow, LB_GETTEXTLEN, uItem, 0) + 1); // or GMEM_DDESHARE
ClipBoard:= GlobalLock(hClipBoard);
SendMessage(HandleLBWindow, LB_GETTEXT, uItem, DWORD(Buffer)); 
lstrcpy(ClipBoard, Pointer(DWORD(Buffer) + Pos('=', Buffer) + 1));
GlobalUnlock(hClipBoard);
OpenClipboard(HWND_DESKTOP); //
EmptyClipboard();
SetClipboardData(CF_TEXT, hClipBoard);
CloseClipboard()

end { CopyToClipBoard }; *)

procedure DoTwoPeakApproximation();

var index, errcode, varindex : Integer; 

begin
QualifyToTwoPeak();
if (SufficientRequirements(TWOPEAK, a2peak.td.data)) then begin
                                                          index:= TwoPeakFirstApproachErrorCode(errcode, varindex);
                                                          if (index >= 0) then MessageBox(HandleDlgWindow, PChar('Параметр ' + a2peak.td.FuncStruct.Constants[index] + ' имеет недопустимое значение на выбранном участке спектра для пары пиков'), ERROR_, MB_OK or MB_ICONERROR)
                                                                          else if (index = -2) then begin 
                                                                                                    MessageBox(HandleDlgWindow, PChar('Для параметра ' + a2peak.td.FuncStruct.Constants[varindex] + errmsg[errcode]), ERROR_, MB_OK or MB_ICONERROR)
                                                                                                    end
                                                                                               else if (index = -1) then begin
                                                                                                                         DeleteAllGraph();
                                                                                                                         RunThread(@bfmethod.DoTwoPeakApproximation)
                                                                                                                         end { IF } { IF } { IF }
                                                          end { IF }

end { DoTwoPeakApproximation };
                   
procedure OnClose();
begin
KillTimer(HandleDlgWindow, UPDRESULTS_TIMER);
QuitThread();
DestroyMenu(SpectraPopupMenu);

EndDialog(HandleDlgWindow, 0)

end { OnClose };

procedure OnCommand(wParam : WPARAM; lParam : LPARAM);
begin
if (lParam = 0) then case Word(wParam) of IDCANCEL : OnClose() { IDCANCEL };
                                          IDM_FILE_OPEN : OpenSpectra(GetOpenTableFileName(HandleDlgWindow)) { IDM_FILE_OPEN };
                                          IDM_FILE_SAVE : SaveSpectra() { IDM_FILE_SAVE };
                                          IDM_FILE_CLOSE : CloseSpectra() { IDM_FILE_CLOSE };
                                          IDM_ABOUT : About() { IDM_ABOUT };
                                          IDM_HELP : Help() { IDM_HELP };
                                          IDM_TERMINATE : TerminateFunc() { IDM_TERMINATE };
                                          IDM_DO1ST : DoFirstOnePeakApproximation() { IDM_DO1ST };
                                          IDM_DO1PEAK : DoOnePeakApproximation() { IDM_DO1PEAK };
                                          IDM_DO2PEAK : DoTwoPeakApproximation() { IDM_DO2PEAK };
                                          IDM_MODE : SelectNotDrag:= not SelectNotDrag { IDM_MODE };
                                          IDM_HJPROPERTY : OnHJPropertyRequest(HandleDlgWindow, @ThreadPriority) { IDM_HJPROPERTY };
                                          IDM_GRAPHPROPERTY : GraphPropertyRequest(HandleDlgWindow) { IDM_HJPROPERTY };
                                          IDM_SETSOURCESPECTRARANGE : GetSelectedField() { IDM_SETSOURCESPECTRARANGE };
                                          IDM_FOCUSONSOURCESPECTRA : FocusOnSourceSpectra() { IDM_FOCUSONSOURCESPECTRA }
                     end { CASE }
                else case Word(wParam) of IDC_BUTTON_FIRST : DoFirstOnePeakApproximation() { IDC_BUTTON_FIRST };
                                          IDC_BUTTON_ONEPEAK : DoOnePeakApproximation() { IDC_BUTTON_ONEPEAK };
                                          //IDC_BUTTON_ONEPEAK_DATA : QualifyToOnePeak() { IDC_BUTTON_ONEPEAK_DATA };
                                          IDC_BUTTON_ONEPEAK_INFO : if not (IsThreadStarted()) then OnFuncSettingsRequest(HandleDlgWindow, a1peak.td) { IF } { IDC_BUTTON_ONEPEAK_INFO };
                                          IDC_BUTTON_TWOPEAK : DoTwoPeakApproximation() { IDC_BUTTON_TWOPEAK };
                                          //IDC_BUTTON_TWOPEAK_DATA : QualifyToTwoPeak() { IDC_BUTTON_TWOPEAK_DATA };
                                          IDC_BUTTON_TWOPEAK_INFO : if not (IsThreadStarted()) then OnFuncSettingsRequest(HandleDlgWindow, a2peak.td) { IF } { IDC_BUTTON_TWOPEAK_INFO };                                                
                                          IDC_BUTTON_TERMINATE : TerminateFunc() { IDC_BUTTON_TERMINATE };
                                          IDC_BUTTON_COPYTOLPEAK : if not (IsThreadStarted()) then Copy2LPeak() { IF } { IDC_BUTTON_COPYTOLPEAK };
                                          IDC_BUTTON_COPYTORPEAK : if not (IsThreadStarted()) then Copy2RPeak() { IF } { IDC_BUTTON_COPYTOLPEAK };
                                          IDC_LISTBOX_ONEPEAK : case Word(wParam shr 16) of LBN_DBLCLK : begin
                                                                                                         OnVarSelectionRequest(HandleDlgWindow, SendMessage(hwndListbox1Peak, LB_GETCURSEL, 0, 0), a1peak.td);
                                                                                                         UpdateOnePeakListBox()
                                                                                                         end { LBN_DBLCLK }
                                                                end { CASE } { IDC_LISTBOX_ONEPEAK };
                                          IDC_LISTBOX_TWOPEAK : case Word(wParam shr 16) of LBN_DBLCLK : begin
                                                                                                         OnVarSelectionRequest(HandleDlgWindow, SendMessage(hwndListbox2Peak, LB_GETCURSEL, 0, 0), a2peak.td);
                                                                                                         UpdateTwoPeakListBox()
                                                                                                         end { LBN_DBLCLK }
                                                                end { CASE } { IDC_LISTBOX_TWOPEAK }                                                                      
                     end { CASE } { IF }

end { OnCommand };

procedure SpectraMenu();

var CursorPosScreen : TPoint; 

begin
if (IsValidSpectra(FullSpectra)) then begin
                                      GetCursorPos(CursorPosScreen);
                                      if (SelectNotDrag) then ModifyMenu(SpectraPopupMenu, IDM_MODE, MF_BYCOMMAND, IDM_MODE, 'Режим &прокрутки')
                                                         else ModifyMenu(SpectraPopupMenu, IDM_MODE, MF_BYCOMMAND, IDM_MODE, 'Режим &выделения') { IF };


                                      SetGrayedPopupMenuItem(IDM_FOCUSONSOURCESPECTRA, not IsValidSpectra(SourceSpectra));
                                      SetGrayedPopupMenuItem(IDM_SETSOURCESPECTRARANGE, IsThreadStarted() or not IsValidSpectra(FullSpectra));

                                      TrackPopupMenu(SpectraPopupMenu, TPM_RIGHTALIGN or TPM_RIGHTBUTTON, CursorPosScreen.X, CursorPosScreen.Y, 0, HandleDlgWindow, nil)
                                      end
                                 else if not (IsValidSpectra(FullSpectra) or IsThreadStarted()) then OpenSpectra(GetOpenTableFileName(HandleDlgWindow)) { IF } { IF }

end { SpectraMenu };

procedure OnCreate(HandleDlgWindow : HWND); 
begin
bfwindow.HandleDlgWindow:= HandleDlgWindow;
GetWindowRect(HandleDlgWindow, WindowStartRect);
SendMessage(HandleDlgWindow, WM_SETICON, ICON_BIG, LoadIcon(SysInit.HInstance, BF));

lstrcpy(IsRunningText, START);

LoadKeyboardLayout('00000409', KLF_ACTIVATE);
//LoadKeyboardLayout('00000419', KLF_ACTIVATE); // Менюшки-то у нас на русском ((

RightButtonClickHandler:= @SpectraMenu;
LeftButtonDoubleClickHandler:= @bfwindow.FocusOnSourceSpectra; 
SpectraPopupMenu:= CreatePopupMenu();
SelectNotDrag:= FALSE;
AppendMenu(SpectraPopupMenu, MF_STRING, IDM_MODE, '');
AppendMenu(SpectraPopupMenu, MF_STRING, IDM_SETSOURCESPECTRARANGE, '&Задать обрабатываемую область');
AppendMenu(SpectraPopupMenu, MF_STRING, IDM_FOCUSONSOURCESPECTRA, 'Показать &обрабатываемую область');

hwndButtonFirst:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_FIRST); 

hwndButton1Peak:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_ONEPEAK);
//hwndButton1PeakData:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_ONEPEAK_DATA);
hwndButton1PeakInfo:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_ONEPEAK_INFO);
hwndListbox1Peak:= GetDlgItem(HandleDlgWindow, IDC_LISTBOX_ONEPEAK);

hwndButton2Peak:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_TWOPEAK);
//hwndButton2PeakData:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_TWOPEAK_DATA);
hwndButton2PeakInfo:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_TWOPEAK_INFO);
hwndListbox2Peak:= GetDlgItem(HandleDlgWindow, IDC_LISTBOX_TWOPEAK); 

hwndButtonTerminate:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_TERMINATE);
hwndLTextNPoints:= GetDlgItem(HandleDlgWindow, IDC_LTEXT_NPOINTS);
hwndButtonCopyToLeftPeak:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_COPYTOLPEAK);
hwndButtonCopyToRightPeak:= GetDlgItem(HandleDlgWindow, IDC_BUTTON_COPYTORPEAK); 

hwndStatic:= GetDlgItem(HandleDlgWindow, IDC_STATIC);
SubClassGraphStatic(hwndStatic);

hwndTabControl:= GetDlgItem(HandleDlgWindow, IDC_TABCONTROL);
TabCtrl_InsertItem(hwndTabControl, 0, 'Спектр'); // &С
TabCtrl_InsertItem(hwndTabControl, 1, 'Метод'); // &М

Menu:= LoadMenu(SysInit.HInstance, BF);
AppendMenu(Menu, MF_STRING or MFT_RIGHTJUSTIFY, IDM_TERMINATE, '&Прервать');
SetMenu(HandleDlgWindow, Menu);

SysMenu:= GetSystemMenu(HandleDlgWindow, FALSE);
with mii do begin
            cbSize:= SizeOf(MENUITEMINFO);
            fMask:= MIIM_TYPE or MIIM_ID;
            fType:= MFT_STRING;
            dwTypeData:= 'О программе...';
            cch:= 14; // Length('О программе...')
            wID:= IDM_ABOUT
            end { mii };
InsertMenuItem(SysMenu, 5, TRUE, mii);
with mii do begin
            cbSize:= SizeOf(MENUITEMINFO);
            fMask:= MIIM_TYPE;
            fType:= MFT_SEPARATOR
            end { mii };
InsertMenuItem(SysMenu, 5, TRUE, mii); 

ShowSheet(0);

SetTimer(HandleDlgWindow, UPDRESULTS_TIMER, UPDRESULTS_TIMER_INTERVAL, @TimerProc);
                         
//RunThread(@Prepare)
hMathThread:= CreateThread(nil, 0, @Prepare, @bfwindow.HandleDlgWindow, 0, ID_MATH_THREAD) 

end { OnCreate };

function WindowDlgProc(HandleDlgWindow : HWND; msg : UINT; wParam : WPARAM; lParam : LPARAM) : BOOL; stdcall;
begin
Result:= TRUE;                
case msg of WM_INITDIALOG : OnCreate(HandleDlgWindow) { WM_INITDIALOG };
            WM_THREADMSG : ThreadMessageHandler(wParam, lParam) { WM_THREADMSG }; // wParam == ID
            WM_GETMINMAXINFO : with PMinMaxInfo(lParam)^.ptMinTrackSize do with WindowStartRect do begin
                                                                                                   Y:= Bottom - Top;
                                                                                                   X:= Right - Left
                                                                                                   end { TMinMaxInfo }  { WM_GETMINMAXINFO };
            WM_SIZE : OnResizeProc(lParam) { WM_SIZE };
            WM_COMMAND : OnCommand(wParam, lParam) { WM_COMMAND }; 
            WM_SYSCOLORCHANGE : SendMessage(hwndStatic, msg, wParam, lParam) { WM_SYSCOLORCHANGE };
            WM_INITMENU : OnInitMenu() { WM_INITMENU }; 
            WM_HELP : Help() { WM_HELP };
            WM_NOTIFY : case Word(wParam) of IDC_TABCONTROL : with PNMHDR(lParam)^ do case code of TCN_SELCHANGE : ShowSheet(SendMessage(hwndTabControl, TCM_GETCURSEL, 0, 0)) { TCN_SELCHANGE };
                                                                                                   //TCN_KEYDOWN : { TCN_KEYDOWN }
                                                                                      end { CASE } { WITH } { IDC_TABCONTROL };
                        end { CASE } { WM_NOTIFY };
            WM_MOUSEWHEEL : if (IsWindowVisible(hwndStatic)) then SendMessage(hwndStatic, msg, wParam, lParam) { IF } { WM_MOUSEWHEEL };
            WM_CLOSE : OnClose() { WM_CLOSE }
         else begin
              case msg of WM_SYSCOMMAND : if (wParam = IDM_ABOUT) then About() { IF } { WM_SYSCOMMAND }; 
                          WM_NCACTIVATE : if BOOL(wParam) then SetWindowText(HandleDlgWindow, PChar(BF + IsRunningText + FileOpenText))
                                                          else SetWindowText(HandleDlgWindow, PChar(BF + IsRunningText + FileOpenText + ' - Томилов А.В. '#169' 2007-2008')) { IF } { WM_NCACTIVATE } // Дань самолюбию =)
              end { CASE };
              Result:= FALSE // обрабатывать далее
              end { ELSE }
end { CASE }
                 
end { WindowDlgProc };

procedure WinMain();
begin
//if (TRUE = FALSE) then Halt; // На всякий случай. © bashorg.ru

DialogBoxParam(SysInit.HInstance, BF, HWND_DESKTOP, @WindowDlgProc, 0)

end { WinMain };
                    
INITIALIZATION

HGLOBAL(FileOpenText):= GlobalAlloc(GPTR, MAX_PATH);
HGLOBAL(IsRunningText):= GlobalAlloc(GPTR, MAX_PATH)

FINALIZATION

GlobalFree(HGLOBAL(FileOpenText));
GlobalFree(HGLOBAL(IsRunningText))

END { BFWINDOW }.
