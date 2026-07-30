;===============================================================================
; DRAG-TO-MOVE for all four borderless (-Caption) overlay windows. There's
; no title bar to grab, so a click on the window background (or any of its
; plain Text labels) is turned into a native "drag the title bar" message
; instead - Windows then handles the actual move. Clicks on interactive
; controls (Button/Edit/Checkbox - all the same "Button" Win32 class) are
; left alone so Start/Translate/Clear/expand/checkboxes keep working
; normally.
;===============================================================================

f_is_draggable_hwnd(hwnd) {
    global g_gui, g_chatGui, g_buffGui, g_menuGui, g_partyGui, g_findGui, g_zoneTargetGui, g_zoneChatGui, g_zonePartyGui
    root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")   ; GA_ROOT
    known := (root = g_gui.Hwnd || root = g_chatGui.Hwnd || root = g_buffGui.Hwnd || root = g_menuGui.Hwnd
        || root = g_partyGui.Hwnd || root = g_findGui.Hwnd || root = g_zoneTargetGui.Hwnd || root = g_zoneChatGui.Hwnd || root = g_zonePartyGui.Hwnd)
    if !known
        return false
    cls := ""
    try cls := WinGetClass("ahk_id " hwnd)
    return (cls != "Button" && cls != "Edit" && cls != "ComboBox" && cls != "ComboLBox")
}

; persists a calibration zone's current rect: both to the live CAPTURE_*/
; CHAT_CAPTURE_*/PARTY_CAPTURE_* globals (so OCR uses it on the very next
; poll) and to disk (so it survives a restart).
f_persist_zone_rect(hwnd) {
    global g_zoneTargetGui, g_zoneChatGui, g_zonePartyGui
    global CAPTURE_X, CAPTURE_Y, CAPTURE_W, CAPTURE_H, CHAT_CAPTURE_X, CHAT_CAPTURE_Y, CHAT_CAPTURE_W, CHAT_CAPTURE_H
    global PARTY_CAPTURE_X, PARTY_CAPTURE_Y, PARTY_CAPTURE_W, PARTY_CAPTURE_H
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    if (hwnd = g_zoneTargetGui.Hwnd) {
        CAPTURE_X := x, CAPTURE_Y := y, CAPTURE_W := w, CAPTURE_H := h
        f_save_rect("capture_target", x, y, w, h)
    } else if (hwnd = g_zoneChatGui.Hwnd) {
        CHAT_CAPTURE_X := x, CHAT_CAPTURE_Y := y, CHAT_CAPTURE_W := w, CHAT_CAPTURE_H := h
        f_save_rect("capture_chat", x, y, w, h)
    } else if (hwnd = g_zonePartyGui.Hwnd) {
        PARTY_CAPTURE_X := x, PARTY_CAPTURE_Y := y, PARTY_CAPTURE_W := w, PARTY_CAPTURE_H := h
        f_save_rect("capture_party", x, y, w, h)
    }
}

; Relying on native OS non-client resize (WM_NCHITTEST edge codes) turned
; out to not reliably reach a caption-less AHK Gui window's message
; procedure in practice - resizing silently stopped working. Doing it fully
; manually instead: on a client-area click near a zone's edge, track the
; mouse with a fast timer and WinMove the window directly until the button
; is released. Deterministic, no dependency on how the OS chooses to route
; non-client hit-testing for this window style.
g_zoneResizing := false
g_zoneResizeHwnd := 0
g_zoneResizeEdge := {}
g_zoneResizeStartMouseX := 0
g_zoneResizeStartMouseY := 0
g_zoneResizeStartX := 0
g_zoneResizeStartY := 0
g_zoneResizeStartW := 0
g_zoneResizeStartH := 0
ZONE_RESIZE_MARGIN := 8
ZONE_MIN_SIZE := 20

; lParam of a client-area mouse message is (x, y) relative to the window's
; own client area, which is exactly what's needed to test "near an edge".
f_zone_edge_at(hwnd, lParam) {
    global ZONE_RESIZE_MARGIN
    xCur := lParam & 0xFFFF
    if (xCur > 32767)
        xCur -= 65536
    yCur := (lParam >> 16) & 0xFFFF
    if (yCur > 32767)
        yCur -= 65536
    WinGetClientPos(, , &cw, &ch, "ahk_id " hwnd)
    m := ZONE_RESIZE_MARGIN
    return { left: xCur < m, right: xCur >= cw - m, top: yCur < m, bottom: yCur >= ch - m }
}

