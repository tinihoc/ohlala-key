#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; OhlalaKey / OpenKey Polyglot - Vietnamese & Polyglot Input Method Engine
; Entry point, Tray menu, settings manager, startup toggle
; ==============================================================================

; Set Tray Icon Tooltip
A_IconTip := "OpenKey Polyglot"

; Include Engine Libraries
#Include lib\WordBuffer.ahk
#Include lib\PolyglotEngine.ahk
#Include lib\VietnameseEngine.ahk
#Include lib\MacroManager.ahk
#Include lib\InputHookManager.ahk

; Global Application State
global ConfigPath := A_ScriptDir . "\config.ini"
global MacroPath := A_ScriptDir . "\macros.txt"
global StartupShortcutPath := A_Startup . "\OpenKeyPolyglot.lnk"

; Settings variables
global SettingInputMethod := "Telex"
global SettingModernTone := true
global SettingAutoRestore := true
global SettingPolyglot := true
global SettingStartWithWindows := false

; Engine instances
global gWordBuffer := unset
global gPolyglot := unset
global gVietnamese := unset
global gMacroManager := unset
global gHookManager := unset

; Initialize Application
InitApp()

; ------------------------------------------------------------------------------
; Application Initialization
; ------------------------------------------------------------------------------
InitApp() {
    LoadSettings()

    ; Instantiate Components
    global gWordBuffer := WordBuffer()
    global gPolyglot := PolyglotEngine(SettingInputMethod, SettingPolyglot)
    global gVietnamese := VietnameseEngine(SettingInputMethod, SettingModernTone, SettingAutoRestore)
    global gMacroManager := MacroManager(MacroPath, true)
    global gHookManager := InputHookManager(gWordBuffer, gPolyglot, gVietnamese, gMacroManager)

    ; Build Tray Menu
    BuildTrayMenu()

    ; Start Low-Level Interceptor Hook
    gHookManager.Start()
}

; ------------------------------------------------------------------------------
; Configuration Persistence (config.ini)
; ------------------------------------------------------------------------------
LoadSettings() {
    global SettingInputMethod, SettingModernTone, SettingAutoRestore, SettingPolyglot, SettingStartWithWindows

    if (!FileExist(ConfigPath)) {
        IniWrite("Telex", ConfigPath, "Settings", "InputMethod")
        IniWrite("1", ConfigPath, "Settings", "ModernTone")
        IniWrite("1", ConfigPath, "Settings", "AutoRestore")
        IniWrite("1", ConfigPath, "Settings", "Polyglot")
        IniWrite("0", ConfigPath, "Settings", "StartWithWindows")
    }

    try {
        SettingInputMethod := IniRead(ConfigPath, "Settings", "InputMethod", "Telex")
        SettingModernTone := (IniRead(ConfigPath, "Settings", "ModernTone", "1") == "1")
        SettingAutoRestore := (IniRead(ConfigPath, "Settings", "AutoRestore", "1") == "1")
        SettingPolyglot := (IniRead(ConfigPath, "Settings", "Polyglot", "1") == "1")
        SettingStartWithWindows := (IniRead(ConfigPath, "Settings", "StartWithWindows", "0") == "1")
    } catch {
        ; Fallback defaults
        SettingInputMethod := "Telex"
        SettingModernTone := true
        SettingAutoRestore := true
        SettingPolyglot := true
        SettingStartWithWindows := false
    }

    ; Synchronize actual Windows startup shortcut state
    if (FileExist(StartupShortcutPath))
        SettingStartWithWindows := true
}

SaveSettings() {
    try {
        IniWrite(SettingInputMethod, ConfigPath, "Settings", "InputMethod")
        IniWrite(SettingModernTone ? "1" : "0", ConfigPath, "Settings", "ModernTone")
        IniWrite(SettingAutoRestore ? "1" : "0", ConfigPath, "Settings", "AutoRestore")
        IniWrite(SettingPolyglot ? "1" : "0", ConfigPath, "Settings", "Polyglot")
        IniWrite(SettingStartWithWindows ? "1" : "0", ConfigPath, "Settings", "StartWithWindows")
    }
}

