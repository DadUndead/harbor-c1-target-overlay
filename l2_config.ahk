;===============================================================================
; L2 TARGET OVERLAY - OCR VERSION (Chronicle 1 client)
;
; No Cheat Engine, no memory reading, no injection at all. Just:
;   1) screenshot the small screen area where the game itself draws the
;      target's name (the target HP bar at the top of the screen),
;   2) run that image through Tesseract OCR,
;   3) show the recognized name in a small always-on-top overlay window.
;
; ------------------------------------------------------------------------
; SETUP:
;
; 1) Tesseract OCR must be installed (already done via winget on this PC:
;    "C:\Program Files\Tesseract-OCR\tesseract.exe"). If you reinstall
;    Windows/move this to another PC, run:
;      winget install --id UB-Mannheim.TesseractOCR
;
; 2) CAPTURE_X / CAPTURE_Y / CAPTURE_W / CAPTURE_H below must match where
;    YOUR target name text appears on screen. Defaults are tuned for 1920x1080
;    with the target frame in its default UI position (top area, right of the
;    skill bar). If your UI is moved/resized, or your resolution differs,
;    these numbers need adjusting - see CALIBRATION below.
;
; ------------------------------------------------------------------------
; CALIBRATION (do this once):
;
;   Run this script, target a monster with a short name, press End.
;   It saves a screenshot of exactly the capture region to:
;     %A_Temp%\l2_target_capture_debug.bmp
;   Open that file - if the name text isn't fully inside the crop (cut off,
;   or extra clutter from other UI elements), adjust CAPTURE_X/Y/W/H below
;   and press End again to re-check, until the crop shows just the name text
;   with a little margin.
;
; ------------------------------------------------------------------------
; This file: all CONFIG constants, shared globals, and the handful of tiny
; save/load helpers config-loading itself depends on. #Include'd first (via
; the main script) so every other module can rely on these being defined.
;===============================================================================

; ------------------------------- CONFIG ---------------------------------

; All CAPTURE_*/OVERLAY_Y numbers below were tuned by hand at 1920x1080. To
; work out-of-the-box on other players' screens, we read the client's own
; System\Option.ini (GamePlayViewportX/Y - the resolution the client is
; actually running at) and scale everything proportionally. This won't be
; pixel-perfect if someone has moved/resized their UI, but it gets close
; enough that F9 calibration only needs small tweaks instead of starting
; from scratch - see CALIBRATION above.
REF_W := 1920, REF_H := 1080

f_detect_resolution() {
    global REF_W, REF_H
    iniPath := A_ScriptDir "\System\Option.ini"
    w := 0, h := 0
    if FileExist(iniPath) {
        w := IniRead(iniPath, "Video", "GamePlayViewportX", 0)
        h := IniRead(iniPath, "Video", "GamePlayViewportY", 0)
    }
    if (!w || !h)
        return { w: REF_W, h: REF_H }
    return { w: w + 0, h: h + 0 }
}

g_screen := f_detect_resolution()
SCALE_X := g_screen.w / REF_W
SCALE_Y := g_screen.h / REF_H

CAPTURE_X := Round(888 * SCALE_X)
CAPTURE_Y := Round(2 * SCALE_Y)
CAPTURE_W := Round(128 * SCALE_X)
CAPTURE_H := Round(18 * SCALE_Y)
UPSCALE   := 4          ; upscaling factor before OCR - helps a lot with small UI text

TESSERACT_EXE := "C:\Program Files\Tesseract-OCR\tesseract.exe"
TEMP_IMG       := A_Temp "\l2_target_capture.bmp"
TEMP_DEBUG_IMG := A_Temp "\l2_target_capture_debug.bmp"
TEMP_OUT_BASE  := A_Temp "\l2_target_ocr"
NPC_NAMES_FILE := A_ScriptDir "\npc_names.txt"
NPC_DROPS_FILE := A_ScriptDir "\npc_drops.txt"
NPC_INFO_FILE  := A_ScriptDir "\npc_info.txt"
NPC_OVERRIDES_FILE := A_ScriptDir "\npc_overrides.txt"   ; user corrections (e.g. aggro), survives base-DB updates
NPC_ATTR_FILE := A_ScriptDir "\npc_attributes.txt"   ; name, respawn, passive attributes, active attributes (from Prima guide)
WINDOW_POS_FILE := A_ScriptDir "\window_positions.ini"   ; remembers dragged window positions between runs
GEMINI_API_KEY_FILE := A_ScriptDir "\gemini_api_key.txt"   ; OLD (pre-1.2.0) plaintext-file storage - only read once, to migrate, then deleted
GEMINI_REG_KEY := "HKCU\Software\L2TargetOverlayHarborC1"   ; the key itself now lives here instead of a file, so it can never end up
    ; inside the tool's own folder and get accidentally zipped/screenshotted/shared alongside it
