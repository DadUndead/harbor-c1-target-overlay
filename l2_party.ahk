;===============================================================================
; PARTY CLASSES OVERLAY (separate window) - C1's party list shows no class
; info, which buffers need. "Scan" OCRs the party member list and shows
; each nick's class next to it (looked up from player_classes.txt); unknown
; nicks get a dropdown instead, and picking one saves it as a correction.
;===============================================================================

g_partyGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "L2PartyClasses")
g_partyGui.BackColor := "202020"
g_partyGui.SetFont("s9", "Consolas")
g_partyScanBtn := g_partyGui.AddButton("x8 y6 w80 h24", "Scan")
g_partyScanBtn.OnEvent("Click", f_on_party_scan_click)
; there's no way to tell "no party right now" from "something else is
; drawn in that screen area" from OCR content alone - solo (or between
; scans while the party UI is transitioning), Scan will read whatever's
; actually behind the capture zone instead. Clear wipes a bad read.
g_partyClearBtn := g_partyGui.AddButton("x92 y6 w70 h24", "Clear")
g_partyClearBtn.OnEvent("Click", f_on_party_clear_click)

PARTY_ROWS_START_Y := 40
g_partyRows := []   ; pooled row controls: {nameCtrl, classText, classCombo, editBtn, saveBtn, nick}

; rows are created lazily (on first Scan, well after startup has loaded
; g_class_list) rather than up front, so the dropdowns always have the
; full class list available the moment they're created.
;
; The name field is a real Edit box, not a Text label - two reasons: it
; gives OCR corrections somewhere to go (retype the nick if it was
; misread), and an Edit box has its own opaque white background regardless
; of the window's dark theme, unlike a Text control (which was rendering
; near-black-on-black and unreadable, since no explicit font color had
; been set for it).
f_get_party_row(idx) {
    global g_partyRows, g_partyGui, PARTY_ROW_H, g_class_list
    while (g_partyRows.Length < idx) {
        g_partyGui.SetFont("s9", "Consolas")
        nameCtrl := g_partyGui.AddEdit("x8 y0 w90 h20 Hidden", "")
        classText := g_partyGui.AddText("x100 y0 w110 h20 +0xC Hidden", "")
        classCombo := g_partyGui.AddDropDownList("x100 y0 w110 h150 Hidden", g_class_list)
        ; Consolas has no pencil glyph (renders as a blank box) - same fix
        ; as the buff timer's ▶/↺ icons.
        g_partyGui.SetFont("s10", "Segoe UI Symbol")
        editBtn := g_partyGui.AddButton("x212 y0 w20 h20 Hidden", "✎")
        g_partyGui.SetFont("s9", "Consolas")
        saveBtn := g_partyGui.AddButton("x212 y0 w36 h20 Hidden", "OK")
        row := { nameCtrl: nameCtrl, classText: classText, classCombo: classCombo
            , editBtn: editBtn, saveBtn: saveBtn, nick: "", y: 0 }
        editBtn.OnEvent("Click", f_on_party_edit_click.Bind(row))
        saveBtn.OnEvent("Click", f_on_party_save_click.Bind(row))
        ; retyping the nick and tabbing/clicking away re-checks the DB
        ; immediately - if the corrected name is already known, the class
        ; shows up right away with no extra click needed.
        nameCtrl.OnEvent("LoseFocus", f_on_party_name_edited.Bind(row))
        g_partyRows.Push(row)
    }
    return g_partyRows[idx]
}

f_hide_party_rows_from(startIdx) {
    global g_partyRows
    loop g_partyRows.Length - startIdx + 1 {
        row := g_partyRows[startIdx + A_Index - 1]
        row.nameCtrl.Visible := false
        row.classText.Visible := false
        row.classCombo.Visible := false
        row.editBtn.Visible := false
        row.saveBtn.Visible := false
    }
}

; underscores in class names (as stored in player_classes.txt, e.g.
; "Silver_Ranger") read worse on screen than a plain space.
f_format_class_name(cls) {
    return StrReplace(cls, "_", " ")
}

; shows one row in either "matched" (class + pencil) or "unmatched"
; (dropdown + OK) layout at the given y - shared by the initial render and
; by re-checking a row after its name gets corrected.
f_apply_party_row_state(row, y, cls) {
    global COLOR_STAT
    row.y := y
    row.nameCtrl.Move(8, y, 90, 20)
    if (cls != "") {
        row.classText.Move(100, y, 110, 20)
        row.classText.SetFont("s9 c" COLOR_STAT, "Consolas")
        row.classText.Text := f_format_class_name(cls)
        row.classText.Visible := true
        row.classCombo.Visible := false
        row.editBtn.Move(212, y, 20, 20)
        row.editBtn.Visible := true
        row.saveBtn.Visible := false
    } else {
        row.classText.Visible := false
        row.editBtn.Visible := false
        row.classCombo.Move(100, y, 110, 150)
        row.classCombo.Value := 0
        row.classCombo.Visible := true
        row.saveBtn.Move(212, y, 36, 20)
        row.saveBtn.Text := "OK"
        row.saveBtn.Visible := true
    }
}

