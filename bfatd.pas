{ © 2007-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfatd;
// Абстрактные типы данных и множество операторов над ними для компилятора и его
// связки с процедурой поиска наилучшего приближения вида функции методом Хука-Дживса.
// В совокупности модули bfatd, bfcompiler, bfhjtechnique являются как бы engine
// для решения возможных численных задач оптимизации многопараметрических функций
// многих переменных, в частности, задачи минимизации суммы квадратов невязок для
// метода наименьших квадратов (функция TargetFunction на самом деле считает
// именно сумму взвешеных квадратов невязок, но несложно переделать на любую другую
// задачу (целевую функцию), изменив всего лишь несколько строк (десятков =) ))

INTERFACE

uses Windows;

type //PQUALIFYITEM = ^TQUALIFYITEM;
     TQUALIFYITEM = record
                    Locked : BOOL;    
                    Value,
                    Min,
                    Max,
                    Step,
                    Precision,
                    rmse : Real // root-sum-square uncertainty, mean square error, root-mean-square error, standard error
                    end { TQUALIFYITEM };
 
type TQUALIFY = array of TQUALIFYITEM { TQUALIFY };

type TMATRIX = array of array of Real; // dim = 2*2 и больше - только квадратные, [v, h] == [строка - 1, столбец - 1] - массив указателей на строки

const LBRACKET = '(';
      RBRACKET = ')';

type //PSPECTRAAXIES = ^TSPECTRAAXIES;
     TSPECTRAAXIES = array of Real;

type TSPECTRA = record
                x,
                y : TSPECTRAAXIES
                end { TSPECTRA };

(*type //PSPECTRALIST = ^TSPECTRALIST;
     TSPECTRALIST = array of TSPECTRA { TSPECTRALIST };*)      

type DIAGRAM = record // Шаблон строки и оператор над ней
               template,         // Справа налево
               operator : string // Слева направо
               end { DIAGRAMS }; 

type FUNCDEFINITION = record
                      EntryPoint : function(DSV : HGLOBAL) : Real; stdcall; // Изменяет EAX и EDX, EFLAGS (max и min) по stdcall остваляет в ST(0) результат вычислений
                      //FuncName : string; // Имя функции
                      Expresion : string; // Сторока-выражение 
                      CODE : array of Byte // Указатель на массив, служит для удобного обращения к памяти при формировании кода (посредством встроенного АТД динамических массивов)
                      end { FUNCDEFINITION };                          

type FUNC = ^_FUNC;
     _FUNC = record // Как можно более удобная структура для создания функций и использования их в методе Хука-Дживса
             Functions : array of FUNCDEFINITION; // На одной базе можно определить несколько функций 
             Variables : array of string; // Имена переменных параметров
             Constants : array of string; // Имена постоянных параметров
             DSC : HGLOBAL; // Указатель на область памяти (массив Real чисел), константы в порядке их появления при парсинге
             // private
             // автомат при рекурсии в парсинге - контроль использования данных
             ENTIRETYSV, // Заполненность массива переменных минус один
             ENTIRETYSC : Integer // Заполненность массива констант минус один
             end { _FUNC };                    

function FINDTEMPLATE(const expr : string; const MAPPING : array of DIAGRAM; out l, r : string; var id : Integer) : BOOL;
function SECONDBRACKET(const EXPRESSION : string; FIRSTBRACKET : Integer) : Integer;
procedure DeleteExternalBracket(var EXPRESSION : string);
procedure FIRSTFUNCTION(var fs : _FUNC); // Инициализирует структуру fs для компиляции
function NEXTFUNCTION(var fs : _FUNC) : Integer; // Создаёт ещё одну структуру под код и строковые определения функции
function IsVarIdent(const S : string) : BOOL; // Тестирует на соответствие строки возможному имени параметру-переменной
function IsConstIdent(const S : string) : BOOL; // Тестирует на соответствие строки возможному имени параметру-постоянной
function FINDCONSTVAR(const S : string; const fs : _FUNC) : Integer; // Даёт индекс параметру-переменной или параметру-постоянной, которому дано в соответствие место в массиве (переменных или констант)
function NEWCONSTORVAR(const S : string; var fs : _FUNC) : Integer; // Добавляет новое имя в массив переменных/констант и даёт индекс или даёт индекс старого, взамен которого было помещено новое
function det(const m : TMATRIX) : Real;
function minor(const m : TMATRIX; v, h : Integer) : TMATRIX;

IMPLEMENTATION 

// В наборе шаблонов MAPPING ищет по приоритету первый соответствующий expr шаблон и возвращает его индекс и указанные подстроки ('l#' и/или 'r#').
// Последний шаблон в MAPPING должен быть проходным (типа 'l#' или 'r#')
function FINDTEMPLATE(const expr : string; const MAPPING : array of DIAGRAM; out l, r : string; var id : Integer) : BOOL; // Функция была написана сначала на листочке бумаги

var io, ie,
    b : Integer; 
    cur_tpl,
    drain : string;

begin
id:= -1;
Result:= FALSE;
if (expr = '') then Exit { IF };    
b:= 0;
repeat            
Inc(id);
SetLength(l, 0);
SetLength(r, 0);
cur_tpl:= MAPPING[id].template;
io:= Length(cur_tpl);
ie:= Length(expr);
repeat        
if (cur_tpl[io] = '#') then begin
                            Dec(io, 2);
                            if (io = 0) then begin
                                             drain:= Copy(expr, 1, ie);
                                             ie:= 0
                                             end
                                        else begin
                                             b:= 0;
                                             SetLength(drain, 0); 
                                             repeat
                                             drain:= expr[ie] + drain; 
                                             case expr[ie] of RBRACKET : Inc(b) { RBRACKET };
                                                              LBRACKET : Dec(b) { LBRACKET }
                                             end { CASE };
                                             Dec(ie); 
                                             if ((ie > 0) and (b = 0)) then if (expr[ie] = cur_tpl[io]) then Break { IF } { IF }
                                             until (ie = 0) { REPEAT }
                                             end { IF };
                            case cur_tpl[io + 1] of 'l' : l:= drain { 'l' }; // Можно ещё 254 разных варианта для case сделать, а не только l и r
                                                    'r' : r:= drain { 'r' }
                            end { CASE }
                            end
                       else if (expr[ie] = cur_tpl[io]) then begin
                                                             Dec(ie);
                                                             Dec(io)
                                                             end
                                                        else Break { IF } { IF }
until ((io = 0) or (ie = 0)) { REPEAT }
until ((id = High(MAPPING)) or ((io = 0) and (ie = 0))) { REPEAT }; // Если отображение MAPPING устроено корректно, то (id = High(MAPPING)) не надобится
Result:= ((io = 0) and (ie = 0)) and (b = 0) // Строки разобраны до конца + все закрытые скобки - открыты
                         
end { FINDTEMPLATE };   

function SECONDBRACKET(const EXPRESSION : string; FIRSTBRACKET : Integer) : Integer; // Алгоритм обхода препятствий :)

var index, L : Integer;

begin
Result:= 0;

L:= Length(EXPRESSION);
if ((L = 0) or (FIRSTBRACKET > L) or (FIRSTBRACKET < 1) or not ((EXPRESSION[FIRSTBRACKET] = LBRACKET) or (EXPRESSION[FIRSTBRACKET] = RBRACKET))) then Exit { IF };

index:= 0;
Result:= FIRSTBRACKET;
case EXPRESSION[FIRSTBRACKET] of RBRACKET : repeat
                                            if ((index = 1) and (EXPRESSION[Result] = LBRACKET)) then Exit { IF };
                                            case EXPRESSION[Result] of LBRACKET : Dec(index) { LBRACKET };
                                                                       RBRACKET : Inc(index) { RBRACKET }
                                            end { CASE };
                                            Dec(Result)
                                            until (Result < 1) { RBRACKET };
                                 LBRACKET : repeat
                                            if ((index = 1) and (EXPRESSION[Result] = RBRACKET)) then Exit { IF };
                                            case EXPRESSION[Result] of RBRACKET : Dec(index) { RBRACKET };
                                                                       LBRACKET : Inc(index) { LBRACKET }
                                            end { CASE };
                                            Inc(Result)
                                            until (Result > L) { LBRACKET }
end { CASE };

if (Result > L) then Result:= 0 // or 0 = L + 1 

end { SECONDBRACKET };

procedure DeleteExternalBracket(var EXPRESSION : string);
begin
while (SecondBracket(EXPRESSION, Length(EXPRESSION)) = 1) do EXPRESSION:= Copy(EXPRESSION, 2, Length(EXPRESSION) - 2) { WHILE }

end { DeleteExternalBracket };
                    
function FINDCONSTVAR(const S : string; const fs : _FUNC) : Integer;

var index : Integer;

begin
Result:= - 1;
                                
if (IsVarIdent(S)) then begin
                        for index:= 0 to (fs.ENTIRETYSV) do if (fs.Variables[index] = S) then Result:= index { IF } { FOR }
                        end
                   else if (IsConstIdent(S)) then for index:= 0 to (fs.ENTIRETYSC) do if (fs.Constants[index] = S) then Result:= index { IF } { FOR } { IF }
                         
end { FINDCONSTVAR };

const //ALLOWCHARS = ['('..'9', '^'..'_', 'a'..'z']; // ()*+,-./0123456789^_abcdefghijklmnopqrstuvwxyz // [40..57, 94..95, 97..122];
      DENYFIRST = ['0'..'9', '_'];
      IDENTIFIERCHARS = ['0'..'9', '_', 'a'..'z'];

function IsConstIdent(const S : string) : BOOL;

var index, L : Integer;

begin
Result:= FALSE;

L:= Length(S);
for index:= 1 to (L) do if not (S[index] in IDENTIFIERCHARS) then L:= 0 { IF } { FOR }; // Так нельзя, но что ж поделать

if (L > 0) then if not (S[1] in DENYFIRST) then Result:= TRUE { IF } { IF }
           
end { IsConstIdent };          
 
function IsVarIdent(const S : string) : BOOL;

var index, L : Integer;

begin      
Result:= FALSE;

L:= Length(S);
for index:= 1 to (L) do if not (S[index] in IDENTIFIERCHARS) then L:= 0 { IF } { FOR };

if (L > 0) then if ((S[1] = '_') and not (S[2] in DENYFIRST)) then Result:= TRUE { IF } { IF }
                   
end { IsVarIdent };
 
(*function IsExpresion(const S : string) : BOOL;

var index, L, b : Integer;

begin
Result:= FALSE;

L:= Length(S);
if (L = 0) then Exit { IF };

Result:= TRUE;
for index:= 1 to (L) do Result:= (Result and (S[index] in ALLOWCHARS)) { FOR }; 

if (Result) then b:= 0
            else Exit { IF };

for index:= 1 to (L) do case S[index] of LEFTBRACKET : Inc(b);
                                         RIGHTBRACKET : Dec(b)
                        end { CASE } { FOR };

Result:= (b = 0) // Только когда все открытые скобки закрыты и наоборот

end { IsExpresion };*)

function NEWCONSTORVAR(const S : string; var fs : _FUNC) : Integer; // До этой процедуры не должно допускать строки 'pi', 'l2e', 'l2t', 'lg2', 'ln2'
begin        
Result:= FINDCONSTVAR(S, fs);

if (Result > - 1) then Exit { IF };

if (IsVarIdent(S)) then with fs do begin
                                   Inc(ENTIRETYSV);
                                   Result:= ENTIRETYSV;
                                   SetLength(Variables, ENTIRETYSV + 1);
                                   Variables[ENTIRETYSV]:= S
                                   end { WITH }
                   else if (IsConstIdent(S)) then with fs do begin
                                                             Inc(ENTIRETYSC);
                                                             Result:= ENTIRETYSC;
                                                             SetLength(Constants, ENTIRETYSC + 1);
                                                             Constants[ENTIRETYSC]:= S
                                                             end { WITH } { IF } { IF }
                                     
end { NEWCONSTORVAR };
          
procedure FIRSTFUNCTION(var fs : _FUNC);
begin
with fs do begin
           SetLength(Functions, 1);
           ENTIRETYSV:= -1;
           ENTIRETYSC:= -1
           end { fs^ }

end { FIRSTFUNCTION };

function NEXTFUNCTION(var fs : _FUNC) : Integer;
begin
Result:= Length(fs.Functions);
SetLength(fs.Functions, Result + 1) 

end { NEXTFUNCTION };

function minor(const m : TMATRIX; v, h : Integer) : TMATRIX; // v - строка, h - столбец

var index, iv, ih, ivp, ihp,
    dim : Integer;

begin
dim:= High(m);
SetLength(Result, dim);
for index:= (dim - 1) downto (0) do SetLength(Result[index], dim) { FOR };
for index:= (dim*dim - 1) downto (0) do begin
                                        ih:= index mod dim;
                                        ihp:= ih;
                                        if (ih >= h) then Inc(ihp) { IF };

                                        iv:= index div dim;
                                        ivp:= iv;
                                        if (iv >= v) then Inc(ivp) { IF };

                                        Result[iv][ih]:= m[ivp][ihp]
                                        end { FOR }

end { minor };

function det(const m : TMATRIX) : Real; // Определитель

var index, H : Integer;
    tmp : Real;

begin
H:= High(m);

if (H = 1) then Result:= m[0][0]*m[1][1] - m[0][1]*m[1][0]
//if (H = 0) then Result:= m[0][0]
           else begin
                Result:= 0.0;
                for index:= H downto (0) do begin
                                            tmp:= m[0][index]*det(minor(m, 0, index)); // по первой строке
                                            if (Odd(index)) then Result:= Result - tmp // Превращаем определитель минора в алгебраическое дополнение
                                                            else Result:= Result + tmp { IF }
                                            end { FOR }
                end { IF }

end { det };

INITIALIZATION

FINALIZATION    

END { BFATD }.