GEMINI_MODEL_FILE := A_ScriptDir "\gemini_model.txt"   ; optional - one line, overrides which model to call
GEMINI_MODEL_DEFAULT := "gemini-3.5-flash-lite"   ; Google's free-tier model names change over time (this
    ; replaced gemini-2.0-flash, whose free quota had dropped to 0) - the model file lets that be fixed by
    ; editing a text file instead of needing a recompile
GEMINI_LOG_FILE := A_ScriptDir "\gemini_debug.log"   ; every Gemini failure's real response body gets logged here for troubleshooting

APP_VERSION := "1.4.0"
UPDATE_GITHUB_OWNER := "dadundead"
UPDATE_GITHUB_REPO := "harbor-c1-target-overlay"

; Gemini failures fall back to Google Translate silently (see f_translate_
; outgoing/f_translate_batch_gemini), so the chat window itself never shows
; *why* Gemini failed - only that it did (via the [T] vs [G] tag). This
; logs the actual HTTP status and response body (Google's error responses
; normally include a human-readable "message" field - e.g. bad API key,
; quota exceeded, wrong model name - far more useful than a bare "HTTP 429").
f_log_gemini_error(context, status, body) {
    global GEMINI_LOG_FILE
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " [" context "] HTTP " status ": " SubStr(body, 1, 500) "`n---`n", GEMINI_LOG_FILE, "UTF-8")
}

; returns the last-saved (x, y) for a named window, or the given defaults
; if it's never been moved (or this is a fresh install with no ini yet).
f_load_saved_pos(name, defaultX, defaultY) {
    global WINDOW_POS_FILE
    x := IniRead(WINDOW_POS_FILE, name, "x", defaultX)
    y := IniRead(WINDOW_POS_FILE, name, "y", defaultY)
    return { x: x + 0, y: y + 0 }
}

; same idea but for a capture zone's full rect (x/y/w/h) - used for the
; visual calibration zones, which are draggable AND resizable.
f_load_saved_rect(name, defaultX, defaultY, defaultW, defaultH) {
    global WINDOW_POS_FILE
    x := IniRead(WINDOW_POS_FILE, name, "x", defaultX)
    y := IniRead(WINDOW_POS_FILE, name, "y", defaultY)
    w := IniRead(WINDOW_POS_FILE, name, "w", defaultW)
    h := IniRead(WINDOW_POS_FILE, name, "h", defaultH)
    return { x: x + 0, y: y + 0, w: w + 0, h: h + 0 }
}

f_save_rect(name, x, y, w, h) {
    global WINDOW_POS_FILE
    IniWrite(x, WINDOW_POS_FILE, name, "x")
    IniWrite(y, WINDOW_POS_FILE, name, "y")
    IniWrite(w, WINDOW_POS_FILE, name, "w")
    IniWrite(h, WINDOW_POS_FILE, name, "h")
}

; how close (relative to name length) an OCR reading must be to a known NPC
; name before we trust the match; otherwise we show the raw OCR text with "?"
FUZZY_MAX_RATIO := 0.34

POLL_INTERVAL_MS := 700
TOGGLE_KEY        := "+ScrollLock"
CALIBRATE_KEY     := "End"

OVERLAY_W := 380
SCREEN_W  := g_screen.w
OVERLAY_X := SCREEN_W - OVERLAY_W - 15         ; hug the right edge
OVERLAY_Y := Round(105 * SCALE_Y)               ; just under the radar/compass

; ----------------------------- CHAT TRANSLATE ---------------------------
; Reads the game's own chat log window, OCRs it, and shows a live-translated
; (to Russian) copy in a separate overlay. Tuned by default for the chat box
; in its default bottom-left position at 1920x1080 - use CHAT_CALIBRATE_KEY
; to check/adjust CHAT_CAPTURE_X/Y/W/H the same way as the target capture.
CHAT_CAPTURE_X := Round(8 * SCALE_X)
CHAT_CAPTURE_Y := Round(905 * SCALE_Y)
CHAT_CAPTURE_W := Round(340 * SCALE_X)
CHAT_CAPTURE_H := Round(130 * SCALE_Y)
CHAT_UPSCALE   := 3