f_start_zone_resize(hwnd, edge) {
    global g_zoneResizing, g_zoneResizeHwnd, g_zoneResizeEdge
    global g_zoneResizeStartMouseX, g_zoneResizeStartMouseY
    global g_zoneResizeStartX, g_zoneResizeStartY, g_zoneResizeStartW, g_zoneResizeStartH
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    MouseGetPos(&mx, &my)
    g_zoneResizing := true
    g_zoneResizeHwnd := hwnd
    g_zoneResizeEdge := edge
    g_zoneResizeStartMouseX := mx, g_zoneResizeStartMouseY := my
    g_zoneResizeStartX := x, g_zoneResizeStartY := y, g_zoneResizeStartW := w, g_zoneResizeStartH := h
    SetTimer(f_zone_resize_step, 15)
}

f_zone_resize_step() {
    global g_zoneResizing, g_zoneResizeHwnd, g_zoneResizeEdge, ZONE_MIN_SIZE
    global g_zoneResizeStartMouseX, g_zoneResizeStartMouseY
    global g_zoneResizeStartX, g_zoneResizeStartY, g_zoneResizeStartW, g_zoneResizeStartH
    if !g_zoneResizing
        return
    if !GetKeyState("LButton", "P") {
        f_stop_zone_resize()
        return
    }
    MouseGetPos(&mx, &my)
    dx := mx - g_zoneResizeStartMouseX
    dy := my - g_zoneResizeStartMouseY

    x := g_zoneResizeStartX, y := g_zoneResizeStartY
    w := g_zoneResizeStartW, h := g_zoneResizeStartH

    if g_zoneResizeEdge.left {
        if (w - dx < ZONE_MIN_SIZE)
            dx := w - ZONE_MIN_SIZE
        x += dx, w -= dx
    } else if g_zoneResizeEdge.right {
        w := Max(ZONE_MIN_SIZE, w + dx)
    }
    if g_zoneResizeEdge.top {
        if (h - dy < ZONE_MIN_SIZE)
            dy := h - ZONE_MIN_SIZE
        y += dy, h -= dy
    } else if g_zoneResizeEdge.bottom {
        h := Max(ZONE_MIN_SIZE, h + dy)
    }
    WinMove(x, y, w, h, "ahk_id " g_zoneResizeHwnd)
}

f_stop_zone_resize() {
    global g_zoneResizing, g_zoneResizeHwnd
    SetTimer(f_zone_resize_step, 0)
    g_zoneResizing := false
    f_persist_zone_rect(g_zoneResizeHwnd)
}

f_wm_lbuttondown(wParam, lParam, msg, hwnd) {
    static WM_NCLBUTTONDOWN := 0xA1, HTCAPTION := 2
    global g_zoneTargetGui, g_zoneChatGui, g_zonePartyGui, g_chatGui

    if (hwnd = g_zoneTargetGui.Hwnd || hwnd = g_zoneChatGui.Hwnd || hwnd = g_zonePartyGui.Hwnd) {
        edge := f_zone_edge_at(hwnd, lParam)
        if (edge.left || edge.right || edge.top || edge.bottom) {
            f_start_zone_resize(hwnd, edge)
            return
        }
    }

    if (hwnd = g_chatGui.Hwnd && f_chat_at_bottom_edge(hwnd, lParam)) {
        f_start_chat_resize()
        return
    }

    if !f_is_draggable_hwnd(hwnd)
        return
    root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
    PostMessage(WM_NCLBUTTONDOWN, HTCAPTION, , , "ahk_id " root)
}

OnMessage(0x201, f_wm_lbuttondown)   ; WM_LBUTTONDOWN

; Windows sends WM_EXITSIZEMOVE to a window right when a native drag
; (move) finishes - that's the moment to persist its new position, rather
; than writing to disk on every mouse-move during the drag. The zone
; windows' resize no longer goes through this (it's the manual path above
; now), but their move still does, same as the other three windows.
f_wm_exitsizemove(wParam, lParam, msg, hwnd) {
    global g_gui, g_chatGui, g_buffGui, g_menuGui, g_partyGui, g_findGui, g_zoneTargetGui, g_zoneChatGui, g_zonePartyGui, WINDOW_POS_FILE

    if (hwnd = g_zoneTargetGui.Hwnd || hwnd = g_zoneChatGui.Hwnd || hwnd = g_zonePartyGui.Hwnd) {
        f_persist_zone_rect(hwnd)
        return
    }

    name := (hwnd = g_gui.Hwnd) ? "target"
        : (hwnd = g_chatGui.Hwnd) ? "chat"
        : (hwnd = g_buffGui.Hwnd) ? "buff"
        : (hwnd = g_menuGui.Hwnd) ? "menu"
        : (hwnd = g_partyGui.Hwnd) ? "party"
        : (hwnd = g_findGui.Hwnd) ? "find" : ""
    if (name = "")
        return
    WinGetPos(&x, &y, , , "ahk_id " hwnd)
    IniWrite(x, WINDOW_POS_FILE, name, "x")
    IniWrite(y, WINDOW_POS_FILE, name, "y")
}

