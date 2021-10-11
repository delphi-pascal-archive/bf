{ © 2007-2008 Tomilov A.V. mailto:tomilov@fizteh.ru }
//
{$RESOURCE bfdlgwin.RES bfdlgwin.rc}
{$RESOURCE bfver.RES bfver.rc}

{$ALIGN 8}
{$Z4}

{$BOOLEVAL OFF}
{$RANGECHECKS OFF}
{$IOCHECKS OFF}

{$LONGSTRINGS ON}
{$STACKFRAMES OFF}

{$APPTYPE GUI}
//{$APPTYPE CONSOLE}

PROGRAM bf; { Brute Force }

uses bfatd in 'bfatd.pas',
     bfcompiler in 'bfcompiler.pas',
     bfderivator in 'bfderivator.pas',
     bfgraph in 'bfgraph.pas',
     bfhjtechnique in 'bfhjtechnique.pas',
     bfmethod in 'bfmethod.pas',
     bfspecialfunc in 'bfspecialfunc.pas',
     bfsysutils in 'bfsysutils.pas',
     bftablefile in 'bftablefile.pas',
     bfwindow in 'bfwindow.pas',
     bfdialogs in 'bfdialogs.pas';

ASM // :-) мы не ищём лёгких путей

call bfwindow.WinMain

END { BF }.
