;===============================================================================
; TARGET OVERLAY (separate window) - shows the currently-targeted NPC's
; name/level/aggro at a glance, with an expandable panel for full stats,
; traits and drop/spoil. Driven entirely by f_tick() polling the OCR'd
; target-name capture zone (see MAIN LOOP below).
;===============================================================================

LINE_H      := 17
NAME_AREA_H := 26
CHAR_W      := 7    ; approximate Consolas s9 advance width, for laying out segments

PCT_CHARS := 10   ; fixed width (characters) reserved for the percent column on the left

EXPAND_BTN_W := 24
BTN_GAP      := 4

EXPAND_BTN_X := OVERLAY_W - 8 - EXPAND_BTN_W
NAME_TEXT_W  := EXPAND_BTN_X - 8 - BTN_GAP

g_gui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2TargetOCR")
g_gui.BackColor := "202020"
g_gui.SetFont("s11 cLime", "Consolas")
g_text := g_gui.AddText("x8 y4 w" NAME_TEXT_W " h22 +0xC", "No target")

g_gui.SetFont("s8", "Consolas")
g_expandBtn := g_gui.AddButton("x" EXPAND_BTN_X " y3 w" EXPAND_BTN_W " h22 Hidden", "v")
g_expandBtn.OnEvent("Click", f_on_expand_click)

g_gui.SetFont("s9 cSilver", "Consolas")
g_dropHeader := g_gui.AddText("x8 y0 w" (OVERLAY_W - 16) " h" LINE_H " +0xC Hidden", "")
g_spoilHeader := g_gui.AddText("x8 y0 w" (OVERLAY_W - 16) " h" LINE_H " +0xC Hidden", "")

targetPos := f_load_saved_pos("target", OVERLAY_X, OVERLAY_Y)
g_gui.Show("x" targetPos.x " y" targetPos.y " w" OVERLAY_W " h" (NAME_AREA_H + LINE_H + 10) " NoActivate Hide")
WinSetTransparent(230, g_gui)

; growable pool of single-segment Text controls, reused across all lines
; and ticks - each line is drawn as 1+ segments (label/value, pct/item, ...)
; laid out left-to-right so each segment can have its own color.
g_pool := []

f_get_seg(idx) {
    global g_pool, g_gui, LINE_H
    while (g_pool.Length < idx) {
        ctrl := g_gui.AddText("x8 y0 w10 h" LINE_H " +0xC Hidden", "")
        g_pool.Push(ctrl)
    }
    return g_pool[idx]
}

f_hide_from(startIdx) {
    global g_pool
    loop g_pool.Length - startIdx + 1 {
        g_pool[startIdx + A_Index - 1].Visible := false
    }
}

; draws one line (array of {t, color} segments) at the given y, using and
; advancing segCounter (a {n: ...} box so it can be updated by reference)
f_draw_line(segments, y, segCounterBox) {
    global CHAR_W, LINE_H
    x := 8
    for seg in segments {
        segCounterBox.n += 1
        ctrl := f_get_seg(segCounterBox.n)
        w := Max(6, StrLen(seg.t) * CHAR_W + 2)
        ctrl.Move(x, y, w, LINE_H)
        ctrl.SetFont("s9 c" seg.color, "Consolas")
        ctrl.Text := seg.t
        ctrl.Visible := true
        x += w
    }
}

f_pct_segment(chanceStr, color) {
    padded := chanceStr "%"
    global PCT_CHARS
    if (StrLen(padded) < PCT_CHARS)
        padded .= SubStr("                    ", 1, PCT_CHARS - StrLen(padded))
    return { t: padded, color: color }
}

;===============================================================================
; MAIN LOOP
;===============================================================================

