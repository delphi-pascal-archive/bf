{ © 2006-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfcompiler;
// Компилятор математических выражений (любой сложности - без переполнения стека FPU)
// с поддержкой идентификаторов-констант (pi, l2e, l2t, lg2, ln2 и user-defined именованные константы и др.).
// Начальная идея компилятора (образец): Сергей Втюрин, "Компилятор синтаксических выражений", delphikingdom.ru

INTERFACE

uses Windows, // BOOL/DWORD/PDWORD declaration
     bfatd;

type PCOMPILERBASE = ^TCOMPILERBASE { PCOMPILERBASE };
     TCOMPILERBASE = record
                     LSG : array of Real; // Указатель на массив хранящий значения литералов: значения не именованных не повторяются
                     TMP : array of Real; // Указатель на массив, служащий для сбрасывания переменных, которое происходит в случае, если следующий код переполняет стек матсопроцессора
                     ENTIRETYLSG,
                     ENTIRETYTMP : Integer; // Заполнености массивов минус один
                     // Литералы
                     LiteralNames : array of string;
                     LiteralIndexes : array of Integer 
                     end { TCOMPILERBASE };

procedure NEWTASK(pcb : PCOMPILERBASE; LSGSIZE, TMPSIZE : DWORD); // Выделяет память под стек защиты от переполнения и массив для значений литералов
//procedure OLDTASK(pcb : PCOMPILERBASE); // Здесь не надобится (впрок)
function BUILD(var fs : _FUNC; nf : DWORD) : BOOL; // Компилирует функцию, определённую в специальной стуктуре, в исполняемый код непосредственно в память
procedure QualifyNamedLiteral(const NAME : string; const VALUE : Real); // Задаёт именованную константу 

IMPLEMENTATION 
     
var pcb : PCOMPILERBASE; // Текущая установленная ссылка - на базу для всех компилируемых функций

procedure NEWTASK(pcb : PCOMPILERBASE; LSGSIZE, TMPSIZE : DWORD);
begin
with pcb^ do begin
             ENTIRETYLSG:= -1;
             ENTIRETYTMP:= -1;

             LiteralNames:= nil;
             LiteralIndexes:= nil;

             SetLength(LSG, LSGSIZE);
             SetLength(TMP, TMPSIZE)
             end { pcb^ };          
 
bfcompiler.pcb:= pcb

end { NEWFUNCTION };    

(*procedure OLDTASK(pcb : PCOMPILERBASE);
begin
bfcompiler.pcb:= pcb

end { OLDTASK };*)

procedure QualifyNamedLiteral(const NAME : string; const VALUE : Real); // Выделяет место в массиве литералов под значение X литерала или переназначает литералу с именем NAME значение VALUE там же

var index, index0, L : Integer;

begin
with pcb^ do begin
             L:= Length(LiteralNames);
             index0:= L;
             for index:= High(LiteralNames) downto (0) do if (LiteralNames[index] = NAME) then begin
                                                                                               index0:= index;
                                                                                               Break
                                                                                               end { IF } { FOR };

             if (index0 = L) then begin
                                  SetLength(LiteralNames, L + 1);
                                  SetLength(LiteralIndexes, L + 1);

                                  LiteralNames[L]:= NAME;
                                  Inc(ENTIRETYLSG);
                                  LiteralIndexes[L]:= ENTIRETYLSG
                                  end { IF };

             LSG[LiteralIndexes[index0]]:= VALUE
             end { pcb^ }

end { QualifyNamedLiteral };

function GetNamedLiteralIndex(const EXPRESION : string) : Integer; // Возвращает индекс значения литерала в массиве литералов или -1 если литерала с таким именем небыло задано

var index : Integer;

begin
Result:= -1;
with pcb^ do for index:= High(LiteralNames) downto (0) do if (LiteralNames[index] = EXPRESION) then begin
                                                                                                    Result:= LiteralIndexes[index];
                                                                                                    Break
                                                                                                    end { IF } { FOR } { pcb^ }

end { GetNamedLiteralIndex };
                                                                                        // операторы - соответственный код, формируемый процедурой PARSE
var SUPPORTEDOPERATORS : array [0..34] of DIAGRAM = ((template : 'l#+r#';               operator : ''           ),
                                                     (template : '+r#';                 operator : ''           ),
                                                     (template : 'l#-r#';               operator : ''           ),
                                                     (template : '-r#';                 operator : ''           ),
                                                     (template : 'l#*r#';               operator : ''           ),
                                                     (template : 'l#/r#';               operator : ''           ),
                                                     (template : 'l#^r#';               operator : ''           ),
                                                     (template : 'cos(r#)';             operator : ''           ),
                                                     (template : 'sin(r#)';             operator : ''           ),
                                                     (template : 'ln(r#)';              operator : ''           ),
                                                     (template : 'exp(r#)';             operator : ''           ),
                                                     (template : 'lg(r#)';              operator : ''           ),
                                                     (template : 'tg(r#)';              operator : ''           ),
                                                     (template : 'ctg(r#)';             operator : ''           ),
                                                     (template : 'arctg(r#)';           operator : ''           ),
                                                     (template : 'pwr(l#)(r#)';         operator : ''           ),
                                                     (template : 'abs(r#)';             operator : ''           ),
                                                     (template : 'sqr(r#)';             operator : ''           ),
                                                     (template : 'sqrt(r#)';            operator : ''           ),
                                                     (template : 'round(r#)';           operator : ''           ),
                                                     (template : 'polynom(l#)(r#)';     operator : ''           ),
                                                     (template : 'log2(r#)';            operator : ''           ),
                                                     (template : 'log(l#)(r#)';         operator : ''           ),
                                                     (template : 'arcsin(r#)';          operator : ''           ),
                                                     (template : 'arccos(r#)';          operator : ''           ),
                                                     (template : 'chs(r#)';             operator : ''           ),
                                                     (template : 'max(r#)';             operator : ''           ),
                                                     (template : 'min(r#)';             operator : ''           ),
                                                     (template : 'pi';                  operator : ''           ),
                                                     (template : 'l2e';                 operator : ''           ),
                                                     (template : 'l2t';                 operator : ''           ),
                                                     (template : 'lg2';                 operator : ''           ),
                                                     (template : 'ln2';                 operator : ''           ),
                                                     (template : 'double(r#)';          operator : ''           ),
                                                     (template : 'r#';                  operator : ''           )) { SUPPORTEDOPERATORS };
                                                     
const CDIM = High(SUPPORTEDOPERATORS);

function NEXTCOEFF(var EXPRESION : string; PREFIX : string = '') : string; // Вырезает фрагменты si с указанным префиксом prefi из строки типа 'pref0(s0)pref1(s1)pref2(s2)...', где каждый prefi может быть пустой строкой (порядок изъятия - справа налево для prefi - пустых строк)

var index, BC, LP, a, b2 : Integer;
    FLAG : BOOL;

begin
LP:= Length(PREFIX);
BC:= 0; 
SetLength(Result, 0); 
for index:= Length(EXPRESION) downto (1) do begin
                                            case EXPRESION[index] of LBRACKET : Dec(BC) { LBRACKET };
                                                                     RBRACKET : Inc(BC) { RBRACKET }
                                            end { CASE };
                                            if (BC <> 0) then Continue { IF };
                                            if (LP = 0) then if (index = 1) then FLAG:= TRUE
                                                                            else FLAG:= (EXPRESION[index - 1] = ')') and (EXPRESION[index] = '(') { IF }
                                                        else FLAG:= (Copy(EXPRESION, index, LP) = PREFIX) { IF };
                                            if (FLAG) then begin
                                                           a:= index + LP;
                                                           b2:= SecondBracket(EXPRESION, a) + 1;
                                                           Result:= Copy(EXPRESION, a, b2 - a);
                                                           Delete(EXPRESION, index, b2 - index);
                                                           Break
                                                           end { IF }
                                            end { FOR }

end { NEXTCOEFF };

function BUILD(var fs : _FUNC; nf : DWORD) : BOOL;

var STUSE : DWORD; // bottom-stack pointer ST(STUSE) - чтобы функция PARSE вела себя как автомат при парсинге, д.б. внешней для PARSE

 procedure addBYTE(B : Byte); // Добавляет байт в CODE

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + SizeOf(Byte));
                          CODE[L]:= B
                          end { fs.Functions[nf] }

 end { addBYTE };            

 procedure addWORD(W : Word); // Добавляет слово в CODE. Наоборот байты опкодов... зато меньше кода, чем по байту

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + SizeOf(Word));
                          PWORD(@CODE[L])^:= W
                          end { fs.Functions[nf] }

 end { addWORD }; // FWORD? - 2 times

 procedure addDWORD(D : DWORD); // Добавляет двойное слово в CODE. Байты опкодов справа налево

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + SizeOf(DWORD));
                          PDWORD(@CODE[L])^:= D
                          end { fs.Functions[nf] }

 end { addDWORD };

 (*procedure addQWORD(Q : LONGLONG); // Добавляет учетверённое слово в CODE. Байты опкодов справа налево

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + 8);
                          PInt64(@CODE[L])^:= Q
                          end { fs.Functions[nf] }

 end { addQWORD }; *)

 procedure PARSE(EXPRESION : string); // Формирует CODE процедуры

  {------------------------------------------------------------------------------
  Increment or Decrement Stack Pointer
  Syntax: FINCSTP, FDECSTP
  Description: Increments or decrements the stack-top pointer in the status word.
  No tags or registers are changed, and no data is transferred.
  If the stack pointer is 7, FINCSTP changes it to 0.
  If the stack pointer is 0, FDECSTP changes it to 7.
  -------------------------------------------------------------------------------}

  // Создавая этот алгоритм контроля за переполнением я ловил ошибки даже 100 раз перепроверив всЁЁ ! почти отчаялся(... Но потом обратил на описание комманд FDECSTP и FINCSTP 'no data is transferred'... и поменял их местами))). Оказвается крутил не в ту сторону

  // STPEAK - количество операндов, к которым обращается код; STREQUARED - количество регистров, используемое кодом в общем; STABANDONED - сколько переменных оставляет после вычислений
  procedure CONTROL(STPEAK, STREQUIRED : DWORD; STABANDONED : DWORD = 1);

  const STSIZE : DWORD = 8; // Размер стека - постоянная для всех процессоров 80x86

  var index : DWORD;

   procedure PUSHONOVERFLOW(); 
   begin 
   with pcb^ do begin
                Inc(ENTIRETYTMP);

                addWORD($1DDD); // FSTP qword ptr [DWORD(@pcb^.TMP[pcb^.ENTIRETYTMP])]
                addDWORD(DWORD(@TMP[ENTIRETYTMP]))
                end { IF } { pcb^ }    

   end { PUSHONOVERFLOW };

   procedure POPONSHORTAGE(); 
   begin                   
   with pcb^ do begin
                addWORD($05DD); // FLD qword ptr [DWORD(@pcb^.TMP[pcb^.ENTIRETYTMP])]
                addDWORD(DWORD(@TMP[ENTIRETYTMP]));

                Dec(ENTIRETYTMP)
                end { IF } { pcb^ }

   end { POPONSHORTAGE };

  begin // Необходима внешняя для PARSE переменная STUSE.
  // Если кольцевой стек переполнится из-за действий кода далее, то необходимо слить часть ячеек в TMP;
  // или если нехватает операндов для последующего кода, то необходимо считать несколько операндов из TMP
  if (STREQUIRED + STUSE > STSIZE + STPEAK) then begin // на ((STUSE + (STREQUIRED - STPEAK)) - STSIZE) ячеек переполнение из-за действий следующего кода
                                                 for index:= (1 + STPEAK) to (STREQUIRED) do addWORD($F6D9) { FOR }; // FDECSTP // Крутим-вертим пока ((STUSE + (STREQUIRED - STPEAK)) - STSIZE) последних ячеек не будет лежать на вершине (повернули на ((((STUSE - STPEAK) + STREQUIRED) - STUSE) ячеек в "прямую" сторону (всего STREQUIRED - STPEAK))
                                                 for index:= (1 + STPEAK + STSIZE) to (STREQUIRED + STUSE) do PUSHONOVERFLOW() { FOR }; // Сливаем ((STUSE + (STREQUIRED - STPEAK)) - STSIZE) ячеек (повернули на ((((STUSE - STPEAK) + STREQUIRED) - STSIZE) ячеек в "обратную" сторону)
                                                 for index:= (1 + STUSE) to (STSIZE) do addWORD($F7D9) { FOR }; // FINCSTP // Докручиваем пока бывшая вершина стека не вернётся на место (повернули на (((((STUSE - STPEAK) + STREQUIRED) - STUSE) - ((((STUSE - STPEAK) + STREQUIRED) - STSIZE)) ячеек в "обратную" сторону (всего STSIZE - STUSE))
                                                 STUSE:= STSIZE - (STREQUIRED - STPEAK)
                                                 end { IF };

  if (STPEAK > STUSE) then begin // возможно stack fault // нехватка (STPEAK - STUSE) ячеек
                           for index:= (1 + STUSE) to (STPEAK) do POPONSHORTAGE() { FOR }; // Выкладываем (STPEAK - STUSE) ячеек
                           STUSE:= STPEAK 
                           end { IF };

  Inc(STUSE, STABANDONED - STPEAK) // После действий кода остаётся STUSE занятых ячеек                         

  end { CONTROL }; 

 var index, o, a : Integer;
     l, r : string; 

  procedure LPARSE();
  begin
  if (Result) then PARSE(l) { IF }

  end { LPARSE };  

  procedure RPARSE(); 
  begin
  if (Result) then PARSE(r) { IF }

  end { RPARSE };

  procedure NEXTPARSE();
  begin
  if (Result) then PARSE(NEXTCOEFF(r)) { IF }

  end { NEXTPARSE };

  procedure TRYLOAD();

  var x : Real;
      index0, index1 : Integer;

  begin                 
  Val(r, x, o); // Если r - число, то x равно этому числу, (o = 0), иначе (o <> 0) а (x == 0.0)
  if (o = 0) then with pcb^ do begin
                               if (x = 0.0) then begin 
                                                 CONTROL(0, 1);
                                                 addWORD($EED9) // FLDZ 
                                                 end
                                            else if (x = 1.0) then begin    
                                                                   CONTROL(0, 1); 
                                                                   addWORD($E8D9) // FLD1
                                                                   end
                                                              else begin // Литералы >> в LSG
                                                                   a:= -1;

                                                                   for index0:= 0 to (ENTIRETYLSG) do if (x = LSG[index0]) then begin // Экономим "стек" литералов (2*a=2*b-2*_c)
                                                                                                                                a:= index0;
                                                                                                                                for index1:= High(LiteralIndexes) downto (0) do if (LiteralIndexes[index1] = index0) then a:= -1 { IF } { FOR }; // Защита от ссылок на те числа, значения которых могут быть переназначены по имени
                                                                                                                                if (a >= 0) then Break
                                                                                                                                end { IF } { FOR };

                                                                   if (a < 0) then begin
                                                                                   Inc(ENTIRETYLSG);
                                                                                   LSG[ENTIRETYLSG]:= x;
                                                                                   a:= ENTIRETYLSG
                                                                                   end { IF };

                                                                   CONTROL(0, 1);
                                                                   addWORD($05DD); // FLD qword ptr [@pcb^.LSG[b]]
                                                                   addDWORD(DWORD(@LSG[a]))
                                                                   end { IF } { IF };
                               Exit
                               end { pcb^ } { IF };     

  o:= GetNamedLiteralIndex(r);
  if (o >= 0) then begin
                   CONTROL(0, 1);
                   addWORD($05DD); // FLD qword ptr [@pcb^.LSG[o]]
                   addDWORD(DWORD(@pcb^.LSG[o]));
                   Exit                  
                   end { IF };

  o:= NEWCONSTORVAR(r, fs);
  //if (r = fs.Functions[nf].FuncName) then o:= -1 { IF }; // Имя функции нам не подходит как переменная в выражении
  if (o >= 0) then begin
                   a:= o*SizeOf(Real);

                   CONTROL(0, 1);
                   addBYTE($DD); // FLD qword ptr [...
                   if (a = 0) then if (r[1] = '_') then addBYTE($00) // ...EAX]
                                                   else addBYTE($02) { IF } // ...EDX]
                              else begin
                                   if (r[1] = '_') then if (a < $80) then addBYTE($40) // ...EAX + ...
                                                                     else addBYTE($80) { IF }
                                                   else if (a < $80) then addBYTE($42) // ...EDX + ...
                                                                     else addBYTE($82) { IF } { IF };
                                   addBYTE(PByte(@a)^); // ...Shortint(a)] или младший байт Integer(a)
                                   if (a > $7F) then begin
                                                     addWORD(PWord(DWORD(@a) + 1)^); // ... 2 и 3 байты Integer(a)]
                                                     addBYTE(PByte(DWORD(@a) + 3)^) // ... 4й байт Integer(a)]
                                                     end { IF } 
                                   end { IF }
                   end
              else Result:= FALSE { IF } // непонятно что => ошибка
              
  end { TRYLOAD };

 begin // Result лежит в фрэйме функции BUILD 
 DeleteExternalBracket(EXPRESION); 
 // FINDTEMPLATE включает кроме всего прочего проверку условия непустоты строки
 if (FINDTEMPLATE(EXPRESION, SUPPORTEDOPERATORS, l, r, o)) then case o of CDIM : TRYLOAD() { CDIM };
                                                                          00 : begin
                                                                               LPARSE(); // FLD l
                                                                               RPARSE(); // FLD r

                                                                               CONTROL(2, 2);
                                                                               addWORD($C1DE) // FADD
                                                                               end { l+r };
                                                                          01 : begin
                                                                               RPARSE() // Просто FLD r
                                                                               end { +r };
                                                                          02 : begin
                                                                               LPARSE(); // FLD l
                                                                               RPARSE(); // FLD r

                                                                               CONTROL(2, 2);
                                                                               addWORD($E9DE) // FSUB
                                                                               end { l-r };
                                                                          03 : begin
                                                                               RPARSE(); // FLD r

                                                                               CONTROL(1, 1);
                                                                               addWORD($E0D9) // FCHS
                                                                               end { -r };
                                                                          04 : begin
                                                                               LPARSE(); // FLD l
                                                                               RPARSE(); // FLD r

                                                                               CONTROL(2, 2);
                                                                               addWORD($C9DE) // FMUL
                                                                               end { l*r };
                                                                          05 : begin
                                                                               LPARSE(); // FLD l
                                                                               RPARSE(); // FLD r

                                                                               CONTROL(2, 2);
                                                                               addWORD($F9DE) // FDIV
                                                                               end { l/r };
                                                                          06 : begin // l^r - алгоритм взят из модуля Math Delphi - функция IntPower, но формируется линейный код, так что r д.б. литералом
                                                                               CONTROL(0, 1);
                                                                               addWORD($E8D9); // FLD1 для (r == 0) и вообще нуна

                                                                               DeleteExternalBracket(r);
                                                                               Val(r, a, index);

                                                                               if (index <> 0) then begin
                                                                                                    Result:= FALSE;    
                                                                                                    Exit
                                                                                                    end { IF };
                                                                                                    
                                                                               LPARSE(); // FLD l - лишняя, если (r = 0), но не лишняя в общем - т.к. нам нужны параметры из этого выражения в ENTIRETYSV, ENTIRETYSC в любом случае

                                                                               if (a = 0) then begin
                                                                                               CONTROL(1, 1, 0);
                                                                                               addWORD($D8DD); // FSTP ST(0) = l, ST(0) == 1.0
                                                                                               Exit
                                                                                               end { IF };
                                                                               // else
                                                                               // index == 0
                                                                               if (a < 0) then a:= -a // a:= Abs(a) (index == 0)
                                                                                          else index:= -1 { IF }; 

                                                                               CONTROL(2, 2, 2);
                                                                               while (a > 0) do begin
                                                                                                while ((a and 1) = 0) do begin // <=> not Odd(a) - even number
                                                                                                                         //CONTROL(1, 1, 1);
                                                                                                                         addWORD($C8DC); // FMUL ST(0), ST 
                                                                                                                         a:= a shr 1
                                                                                                                         end { WHILE };
                                                                                                Dec(a);
                                                                                                //CONTROL(2, 2, 2);
                                                                                                addWORD($C9DC) // FMUL ST(1), ST
                                                                                                end { WHILE };
                                                                               CONTROL(1, 1, 0);
                                                                               addWORD($D8DD); // FSTP ST(0) 
                                                                               if (index = 0) then begin // a < 0
                                                                                                   CONTROL(1, 2);
                                                                                                   addDWORD($F1DEE8D9) // FLD1 FDIVR
                                                                                                   end { IF } // a > 0
                                                                               end { l^r };
                                                                          07 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 1);
                                                                               addWORD($FFD9) // FCOS
                                                                               end { cos(r) };
                                                                          08 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 1);
                                                                               addWORD($FED9) // FSIN
                                                                               end { sin(r) };
                                                                          09 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($EDD9); // FLDLN2

                                                                               RPARSE();

                                                                               CONTROL(2, 2);
                                                                               addWORD($F1D9) // FYL2X  
                                                                               end { ln(r) };
                                                                          10 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 3); // Нужен 1, максимум до ST(2) юзает кольцевой стек
                                                                               addDWORD($C9DEEAD9); // FLDL2E FMUL 
                                                                               addDWORD($FCD9C0D9); // FLD ST FRNDINT
                                                                               addDWORD($E1D8C9D9); // FXCH ST(1) FSUB ST, ST(1)
                                                                               addDWORD($E8D9F0D9); // F2XM1 FLD1
                                                                               addDWORD($FDD9C1DE); // FADD FSCALE 
                                                                               addWORD($D9DD) // FSTP ST(1)
                                                                               end { exp(r) };
                                                                          11 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($ECD9); // FLDLG2

                                                                               RPARSE();

                                                                               CONTROL(2, 2);
                                                                               addWORD($F1D9) // FYL2X  
                                                                               end { lg(r) };
                                                                          12 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 2);
                                                                               addDWORD($D8DDF2D9) // FPTAN FSTP ST(0)  
                                                                               end { tg(r) };
                                                                          13 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 2);
                                                                               addDWORD($F1DEF2D9) // FPTAN FDIVR 
                                                                               end { ctg(r) };
                                                                          14 : begin // Abs(arg) must be less than 2^63
                                                                               RPARSE();

                                                                               CONTROL(1, 2);
                                                                               addDWORD($F3D9E8D9) // FLD1 FPATAN
                                                                               end { arctg(r) };
                                                                          15 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($EDD9); // FLDLN2 (ln(2)) 

                                                                               LPARSE(); // FLD l (l | ln(2))

                                                                               CONTROL(2, 2);
                                                                               addWORD($F1D9); // FYL2X (log(sub(2))(l)*ln(2)) <=> (ln(l))

                                                                               RPARSE(); // FLD r (r | ln(l))

                                                                               CONTROL(2, 3);
                                                                               addDWORD($EAD9C9DE); // FMUL (r*ln(l)) <=> (ln(l^r)) // FLDL2E (log(sub(2))(e) | r*ln(l))
                                                                               addDWORD($C0D9C9DE); // FMUL (r*log(sub(2))(l)) <=> (z) // FLD ST (z | z)
                                                                               addDWORD($C9D9FCD9); // FRNDINT ([z] | z) // FXCH ST(1) (z | [z])
                                                                               addDWORD($F0D9E1D8); // FSUB ST, ST(1) ({z} | [z]) // F2XM1 (2^{z} - 1 | [z])
                                                                               addDWORD($C1DEE8D9); // FLD1 (1 | 2^{z} - 1 | [z]) // FADD (2^{z} | [z])
                                                                               addDWORD($D9DDFDD9)  // FSCALE (2^{z}*2^[z] | [z]) // FSTP ST(1) (2^z) <=> (2^log(sub(2))(l^r)) <=> l^r
                                                                               end { pwr((l)(r)) };
                                                                          16 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 1);
                                                                               addWORD($E1D9) // FABS
                                                                               end { abs(r) };
                                                                          17 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 1);
                                                                               addWORD($C8D8) // FMUL ST, ST(0) 
                                                                               end { sqr(r) };             
                                                                          18 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 1);
                                                                               addWORD($FAD9) // FSQRT
                                                                               end { sqrt(r) };
                                                                          19 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 1);
                                                                               addWORD($FCD9) // FRNDINT  
                                                                               end { round(r) };
                                                                          20 : begin // polynom(x)((y0)...(yi)...(yn))
                                                                               LPARSE(); // FLD x 
                                                                               NEXTPARSE(); // FLD yn // Result x

                                                                               while ((r <> '') and Result) do begin
                                                                                                               CONTROL(2, 2, 2);
                                                                                                               addWORD($C9D8); // FMUL ST, ST(1) // Result*x x

                                                                                                               NEXTPARSE(); // FLD yi // yi Result*x x

                                                                                                               CONTROL(2, 2);
                                                                                                               addWORD($C1DE) // FADD // (upd -> Result) x
                                                                                                               end { WHILE };
                                                                               CONTROL(2, 2);
                                                                               addWORD($D9DD) // FSTP ST(1) // x replased in Result
                                                                               end { polynom(l)(r) }; // Horner's method - украдено в модуле Math (Poly func) - оптимальнее чем мой
                                                                          21 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($E8D9); // FLD1  

                                                                               RPARSE(); // FLD arg

                                                                               CONTROL(2, 2);
                                                                               addWORD($F1D9) // FYL2X  
                                                                               end { log2(r) };
                                                                          22 : begin   
                                                                               CONTROL(0, 1);
                                                                               addWORD($E8D9); // FLD1  

                                                                               RPARSE(); // FLD arg

                                                                               CONTROL(2, 2, 2);
                                                                               addDWORD($E8D9F1D9); // FLD1 // FYL2X

                                                                               LPARSE();

                                                                               CONTROL(3, 3);
                                                                               addDWORD($F9DEF1D9) // FYL2X // FDIV  
                                                                               end { log(l)(r) };
                                                                          23 : begin 
                                                                               RPARSE(); // FLD arg

                                                                               CONTROL(1, 3);
                                                                               addDWORD($C1D9E8D9); // FLD1 // 1, arg // FLD ST(1) // arg, 1, arg 
                                                                               addDWORD($E9DEC8D8); // FMUL ST, ST(0) // arg^2, 1, arg // FSUB // 1 - arg^2, arg
                                                                               addDWORD($F3D9FAD9) // FSQRT // sqrt(1 - arg^2), arg // FPATAN 
                                                                               end { arcsin(r) };
                                                                          24 : begin 
                                                                               RPARSE(); // FLD arg

                                                                               CONTROL(1, 3);
                                                                               addDWORD($C1D9E8D9); // FLD1 // 1, arg // FLD ST(1) // arg, 1, arg
                                                                               addDWORD($E9DEC8D8); // FMUL ST, ST(0) // arg^2, 1, arg // FSUB // 1 - arg^2, arg
                                                                               addDWORD($C9D9FAD9); // FSQRT // sqrt(1 - arg^2), arg // FXCH // arg, sqrt(1 - arg^2)
                                                                               addDWORD($F3D9)  // FPATAN
                                                                               end { arccos(r) };
                                                                          25 : begin
                                                                               RPARSE();

                                                                               CONTROL(1, 1);
                                                                               addWORD($E0D9) // FCHS
                                                                               end { chs(r) };
                                                                          26 : begin // max((x0)...(xi)...(xn))
                                                                               NEXTPARSE(); // FLD xn

                                                                               while ((r <> '') and Result) do begin
                                                                                                               NEXTPARSE(); // FLD xi

                                                                                                               CONTROL(2, 2);
                                                                                                               addDWORD($C1DAF1DB); // FCOMI ST, ST(1) FCMOVB ST, ST(1) // FLAGS меняется
                                                                                                               addWORD($D9DD) // FSTP ST(1)
                                                                                                               end { WHILE } 
                                                                               end { max(r) };
                                                                          27 : begin // min((x0)...(xi)...(xn))
                                                                               NEXTPARSE(); // FLD xn

                                                                               while ((r <> '') and Result) do begin
                                                                                                               NEXTPARSE(); // FLD xi

                                                                                                               CONTROL(2, 2);
                                                                                                               addDWORD($D1DBF1DB); // FCOMI ST, ST(1) FCMOVNBE ST, ST(1) // FLAGS меняется
                                                                                                               addWORD($D9DD) // FSTP ST(1)
                                                                                                               end { WHILE }
                                                                               end { min(r) };
                                                                          28 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($EBD9) // FLDPI
                                                                               end { pi };
                                                                          29 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($EAD9) // FLDL2E
                                                                               end { l2e };
                                                                          30 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($E9D9) // FLDL2T
                                                                               end { l2t };
                                                                          31 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($ECD9) // FLDLG2
                                                                               end { lg2 };
                                                                          32 : begin
                                                                               CONTROL(0, 1);
                                                                               addWORD($EDD9) // FLDLN2
                                                                               end { ln2 };
                                                                          33 : begin // double(r) == r + r = 2.0*r - оч. хорошая штука - не надо умножать
                                                                               RPARSE(); // FLD arg

                                                                               CONTROL(1, 1);
                                                                               addWORD($C0D8) // FADD ST, ST(0)
                                                                               end { double(r) }
                                                                end { CASE }
                                                           else Result:= FALSE { IF }

 end { PARSE };

