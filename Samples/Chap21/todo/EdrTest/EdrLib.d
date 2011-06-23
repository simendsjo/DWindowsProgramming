module EdrLib;

pragma(lib, "gdi32.lib");
pragma(lib, "comdlg32.lib");
import win32.windef;
import win32.wingdi;    

export extern(Windows) BOOL EdrCenterText(HDC hdc, PRECT prc, string pString)
{
     import std.utf : count, toUTF16z;
    
     SIZE size;
     GetTextExtentPoint32(hdc, toUTF16z(pString), pString.count, &size);
     return TextOut(hdc, (prc.right - prc.left - size.cx) / 2,
                         (prc.bottom - prc.top - size.cy) / 2, toUTF16z(pString), pString.count);
}
