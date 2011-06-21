@echo off
dmd -ofBitLib.dll -I..\..\..\ ..\..\..\win32.lib -I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista BitLib.d BitLib.res
dmd -ofShowBit.exe -I..\..\..\ ..\..\..\win32.lib -I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista ShowBit.d
