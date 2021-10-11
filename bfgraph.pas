{ © 2007 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfgraph; 
// Функции для сабклассирования статика и управления им
// (можно и не статик, только необходимо дополняемые стили соответственно заменить).
// Статик служит для вывода двумерных графиков.
// В итоге получается аналог визуального компонента TChart
// (функциональность я вообще в большей степени копировал).
// Работа с растровыми шрифтами (BuildFont, glPrint (тут glDrawText)): http://nehe.gamedev.net © Jeff Molofee (NeHe)

INTERFACE      

uses Windows;

type TGRAPHAXIES = array of Real { TGRAPHAXIES };

type //PGRAPH = ^TGRAPH;
     TGRAPH = record
              x,                  
              y : TGRAPHAXIES
              end { TGRAPH };

var RightButtonClickHandler : procedure(); // Обработчик одиночного клика правой кнопкой  
    LeftButtonDoubleClickHandler : procedure(); // Обработчик двойного клика левой кнопкой

var SelectNotDrag : BOOL = FALSE; // Определяет свойства правой кнопки мыши               

procedure SubClassGraphStatic(hwndStatic : HWND); // on WM_CREATE - сабклассинг контрола 
procedure ResizeGraphStatic(X, Y, nWidth, nHeight : Integer); // on WM_RESIZE - можно и не по WM_RESIZE
procedure OptimizeZoom(); // Масштабирует и центрует график так, что видно все графики полностью +zoomgraph по высоте и ширине по краям с каждого краю, может быть вызвана до создания статика
procedure SetZoom(const xfrom, yfrom, xto, yto : Real); // Позволяет отмасштабировть и отцентровать график по указаным пределам
procedure OnChangeGraphStaticState(); // Вся логика подписей по осям содержится здесь (основа компонента), не должна вызваться до сабклассирования статика (SubClassGraphStatic)
//procedure ShowSelectRange(Visible : BOOL);
procedure GetSelectRange(out startpos, endpos : Real); // Возвращает в указаные переменные значения границ диапазона выделенных отсчётов по оси абсцисс
procedure SetSelectRange(const startpos, endpos : Real); // Задаёт в указаные переменные значения границ диапазона выделяемых отсчётов по оси абсцисс
procedure ResetSelectRange(const pos : Real); // Задаёт значение границ диапазона выделенных отсчётов по оси абсцисс равным pos 
function AddGraphData(const Graph : TGRAPH; RGB : COLORREF; Visible : BOOL) : Integer; // Возвращает zero-based индекс, для обращения к графику спектра, может быть вызвана до создания статика
procedure UpdateGraphData(const Graph : TGRAPH; n : Integer); // Служит для динамичесого обновления конкретного графика
//function AddSingleLine(const xfrom, yfrom, xto, yto : Real; RGB : COLORREF) : Integer; // Возвращает zero-based индекс, для обращения к линии, может быть вызвана до создания статика
//procedure UpdateGraphLine(const xfrom, yfrom, xto, yto : Real; n : Integer); // Служит для динамичесого обновления конкретного графика линии
procedure DeleteItem(var n : Integer); // Удаляет из списка отображения названный график/линию и задаёт n равным -1
procedure ClearSpectra(); // Удаляет все отображаемые TGRAPH
procedure SetItemColor(n : Integer; Color : COLORREF); // Для TGRAPH номер n задаёт цвет Color 
//function GetMaxItem() : Integer; // Возвращает максимальный номер графика, который есть в списке
//procedure GetXYDisplayRange(out xfrom, yfrom, xto, yto : Real);
procedure ShowItem(n : Integer; Visible : BOOL); // Управление отображением названного графика

IMPLEMENTATION

uses Messages,
     OpenGL,
     bfsysutils;

var hwndStatic : HWND;

//var cs : TRTLCriticalSection;

function MantissaByTenPower(const Val : Real; Exponent : Integer) : Real; stdcall;    
asm 
        FNINIT

        FLD Val // Val == s2*2^e2 
        FXTRACT // s2 e2

        FILD Exponent // de s2 e2
        FLDLG2 // lg2 de s2 e2
        FDIV // de/lg2 s2 e2 // (/lg2) == (*log(sub(2)(10)))
        FSUBP ST(2), ST // s2 (e2 - de/lg2)

        FXCH // (e2 - de/lg2) s2 

        FLD ST // (e2 - de/lg2) (e2 - de/lg2) s2
        FRNDINT // [e2 - de/lg2] (e2 - de/lg2) s2
        FSUB ST(1), ST // [e2 - de/lg2] {e2 - de/lg2} s2
        FXCH // {e2 - de/lg2} [e2 - de/lg2] s2
        F2XM1 // (2^{e2 - de/lg2} - 1) [e2 - de/lg2] s2
        FLD1 // 1.0 (2^{e2 - de/lg2} - 1) [e2 - de/lg2] s2
        FADD // 2^{e2 - de/lg2} [e2 - de/lg2] s2
        FSCALE // 2^{e2 - de/lg2}*2^[e2 - de/lg2] [e2 - de/lg2] s2
        FSTP ST(1) // 2^{e2 - de/lg2}*2^[e2 - de/lg2] s2
        FMUL // 2^{e2 - de/lg2}*2^[e2 - de/lg2]*s2
 
        //FSTP Result
         
end { MantissaByTenPower }; 

function RoundUp(const Val : Real) : Integer; stdcall;
asm
        FNINIT
        
        FLDCW cwup
        FLD Val
        FISTP Result
        FLDCW stdcw // Хороший тон (не более того, т.к. тут не влияет ни на что)

end { RoundUp };

function RoundDown(const Val : Real) : Integer; stdcall;
asm
        FNINIT
        
        FLDCW cwdown
        FLD Val
        FISTP Result
        FLDCW stdcw

end { RoundDown };

function XTRACTMANTISSA10(const Radix : Real) : Integer; stdcall;
asm 
        FNINIT

        FLD Radix 
        FXTRACT
        FSTP ST
        FLDLG2
        FMUL 
        FISTP Result  

end { XTRACTMANTISSA10 };

function TenPower(Exponent : Integer) : Real; register; // Возвращает число 10 в целой степени - алгоритм украден в модуле Math

const ten : Extended = 10.0; 

asm         
        FNINIT
 
        mov ECX, Exponent
        cdq
        FLD1
        xor EAX, EDX
        sub EAX, EDX
        jz @end
        FLD ten
        jmp @start
@sqr:   FMUL ST, ST(0)
@start: shr EAX, 1
        jnc @sqr
        FMUL ST(1), ST
        jnz @sqr
        FSTP ST
        cmp ECX, 0 
        jge @end
        FLD1
        FDIVRP
@end:   //FSTP Result

end { TenPower };

const ADDITIONALPXLSV : Integer = 6;
      ADDITIONALPXLSH : Integer = 2;                 

type TFloatPoint = packed record
                          x,
                          y : Real
                          end { TFloatPoint };

type TGRAPHDATA = record
                  Graph : TGRAPH;
                  RGB : COLORREF;
                  Visible : BOOL
                  end { TGRAPHDATA };
 
type TGRAPHDATALIST = array of TGRAPHDATA { TGRAPHDATALIST };

type TDIAPASON = record
                 xfrom,
                 yfrom,
                 xto,
                 yto,
                 deltax,
                 deltay : Real
                 end { TDIAPASON };


var datadiap,
    displaydiap : TDIAPASON;

var DC : HDC;
    RC : HGLRC;
    StaticClientRect : TRect;
    StaticWidth,
    StaticHeight : Integer;
    GLF_STRING_LIST : GLuint;
    SymbolSize : TSize;
    SymbolHeight : Real;
    LButtonDownPos,
    RButtonDownPos,
    CurrentMousePos : TPoint;
                            
var LRecordsWidth,
    BRecordsHeight : Integer;

var sl : TGRAPHDATALIST;

const zoomgraph : Real = 0.05; // - то, что выгодно отличает от TChart в Spectr13 Соломеина =)
      zoomwhell : Real = 0.05; // - фишка из Hammer3D =) 

type AXISRECORD = record
                  str : string;
                  val : Real 
                  end { AXISRECORD }; 

var YAxisRecords,
    XAxisRecords : array of AXISRECORD;

var BKCOLOR,
    GREEDCOLOR,
    TEXTCOLOR,
    FRAMECOLOR : COLORREF;

var SelectFrameVisible : BOOL = FALSE;    

const SELECTFRAME_TIMER = $FE;
      SELECTFRAME_TIMER_INTERVAL : DWORD = 1000 div 50; // 20 мс - время реакции человека :-)

var CatchPoint : TFloatPoint;      

procedure SetDCPixelFormat(DC : HDC);

var pfd : TPIXELFORMATDESCRIPTOR;
    nPixelFormat : Integer;

begin        
ZeroMemory(@pfd, SizeOf(TPIXELFORMATDESCRIPTOR));
with pfd do begin
            nSize:= SizeOf(TPIXELFORMATDESCRIPTOR);                                 // размер структуры
            nVersion:= 1;                                                           // номер версии
            dwFlags:= PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER; // множество битовых флагов, определяющих устройство и интерфейс
            iPixelType:= PFD_TYPE_RGBA;                                             // режим для изображения цветов
            cColorBits:= 16;                                                        // число битовых плоскостей в каждом буфере цвета
            //cRedBits:= 0;                                                           // число битовых плоскостей красного в каждом буфере RGBA
            //cRedShift:= 0;                                                          // смещение от начала числа битовых плоскостей красного в каждом буфере RGBA
            //cGreenBits:= 0;                                                         // число битовых плоскостей зелёного в каждом буфере RGBA
            //cGreenShift:= 0;                                                        // смещение от начала числа битовых плоскостей зелёного в каждом буфере RGBA
            //cBlueBits:= 0;                                                          // число битовых плоскостей синего в каждом буфере RGBA
            //cBlueShift:= 0;                                                         // смещение от начала числа битовых плоскостей синего в каждом буфере RGBA
            //cAlphaBits:= 0;                                                         // число битовых плоскостей альфа в каждом буфере RGBA
            //cAlphaShift:= 0;                                                        // смещение от начала числа битовых плоскостей альфа в каждом буфере RGBA
            //cAccumBits:= 0;                                                         // общее число битовых плоскостей в буфере аккумулятора
            //cAccumRedBits:= 0;                                                      // число битовых плоскостей красного в буфере аккумулятора
            //cAccumGreenBits:= 0;                                                    // число битовых плоскостей зелёного в буфере аккумулятора
            //cAccumBlueBits:= 0;                                                     // число битовых плоскостей синего в буфере аккумулятора
            //cAccumAlphaBits:= 0;                                                    // число битовых плоскостей альфа в буфере аккумулятора
            cDepthBits:= 32;                                                        // размер буфера глубины (ось z)
            //cStencilBits:= 0;                                                       // размер буфера трафарета
            //cAuxBuffers:= 0;                                                        // число вспомогательных буферов
            iLayerType:= PFD_MAIN_PLANE;                                            // тип плоскости
            //bReserved:= 0;                                                          // число плоскостей переднего и заднего плана
            //dwLayerMask:= 0;                                                        // игнорируется
            //dwVisibleMask:= 0;                                                      // индекс или цвет прозрачности нижней плоскости
            //dwDamageMask:= 0                                                        // игнорируется
            end { pfd };

nPixelFormat:= ChoosePixelFormat(DC, @pfd);                                         // запрос системе - поддерживается ли выбранный формат пикселей
SetPixelFormat(DC, nPixelFormat, @pfd)                                              // устанавливаем формат пикселей в контексте устройства
                             
end { SetDCPixelFormat };

function BuildFont(DC : HDC) : HFONT; // Необходима моноширинная гарнитура
begin
GLF_STRING_LIST:= glGenLists(96);

Result:= CreateFont(-12,                          // Высота фонта
                    -7,                           // Ширина фонта
                    0,                            // Угол отношения
                    0,                            // Угол наклона
                    FW_NORMAL,                    // Ширина шрифта
                    0,                            // Курсив
                    0,                            // Подчеркивание
                    0,                            // Перечеркивание
                    ANSI_CHARSET,                 // Идентификатор набора символов
                    OUT_TT_PRECIS,                // Точность вывода
                    CLIP_DEFAULT_PRECIS,          // Точность отсечения
                    ANTIALIASED_QUALITY,          // Качество вывода
                    FF_DONTCARE or DEFAULT_PITCH, // Семейство и шаг
                    'Lucida Console');            // Имя шрифта

SelectObject(DC, Result);
wglUseFontBitmaps(DC, 32, 96, GLF_STRING_LIST);
GetTextExtentPoint32(DC, #32, 1, SymbolSize);
SymbolHeight:= SymbolSize.cy*0.55 + ADDITIONALPXLSV; // +3 пиксела сверху +3 пиксела снизу, число 0.55 - эмпирически

end { BuildFont };

procedure TimerProc(HandleWindow : HWND; msg : UINT; ID_TIMER : UINT; Time : DWORD); stdcall;

var StaticWindowRect : TRect;
    CursorPos : TPoint;

begin                          
case ID_TIMER of SELECTFRAME_TIMER : begin
                                     GetCursorPos(CursorPos);
                                     GetWindowRect(HandleWindow, StaticWindowRect);
                                     if (SelectFrameVisible and not (PtInRect(StaticWindowRect, CursorPos))) then begin
                                                                                                                  SelectFrameVisible:= FALSE;
                                                                                                                  InvalidateRect(HandleWindow, nil, FALSE)
                                                                                                                  end { IF }
                                     end { SELECTFRAME_TIMER }
end { CASE }                                          

end { TimerProc };

procedure OnChangeGraphStaticState(); // Вся логика подписей по осям содержится здесь (основа компонента)

var MAX_LVCOUNT : Integer; // Штуки
    MAX_BHLENGTH : Integer; // Пиксели

var LVCOUNT, BHCOUNT : Integer; // Штуки       

var a, b, c, d,
    interval, index,
    highest, lowest, savedlowest : Integer; // Все FOR-Loop переменные могут быть неопределены после циклов - ну в 6 версии вроде всё норм - видать дело в регистрах, используемых для их сохранения, но все функции, вызываемые тут ничего с ними не делают

label BREAKCIRCLEY, BREAKCIRCLEX; // Плохой тон говорите?

begin // fuzzy logic enhanced here :O // Не претендую на оригинальность, но аналогов не видел и придумал всё сам - чесслово
BRecordsHeight:= Trunc(SymbolHeight) + 1; // Round(SymbolHeight + 0.5) 

// y-axis
MAX_LVCOUNT:= (StaticHeight - BRecordsHeight) div (BRecordsHeight - 2); 
a:= XTRACTMANTISSA10(displaydiap.deltay);
for b:= 0 to (6) do begin // 6 in [3..High(DWORD)], 6 - конечно слишком много и до этого никогда не дойдёт на мониторах с современным разрешением :)                        
                    savedlowest:= RoundUp(MantissaByTenPower(displaydiap.yfrom, a - b)); // Ограниченнность данного представления в том, что число, записанное общим количеством значащих цифр, должно удовлетворять условию: "value must be between –2147483648 and 2147483647". Т.е. 0.02147483648 или 214748.3648 не отобразятся уже
                    highest:= RoundDown(MantissaByTenPower(displaydiap.yto, a - b));     // Надо сделать с FPREM/FPREM1 на действительных числах и своим FloatToStr (уже есть)
                    for interval:= 9 downto (1) do if (MAX_LVCOUNT*interval < (highest - savedlowest)) then goto BREAKCIRCLEY { GOTO } // очень втему 
                                                                                                       else begin
                                                                                                            LVCOUNT:= (highest - savedlowest) div interval;
                                                                                                            lowest:= savedlowest
                                                                                                            end { IF } { FOR } 
                    end { FOR };
                    
BREAKCIRCLEY : { LABEL };
Dec(a, b);
Inc(interval); // компенсируем лишний downto Dec переменной interval
if (interval = 10) then begin // лишние нули в конце нам не нужны
                        interval:= 1;
                        Inc(a)
                        end { IF };               
b:= 0;
SetLength(YAxisRecords, LVCOUNT + 1); // Строка последней подписи создаётся, но не надобится далее
//if ((LVCOUNT = 37) and (a > 0)) then Str(YAxisRecords[16].val:0:0, YAxisRecords[16].str) { IF }; // непонятная ошибка (с AV) методом "интуитивного анализа" устранена так... глупость в общем (файл errpeak.bfs - ошибка была восрпроизводимая до какого-то момента - непнятно (© COMEDY CLUB))
for index:= 0 to (LVCOUNT) do begin
                              YAxisRecords[index].val:= (index*interval + lowest)*TenPower(a);
                              if (a > 0) then Str(YAxisRecords[index].val:0:0, YAxisRecords[index].str)
                                         else Str(YAxisRecords[index].val:0:(-a), YAxisRecords[index].str) { IF };
                              c:= Length(YAxisRecords[index].str);
                              if (b < c) then b:= c { IF }
                              end { FOR };

LRecordsWidth:= SymbolSize.cx*b;

// x-axis
// Длина оси зависит от ширины подписей оси y
MAX_BHLENGTH:= (StaticWidth - (LRecordsWidth + (ADDITIONALPXLSH shr 1))); 
a:= XTRACTMANTISSA10(displaydiap.deltax);
for b:= 0 to (6) do begin  
                    savedlowest:= RoundUp(MantissaByTenPower(displaydiap.xfrom, a - b));
                    highest:= RoundDown(MantissaByTenPower(displaydiap.xto, a - b)); 
                    for interval:= 9 downto (1) do begin
                                                   SetLength(XAxisRecords, (highest - savedlowest + 1) div interval);
                                                   c:= 0;
                                                   for index:= 0 to (((highest - savedlowest) div interval) - 1) do begin // по переменной c проверяем что влезет по максимуму (информации)
                                                                                                                   XAxisRecords[index].val:= (index*interval + savedlowest)*TenPower(a - b);
                                                                                                                   if (a > b) then Str(XAxisRecords[index].val:0:0, XAxisRecords[index].str)
                                                                                                                              else Str(XAxisRecords[index].val:0:(b - a), XAxisRecords[index].str) { IF };
                                                                                                                   d:= Length(XAxisRecords[index].str);
                                                                                                                   if (c < d) then c:= d { IF }
                                                                                                                   end { FOR };
                                                   if (MAX_BHLENGTH*interval < (SymbolSize.cx + (ADDITIONALPXLSH shr 1))*c*(highest - savedlowest)) then goto BREAKCIRCLEX { GOTO } // ну очень втему
                                                                                                                                                    else begin
                                                                                                                                                         BHCOUNT:= (highest - savedlowest) div interval;
                                                                                                                                                         lowest:= savedlowest
                                                                                                                                                         end { IF }
                                                   end { FOR }
                    end { FOR };

BREAKCIRCLEX : { LABEL };                    
Dec(a, b);
Inc(interval);
if (interval = 10) then begin  
                        interval:= 1;
                        Inc(a)
                        end { IF };
SetLength(XAxisRecords, BHCOUNT + 1);
for index:= 0 to (BHCOUNT) do begin
                              XAxisRecords[index].val:= (index*interval + lowest)*TenPower(a); 
                              if (a > 0) then Str(XAxisRecords[index].val:0:0, XAxisRecords[index].str)
                                         else Str(XAxisRecords[index].val:0:(-a), XAxisRecords[index].str) { IF }
                              end { FOR };

InvalidateRect(hwndStatic, nil, FALSE)                                  

end { OnChangeGraphStaticState };  

function GetGraphCoord(X, Y : Integer; out fp : TFloatPoint) : BOOL;
begin
Result:= ((X > 0) and (Y > 0) and (X > LRecordsWidth) and (Y < StaticHeight - BRecordsHeight));
                               
fp.x:= displaydiap.deltax*(X - LRecordsWidth)/(StaticWidth - LRecordsWidth) + displaydiap.xfrom;
fp.y:= displaydiap.yto - displaydiap.deltay*Y/(StaticHeight - BRecordsHeight)
          
end { GetGraphCoord };

procedure LButtonDownFunc(X, Y : Word);
begin
SetCapture(hwndStatic);
LButtonDownPos.X:= X;
LButtonDownPos.Y:= Y

end { LButtonDownFunc };

procedure LButtonUpFunc(X, Y : Word);

var StartPoint,
    FinishPoint : TFloatPoint;

begin
ReleaseCapture();
if not (SelectFrameVisible) then begin
                                 LButtonDownPos.X:= 0;
                                 LButtonDownPos.Y:= 0;
                                 InvalidateRect(hwndStatic, nil, FALSE);
                                 Exit
                                 end { IF };

if ((X - LButtonDownPos.X > 20) and (Y - LButtonDownPos.Y > 20)) then if (GetGraphCoord(LButtonDownPos.X, LButtonDownPos.Y, StartPoint) and GetGraphCoord(X, Y, FinishPoint)) then with displaydiap do begin
                                                                                                                                                                                                       xfrom:= StartPoint.x;
                                                                                                                                                                                                       yfrom:= FinishPoint.y;
                                                                                                                                                                                                       xto:= FinishPoint.x;
                                                                                                                                                                                                       yto:= StartPoint.y;
                                                                                                                                                                                                       deltax:= xto - xfrom;
                                                                                                                                                                                                       deltay:= yto - yfrom
                                                                                                                                                                                                       end { WITH } { IF };


SelectFrameVisible:= FALSE;

if (((X - LButtonDownPos.X < 0) or (Y - LButtonDownPos.Y < 0)) and ((Abs(X - LButtonDownPos.X) > 20) or (Abs(Y - LButtonDownPos.Y) > 20))) then OptimizeZoom() { IF };
OnChangeGraphStaticState();    

LButtonDownPos.X:= 0;
LButtonDownPos.Y:= 0

end { LButtonUpFunc };      

var SelectRange : record
                  startpos,
                  endpos : Real;
                  //Visible : BOOL;
                  RGB : COLORREF
                  end { SelectRange } = (startpos : -1E10; endpos : -1E10);

var startpos : Real;
    IsSelectionBegining : BOOL;

procedure ResetSelectRange(const pos : Real);
begin
SelectRange.startpos:= pos;
SelectRange.endpos:= pos

end { ResetSelectRange };   

procedure GetSelectRange(out startpos, endpos : Real);
begin
startpos:= SelectRange.startpos;
endpos:= SelectRange.endpos

end { GetSelectRange };                  

procedure SetSelectRange(const startpos, endpos : Real);
begin
SelectRange.startpos:= startpos;
SelectRange.endpos:= endpos 

end { SetSelectRange };  
(*
procedure ShowSelectRange(Visible : BOOL);
begin
SelectRange.Visible:= Visible

end { ShowSelectRange }; *)

procedure MWheelFunc(wParam : Integer);

var rw, rh, factor : Real;

begin
rw:= 1.0/(StaticWidth - LRecordsWidth);
rh:= 1.0/(StaticHeight - BRecordsHeight);
factor:= (PSmallInt(DWORD(@wParam) + 2)^/120.0)*zoomwhell;
with displaydiap do begin
                    xfrom:= xfrom - factor*deltax*(CurrentMousePos.X - LRecordsWidth)*rw;
                    yfrom:= yfrom - factor*deltay*(1.0 - CurrentMousePos.Y*rh);
                    xto:= xto + factor*deltax*(1.0 - (CurrentMousePos.X - LRecordsWidth)*rw);
                    yto:= yto + factor*deltay*CurrentMousePos.Y*rh;
                    deltax:= xto - xfrom;
                    deltay:= yto - yfrom;
                    OnChangeGraphStaticState() 
                    end { WITH }
                    
end { MWheelFunc };

procedure RButtonDownFunc(X, Y : Word); 
begin             
RButtonDownPos.X:= X;
RButtonDownPos.Y:= Y;

if (SelectNotDrag) then begin
                        IsSelectionBegining:= TRUE
                        end
                   else begin
                        CatchPoint.x:= displaydiap.xfrom;
                        CatchPoint.y:= displaydiap.yfrom
                        end { IF }

end { RButtonDownFunc };

procedure RButtonUpFunc(X, Y : Word);
begin                   
if ((RButtonDownPos.X = X) and (RButtonDownPos.Y = Y)) then begin
                                                            RightButtonClickHandler();
                                                            //SelectNotDrag:= FALSE
                                                            //IsSelectionBegining:= FALSE
                                                            end { IF } // !проверку (RightButtonClickHandler = nil)

end { RButtonUpFunc }; 

procedure MouseMoveFunc(X, Y : Word; fwKeys : Integer);

var void : TFloatPoint;
    StaticWindowRect : TRect;
    CursorPos : TPoint;

begin
if (Length(sl) = 0) then Exit { IF };
CurrentMousePos.X:= X;
CurrentMousePos.Y:= Y;
if (((CurrentMousePos.X - LButtonDownPos.X > 20) and (CurrentMousePos.Y - LButtonDownPos.Y > 20)) or (((CurrentMousePos.X - LButtonDownPos.X < 0) or (CurrentMousePos.Y - LButtonDownPos.Y < 0)) and ((Abs(CurrentMousePos.X - LButtonDownPos.X) > 20) or (Abs(CurrentMousePos.Y - LButtonDownPos.Y) > 20)))) then FRAMECOLOR:= RGB(255, 255, 255)
                                                                                                                                                                                                                                                                                                              else FRAMECOLOR:= RGB(255, 0, 0) { IF };
// fwKeys - одна кнопка нажата
case fwKeys of MK_LBUTTON : begin 
                            GetWindowRect(hwndStatic, StaticWindowRect);
                            GetCursorPos(CursorPos);
                            SelectFrameVisible:= GetGraphCoord(LButtonDownPos.X, LButtonDownPos.Y, void) and GetGraphCoord(X, Y, void) and PtInRect(StaticWindowRect, CursorPos); // +timer
                            if (SelectFrameVisible) then InvalidateRect(hwndStatic, nil, FALSE) { IF }
                            end { MK_LBUTTON };
               MK_RBUTTON : begin      
                            if (SelectNotDrag) then begin
                                                    if (IsSelectionBegining) then begin
                                                                                  IsSelectionBegining:= FALSE;
                                                                                  startpos:= displaydiap.xfrom + displaydiap.deltax*(RButtonDownPos.X - LRecordsWidth)/(StaticWidth - LRecordsWidth)
                                                                                  end { IF };
                                                    if ((RButtonDownPos.X <> X) and (RButtonDownPos.Y <> Y)) then SetSelectRange(startpos, displaydiap.xfrom + displaydiap.deltax*(CurrentMousePos.X - LRecordsWidth)/(StaticWidth - LRecordsWidth)) { IF }
                                                    end
                                               else with displaydiap do begin
                                                                        xfrom:= CatchPoint.x + deltax*(RButtonDownPos.X - CurrentMousePos.X)/(StaticWidth - LRecordsWidth);
                                                                        yfrom:= CatchPoint.y + deltay*(CurrentMousePos.Y - RButtonDownPos.Y)/(StaticHeight - BRecordsHeight);
                                                                        xto:= xfrom + deltax;
                                                                        yto:= yfrom + deltay
                                                                        end { displaydiap } { IF };
                            OnChangeGraphStaticState()
                            end { MK_RBUTTON }                 
            else SelectFrameVisible:= FALSE { ELSE }
end { CASE }            


end { MouseMoveFunc };

procedure glDrawText(TEXT : PChar);
begin
glPushAttrib(GL_LIST_BIT);
glListBase(GLF_STRING_LIST - 32);                   // Задать базу символа в 32
glCallLists(lstrlen(TEXT), GL_UNSIGNED_BYTE, TEXT); // Текст списками отображения
glPopAttrib()

end { glDrawText };

type TRecordTextOrientation = (RIGHTC, TOPC, LEFTC, BOTTOMC);

// Надпись шириной LRecordsWidth текста шириной W, ориентированого относительно указаной точки и выравненного
procedure DrawOrientedText(const S : string; x, y : Real; ORIENT : TRecordTextOrientation);

var W : Integer;

begin
W:= SymbolSize.cx*Length(S); 

case ORIENT of (*RIGHTC : begin
                        //x:= x; 
                        y:= y - 0.25*displaydiap.deltay*BRecordsHeight/StaticHeight
                        end { RIGHTC };
               TOPC : begin
                      x:= x - 0.5*displaydiap.deltax*W/StaticWidth; 
                      y:= y - BRecordsHeight/StaticHeight
                      end { TOPC };  *)
               LEFTC : begin    
                       x:= x + ((LRecordsWidth - W) shl 1)/StaticWidth;
                       y:= y - 0.25*BRecordsHeight/StaticHeight
                       end { LEFTC };
               BOTTOMC : begin       
                         //y:= y + 0 // Располагаем выше
                         x:= x - 0.5*W/StaticWidth 
                         end { BOTTOMC };
end { CASE }; 

// text
glColor3ubv(@TEXTCOLOR);        
glRasterPos2f(x, y);  
glDrawText(PChar(S))

end { DrawOrientedText }; 

function IsValidGraphData(Graph : TGRAPH) : BOOL;

var L : Integer;

begin
L:= Length(Graph.x);
Result:= (L > 1) and (L = Length(Graph.y))

end { IsValidGraphData };

procedure OnResizeProc();
begin
LButtonDownPos.X:= 0;
LButtonDownPos.Y:= 0;
GetClientRect(hwndStatic, StaticClientRect);
StaticWidth:= StaticClientRect.Right - StaticClientRect.Left;
StaticHeight:= StaticClientRect.Bottom - StaticClientRect.Top;
OnChangeGraphStaticState() 

end { OnResizeProc };

procedure OnPaintProc();

var index, index0 : Integer;

var GraphOffsetX, GraphScaleX : Real; // смещаем в правый...
    GraphOffsetY, GraphScaleY : Real; // ...верхний угол

var srlp, srrp, srlbp, srrbp : Real;
    rw, rh : Real;
    rx, ry : Real;
    x1param, y1param,
    x2param, y2param : Real;

begin 
rw:= 1.0/StaticWidth;       
rh:= 1.0/StaticHeight;

rx:= 1.0/displaydiap.deltax;
ry:= 1.0/displaydiap.deltay;

GraphOffsetX:= LRecordsWidth*rw;
GraphScaleX:= (StaticWidth - LRecordsWidth)*rw;

GraphOffsetY:= BRecordsHeight*rh;
GraphScaleY:= (StaticHeight - BRecordsHeight)*rh;

glPushMatrix();
glTranslatef(GraphOffsetX - GraphScaleX, GraphOffsetY - GraphScaleY, 0.0);
glScalef(GraphScaleX + GraphScaleX, GraphScaleY + GraphScaleY, 1.0);

// range selection
srlp:= (SelectRange.startpos - displaydiap.xfrom)*rx;
srrp:= (SelectRange.endpos - displaydiap.xfrom)*rx;
x1param:= 10.0*rw;
with SelectRange do if (startpos > endpos) then begin
                                                srlbp:= srlp + x1param;
                                                srrbp:= srrp - x1param
                                                end
                                           else begin
                                                srlbp:= srlp - x1param;
                                                srrbp:= srrp + x1param
                                                end { IF };
//glColor3ub(GetRValue(SelectRange.RGB), GetGValue(SelectRange.RGB), GetBValue(SelectRange.RGB));
glColor3ubv(@SelectRange.RGB);
glRectf(srlp, 0.0, srrp, 1.0);

// Далее всё масштабируется и смещается частично здесь, так как при предельных увеличениях проявляются ограничения формата представления с одинарной точностью чисел с плавающей запятой (дискретность), внутренне используемом в OpenGL (для масштабирования включительно)
// greed
glLineStipple(1, $F0F0); // Сетка - серой штриховой линией
glEnable(GL_LINE_STIPPLE);
//glColor3ub(GetRValue(GREEDCOLOR), GetGValue(GREEDCOLOR), GetBValue(GREEDCOLOR));
glColor3ubv(@GREEDCOLOR);
// Горизонтальная 
glBegin(GL_LINES);
for index:= High(YAxisRecords) downto (0) do begin 
                                             glVertex2f(0.0, (YAxisRecords[index].val - displaydiap.yfrom)*ry);
                                             glVertex2f(1.0, (YAxisRecords[index].val - displaydiap.yfrom)*ry)
                                             end { FOR };
glEnd(); 
// Вертикальная
glBegin(GL_LINES);
for index:= High(XAxisRecords) downto (0) do begin
                                             glVertex2f((XAxisRecords[index].val - displaydiap.xfrom)*rx, 0.0);
                                             glVertex2f((XAxisRecords[index].val - displaydiap.xfrom)*rx, 1.0)
                                             end { FOR };
glEnd(); 
glDisable(GL_LINE_STIPPLE);   

// green to red arrows 
glColor3f(0.0, 0.64, 0.0);
glBegin(GL_TRIANGLES);
glVertex2f(srlbp, 1.0 - 5.0*rh);
glVertex2f(srlp, 1.0 - 10.0*rh);
glVertex2f(srlbp, 1.0 - 15.0*rh);
glVertex2f(srlbp, 5.0*rh);
glVertex2f(srlp, 10.0*rh);
glVertex2f(srlbp, 15.0*rh);
glColor3f(1.0, 0.0, 0.0);
glVertex2f(srrbp, 1.0 - 5.0*rh);
glVertex2f(srrp, 1.0 - 10.0*rh);
glVertex2f(srrbp, 1.0 - 15.0*rh);
glVertex2f(srrbp, 5.0*rh);
glVertex2f(srrp, 10.0*rh);
glVertex2f(srrbp, 15.0*rh);
glEnd();

// graph
//EnterCriticalSection(cs); 
for index0:= 0 to (High(sl)) do with sl[index0] do if (IsValidGraphData(Graph) and (Visible)) then begin
                                                                                                   //glColor3ub(GetRValue(RGB), GetGValue(RGB), GetBValue(RGB));
                                                                                                   glColor3ubv(@RGB);
                                                                                                   glBegin(GL_LINE_STRIP);     
                                                                                                   for index:= High(Graph.x) downto (0) do glVertex2f((Graph.x[index] - displaydiap.xfrom)*rx, (Graph.y[index] - displaydiap.yfrom)*ry) { FOR };
                                                                                                   glEnd()
                                                                                                   end { IF } { WITH } { FOR };
//LeaveCriticalSection(cs);
glPopMatrix(); 

glPushMatrix(); // Преобразование квадрата [0, 1]*[0, 1] --> [-1, 1]*[-1, 1] (на ТКП научили - конформные отображения и всё такое =) )
glTranslatef(-1.0, -1.0, 0.0);
glScalef(2.0, 2.0, 1.0);

// records background
//glColor3ub(GetRValue(BKCOLOR), GetGValue(BKCOLOR), GetBValue(BKCOLOR));
glColor3ubv(@BKCOLOR);
glRectf(0.0, 0.0, GraphOffsetX, 1.0);
glRectf(GraphOffsetX, 0.0, 1.0, GraphOffsetY);

// edge graph
if (Length(YAxisRecords) > 1) then begin
                                   glColor3f(0.5, 0.5, 0.5);
                                   glBegin(GL_LINE_STRIP);
                                   glVertex2f(1.0, GraphOffsetY);
                                   glVertex2f(GraphOffsetX, GraphOffsetY);
                                   glVertex2f(GraphOffsetX, 1.0);
                                   glEnd()
                                   end { IF };

// frame
if (SelectFrameVisible) then begin
                             y1param:= 1.0 - LButtonDownPos.Y*rh;
                             y2param:= 1.0 - CurrentMousePos.Y*rh;
                             x1param:= LButtonDownPos.X*rw;
                             x2param:= CurrentMousePos.X*rw;
                             //glColor3ub(GetRValue(FRAMECOLOR), GetGValue(FRAMECOLOR), GetBValue(FRAMECOLOR));
                             glColor3ubv(@FRAMECOLOR);
                             glBegin(GL_LINE_LOOP);
                             glVertex2f(x1param, y1param);
                             glVertex2f(x1param, y2param);
                             glVertex2f(x2param, y2param);
                             glVertex2f(x2param, y1param);
                             glEnd()
                             end { IF };
glPopMatrix();

// Масштабируется и смещается частично здесь, так как при предельных увеличениях проявляются ограничения формата представления с одинарной точностью чисел с плавающей запятой (некоторая дискретность),
// внутренне используемом в OpenGL (для масштабирования включительно), но тут всё в Real формате (имеется ввиду выражения (YAxisRecords[index].val - displaydiap.yfrom)*ry и (XAxisRecords[index].val - displaydiap.xfrom)*rx)

// axises records
// y
glPushMatrix();
glTranslatef(0.0, GraphOffsetY - GraphScaleY, 0.0);
glScalef(1.0, GraphScaleY + GraphScaleY, 1.0);
for index:= (High(YAxisRecords) - 1) downto (0) do DrawOrientedText(YAxisRecords[index].str, -1.0, (YAxisRecords[index].val - displaydiap.yfrom)*ry, LEFTC) { FOR }; // Последние циферки не влезают - поэтому на 1 меньше подписей, чем линий сетки
glPopMatrix();
// x
glPushMatrix();
glTranslatef(GraphOffsetX - GraphScaleX, 0.0, 0.0);
glScalef(GraphScaleX + GraphScaleX, 1.0, 1.0);    
for index:= (High(XAxisRecords) - 1) downto (0) do DrawOrientedText(XAxisRecords[index].str, (XAxisRecords[index].val - displaydiap.xfrom)*rx, -1.0, BOTTOMC) { FOR };
glPopMatrix()

end { OnPaintProc };

procedure OnChangeColors();
begin
BKCOLOR:= GetSysColor(COLOR_BTNFACE); 
GREEDCOLOR:= GetSysColor(COLOR_BTNSHADOW) + RGB(23, 23, 23);
TEXTCOLOR:= GetSysColor(COLOR_WINDOWTEXT);
SelectRange.RGB:= BKCOLOR + RGB(10, 10, 10) // Чуть посветлее

end { OnChangeColors };

var StaticWindowProcOld : TFarProc;

function StaticWindowProc(hwndStatic : HWND; msg : UINT; wParam : WPARAM; lParam : LPARAM) : LRESULT; stdcall;
begin
Result:= 0;
                                                                                                                
case msg of WM_CREATE : begin
                        OnChangeColors();                               
                        GetClientRect(hwndStatic, StaticClientRect);   // 746 462  // 750 20
                                 
                        DC:= GetDC(hwndStatic);
                        SetDCPixelFormat(DC);
                        RC:= wglCreateContext(DC);

                        wglMakeCurrent(DC, RC);
                        BuildFont(DC);
                        glLineWidth(1.0);
                        wglMakeCurrent(0, 0);

                        SetTimer(hwndStatic, SELECTFRAME_TIMER, SELECTFRAME_TIMER_INTERVAL, @TimerProc) 
                        end { WM_CREATE };
            WM_DESTROY : begin
                         KillTimer(hwndStatic, SELECTFRAME_TIMER);
                         glDeleteLists(GLF_STRING_LIST, 96);
                         //wglMakeCurrent(0, 0);
                         wglDeleteContext(RC);
                         ReleaseDC(hwndStatic, DC);
                         DeleteDC(DC)
                         end { WM_DESTROY };
            WM_SYSCOLORCHANGE : OnChangeColors() { WM_SYSCOLORCHANGE };                         
            WM_MOUSEWHEEL : MWheelFunc(wParam) { WM_MOUSEWHEEL };
            WM_RBUTTONDOWN : RButtonDownFunc(lParam, lParam shr 16) { WM_RBUTTONDOWN };
            WM_LBUTTONDOWN : LButtonDownFunc(lParam, lParam shr 16) { WM_LBUTTONDOWN };
            WM_LBUTTONUP : LButtonUpFunc(lParam, lParam shr 16) { WM_LBUTTONUP };
            WM_LBUTTONDBLCLK : LeftButtonDoubleClickHandler() { WM_LBUTTONDBLCLK }; // !проверку (LeftButtonDoubleClickHandler = nil)
            WM_RBUTTONUP : RButtonUpFunc(lParam, lParam shr 16) { WM_RBUTTONUP };
            WM_MOUSEMOVE : MouseMoveFunc(lParam, lParam shr 16, wParam) { WM_MOUSEMOVE };
            WM_ERASEBKGND : {Exit} { WM_ERASEBKGND }; // на ресайзе 
            WM_SIZE : OnResizeProc() { WM_SIZE }
         else begin
              case msg of WM_PAINT : begin
                                     wglMakeCurrent(DC, RC);
                                     glViewPort(0, 0, StaticWidth, StaticHeight);
                                     glClearColor(GetRValue(BKCOLOR)*0.00392, GetGValue(BKCOLOR)*0.00392, GetBValue(BKCOLOR)*0.00392, 1.0); // 0.00392 = round down of 1.0/255.0 = 0.00(3921568627450980) 
                                     glClear(GL_COLOR_BUFFER_BIT); 
                                     OnPaintProc();
                                     SwapBuffers(DC);
                                     glFlush();
                                     wglMakeCurrent(0, 0)
                                     end { WM_PAINT }
              end { CASE };
              Result:= CallWindowProc(StaticWindowProcOld, hwndStatic, msg, wParam, lParam)
              end { ELSE }
end { CASE }

end { StaticWindowProc };
                     
procedure SubClassGraphStatic(hwndStatic : HWND);
begin
bfgraph.hwndStatic:= hwndStatic;
SetWindowLong(hwndStatic, GWL_STYLE, GetWindowLong(hwndStatic, GWL_STYLE) or SS_NOTIFY or SS_OWNERDRAW);
DWORD(StaticWindowProcOld):= SetWindowLong(hwndStatic, GWL_WNDPROC, DWORD(@StaticWindowProc));
SendDlgItemMessage(GetParent(hwndStatic), GetDlgCtrlID(hwndStatic), WM_CREATE, 0, 0)

end { SubClassGraphStatic };

procedure ResizeGraphStatic(X, Y, nWidth, nHeight : Integer);
begin         
if not ((nWidth <= 0) or (nHeight <= 0)) then MoveWindow(hwndStatic, X, Y, nWidth, nHeight, TRUE) { IF }

end { ResizeGraphStatic };

(*function GetMaxItem() : Integer;
begin
Result:= High(sl)

end { GetMaxItem };*)

function AddGraphData(const Graph : TGRAPH; RGB : COLORREF; Visible : BOOL) : Integer;

var index : Integer; 

begin
Result:= -1;
if not (IsValidGraphData(Graph)) then Exit { IF };
//EnterCriticalSection(cs); 
for index:= High(sl) downto (0) do if not (IsValidGraphData(sl[index].Graph)) then begin
                                                                                   Result:= index;
                                                                                   Break 
                                                                                   end { IF } { FOR };
                                                                                   
if (Result < 0) then begin
                     Result:= Length(sl);
                     SetLength(sl, Result + 1); // now Result == High(sl)
                     end { IF };
                             
//sl[Result].Graph.x:= Graph.x;
//sl[Result].Graph.y:= Graph.y;

index:= Length(Graph.x);
SetLength(sl[Result].Graph.x, index);
SetLength(sl[Result].Graph.y, index);
index:= index shl 3;
CopyMemory(sl[Result].Graph.x, Graph.x, index);
CopyMemory(sl[Result].Graph.y, Graph.y, index); 
 
sl[Result].RGB:= RGB;
sl[Result].Visible:= Visible
//LeaveCriticalSection(cs)

end { AddGraphData };

procedure UpdateGraphData(const Graph : TGRAPH; n : Integer);

var L : Integer;

begin
if not (IsValidGraphData(Graph) and ((n >= 0) and (n <= High(sl)))) then Exit { IF };
//EnterCriticalSection(cs);
L:= Length(Graph.x);
with sl[n].Graph do begin
                    if (Length(x) <> L) then begin
                                             SetLength(x, L);
                                             SetLength(y, L)
                                             end { IF };
                    //x:= nil;
                    //y:= nil;
                    //SetLength(x, L);
                    //SetLength(y, L);
                    L:= L shl 3;
                    CopyMemory(x, Graph.x, L);
                    CopyMemory(y, Graph.y, L)
                    end { sl[n].Graph }
//LeaveCriticalSection(cs)                         

end { UpdateGraphData };

procedure DeleteItem(var n : Integer);

var index : Integer;

begin 
index:= n;
n:= -1;
//EnterCriticalSection(cs);
if ((index <= High(sl)) and (index >= 0)) then begin
                                               sl[index].Graph.x:= nil;
                                               sl[index].Graph.y:= nil
                                               end { IF };

for index:= High(sl) downto (0) do if (IsValidGraphData(sl[index].Graph)) then Break
                                                                          else SetLength(sl, index) { IF } { FOR };    
//LeaveCriticalSection(cs)

end { DeleteItem };

procedure ClearSpectra(); 
begin
//EnterCriticalSection(cs);
SetLength(sl, 0);
//LeaveCriticalSection(cs);

OptimizeZoom();
OnChangeGraphStaticState()

end { ClearSpectra };

procedure ShowItem(n : Integer; Visible : BOOL);
begin
//EnterCriticalSection(cs);
if ((n <= High(sl)) and (n >= 0)) then begin
                                       sl[n].Visible:= Visible;
                                       InvalidateRect(hwndStatic, nil, FALSE)
                                       end { IF };
//LeaveCriticalSection(cs)

end { ShowItem };    

procedure SetItemColor(n : Integer; Color : COLORREF);
begin
//EnterCriticalSection(cs);
if ((n <= High(sl)) and (n >= 0)) then begin
                                       sl[n].RGB:= Color;
                                       InvalidateRect(hwndStatic, nil, FALSE)
                                       end { IF };
//LeaveCriticalSection(cs)

end { SetItemColor };  

procedure OptimizeZoom();

var index, index0 : Integer;

begin
//EnterCriticalSection(cs);
for index:= High(sl) downto (0) do with sl[index] do if (IsValidGraphData(Graph) and Visible) then with datadiap do with Graph do begin   
                                                                                                                                  xfrom:= x[0]; // НУ - 1й график
                                                                                                                                  yfrom:= y[0];
                                                                                                                                  xto:= x[0];
                                                                                                                                  yto:= y[0];
                                                                                                                                  Break
                                                                                                                                  end { WITH } { WITH } { IF } { FOR };
                                                           
for index:= High(sl) downto (0) do with sl[index] do if (IsValidGraphData(Graph) and Visible) then with datadiap do with Graph do for index0:= High(x) downto (0) do begin                                                       
                                                                                                                                                                     if (xfrom > x[index0]) then xfrom:= x[index0] { IF };
                                                                                                                                                                     if (yfrom > y[index0]) then yfrom:= y[index0] { IF };
                                                                                                                                                                     if (xto < x[index0]) then xto:= x[index0] { IF };
                                                                                                                                                                     if (yto < y[index0]) then yto:= y[index0] { IF }
                                                                                                                                                                     end { FOR } { WITH } { WITH } { IF } { FOR };
                                                                                                                                                                            

                                                           
                                                           
with datadiap do begin
                 if (Length(sl) = 0) then begin
                                          xfrom:= 0.0;
                                          yfrom:= 0.0;
                                          xto:= 0.0;
                                          yto:= 0.0
                                          end { IF };
                 deltax:= xto - xfrom;
                 deltay:= yto - yfrom
                 end { WITH };

//LeaveCriticalSection(cs);                         

with displaydiap do begin
                    xfrom:= datadiap.xfrom - datadiap.deltax*zoomgraph;
                    yfrom:= datadiap.yfrom - datadiap.deltay*zoomgraph;
                    xto:= datadiap.xto + datadiap.deltax*zoomgraph;
                    yto:= datadiap.yto + datadiap.deltay*zoomgraph;
                    deltax:= xto - xfrom;
                    deltay:= yto - yfrom       
                    end { WITH }

end { OptimizeZoom };

procedure SetZoom(const xfrom, yfrom, xto, yto : Real);
begin
displaydiap.xfrom:= xfrom - (xto - xfrom)*zoomgraph;
displaydiap.yfrom:= yfrom - (yto - yfrom)*zoomgraph;
displaydiap.xto:= xto + (xto - xfrom)*zoomgraph;
displaydiap.yto:= yto + (yto - yfrom)*zoomgraph;     
displaydiap.deltax:= displaydiap.xto - displaydiap.xfrom;
displaydiap.deltay:= displaydiap.yto - displaydiap.yfrom

end { SetZoom };

(*procedure GetXYDisplayRange(out xfrom, yfrom, xto, yto : Real);
begin
xfrom:= displaydiap.xfrom;
yfrom:= displaydiap.yfrom;
xto:= displaydiap.xto;
yto:= displaydiap.yto

end { GetXYDisplayRange };     *)

(*function AddSingleLine(const xfrom, yfrom, xto, yto : Real; RGB : COLORREF) : Integer;

var Line : TGRAPH;

begin
SetLength(Line.x, 2);
SetLength(Line.y, 2);
Line.x[0]:= xfrom;
Line.x[1]:= xto;
Line.y[0]:= yfrom;
Line.y[1]:= yto;   
Result:= AddGraphData(Line, RGB, TRUE);
Line.x:= nil;
Line.y:= nil

end { AddSingleLine };

procedure UpdateGraphLine(const xfrom, yfrom, xto, yto : Real; n : Integer); 
begin        
SetLength(sl[n].Graph.x, 2);
SetLength(sl[n].Graph.y, 2);

sl[n].Graph.x[0]:= xfrom;
sl[n].Graph.y[0]:= yfrom;

sl[n].Graph.x[1]:= xto;
sl[n].Graph.y[1]:= yto

end { UpdateGraphLine }; *)
 
INITIALIZATION

//InitializeCriticalSection(cs)

FINALIZATION

//DeleteCriticalSection(cs)
               
END { BFGRAPH }.
