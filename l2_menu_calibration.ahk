;===============================================================================
; MENU (separate window) - checkboxes show/hide the other three windows.
;===============================================================================

g_menuGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2Menu")
g_menuGui.BackColor := "202020"
g_menuGui.SetFont("s10 cSilver", "Consolas")
g_chkTimer := g_menuGui.AddCheckbox("x10 y8 w70 h20", "Timer")
g_chkTimer.OnEvent("Click", f_on_chk_timer)
g_chkMobInfo := g_menuGui.AddCheckbox("x86 y8 w85 h20", "Mob Info")
g_chkMobInfo.OnEvent("Click", f_on_chk_mobinfo)
g_chkTranslate := g_menuGui.AddCheckbox("x177 y8 w95 h20", "Translator")
g_chkTranslate.OnEvent("Click", f_on_chk_translate)
g_chkParty := g_menuGui.AddCheckbox("x279 y8 w80 h20", "Party")
g_chkParty.OnEvent("Click", f_on_chk_party)
g_chkFind := g_menuGui.AddCheckbox("x361 y8 w70 h20", "Target")
g_chkFind.OnEvent("Click", f_on_chk_find)
g_menuBtn := g_menuGui.AddButton("x438 y6 w30 h22", "☰")
g_menuBtn.OnEvent("Click", f_on_menu_btn_click)
menuPos := f_load_saved_pos("menu", MENU_X, MENU_Y)
g_menuGui.Show("x" menuPos.x " y" menuPos.y " w" MENU_W " h36 NoActivate")
WinSetTransparent(230, g_menuGui)

;===============================================================================
; CALIBRATION ZONES - visual, draggable+resizable rectangles showing exactly
; where the target-name and chat OCR capture regions are. Deliberately NOT
; using the native "+Resize" (WS_THICKFRAME) style here: Windows reserves
; extra frame space for it even with no caption, which pushed the visible
; colored area down and out of alignment with the actual (tiny) capture
; rect - exactly the "zone sits below the mob name" bug. Instead, a custom
; WM_NCHITTEST handler reports resize edges near the border (~8px) with no
; real frame/border added at all, so the visible rectangle IS the capture
; rect, pixel for pixel. Interior clicks fall through to the same
; WM_LBUTTONDOWN drag-move trick used by the other windows.
;===============================================================================

g_zoneTargetGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2ZoneTarget")
g_zoneTargetGui.BackColor := "FF3030"
g_zoneTargetGui.SetFont("s9 cWhite Bold", "Consolas")
g_zoneTargetGui.AddText("x4 y2 w120 h18 +0xC", "TARGET")
g_zoneTargetGui.Show("x" CAPTURE_X " y" CAPTURE_Y " w" CAPTURE_W " h" CAPTURE_H " NoActivate Hide")
WinSetTransparent(120, g_zoneTargetGui)

g_zoneChatGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2ZoneChat")
g_zoneChatGui.BackColor := "3080FF"
g_zoneChatGui.SetFont("s9 cWhite Bold", "Consolas")
g_zoneChatGui.AddText("x4 y2 w120 h18 +0xC", "CHAT")
g_zoneChatGui.Show("x" CHAT_CAPTURE_X " y" CHAT_CAPTURE_Y " w" CHAT_CAPTURE_W " h" CHAT_CAPTURE_H " NoActivate Hide")
WinSetTransparent(120, g_zoneChatGui)

g_zonePartyGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2ZoneParty")
g_zonePartyGui.BackColor := "30D030"
g_zonePartyGui.SetFont("s9 cWhite Bold", "Consolas")
g_zonePartyGui.AddText("x4 y2 w120 h18 +0xC", "PARTY")
g_zonePartyGui.Show("x" PARTY_CAPTURE_X " y" PARTY_CAPTURE_Y " w" PARTY_CAPTURE_W " h" PARTY_CAPTURE_H " NoActivate Hide")
WinSetTransparent(120, g_zonePartyGui)