OnMessage(0x232, f_wm_exitsizemove)   ; WM_EXITSIZEMOVE

; Remembers the last active window that wasn't one of our own overlay
; windows - almost always the game client - so Send can restore keyboard
; focus to it before typing, regardless of what the game's process/window
; title actually is. Runs continuously and cheaply, independent of any
; checkbox, since the compose box can be used any time.
g_last_game_hwnd := 0

f_track_active_window() {
    global g_last_game_hwnd, g_gui, g_chatGui, g_buffGui, g_menuGui, g_findGui, g_zoneTargetGui, g_zoneChatGui
    active := WinExist("A")
    if !active
        return
    if (active = g_gui.Hwnd || active = g_chatGui.Hwnd || active = g_buffGui.Hwnd || active = g_menuGui.Hwnd
        || active = g_findGui.Hwnd || active = g_zoneTargetGui.Hwnd || active = g_zoneChatGui.Hwnd)
        return
    g_last_game_hwnd := active
}

SetTimer(f_track_active_window, 500)

; L2's chat input box opens/focuses on a bare Enter press (confirmed
; behavior on this server) - so no pixel-calibrated click is needed: just
; make sure the game window has keyboard focus, press Enter to open chat,
; type the translated text, and press Enter again to submit it. Focus
; ends up back on the game window afterward, same as if the player had
; typed it themselves - nothing extra needed for that.
f_send_to_game_chat(text) {
    global g_last_game_hwnd
    ; confirmed by testing: even a keyboard-only trigger (Enter in the
    ; name field, no click on any button) still reproduces this, as long
    ; as the mouse cursor is left sitting wherever it was after focusing
    ; that field - so the client is reacting to CURRENT cursor position
    ; at the moment it regains focus/keyboard input, not to any specific
    ; click event. Parking the cursor over the player's own status panel
    ; (always top-left) first means whatever it reacts to is a harmless
    ; self-target instead of a run-across-the-map click-to-move.
    MouseGetPos(&origMouseX, &origMouseY)
    MouseMove(2, 2, 0)
    ; WinActivate() doesn't block until the window is actually focused -
    ; if the old client is slow to process WM_ACTIVATE, a fixed short
    ; Sleep() could let the Escape/Enter/text below fire before the game
    ; is really the focused window, so they'd land wherever focus actually
    ; was instead (which could still open/not-open chat unpredictably). If
    ; chat never actually opens, the typed text lands as raw keystrokes in
    ; the game world instead, where individual letters are bound to
    ; skills/actions - manual typing doesn't hit this because a human
    ; naturally waits to see chat open before typing. WinWaitActive
    ; confirms activation actually completed before proceeding, instead of
    ; hoping a guessed delay was long enough.
    if (g_last_game_hwnd && !WinActive("ahk_id " g_last_game_hwnd)) {
        WinActivate("ahk_id " g_last_game_hwnd)
        WinWaitActive("ahk_id " g_last_game_hwnd, , 1)
    }
    Sleep(100)
    ; Escape first, unconditionally - Enter TOGGLES the chat input rather
    ; than always opening it, so if it happened to already be open (e.g.
    ; left open from typing a message manually) the "open chat" Enter below
    ; would instead submit/close it, and the text meant for chat would then
    ; land as raw keystrokes in the game world instead (individual letters
    ; are bound to skills/actions in L2, so this could visibly "do things"
    ; in-game). Escape reliably closes chat if it was open and is a no-op
    ; if it wasn't, so the Enter that follows can assume a known state.
    Send("{Escape}")
    Sleep(50)
    Send("{Enter}")
    Sleep(150)
    ; SendText() injects Unicode text via a message-based path rather than
    ; real key-down/up events - this client apparently reads keyboard input
    ; at a lower level (like DirectInput) that never sees SendText at all,
    ; so the chat box stayed empty and something else (the client's normal,
    ; un-intercepted keybinds, or leftover mouse state) reacted instead,
    ; producing an unrelated in-game action (e.g. click-to-move firing).
    ; Send's "{Text}" sub-mode gets the same "no need to escape special
    ; characters" safety as SendText, but goes through the same real
    ; hardware-level key event path as every other Send() call here.
    Send("{Text}" text)
    Sleep(30)
    Send("{Enter}")
    Sleep(30)
    MouseMove(origMouseX, origMouseY, 0)
}