; ------------------------------ PARTY CLASSES ---------------------------
; C1's party window doesn't show anyone's class, which buffers need. Reads
; the vertical list of party-member names (top-left, under your own HP/MP)
; and looks each one up in player_classes.txt (nick -> class, exported
; from server data). Unknown nicks get a dropdown to set (and remember)
; their class by hand.
PARTY_CAPTURE_X := Round(0 * SCALE_X)
PARTY_CAPTURE_Y := Round(60 * SCALE_Y)
PARTY_CAPTURE_W := Round(160 * SCALE_X)
PARTY_CAPTURE_H := Round(290 * SCALE_Y)
PARTY_UPSCALE   := 3

PARTY_TEMP_IMG       := A_Temp "\l2_party_capture.bmp"
PARTY_TEMP_PNG       := A_Temp "\l2_party_capture.png"   ; PNG capture for Gemini vision (Tesseract reads this fine too)
PARTY_TEMP_DEBUG_IMG := A_Temp "\l2_party_capture_debug.bmp"
PARTY_TEMP_OUT_BASE  := A_Temp "\l2_party_ocr"

PARTY_CALIBRATE_KEY := "Insert"
PARTY_MAX_MEMBERS   := 9   ; classic L2 party size cap

PLAYER_CLASSES_FILE := A_ScriptDir "\player_classes.txt"   ; nick<TAB>class<TAB>level<TAB>clan - base DB, exported from the server
PLAYER_CLASS_OVERRIDES_FILE := A_ScriptDir "\player_class_overrides.txt"   ; your manual corrections/additions, layered on top

PARTY_OVERLAY_W := 260
PARTY_OVERLAY_X := Round(170 * SCALE_X)         ; just right of the native party list
PARTY_OVERLAY_Y := Round(60 * SCALE_Y)
PARTY_ROW_H     := 26
PARTY_BTN_H     := 24

g_player_classes := Map()             ; lowercase nick -> class (from player_classes.txt)
g_player_class_overrides := Map()     ; lowercase nick -> class (manual correction, takes priority)
g_class_list := []                    ; sorted unique class names, for the dropdowns
g_player_nick_list := []              ; original-casing nicks, for fuzzy-matching OCR'd party names
g_show_party := false

; restore hand-adjusted capture zones from a previous session, if any (see
; the "Calibrate" checkbox / visual zone overlays further down)
capRect := f_load_saved_rect("capture_target", CAPTURE_X, CAPTURE_Y, CAPTURE_W, CAPTURE_H)
CAPTURE_X := capRect.x, CAPTURE_Y := capRect.y, CAPTURE_W := capRect.w, CAPTURE_H := capRect.h
chatCapRect := f_load_saved_rect("capture_chat", CHAT_CAPTURE_X, CHAT_CAPTURE_Y, CHAT_CAPTURE_W, CHAT_CAPTURE_H)
CHAT_CAPTURE_X := chatCapRect.x, CHAT_CAPTURE_Y := chatCapRect.y, CHAT_CAPTURE_W := chatCapRect.w, CHAT_CAPTURE_H := chatCapRect.h
partyCapRect := f_load_saved_rect("capture_party", PARTY_CAPTURE_X, PARTY_CAPTURE_Y, PARTY_CAPTURE_W, PARTY_CAPTURE_H)
PARTY_CAPTURE_X := partyCapRect.x, PARTY_CAPTURE_Y := partyCapRect.y, PARTY_CAPTURE_W := partyCapRect.w, PARTY_CAPTURE_H := partyCapRect.h

CHAT_TEMP_IMG       := A_Temp "\l2_chat_capture.bmp"
CHAT_TEMP_PNG       := A_Temp "\l2_chat_capture.png"   ; PNG capture for Gemini vision (same file serves the Tesseract fallback too)
CHAT_TEMP_DEBUG_IMG := A_Temp "\l2_chat_capture_debug.bmp"
CHAT_TEMP_OUT_BASE  := A_Temp "\l2_chat_ocr"

CHAT_CALIBRATE_KEY    := "Home"
CHAT_LOG_MAX          := 4   ; how many recent chat lines to keep on screen, for the incremental OCR+text pipeline (kept low so the window fits above the skill bar by default)
CHAT_LOG_MAX_VISION    := 40   ; the Gemini-vision pipeline instead replaces the whole log with one full snapshot of the visible chat pane each click - this just guards against a pathological over-long response

