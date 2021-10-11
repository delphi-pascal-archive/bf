{ � 2006-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfcompiler;
// ���������� �������������� ��������� (����� ��������� - ��� ������������ ����� FPU)
// � ���������� ���������������-�������� (pi, l2e, l2t, lg2, ln2 � user-defined ����������� ��������� � ��.).
// ��������� ���� ����������� (�������): ������ ������, "���������� �������������� ���������", delphikingdom.ru

INTERFACE

uses Windows, // BOOL/DWORD/PDWORD declaration
     bfatd;

type PCOMPILERBASE = ^TCOMPILERBASE { PCOMPILERBASE };
     TCOMPILERBASE = record
                     LSG : array of Real; // ��������� �� ������ �������� �������� ���������: �������� �� ����������� �� �����������
                     TMP : array of Real; // ��������� �� ������, �������� ��� ����������� ����������, ������� ���������� � ������, ���� ��������� ��� ����������� ���� ���������������
                     ENTIRETYLSG,
                     ENTIRETYTMP : Integer; // ������������ �������� ����� ����
                     // ��������
                     LiteralNames : array of string;
                     LiteralIndexes : array of Integer 
                     end { TCOMPILERBASE };

procedure NEWTASK(pcb : PCOMPILERBASE; LSGSIZE, TMPSIZE : DWORD); // �������� ������ ��� ���� ������ �� ������������ � ������ ��� �������� ���������
//procedure OLDTASK(pcb : PCOMPILERBASE); // ����� �� ��������� (�����)
function BUILD(var fs : _FUNC; nf : DWORD) : BOOL; // ����������� �������, ����������� � ����������� ��������, � ����������� ��� ��������������� � ������
procedure QualifyNamedLiteral(const NAME : string; const VALUE : Real); // ����� ����������� ��������� 

IMPLEMENTATION 
     
var pcb : PCOMPILERBASE; // ������� ������������� ������ - �� ���� ��� ���� ������������� �������

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

procedure QualifyNamedLiteral(const NAME : string; const VALUE : Real); // �������� ����� � ������� ��������� ��� �������� X �������� ��� ������������� �������� � ������ NAME �������� VALUE ��� ��

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

function GetNamedLiteralIndex(const EXPRESION : string) : Integer; // ���������� ������ �������� �������� � ������� ��������� ��� -1 ���� �������� � ����� ������ ������ ������

var index : Integer;

begin
Result:= -1;
with pcb^ do for index:= High(LiteralNames) downto (0) do if (LiteralNames[index] = EXPRESION) then begin
                                                                                                    Result:= LiteralIndexes[index];
                                                                                                    Break
                                                                                                    end { IF } { FOR } { pcb^ }

end { GetNamedLiteralIndex };
                                                                                        // ��������� - ��������������� ���, ����������� ���������� PARSE
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

function NEXTCOEFF(var EXPRESION : string; PREFIX : string = '') : string; // �������� ��������� si � ��������� ��������� prefi �� ������ ���� 'pref0(s0)pref1(s1)pref2(s2)...', ��� ������ prefi ����� ���� ������ ������� (������� ������� - ������ ������ ��� prefi - ������ �����)

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

var STUSE : DWORD; // bottom-stack pointer ST(STUSE) - ����� ������� PARSE ���� ���� ��� ������� ��� ��������, �.�. ������� ��� PARSE

 procedure addBYTE(B : Byte); // ��������� ���� � CODE

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + SizeOf(Byte));
                          CODE[L]:= B
                          end { fs.Functions[nf] }

 end { addBYTE };            

 procedure addWORD(W : Word); // ��������� ����� � CODE. �������� ����� �������... ���� ������ ����, ��� �� �����

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + SizeOf(Word));
                          PWORD(@CODE[L])^:= W
                          end { fs.Functions[nf] }

 end { addWORD }; // FWORD? - 2 times

 procedure addDWORD(D : DWORD); // ��������� ������� ����� � CODE. ����� ������� ������ ������

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + SizeOf(DWORD));
                          PDWORD(@CODE[L])^:= D
                          end { fs.Functions[nf] }

 end { addDWORD };

 (*procedure addQWORD(Q : LONGLONG); // ��������� ����������� ����� � CODE. ����� ������� ������ ������

 var L : Integer;

 begin
 with fs.Functions[nf] do begin
                          L:= Length(CODE);
                          SetLength(CODE, L + 8);
                          PInt64(@CODE[L])^:= Q
                          end { fs.Functions[nf] }

 end { addQWORD }; *)

 procedure PARSE(EXPRESION : string); // ��������� CODE ���������

  {------------------------------------------------------------------------------
  Increment or Decrement Stack Pointer
  Syntax: FINCSTP, FDECSTP
  Description: Increments or decrements the stack-top pointer in the status word.
  No tags or registers are changed, and no data is transferred.
  If the stack pointer is 7, FINCSTP changes it to 0.
  If the stack pointer is 0, FDECSTP changes it to 7.
  -------------------------------------------------------------------------------}

  // �������� ���� �������� �������� �� ������������� � ����� ������ ���� 100 ��� ������������ �� ! ����� ��������(... �� ����� ������� �� �������� ������� FDECSTP � FINCSTP 'no data is transferred'... � ������� �� �������))). ���������� ������ �� � �� �������

  // STPEAK - ���������� ���������, � ������� ���������� ���; STREQUARED - ���������� ���������, ������������ ����� � �����; STABANDONED - ������� ���������� ��������� ����� ����������
  procedure CONTROL(STPEAK, STREQUIRED : DWORD; STABANDONED : DWORD = 1);

  const STSIZE : DWORD = 8; // ������ ����� - ���������� ��� ���� ����������� 80x86

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

  begin // ���������� ������� ��� PARSE ���������� STUSE.
  // ���� ��������� ���� ������������ ��-�� �������� ���� �����, �� ���������� ����� ����� ����� � TMP;
  // ��� ���� ��������� ��������� ��� ������������ ����, �� ���������� ������� ��������� ��������� �� TMP
  if (STREQUIRED + STUSE > STSIZE + STPEAK) then begin // �� ((STUSE + (STREQUIRED - STPEAK)) - STSIZE) ����� ������������ ��-�� �������� ���������� ����
                                                 for index:= (1 + STPEAK) to (STREQUIRED) do addWORD($F6D9) { FOR }; // FDECSTP // ������-������ ���� ((STUSE + (STREQUIRED - STPEAK)) - STSIZE) ��������� ����� �� ����� ������ �� ������� (��������� �� ((((STUSE - STPEAK) + STREQUIRED) - STUSE) ����� � "������" ������� (����� STREQUIRED - STPEAK))
                                                 for index:= (1 + STPEAK + STSIZE) to (STREQUIRED + STUSE) do PUSHONOVERFLOW() { FOR }; // ������� ((STUSE + (STREQUIRED - STPEAK)) - STSIZE) ����� (��������� �� ((((STUSE - STPEAK) + STREQUIRED) - STSIZE) ����� � "��������" �������)
                                                 for index:= (1 + STUSE) to (STSIZE) do addWORD($F7D9) { FOR }; // FINCSTP // ����������� ���� ������ ������� ����� �� ������� �� ����� (��������� �� (((((STUSE - STPEAK) + STREQUIRED) - STUSE) - ((((STUSE - STPEAK) + STREQUIRED) - STSIZE)) ����� � "��������" ������� (����� STSIZE - STUSE))
                                                 STUSE:= STSIZE - (STREQUIRED - STPEAK)
                                                 end { IF };

  if (STPEAK > STUSE) then begin // �������� stack fault // �������� (STPEAK - STUSE) �����
                           for index:= (1 + STUSE) to (STPEAK) do POPONSHORTAGE() { FOR }; // ����������� (STPEAK - STUSE) �����
                           STUSE:= STPEAK 
                           end { IF };

  Inc(STUSE, STABANDONED - STPEAK) // ����� �������� ���� ������� STUSE ������� �����                         

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
  Val(r, x, o); // ���� r - �����, �� x ����� ����� �����, (o = 0), ����� (o <> 0) � (x == 0.0)
  if (o = 0) then with pcb^ do begin
                               if (x = 0.0) then begin 
                                                 CONTROL(0, 1);
                                                 addWORD($EED9) // FLDZ 
                                                 end
                                            else if (x = 1.0) then begin    
                                                                   CONTROL(0, 1); 
                                                                   addWORD($E8D9) // FLD1
                                                                   end
                                                              else begin // �������� >> � LSG
                                                                   a:= -1;

                                                                   for index0:= 0 to (ENTIRETYLSG) do if (x = LSG[index0]) then begin // �������� "����" ��������� (2*a=2*b-2*_c)
                                                                                                                                a:= index0;
                                                                                                                                for index1:= High(LiteralIndexes) downto (0) do if (LiteralIndexes[index1] = index0) then a:= -1 { IF } { FOR }; // ������ �� ������ �� �� �����, �������� ������� ����� ���� ������������� �� �����
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
  //if (r = fs.Functions[nf].FuncName) then o:= -1 { IF }; // ��� ������� ��� �� �������� ��� ���������� � ���������
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
                                   addBYTE(PByte(@a)^); // ...Shortint(a)] ��� ������� ���� Integer(a)
                                   if (a > $7F) then begin
                                                     addWORD(PWord(DWORD(@a) + 1)^); // ... 2 � 3 ����� Integer(a)]
                                                     addBYTE(PByte(DWORD(@a) + 3)^) // ... 4� ���� Integer(a)]
                                                     end { IF } 
                                   end { IF }
                   end
              else Result:= FALSE { IF } // ��������� ��� => ������
              
  end { TRYLOAD };

 begin // Result ����� � ������ ������� BUILD 
 DeleteExternalBracket(EXPRESION); 
 // FINDTEMPLATE �������� ����� ����� ������� �������� ������� ��������� ������
 if (FINDTEMPLATE(EXPRESION, SUPPORTEDOPERATORS, l, r, o)) then case o of CDIM : TRYLOAD() { CDIM };
                                                                          00 : begin
                                                                               LPARSE(); // FLD l
                                                                               RPARSE(); // FLD r

                                                                               CONTROL(2, 2);
                                                                               addWORD($C1DE) // FADD
                                                                               end { l+r };
                                                                          01 : begin
                                                                               RPARSE() // ������ FLD r
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
                                                                          06 : begin // l^r - �������� ���� �� ������ Math Delphi - ������� IntPower, �� ����������� �������� ���, ��� ��� r �.�. ���������
                                                                               CONTROL(0, 1);
                                                                               addWORD($E8D9); // FLD1 ��� (r == 0) � ������ ����

                                                                               DeleteExternalBracket(r);
                                                                               Val(r, a, index);

                                                                               if (index <> 0) then begin
                                                                                                    Result:= FALSE;    
                                                                                                    Exit
                                                                                                    end { IF };
                                                                                                    
                                                                               LPARSE(); // FLD l - ������, ���� (r = 0), �� �� ������ � ����� - �.�. ��� ����� ��������� �� ����� ��������� � ENTIRETYSV, ENTIRETYSC � ����� ������

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

                                                                               CONTROL(1, 3); // ����� 1, �������� �� ST(2) ����� ��������� ����
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
                                                                               end { polynom(l)(r) }; // Horner's method - �������� � ������ Math (Poly func) - ����������� ��� ���
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
                                                                                                               addDWORD($C1DAF1DB); // FCOMI ST, ST(1) FCMOVB ST, ST(1) // FLAGS ��������
                                                                                                               addWORD($D9DD) // FSTP ST(1)
                                                                                                               end { WHILE } 
                                                                               end { max(r) };
                                                                          27 : begin // min((x0)...(xi)...(xn))
                                                                               NEXTPARSE(); // FLD xn

                                                                               while ((r <> '') and Result) do begin
                                                                                                               NEXTPARSE(); // FLD xi

                                                                                                               CONTROL(2, 2);
                                                                                                               addDWORD($D1DBF1DB); // FCOMI ST, ST(1) FCMOVNBE ST, ST(1) // FLAGS ��������
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
                                                                          33 : begin // double(r) == r + r = 2.0*r - ��. ������� ����� - �� ���� ��������
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

                         addDWORD($0424448B); // mov EAX, [ESP + 4] // � dword ptr [ESP] ����� ����� �������� ����� ���
                         addWORD($158B); // mov EDX, ...
                         addDWORD(DWORD(@fs.DSC)); // ...fs.DSC

                         //addWORD($E3DB); // FINIT // Initialize Coprocessor ��� FNOP/nop � FWAIT/wait // ��������� (� 2-4 ����) �������� ������� ������� �������

                         Result:= TRUE;
                         STUSE:= 0; // ������� �.�. ����
                         PARSE(Expresion);

                         if not (Result) then begin // ��������� ���������� - ������� ��������� 0.0
                                              CODE:= nil;
                                              //addWORD($E3DB); // FINIT
                                              addWORD($EED9) // FLDZ
                                              end { IF };

                         //addBYTE($9B); // FWAIT/wait

                         addBYTE($C2); // retn ... // Near return to calling procedure
                         addWORD($0004); // ...4 // and pop 4 bytes from stack // �� 4 ����� - SizeOf(Pointer(DSV)), ��� �� stdcall ������� �� ����


                         EntryPoint:= Pointer(CODE) // ^^... ���... ����� �������� ��������� �������������
                         end { fs.Functions[nf] }

//if (STUSE <> 1) then MessageBox(HWND_DESKTOP, 'bfcompiler.BUILD', 'ERROR', MB_OK or MB_ICONERROR) { IF }

end { BUILD };

INITIALIZATION

FINALIZATION
       
END { BFCOMPILER }.
