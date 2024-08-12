#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance Force
OnExit("ExitFunc")

HiddenWindow := 0
HelpMessage := "Modal dialog under mouse cursor -> Ctrl+Alt+M`nPress again to hide/show pointed window."
Menu, Tray, Tip, unmodalizer`n`n%HelpMessage%
TrayTip unmodalizer, %HelpMessage%

OnMessage(0x404, "AHK_NOTIFYICON") ; Registers a callback for the WM_NOTIFYICON message

AHK_NOTIFYICON(wParam, lParam, uMsg, hWnd) {
	Global HelpMessage
	if (lParam = 0x201) ; WM_LBUTTONDOWN
	{
		TrayTip unmodalizer, %HelpMessage%
	}
}

^!m::
MouseGetPos,,, WindowUnderMouse
hOwner := DllCall("user32\GetWindow", Ptr, WindowUnderMouse, UInt, 4, Ptr) ; GW_OWNER = 4
if (HiddenWindow)
{
	WinShow, ahk_id %HiddenWindow%
	WinActivate, ahk_id %HiddenWindow%
	HiddenWindow := 0
}
else
{
	if (!hOwner)
	{
		WinHide, ahk_id %WindowUnderMouse%
		HiddenWindow := WindowUnderMouse
	}
	else
	{
		; remove modality: unlock disabled owner window
		WinSet, Style, -0x08000000, ahk_id %hOwner%  ; WS_DISABLED 0x08000000L
		
		; make former modal dialog the proper independent window shown on taskbar
		SetOwner(WindowUnderMouse, 0)
		WinSet, Style, -0x80000000, ahk_id %WindowUnderMouse%  ; WS_POPUP 0x80000000L
		WinSet, ExStyle, -0x00000080, ahk_id %WindowUnderMouse%  ; WS_EX_TOOLWINDOW 0x00000080L
		WinSet, ExStyle, -0x08000000, ahk_id %WindowUnderMouse%  ; WS_EX_NOACTIVATE 0x08000000L
		WinSet, ExStyle, +0x00040000, ahk_id %WindowUnderMouse%  ; WS_EX_APPWINDOW 0x00040000L
		WinSet, Style, +0x00cf0000, ahk_id %WindowUnderMouse%  ; WS_OVERLAPPEDWINDOW 0x00cf0000
		AddSystemMenuItems(WindowUnderMouse)
		
		; disable minimize for IrfanView (erasing dialog contents)
		WinGetClass, OwnerClass, ahk_id %hOwner%
		if (OwnerClass == "IrfanView")
			WinSet, Style, -0x00020000, ahk_id %WindowUnderMouse%  ; WS_MINIMIZEBOX 0x00020000L
		;WinSet, Style, -0x00010000, ahk_id %WindowUnderMouse%  ; WS_MAXIMIZEBOX 0x00010000L
		
		; refresh window to apply changes
		DllCall("SetWindowPos", "UInt", WindowUnderMouse, "UInt", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x27)
		
		; update window's taskbar button
		WinActivate, ahk_id %hOwner%
		WinActivate, ahk_id %WindowUnderMouse%
		SoundBeep, 750, 200
	}
}
return

SetOwner(hwnd, newOwner) {
	static GWL_HWNDPARENT := -8
	if A_PtrSize = 8
		DllCall("SetWindowLongPtr", "ptr", hwnd, "int", GWL_HWNDPARENT, "ptr", newOwner)
	else
		DllCall("SetWindowLong", "int", hwnd, "int", GWL_HWNDPARENT, "int", newOwner)
}

IsWindowVisible(hwnd) {
	static WS_VISIBLE := 0x10000000 ; WS_VISIBLE
	WinGet, Style, Style, ahk_id %hwnd%
	if (Style & WS_VISIBLE)
		return 1
	return 0
}

ExitFunc(ExitReason, ExitCode) {
	Global HiddenWindow
	if ExitReason not in Logoff,Shutdown
	{
		if (HiddenWindow)
		{
			WinShow, ahk_id %HiddenWindow%
		}
	}
	; Do not call ExitApp -- that would prevent other OnExit functions from being called.
}

AddSystemMenuItems(hwnd) {
	hMenu := DllCall("GetSystemMenu", "UInt", hwnd, "UInt", False)
	if (hMenu) {
		DllCall("AppendMenu", "UInt", hMenu, "UInt", 0x800, "UInt", 0, "Str", "")
		DllCall("AppendMenu", "UInt", hMenu, "UInt", 0x0000 | 0x0000, "UInt", 0xF120, "Str", "Restore")
		;DllCall("AppendMenu", "UInt", hMenu, "UInt", 0x0000 | 0x0000, "UInt", 0xF010, "Str", "Move")
		DllCall("AppendMenu", "UInt", hMenu, "UInt", 0x0000 | 0x0000, "UInt", 0xF000, "Str", "Size")
		DllCall("AppendMenu", "UInt", hMenu, "UInt", 0x0000 | 0x0000, "UInt", 0xF020, "Str", "Minimize")
		DllCall("AppendMenu", "UInt", hMenu, "UInt", 0x0000 | 0x0000, "UInt", 0xF030, "Str", "Maximize")
		DllCall("DrawMenuBar", "UInt", hwnd)
	}
}
