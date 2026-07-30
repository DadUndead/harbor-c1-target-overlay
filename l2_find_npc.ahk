;===============================================================================
; FIND NPC OVERLAY (separate window) - type a name and click ▶ to send
; /target <name> into game chat once. A single manual action per click,
; same spirit as chat Translate/Send - not an automated repeating search.
;===============================================================================

g_findGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2Find")
g_findGui.BackColor := "202020"
; Edit controls render with their own opaque white background regardless
; of the Gui's own color - cSilver (light gray) text there is nearly
; unreadable, same issue the party-nickname edit fields had. Dark text
; instead, matching that established fix.
g_findGui.SetFont("s10 c000000", "Consolas")
g_findNameEdit := g_findGui.AddEdit("x8 y7 w120 h22", "")
g_findGui.SetFont("s12 cSilver", "Segoe UI Symbol")
g_findBtn := g_findGui.AddButton("x134 y6 w28 h24", "▶")
g_findBtn.OnEvent("Click", f_on_find_click)
findPos := f_load_saved_pos("find", FIND_OVERLAY_X, FIND_OVERLAY_Y)
g_findGui.Show("x" findPos.x " y" findPos.y " w" FIND_OVERLAY_W " h36 NoActivate Hide")
WinSetTransparent(230, g_findGui)

; FIND NPC - a single /target <name> per click, nothing automated/repeating.
f_on_find_click(*) {
    global g_findNameEdit
    name := Trim(g_findNameEdit.Text)
    if (name = "")
        return
    f_send_to_game_chat("/target " name)
}

f_find_edit_focused() {
    global g_findGui, g_findNameEdit
    return WinActive("ahk_id " g_findGui.Hwnd) && g_findGui.FocusedCtrl = g_findNameEdit
}

#HotIf f_find_edit_focused()
Enter::f_on_find_click()
#HotIf
