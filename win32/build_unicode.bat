@echo off
setlocal EnableDelayedExpansion
set "files="
for %%i in (*.d) do set files=!files! %%i
dmd -lib -of..\win32.lib -I..\ -version=Unicode -version=WIN32_WINNT_ONLY -version=WindowsNTonly -version=Windows2000 -version=Windows2003 -version=WindowsXP -version=WindowsVista %files% 
