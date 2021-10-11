{ Copr. 1986-92 Numerical Recipes Software .5-28. }
UNIT bfspecialfunc; 
// Специальные функции.
// Функция ошибок используется для рассчёта параметра разрешённости
// (в a*exp(-sqr(rfactor*r*(x/m - 1.0)) - параметр r) пика, соответствующего 
// определённой площади под пиком при конкретезированном значении амплитуды (a)

INTERFACE             

function Erf(x : Double) : Double; { Функция ошибок }
//function Erfc(x : Double) : Double; { Дополнительная функция ошибок }
                
IMPLEMENTATION

const cEps : Extended = 3.0E-14;        { 3.0E-7;  - for Real }
      cFPMin : Extended = 1.0E-300;     { 1.0E-30; - for Real }
      cItMax : Cardinal = 1000;         { 100;     - for Real }
 
function GammLn(x : Double) : Double; { Натуральный логарифм Гамма-функции }

const cof : array[1..6] of Extended = ( 76.18009172947146,
				       -86.50532032941677,
				        24.01409824083091,
				       -1.231739572450155,
				        0.1208650973866179E-2,
				       -0.5395239384953E-5) { cof };
                                     
const stp : Extended = 2.5066282746310005;

var j : Byte;
    ser, tmp, y : Extended;

begin
y:= x;
tmp:= x + 5.5;
tmp:= (x + 0.5)*Ln(tmp) - tmp;
ser:= 1.000000000190015;
for j:= 1 to (6) do begin
                    y:= y + 1.0;
                    ser:= ser + cof[j]/y
                    end { FOR };

GammLn:= tmp + Ln(stp*ser/x)

end { GammLn };

{ внутренняя процедура }
procedure GCF(out gammcf : Double; a, x : Double; out gln : Double);

var i : Word;
    an, b, c, d, del, h : Extended;

begin    
gln:= GammLn(a);
b:= x + (1.0 - a);
c:= 1.0/cFPMin;
d:= 1.0/b;
h:= d;
i:= 1;
repeat
an:= i*(a - i);
b:= b + 2.0;
d:= an*d + b;
if (Abs(d) < cFPMin) then d:= cFPMin { IF };
c:= b + an/c;
if (Abs(c) < cFPMin) then c:= cFPMin { IF };
d:= 1.0/d;
del:= d*c;
h:= h*del;
Inc(i);     
{$IFOPT R+}
if (i > CItMAx) then RunError(201) { IF };
{$ENDIF R+}
until (Abs(del - 1.0) < cEps) { REPEAT };

gammcf:= Exp(a*Ln(x) - gln - x)*h
  
end { GCF };

{ внутренняя процедура }
procedure GSer(out gamser : Double; a, x : Double; out gln : Double);

var ap, del, sum : Extended; 
    {$IFOPT R+}
    n : Word;
    {$ENDIF R+}

begin
gln:= GammLn(a);
if (x <= 0.0) then begin
                   {$IFOPT R+}
                   if (x < 0.0) then RunError(201) { IF };
                   {$ENDIF R+}
                   gamser:= 0.0;
                   Exit
                   end { IF };

ap:= a;
sum:= 1.0/a;
del:= sum;
{$IFOPT R+}
n:= cItMAx;
{$ENDIF R+}
repeat
ap:= ap + 1.0;
del:= del*x/ap;
sum:= sum + del;
{$IFOPT R+}
Dec(n);
if (n <= 0) then RunError(201) { IF };
{$ENDIF R+}
until (Abs(del) < Abs(sum)*cEps) { REPEAT };
gamser:= sum*Exp(a*Ln(x) - gln - x)

end { GSer };

function GammP(a, x : Double) : Double;

var gamser, gammcf, gln : Double;

begin
{$IFOPT R+}
if ((x < 0.0) or (a <= 0.0)) then RunError(201) { IF };
{$ENDIF R+}
if (x < a + 1.0) then begin
                      GSer(gamser, a, x, gln);
                      GammP:= gamser
                      end
                 else begin
                      GCF(gammcf, a, x, gln);
                      GammP:= 1.0 - gammcf
                      end { IF }

end { GammP };

function Erf(x : Double) : Double;
begin
if (x < 0.0) then Erf:= -GammP(0.5, x*x)
	     else Erf:= GammP(0.5, x*x) { IF }
        
end { Erf };


function Erfc(x : Double) : Double;

var f, t, z : Double;

begin
z:= Abs(x);
t:= 1.0/(1.0 + 0.5*z);
f:= t*Exp(-z*z - 1.26551223 +
	      t*(1.00002368 +
	      t*(0.37409196 +
              t*(0.09678418 +
              t*(-0.18628806 +
              t*(0.27886807 +
              t*(-1.13520398 +
              t*(1.48851587 +
              t*(-0.82215223 +
              t*0.17087277))))))))) { f };

if (x < 0.0) then Erfc:= 2.0 - f
             else Erfc:= f { IF }

end { Erfc };

INITIALIZATION

FINALIZATION
                     
END { BFSPECIALFUNC }.
