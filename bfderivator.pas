{ © 2007 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bfderivator;
// Набор функций - операторов над строками-выражениями, позволяющий взять частную
// производную. Функция SIMPLER необходима для упрощения выражения получаемого после
// DERIVATOR, что проще, чем оптимизация кода, получаемого в результате последующей
// компиляции (множатся лишние операции умножения на 0 и 1, сложением с 0 и т.п. при
// взятие частной производной)

INTERFACE

function DERIVATOR(const expr, fvar : string) : string; // "По-честному" берёт производную
function SIMPLER(const expr : string) : string; // Исправляет отрицательные эффекты "честности" процедуры DERIVATOR
//function REPLACERSIMPLER(const expr, substr, replstr : string) : string; // Упрощает выражение и заменяет подстроку substr в expr на replstr

IMPLEMENTATION

uses bfatd,
     Windows;

function IsSimple(expr : string) : BOOL; // Строка - число или идентификатор? или имеет более сложную структуру?

var Code : Integer;
    stub : Single;

begin
//DeleteExternalBracket(expr); 
Val(expr, stub, Code);
Result:= IsConstIdent(expr) or IsVarIdent(expr) or (Code = 0)

end { IsSimple };      

// #x - подстрока д.б. оставлена без изменений, $x - применить оператор дифференцирования к подстроке
var DIFFMAPPING : array [0..26] of DIAGRAM = ((template : 'l#+r#';              operator : '$l+$r'                                              ),
                                              (template : '+r#';                operator : '$r'                                                 ),
                                              (template : 'l#-r#';              operator : '$l-($r)'                                            ),
                                              (template : '-r#';                operator : 'chs($r)'                                            ),
                                              (template : 'l#*r#';              operator : '($l)*(#r)+(#l)*($r)'                                ),
                                              (template : 'l#/r#';              operator : '(($l)*(#r)-(#l)*($r))/sqr(#r)'                      ),
                                              (template : 'l#^r#';              operator : '(#l^#r)*(#r)*($l)/(#l)'                             ),
                                              (template : 'pwr(l#)(r#)';        operator : '(ln(#l)*($r)+($l)*(#r)/(#l))*pwr(#l)(#l)'           ),
                                              (template : 'log(l#)(r#)';        operator : '(ln(#l)*($r)/(#r)-ln(#r)*($l)/(#l))/sqr(ln(#l))'    ),
                                              (template : 'cos(r#)';            operator : '($r)*chs(sin(#r))'                                  ),
                                              (template : 'sin(r#)';            operator : '($r)*cos(#r)'                                       ),
                                              (template : 'ln(r#)';             operator : '($r)/(#r)'                                          ),
                                              (template : 'exp(r#)';            operator : '($r)*exp(#r)'                                       ),
                                              (template : 'lg(r#)';             operator : '($r)/((#r)*ln(10))'                                 ),
                                              (template : 'tg(r#)';             operator : '($r)/sqr(cos(#r))'                                  ),
                                              (template : 'ctg(r#)';            operator : '($r)/chs(sqr(sin(#r)))'                             ),
                                              (template : 'arctg(r#)';          operator : '($r)/(1+sqr(#r))'                                   ),
                                              (template : 'abs(r#)';            operator : '($r)*(#r)/abs(#r)'                                  ),
                                              (template : 'sqr(r#)';            operator : 'double(#r)*($r)'                                    ),
                                              (template : 'sqrt(r#)';           operator : '($r)/chs(double(sqrt(#r)))'                         ),
                                              (template : 'log2(r#)';           operator : '($r)/(#r*ln2)'                                      ),
                                              (template : 'arcsin(r#)';         operator : '($r)/sqrt(1-sqr(#r))'                               ),
                                              (template : 'arccos(r#)';         operator : '($r)/chs(sqrt(1-sqr(#r)))'                          ),
                                              (template : 'chs(r#)';            operator : 'chs($r)'                                            ),
                                              (template : 'double(r#)';         operator : 'double($r)'                                         ),
                                              (template : '';                   operator : '1'                                                  ),
                                              (template : 'r#';                 operator : '0'                                                  )) { DIFFMAPPING };

const DDIM = High(DIFFMAPPING);

function d(const expr : string) : string;

var cur_tpl,
    l, r,
    drain : string;
    c : Char;
    id, it,
    LT : Integer;

begin
Result:= expr;
DeleteExternalBracket(Result);
SetLength(drain, 0);
FINDTEMPLATE(Result, DIFFMAPPING, l, r, id);
if (id = DDIM) then if not (IsSimple(r)) then begin 
                                              Result:= '[' + r + ']';
                                              Exit
                                              end { IF } { IF };
                                              
cur_tpl:= DIFFMAPPING[id].operator;
LT:= Length(cur_tpl);
it:= 1;
SetLength(Result, 0); 
repeat
c:= cur_tpl[it];
Inc(it);
case c of '$' : begin
                case cur_tpl[it] of 'l' : drain:= d(l) { 'l' };
                                    'r' : drain:= d(r) { 'r' }
                end { CASE };
                Inc(it)
                end { '$' };
          '#' : begin
                case cur_tpl[it] of 'l' : drain:= l { 'l' };
                                    'r' : drain:= r { 'r' }
                end { CASE };
                Inc(it)
                end { '$' }
       else drain:= c { ELSE }
end { CASE };
Result:= Result + drain  
until (it > LT) { REPEAT }

end { d };

function DERIVATOR(const expr, fvar : string) : string;
begin
DIFFMAPPING[DDIM - 1].template:= fvar;
Result:= d(expr)

end { DERIVATOR };

function dresser(var expr : string) : BOOL;

var index : Integer;

begin        
DeleteExternalBracket(expr);
Result:= IsSimple(expr);
if (Result) then Result:= (expr[1] <> '-') { IF };
index:= Length(expr);
if (expr[index] = ')') then Result:= Result or IsConstIdent(Copy(expr, 1, SECONDBRACKET(expr, index) - 1)) { IF };
if not (Result) then expr:= '(' + expr + ')'

end { dresser };
// #x - подстрока как есть, %x - подстрока наряжается в скобки, если не имеет простую структуру
var SIMPLERMAPPING : array [0..65] of DIAGRAM = ((template : '0+r#';            operator : '#r'                 ),
                                                 (template : 'l#+0';            operator : '#l'                 ),
                                                 (template : 'l#+r#';           operator : '#l+#r'              ),
                                                 (template : '+r#';             operator : '#r'                 ),
                                                 (template : 'l#-0';            operator : '#l'                 ),
                                                 (template : '0-r#';            operator : 'chs(#r)'            ),
                                                 (template : '-r#';             operator : 'chs(#r)'            ),
                                                 (template : 'l#-r#';           operator : '#l-%r'              ),
                                                 (template : '-r#';             operator : 'chs(#r)'            ),
                                                 (template : '0*r#';            operator : '0'                  ),
                                                 (template : 'l#*0';            operator : '0'                  ),
                                                 (template : 'l#*1';            operator : '#l'                 ),
                                                 (template : '1*r#';            operator : '#r'                 ),
                                                 (template : 'l#*r#';           operator : '%l*%r'              ),
                                                 (template : '0/r#';            operator : '0'                  ),
                                                 (template : 'l#/0';            operator : '[divbyz]'           ),
                                                 (template : 'l#/1';            operator : '#l'                 ),
                                                 (template : 'l#/r#';           operator : '%l/%r'              ),
                                                 (template : 'l#^(-2)';         operator : '1/sqr(%l)'          ),
                                                 (template : 'l#^2';            operator : 'sqr(%l)'            ),
                                                 (template : 'l#^(-1)';         operator : '1/%l'               ),
                                                 (template : 'l#^1';            operator : '%l'                 ),
                                                 (template : 'l#^0';            operator : '1'                  ),
                                                 (template : 'l#^r#';           operator : '%l^%r'              ),
                                                 (template : 'pwr(l#)(r#)';     operator : 'pwr(%l)(%r)'        ),
                                                 (template : 'log(l#)(r#)';     operator : 'log(%l)(%r)'        ),
                                                 (template : 'cos(0)';          operator : '1'                  ),
                                                 (template : 'cos(r#)';         operator : 'cos(#r)'            ),
                                                 (template : 'sin(0)';          operator : '0'                  ),
                                                 (template : 'sin(r#)';         operator : 'sin(#r)'            ),
                                                 (template : 'ln(0)';           operator : '[lnz]'              ),
                                                 (template : 'ln(1)';           operator : '0'                  ),
                                                 (template : 'ln(r#)';          operator : 'ln(#r)'             ),
                                                 (template : 'exp(0)';          operator : '1'                  ),
                                                 (template : 'exp(r#)';         operator : 'exp(#r)'            ),
                                                 (template : 'lg(0)';           operator : '[lgz]'              ),
                                                 (template : 'lg(1)';           operator : '0'                  ),
                                                 (template : 'lg(r#)';          operator : 'lg(#r)'             ),
                                                 (template : 'tg(0)';           operator : '0'                  ),
                                                 (template : 'tg(r#)';          operator : 'tg(#r)'             ),
                                                 (template : 'ctg(0)';          operator : '[ctgz]'             ),
                                                 (template : 'ctg(r#)';         operator : 'ctg(#r)'            ),
                                                 (template : 'arctg(0)';        operator : '0'                  ),
                                                 (template : 'arctg(r#)';       operator : 'arctg(#r)'          ),
                                                 (template : 'abs(0)';          operator : '0'                  ),
                                                 (template : 'abs(1)';          operator : '1'                  ),
                                                 (template : 'abs(r#)';         operator : 'abs(#r)'            ),
                                                 (template : 'sqr(0)';          operator : '0'                  ),
                                                 (template : 'sqr(1)';          operator : '1'                  ),
                                                 (template : 'sqr(r#)';         operator : 'sqr(#r)'            ),
                                                 (template : 'sqrt(0)';         operator : '0'                  ),
                                                 (template : 'sqrt(1)';         operator : '1'                  ),
                                                 (template : 'sqrt(r#)';        operator : 'sqrt(#r)'           ),
                                                 (template : 'log2(0)';         operator : '[log2z]'            ),
                                                 (template : 'log2(1)';         operator : '0'                  ),
                                                 (template : 'log2(r#)';        operator : 'log2(#r)'           ),
                                                 (template : 'arcsin(0)';       operator : '0'                  ),
                                                 (template : 'arcsin(r#)';      operator : 'arcsin(#r)'         ),
                                                 (template : 'arccos(1)';       operator : '0'                  ),
                                                 (template : 'arccos(r#)';      operator : 'arccos(#r)'         ),
                                                 (template : 'chs(0)';          operator : '0'                  ),
                                                 (template : 'chs(r#)';         operator : 'chs(#r)'            ),
                                                 (template : 'double(0)';       operator : '0'                  ),
                                                 (template : 'double(r#)';      operator : 'double(#r)'         ),
                                                 (template : '';                operator : ''                   ),
                                                 (template : 'r#';              operator : '%r'                 )) { SIMPLERMAPPING };

const SDIM = High(SIMPLERMAPPING);

function s(const expr : string) : string;

var cur_tpl,
    l, r,
    drain : string;
    c : Char;
    id, it,
    LT : Integer;
    
begin               
Result:= expr;
DeleteExternalBracket(Result);         
FINDTEMPLATE(Result, SIMPLERMAPPING, l, r, id);
if (id = SDIM) then begin 
                    if not (dresser(Result)) then Result:= '[' + Result + ']' { IF };
                    Exit
                    end { IF };    
cur_tpl:= SIMPLERMAPPING[id].operator;
LT:= Length(cur_tpl);
it:= 1;
SetLength(Result, 0);
SetLength(drain, 0);      
repeat
c:= cur_tpl[it];
Inc(it);
case c of '#', '%' : begin 
                     case cur_tpl[it] of 'l' : drain:= s(l) { 'l' };
                                         'r' : drain:= s(r) { 'r' } 
                     end { CASE };
                     Inc(it);
                     if (c = '%') then dresser(drain) { IF }
                     end { '#', '%' } 
       else drain:= c { ELSE }
end { CASE };
Result:= Result + drain
until (it > LT) { REPEAT }  

end { s };

function SIMPLER(const expr : string) : string;

var L : Integer;

begin
SIMPLERMAPPING[SDIM - 1].template:= '?';
SIMPLERMAPPING[SDIM - 1].operator:= '?';
Result:= expr; 
repeat   
L:= Length(Result);
Result:= s(Result);
if (Pos('[', Result) <> 0) then Break { IF }
until (L = Length(Result)) { REPEAT } // Необходимое, но не достаточное условие окончания цикла, к сожалению ничего другого в голову не приходит

end { SIMPLER };

(*function REPLACERSIMPLER(const expr, substr, replstr : string) : string;

var L : Integer;

begin
SIMPLERMAPPING[SDIM - 1].template:= substr;
SIMPLERMAPPING[SDIM - 1].operator:= replstr;
Result:= expr; 
repeat   
L:= Length(Result);
Result:= s(Result);
if (Pos('[', Result) <> 0) then Break { IF }
until (L = Length(Result)) { REPEAT }

end { REPLACERSIMPLER }; *)

INITIALIZATION
//{$APPTYPE CONSOLE} Writeln(SIMPLER(DERIVATOR(SIMPLER(DERIVATOR('a*a*a', 'a')), 'a'))); Readln; Halt

FINALIZATION

END { BFDERIVATOR }.
