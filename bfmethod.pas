{ © 2007-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfmethod;
// Матметоды темы приложения.
// Вес - число обратное текущему значению искомой функции.
// Тут тоже немного АТД

INTERFACE

uses bfatd, 
     Windows,   
     Messages; 

const WM_THREADMSG = WM_USER + $1000; 

type TVECTOR = array of Real;

var FullSpectra : TSPECTRA; // Исходный спектр
    fs : record
         iItem : Integer
         end { fs } = (iItem : -1);

var SourceSpectra : TSPECTRA; // Обрабатываемый спектр
    ss : record
         iItem : Integer;
         Color : COLORREF
         end { ss } = (iItem : -1);

type PTASKDEFINITION = ^TTASKDEFINITION;
     TTASKDEFINITION = record
                       data,
                       Spectra : TSPECTRA;
                       FuncStruct, weights : _FUNC;
                       wi : Integer;  
                       Color : COLORREF; 
                       iItem : Integer; 
                       q : TQUALIFY 
                       end { TTASKDEFINITION };

var a1peak : record   
             td : TTASKDEFINITION;
             index : record // Индексы - для экономии кода
                     noise,
                     amplitude,
                     resolution,
                     mass : Integer
                     end { index }
             end { OnePeakApproximation } = (td : (iItem : -1));

var a2peak : record
             td : TTASKDEFINITION; 
             sItem : Integer;
             sVisible : BOOL;
             noisel,
             noiser : Real;
             index : record
                     noise,
                     amplitudel,
                     amplituder,
                     resolutionl,
                     resolutionr,
                     massl,
                     massr : Integer
                     end { index } 
             end { TwoPeakApproximation } = (td : (iItem : -1); sItem : -1; sVisible : FALSE);

function IsValidSpectra(Spectra : TSPECTRA) : BOOL; // Не пустой ли спектр?
function DoFirstApproximation(ThreadParam : PHandle) : DWORD; stdcall; // Считает первое приближение для одиночного пика
function DoOnePeakApproximation(ThreadParam : PHandle) : DWORD; stdcall; // Считает приближение для одиночного пика в соответствии с критерием наименьших квадратов   
function OnePeakFirstApproachErrorCode(out errcode, varindex : Integer) : Integer; // Тестирует все параметры на корректность и выдаёт код ошибки для одиночного пика 
function TwoPeakFirstApproachErrorCode(out errcode, varindex : Integer) : Integer; // Тестирует все параметры на корректность и выдаёт код ошибки для пары пиков  
function DoTwoPeakApproximation(ThreadParam : PHandle) : DWORD; stdcall; // Считает приближение для пары пиков в соответствии с критерием наименьших квадратов 
function Prepare(ThreadParam : PHandle) : DWORD; stdcall; // На старте компилируются функции, считаются их производные и тоже компилируются
procedure CreateChart(var td : TTASKDEFINITION; ni : Integer = 0); // Считаются значения функции номер ni из указанной структуры и с ними обновляется её график 
procedure ReduceChart(var td : TTASKDEFINITION); // Копируются значения из hjd.Result в массив из структуры и с соответственными значениями по оси абсцисс обновляется её график 
//function CreateNormedDiscrepancyChafrt(GeneratedX : TSPECTRAAXIES; NORMA : Real; out NewDiscrepancyChart : TSPECTRA) : Real;
function GetSelectedField() : Integer; // Копирует выделенную область в отдельный график 
//procedure GetMassRange();
procedure FocusOnSourceSpectra(); // Масштабирует и центрует графика таким образом, что видна полностью выделенная часть графика
function UpdateIt() : BOOL; // "Это" - это все отображённые графики функций
function IsNotPositivelyDefined(Axis : TSPECTRAAXIES) : BOOL; // Является ли множество Axis неположительно определённым  
function IsNegativelyDefined(Axis : TSPECTRAAXIES) : BOOL; // Является ли множество Axis отрицательно определённым                                                              
function SubtractBaseLine(var Axis : TSPECTRAAXIES) : Real; // Возвращает массив в таком виде, что из всех его элементов вычтено самый большой по модулю отрицательный элемент
//function IsIncrementalledSequence(Axis : TSPECTRAAXIES) : BOOL;
//function IsDecrementalledSequence(Axis : TSPECTRAAXIES) : BOOL;
function IsSequential(Axis : TSPECTRAAXIES) : BOOL; // Монотонная ли последовательность
procedure DeleteAllGraph(); // Очищает спектр от графиков функций
procedure CalcStdErr(var td : TTASKDEFINITION); // Считает наиболее вероятное значение средней квадратичной ошибки
procedure QualifyToOnePeak(); // Определяет все параметры метода для всех параметров-констант для одиночного пика
procedure QualifyToTwoPeak(); // Определяет все параметры метода для всех параметров-констант для пары пиков
procedure SetTaskData(var td : TTASKDEFINITION; const Source : TSPECTRA); // Задаёт указаной структуре соответствующие ей отсчёты 

IMPLEMENTATION

uses bftablefile,
     bfhjtechnique,
     bfderivator,
     bfgraph,
     bfcompiler,
     bfspecialfunc,
     bfsysutils;

const REDUCEDINF : record // Необходима, чтобы явно записать максимальные по модулю Real-Double такие, что: Exp(Real(REDUCEDINF.R+-)) ещё не not a number (а NaN бывает тогда, когда аргумент Exp() равен +- Inf)
                   case BOOL of TRUE : (RPOS, RNEG : Real) { TRUE }; // REDUCEDINF.RPOS: Exp(REDUCEDINF.RPOS) = +Inf
                                FALSE : (IPOS, INEG : LONGLONG) { FALSE } // REDUCEDINF.RNEG: Exp(REDUCEDINF.RNEG) = +0.0
                   end = (IPOS : $7FEFFFFFFFFFFFFF; INEG : $FFEFFFFFFFFFFFFF) { REDUCEDINF };     

    // Константы теории (вычисляются в INITIALIZATION)
var SQRTPI,
    RESOLUTIONFACTOR : Extended; // Константа '1.6651' в теории

var ALPHA : Real = 0.05;    

var cb : TCOMPILERBASE;    

function IsValidSpectra(Spectra : TSPECTRA) : BOOL;

var L : Integer;

begin          
L:= Length(Spectra.x);
Result:= (L > 1) and (L = Length(Spectra.y))

end { IsValidGraphData };

function IsSequential(Axis : TSPECTRAAXIES) : BOOL; // Монотонная ли последовательность

var index : Integer;
    Order : BOOL;

begin
Result:= TRUE;
Order:= (Axis[1] > Axis[0]);
for index:= High(Axis) downto (1) do Result:= Result and (Order = (Axis[index] > Axis[index - 1])) { FOR }

end { IsSequential };

(*function IsIncrementalledSequence(Axis : TSPECTRAAXIES) : BOOL;

var index : Integer;

begin
Result:= TRUE;
for index:= High(Axis) downto (1) do Result:= Result and (Axis[index] > Axis[index - 1]) { FOR }

end { IsIncrementalledSequence };

function IsDecrementalledSequence(Axis : TSPECTRAAXIES) : BOOL;

var index : Integer;

begin
Result:= TRUE;
for index:= High(Axis) downto (1) do Result:= Result and (Axis[index] < Axis[index - 1]) { FOR }

end { IsDecrementalledSequence };  *)

function IsNegativelyDefined(Axis : TSPECTRAAXIES) : BOOL; // Отрицательно ли определённая последовательность

var index : Integer;

begin
Result:= FALSE;
for index:= High(Axis) downto (0) do Result:= Result or (Axis[index] < 0) { FOR } 

end { IsNegativelyDefined };

function IsNotPositivelyDefined(Axis : TSPECTRAAXIES) : BOOL; // Неположительно ли определённая последовательность

var index : Integer;

begin
Result:= FALSE;
for index:= High(Axis) downto (0) do Result:= Result or (Axis[index] <= 0) { FOR } 

end { IsNotPositivelyDefined };
 
function SpectraSquare(Spectra : TSPECTRA) : Real; stdcall; // Length(Spectra.x) must be > 1 // по формуле трапеций считаем площадь под спектром

var index : Integer;

begin
with Spectra do begin
                index:= High(x);
                Result:= y[index]*(x[index] - x[index - 1]);
                for index:= (High(x) - 1) downto (1) do Result:= Result + y[index]*(x[index + 1] - x[index - 1]) { FOR };
                Result:= Result + y[0]*(x[1] - x[0]);
                Result:= Result*0.5
                end { Spectra }

end { SpectraSquare };

function SpectraPartLine(Spectra : TSPECTRA; Part : Real) : Real; stdcall; // Считая площади по формуле трапеций ищем вертикальную секущую, слева от которой находится часть Part всей площади под графиком

var Square,
    FlowedSquare : Real; // =*2
    index,
    index0 : Integer;

begin 
Square:= 2.0*(1.0 - Part)*SpectraSquare(Spectra);
with Spectra do begin
                index:= High(x);
                index0:= index;
                Result:= y[index]*(x[index] - x[index - 1]);
                //FlowedSquare:= Result; // Variable 'Square' might not have been initialized
                for index:= (High(x) - 1) downto (1) do begin 
                                                        FlowedSquare:= y[index]*(x[index + 1] - x[index - 1]);
                                                        if (Result + FlowedSquare > Square) then Break
                                                                                            else begin
                                                                                                 Result:= Result + FlowedSquare;
                                                                                                 index0:= index
                                                                                                 end { IF }
                                                        end { FOR };
                Result:= x[index0] + (x[index0] - x[index0 - 1])*(Result - Square)/FlowedSquare // - линейная интерполяция для увеличения точности
                end { Spectra }

end { SpectraPartLine };

function SpectraPartHighIndex(Spectra : TSPECTRA; Part : Real) : Integer; stdcall; 

var DoubleSquare,
    CurrentIntegral,
    FlowedSquare : Real; // *2
    index : Integer;

begin  
DoubleSquare:= 2.0*(1.0 - Part)*SpectraSquare(Spectra);
with Spectra do begin
                index:= High(x);
                Result:= index;
                CurrentIntegral:= y[index]*(x[index] - x[index - 1]);
                //FlowedSquare:= CurrentIntegral; // Variable 'Square' might not have been initialized
                for index:= (High(x) - 1) downto (1) do begin 
                                                        FlowedSquare:= y[index]*(x[index + 1] - x[index - 1]);
                                                        if (CurrentIntegral + FlowedSquare > DoubleSquare) then Break
                                                                                                           else begin
                                                                                                                 CurrentIntegral:= CurrentIntegral + FlowedSquare;
                                                                                                                 Result:= index
                                                                                                                 end { IF }
                                                        end { FOR }
                end { Spectra }

end { SpectraPartHighIndex };

function SpectraPartLowIndex(Spectra : TSPECTRA; Part : Real) : Integer; stdcall; 

var DoubleSquare,
    CurrentIntegral,
    FlowedSquare : Real; // *2
    index : Integer;

begin  
DoubleSquare:= 2.0*(1.0 - Part)*SpectraSquare(Spectra);
with Spectra do begin
                Result:= 0;
                CurrentIntegral:= y[0]*(x[1] - x[0]);
                FlowedSquare:= CurrentIntegral;
                for index:= 1 to (High(x) - 1) do begin
                                                  FlowedSquare:= y[index]*(x[index + 1] - x[index - 1]);
                                                  if (CurrentIntegral + FlowedSquare > DoubleSquare) then Break
                                                                                                     else begin
                                                                                                          CurrentIntegral:= CurrentIntegral + FlowedSquare;
                                                                                                          Result:= index
                                                                                                          end { IF }
                                                  end { FOR } 
                end { Spectra } 

end { SpectraPartLowIndex };

function GetSpectraAmplitude(GeneratedY : TSPECTRAAXIES) : Real; // Возвращает амплитуду спектра - максимальное значение на графике

var index : Integer;

begin
Result:= GeneratedY[0];
for index:= High(GeneratedY) downto (1) do if (Result < GeneratedY[index]) then Result:= GeneratedY[index] { IF } { FOR };

end { GetSpectraAmplitude };

function GetSpectraGround(GeneratedY : TSPECTRAAXIES) : Real; 

var index : Integer;

begin
Result:= GeneratedY[0];
for index:= High(GeneratedY) downto (1) do if (Result > GeneratedY[index]) then Result:= GeneratedY[index] { IF } { FOR };

end { GetSpectraGround };

function SubtractBaseLine(var Axis : TSPECTRAAXIES) : Real; // Вычитает базовую линию

var index : Integer;

begin
Result:= GetSpectraGround(Axis); 
for index:= High(Axis) downto (0) do Axis[index]:= Axis[index] - Result { FOR }

end { SubtractBaseLine }; 

procedure FocusOnSourceSpectra();
begin
if (IsValidSpectra(SourceSpectra)) then begin
                                        SetZoom(SourceSpectra.x[0], GetSpectraGround(SourceSpectra.y), SourceSpectra.x[High(SourceSpectra.x)], GetSpectraAmplitude(SourceSpectra.y));
                                        SetSelectRange(SourceSpectra.x[0], SourceSpectra.x[High(SourceSpectra.x)])
                                        end
                                   else ResetSelectRange(-1E10) { IF }

end { FocusOnSourceSpectra };

function GetSpectraNoise(Intensity : TSPECTRAAXIES) : Real; // Берёт Part часть наименьших значений интенсивностей и считает их среднее арифметическое

var Ordered : TSPECTRAAXIES;
    index, L : Integer;

begin
L:= Length(Intensity);
SetLength(Ordered, L);
CopyMemory(Ordered, Intensity, L shl 3);
QUICKSORT(Ordered, 0, L - 1);
L:= Trunc(L*ALPHA);
if (L = 0) then L:= 1 { IF };
Result:= 0.0;
for index:= (L - 1) downto (0) do Result:= Result + Ordered[index] { FOR };  
Result:= Result/L

end { GetSpectraNoise }; 

// даёт высокоточное начальное приближеие разрешённости для графика 1 пика Гаусса 
function GetResolutionApproximation(Spectra : TSPECTRA; RESOLUTIONSTEP : Real) : Real; stdcall;

var median,
    step,
    difference,
    A,
    B : Real;
    
begin
median:= SpectraPartLine(Spectra, 0.5); // слева 1/2 часть площади всего графика - эффективная оценка положения центра пика
difference:= Spectra.x[High(Spectra.x)] - Spectra.x[0];
A:= difference/(median + median);
B:= (SpectraSquare(Spectra) - GetSpectraNoise(Spectra.y)*difference)/(SQRTPI*median*GetSpectraAmplitude(Spectra.y));

step:= RESOLUTIONSTEP*RESOLUTIONFACTOR;

Result:= step;
while (Erf(A*Result) > B*Result) do Result:= Result + step { WHILE };  // Erf(A*Result) ~= B*Result - решаем это уравнение с точностью +-RESOLUTIONSTEP пользуясь свойством монотонности функции Erf, как интеграла от положительно определённой функции
Result:= Result/RESOLUTIONFACTOR

end { GetResolutionApproximation };

(*function CreateNormedDiscrepancyChart(GeneratedX : TSPECTRAAXIES; NORMA : Real; out NewDiscrepancyChart : TSPECTRA) : Real;

var index : Integer;  

begin
index:= Length(GeneratedX);
SetLength(NewDiscrepancyChart.x, index);
SetLength(NewDiscrepancyChart.y, index);

Result:= 0.0;
for index:= High(GeneratedX) downto (0) do if (Result < Abs(PReal(hjd.Discrepancy + (index shl 3))^)) then Result:= Abs(PReal(hjd.Discrepancy + (index shl 3))^) { IF } { FOR };
Result:= NORMA/Result;
 
for index:= High(GeneratedX) downto (0) do with NewDiscrepancyChart do begin 
                                                                       x[index]:= GeneratedX[index];
                                                                       y[index]:= Abs(PReal(hjd.Discrepancy + (index shl 3))^*Result)
                                                                       end { FOR }

end { CreateNormedDiscrepancyChart };  *)

procedure ReduceChart(var td : TTASKDEFINITION);

var L : Integer;

begin
L:= Length(td.data.x);
SetLength(td.Spectra.x, L);
SetLength(td.Spectra.y, L);

L:= L shl 3;

EnterCriticalSection(hjd.cs);
CopyMemory(td.Spectra.x, td.data.x, L);
CopyMemory(td.Spectra.y, Pointer(hjd.Result), L);
LeaveCriticalSection(hjd.cs)

end { ReduceChart };

procedure SetTaskData(var td : TTASKDEFINITION; const Source : TSPECTRA);

var L : Integer; 

begin
L:= Length(Source.x);
SetLength(td.data.x, L);
SetLength(td.data.y, L);

L:= L shl 3;

CopyMemory(td.data.x, Source.x, L);
CopyMemory(td.data.y, Source.y, L) 

end { SetTaskData };

// на множестве абцисс GeneratedX строит график NewChart по функции FuncStruct.EntryPoint после её конкретизации (вызова BuildAndPrepare)
procedure CreateChart(var td : TTASKDEFINITION; ni : Integer = 0);

var index : Integer;

var point : packed record
                   y,
                   x,
                   yc : Real
                   end { point };    

begin
index:= Length(td.data.x);
SetLength(td.Spectra.x, index);
SetLength(td.Spectra.y, index);

with td.FuncStruct.Functions[ni] do for index:= High(td.data.x) downto (0) do begin
                                                                              point.x:= td.data.x[index];
                                                                              //point.yc:= EntryPoint(HGLOBAL(@point));
                                                                              //PReal(fb.ESV + 8)^:= GeneratedX[index];
                                                                              td.Spectra.x[index]:= point.x;
                                                                              td.Spectra.y[index]:= EntryPoint(HGLOBAL(@point))
                                                                              end { FOR }

end { CreateChart };

function UpdateIt() : BOOL;
begin
Result:= FALSE;
 
with a1peak do if (td.iItem >= 0) then begin
                                       ReduceChart(td);
                                       UpdateGraphData(TGRAPH(td.Spectra), td.iItem);

                                       Result:= TRUE 
                                       end { IF } { a1peak };  

with a2peak do if (td.iItem >= 0) then begin
                                       ReduceChart(td);
                                       UpdateGraphData(TGRAPH(td.Spectra), td.iItem);

                                       Result:= TRUE
                                       end { IF } { a2peak }

end { UpdateIt };

procedure DeleteAllGraph();
begin 
DeleteItem(a1peak.td.iItem);
DeleteItem(a2peak.td.iItem);
DeleteItem(a2peak.sItem)

end { DeleteAllGraph };

function GetSelectedField() : Integer;

const ONESTEPFILLSIZE = $400;

var xfrom, xto : Real;
    index, SL : Integer;

begin           
GetSelectRange(xfrom, xto);
RankFloat(xfrom, xto);
SelectNotDrag:= FALSE;

Result:= 0;
SL:= 0;                      
for index:= 0 to (High(FullSpectra.x)) do if ((FullSpectra.x[index] >= xfrom) and (FullSpectra.x[index] <= xto)) then begin //  and (FullSpectra.y[index] > yfrom) and (FullSpectra.y[index] < yto)
                                                                                                                      if ((Result mod ONESTEPFILLSIZE) = 0) then begin
                                                                                                                                                                 Inc(SL, ONESTEPFILLSIZE);
                                                                                                                                                                 SetLength(SourceSpectra.x, SL);
                                                                                                                                                                 SetLength(SourceSpectra.y, SL)
                                                                                                                                                                 end { IF };
                                                                                                                      SourceSpectra.x[Result]:= FullSpectra.x[index];
                                                                                                                      SourceSpectra.y[Result]:= FullSpectra.y[index];
                                                                                                                      Inc(Result)
                                                                                                                      end { IF } { FOR };                                                                                                                      

SetLength(SourceSpectra.x, Result);
SetLength(SourceSpectra.y, Result);

SetTaskDimAndPointsCount(3, Result); // 3 == (fs^.ENTIRETYSV + 1) 
SetVarVector(0, SourceSpectra.y);
SetVarVector(1, SourceSpectra.x);

DeleteAllGraph();

DeleteItem(ss.iItem);
ss.iItem:= AddGraphData(TGRAPH(SourceSpectra), ss.Color, TRUE)
 
end { GetSelectedField }; 

procedure CreateDerivatives(var fs : _FUNC); // Считает и компилирует все частные производные от fs.Functions[0].Expresion по параметрам-константам

var index : Integer;

begin
for index:= 0 to (fs.ENTIRETYSC) do SetExpresion(SIMPLER(DERIVATOR(fs.Functions[0].Expresion, fs.Constants[index])), fs) { FOR }

end { CreateDerivatives };

procedure CalcStdErr(var td : TTASKDEFINITION);

 function MulSum(a, b, w : Pointer; n : DWORD) : Real; stdcall;
 asm
         push ESI
         push EDI

         mov ECX, n
         mov ESI, a
         mov EDI, b
         mov EAX, w
         mov EDX, 8
         sub ESI, EDX
         sub EDI, EDX
         sub EAX, EDX

         FNINIT
         FLDZ

 @loop:  FLD qword ptr [ESI + 8*ECX]
         FMUL qword ptr [EDI + 8*ECX]
         FMUL qword ptr [EAX + 8*ECX] // weights taken into account
         FADD         
         loop @loop

         pop EDI
         pop ESI

 end { MulSum };

 function SumSqr(a, w : Pointer; n : DWORD) : Real; stdcall;
 asm
         mov ECX, n
         mov EAX, a
         mov EDX, w
         sub EAX, 8
         sub EDX, 8    

         FNINIT
         FLDZ

 @loop:  FLD qword ptr [EAX + 8*ECX]
         FMUL ST, ST(0)
         FMUL qword ptr [EDX + 8*ECX]
         FADD
         loop @loop

 end { SumSqr };

var derivint : array of TVECTOR; // dim = nco*pt
    normequsyscoeff : TMATRIX; // dim = nco*nco 
    //Discrepancy : TVECTOR; // dim = pt
    weight : TVECTOR; // dim = pt    
    index0, index1,
    pt : DWORD;
    coeff : Real;
    nco : DWORD;
    Func, w : function(DSV : HGLOBAL) : Real; stdcall;    
    point : packed record
                   y,
                   x,
                   yc : Real
                   end { point };

begin   
nco:= td.FuncStruct.ENTIRETYSC;
Inc(nco);

td.FuncStruct.DSC:= GlobalAlloc(GPTR, nco shl 3);
for index0:= 0 to (td.FuncStruct.ENTIRETYSC) do PReal(td.FuncStruct.DSC + DWORD(index0 shl 3))^:= td.q[index0].Value { FOR };

pt:= Length(td.data.x);
                         
SetLength(weight, pt);
//SetLength(Discrepancy, pt);
Func:= td.FuncStruct.Functions[0].EntryPoint;
w:= td.weights.Functions[td.wi].EntryPoint;
coeff:= 0.0;                
for index0:= (pt - 1) downto (0) do begin
                                    point.y:= td.data.y[index0];
                                    point.x:= td.data.x[index0];
                                    point.yc:= Func(HGLOBAL(@point));
                                    td.Spectra.y[index0]:= point.yc;
                                    weight[index0]:= w(HGLOBAL(@point));
                                    coeff:= coeff + Sqr(point.yc - point.y)*weight[index0] // Пока - сумма взвешенных квадратов невязок
                                    end { FOR };

SetLength(derivint, nco);
for index0:= 0 to (td.FuncStruct.ENTIRETYSC) do begin
                                                SetLength(derivint[index0], pt);
                                                Func:= td.FuncStruct.Functions[index0 + 1].EntryPoint;
                                                for index1:= (pt - 1) downto (0) do begin
                                                                                    point.x:= td.data.x[index1];
                                                                                    derivint[index0][index1]:= Func(HGLOBAL(@point))
                                                                                    end { FOR }
                                                end { IF }; 

SetLength(normequsyscoeff, nco);
for index0:= 0 to (td.FuncStruct.ENTIRETYSC) do begin
                                                SetLength(normequsyscoeff[index0], nco);
                                                normequsyscoeff[index0][index0]:= SumSqr(derivint[index0], weight, pt) // Диагональные
                                                end { IF };

for index0:= 1 to (td.FuncStruct.ENTIRETYSC) do for index1:= (index0 - 1) downto (0) do begin 
                                                                                        point.x:= MulSum(derivint[index0], derivint[index1], weight, pt);
                                                                                        normequsyscoeff[index0][index1]:= point.x; // Симметричные
                                                                                        normequsyscoeff[index1][index0]:= point.x
                                                                                        end { FOR } { FOR } { IF };

coeff:= coeff/(det(normequsyscoeff)*(pt - nco));  
for index0:= 0 to (td.FuncStruct.ENTIRETYSC) do td.q[index0].rmse:= Sqrt(coeff*det(minor(normequsyscoeff, index0, index0))) { FOR };

GlobalFree(td.FuncStruct.DSC)

end { CalcStdErr };
                                     
(*procedure GetMassRange();
begin
GetSelectRange(a2peak.leftpos, a2peak.rightpos);
ResetSelectRange(-1E10);
SelectRangeDragMode:= DragMode

end { GetMassRange };*) 

function IsCorrectlyDefinedParam(qi : TQUALIFYITEM; out errcode : Integer) : BOOL;
begin
errcode:= 0;
if (qi.Min >= qi.Value) then errcode:= 1 { IF };
if (qi.Max <= qi.Value) then errcode:= 2 { IF };
if (qi.Step*3.0 > (qi.Max - qi.Min)) then errcode:= 3 { IF };
if (qi.Precision >= qi.Step) then errcode:= 4 { IF };
Result:= (errcode = 0)

end { IsCorrectlyDefinedParam };

function OnePeakFirstApproachErrorCode(out errcode, varindex : Integer) : Integer;  

var spectraamplitude : Real;
    index : Integer;

begin
Result:= -1;

spectraamplitude:= GetSpectraAmplitude(a1peak.td.data.y);
with a1peak do with index do with td do begin
                                        if ((q[noise].Value > spectraamplitude) or (q[noise].Value < 0.0)) then Result:= noise { IF };
                                        if ((q[amplitude].Value > spectraamplitude + spectraamplitude) or (q[amplitude].Value < 0.0)) then Result:= amplitude { IF };
                                        if (q[resolution].Value < 0.5*(data.x[High(data.x)] + data.x[0])/(data.x[High(data.x)] - data.x[0])) then Result:= resolution { IF };
                                        if ((q[mass].Value < data.x[0]) or (q[mass].Value > data.x[High(data.x)])) then Result:= mass { IF }
                                        end { td } { index } { a1peak };

varindex:= -1;
for index:= 0 to (a1peak.td.FuncStruct.ENTIRETYSC) do if not (IsCorrectlyDefinedParam(a1peak.td.q[index], errcode)) then begin
                                                                                                                         Result:= -2;
                                                                                                                         varindex:= index;
                                                                                                                         Break
                                                                                                                         end { IF } { FOR }; 

end { OnePeakFirstApproachErrorCode };

procedure QualifyToOnePeak();
begin
if not (IsValidSpectra(SourceSpectra)) then Exit { IF };
SetTaskData(a1peak.td, SourceSpectra); 
with a1peak do with index do with td do begin
                                        q[noise].Value:= GetSpectraNoise(data.y);
                                        q[amplitude].Value:= GetSpectraAmplitude(data.y) - q[noise].Value;
                                        q[mass].Value:= SpectraPartLine(data, 0.5);

                                        with q[noise] do begin
                                                        Step:= q[amplitude].Value*0.01;
                                                        Min:= 0.0;
                                                        Max:= q[amplitude].Value;
                                                        Precision:= q[amplitude].Value*1E-6
                                                        end { q[noise] };

                                        with q[amplitude] do begin
                                                             Step:= q[amplitude].Value*0.01;
                                                             Min:= 0.0;
                                                             Max:= q[amplitude].Value*2.0;
                                                             Precision:= q[amplitude].Value*1E-6
                                                             end { q[amplitude] };

                                        with q[resolution] do begin
                                                              Step:= 3E-3*0.5*(data.x[High(data.x)] + data.x[0])/(data.x[High(data.x)] - data.x[0]);
                                                              Value:= GetResolutionApproximation(data, Step);
                                                              Min:= 0.0;
                                                              Max:= 5E4;
                                                              Precision:= 1E-1
                                                              end { q[resolution] };

                                        with q[mass] do begin
                                                        Step:= 0.0001;
                                                        Min:= data.x[0];
                                                        Max:= data.x[High(data.x)];
                                                        Precision:= 1E-6
                                                        end { q[mass] }
                                                        
                                        end { index } { a1peak }
                                                        
end { QualifyToOnePeak };

function DoFirstApproximation(ThreadParam : PHandle) : DWORD; stdcall;
begin
SelectNotDrag:= FALSE;
SetCurrentFunc(a1peak.td.FuncStruct, a1peak.td.weights, a1peak.td.wi);

with a1peak do with index do with td do begin 
                                        QualifyConstantBase(noise, q[noise]);
                                        QualifyConstantBase(amplitude, q[amplitude]);
                                        QualifyConstantBase(resolution, q[resolution]);
                                        QualifyConstantBase(mass, q[mass]); 

                                        CreateChart(a1peak.td);
                                        iItem:= AddGraphData(TGRAPH(Spectra), Color, TRUE);

                                        CopyMemory(Pointer(hjd.Result), Spectra.y, hjd.pt shl 3) 
                                        end { index } { a1peak };

CalcStdErr(a1peak.td);

BOOL(Result):= PostMessage(ThreadParam^, WM_THREADMSG, (0), 0)

end { DoFirstApproximation };

function DoOnePeakApproximation(ThreadParam : PHandle) : DWORD; stdcall; // function MathThread(ThreadParam : PMATHTHREADDATA) : DWORD; stdcall;

var index : Integer;

begin
SelectNotDrag:= FALSE;
SetCurrentFunc(a1peak.td.FuncStruct, a1peak.td.weights, a1peak.td.wi);
                     
with a1peak do with index do with td do begin
                                        FullQualifyConstant(noise, q[noise]);
                                        FullQualifyConstant(amplitude, q[amplitude]);
                                        FullQualifyConstant(resolution, q[resolution]);
                                        FullQualifyConstant(mass, q[mass]);

                                        CreateChart(a1peak.td);
                                        iItem:= AddGraphData(TGRAPH(Spectra), Color, TRUE)
                                        end { index } { a1peak };
 
index:= HookeAndJeevesTechnique();

with a1peak do with index do with td do begin
                                        q[amplitude].Value:= PReal(hjd.UPV + DWORD(amplitude shl 3))^;
                                        q[mass].Value:= PReal(hjd.UPV + DWORD(mass shl 3))^;
                                        q[resolution].Value:= PReal(hjd.UPV + DWORD(resolution shl 3))^;
                                        q[noise].Value:= PReal(hjd.UPV + DWORD(noise shl 3))^
                                        end { index } { a1peak }; 

CalcStdErr(a1peak.td);
                        
BOOL(Result):= PostMessage(ThreadParam^, WM_THREADMSG, (1), index)

end { DoOnePeakApproximation };

function TwoPeakFirstApproachErrorCode(out errcode, varindex : Integer) : Integer; 

var spectraamplitude,
    worseresolution : Real;
    index : Integer;

begin 
Result:= -1;  
spectraamplitude:= GetSpectraAmplitude(a2peak.td.data.y);
worseresolution:= 0.5*(a2peak.td.data.x[High(a2peak.td.data.x)] + a2peak.td.data.x[0])/(a2peak.td.data.x[High(a2peak.td.data.x)] - a2peak.td.data.x[0]);
with a2peak do with index do with td do begin 
                                        if ((q[noise].Value > spectraamplitude) or (q[noise].Value < 0.0)) then Result:= noise { IF };
                                        if ((q[amplitudel].Value > spectraamplitude + spectraamplitude) or (q[amplitudel].Value < 0.0)) then Result:= amplitudel { IF };
                                        if ((q[amplituder].Value > spectraamplitude + spectraamplitude) or (q[amplituder].Value < 0.0)) then Result:= amplituder { IF };
                                        if (q[resolutionl].Value < worseresolution) then Result:= resolutionl { IF };
                                        if (q[resolutionr].Value < worseresolution) then Result:= resolutionr { IF };
                                        if ((q[massl].Value < data.x[0]) or (q[massl].Value > data.x[High(data.x)])) then Result:= massl { IF };
                                        if ((q[massr].Value < data.x[0]) or (q[massr].Value > data.x[High(data.x)])) then Result:= massr { IF }
                                        end { index } { a2peak };

varindex:= -1;
for index:= 0 to (a2peak.td.FuncStruct.ENTIRETYSC) do if not (IsCorrectlyDefinedParam(a2peak.td.q[index], errcode)) then begin
                                                                                                                         Result:= -2;
                                                                                                                         varindex:= index;
                                                                                                                         Break
                                                                                                                         end { IF } { FOR }; 
                                                                              

end { TwoPeakFirstApproachErrorCode };

procedure QualifyToTwoPeak();
begin
if not (IsValidSpectra(SourceSpectra)) then Exit { IF };
SetTaskData(a2peak.td, SourceSpectra); 
with a2peak do with index do with td do begin
                                        with q[noise] do begin
                                                         Value:= 0.5*(noisel + noiser);
                                                         Step:= (q[amplitudel].Value + q[amplituder].Value)*1E-2;
                                                         Min:= 0.0;
                                                         Max:= 50.0*Step;
                                                         Precision:= Step*1E-4
                                                         end { qi };

                                        with q[amplitudel] do begin
                                                              Step:= q[amplitudel].Value*0.01;
                                                              Min:= 0.0;
                                                              Max:= q[amplitudel].Value*2.0;
                                                              Precision:= q[amplitudel].Value*1E-6
                                                              end { q[amplitudel] };

                                        with q[amplituder] do begin
                                                              Step:= q[amplituder].Value*0.01;
                                                              Min:= 0.0;
                                                              Max:= q[amplituder].Value*2.0;
                                                              Precision:= q[amplituder].Value*1E-6
                                                              end { q[amplituder] };

                                        with q[resolutionl] do begin
                                                               Step:= a1peak.td.q[a1peak.index.resolution].Step;
                                                               Min:= 0.0;
                                                               Max:= 5E4;
                                                               Precision:= 1E-1
                                                               end { q[resolutionl] };

                                        with q[resolutionr] do begin
                                                               Step:= a1peak.td.q[a1peak.index.resolution].Step;
                                                               Min:= 0.0;
                                                               Max:= 5E4;
                                                               Precision:= 1E-1
                                                               end { q[resolutionr] };
   
                                        with q[massl] do begin
                                                         Step:= 0.0001;
                                                         Min:= data.x[0];
                                                         Max:= data.x[High(data.x)];
                                                         Precision:= 1E-6
                                                         end { q[massl] };

                                        with q[massr] do begin
                                                         Step:= 0.0001;
                                                         Min:= data.x[0];
                                                         Max:= data.x[High(data.x)];
                                                         Precision:= 1E-6
                                                         end { q[massr] }
                                        end { index } { a2peak }
                                        
end { QualifyToTwoPeak };                                                                                                 


function DoTwoPeakApproximation(ThreadParam : PHandle) : DWORD; stdcall; 

var index : Integer; 

begin
SelectNotDrag:= FALSE;    
SetCurrentFunc(a2peak.td.FuncStruct, a2peak.td.weights, a2peak.td.wi);

with a2peak do with index do with td do begin
                                        FullQualifyConstant(noise, q[noise]);

                                        FullQualifyConstant(amplitudel, q[amplitudel]);
                                        FullQualifyConstant(resolutionl, q[resolutionl]);
                                        FullQualifyConstant(massl, q[massl]);

                                        FullQualifyConstant(amplituder, q[amplituder]);
                                        FullQualifyConstant(resolutionr, q[resolutionr]);
                                        FullQualifyConstant(massr, q[massr]);

                                        CreateChart(a2peak.td);
                                        iItem:= AddGraphData(TGRAPH(Spectra), Color, TRUE);
                                        sItem:= AddGraphData(TGRAPH(Spectra), a1peak.td.Color, sVisible)
                                        end { index } { a2peak };

index:= HookeAndJeevesTechnique();

if not (hjd.TerminateHJ) then with a2peak do with index do with td do begin
                                                                      q[noise].Value:= PReal(hjd.UPV + DWORD(noise shl 3))^;

                                                                      q[amplitudel].Value:= PReal(hjd.UPV + DWORD(amplitudel shl 3))^;
                                                                      q[massl].Value:= PReal(hjd.UPV + DWORD(massl shl 3))^;
                                                                      q[resolutionl].Value:= PReal(hjd.UPV + DWORD(resolutionl shl 3))^;

                                                                      q[amplituder].Value:= PReal(hjd.UPV + DWORD(amplituder shl 3))^;
                                                                      q[massr].Value:= PReal(hjd.UPV + DWORD(massr shl 3))^;
                                                                      q[resolutionr].Value:= PReal(hjd.UPV + DWORD(resolutionr shl 3))^
                                                                      end { index } { a2peak };

CalcStdErr(a2peak.td);

BOOL(Result):= PostMessage(ThreadParam^, WM_THREADMSG, (2), index)

end { DoTwoPeakApproximation };
 
(*function DoTwoPeakExhaustiveSearch(ThreadParam : PHandle) : DWORD; stdcall;
 
var index, indexr, indexl : Integer;
    dissection : DWORD;
    counter : Integer;
    bestindexl, bestindexr : Integer;
    bestresid : Real; 
  
begin
DeleteAllGraph();
SelectRangeDragMode:= DragMode; 

SetCurrentFunc(a2peak.FuncStruct);

dissection:= 9;


//hjd.TerminateHJ:= FALSE;

//QualifyPrecision(0.0);
 
with a1peak.value do begin
                     a2peak.amplitude:= amplitude;
                     FullQualifyConstant(a2peak.index.noise, 1E-4*amplitude, 0.0, amplitude, amplitude*0.01, amplitude*1E-6);
                     //FullQualifyConstant(a2peak.index.resolutionfactor, RESOLUTIONFACTOR, 0.0, 0.0, 0.0, 1.0);
                     //LockConstant(a2peak.index.resolutionfactor, TRUE);

                     FullQualifyConstant(a2peak.index.amplitudel, amplitude + noise, 0.0, amplitude + amplitude, 0.01*amplitude, amplitude*1E-6);
                     //FullQualifyConstant(a2peak.index.asymmetryl, 1000.0, 0.5, 10000.0, 1.0, 1E-4);
                     FullQualifyConstant(a2peak.index.resolutionl, resolution + resolution, 800.0, 5E3, a1peak.value.resolutionstep, 1E-1);
                     FullQualifyConstant(a2peak.index.massl, SourceSpectra.x[0], SourceSpectra.x[0], SourceSpectra.x[High(SourceSpectra.x)], 0.0001, 1E-9);

                     FullQualifyConstant(a2peak.index.amplituder, amplitude + noise, 0.0, amplitude + amplitude, 0.01*amplitude, amplitude*1E-6);
                     //FullQualifyConstant(a2peak.index.asymmetryr, 1000.0, 0.5, 10000.0, 1.0, 1E-4);
                     FullQualifyConstant(a2peak.index.resolutionr, resolution + resolution, 800.0, 5E3, a1peak.value.resolutionstep, 1E-1);
                     FullQualifyConstant(a2peak.index.massr, SourceSpectra.x[High(SourceSpectra.x)], SourceSpectra.x[0], SourceSpectra.x[High(SourceSpectra.x)], 0.0001, 1E-9)
                     end { a1peak };

Writeln('Quantity of ticks of one call (for criterion function) = ', TestTargetFunc($FF));

with a2peak do begin
               EnterCriticalSection(hjd.csec);
               ReduceChart(SourceSpectra.x, Spectra);
               iItem:= AddGraphData(TGRAPH(Spectra), RGB(255, 0, 0), TRUE); 
 
               LeaveCriticalSection(hjd.csec)
               end { a2peak };
                                      
Writeln; 
bestresid:= 1.0/0.0; 
counter:= 0;
for indexl:= 0 to (dissection - 1) do begin          
                                      a2peak.lstartmass:= SourceSpectra.x[0] + (indexl/dissection)*(SourceSpectra.x[High(SourceSpectra.x)] - SourceSpectra.x[0]);
                                      for indexr:= (dissection) downto (indexl + 1) do begin
                                                                                       a2peak.rstartmass:= SourceSpectra.x[0] + (indexr/dissection)*(SourceSpectra.x[High(SourceSpectra.x)] - SourceSpectra.x[0]);
                                                                                       with a1peak do begin
                                                                                                      QualifyConstantBase(index.noise, 1E-4*value.amplitude); 

                                                                                                      QualifyConstantBase(a2peak.index.amplitudel, value.amplitude + value.noise);
                                                                                                      QualifyConstantBase(a2peak.index.resolutionl, value.resolution + value.resolution);
                                                                                                      QualifyConstantBase(a2peak.index.massl, a2peak.lstartmass);

                                                                                                      QualifyConstantBase(a2peak.index.amplituder, value.amplitude + value.noise);
                                                                                                      QualifyConstantBase(a2peak.index.resolutionr, value.resolution + value.resolution);
                                                                                                      QualifyConstantBase(a2peak.index.massr, a2peak.rstartmass)
                                                                                                      end { a1peak };

                                                                                       DeleteItem(a2peak.sItem);
                                                                                       CreateChart(SourceSpectra.x, a2peak.FuncStruct, a2peak.Spectra); // Reduse не подойдёт в этом случае
                                                                                       a2peak.sItem:= AddGraphData(TGRAPH(a2peak.Spectra), RGB(0, 200, 0), TRUE); 

                                                                                       LockConstant(a2peak.index.noise, TRUE);
                                                                                       
                                                                                       if (HookeAndJeevesTechnique() = 1) then Writeln('TIMEOUT') { IF };

                                                                                       Write('---------------------------------------');

                                                                                       LockConstant(a2peak.index.noise, FALSE);
                                                                                       if (HookeAndJeevesTechnique() = 1) then Writeln('TIMEOUT') { IF };

                                                                                       if (hjd.TerminateHJ) then Break { IF };

                                                                                       Writeln; 
                                                                                       Writeln('Sqrt(S/(N - P)) = ', Sqrt(hjd.SFB/(hjd.pt - hjd.nco)));
                                                                                       if (bestresid > hjd.SFB) then begin   
                                                                                                                     bestresid:= hjd.SFB;
                                                                                                                     bestindexl:= indexl;
                                                                                                                     bestindexr:= indexr
                                                                                                                     end { IF };
                                                                                       Writeln('(interval/times) = ', hjd.ExpendedTime/hjd.FCC:0:3, ' ms');
                                                                                       Inc(counter);
                                                                                       Writeln(counter, '/', dissection*(dissection + 1) shr 1);
                                                                                       Writeln(100.0*counter/(dissection*(dissection + 1) shr 1):0:2, '%');
                                                                                       Writeln;
                                                                                       for index:= 0 to (a2peak.FuncStruct.ENTIRETY.ESC) do Writeln(a2peak.FuncStruct.Constants[index], ' = ', PReal(hjd.UPV + (index shl 3))^) { FOR };
                                                                                       Writeln
                                                                                       end { FOR };
                                      if (hjd.TerminateHJ) then Break { IF }
                                      end { FOR }; 
                     
a2peak.lstartmass:= SourceSpectra.x[0] + (bestindexl/dissection)*(SourceSpectra.x[High(SourceSpectra.x)] - SourceSpectra.x[0]);  
a2peak.rstartmass:= SourceSpectra.x[0] + (bestindexr/dissection)*(SourceSpectra.x[High(SourceSpectra.x)] - SourceSpectra.x[0]);
with a1peak do begin
               QualifyConstantBase(index.noise, 1E-4*value.amplitude);  

               QualifyConstantBase(a2peak.index.amplitudel, value.amplitude + value.noise);
               QualifyConstantBase(a2peak.index.resolutionl, value.resolution + value.resolution);
               QualifyConstantBase(a2peak.index.massl, a2peak.lstartmass);

               QualifyConstantBase(a2peak.index.amplituder, value.amplitude + value.noise);
               QualifyConstantBase(a2peak.index.resolutionr, value.resolution + value.resolution);
               QualifyConstantBase(a2peak.index.massr, a2peak.rstartmass)
               end { a1peak };

DeleteItem(a2peak.sItem); 
CreateChart(SourceSpectra.x, a2peak.FuncStruct, a2peak.Spectra);
a2peak.sItem:= AddGraphData(TGRAPH(a2peak.Spectra), RGB(0, 200, 0), TRUE);           

LockConstant(a2peak.index.noise, TRUE);

if (HookeAndJeevesTechnique() = 1) then Writeln('TIMEOUT') { IF };

Write('---------------------------------------');

LockConstant(a2peak.index.noise, FALSE);
if (HookeAndJeevesTechnique() = 1) then Writeln('TIMEOUT') { IF };

BOOL(Result):= not hjd.TerminateHJ;

if BOOL(Result) then PostMessage(ThreadParam^, WM_THREADMSG, (3), 0) { IF }

end { TwoPeakExhaustiveSearch };  *)

function Prepare(ThreadParam : PHandle) : DWORD; stdcall;
begin 
hjd.LimitsPermit:= TRUE;
hjd.SeparatePrecision:= TRUE;
hjd.Divisor:= 30.0;
//hjd.TimeOut:= INFINITE;

NEWTASK(@cb, $7F, $7F);
QualifyNamedLiteral('resolutionfactor', RESOLUTIONFACTOR);  
QualifyNamedLiteral('posinfexpprotector', REDUCEDINF.RPOS);
QualifyNamedLiteral('neginfexpprotector', REDUCEDINF.RNEG);

SetExpresion('noise+amplitude*exp(-sqr(resolutionfactor*resolution*(1-(_x/mass))))', a1peak.td.FuncStruct);
a1peak.td.wi:= SetWeightExpresion('1/_yc', a1peak.td.FuncStruct, a1peak.td.weights);
CreateDerivatives(a1peak.td.FuncStruct);
SetLength(a1peak.td.q, a1peak.td.FuncStruct.ENTIRETYSC + 1);
with a1peak do with index do with td do begin
                                        noise:= FINDCONSTVAR('noise', FuncStruct);
                                        amplitude:= FINDCONSTVAR('amplitude', FuncStruct);
                                        resolution:= FINDCONSTVAR('resolution', FuncStruct);
                                        mass:= FINDCONSTVAR('mass', FuncStruct);

                                        Color:= RGB(0, 200, 0)
                                        end { index } { a1peak };

SetExpresion('noise+amplitudel*exp(-sqr(resolutionfactor*resolutionl*(1-(_x/massl))))+amplituder*exp(-sqr(resolutionfactor*resolutionr*(1-(_x/massr))))', a2peak.td.FuncStruct);
a2peak.td.wi:= SetWeightExpresion('1/_yc', a2peak.td.FuncStruct, a2peak.td.weights);
CreateDerivatives(a2peak.td.FuncStruct);
SetLength(a2peak.td.q, a2peak.td.FuncStruct.ENTIRETYSC + 1);
with a2peak do with index do with td do begin
                                        noise:= FINDCONSTVAR('noise', FuncStruct);
                                        amplitudel:= FINDCONSTVAR('amplitudel', FuncStruct);
                                        resolutionl:= FINDCONSTVAR('resolutionl', FuncStruct);
                                        massl:= FINDCONSTVAR('massl', FuncStruct);
                                        amplituder:= FINDCONSTVAR('amplituder', FuncStruct);
                                        resolutionr:= FINDCONSTVAR('resolutionr', FuncStruct);
                                        massr:= FINDCONSTVAR('massr', FuncStruct);
                                        //noiser:= a2peak.FuncStruct.ENTIRETYSC + 1;

                                        Color:= RGB(255, 0, 0)
                                        end { index } { a2peak };

ss.Color:= RGB(80, 80, 255); 
                                              
BOOL(Result):= PostMessage(ThreadParam^, WM_THREADMSG, (-5), 0)

end { Prepare }; 

INITIALIZATION

asm
        FNINIT

        // 2.0*Sqrt(Ln(2.0))  
        FLDLN2 
        FSQRT
        FADD ST, ST(0)
        FSTP RESOLUTIONFACTOR // ~=1.66510922231540

        // Sqrt(Pi)
        FLDPI
        FSQRT
        FSTP SQRTPI // ~=1.77245385090552

end { ASM }

FINALIZATION        

END { BFMETHOD }.    