begin //addWORD($1D8D); // ud2
with fs.Functions[nf] do begin
                         CODE:= nil;

                         addDWORD($0424448B); // mov EAX, [ESP + 4] // в dword ptr [ESP] лежит адрес возврата вроде как
                         addWORD($158B); // mov EDX, ...
                         addDWORD(DWORD(@fs.DSC)); // ...fs.DSC

                         //addWORD($E3DB); // FINIT // Initialize Coprocessor без FNOP/nop и FWAIT/wait // замедляет (в 2-4 раза) скорость расчёта целевой функции

                         Result:= TRUE;
                         STUSE:= 0; // Вначале д.б. нуль
                         PARSE(Expresion);

                         if not (Result) then begin // Синтаксис несооблюдён - функция вовращает 0.0
                                              CODE:= nil;
                                              //addWORD($E3DB); // FINIT
                                              addWORD($EED9) // FLDZ
                                              end { IF };

                         //addBYTE($9B); // FWAIT/wait

                         addBYTE($C2); // retn ... // Near return to calling procedure
                         addWORD($0004); // ...4 // and pop 4 bytes from stack // Те 4 байта - SizeOf(Pointer(DSV)), что по stdcall кладётся на стек


                         EntryPoint:= Pointer(CODE) // ^^... уфф... можно заняться подсчётом человекочасов
                         end { fs.Functions[nf] }

//if (STUSE <> 1) then MessageBox(HWND_DESKTOP, 'bfcompiler.BUILD', 'ERROR', MB_OK or MB_ICONERROR) { IF }

end { BUILD };

INITIALIZATION

FINALIZATION
       
END { BFCOMPILER }.
