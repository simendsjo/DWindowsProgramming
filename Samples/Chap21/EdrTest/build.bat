@echo off
dmd -H -ofEdrLib.dll -L/IMPLIB -I..\..\..\ ..\..\..\win32.lib -I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista dllmodule.d EdrLib.d %*
dmd -ofEdrTest.exe -I..\..\..\ ..\..\..\win32.lib -I. -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista EdrTest.d EdrLib.lib %*
