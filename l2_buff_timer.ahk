;===============================================================================
; BUFF TIMER OVERLAY (separate window)
;===============================================================================

g_buffGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2BuffTimer")
g_buffGui.BackColor := "202020"
g_buffGui.SetFont("s10 cSilver", "Consolas")
g_buffMinEdit := g_buffGui.AddEdit("x8 y7 w32 h22 Number Center", String(BUFF_TIMER_DEFAULT_MIN))
g_buffGui.SetFont("s12", "Segoe UI Symbol")
g_buffStartBtn := g_buffGui.AddButton("x46 y6 w28 h24", "▶")   ; start
g_buffStartBtn.OnEvent("Click", f_on_buff_start_click)
g_buffResetBtn := g_buffGui.AddButton("x78 y6 w28 h24", "↺")   ; reset
g_buffResetBtn.OnEvent("Click", f_on_buff_reset_click)
g_buffMuteBtn := g_buffGui.AddButton("x110 y6 w24 h24", "♪")   ; mute toggle - see f_on_buff_mute_click
g_buffMuteBtn.OnEvent("Click", f_on_buff_mute_click)
g_buffGui.SetFont("s14 cLime", "Consolas")
g_buffDisplay := g_buffGui.AddText("x138 y7 w" (BUFF_TIMER_W - 146) " h22 +0xC Center", Format("{:02}:00", BUFF_TIMER_DEFAULT_MIN))
buffPos := f_load_saved_pos("buff", BUFF_TIMER_X, BUFF_TIMER_Y)
g_buffGui.Show("x" buffPos.x " y" buffPos.y " w" BUFF_TIMER_W " h36 NoActivate Hide")
WinSetTransparent(230, g_buffGui)

; renders remaining time as MM:SS, turning red for the last 5 minutes (and
; on hitting zero) so it's noticeable without needing to read the number.
f_set_buff_display(totalSeconds, urgent) {
    global g_buffDisplay
    if (totalSeconds < 0)
        totalSeconds := 0
    txt := Format("{:02}:{:02}", totalSeconds // 60, Mod(totalSeconds, 60))
    g_buffDisplay.SetFont(urgent ? "s14 cRed" : "s14 cLime", "Consolas")
    g_buffDisplay.Text := txt
}

f_on_buff_start_click(*) {
    global g_buffMinEdit, g_buff_running, g_buff_end_tick, g_buff_duration_min, g_buff_beeped_5min, g_buff_beeped_1min
    val := g_buffMinEdit.Text + 0
    if (val <= 0)
        val := BUFF_TIMER_DEFAULT_MIN
    g_buff_duration_min := val
    g_buff_end_tick := A_TickCount + Round(val * 60000)
    g_buff_beeped_5min := false
    g_buff_beeped_1min := false
    g_buff_running := true
}

f_on_buff_reset_click(*) {
    global g_buff_running, g_buffMinEdit, g_buff_duration_min, g_buff_beeped_5min, g_buff_beeped_1min
    g_buff_running := false
    g_buff_beeped_5min := false
    g_buff_beeped_1min := false
    val := g_buffMinEdit.Text + 0
    if (val <= 0)
        val := g_buff_duration_min
    f_set_buff_display(val * 60, false)
}

f_on_buff_mute_click(*) {
    global g_buff_muted, g_buffMuteBtn
    g_buff_muted := !g_buff_muted
    g_buffMuteBtn.Text := g_buff_muted ? "⊗" : "♪"
}

f_buff_timer_tick() {
    global g_buff_running, g_buff_end_tick, g_buff_beeped_5min, g_buff_beeped_1min, g_buff_muted
    if !g_buff_running
        return
    remainMs := g_buff_end_tick - A_TickCount
    if (remainMs <= 0) {
        f_set_buff_display(0, true)
        g_buff_running := false
        if !g_buff_muted
            SoundBeep(1000, 300)
        return
    }
    remainSec := Ceil(remainMs / 1000)
    if (remainSec <= 300 && !g_buff_beeped_5min) {
        g_buff_beeped_5min := true
        if !g_buff_muted
            SoundBeep(1000, 300)
        f_start_buff_blink()
    }
    if (remainSec <= 60 && !g_buff_beeped_1min) {
        g_buff_beeped_1min := true
        if !g_buff_muted
            SoundBeep(1000, 300)
        f_start_buff_blink()
    }
    f_set_buff_display(remainSec, remainSec <= 300)
}

; flashes the time display a few times to draw the eye at the 5-minute and
; 1-minute marks, on top of the beep - useful when sound is muted or the
; game's own audio drowns it out. Runs on its own faster timer rather than
; blocking the main 250ms tick, and stops itself after a fixed count.
f_start_buff_blink() {
    global g_buff_blink_count
    g_buff_blink_count := 8   ; 8 visibility toggles = 4 blinks
    SetTimer(f_buff_blink_step, 150)
}

f_buff_blink_step() {
    global g_buff_blink_count, g_buffDisplay
    if (g_buff_blink_count <= 0) {
        SetTimer(f_buff_blink_step, 0)
        g_buffDisplay.Visible := true
        return
    }
    g_buffDisplay.Visible := !g_buffDisplay.Visible
    g_buff_blink_count -= 1
}

SetTimer(f_buff_timer_tick, 250)
