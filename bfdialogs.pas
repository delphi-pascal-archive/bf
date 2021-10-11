{ © 2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfdialogs;

INTERFACE

uses Windows,
     bfmethod;

procedure OnVarSelectionRequest(Parent : HWND; uItem : Integer; var td : TTASKDEFINITION); // Создаёт модальный для Parent диалог свойств параметра-переменной с индексом uItem в своей структуре
procedure OnFuncSettingsRequest(Parent : HWND; var td : TTASKDEFINITION); // Создаёт модальный для Parent диалог свойств функции
procedure OnHJPropertyRequest(Parent : HWND; ptp : PInteger); // Создаёт модальный для Parent диалог свойств метода Хука и Дживса
procedure GraphPropertyRequest(Parent : HWND); // Создаёт модальный для Parent диалог свойств компонента, отображающего графики      

IMPLEMENTATION

uses Messages,
     CommDlg,
     bfsysutils,
     bfhjtechnique,
     bfgraph;   

const IDC_EDIT_VAR_VAL = $1000;
      IDC_EDIT_VAR_MIN = $1001;
      IDC_EDIT_VAR_MAX = $1002;
      IDC_EDIT_VAR_STEP = $1003;
      IDC_EDIT_VAR_PRECISION = $1004;
      IDC_EDIT_VAR_RMSE = $1005;
      IDC_AUTOCHECKBOX_VAR_LOCK = $1006;

      IDC_EDIT_EXPRESION = $1000;
      IDC_EDIT_WEIGHT = $1001;
      IDC_EDIT_TICKS = $1002;
      IDC_EDIT_CORESPEED = $1003;

      IDC_EDIT_HJPROPERTY_DIVISOR = $1000;
      IDC_EDIT_HJPROPERTY_TIMEOUT = $1001;
      IDC_EDIT_HJPROPERTY_PREC = $1002;
      IDC_EDIT_PRIORITY = $1003;
      IDC_AUTORADIOBUTTON_HJPROPERTY_INF = $1004;
      IDC_AUTORADIOBUTTON_HJPROPERTY_VAL = $1005;
      IDC_AUTOCHECKBOX_PREC = $1006;

      IDC_AUTOCHECKBOX_1ST2PEAK = $1000;
      IDC_BUTTON_COLOR1PEAK = $1001;
      IDC_BUTTON_COLOR2PEAK = $1002;
      IDC_BUTTON_COLORSS = $1003; 

var ptd : PTASKDEFINITION;
    item : Integer;
    CPUSpeed,
    TicksCount : DWORD;
    DivisorTxt : string = '30.0';
    GeneralPrecTxt : string = '0.0';
    TimeOutVal : DWORD = 2000; // 2 с
    fInfCheck : record
                case BOOL of TRUE : (bool : BOOL) { TRUE };
                             FALSE : (dw : DWORD) { FALSE }
                end = (dw : BST_CHECKED) { fInfCheck };
    pThreadPriority : PInteger;
    point : packed record
                   y,
                   x : Real
                   end = (y : 1.001; x : 1.01) { point };


var EditRMSEWndProcOld : TFNWndProc;

function EditRMSEWndProc(hwndEditFunc : HWND; msg : UINT; wParam : WPARAM; lParam: LPARAM) : LRESULT; stdcall;
begin              
Result:= 0;        
if (msg <> WM_CHAR) then Result:= CallWindowProc(EditRMSEWndProcOld, hwndEditFunc, msg, wParam, lParam) { IF }
(*case msg of WM_CHAR : { ! } { WM_CHAR };
         else Result:= CallWindowProc(EditRMSEWndProcOld, hwndEditFunc, msg, wParam, lParam) { ELSE }
end { CASE }*)                        

end { EditRMSEWndProc };

function VarPropertyDlgProc(VarPropertyDlgWindow : HWND; msg : UINT; wParam : WPARAM; lParam : LPARAM) : BOOL; stdcall;

 procedure FillEdit(const X : Real; ID : Integer);
 begin
 SetDlgItemText(VarPropertyDlgWindow, ID, PChar(FloatToStr(X)))

 end { FillEdit };

 function GetEditVal(ID : Integer; var X : Real) : BOOL;

 var rtemp : Real;

 begin
 GetDlgItemText(VarPropertyDlgWindow, ID, Buffer, MAX_PATH - 1);
 Val(Buffer, rtemp, ID);
 Result:= (ID = 0);
 if (Result) then X:= rtemp { IF }

 end { GetEditVal };

 procedure Confirm();
 begin
 GetEditVal(IDC_EDIT_VAR_VAL, ptd^.q[item].Value);
 GetEditVal(IDC_EDIT_VAR_MIN, ptd^.q[item].Min);
 GetEditVal(IDC_EDIT_VAR_MAX, ptd^.q[item].Max);
 GetEditVal(IDC_EDIT_VAR_STEP, ptd^.q[item].Step);
 GetEditVal(IDC_EDIT_VAR_PRECISION, ptd^.q[item].Precision);
 //GetEditVal(IDC_EDIT_VAR_RMSE, ptd^.q[item].rmse);

 //PReal(ptd^.FuncStruct.DSC + (item shl 3))^:= ptd^.q[item].Value;
 if (IsValidSpectra(ptd^.data)) then begin
                                     CalcStdErr(ptd^);                                                        //Writeln('12', ptd^.Spectra.y[0], ptd^.q[item].Value);
                                     UpdateGraphData(TGRAPH(ptd^.Spectra), ptd^.iItem)
                                     end { IF };
 //DeleteItem(ptd^.iItem);
 //ptd^.iItem:= AddGraphData(TGRAPH(ptd^.Spectra), ptd^.Color, TRUE);        Writeln('13', ptd^.Spectra.y[0], ptd^.q[item].Value);
 //UpdateGraphData(TGRAPH(ptd^.Spectra), ptd^.iItem);

 ptd^.q[item].Locked:= BOOL(SendDlgItemMessage(VarPropertyDlgWindow, IDC_AUTOCHECKBOX_VAR_LOCK, BM_GETCHECK, 0, 0));

 EndDialog(VarPropertyDlgWindow, 0)

 end { Confirm };

begin
Result:= TRUE;
case msg of WM_INITDIALOG : begin
                            DWORD(EditRMSEWndProcOld):= SetWindowLong(GetDlgItem(VarPropertyDlgWindow, IDC_EDIT_VAR_RMSE), GWL_WNDPROC, DWORD(@EditRMSEWndProc));

                            //bfdialogs.VarPropertyDlgWindow:= VarPropertyDlgWindow;
                            SetWindowText(VarPropertyDlgWindow, PChar(ptd^.FuncStruct.Constants[item]));
                            //SetDlgItemText(VarPropertyDlgWindow, IDC_EDIT_VAR_VAL, PChar(FloatToStr(pqi^.Value)));
                            FillEdit(ptd^.q[item].Value, IDC_EDIT_VAR_VAL);
                            FillEdit(ptd^.q[item].Min, IDC_EDIT_VAR_MIN);
                            FillEdit(ptd^.q[item].Max, IDC_EDIT_VAR_MAX);
                            FillEdit(ptd^.q[item].Step, IDC_EDIT_VAR_STEP);
                            SendDlgItemMessage(VarPropertyDlgWindow, IDC_EDIT_VAR_PRECISION, EM_SETREADONLY, Integer(not hjd.SeparatePrecision), 0);
                            if (hjd.SeparatePrecision) then FillEdit(ptd^.q[item].Precision, IDC_EDIT_VAR_PRECISION)
                                                       else SetDlgItemText(VarPropertyDlgWindow, IDC_EDIT_VAR_PRECISION, PChar(GeneralPrecTxt)) { IF };
                            FillEdit(ptd^.q[item].rmse, IDC_EDIT_VAR_RMSE);
                            SendDlgItemMessage(VarPropertyDlgWindow, IDC_AUTOCHECKBOX_VAR_LOCK, BM_SETCHECK, DWORD(ptd^.q[item].Locked), 0);
                            //SendDlgItemMessage(VarPropertyDlgWindow, IDC_EDIT_VAR_RMSE, EM_SETREADONLY, DWORD(TRUE), 0)
                            end { WM_INITDIALOG };
            WM_CLOSE : EndDialog(VarPropertyDlgWindow, 0) { WM_CLOSE };
            WM_CTLCOLOREDIT : if (GetDlgCtrlID(lParam) = IDC_EDIT_VAR_RMSE) then if (IsValidSpectra(ptd^.Spectra)) then SetTextColor(wParam, RGB(0, 180, 0))
                                                                                                                   else SetTextColor(wParam, RGB(255, 0, 0)) { IF } { IF } { WM_CTLCOLOREDIT };
            WM_COMMAND : if (lParam = 0) then case Word(wParam) of IDCANCEL : EndDialog(VarPropertyDlgWindow, 0) { IDCANCEL };
                                                                   IDOK : Confirm() { IDOK }
                                              end { CASE }
                                         else case Word(wParam) of IDOK : Confirm() { IDOK };
                                                                   //IDC_AUTOCHECKBOX_VAR_LOCK : if (Word(wParam shr 16) = BN_CLICKED) then ptd^.q[item].Locked:= BOOL(SendDlgItemMessage(VarPropertyDlgWindow, IDC_AUTOCHECKBOX_VAR_LOCK, BM_GETCHECK, 0, 0)) { IF } { IDC_AUTOCHECKBOX_SOR } // BST_CHECKED/BST_UNCHECKED
                                              end { CASE } { IF } { WM_COMMAND }
         else Result:= FALSE { ELSE }
end { CASE }

end { VarPropertyDlgProc };

procedure OnVarSelectionRequest(Parent : HWND; uItem : Integer; var td : TTASKDEFINITION);
begin                                           
item:= uItem;
ptd:= @td;
DialogBoxParam(SysInit.HInstance, 'var', Parent, @VarPropertyDlgProc, 0)

end { OnVarSelectionRequest };

function TargetFuncTickTest(nIter : DWORD; Func : Pointer; ARG : Pointer) : LONGLONG; stdcall; assembler;

var CurrentThread,
    CurrentProcess : THandle;
    ThreadPriority : Integer;
    PriorityClass : DWORD; 

asm     
        //push ESI
        //push EDI
        //push ECX
        pushad

        mov EBX, ARG
        //push EBX

        call GetCurrentThread
        mov CurrentThread, EAX
        push EAX
        call GetThreadPriority
        mov ThreadPriority, EAX

        call GetCurrentProcess
        mov CurrentProcess, EAX
        push EAX
        call GetPriorityClass
        mov PriorityClass, EAX

        push THREAD_PRIORITY_TIME_CRITICAL
        push CurrentThread
        call SetThreadPriority

        push REALTIME_PRIORITY_CLASS
        push CurrentProcess
        call SetPriorityClass
        
        //pop EBX

        mov dword ptr [Result], 0
        mov dword ptr [Result + 4], 0

        FNINIT
        mov ECX, nIter 
@loop:  db 00Fh, 031h // rdtsc // ReaD Time Stamp Counter
        push EAX
        push EDX

        push EBX
        call Func
        
        db 00Fh, 031h // rdtsc
        pop EDI
        pop ESI
        sub EAX, ESI 
        sbb EDX, EDI
        add dword ptr [Result], EAX  
        adc dword ptr [Result + 4], EDX  
        FSTP ST
        loop @loop

        //FNINIT
        FILD Result 
        FIDIV nIter
        FISTP Result

        push ThreadPriority
        push CurrentThread
        call SetThreadPriority

        push PriorityClass
        push CurrentProcess
        call SetPriorityClass  

        popad
        //pop ECX
        //pop EDI
        //pop ESI

end { TargetFuncTickTest };
 
function SettingsDlgProc(SettingsDlgWindow : HWND; msg : UINT; wParam : WPARAM; lParam : LPARAM) : BOOL; stdcall;
begin
Result:= TRUE;                          
case msg of WM_INITDIALOG : begin // IDC_EDIT_EXPRESION IDC_EDIT_TICKS IDC_EDIT_CORESPEED
                            //Result:= FALSE; 
                            //SendDlgItemMessage(SettingsDlgWindow, IDC_EDIT_EXPRESION, EM_SETREADONLY, Integer(TRUE), 0);
                            //SendDlgItemMessage(SettingsDlgWindow, IDC_EDIT_WEIGHT, EM_SETREADONLY, Integer(TRUE), 0);
                            //SendDlgItemMessage(SettingsDlgWindow, IDC_EDIT_CORESPEED, EM_SETREADONLY, Integer(TRUE), 0);
                            //SendDlgItemMessage(SettingsDlgWindow, IDC_EDIT_TICKS, EM_SETREADONLY, Integer(TRUE), 0);

                            SetDlgItemText(SettingsDlgWindow, IDC_EDIT_EXPRESION, PChar('_yc=' + ptd^.FuncStruct.Functions[0].Expresion));
                            SetDlgItemText(SettingsDlgWindow, IDC_EDIT_WEIGHT, PChar(ptd^.weights.Functions[ptd^.wi].Expresion));

                            SetDlgItemInt(SettingsDlgWindow, IDC_EDIT_TICKS, TicksCount, FALSE);
                            //SetDlgItemText(SettingsDlgWindow, IDC_EDIT_TICKS, PChar(IntToStr(DWORD(TargetFuncTickTest(MAX_PATH, @ptd^.FuncStruct.Functions[0].EntryPoint, @point)))));
                                                                                   
                            SetDlgItemInt(SettingsDlgWindow, IDC_EDIT_CORESPEED, CPUSpeed, FALSE);

                            //SetFocus(GetDlgItem(SettingsDlgWindow, IDOK))
                            end { WM_INITDIALOG };
            WM_COMMAND : if (lParam = 0) then case Word(wParam) of IDCANCEL, IDOK : EndDialog(SettingsDlgWindow, 0) { IDCANCEL, IDOK }
                                              end { CASE }
                                         else case Word(wParam) of IDOK : EndDialog(SettingsDlgWindow, 0) { IDOK }
                                              end { CASE } { IF } { WM_COMMAND };
            WM_CLOSE : EndDialog(SettingsDlgWindow, 0) { WM_CLOSE }
         else Result:= FALSE { ELSE }
end { CASE }

end { SettingsDlgProc };

procedure OnFuncSettingsRequest(Parent : HWND ;var td : TTASKDEFINITION);

var index : DWORD;

begin
ptd:= @td;
td.FuncStruct.DSC:= GlobalAlloc(GPTR, (td.FuncStruct.ENTIRETYSC + 1) shl 3);
for index:= 0 to (td.FuncStruct.ENTIRETYSC) do PReal(td.FuncStruct.DSC + DWORD(index shl 3))^:= 1.0 { FOR };
TicksCount:= TargetFuncTickTest($FF, @td.FuncStruct.Functions[0].EntryPoint, @point); // где-то тут EBX требуется...
GlobalFree(td.FuncStruct.DSC);
CPUSpeed:= GetCPUFreq();
//bfdialogs.ReadOnly:= ReadOnly;
DialogBoxParam(SysInit.HInstance, 'info', Parent, @SettingsDlgProc, 0)

end { OnFuncSettingsRequest };

var EditPriorityWndProcOld : TFNWndProc;

function EditPriorityWndProc(hwndEditFunc : HWND; msg : UINT; wParam : WPARAM; lParam: LPARAM) : LRESULT; stdcall;
begin
Result:= 0;
case msg of WM_CHAR : begin
                      case wParam of $30..$32 :  { $30..$32 };
                                     VK_NUMPAD0, VK_NUMPAD1, VK_NUMPAD2 : Dec(wParam, $30) { VK_NUMPAD0, VK_NUMPAD1, VK_NUMPAD2 }
                                  else Exit { ELSE }                                        
                      end { CASE };   
                      pThreadPriority^:= $30 - wParam; // THREAD_PRIORITY_NORMAL THREAD_PRIORITY_LOWEST THREAD_PRIORITY_BELOW_NORMAL
                      SetWindowText(hwndEditFunc, @wParam) // Старшие байты всегда равны нулю -> получается null-terminated string 
                      //if (IsThreadStarted()) then SetThreadPriority(hMathThread, ThreadPriority) { IF }
                      end { WM_CHAR };
         else Result:= CallWindowProc(EditPriorityWndProcOld, hwndEditFunc, msg, wParam, lParam) { ELSE }
end { CASE }                        

end { EditPriorityWndProc };    

var hwndEditPriority,
    hwndEditTimeOut,
    hwndEditPrecision : HWND;

function HJPropertyDlgProc(HJDlgWindow : HWND; msg : UINT; wParam : WPARAM; lParam : LPARAM) : BOOL; stdcall;

var itmpvar : DWORD;

 procedure Confirm();

 var rtmpvar : Real; 

 begin
 TimeOutVal:= GetDlgitemInt(HJDlgWindow, IDC_EDIT_HJPROPERTY_TIMEOUT, Result, FALSE);

 fInfCheck.bool:= IsWindowEnabled(hwndEditTimeOut);

 if (fInfCheck.bool) then hjd.TimeOut:= TimeOutVal
                     else hjd.TimeOut:= INFINITE { IF };
                     
 GetDlgItemText(HJDlgWindow, IDC_EDIT_HJPROPERTY_DIVISOR, Buffer, MAX_PATH - 1);
 rtmpvar:= StrToFloat(Buffer);
 if (rtmpvar > 1.0) then begin
                         DivisorTxt:= Buffer;
                         hjd.Divisor:= rtmpvar
                         end
                    else begin
                         MessageBox(HJDlgWindow, 'Делитель должен быть больше 1.0', ERROR_, MB_OK or MB_ICONERROR);
                         Result:= FALSE
                         end { IF };

 hjd.SeparatePrecision:= not IsWindowEnabled(hwndEditPrecision);    

 GetDlgItemText(HJDlgWindow, IDC_EDIT_HJPROPERTY_PREC, Buffer, MAX_PATH - 1); 
 Val(Buffer, rtmpvar, itmpvar);
 if ((rtmpvar >= 0.0) and (itmpvar = 0)) then begin
                                              GeneralPrecTxt:= Buffer;
                                              hjd.Precision:= rtmpvar
                                              end
                                         else begin
                                              MessageBox(HJDlgWindow, 'Общий предел шагов должен быть числом не меньшим 0.0', ERROR_, MB_OK or MB_ICONERROR);
                                              Result:= FALSE
                                              end { IF };

 if (Result) then EndDialog(HJDlgWindow, 0) { IF }
 
 end { Confirm };

begin
Result:= TRUE;
case msg of WM_INITDIALOG : begin
                            hwndEditPriority:= GetDlgItem(HJDlgWindow, IDC_EDIT_PRIORITY);
                            hwndEditTimeOut:= GetDlgItem(HJDlgWindow, IDC_EDIT_HJPROPERTY_TIMEOUT);
                            hwndEditPrecision:= GetDlgItem(HJDlgWindow, IDC_EDIT_HJPROPERTY_PREC);
                                      
                            SetDlgItemText(HJDlgWindow, IDC_EDIT_HJPROPERTY_DIVISOR, PChar(DivisorTxt));
                            SetDlgItemText(HJDlgWindow, IDC_EDIT_HJPROPERTY_PREC, PChar(GeneralPrecTxt)); 
                            SetDlgItemInt(HJDlgWindow, IDC_EDIT_HJPROPERTY_TIMEOUT, TimeOutVal, FALSE);

                            SendMessage(hwndEditPriority, EM_LIMITTEXT, 1, 0);
                            DWORD(EditPriorityWndProcOld):= SetWindowLong(hwndEditPriority, GWL_WNDPROC, DWORD(@EditPriorityWndProc));
                            itmpvar:= $30 - pThreadPriority^;
                            SetDlgItemText(HJDlgWindow, IDC_EDIT_PRIORITY, @itmpvar);

                            SendDlgItemMessage(HJDlgWindow, IDC_AUTORADIOBUTTON_HJPROPERTY_INF, BM_SETCHECK, DWORD(not fInfCheck.bool), 0);
                            SendDlgItemMessage(HJDlgWindow, IDC_AUTORADIOBUTTON_HJPROPERTY_VAL, BM_SETCHECK, DWORD(fInfCheck.bool), 0);
                            SendDlgItemMessage(HJDlgWindow, IDC_AUTOCHECKBOX_PREC, BM_SETCHECK, DWORD(not hjd.SeparatePrecision), 0); 

                            EnableWindow(hwndEditTimeOut, fInfCheck.bool);
                            EnableWindow(hwndEditPrecision, not hjd.SeparatePrecision)
                            end { WM_INITDIALOG };
            WM_COMMAND : if (lParam = 0) then case Word(wParam) of IDCANCEL : EndDialog(HJDlgWindow, 0) { IDCANCEL };
                                                                   IDOK : Confirm() { IDOK }               
                                              end { CASE }
                                         else case Word(wParam) of IDOK : Confirm() { IDOK };
                                                                   IDC_AUTORADIOBUTTON_HJPROPERTY_INF : if ((wParam shr 32) = BN_CLICKED) then EnableWindow(hwndEditTimeOut, FALSE) { IF } { IDC_AUTORADIOBUTTON_HJPROPERTY_INF };
                                                                   IDC_AUTORADIOBUTTON_HJPROPERTY_VAL : if ((wParam shr 32) = BN_CLICKED) then EnableWindow(hwndEditTimeOut, TRUE) { IF } { IDC_AUTORADIOBUTTON_HJPROPERTY_VAL };
                                                                   IDC_AUTOCHECKBOX_PREC : if (Word(wParam shr 16) = BN_CLICKED) then EnableWindow(hwndEditPrecision, (SendDlgItemMessage(HJDlgWindow, IDC_AUTOCHECKBOX_PREC, BM_GETCHECK, 0, 0) = BST_CHECKED)) { IF } { IDC_AUTOCHECKBOX_PREC };
                                              end { CASE } { IF } { WM_COMMAND };
            WM_CTLCOLOREDIT : if (HWND(lParam) = hwndEditPriority) then SetTextColor(wParam, RGB(0, 0, 255)) { IF } { WM_CTLCOLOREDIT };
            WM_CLOSE : EndDialog(HJDlgWindow, 0) { WM_CLOSE }
         else Result:= FALSE { ELSE }              
end { CASE }

end { HJPropertyDlgProc };

procedure OnHJPropertyRequest(Parent : HWND; ptp : PInteger);
begin
pThreadPriority:= ptp;
DialogBoxParam(SysInit.HInstance, 'hj', Parent, @HJPropertyDlgProc, 0)

end { OnHJPropertyRequest };

var CustomColors : array[0..15] of COLORREF = (0, 65280, 16711680, 255, 16711935, 16776990, 65535, 16777215, 16777215, 16777215, 16777215, 16777215, 16777215, 0, 14211288, 11711154);  

procedure ChooseGraphColor(HandleWindow : HWND; var Color : COLORREF);

var cc : TChooseColor;

begin
CustomColors[0]:= Color;
with cc do begin
           lStructSize:= SizeOf(TChooseColor);
           Flags:= CC_RGBINIT or CC_FULLOPEN;
           rgbResult:= Color;
           hWndOwner:= HandleWindow; 
           lpCustColors:= @CustomColors;
           if (ChooseColor(cc)) then begin
                                     CustomColors[0]:= rgbResult;
                                     Color:= rgbResult
                                     end { IF }
           end { cc }

end { ChooseGraphColor };

function GraphPropertyDlgProc(GDlgWindow : HWND; msg : UINT; wParam : WPARAM; lParam : LPARAM) : BOOL; stdcall;

 procedure Confirm();
 begin
 with a2peak do begin
                sVisible:= (SendDlgItemMessage(GDlgWindow, IDC_AUTOCHECKBOX_1ST2PEAK, BM_GETCHECK, 0, 0) = BST_CHECKED);
                ShowItem(sItem, sVisible)
                end { a2peak };

 EndDialog(GDlgWindow, 0)
 
 end { Confirm };

begin
Result:= TRUE;
case msg of WM_INITDIALOG : begin
                            SendDlgItemMessage(GDlgWindow, IDC_AUTOCHECKBOX_1ST2PEAK, BM_SETCHECK, DWORD(a2peak.sVisible), 0)
                            end { WM_INITDIALOG };
            WM_COMMAND : if (lParam = 0) then case Word(wParam) of IDCANCEL : EndDialog(GDlgWindow, 0) { IDCANCEL };
                                                                   IDOK : Confirm() { IDOK } 
                                              end { CASE }
                                         else case Word(wParam) of IDOK : Confirm() { IDOK };
                                                                   IDC_BUTTON_COLOR1PEAK : with a1peak do begin
                                                                                                          ChooseGraphColor(GDlgWindow, td.Color);
                                                                                                          SetItemColor(td.iItem, td.Color);
                                                                                                          SetItemColor(a2peak.sItem, td.Color)
                                                                                                          end { a1peak } { IDC_BUTTON_COLOR1PEAK };
                                                                   IDC_BUTTON_COLOR2PEAK : with a2peak do begin
                                                                                                          ChooseGraphColor(GDlgWindow, td.Color);
                                                                                                          SetItemColor(td.iItem, td.Color)
                                                                                                          end { a2peak } { IDC_BUTTON_COLOR2PEAK };
                                                                   IDC_BUTTON_COLORSS : with ss do begin
                                                                                                   ChooseGraphColor(GDlgWindow, Color);
                                                                                                   SetItemColor(iItem, Color)
                                                                                                   end { ss } { IDC_BUTTON_COLORSS }
                                              end { CASE } { IF } { WM_COMMAND };  
            WM_CLOSE : EndDialog(GDlgWindow, 0) { WM_CLOSE }                              
         else Result:= FALSE { ELSE }              
end { CASE }

end { GraphPropertyDlgProc };

procedure GraphPropertyRequest(Parent : HWND);
begin
DialogBoxParam(SysInit.HInstance, 'graph', Parent, @GraphPropertyDlgProc, 0)

end { GraphPropertyRequest };

INITIALIZATION 

FINALIZATION

END { BFDIALOGS }.
