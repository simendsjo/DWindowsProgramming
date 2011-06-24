@echo off
dmd -H -ofStrLib.dll -L/IMPLIB -I..\..\..\ ..\..\..\win32.lib -I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista StrLib.d dllmodule.d %*

dmd -ofStrProg.exe -I..\..\..\ ..\..\..\win32.lib -I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista StrProg.d StrLib.lib StrProg.res %*
