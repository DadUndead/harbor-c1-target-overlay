#Requires AutoHotkey v2.0
#SingleInstance Force
#Include l2_strings.ahk
CoordMode("Mouse", "Screen")   ; MouseGetPos returns absolute screen coords, matching WinGetPos/WinMove

; Re-launch elevated if not already running as admin (the game and the
; capture/DllCall work are more reliable with matching privilege level).
; This triggers a normal Windows UAC prompt on startup.
if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; ------------------------------------------------------------------------
; This script used to be one 3000+ line file. It's now split into modules
; by feature, #Include'd below in dependency order (config/data first,
; each window's own file next, shared utilities after, startup last -
; l2_startup.ahk needs every window/function above it to already exist).
; Ahk2Exe bundles every included file straight into the compiled exe, so
; end users still only ever see one L2TargetOverlay.exe - this split is
; purely for keeping the source maintainable.
; ------------------------------------------------------------------------
#Include l2_config.ahk
#Include l2_npc_data.ahk
#Include l2_capture_ocr.ahk
#Include l2_target_panel.ahk
#Include l2_chat_translate.ahk
#Include l2_buff_timer.ahk
#Include l2_find_npc.ahk
#Include l2_party.ahk
#Include l2_menu_calibration.ahk
#Include l2_window_utils.ahk
#Include l2_update_check.ahk
#Include l2_startup.ahk