f_tick() {
    global g_enabled, g_show_target, g_last_text, g_forceRedraw
    global CAPTURE_X, CAPTURE_Y, CAPTURE_W, CAPTURE_H, UPSCALE, TEMP_IMG
    global OVERLAY_X, OVERLAY_Y, OVERLAY_W, NAME_AREA_H, LINE_H
    global COLOR_DROP, COLOR_SPOIL, g_screen, g_current_npc

    if !g_enabled || !g_show_target
        return

    f_capture_and_save(CAPTURE_X, CAPTURE_Y, CAPTURE_W, CAPTURE_H, UPSCALE, TEMP_IMG)
    raw := f_ocr(TEMP_IMG)

    if (raw = g_last_text)
        return
    g_last_text := raw

    y := NAME_AREA_H
    seg := { n: 0 }

    if (raw = "") {
        g_text.Text := "No target"
        g_dropHeader.Visible := false
        g_spoilHeader.Visible := false
        g_expandBtn.Visible := false
        g_current_npc := ""
        f_hide_from(1)
        g_gui.Move(, , OVERLAY_W, NAME_AREA_H + LINE_H + 10)
        return
    }

    result := f_best_npc_match(raw)
    if !result.matched {
        g_text.Text := raw " (?)"
        g_dropHeader.Visible := false
        g_spoilHeader.Visible := false
        g_expandBtn.Visible := false
        g_current_npc := ""
        f_hide_from(1)
        g_gui.Move(, , OVERLAY_W, NAME_AREA_H + LINE_H + 10)
        return
    }

    ; OCR noise (a stray misread character, a case flip, etc.) can make raw
    ; text differ slightly between polls even while facing the same,
    ; stationary target. Without this check, every such blip would still
    ; pass the raw-text comparison above and trigger a full rebuild/resize
    ; of the overlay, which is what caused the visible flicker. Since the
    ; fuzzy match already resolved to the same NPC as last tick, there is
    ; nothing new to show - skip the redraw entirely. g_forceRedraw lets the
    ; expand/collapse button bypass this (otherwise clicking it while still
    ; facing the same target - the common case - would silently do nothing).
    skipRedraw := (result.name = g_current_npc) && !g_forceRedraw
    g_forceRedraw := false
    if skipRedraw
        return

    g_text.Text := f_npc_header(result.name)
    g_current_npc := result.name

    ; some names in npc_names.txt (the client's own full NPC name list)
    ; don't correspond to any monster entry in the server's DB.json export
    ; (e.g. harvest nodes like "Ivory Fungus") - matched fine by name, but
    ; with nothing to show. Without this check, expanding gave a big empty
    ; box, which read as broken. Hide the expand button entirely instead.
    key := StrLower(result.name)
    hasAnyData := g_npc_info.Has(key) || g_npc_drops.Has(key) || g_npc_attr.Has(key)
    if !hasAnyData {
        g_expandBtn.Visible := false
        g_dropHeader.Visible := false
        g_spoilHeader.Visible := false
        f_hide_from(1)
        g_gui.Move(, , OVERLAY_W, NAME_AREA_H + 10)
        return
    }

    g_expandBtn.Visible := true

    if !g_panelExpanded {
        g_dropHeader.Visible := false
        g_spoilHeader.Visible := false
        f_hide_from(1)
        g_gui.Move(, , OVERLAY_W, NAME_AREA_H + 10)
        return
    }

    infoLines := f_format_info(result.name)
    for line in infoLines {
        f_draw_line(line, y, seg)
        y += LINE_H
    }
    y += 6

    key := StrLower(result.name)
    hasPassive := g_npc_attr.Has(key) && g_npc_attr[key].passive != ""
    hasActive := g_npc_attr.Has(key) && g_npc_attr[key].active != ""
    if (hasPassive || hasActive) {
        f_draw_line([f_lbl(f_divider("TRAITS", OVERLAY_W // 7))], y, seg)
        y += LINE_H
        if hasPassive {
            for clause in f_split_attr_clauses(g_npc_attr[key].passive) {
                f_draw_line([f_format_attr_line(clause)], y, seg)
                y += LINE_H
            }
        }
        if hasActive {
            for clause in f_split_attr_clauses(g_npc_attr[key].active) {
                f_draw_line([f_format_attr_line_active(clause)], y, seg)
                y += LINE_H
            }
        }
    }

    y += LINE_H // 2

    data := f_get_drops(result.name)

    if (data.drop.Length > 0) {
        g_dropHeader.Move(, y, , LINE_H)
        g_dropHeader.Text := f_divider("DROP", OVERLAY_W // 7)
        g_dropHeader.Visible := true
        y += LINE_H
        for r in data.drop {
            qty := (r.min = r.max) ? r.min : (r.min "-" r.max)
            f_draw_line([f_pct_segment(r.chanceStr, COLOR_DROP), f_lbl(r.item " x" qty)], y, seg)
            y += LINE_H
        }
    } else {
        g_dropHeader.Visible := false
    }

    if (data.spoil.Length > 0) {
        g_spoilHeader.Move(, y, , LINE_H)
        g_spoilHeader.Text := f_divider("SPOIL", OVERLAY_W // 7)
        g_spoilHeader.Visible := true
        y += LINE_H
        for r in data.spoil {
            qty := (r.min = r.max) ? r.min : (r.min "-" r.max)
            f_draw_line([f_pct_segment(r.chanceStr, COLOR_SPOIL), f_lbl(r.item " x" qty)], y, seg)
            y += LINE_H
        }
    } else {
        g_spoilHeader.Visible := false
    }

    if (data.drop.Length = 0 && data.spoil.Length = 0)
        y += LINE_H

    f_hide_from(seg.n + 1)

    newH := y + 10
    maxH := g_screen.h - OVERLAY_Y - 10
    if (newH > maxH)
        newH := maxH
    g_gui.Move(, , OVERLAY_W, newH)
}

f_calibrate(*) {
    global TEMP_DEBUG_IMG, SCALE_X, SCALE_Y
    ; wide, generous region regardless of current OCR crop settings, so it's
    ; easy to see full context and pick precise tight-crop boundaries
    f_capture_and_save(Round(880 * SCALE_X), 0, Round(260 * SCALE_X), Round(40 * SCALE_Y), 1, TEMP_DEBUG_IMG)
    TrayTip("L2 Target OCR", "Saved calibration screenshot to:`n" TEMP_DEBUG_IMG)
}