; prominent floating button shown only while calibration is active - easier
; to spot over the game than a small menu checkbox, and sits right under
; the menu so it's always near at hand regardless of where the zones
; themselves get dragged to.
g_endCalibGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2EndCalibration")
g_endCalibGui.BackColor := "CC0000"
g_endCalibGui.SetFont("s11 cWhite Bold", "Consolas")
g_endCalibBtn := g_endCalibGui.AddButton("x4 y4 w240 h32", T("end_calib_btn"))
g_endCalibBtn.OnEvent("Click", f_end_calibration)
g_endCalibGui.Show("w248 h40 NoActivate Hide")
WinSetTransparent(235, g_endCalibGui)

f_on_menu_btn_click(*) {
    ; named ctxMenu, not "menu" - AHK variable names are case-insensitive, so
    ; a local var literally named "menu" shadows the built-in Menu class
    ; within this function, breaking the Menu() call that follows it.
    ctxMenu := Menu()
    ctxMenu.Add("Calibrate", f_start_calibration)
    ctxMenu.Add("Gemini API...", f_show_gemini_key_popup)
    ctxMenu.Add()   ; separator
    ctxMenu.Add(T("exit_menu_item"), (*) => ExitApp())
    ctxMenu.Show()
}

f_start_calibration(*) {
    global g_show_calibrate, g_zoneTargetGui, g_zoneChatGui, g_zonePartyGui, g_endCalibGui, g_menuGui, WINDOW_POS_FILE
    g_show_calibrate := true
    IniWrite(g_show_calibrate, WINDOW_POS_FILE, "checkboxes", "calibrate")
    g_zoneTargetGui.Show("NoActivate")
    g_zoneChatGui.Show("NoActivate")
    g_zonePartyGui.Show("NoActivate")
    WinGetPos(&mx, &my, , &mh, "ahk_id " g_menuGui.Hwnd)
    g_endCalibGui.Move(mx, my + mh + 4)
    g_endCalibGui.Show("NoActivate")
}

f_end_calibration(*) {
    global g_show_calibrate, g_zoneTargetGui, g_zoneChatGui, g_zonePartyGui, g_endCalibGui, WINDOW_POS_FILE
    g_show_calibrate := false
    IniWrite(g_show_calibrate, WINDOW_POS_FILE, "checkboxes", "calibrate")
    g_zoneTargetGui.Hide()
    g_zoneChatGui.Hide()
    g_zonePartyGui.Hide()
    g_endCalibGui.Hide()
}

; popup for entering/replacing the personal Gemini API key - explains why it's
; worth setting up and exactly how to get one, since "paste a key from a
; website" is the one setup step that isn't self-explanatory from the tray
; tip alone.
f_show_gemini_key_popup(*) {
    global g_gemini_key, g_menuGui

    keyGui := Gui("+AlwaysOnTop +Owner" g_menuGui.Hwnd, "Gemini API")
    keyGui.SetFont("s10", "Segoe UI")
    keyGui.AddText("w480", T("gemini_intro"))
    keyGui.SetFont("s10 Bold")
    keyGui.AddText("w480 y+12", T("gemini_how_to"))
    keyGui.SetFont("s10 Norm")
    linkCtrl := keyGui.AddLink("w480 y+12", T("gemini_step1"))
    linkCtrl.OnEvent("Click", (*) => Run("https://aistudio.google.com/app/apikey"))
    keyGui.AddText("w480", T("gemini_step23"))
    keyGui.AddText("y+12", T("gemini_key_label"))
    keyEdit := keyGui.AddEdit("w480 y+2 Password*", g_gemini_key)
    keyGui.AddText("w480 cGray", T("gemini_storage_note"))
    saveBtn := keyGui.AddButton("y+15 w110", T("save_btn"))
    cancelBtn := keyGui.AddButton("x+10 w90", T("cancel_btn"))

    saveBtn.OnEvent("Click", (*) => f_save_gemini_key(Trim(keyEdit.Text, " `t`r`n"), keyGui))
    cancelBtn.OnEvent("Click", (*) => keyGui.Destroy())
    keyGui.OnEvent("Close", (*) => keyGui.Destroy())

    keyGui.Show("w500")
}

