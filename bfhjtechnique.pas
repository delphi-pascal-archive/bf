{ � 2006-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfhjtechnique;
// ����� ����-������ � ������������� � ��� ���, � �������������� ���
// ����� �������� �������� �� ������ ����������, � �������������� �����
// ��� ������ ����������, � ������������ ������������� ������ ����������,
// � ������������ ���������� ���������� � �������� ������������
// ������������ ����� ��������, �������� ��������������� � bfatd
// � bfcompiler.
// � �������� ����� ���� ������ ������ � 1 ������, �� �����
// (threadvar ������������ ������ - �����-�����-������-�������).
// �� ����������������� ������� ��������� ��� ��������: ��� ������ ��������
// ������������� � ������������ �������� ������������ ��������, ��� � ������
// ������ ����������� �����������

INTERFACE            

uses Windows,
     bfcompiler,
     bfsysutils,  
     bfatd;

// threadvar???                
var hjd : record // ������ ����� ������ ���������� ��� ������ ������
          // _FUNC
          EntryPoint, // �������������� �������
          w : function(DSV : HGLOBAL) : Real; stdcall; // ���
          nco, // ���������� �������� (_FUNC.ENTIRETYSC + 1)
          dim, // ���������� ���������� (_FUNC.ENTIRETYSV + 1)
          // Method
          pt, // ���������� �����
          vss : DWORD; // private ������ ������� ���������� � ������ ((_FUNC.ENTIRETYSV + 1)*SizeOf(Real))          
          //Discrepancy, // (dim = pt) �������� ������� ������� � ������, ����� ��������� ������� - �������� ������� ������� ��� ���������� ��������� ���������� ��� ����� ������
          Precision, // ���������� �������� ���� (���� ����� ����� <=> (SeparatePrecision = FALSE))
          Divisor, // ����� �������� ����� (������ �����)
          Factor : Real; // private ����� ��������� ����� == 1.0/Divisor
          Result : HGLOBAL; // (dim = pt) �������� ������� � ������
          BPV, // dim = (ESC + 1) Basic Point Vector ������� ����� - ������ ���� ��������� ����� ������������ ���������� ����������; �� ����� ���� �� ����� HGLOBAL, � ���������, �.�. ���������� � ���������� GPTR - get pointer
          UPV, // dim = (ESC + 1) Uncertain Point Vector ����������� �����
          Points : HGLOBAL; // dim = pt*(DSV + 1) �����, ������ �������� �������� ����������
          HEAPV, // �������� ������� Result{, Discrepancy} � ������ �������� ������
          HEAPC : HGLOBAL; // �������� ������� QUALIFY., Steps, MASK
          Steps : HGLOBAL; // dim = (ESC + 1) ��� ������������� �������� ����� ��� ��������� ������ ������� hjt ���������� � _HJDATA.QUALIFY.Step
          MASK : HGLOBAL; // dim = (ESC + 1) ����� ��� ������� ������ �� ������� (1 inc +step) (2 dec -step) (0 skip nop) (4 - locked, �������� ������������)
          QUALIFY : record // ����� ���������� �� ������� ������ ��� ���������:
                    Step, // ������� �������� �����
                    Min, // ����������� ���������� ����� (���������� � ����������� ������ ���� (LimitsPermit = TRUE))
                    Max, // ����������� ���������� ������ (���������� � ����������� ������ ���� (LimitsPermit = TRUE))
                    Precision : HGLOBAL // ����������� �������� ����� �����
                    end { QUALIFY }; // dim = (ESC + 1) ��� �������
          FCC, // ������� ���������� ���������� �������� ������� �������
          TimeOut, // ���������� ������� � [��] ����� ���������� �������� � ������� ������ ������� � ������ �������� ����������� (������������� INFINITE == Cardinal(-1), ����� ����� ���� 49.7 �����)
          ExpendedTime : DWORD; // ����� [��], ����������� �� ������ �� �������� ����������, ����������� ���������� ��� timeout
          CARRIEDOUT : DWORD; // ���� ���������� �������� ����� (� ������������ ������)
          LimitsPermit, // � ������������� ��
          SeparatePrecision, // � ������� �� ��������� �������� ��� ������ ����������
          TerminateHJ : BOOL; // ������������� � TRUE � ��� ��������� ����� - ����� ������ ��������� �����������
          cs : TRTLCriticalSection; // ������ � ����������� ������ ��� ����������� ��������� ���������� ��� ���� �� ��, ����� ������ ������ ����� ������� ������������� ���������� �� ����������
          OFV, // ������ �������� ������� �������
          NFV, // ����� �������� ������� �������
          BFV : Real // �������� ������� ������� � ������� �����
          end = (Precision : 0.0; HEAPV : HGLOBAL(nil); HEAPC : HGLOBAL(nil); TimeOut : INFINITE; TerminateHJ : FALSE) { hjd };

function HookeAndJeevesTechnique() : Integer; // (-1) - ������� (������ ��������), (0) - ����� ���������� ������, (1) - ������� (������� ���������� hjd.TimeOut)
procedure SetExpresion(const expr : string; var fs : _FUNC); // ����� ��������� ����������-������� ����� ��������� � ����������
function SetWeightExpresion(const expr : string; var fs, w : _FUNC) : Integer;
procedure SetTaskDimAndPointsCount(dim, pt : DWORD); // ���������� ���������� �����, �� ������� ����� ������� �����
procedure SetCurrentFunc(var fs, w : _FUNC; wi : Integer); // ����� ������� ���������
function SetVarVector(ni : Integer; const VarVector : array of Real) : Integer; // ����� ���������� ����� ni ����� ������ ��������
procedure FullQualifyConstant(ni : DWORD; const qi : TQUALIFYITEM);  // ������ ��� ������� �������� ���������
procedure QualifyConstantBase(ni : DWORD; const qi : TQUALIFYITEM); // ������ ��� ��������������� ���������� �������� ���������
procedure LockConstant(ni : DWORD; LockIt : BOOL); // ��������� ������������ ���������, ������ ��� ������� ��������� ����������� QualifyNamedLiteral

IMPLEMENTATION

function HookeAndJeevesTechnique() : Integer;

var SurveyFunc : procedure();
    PatternStepFunc : procedure();
    CompareAndDecreaseStepsFunc : procedure();

 function TargetFunction() : Real; stdcall; assembler; // ��������� �������� ������� � ������� ������� � ��������� � �������� � NFV
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
         //FST qword ptr [EDI] // ��������� ������� � ���� �����
         FMUL ST, ST(0) // ^2 - ��������� ������� �������� - ��� ��� � PReal(DSV)^ ������ ���� ����������������� �������� �������
         FMUL // ���� ���� �������� �������
         FADD hjd.NFV 
         add EAX, hjd.vss // SizeOf(packed record _y, _x, _yc : Real end) == 3*8 ��� ���� ������
         //add EDI, 8 // SizeOf(Real)
         add ESI, 8 // SizeOf(Real)
         loop @loop // ��������� � �������������� �������� ���������� ��������� ������� �� ���� ������
 
         //FSTP hjd.NFV // ��������� �������� ������� �������
         inc hjd.FCC // ������� ������������� �� 1
 
         pop EDX
         pop ECX
         pop ESI
         //pop EDI
 
 end { TargetFunction };
 
 procedure Survey(); assembler; // ��������� ���������� ����� UPV, ������ ��� � OFV ��������� �������� ������� ������� � ��� �� �������� �����������

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

 procedure SurveyL(); assembler; // ��������� ���������� ����� UPV, ������ ��� � OFV ��������� �������� ������� ������� � ��� �������� �����������

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
         mov byte ptr [EDX + ECX], 00000000b // 0 - ������ �� ������ 
         jmp @noop
 @save:  FSTP hjd.OFV 
 @noop:  jecxz @end
         jmp @loop 
 @end:    

 end { SurveyL };    

 procedure PatternStep(); assembler; // ��������� ������� �� ����� (����������� ������ � ����������� ������ �� �������), �� �������� �����������
 asm 
         mov EDI, hjd.UPV
         mov ESI, hjd.QUALIFY.Step
         mov EDX, hjd.MASK

         mov ECX, hjd.nco
 @loop:  dec ECX
         test byte ptr [EDX + ECX], 00000001b or 00000010b // 1 or 2
         jz @noop // (4 ��� 0) ������ �� ������
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
 
 procedure PatternStepL(); assembler; // ��������� ������� �� ����� (����������� ������ � ����������� ������ �� �������), �������� �����������
 asm 
         mov EDI, hjd.UPV
         mov ESI, hjd.QUALIFY.Step
         mov EDX, hjd.MASK
         mov EAX, hjd.QUALIFY.Min
         mov EBX, hjd.QUALIFY.Max

         mov ECX, hjd.nco 
 @loop:  dec ECX

         test byte ptr [EDX + ECX], 00000001b or 00000010b // 3 
         jz @noop // ���� �� 1 � �� 2, �� 4 ��� 0 - ������ �� ������ 
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
         FSTP ST // ����� �� ������������ ���� FPU
 @noop:  jecxz @end
         jmp @loop
 @end:         

 end { PatternStepL };   

 procedure CompareAndDecreaseStepsA(); assembler; // ��������� ���� � ���������� � ����������� � �� ����� ������������� ��������� ���� ��� ���� �� ������ = ����������� �� �������� ������
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
         jnbe @next // or equal �������� - ����� ��� Precision == 0.0 ����� ���������� ���������
         dec EDX 
         js @exit
 @next:  dec ECX
         jns @loop
 @exit:  inc ECX // ECX = 0 xor 1 ���� ��� ���� ������ ������������
         FSTP ST 
         FSTP ST

 end { CompareAndDecreaseStepsA };

 procedure CompareAndDecreaseStepsS(); assembler; // ��������� ���� � ���������� � ������������ � �� ����� ������������� ��������� ���� ������ ��� �� ������ = ���������������� ����������� �� �������� ������
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
 @exit:  inc ECX // ECX = 0 xor 1 ���� ��� ���� ������ �����������
         FSTP ST

 end { CompareAndDecreaseStepsS };
  
 procedure CopyBP2UP(); assembler; // �������� ������� ����� � �����������
 asm        
         mov ESI, hjd.BPV
         mov EDI, hjd.UPV
         mov ECX, hjd.nco 
         shl ECX, 1 // *2
         cld // ++
 @loop:  mov EAX, [ESI]
         stosd  
         add ESI, 4 // (SizeOf(Real) div 2), �.�. store string ��� QWORD ��� 
         loop @loop  

 end { CopyBP2UP };

 procedure CopyUP2BP(); assembler; // �������� ����������� ����� � ������� 
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

 procedure UpdateSteps(); assembler; // ��������� �������� ����� � ������� ��������� Factor
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
        jne @end // ������� ��� ������������� ���������� ���������� ������ Result == -1 

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
        mov hjd.vss, EAX // ������������� ��������

        call TargetFunction // ��������� � ��������� �����
        //FLD hjd.NFV
        FST hjd.BFV
        FSTP hjd.OFV // ��� ����� �-� �����
        call CopyUP2BP // ���������������� ��� �������
        // ������� ����� ���������
        mov hjd.CARRIEDOUT, 0
        jmp @gogo // BP to UP ��� ���������� �� ���� � OFV ��� �������� ������ ��������, ������� �� � @start

@decs:  FSTP ST
        lea EAX, hjd.&cs // mov EAX, OFFSET hjd.&cs
        push EAX
        push EAX
        call LeaveCriticalSection
        // ��� �������������� ��� �� �� �� ������ ������ ������ ��� �������� 
        call EnterCriticalSection
        
        call GetTickCount // ������� 60 ������ �������� �� ����� ���� ������� - �������� ����
        sub EAX, hjd.ExpendedTime
        cmp EAX, hjd.TimeOut 
        ja @tout // Result == 1
                        
        cmp hjd.TerminateHJ, FALSE
        jne @end // ������� ��� ������������� ���������� ���������� ������ Result == -1         

        cmp hjd.CARRIEDOUT, 0
        jne @succ
        call CompareAndDecreaseStepsFunc // ��������� ���� � Divisor ���
        mov hjd.CARRIEDOUT, ECX 

@start: FLD hjd.BFV
        FSTP hjd.OFV // ��������� �������� ������� ������� � ������� ����� ��� ������������ � � ����������
        call CopyBP2UP // ������� ����� ������������ ��� ������������
@gogo:  call SurveyFunc // ��������� ����������� �����
        FLD hjd.OFV
        FCOM hjd.BFV
        FNSTSW AX
        sahf
        jnb @decs // ���� ������ ��������� ���, �� jmp 

@ptrn:  FSTP hjd.BFV // ����� ���� <-- OFV xor NFV
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

        call PatternStepFunc // ������ ��� ������ �� �������
        call TargetFunction // "���������" � ����� �����
        //FLD hjd.NFV
        FCOM hjd.BFV
        FNSTSW AX
        sahf 
        jb @ptrn // ����������� � ����������������� �������� � ����� 
        FSTP ST
        jmp @start // ����������� � ����������������� �� �������� �����

@tout:  mov Result, 1 // TimeOut
        jmp @end
@succ:  mov Result, 0 // ������� ����������

@end:   push OFFSET hjd.&cs
        call LeaveCriticalSection

        call GetTickCount
        sub EAX, hjd.ExpendedTime
        mov hjd.ExpendedTime, EAX

        popad

end { HookeAndJeevesTechnique };  

// ������� � �������� 0 - ��������, ��������� �������� ��������� �� ���������� �� ����������� ��������� � ���������� 
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
GetMemory(hjd.HEAPV, LRV*(1 + hjd.dim)); // LRV*(2 + hjd.dim) ���� Discrepancy ����
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

(*// ��� ���������� ��������
procedure MainQualifyConstant(ni : DWORD; const Base, Step, Prec : Real); // hjd.Divisor ������ ���� ��� ��������

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

procedure FullQualifyConstant(ni : DWORD; const qi : TQUALIFYITEM); // hjd.Divisor ������ ���� ��� ��������

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
