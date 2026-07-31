;===============================================================================
; HOTKEYS
;===============================================================================

Hotkey(TOGGLE_KEY, f_toggle_enabled)
Hotkey(CALIBRATE_KEY, f_calibrate)
Hotkey(CHAT_CALIBRATE_KEY, f_calibrate_chat)
Hotkey(PARTY_CALIBRATE_KEY, f_calibrate_party)

f_check_tesseract() {
    global TESSERACT_EXE
    candidates := [A_ScriptDir "\Tesseract-OCR\tesseract.exe", TESSERACT_EXE
        , "C:\Program Files\Tesseract-OCR\tesseract.exe", "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]
    for c in candidates {
        if FileExist(c) {
            TESSERACT_EXE := c
            return true
        }
    }
    return false
}

f_try_auto_install_tesseract() {
    MsgBox(T("tesseract_installing_msg"), "L2 Target Overlay", "OK Icon! T2")
    RunWait('winget install --id UB-Mannheim.TesseractOCR --silent --accept-package-agreements --accept-source-agreements', , "Hide")
}

; chat OCR needs to read Cyrillic text too (to tell whether a message is
; already Russian), which the default Tesseract install doesn't include -
; only the "eng" language data ships by default. Fetches the official
; rus.traineddata (~15MB) once and drops it next to the other language
; files. On failure, chat OCR still runs in English-only mode (Cyrillic
; messages just won't be read correctly) rather than blocking startup.
f_ensure_rus_traineddata() {
    global TESSERACT_EXE, g_chat_lang
    tessdataDir := RegExReplace(TESSERACT_EXE, "tesseract\.exe$", "tessdata")
    rusFile := tessdataDir "\rus.traineddata"
    if FileExist(rusFile) {
        g_chat_lang := "eng+rus"
        return
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://github.com/tesseract-ocr/tessdata/raw/main/rus.traineddata", false)
        try whr.Option[9] := 0x00000800   ; SecureProtocols: TLS 1.2
        whr.SetTimeouts(5000, 5000, 30000, 60000)
        whr.Send()
        if (whr.Status != 200)
            return
        stream := ComObject("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        stream.Write(whr.ResponseBody)
        stream.SaveToFile(rusFile, 2)
        stream.Close()
        if FileExist(rusFile)
            g_chat_lang := "eng+rus"
    } catch {
        ; no internet / blocked - fall back silently, g_chat_lang stays "eng"
    }
}

; restore last session's checkbox state - each window is shown immediately
; if it was left checked, same as if the user had just clicked it. Runs
; last (after every window has been created) since it touches all of them.
g_show_timer := IniRead(WINDOW_POS_FILE, "checkboxes", "timer", 0) + 0
g_show_target := IniRead(WINDOW_POS_FILE, "checkboxes", "mobinfo", 0) + 0
g_show_chat := IniRead(WINDOW_POS_FILE, "checkboxes", "translate", 0) + 0
g_show_calibrate := IniRead(WINDOW_POS_FILE, "checkboxes", "calibrate", 0) + 0
g_show_party := IniRead(WINDOW_POS_FILE, "checkboxes", "party", 0) + 0
g_show_find := IniRead(WINDOW_POS_FILE, "checkboxes", "find", 0) + 0
g_chkTimer.Value := g_show_timer
g_chkMobInfo.Value := g_show_target
g_chkTranslate.Value := g_show_chat
g_chkParty.Value := g_show_party
g_chkFind.Value := g_show_find
if g_show_timer
    g_buffGui.Show("NoActivate")
if g_show_target
    g_gui.Show("NoActivate")
if g_show_chat
    g_chatGui.Show("NoActivate")
if g_show_calibrate {
    g_zoneTargetGui.Show("NoActivate")
    g_zoneChatGui.Show("NoActivate")
    g_zonePartyGui.Show("NoActivate")
    WinGetPos(&mx, &my, , &mh, "ahk_id " g_menuGui.Hwnd)
    g_endCalibGui.Move(mx, my + mh + 4)
    g_endCalibGui.Show("NoActivate")
}
if g_show_party
    g_partyGui.Show("NoActivate")
if g_show_find
    g_findGui.Show("NoActivate")

if !f_check_tesseract() {
    result := MsgBox(T("tesseract_not_found_msg"), T("tesseract_not_found_title"), "YesNo Icon!")
    if (result = "Yes") {
        f_try_auto_install_tesseract()
        if !f_check_tesseract() {
            MsgBox(T("tesseract_autoinstall_failed_msg"), "L2 Target Overlay", "OK Icon!")
            ExitApp()
        }
    } else {
        ExitApp()
    }
}

f_gdiplus_startup()
f_ensure_rus_traineddata()
try g_gemini_key := RegRead(GEMINI_REG_KEY, "GeminiApiKey")
; one-time migration from the old plaintext-file storage (pre-1.2.0) - that
; file lived right next to the exe, which is exactly the kind of file that's
; easy to accidentally zip/screenshot/share alongside the tool. The registry
; (tied to this Windows account only) doesn't have that risk.
if (g_gemini_key = "" && FileExist(GEMINI_API_KEY_FILE)) {
    migratedKey := Trim(FileRead(GEMINI_API_KEY_FILE, "UTF-8"), " `t`r`n")
    if (migratedKey != "") {
        RegWrite(migratedKey, "REG_SZ", GEMINI_REG_KEY, "GeminiApiKey")
        g_gemini_key := migratedKey
    }
    try FileDelete(GEMINI_API_KEY_FILE)
}
g_gemini_model := FileExist(GEMINI_MODEL_FILE) ? Trim(FileRead(GEMINI_MODEL_FILE, "UTF-8"), " `t`r`n") : GEMINI_MODEL_DEFAULT
f_load_npc_names()
f_load_npc_drops()
f_load_npc_info()
f_load_npc_overrides()
f_load_npc_attributes()
f_load_npc_custom()
f_load_player_classes()
f_load_player_class_overrides()

SetTimer(f_tick, POLL_INTERVAL_MS)
SetTimer(f_check_for_update, -100)   ; deferred so a slow/hung network check can never delay the overlay's startup

TrayTip("L2 Target OCR", "Loaded " g_npc_names.Length " NPC names, " g_npc_drops.Count " with drop/spoil, " g_npc_info.Count " with stats, " g_npc_attr.Count " with Prima attributes, " g_npc_overrides.Count " user corrections, " g_player_classes.Count " player classes."
    (g_chat_lang = "eng+rus" ? T("traytip_chat_ready") : T("traytip_chat_not_ready"))
    (g_gemini_key != "" ? f_fmt(T("traytip_gemini_on"), g_gemini_model) : T("traytip_gemini_off")))
