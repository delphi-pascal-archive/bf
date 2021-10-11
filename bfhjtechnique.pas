{ © 2006-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfhjtechnique;
// Метод Хука-Дживса с ограничениями и без них, с индивидуальным или
// общим пределом точности по каждой переменной, с индивидуальным шагом
// для каждой переменной, с возможностью заблокировать каждую переменную,
// с возможностью досрочного завершения и контроля непревышения
// длительности одной итерации, привязан нипосредственно к bfatd
// и bfcompiler.
// В процессе может быть вызван только в 1 потоке, не более
// (threadvar использовать сложно - потом-когда-нибудь-никогда).
// На многопроцессорных машинах возникает две проблемы: так просто механизм
// синхронизации с критическими секциями отказывается работать, код в секции
// данных некорректно исполняется

INTERFACE            

uses Windows,
     bfcompiler,
     bfsysutils,  
     bfatd;

// threadvar???                
var hjd : record // Просто набор всяких переменных для работы метода
          // _FUNC
          EntryPoint, // Оптимизируемая функция
          w : function(DSV : HGLOBAL) : Real; stdcall; // Вес
          nco, // Количество констант (_FUNC.ENTIRETYSC + 1)
          dim, // Количество переменных (_FUNC.ENTIRETYSV + 1)
          // Method
          pt, // Количество точек
          vss : DWORD; // private Размер вектора переменных в байтах ((_FUNC.ENTIRETYSV + 1)*SizeOf(Real))          
          //Discrepancy, // (dim = pt) Значения невязок функции в точках, сумма квадратов которых - значение целевой функции при конкретных значениях параметров для нашей задачи
          Precision, // Предельное значение шага (если задан общий <=> (SeparatePrecision = FALSE))
          Divisor, // Общий делитель шагов (всегда общий)
          Factor : Real; // private Общий множитель шагов == 1.0/Divisor
          Result : HGLOBAL; // (dim = pt) Значения функции в точках
          BPV, // dim = (ESC + 1) Basic Point Vector Базовая точка - должна быть заполнена перед вычислениями начальными значениями; на самом деле не хэндл HGLOBAL, а указатель, т.к. вызывается с параметром GPTR - get pointer
          UPV, // dim = (ESC + 1) Uncertain Point Vector Исследуемая точка
          Points : HGLOBAL; // dim = pt*(DSV + 1) Точки, массив векторов значений переменных
          HEAPV, // Содержит массивы Result{, Discrepancy} и массив векторов данных
          HEAPC : HGLOBAL; // Содержит массивы QUALIFY., Steps, MASK
          Steps : HGLOBAL; // dim = (ESC + 1) Для инициализации значений шагов при очередном старте функции hjt копируются в _HJDATA.QUALIFY.Step
          MASK : HGLOBAL; // dim = (ESC + 1) Маска для вектора поиска по образцу (1 inc +step) (2 dec -step) (0 skip nop) (4 - locked, параметр игнорируется)
          QUALIFY : record // Набор указателей на участки памяти где находятся:
                    Step, // Текущие значения шагов
                    Min, // Ограничения параметров снизу (существует и учитывается только если (LimitsPermit = TRUE))
                    Max, // Ограничения параметров сверху (существует и учитывается только если (LimitsPermit = TRUE))
                    Precision : HGLOBAL // Ограничение величины шагов снизу
                    end { QUALIFY }; // dim = (ESC + 1) все массивы
          FCC, // Счётчик количества вычислений значения целевой функции
          TimeOut, // Промежуток времени в [мс] после прошествия которого с момента старта функции её работа досрочно прерывается (устанавливаем INFINITE == Cardinal(-1), чтобы время было 49.7 суток)
          ExpendedTime : DWORD; // Время [мс], затраченное на расчёт до удачного завершения, нормального прерывания или timeout
          CARRIEDOUT : DWORD; // Флаг последнего внешнего цикла (с минимальными шагами)
          LimitsPermit, // С ограничениями ли
          SeparatePrecision, // С разными ли пределами точности для каждой переменной
          TerminateHJ : BOOL; // Устанавливаем в TRUE и ждём некоторое время - метод должен корректно завершиться
          cs : TRTLCriticalSection; // Входит в критическую секцию при вычислениях постоянно прерываясь при этом на то, чтобы другие потоки могли считать промежуточные результаты по надобности
          OFV, // Старое значение целевой функции
          NFV, // Новое значение целевой функции
          BFV : Real // Значение целевой функции в базовой точке
          end = (Precision : 0.0; HEAPV : HGLOBAL(nil); HEAPC : HGLOBAL(nil); TimeOut : INFINITE; TerminateHJ : FALSE) { hjd };

function HookeAndJeevesTechnique() : Integer; // (-1) - неудача (работа прервана), (0) - поиск завершился удачей, (1) - таймаут (задаётся переменной hjd.TimeOut)
procedure SetExpresion(const expr : string; var fs : _FUNC); // Задаёт выражение переменной-функции через константы и переменную
function SetWeightExpresion(const expr : string; var fs, w : _FUNC) : Integer;
procedure SetTaskDimAndPointsCount(dim, pt : DWORD); // Определяет количество точек, на которых будет вестись поиск
procedure SetCurrentFunc(var fs, w : _FUNC; wi : Integer); // Задаёт текущую структуру
function SetVarVector(ni : Integer; const VarVector : array of Real) : Integer; // Задаёт переменной номер ni такой вектор значений
procedure FullQualifyConstant(ni : DWORD; const qi : TQUALIFYITEM);  // Служит для полного описания константы
procedure QualifyConstantBase(ni : DWORD; const qi : TQUALIFYITEM); // Служит для переопределения начального значения константы
procedure LockConstant(ni : DWORD; LockIt : BOOL); // Назначает блокирование константе, теперь она подобна константе определённой QualifyNamedLiteral

IMPLEMENTATION

function HookeAndJeevesTechnique() : Integer;

var SurveyFunc : procedure();
    PatternStepFunc : procedure();
    CompareAndDecreaseStepsFunc : procedure();

 function TargetFunction() : Real; stdcall; assembler; // Вычисляет значения невязок и целевую функцию и сохраняет её значение в NFV
 asm 
         //push EDI
         push ESI
         push ECX
         push EDX
 
         mov EAX, hjd.Points
         //mov EDI, hjd.Discrepancy
         mov ESI, hjd.Result
  
         FLDZ // <=> hjd.NFV:= 0.0
 
         mov ECX, hjd.pt 
 @loop:  FSTP hjd.NFV
         push EAX // EntryPoint(>>>DSV<<<)
         call hjd.EntryPoint
         FST qword ptr [ESI] // -> Result
         FSTP qword ptr [EAX + 16] // _yc
         push EAX
         call hjd.w 
         FLD qword ptr [EAX] // PReal(DSV)^ == intensity
         FSUB qword ptr [EAX + 16] // - _yc
         //FST qword ptr [EDI] // Сохраняем невязку в этой точке
         FMUL ST, ST(0) // ^2 - считается квадрат разности - так что в PReal(DSV)^ должно быть экспериментальное значение функции
         FMUL // Учёт веса квадрата невязки
         FADD hjd.NFV 
         add EAX, hjd.vss // SizeOf(packed record _y, _x, _yc : Real end) == 3*8 для этой задачи
         //add EDI, 8 // SizeOf(Real)
         add ESI, 8 // SizeOf(Real)
         loop @loop // Вычислены и просуммированы значения взвешенных квадратов невязок во всех точках
 
         //FSTP hjd.NFV // Вычислено значение целевой функции
         inc hjd.FCC // Счётчик увеличивается на 1
 
         pop EDX
         pop ECX
         pop ESI
         //pop EDI
 
 end { TargetFunction };
 
 procedure Survey(); assembler; // Исследует окресность точки UPV, считая что в OFV сохранено значение целевой функции в ней не учитывая ограничения

 var RTEMP : Real;

 asm  
         mov EDI, hjd.UPV
         mov ESI, hjd.QUALIFY.Step
         mov EDX, hjd.MASK

         mov ECX, hjd.nco 
 @loop:  dec ECX

         test byte ptr [EDX + ECX], 00000100b // 4
         jnz @noop

         FLD qword ptr [EDI + ECX*8]
         FST RTEMP
         FADD qword ptr [ESI + ECX*8] // +
         FSTP qword ptr [EDI + ECX*8]   
         mov byte ptr [EDX + ECX], 00000001b // 1

         call TargetFunction
         //FLD hjd.NFV
         FCOM hjd.OFV
         FNSTSW AX
         sahf
         jb @save

         FSTP ST
         FLD RTEMP
         FSUB qword ptr [ESI + ECX*8] // -
         FSTP qword ptr [EDI + ECX*8]
         mov byte ptr [EDX + ECX], 00000010b // 2

         call TargetFunction
         //FLD hjd.NFV
         FCOM hjd.OFV         
         FNSTSW AX
         sahf 
         jb @save  

         FSTP ST
         FLD RTEMP
         FSTP qword ptr [EDI + ECX*8] 
         mov byte ptr [EDX + ECX], 00000000b // 0

         jmp @noop
 @save:  FSTP hjd.OFV    
 @noop:  jecxz @end
         jmp @loop
 @end:

 end { Survey };

 procedure SurveyL(); assembler; // Исследует окресность точки UPV, считая что в OFV сохранено значение целевой функции в ней учитывая ограничения

 var RTEMP : Real;

 asm 
         mov EDI, hjd.UPV
         mov ESI, hjd.QUALIFY.Step
         mov EDX, hjd.MASK
         mov EAX, hjd.QUALIFY.Min
         mov EBX, hjd.QUALIFY.Max

         mov ECX, hjd.nco 
 @loop:  dec ECX

         test byte ptr [EDX + ECX], 00000100b // 4
         jnz @noop

         FLD qword ptr [EDI + ECX*8]
         FST RTEMP
         FADD qword ptr [ESI + ECX*8] // + 
         FCOM qword ptr [EBX + ECX*8]
         push EAX
         FNSTSW AX
         sahf
         pop EAX
         ja @sub
         FSTP qword ptr [EDI + ECX*8]
         mov byte ptr [EDX + ECX], 00000001b // 1

         push EAX
         call TargetFunction
         //FLD hjd.NFV
         FCOM hjd.OFV 
         FNSTSW AX
         sahf
         pop EAX
         jb @save 

 @sub:   FSTP ST
         FLD RTEMP
         FSUB qword ptr [ESI + ECX*8] // -     
         FCOM qword ptr [EAX + ECX*8]
         push EAX
         FNSTSW AX
         sahf
         pop EAX
         jbe @null 
         FSTP qword ptr [EDI + ECX*8]  
         mov byte ptr [EDX + ECX], 00000010b // 2

         push EAX
         call TargetFunction
         //FLD hjd.NFV
         FCOM hjd.OFV
         FNSTSW AX
         sahf
         pop EAX
         jb @save

 @null:  FSTP ST
         FLD RTEMP
         FSTP qword ptr [EDI + ECX*8]
         mov byte ptr [EDX + ECX], 00000000b // 0 - ничего не делаем 
         jmp @noop
 @save:  FSTP hjd.OFV 
 @noop:  jecxz @end
         jmp @loop 
 @end:    

 end { SurveyL };    

 procedure PatternStep(); assembler; // Суммирует векторы по маске (приращивает вектор в направлении поиска по образцу), не учитывая ограничения
 asm 
         mov EDI, hjd.UPV
         mov ESI, hjd.QUALIFY.Step
         mov EDX, hjd.MASK

         mov ECX, hjd.nco
 @loop:  dec ECX
         test byte ptr [EDX + ECX], 00000001b or 00000010b // 1 or 2
         jz @noop // (4 или 0) ничего не делаем
         FLD qword ptr [EDI + ECX*8]
         test byte ptr [EDX + ECX], 00000001b // 1       
         jz @sub
         FADD qword ptr [ESI + ECX*8]
         jmp @store
 @sub:   FSUB qword ptr [ESI + ECX*8] // 00000010b = 2
 @store: FSTP qword ptr [EDI + ECX*8]
 @noop:  jecxz @end
         jmp @loop
 @end:                 

 end { PatternStep };
 
 procedure PatternStepL(); assembler; // Суммирует векторы по маске (приращивает вектор в направлении поиска по образцу), учитывая ограничения
 asm 
         mov EDI, hjd.UPV
         mov ESI, hjd.QUALIFY.Step
         mov EDX, hjd.MASK
         mov EAX, hjd.QUALIFY.Min
         mov EBX, hjd.QUALIFY.Max

         mov ECX, hjd.nco 
 @loop:  dec ECX

         test byte ptr [EDX + ECX], 00000001b or 00000010b // 3 
         jz @noop // если не 1 и не 2, то 4 или 0 - ничего не делаем 
         FLD qword ptr [EDI + ECX*8]
         FLD ST
         test byte ptr [EDX + ECX], 00000001b // 1 
         jz @sub
         FADD qword ptr [ESI + ECX*8]
         jmp @test
 @sub:   FSUB qword ptr [ESI + ECX*8] // 00000010b = 2
 @test:  FLD qword ptr [EAX + ECX*8]
         db 0DFh, 0F1h // FCOMIP ST, ST(1)
         jae @xchng
         FLD qword ptr [EBX + ECX*8]
         db 0DFh, 0F1h // FCOMIP ST, ST(1) 
         jae @store
 @xchng: FXCH
 @store: FSTP qword ptr [EDI + ECX*8]
         FSTP ST // чтобы не переполнялся стек FPU
 @noop:  jecxz @end
         jmp @loop
 @end:         

 end { PatternStepL };   

 procedure CompareAndDecreaseStepsA(); assembler; // Уменьшает шаги и сравнивает с минимальным и не выдаёт положительный результат пока все шаги не станут = ограничению на точность поиска
 asm 
         FLD hjd.Precision
         FLD hjd.Factor

         mov ESI, hjd.QUALIFY.Step       
         mov ECX, hjd.nco 
         dec ECX
         mov EDX, ECX
 @loop:  FLD qword ptr [ESI + ECX*8]
         FMUL ST, ST(1)
         db 0DBh, 0F2h // FCOMI ST, ST(2)
         db 0DAh, 0C2h // FCMOVB ST, ST(2)  
         FSTP qword ptr [ESI + ECX*8]
         jnbe @next // or equal включено - чтобы при Precision == 0.0 метод завершался корректно
         dec EDX 
         js @exit
 @next:  dec ECX
         jns @loop
 @exit:  inc ECX // ECX = 0 xor 1 если все шаги меньше минимального
         FSTP ST 
         FSTP ST

 end { CompareAndDecreaseStepsA };

 procedure CompareAndDecreaseStepsS(); assembler; // Уменьшает шаги и сравнивает с минимальными и не выдаёт положительный результат пока каждый шаг не станет = соответственному ограничению на точность поиска
 asm 
         FLD hjd.Factor

         mov EDI, hjd.QUALIFY.Precision 
         mov ESI, hjd.QUALIFY.Step
         mov ECX, hjd.nco 
         dec ECX
         mov EDX, ECX
 @loop:  FLD qword ptr [EDI + ECX*8]
         FLD qword ptr [ESI + ECX*8]
         FMUL ST, ST(2)
         db 0DBh, 0F1h // FCOMI ST, ST(1)
         db 0DAh, 0C1h // FCMOVB ST, ST(1)  
         FSTP qword ptr [ESI + ECX*8]
         FSTP ST
         jnbe @next 
         dec EDX 
         js @exit
 @next:  dec ECX
         jns @loop
 @exit:  inc ECX // ECX = 0 xor 1 если все шаги меньше минимальных
         FSTP ST

 end { CompareAndDecreaseStepsS };
  
 procedure CopyBP2UP(); assembler; // Копирует базовую точку в исследуемую
 asm        
         mov ESI, hjd.BPV
         mov EDI, hjd.UPV
         mov ECX, hjd.nco 
         shl ECX, 1 // *2
         cld // ++
 @loop:  mov EAX, [ESI]
         stosd  
         add ESI, 4 // (SizeOf(Real) div 2), т.к. store string для QWORD нет 
         loop @loop  

 end { CopyBP2UP };

 procedure CopyUP2BP(); assembler; // Копирует исследуемую точку в базовую 
 asm
         mov ESI, hjd.UPV
         mov EDI, hjd.BPV
         mov ECX, hjd.nco 
         shl ECX, 1  
         cld  
 @loop:  mov EAX, [ESI]
         stosd
         add ESI, 4 
         loop @loop 

 end { CopyUP2BP };

 procedure UpdateSteps(); assembler; // Обновляет значения шагов и считает множитель Factor
 asm  
         mov ESI, hjd.Steps
         mov EDI, hjd.QUALIFY.Step
         mov ECX, hjd.nco
         shl ECX, 1 // *2
         cld // ++
 @loop:  mov EAX, [ESI]
         stosd
         add ESI, 4
         loop @loop 

 end { UpdateSteps };

asm      
        pushad

        call GetTickCount
        mov hjd.ExpendedTime, EAX    

        push OFFSET hjd.&cs 
        call EnterCriticalSection

        mov Result, -1    

        cmp hjd.TerminateHJ, FALSE
        jne @end // Выходим при необходимости досрочного завершения поиска Result == -1 

        mov SurveyFunc, OFFSET Survey
        mov PatternStepFunc, OFFSET PatternStep
        cmp hjd.LimitsPermit, FALSE
        je @nlp                  
        mov SurveyFunc, OFFSET SurveyL
        mov PatternStepFunc, OFFSET PatternStepL
@nlp:
        mov CompareAndDecreaseStepsFunc, OFFSET CompareAndDecreaseStepsA
        cmp hjd.SeparatePrecision, FALSE
        je @nsp
        mov CompareAndDecreaseStepsFunc, OFFSET CompareAndDecreaseStepsS
@nsp:         
        FNINIT
        FLD1
        FDIV hjd.Divisor
        FSTP hjd.Factor
        
        call UpdateSteps
        mov hjd.FCC, 0 // Function's call counter
        mov EAX, hjd.dim
        shl EAX, 3
        mov hjd.vss, EAX // Приготовления окончены

        call TargetFunction // Вычисляем в стартовой точке
        //FLD hjd.NFV
        FST hjd.BFV
        FSTP hjd.OFV // Все равны м-у собой
        call CopyUP2BP // Инициализированы оба массива
        // Главная часть алгоритма
        mov hjd.CARRIEDOUT, 0
        jmp @gogo // BP to UP нам копировать не надо и OFV уже содержит нужное значение, поэтому не в @start

@decs:  FSTP ST
        lea EAX, hjd.&cs // mov EAX, OFFSET hjd.&cs
        push EAX
        push EAX
        call LeaveCriticalSection
        // Тут переписываются кем то не из нашего потока нужные ему значения 
        call EnterCriticalSection
        
        call GetTickCount // порядка 60 тактов тратится на вызов этой функции - довольно мало
        sub EAX, hjd.ExpendedTime
        cmp EAX, hjd.TimeOut 
        ja @tout // Result == 1
                        
        cmp hjd.TerminateHJ, FALSE
        jne @end // Выходим при необходимости досрочного завершения поиска Result == -1         

        cmp hjd.CARRIEDOUT, 0
        jne @succ
        call CompareAndDecreaseStepsFunc // Уменьшаем шаги в Divisor раз
        mov hjd.CARRIEDOUT, ECX 

@start: FLD hjd.BFV
        FSTP hjd.OFV // Сохраняем значение целевой функции в базовой точке для исследования в её окресности
        call CopyBP2UP // Базовая точка приготовлена для исследований
@gogo:  call SurveyFunc // Исследуем окрестности точки
        FLD hjd.OFV
        FCOM hjd.BFV
        FNSTSW AX
        sahf
        jnb @decs // Если общего улучшения нет, то jmp 

@ptrn:  FSTP hjd.BFV // Новая база <-- OFV xor NFV
        call CopyUP2BP

        lea EAX, hjd.&cs
        push EAX
        push EAX
        call LeaveCriticalSection 
        call EnterCriticalSection    

        call GetTickCount 
        sub EAX, hjd.ExpendedTime
        cmp EAX, hjd.TimeOut 
        ja @tout 

        cmp hjd.TerminateHJ, FALSE
        jne @end          

        call PatternStepFunc // Делаем шаг поиска по образцу
        call TargetFunction // "Исследуем" в новой точке
        //FLD hjd.NFV
        FCOM hjd.BFV
        FNSTSW AX
        sahf 
        jb @ptrn // Направление в гиперпространстве подходит и далее 
        FSTP ST
        jmp @start // Направление в гиперпространстве не подходит далее

@tout:  mov Result, 1 // TimeOut
        jmp @end
@succ:  mov Result, 0 // Удачное завершение

@end:   push OFFSET hjd.&cs
        call LeaveCriticalSection

        call GetTickCount
        sub EAX, hjd.ExpendedTime
        mov hjd.ExpendedTime, EAX

        popad

end { HookeAndJeevesTechnique };  

// Функция с индексом 0 - основная, остальные являются функциями от параметров из подмножеств множества её параметров 
procedure SetExpresion(const expr : string; var fs : _FUNC);

var index : Integer;

begin
index:= Length(fs.Functions);
if (index = 0) then begin
                    FIRSTFUNCTION(fs);
                    NEWCONSTORVAR('_y', fs);
                    NEWCONSTORVAR('_x', fs);
                    NEWCONSTORVAR('_yc', fs)
                    end
               else index:= NEXTFUNCTION(fs) { IF };

fs.Functions[index].Expresion:= expr;
BUILD(fs, index)

end { SetExpresion };

function SetWeightExpresion(const expr : string; var fs, w : _FUNC) : Integer;

var index : Integer;

 procedure CopyBase();

 var index : Integer;

 begin
 SetLength(w.Variables, fs.ENTIRETYSV + 1);
 for index:= 0 to (fs.ENTIRETYSV) do w.Variables[index]:= fs.Variables[index] { FOR };
 SetLength(w.Constants, fs.ENTIRETYSC + 1);
 for index:= 0 to (fs.ENTIRETYSC) do w.Constants[index]:= fs.Constants[index] { FOR };
 w.ENTIRETYSV:= fs.ENTIRETYSV;
 w.ENTIRETYSC:= fs.ENTIRETYSC

 end { CopyBase };

begin
Result:= Length(w.Functions);
if (Result = 0) then begin
                     FIRSTFUNCTION(w);
                     CopyBase()
                     end
                else Result:= NEXTFUNCTION(w) { IF }; 

w.Functions[Result].Expresion:= expr;
BUILD(w, Result);

if ((w.ENTIRETYSV <> fs.ENTIRETYSV) or (w.ENTIRETYSC <> fs.ENTIRETYSC)) then begin
                                                                             SetLength(w.Functions, Result);
                                                                             Dec(Result);
                                                                             CopyBase()
                                                                             end { IF }

end { SetWeightExpresion };

procedure GetMemory(var p : HGLOBAL; Size : DWORD);
begin                            
if (p <> 0) then if (GlobalFlags(p) = GMEM_FIXED) then if (GlobalSize(p) = Size) then Exit
                                                                                 else GlobalFree(p) { IF } { IF } { IF };
p:= GlobalAlloc(GPTR, Size)

end { GetMemory };

procedure SetCurrentFunc(var fs, w : _FUNC; wi : Integer);

var LRC : DWORD;

begin
hjd.nco:= fs.ENTIRETYSC + 1;
hjd.EntryPoint:= fs.Functions[0].EntryPoint;
hjd.w:= w.Functions[wi].EntryPoint;

if (hjd.LimitsPermit) then LRC:= 57 // 57 = 5*8 + 2*8 + 1*1
                      else LRC:= 41 { IF }; // 41 = 5*8 + 1*1
GetMemory(hjd.HEAPC, hjd.nco*LRC);
LRC:= hjd.nco shl 3;

hjd.UPV:= hjd.HEAPC;
hjd.BPV:= hjd.UPV + LRC;
hjd.Steps:= hjd.BPV + LRC;
hjd.QUALIFY.Step:= hjd.Steps + LRC;
hjd.QUALIFY.Precision:= hjd.QUALIFY.Step + LRC;
hjd.MASK:= hjd.QUALIFY.Precision + LRC;
if (hjd.LimitsPermit) then begin
                           hjd.QUALIFY.Min:= hjd.MASK + hjd.nco;
                           hjd.QUALIFY.Max:= hjd.QUALIFY.Min + LRC
                           end { IF };

fs.DSC:= hjd.UPV;
w.DSC:= hjd.UPV

{var xxx : packed record
                 a,b,c : Real
                 end = (c : 2);
;Writeln(hjd.w(HGLOBAL(@xxx)));}

end { SetCurrentFunc };   

procedure SetTaskDimAndPointsCount(dim, pt : DWORD);

var LRV : DWORD;

begin
hjd.dim:= dim; 
hjd.pt:= pt;
LRV:= hjd.pt shl 3;            
GetMemory(hjd.HEAPV, LRV*(1 + hjd.dim)); // LRV*(2 + hjd.dim) если Discrepancy есть
hjd.Result:= hjd.HEAPV;
//hjd.Discrepancy:= hjd.Result + LRV;
//hjd.Points:= hjd.Discrepancy + LRV
hjd.Points:= hjd.Result + LRV

end { SetTaskDimAndPointsCount }; 

function SetVarVector(ni : Integer; const VarVector : array of Real) : Integer; 
begin          
for Result:= 0 to (High(VarVector)) do PReal(hjd.Points + DWORD((Result*hjd.dim + ni) shl 3))^:= VarVector[Result] { FOR };
Result:= High(VarVector) + 1

end { SetVarVector };

(*// Для отключеных пределов
procedure MainQualifyConstant(ni : DWORD; const Base, Step, Prec : Real); // hjd.Divisor должен быть уже определён

var OFFSET : DWORD;

begin
//if (ni < 0) then Exit { IF };
OFFSET:= (ni shl 3);
with hjd do begin
            PReal(UPV + OFFSET)^:= Base; 
            PReal(Steps + OFFSET)^:= Step;
            PReal(QUALIFY.Precision + OFFSET)^:= Prec
            end { hjd }

end { MainQualifyConstant };*)

procedure FullQualifyConstant(ni : DWORD; const qi : TQUALIFYITEM); // hjd.Divisor должен быть уже определён

var OFFSET : DWORD;

begin
//if (ni < 0) then Exit { IF };
OFFSET:= (ni shl 3);
with hjd do begin
            PReal(UPV + OFFSET)^:= qi.Value;
            PReal(QUALIFY.Min + OFFSET)^:= qi.Min;
            PReal(Steps + OFFSET)^:= qi.Step;
            PReal(QUALIFY.Max + OFFSET)^:= qi.Max;
            PReal(QUALIFY.Precision + OFFSET)^:= qi.Precision;
            if (qi.Locked) then PByte(hjd.MASK + ni)^:= 1 shl 2 // db 0000000100b
                           else PByte(hjd.MASK + ni)^:= 0 { IF } 
            end { hjd }

end { FullQualifyConstant };

procedure QualifyConstantBase(ni : DWORD; const qi : TQUALIFYITEM);
begin                
PReal(hjd.UPV + (ni shl 3))^:= qi.Value

end { QualifyConstantBase };

procedure LockConstant(ni : DWORD; LockIt : BOOL);
begin
if (LockIt) then PByte(hjd.MASK + ni)^:= 1 shl 2 // db 0000000100b
            else PByte(hjd.MASK + ni)^:= 0 { IF }

end { LockConstant }; 
    
INITIALIZATION  

//InitializeCriticalSection(hjd.cs)
InitializeCriticalSectionAndSpinCount(hjd.cs, 3)

FINALIZATION     

GlobalFree(hjd.HEAPC);
GlobalFree(hjd.HEAPV); 

DeleteCriticalSection(hjd.cs)

END { BFHJTECHNIQUE }.  

//
(*
var startcode, endcode : DWORD;
    index : Integer;

asm
        jmp @endc
@code:  mov EAX, index
@endc:  mov startcode, OFFSET @code
        mov endcode, OFFSET @endc - 1
end;

for index:= startcode to (endcode) do Writeln(PByte(index)^:3, ':', index - startcode + 1, '/', endcode - startcode + 1) { FOR };

Readln;
Halt;                                        
//*)