f_render_party_rows(members) {
    global PARTY_OVERLAY_W, PARTY_ROWS_START_Y, PARTY_ROW_H, g_partyGui, g_screen
    y := PARTY_ROWS_START_Y
    idx := 0
    for m in members {
        idx += 1
        row := f_get_party_row(idx)
        row.nick := m.nick
        row.nameCtrl.Text := m.nick
        row.nameCtrl.Visible := true
        f_apply_party_row_state(row, y, m.cls)
        y += PARTY_ROW_H
    }
    f_hide_party_rows_from(idx + 1)

    newH := y + 6
    WinGetPos(, &curY, , , "ahk_id " g_partyGui.Hwnd)
    maxH := g_screen.h - curY - 10
    if (newH > maxH)
        newH := maxH
    g_partyGui.Move(, , PARTY_OVERLAY_W, newH)
}

; fires when the name field loses focus (tabbed/clicked away from) - if the
; corrected text is now a known nick, show its class immediately instead
; of leaving the row stuck showing a dropdown for a name that's actually
; already on file.
f_on_party_name_edited(row, *) {
    nick := Trim(row.nameCtrl.Text)
    if (nick = "")
        return
    row.nick := nick
    f_apply_party_row_state(row, row.y, f_get_player_class(nick))
}

; switches an already-matched row into edit mode, pre-selecting its
; current class so fixing a wrong guess is a one-click change.
f_on_party_edit_click(row, *) {
    global g_class_list
    nick := Trim(row.nameCtrl.Text)
    row.classText.Visible := false
    row.editBtn.Visible := false
    curCls := f_get_player_class(nick)
    selIdx := 0
    for i, c in g_class_list {
        if (c = curCls) {
            selIdx := i
            break
        }
    }
    row.classCombo.Value := selIdx
    row.classCombo.Visible := true
    row.saveBtn.Text := "OK"
    row.saveBtn.Visible := true
}

f_on_party_save_click(row, *) {
    global g_class_list, COLOR_STAT
    selIdx := row.classCombo.Value
    if (selIdx < 1 || selIdx > g_class_list.Length)
        return
    cls := g_class_list[selIdx]
    ; read the nick fresh - the user may have just corrected a misread OCR
    ; name in the same pass before picking its class
    nick := Trim(row.nameCtrl.Text)
    if (nick = "")
        return
    row.nick := nick
    f_save_player_class_override(nick, cls)
    row.classCombo.Visible := false
    row.saveBtn.Visible := false
    row.classText.SetFont("s9 c" COLOR_STAT, "Consolas")
    row.classText.Text := f_format_class_name(cls)
    row.classText.Visible := true
    row.editBtn.Visible := true
}

; catches the specific noise pattern seen in practice: short garbled
; tokens made of only 1-2 distinct characters (like "eee", "eeeO") from
; the HP/MP bar graphic under each name. Real nicknames overwhelmingly
; have more character variety than that, so this rarely if ever false-
; positives on a genuine (even short) name.
f_looks_like_party_noise(s) {
    if (StrLen(s) < 3)
        return true
    ; real L2 nicknames never contain a space - Tesseract inserts one as a
    ; word-segmentation artifact for multi-word text (e.g. UI labels from
    ; whatever's behind the capture zone if there's no party at all right
    ; now), even though space isn't in the OCR whitelist itself.
    if InStr(s, " ")
        return true
    distinct := Map()
    loop parse s
        distinct[A_LoopField] := true
    return (distinct.Count <= 2)
}