CHAT_OVERLAY_W := 500
CHAT_OVERLAY_X := Round(360 * SCALE_X)          ; just right of the native chat box
CHAT_OVERLAY_Y := Round(880 * SCALE_Y)
CHAT_LINE_H    := 15
CHAT_CHAR_W    := 6
CHAT_BTN_H     := 24

g_chat_lang := "eng"   ; set to "eng+rus" at startup once rus.traineddata is confirmed present
g_gemini_key := ""   ; loaded from gemini_api_key.txt at startup, if present - see f_translate_batch_gemini()
g_gemini_model := ""   ; loaded from gemini_model.txt (or GEMINI_MODEL_DEFAULT) at startup

; ------------------------------- BUFF TIMER -----------------------------
; Small countdown window next to the game's own buff icon bar (top-left).
; Manual, not automated - OCR can't reliably read the tiny per-icon buff
; countdown, so instead: type the buff's duration in minutes and hit Start
; the moment you cast it, same as glancing at a kitchen timer.
BUFF_TIMER_X := Round(400 * SCALE_X)
BUFF_TIMER_Y := Round(2 * SCALE_Y)
BUFF_TIMER_W := 224
BUFF_TIMER_DEFAULT_MIN := 20

; -------------------------------- FIND NPC -------------------------------
; Types /target <name> into game chat, once per click.
FIND_OVERLAY_X := Round(400 * SCALE_X)
FIND_OVERLAY_Y := Round(40 * SCALE_Y)
FIND_OVERLAY_W := 172

g_buff_running := false
g_buff_end_tick := 0
g_buff_duration_min := BUFF_TIMER_DEFAULT_MIN
g_buff_beeped_5min := false   ; one-shot flag so the 5-minute-left beep fires exactly once per run
g_buff_beeped_1min := false   ; same, for the 1-minute-left mark
g_buff_muted := false
g_buff_blink_count := 0

; -------------------------------- MENU ----------------------------------
; Small control panel, top-right corner just left of the radar/compass.
; Checkboxes show/hide the other three windows independently - all off by
; default, so nothing but this menu appears until you turn something on.
MENU_W := 478
MENU_X := SCREEN_W - MENU_W - 110   ; leaves room for the radar to its right
MENU_Y := Round(5 * SCALE_Y)

g_show_target := false
g_show_timer  := false
g_show_chat   := false
g_show_calibrate := false
g_show_find := false

; --------------------------------------------------------------------------

g_enabled   := true    ; menu is visible immediately on launch; Shift+ScrollLock is a master hide/show toggle
g_last_text := ""
g_pToken    := 0
g_npc_names := []
g_npc_drops := Map()   ; lowercase npc name -> array of {type, item, chance, min, max}
g_npc_info  := Map()   ; lowercase npc name -> {level, hp, mp, patk, pdef, matk, mdef, atkspd, critical, race, aggressive, debuffs}
g_npc_attr  := Map()   ; lowercase npc name -> {respawn, passive, active} (from Prima guide bestiary, pp.202-223)
g_current_npc := ""    ; name of the NPC currently shown in the overlay (for the aggro button)
g_panelExpanded := false   ; whether the detail panel (stats/traits/drop/spoil) is shown
g_forceRedraw := false   ; set by the expand/collapse button to bypass the same-NPC redraw skip below

g_chat_last_lines := []   ; raw OCR'd chat lines from the previous poll, to detect only new lines
g_chat_log := []          ; recent {name, text, translated} entries shown in the chat overlay

; ------------------------- SHARED COLORS/SIZES ---------------------------
; used across the target panel, party classes and chat translate windows.
COLOR_STAT     := "5AB4FF"   ; NPC parameter values
COLOR_DROP     := "FFD700"   ; drop chance %
COLOR_SPOIL    := "FF9933"   ; spoil chance %
COLOR_ATTR_POS := "FF5555"   ; passive attribute lines starting with "+N%"
COLOR_ATTR_NEG := "55FF55"   ; passive attribute lines starting with "-N%"
COLOR_ATTR_ACTIVE := "FF9933"   ; active ability lines (always orange)
COLOR_CHAT_TRANSLATED := "FFEE58"   ; bright yellow - marks a line that was actually translated, distinct from the game's own per-channel color (kept for lines already in the target language)