f_save_gemini_key(key, keyGui) {
    global GEMINI_REG_KEY, g_gemini_key
    if (key = "") {
        try RegDelete(GEMINI_REG_KEY, "GeminiApiKey")
    } else {
        RegWrite(key, "REG_SZ", GEMINI_REG_KEY, "GeminiApiKey")
    }
    g_gemini_key := key
    keyGui.Destroy()
    MsgBox(
        (key != "") ? T("gemini_saved_msg") : T("gemini_removed_msg"),
        "L2 Target Overlay", "OK Icon!")
}

f_on_chk_timer(ctrl, *) {
    global g_show_timer, g_buffGui, WINDOW_POS_FILE
    g_show_timer := ctrl.Value
    IniWrite(g_show_timer, WINDOW_POS_FILE, "checkboxes", "timer")
    if g_show_timer
        g_buffGui.Show("NoActivate")
    else
        g_buffGui.Hide()
}

f_on_chk_mobinfo(ctrl, *) {
    global g_show_target, g_gui, g_last_text, WINDOW_POS_FILE
    g_show_target := ctrl.Value
    IniWrite(g_show_target, WINDOW_POS_FILE, "checkboxes", "mobinfo")
    if g_show_target {
        g_last_text := ""   ; force a fresh redraw instead of showing stale/blank content
        g_gui.Show("NoActivate")
    } else {
        g_gui.Hide()
    }
}

f_on_chk_translate(ctrl, *) {
    global g_show_chat, g_chatGui, WINDOW_POS_FILE
    g_show_chat := ctrl.Value
    IniWrite(g_show_chat, WINDOW_POS_FILE, "checkboxes", "translate")
    if g_show_chat
        g_chatGui.Show("NoActivate")
    else
        g_chatGui.Hide()
}

f_on_chk_party(ctrl, *) {
    global g_show_party, g_partyGui, WINDOW_POS_FILE
    g_show_party := ctrl.Value
    IniWrite(g_show_party, WINDOW_POS_FILE, "checkboxes", "party")
    if g_show_party
        g_partyGui.Show("NoActivate")
    else
        g_partyGui.Hide()
}

f_on_chk_find(ctrl, *) {
    global g_show_find, g_findGui, WINDOW_POS_FILE
    g_show_find := ctrl.Value
    IniWrite(g_show_find, WINDOW_POS_FILE, "checkboxes", "find")
    if g_show_find {
        g_findGui.Show("NoActivate")
    } else {
        g_findGui.Hide()
    }
}

f_toggle_enabled(*) {
    global g_enabled, g_show_target, g_show_timer, g_show_chat, g_show_calibrate, g_show_party, g_show_find, g_last_text
    global g_menuGui, g_endCalibGui, g_findGui
    g_enabled := !g_enabled
    if g_enabled {
        g_menuGui.Show("NoActivate")
        ; only the menu is unconditional - each window follows its own
        ; checkbox, which defaults to unchecked
        if g_show_target {
            g_last_text := ""
            g_gui.Show("NoActivate")
        }
        if g_show_timer
            g_buffGui.Show("NoActivate")
        if g_show_chat
            g_chatGui.Show("NoActivate")
        if g_show_party
            g_partyGui.Show("NoActivate")
        if g_show_find
            g_findGui.Show("NoActivate")
        if g_show_calibrate {
            g_zoneTargetGui.Show("NoActivate")
            g_zoneChatGui.Show("NoActivate")
            g_zonePartyGui.Show("NoActivate")
            WinGetPos(&mx, &my, , &mh, "ahk_id " g_menuGui.Hwnd)
            g_endCalibGui.Move(mx, my + mh + 4)
            g_endCalibGui.Show("NoActivate")
        }
    } else {
        g_menuGui.Hide()
        g_gui.Hide()
        g_chatGui.Hide()
        g_buffGui.Hide()
        g_partyGui.Hide()
        g_findGui.Hide()
        g_zoneTargetGui.Hide()
        g_zoneChatGui.Hide()
        g_zonePartyGui.Hide()
        g_endCalibGui.Hide()
    }
    TrayTip("L2 Target OCR", g_enabled ? "Enabled" : "Disabled")
}
