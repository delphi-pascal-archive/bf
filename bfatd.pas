{ � 2007-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfatd;
// ����������� ���� ������ � ��������� ���������� ��� ���� ��� ����������� � ���
// ������ � ���������� ������ ���������� ����������� ���� ������� ������� ����-������.
// � ������������ ������ bfatd, bfcompiler, bfhjtechnique �������� ��� �� engine
// ��� ������� ��������� ��������� ����� ����������� �������������������� �������
// ������ ����������, � ���������, ������ ����������� ����� ��������� ������� ���
// ������ ���������� ��������� (������� TargetFunction �� ����� ���� �������
// ������ ����� ��������� ��������� �������, �� �������� ���������� �� ����� ������
// ������ (������� �������), ������� ����� ���� ��������� ����� (�������� =) ))

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

type TMATRIX = array of array of Real; // dim = 2*2 � ������ - ������ ����������, [v, h] == [������ - 1, ������� - 1] - ������ ���������� �� ������

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

type DIAGRAM = record // ������ ������ � �������� ��� ���
               template,         // ������ ������
               operator : string // ����� �������
               end { DIAGRAMS }; 

type FUNCDEFINITION = record
                      EntryPoint : function(DSV : HGLOBAL) : Real; stdcall; // �������� EAX � EDX, EFLAGS (max � min) �� stdcall ��������� � ST(0) ��������� ����������
                      //FuncName : string; // ��� �������
                      Expresion : string; // �������-��������� 
                      CODE : array of Byte // ��������� �� ������, ������ ��� �������� ��������� � ������ ��� ������������ ���� (����������� ����������� ��� ������������ ��������)
                      end { FUNCDEFINITION };                          

type FUNC = ^_FUNC;
     _FUNC = record // ��� ����� ����� ������� ��������� ��� �������� ������� � ������������� �� � ������ ����-������
             Functions : array of FUNCDEFINITION; // �� ����� ���� ����� ���������� ��������� ������� 
             Variables : array of string; // ����� ���������� ����������
             Constants : array of string; // ����� ���������� ����������
             DSC : HGLOBAL; // ��������� �� ������� ������ (������ Real �����), ��������� � ������� �� ��������� ��� ��������
             // private
             // ������� ��� �������� � �������� - �������� ������������� ������
             ENTIRETYSV, // ������������� ������� ���������� ����� ����
             ENTIRETYSC : Integer // ������������� ������� �������� ����� ����
             end { _FUNC };                    

function FINDTEMPLATE(const expr : string; const MAPPING : array of DIAGRAM; out l, r : string; var id : Integer) : BOOL;
function SECONDBRACKET(const EXPRESSION : string; FIRSTBRACKET : Integer) : Integer;
procedure DeleteExternalBracket(var EXPRESSION : string);
procedure FIRSTFUNCTION(var fs : _FUNC); // �������������� ��������� fs ��� ����������
function NEXTFUNCTION(var fs : _FUNC) : Integer; // ������ ��� ���� ��������� ��� ��� � ��������� ����������� �������
function IsVarIdent(const S : string) : BOOL; // ��������� �� ������������ ������ ���������� ����� ���������-����������
function IsConstIdent(const S : string) : BOOL; // ��������� �� ������������ ������ ���������� ����� ���������-����������
function FINDCONSTVAR(const S : string; const fs : _FUNC) : Integer; // ��� ������ ���������-���������� ��� ���������-����������, �������� ���� � ������������ ����� � ������� (���������� ��� ��������)
function NEWCONSTORVAR(const S : string; var fs : _FUNC) : Integer; // ��������� ����� ��� � ������ ����������/�������� � ��� ������ ��� ��� ������ �������, ������ �������� ���� �������� �����
function det(const m : TMATRIX) : Real;
function minor(const m : TMATRIX; v, h : Integer) : TMATRIX;

IMPLEMENTATION 

// � ������ �������� MAPPING ���� �� ���������� ������ ��������������� expr ������ � ���������� ��� ������ � ��������� ��������� ('l#' �/��� 'r#').
// ��������� ������ � MAPPING ������ ���� ��������� (���� 'l#' ��� 'r#')
function FINDTEMPLATE(const expr : string; const MAPPING : array of DIAGRAM; out l, r : string; var id : Integer) : BOOL; // ������� ���� �������� ������� �� �������� ������

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
                            case cur_tpl[io + 1] of 'l' : l:= drain { 'l' }; // ����� ��� 254 ������ �������� ��� case �������, � �� ������ l � r
                                                    'r' : r:= drain { 'r' }
                            end { CASE }
                            end
                       else if (expr[ie] = cur_tpl[io]) then begin
                                                             Dec(ie);
                                                             Dec(io)
                                                             end
                                                        else Break { IF } { IF }
until ((io = 0) or (ie = 0)) { REPEAT }
until ((id = High(MAPPING)) or ((io = 0) and (ie = 0))) { REPEAT }; // ���� ����������� MAPPING �������� ���������, �� (id = High(MAPPING)) �� ���������
Result:= ((io = 0) and (ie = 0)) and (b = 0) // ������ ��������� �� ����� + ��� �������� ������ - �������
                         
end { FINDTEMPLATE };   

function SECONDBRACKET(const EXPRESSION : string; FIRSTBRACKET : Integer) : Integer; // �������� ������ ����������� :)

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
for index:= 1 to (L) do if not (S[index] in IDENTIFIERCHARS) then L:= 0 { IF } { FOR }; // ��� ������, �� ��� � ��������

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

Result:= (b = 0) // ������ ����� ��� �������� ������ ������� � ��������

end { IsExpresion };*)

function NEWCONSTORVAR(const S : string; var fs : _FUNC) : Integer; // �� ���� ��������� �� ������ ��������� ������ 'pi', 'l2e', 'l2t', 'lg2', 'ln2'
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

function minor(const m : TMATRIX; v, h : Integer) : TMATRIX; // v - ������, h - �������

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

function det(const m : TMATRIX) : Real; // ������������

var index, H : Integer;
    tmp : Real;

begin
H:= High(m);

if (H = 1) then Result:= m[0][0]*m[1][1] - m[0][1]*m[1][0]
//if (H = 0) then Result:= m[0][0]
           else begin
                Result:= 0.0;
                for index:= H downto (0) do begin
                                            tmp:= m[0][index]*det(minor(m, 0, index)); // �� ������ ������
                                            if (Odd(index)) then Result:= Result - tmp // ���������� ������������ ������ � �������������� ����������
                                                            else Result:= Result + tmp { IF }
                                            end { FOR }
                end { IF }

end { det };

INITIALIZATION

FINALIZATION    

END { BFATD }.
