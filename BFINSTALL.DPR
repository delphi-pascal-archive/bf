{$RESOURCE bfinstall.RES bfinstall.rc}  

PROGRAM bfinstall;

uses Windows;

const BF = 'bf';
      EXTSTR : PChar = '.bfs';
      APPSTR : PChar = 'BF.bf';  
 
var Key,
    NewKey,
    IconKey : HKEY;
    Disposition : Integer;
    index : Integer;
    S1, S2 : string;  

BEGIN

if (RegCreateKeyEx(HKEY_CLASSES_ROOT, EXTSTR, 0, nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, Key, @Disposition) = ERROR_SUCCESS) then if (Disposition = REG_CREATED_NEW_KEY) then RegSetValueEx(Key, '', 0, REG_SZ, APPSTR, 15)
                                                                                                                                                                                    else begin
                                                                                                                                                                                         RegCloseKey(Key);
                                                                                                                                                                                         RegDeleteKey(HKEY_CLASSES_ROOT, EXTSTR);

                                                                                                                                                                                         RegOpenKey(HKEY_CLASSES_ROOT, PChar(APPSTR + '\shell\open'), Key);
                                                                                                                                                                                         RegDeleteKey(Key, 'command');
                                                                                                                                                                                         RegCloseKey(Key);

                                                                                                                                                                                         RegOpenKey(HKEY_CLASSES_ROOT, PChar(APPSTR + '\shell'), Key);
                                                                                                                                                                                         RegDeleteKey(Key, 'open');
                                                                                                                                                                                         RegCloseKey(Key);

                                                                                                                                                                                         RegOpenKey(HKEY_CLASSES_ROOT, APPSTR, Key);
                                                                                                                                                                                         RegDeleteKey(Key, 'DefaultIcon');
                                                                                                                                                                                         RegDeleteKey(Key, 'shell');
                                                                                                                                                                                         RegCloseKey(Key);

                                                                                                                                                                                         RegDeleteKey(HKEY_CLASSES_ROOT, APPSTR);

                                                                                                                                                                                         MessageBox(HWND_DESKTOP, 'Successful uninstalled', BF, MB_OK or MB_ICONINFORMATION or MB_SYSTEMMODAL);
                                                                                                                                                                                         Halt
                                                                                                                                                                                         end { IF } { IF };

RegCloseKey(Key);                                                                                                                                                                                    

if (RegCreateKeyEx(HKEY_CLASSES_ROOT, APPSTR, 0, nil, REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, Key, @Disposition) = ERROR_SUCCESS) then if (Disposition = REG_CREATED_NEW_KEY) then begin
                                                                                                                                                                                         RegCreateKey(Key, 'DefaultIcon', IconKey);
                                                                                                                                                                                         RegCreateKey(Key, 'shell', NewKey);
                                                                                                                                                                                         RegCloseKey(Key);

                                                                                                                                                                                         RegCreateKey(NewKey, 'open', Key);
                                                                                                                                                                                         RegCloseKey(NewKey);

                                                                                                                                                                                         RegCreateKey(Key, 'command', NewKey);
                                                                                                                                                                                         RegCloseKey(Key);
                                                                                                                                                                                         S1:= ParamStr(0);
                                                                                                                                                                                         for index:= Length(S1) downto (1) do if (S1[index] = '\') then begin
                                                                                                                                                                                                                                                        S1:= Copy(S1, 1, index);
                                                                                                                                                                                                                                                        Break
                                                                                                                                                                                                                                                        end { IF } { FOR };

                                                                                                                                                                                         index:= Length(S1) + 9;
                                                                                                                                                                                         S2:= S1 + 'bf.exe %1';
                                                                                                                                                                                         RegSetValueEx(NewKey, '', 0, REG_SZ, PChar(S2), index);
                                                                                                                                                                                         RegCloseKey(NewKey);

                                                                                                                                                                                         S2:= S1 + 'bf.exe, 0';     
                                                                                                                                                                                         RegSetValueEx(IconKey, '', 0, REG_SZ, PChar(S2), index);
                                                                                                                                                                                         RegCloseKey(IconKey);

                                                                                                                                                                                         MessageBox(HWND_DESKTOP, 'Successful installed', BF, MB_OK or MB_ICONINFORMATION or MB_SYSTEMMODAL)
                                                                                                                                                                                         end
                                                                                                                                                                                    else begin
                                                                                                                                                                                         RegCloseKey(Key);
                                                                                                                                                                                         MessageBox(HWND_DESKTOP, 'Already installed', BF, MB_OK or MB_ICONEXCLAMATION or MB_SYSTEMMODAL)
                                                                                                                                                                                         end { IF } { IF }

  
END { BFINSTALL }.
