// D import file generated from 'dllmodule.d'
module dllmodule;
import std.c.windows.windows;
import core.sys.windows.dll;
__gshared HINSTANCE g_hInst;

extern (Windows) BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved);

