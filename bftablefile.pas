{ © 2007-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
UNIT bftablefile; 
// Читает текстовые файлы определённого типа (таблицы)
// с зараннее задаваемым предполагаемым количеством колонок (здесь - 2)

INTERFACE        
                       
uses Windows,
     bfatd;

type TColumnData = TSPECTRAAXIES;

function GetOpenTableFileName(Parent : HWND) : string; // Выдаёт стандартный диалог выбора файла модальный для указанного окна
function GetSaveTableFileName(Parent : HWND) : string;

function LoadTableFile(const FileName : string; Columns : Integer) : Integer; // Считывает указанный файл во внутреннюю структуру, считая что исходный файл - файл таблицы с Columns столбцами
function SaveTableFile(const FileName : string; Columns : Integer) : Integer; // Сохраняет в указаный файл внутреннюю структуру как таблицу

function GetTableColumn(ni : Integer; out ColumnData : TColumnData) : Integer; // Инициализирует ColumnData значениями из ni колонки файла
procedure SetTableColumn(ni : Integer; const ColumnData : TColumnData); // Считывает массив во внутреннюю структуру ("транспонируя") 

IMPLEMENTATION

uses CommDlg,
     bfsysutils;

const FILENAMEFILTER = 'Все файлы (*.*)'#0'*.*'#0'Текстовые файлы спектров (*.txt;*.bfs)'#0'*.txt;*bfs'#0; // завершается вторым #0 компилятором
                       //'All Files (*.*)'#0'*.*'#0'Text Files (*.txt)'#0'*.txt'#0'Spectra Files (*.bfs)'#0'*.bfs'#0#0;
                  
var CurrentTableFile : Text;     

(*function IsFileExist(FileName : PChar) : BOOL;

var HFindFile : THandle;
    FindData : TWin32FindData;    

begin
Result:= TRUE;
HFindFile:= FindFirstFile(FileName, FindData);
if ((HFindFile = INVALID_HANDLE_VALUE) or (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0)) then Result:= FALSE
                                                                                                         else FindClose(HFindFile) { IF }

end { IsFileExist };*)

function GetSaveTableFileName(Parent : HWND) : string; 

var sfn: TOpenFilename;
    S : string;
    index,
    index0 : Integer;
    
begin
S:= ParamStr(0);
index0:= Length(S);
for index:= index0 downto (1) do if (S[index] = '\') then begin
                                                          index0:= index;
                                                          Break
                                                          end { IF } { FOR };

ZeroMemory(@sfn, SizeOf(TOpenFilename));
with sfn do begin
            lStructSize:= SizeOf(TOpenFilename);
            hWndOwner:= Parent; 
            hInstance:= SysInit.HInstance;
            lpstrFilter:= FILENAMEFILTER;
            nFilterIndex:= 1; // *.*
            HGLOBAL(lpstrFile):= GlobalAlloc(GPTR, MAX_PATH);
            lpstrInitialDir:= PChar(Copy(S, 1, index0));
            nMaxFile:= MAX_PATH - 1; // GlobalSize(HGLOBAL(lpstrFile)) - 1;
            lpstrDefExt:= 'txt';
            lpstrTitle:= 'Сохранить спектр'; 
            Flags:= OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER or OFN_HIDEREADONLY 
            end { ofn };

SetLength(Result, 0);
if (GetSaveFileName(sfn)) then if (lstrlen(sfn.lpstrFile) <> 0) then begin 
                                                                     index:= GetFileAttributes(sfn.lpstrFile); 
                                                                     if (index < 0) then Result:= sfn.lpstrFile
                                                                                    else if (index and FILE_ATTRIBUTE_READONLY = 0) then Result:= sfn.lpstrFile { IF } { IF }
                                                                     end { IF } { IF };      
                                                                     
GlobalFree(HGLOBAL(sfn.lpstrFile))
                                
end { GetSaveTableFileName };

function GetOpenTableFileName(Parent : HWND) : string; 

var ofn: TOpenFilename; 
    index,
    index0 : Integer;
    S : string;

begin
S:= ParamStr(0);
index0:= Length(S);
for index:= index0 downto (1) do if (S[index] = '\') then begin
                                                          index0:= index;
                                                          Break
                                                          end { IF } { FOR };

ZeroMemory(@ofn, SizeOf(TOpenFilename));                                                             
with ofn do begin
            lStructSize:= SizeOf(TOpenFilename);
            hWndOwner:= Parent; 
            hInstance:= SysInit.HInstance;
            lpstrFilter:= FILENAMEFILTER;
            nFilterIndex:= 1; // *.*
            HGLOBAL(lpstrFile):= GlobalAlloc(GPTR, MAX_PATH); 
            lpstrInitialDir:= PChar(Copy(S, 1, index0));
            nMaxFile:= MAX_PATH - 1;
            lpstrTitle:= 'Открыть спектр'; 
            Flags:= OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER or OFN_HIDEREADONLY 
            end { ofn };

SetLength(Result, 0);

if (GetOpenFileName(ofn)) then Result:= ofn.lpstrFile { IF }; // Halt(0) if (IsFileExist(ofn.lpstrFile)) then  { IF } 

GlobalFree(HGLOBAL(ofn.lpstrFile))

end { GetOpenTableFileName };
                             
var Table : array of array of Real; // Исключительно внутренняя

function LoadTableFile(const FileName : string; Columns : Integer) : Integer; // возвращает размерность матрицы по строкам 

const ONESTEPREADSIZE = $400; // оптимизация по скорости чтения файла в динамический массив - ReAlloc теперь не каждые 4 Inc его Length

var index,
    L,
    SL, 
    Code : Integer;
    TRIGGER : BOOL;  
    S,
    SS : string;
    rstr : array of Real;

begin
Result:= -1;
if (FileName = '') then Exit { IF }; 

Assign(CurrentTableFile, FileName);
Reset(CurrentTableFile);

SetLength(Table, Columns);
Dec(Columns); 
SL:= 0;                  
Result:= 0;
while not (Eof(CurrentTableFile)) do begin
                                     Readln(CurrentTableFile, S);
                                     index:= Pos('//', S);
                                     if (index > 0) then S:= Copy(S, 1, index - 1) { IF }; // commentary
                                     L:= Length(S);   
                                     if (L = 0) then Continue 
                                                else S:= S + ' ' { IF }; // чтобы последнее число читалось, даже если после него нет пробелов
                                     for index:= 1 to (L) do if (S[index] = ',') then S[index]:= '.' { IF } { FOR }; // Поддерживаем все форматы =)
                                     Inc(L);       
                                     TRIGGER:= ((S[1] = #9) or (S[1] = #32));
                                     SetLength(SS, 0);     
                                     rstr:= nil; 
                                     Code:= 0;          
                                     for index:= 1 to (L) do if (TRIGGER) then if ((S[index] = #9) or (S[index] = #32)) then { ! } // or begin/end comb
                                                                                                                        else begin
                                                                                                                             SS:= S[index];
                                                                                                                             TRIGGER:= FALSE
                                                                                                                             end { IF }
                                                                          else if ((S[index] = #9) or (S[index] = #32)) then begin
                                                                                                                             SetLength(rstr, Length(rstr) + 1);
                                                                                                                             Val(SS, rstr[High(rstr)], Code);
                                                                                                                             if (Code <> 0) then Break { IF };
                                                                                                                             TRIGGER:= TRUE
                                                                                                                             end
                                                                                                                        else SS:= SS + S[index] { IF } { IF } { FOR };
                                     if ((Length(rstr) > Columns) and (Code = 0)) then begin
                                                                                       if ((Result mod ONESTEPREADSIZE) = 0) then begin
                                                                                                                                  Inc(SL, ONESTEPREADSIZE);
                                                                                                                                  for index:= 0 to (Columns) do SetLength(Table[index], SL) { FOR } 
                                                                                                                                  end { IF };
                                                                                       for index:= 0 to (Columns) do Table[index][Result]:= rstr[index] { FOR };
                                                                                       Inc(Result)
                                                                                       end
                                                                                  else {Inc(err counter)} { IF } // для счёта ошибок
                                     end { WHILE };
                                    
for index:= 0 to (Columns) do SetLength(Table[index], Result) { FOR };
                               
CloseFile(CurrentTableFile) // Close(CurrentTableFile)
              
end { LoadTableFile };

function SaveTableFile(const FileName : string; Columns : Integer) : Integer;

var index, index0 : Integer; 

begin
Result:= -1;
if (FileName = '') or (Columns > Length(Table)) then Exit { IF };
Dec(Columns);
for index:= 0 to (Columns) do if (Result < High(Table[index])) then Result:= High(Table[index]) { IF } { FOR };

Assign(CurrentTableFile, FileName);
Rewrite(CurrentTableFile);
SetLength(Table, Columns + 1);
 
for index:= 0 to (Result) do begin 
                             for index0:= 0 to (Columns - 1) do Write(CurrentTableFile, FloatToStr(Table[index0][index]), #9) { FOR };
                             Writeln(CurrentTableFile, FloatToStr(Table[Columns][index]))
                             end { FOR };

CloseFile(CurrentTableFile); // Close(CurrentTableFile)

Inc(Result) 

end { SaveTableFile }; 

function GetTableColumn(ni : Integer; out ColumnData : TColumnData) : Integer;

var index : Integer;

begin
Result:= -1;
if (ni > High(Table)) then Exit { IF };
Result:= High(Table[ni]);    
SetLength(ColumnData, Result + 1);    
for index:= 0 to (Result) do ColumnData[index]:= Table[ni][index] { FOR }

end { GetTableColumn };

procedure SetTableColumn(ni : Integer; const ColumnData : TColumnData);

var index, L : Integer;

begin
L:= -1;
if (ni > High(Table)) then SetLength(Table, ni + 1) { IF };
L:= High(ColumnData);
SetLength(Table[ni], L + 1);
for index:= 0 to (L) do Table[ni][index]:= ColumnData[index] { FOR }

end { SetTableColumn };

INITIALIZATION 

FINALIZATION
                      
END { BFTABLEFILE }.