; ------------------------------------------------------------------------------
; Tray Menu Construction & Handlers
; ------------------------------------------------------------------------------
BuildTrayMenu() {
    tray := A_TrayMenu
    tray.Delete()

    ; Method Submenu
    methodMenu := Menu()
    methodMenu.Add("Telex", OnSelectTelex)
    methodMenu.Add("VNI", OnSelectVNI)
    if (SettingInputMethod == "Telex")
        methodMenu.Check("Telex")
    else
        methodMenu.Check("VNI")
    tray.Add("Input Method", methodMenu)

    ; Tone Placement Submenu
    toneMenu := Menu()
    toneMenu.Add("Modern Style (hóa, thúy)", OnSelectModernTone)
    toneMenu.Add("Classic Style (hoá, thuý)", OnSelectClassicTone)
    if (SettingModernTone)
        toneMenu.Check("Modern Style (hóa, thúy)")
    else
        toneMenu.Check("Classic Style (hoá, thuý)")
    tray.Add("Tone Placement", toneMenu)

    ; Toggles
    tray.Add("Auto-Restore English", OnToggleAutoRestore)
    if (SettingAutoRestore)
        tray.Check("Auto-Restore English")

    tray.Add("Polyglot Extensions (French / Spanish)", OnTogglePolyglot)
    if (SettingPolyglot)
        tray.Check("Polyglot Extensions (French / Spanish)")

    tray.Add() ; Separator

    tray.Add("Start with Windows", OnToggleStartWithWindows)
    if (SettingStartWithWindows)
        tray.Check("Start with Windows")

    tray.Add("Open Macros Table (macros.txt)", (*) => Run(MacroPath))
    tray.Add("Open Settings (config.ini)", (*) => Run(ConfigPath))

    tray.Add() ; Separator
    tray.Add("Reload OhlalaKey", (*) => Reload())
    tray.Add("Exit", (*) => ExitApp())
}

; Menu Event Handlers
OnSelectTelex(ItemName, ItemPos, MyMenu) {
    global SettingInputMethod := "Telex"
    gPolyglot.inputMethod := "Telex"
    gVietnamese.inputMethod := "Telex"
    SaveSettings()
    BuildTrayMenu()
}

OnSelectVNI(ItemName, ItemPos, MyMenu) {
    global SettingInputMethod := "VNI"
    gPolyglot.inputMethod := "VNI"
    gVietnamese.inputMethod := "VNI"
    SaveSettings()
    BuildTrayMenu()
}

OnSelectModernTone(ItemName, ItemPos, MyMenu) {
    global SettingModernTone := true
    gVietnamese.modernTone := true
    SaveSettings()
    BuildTrayMenu()
}

OnSelectClassicTone(ItemName, ItemPos, MyMenu) {
    global SettingModernTone := false
    gVietnamese.modernTone := false
    SaveSettings()
    BuildTrayMenu()
}

OnToggleAutoRestore(ItemName, ItemPos, MyMenu) {
    global SettingAutoRestore := !SettingAutoRestore
    gVietnamese.autoRestore := SettingAutoRestore
    SaveSettings()
    BuildTrayMenu()
}

OnTogglePolyglot(ItemName, ItemPos, MyMenu) {
    global SettingPolyglot := !SettingPolyglot
    gPolyglot.enabled := SettingPolyglot
    SaveSettings()
    BuildTrayMenu()
}

OnToggleStartWithWindows(ItemName, ItemPos, MyMenu) {
    global SettingStartWithWindows := !SettingStartWithWindows
    if (SettingStartWithWindows) {
        try {
            FileCreateShortcut(A_ScriptFullPath, StartupShortcutPath, A_ScriptDir)
        }
    } else {
        try {
            if (FileExist(StartupShortcutPath))
                FileDelete(StartupShortcutPath)
        }
    }
    SaveSettings()
    BuildTrayMenu()
}