f_on_party_scan_click(*) {
    global PARTY_CAPTURE_X, PARTY_CAPTURE_Y, PARTY_CAPTURE_W, PARTY_CAPTURE_H, PARTY_UPSCALE, PARTY_TEMP_PNG
    global g_player_nick_list, g_gemini_key

    ; one PNG capture serves both paths - Gemini's vision API needs PNG
    ; (won't take BMP), and Tesseract reads PNG just as well.
    f_capture_and_save_ex(PARTY_CAPTURE_X, PARTY_CAPTURE_Y, PARTY_CAPTURE_W, PARTY_CAPTURE_H, PARTY_UPSCALE, PARTY_TEMP_PNG, "{557CF401-1A04-11D3-9A73-0000F81EF32E}")

    raw := ""
    confirmedEmpty := false
    if (g_gemini_key != "") {
        vres := f_gemini_vision_party(PARTY_TEMP_PNG)
        if (StrUpper(vres.text) = "NONE")
            confirmedEmpty := true   ; Gemini positively says there's no party list right now - trust that, skip Tesseract
        else if (vres.text != "")
            raw := vres.text
        ; else: the Gemini call itself failed (network/quota/parse) - raw
        ; stays "" and falls through to the Tesseract fallback below
    }

    if (raw = "" && !confirmedEmpty)
        raw := f_ocr_party(PARTY_TEMP_PNG)
    if (confirmedEmpty) {
        ; Gemini positively confirmed there's no party list right now -
        ; clear any stale rows from a previous scan instead of leaving
        ; them showing.
        f_render_party_rows([])
        return
    }
    if (raw = "")
        return

    members := []
    for line in StrSplit(raw, "`n", "`r") {
        t := Trim(line)
        if (t = "" || f_looks_like_party_noise(t))
            continue
        ; deliberately no cap here on how many candidate lines we consider -
        ; a couple of undetected noise lines shouldn't be able to push a
        ; genuine trailing party member off the end of the list. Worst
        ; case is a couple of extra garbage rows to correct/ignore, which
        ; is a much smaller problem than silently losing a real member.
        match := f_best_name_match(t, g_player_nick_list, 0.3)
        nick := match.matched ? match.name : t
        members.Push({ nick: nick, cls: f_get_player_class(nick) })
    }
    f_render_party_rows(members)
}

f_on_party_clear_click(*) {
    global PARTY_OVERLAY_W, PARTY_ROWS_START_Y, g_partyGui
    f_hide_party_rows_from(1)
    g_partyGui.Move(, , PARTY_OVERLAY_W, PARTY_ROWS_START_Y + 10)
}

partyPos := f_load_saved_pos("party", PARTY_OVERLAY_X, PARTY_OVERLAY_Y)
g_partyGui.Show("x" partyPos.x " y" partyPos.y " w" PARTY_OVERLAY_W " h" (PARTY_ROWS_START_Y + 10) " NoActivate Hide")
WinSetTransparent(230, g_partyGui)

;===============================================================================
; PARTY SCAN VIA GEMINI VISION - reads the party-list screenshot directly
; with an LLM instead of Tesseract, when a Gemini key is configured. Two
; real advantages over plain OCR here: it can read past the same kind of
; visual noise (HP/MP bar graphics) that kept leaking garbled extra
; "names" into Tesseract's output, and - more importantly - it can reason
; about whether the image is actually a party list at all, instead of just
; transcribing whatever's there. Falls back to f_ocr_party() (Tesseract)
; on any failure, or when no key is configured.
;===============================================================================

; Returns {text, err}. text is the newline-separated nick list, the literal
; string "NONE" (Gemini's positive confirmation that no party list is
; visible right now), or "" on any failure (caller should fall back to
; Tesseract in that case - "" and "NONE" are deliberately different
; outcomes).
f_gemini_vision_party(imgPath) {
    global g_gemini_key, g_gemini_model
    try {
        b64 := f_file_to_base64(imgPath)
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        url := "https://generativelanguage.googleapis.com/v1beta/models/" g_gemini_model ":generateContent?key=" g_gemini_key
        whr.Open("POST", url, false)
        try whr.Option[9] := 0x00000800   ; SecureProtocols: TLS 1.2
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.SetTimeouts(8000, 8000, 15000, 15000)

        prompt := "На этом изображении может быть список ников персонажей вашей группы (пати) в игре Lineage 2 - "
            . "каждый ник на отдельной строке, обычно рядом с полосками HP/MP. Ники состоят только из "
            . "латинских букв и цифр, без пробелов. Если список пати ДЕЙСТВИТЕЛЬНО виден на изображении - "
            . "выведи ТОЛЬКО сами ники, по одному на строку, точно как написано (сохраняя регистр и цифры), "
            . "без нумерации и пояснений. Если на изображении нет списка пати (там что-то другое - фон игры, "
            . "другое окно интерфейса и т.п., или список пуст) - выведи только слово NONE, без пояснений."

        body := '{"contents":[{"parts":[{"text":"' f_json_escape(prompt) '"},{"inline_data":{"mime_type":"image/png","data":"' b64 '"}}]}],"generationConfig":{"temperature":0.1}}'
        whr.Send(body)
        if (whr.Status != 200) {
            f_log_gemini_error("party-vision", whr.Status, whr.ResponseText)
            return { text: "", err: "Gemini HTTP " whr.Status }
        }
        resp := whr.ResponseText
        if !RegExMatch(resp, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
            f_log_gemini_error("party-vision", 200, resp)
            return { text: "", err: "Gemini: empty parse" }
        }
        return { text: Trim(f_json_unescape(m[1]), " `t`r`n"), err: "" }
    } catch as e {
        f_log_gemini_error("party-vision-exception", 0, e.Message)
        return { text: "", err: "Gemini: " e.Message }
    }
}

f_calibrate_party(*) {
    global PARTY_CAPTURE_X, PARTY_CAPTURE_Y, PARTY_CAPTURE_W, PARTY_CAPTURE_H, PARTY_TEMP_DEBUG_IMG
    f_capture_and_save(PARTY_CAPTURE_X, PARTY_CAPTURE_Y, PARTY_CAPTURE_W, PARTY_CAPTURE_H, 1, PARTY_TEMP_DEBUG_IMG)
    TrayTip("L2 Target OCR", "Saved party calibration screenshot to:`n" PARTY_TEMP_DEBUG_IMG)
}
