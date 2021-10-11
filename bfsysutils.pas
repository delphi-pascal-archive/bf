{ © 2007-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfsysutils;
// Всякие функции не по теме.
// Функция быстрой сортировки переведена с C-примера из книги Томаса Нимана: "Сортировка и поиск: Рецептурный справочник"

INTERFACE

uses Windows;      

const ERROR_ = 'Ошибка';  

var Buffer : PChar;  

type //PSingle = ^Single;
     PReal = ^Real;
     
                    // Округление:
var stdcw,          // в сторону ближайшего целого
    cwup,           // в сторону плюс бесконечности
    cwdown,         // в сторону минус бесконечности
    cwtrunc : Word; // в сторону нуля (отсечением дробной части)

function IntToStr(N : Integer) : string; overload; // Integer 2 string
function IntToStr(C : DWORD) : string; overload;
function FloatToStr(X : Real) : string; // Чтобы сохранять поменьше байт
function StrToFloat(S : string) : Real; // String to float
procedure RankFloat(var Smaller, Bigger : Real); // Упорядочивает предлагаемые действительные числа по возрастанию
function GetCPUFreq() : LONGLONG; stdcall; assembler; // Счтает количество тиков процессора за одну секунду (в смысле Windows'а)
procedure QUICKSORT(var a : array of Real; l, h : Integer); // Thomas Niemann. "Sorting and Searching - A Cookbook"
 
IMPLEMENTATION 

function GetCPUFreq() : LONGLONG; stdcall; assembler;
asm
        push ECX
        push EBX

        db 00Fh, 031h // rdtsc
        push EAX
        push EDX
        push 1000 // Milliseconds 	
        call Sleep
        db 00Fh, 031h // rdtsc  
        pop ECX
        pop EBX
        sub EAX, EBX
        sbb EDX, ECX

        pop EBX
        pop ECX 

end { GetCPUFreq };   

procedure RankFloat(var Smaller, Bigger : Real); // var = in + out
asm
        FNINIT

        FLD qword ptr [Smaller]
        FLD qword ptr [Bigger]
        FCOMI ST, ST(1)
        ja @nxchg
        FSTP qword ptr [Smaller]
        FSTP qword ptr [Bigger]
@nxchg:                

end { RankFloat }; 

function IntToStr(N : Integer) : string;
begin
Str(N, Result)

end { IntToStr };

function IntToStr(C : DWORD) : string; 
begin
Str(C, Result)

end { IntToStr };

function FloatToStr(X : Real) : string;

var index : Integer;

begin
Str(X, Result); 
if (Result[1] = ' ') then Delete(Result, 1, 1) { IF };
index:= Pos('0E', Result);
while (index > 0) do begin
                     Delete(Result, index, 1);
                     index:= Pos('0E', Result)
                     end { WHILE };
index:= Pos('.E', Result);
if (index > 0) then Delete(Result, index, 1) { IF };
index:= Pos('E+', Result);
if (index > 0) then begin
                   Delete(Result, index + 1, 1);
                   index:= Pos('E0', Result);
                   while (index > 0) do begin
                                        Delete(Result, index + 1, 1);
                                        index:= Pos('E0', Result)
                                        end { WHILE };
                   index:= Length(Result);
                   if (Result[index] = 'E') then Delete(Result, index, 1) { IF }
                   end { IF };
index:= Pos('-0', Result);
while (index > 0) do begin
                     Delete(Result, index + 1, 1);
                     index:= Pos('-0', Result)
                     end { WHILE }
//index:= Length(Result) - 1;
//if (Result[index] = 'E-') then Delete(Result, index, 2) { IF }

end { FloatToStr };

function StrToFloat(S : string) : Real;

var Code : Integer;

begin
Val(S, Result, Code)

end { StrToFloat };

// Thomas Niemann. "Sorting and Searching - A Cookbook"
procedure QUICKSORT(var a : array of Real; l, h : Integer);

var m : Integer;

 function PARTITION(var a : array of Real; l, h : Integer) : Integer;

 var c, t : Real;
     i, j, p : Integer;

 begin
 p:= l + ((h - l) shr 1);
 c:= a[p];
 a[p]:= a[l];

 i:= l + 1;
 j:= h;
 repeat
 while ((i < j) and (c > a[i])) do Inc(i) { WHILE };
 while ((j >= i) and (a[j] > c)) do Dec(j) { WHILE };
 if (i >= j) then Break { IF };
 t:= a[i];
 a[i]:= a[j];
 a[j]:= t;
 Dec(j);
 Inc(i)
 until (FALSE) { REPEAT };
 a[l]:= a[j];
 a[j]:= c;
 Result:= j

 end { PARTITION };

begin
while (l < h) do begin
                 m:= PARTITION(a, l, h);
                 if (m - l <= h - m) then begin
                                          QUICKSORT(a, l, m - 1);
                                          l:= m + 1
                                          end
                                     else begin
                                          QUICKSORT(a, m + 1, h);
                                          h:= m - 1
                                          end { IF }   
                 end { WHILE };     

end { QUICKSORT };

INITIALIZATION   
 
asm
        FNINIT  // set cw in std val
        FNSTCW stdcw
        
        mov AX, stdcw
        bts AX, 11
        btr AX, 10
        mov cwup, AX
        bts AX, 10
        btr AX, 11
        mov cwdown, AX
        bts AX, 10
        bts AX, 11
        mov cwtrunc, AX

end { ASM };

HGLOBAL(Buffer):= GlobalAlloc(GPTR, MAX_PATH)

FINALIZATION

GlobalFree(HGLOBAL(Buffer))
                     
END { BFSYSUTILS }. 
