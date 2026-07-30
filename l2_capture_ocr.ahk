;===============================================================================
; GDI / GDI+ SCREEN CAPTURE
;===============================================================================

f_gdiplus_startup() {
    global g_pToken
    si := Buffer(24, 0)
    NumPut("UInt", 1, si, 0)
    DllCall("gdiplus\GdiplusStartup", "ptr*", &tok := 0, "ptr", si, "ptr", 0)
    g_pToken := tok
}

f_capture_and_save(x, y, w, h, scale, path) {
    f_capture_and_save_ex(x, y, w, h, scale, path, "{557CF400-1A04-11D3-9A73-0000F81EF32E}")   ; BMP encoder
}

; same capture, but with the image-format encoder CLSID as a parameter -
; the party-scan Gemini-vision path needs PNG (Gemini's API doesn't accept
; BMP), and Tesseract reads PNG just as well as BMP, so it's reused as the
; single capture for both instead of shooting the screen twice.
f_capture_and_save_ex(x, y, w, h, scale, path, encoderClsid) {
    dw := w * scale
    dh := h * scale

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdcMem     := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hBitmap    := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", dw, "int", dh, "ptr")
    hOld       := DllCall("SelectObject", "ptr", hdcMem, "ptr", hBitmap, "ptr")

    DllCall("SetStretchBltMode", "ptr", hdcMem, "int", 4) ; HALFTONE - smoother upscale
    DllCall("StretchBlt"
        , "ptr", hdcMem, "int", 0, "int", 0, "int", dw, "int", dh
        , "ptr", hdcScreen, "int", x, "int", y, "int", w, "int", h
        , "uint", 0x00CC0020) ; SRCCOPY

    DllCall("SelectObject", "ptr", hdcMem, "ptr", hOld, "ptr")

    pBitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBitmap, "ptr", 0, "ptr*", &pBitmap := 0)

    clsid := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "wstr", encoderClsid, "ptr", clsid)
    DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", path, "ptr", clsid, "ptr", 0)

    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    DllCall("DeleteObject", "ptr", hBitmap)
    DllCall("DeleteDC", "ptr", hdcMem)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
}

;===============================================================================
; OCR
;===============================================================================

f_ocr(path) {
    global TESSERACT_EXE, TEMP_OUT_BASE
    try FileDelete(TEMP_OUT_BASE ".txt")
    whitelist := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz '-"
    RunWait('"' TESSERACT_EXE '" "' path '" "' TEMP_OUT_BASE '" --psm 7 -c tessedit_char_whitelist="' whitelist '"', , "Hide")
    if !FileExist(TEMP_OUT_BASE ".txt")
        return ""
    text := FileRead(TEMP_OUT_BASE ".txt", "UTF-8")
    text := Trim(text, " `t`r`n")
    ; target names are letters/spaces/apostrophes/hyphens only - strip any
    ; trailing OCR artifacts (stray X from the close button, punctuation, digits)
    text := RegExReplace(text, "[^A-Za-z\x{00C0}-\x{017F} '\-]+$", "")
    text := Trim(text, " `t`r`n")
    return text
}

;===============================================================================
; CHAT OCR + TRANSLATION
;
; Separate from the target-name OCR above: reads a wider, multi-line region
; (the game's own chat log box), so it uses --psm 6 ("assume a uniform block
; of text") instead of --psm 7 ("single line"), and no character whitelist
; (chat has digits/punctuation/accented letters/Cyrillic, unlike names).
;===============================================================================

f_ocr_chat(path) {
    global TESSERACT_EXE, CHAT_TEMP_OUT_BASE, g_chat_lang
    try FileDelete(CHAT_TEMP_OUT_BASE ".txt")
    RunWait('"' TESSERACT_EXE '" "' path '" "' CHAT_TEMP_OUT_BASE '" --psm 6 -l ' g_chat_lang, , "Hide")
    if !FileExist(CHAT_TEMP_OUT_BASE ".txt")
        return ""
    return FileRead(CHAT_TEMP_OUT_BASE ".txt", "UTF-8")
}

; party names are a plain alphanumeric list (no spaces/punctuation, unlike
; chat) - a tighter whitelist than chat's helps avoid stray artifacts from
; the HP/MP bar graphics between rows getting misread as characters.
f_ocr_party(path) {
    global TESSERACT_EXE, PARTY_TEMP_OUT_BASE
    try FileDelete(PARTY_TEMP_OUT_BASE ".txt")
    whitelist := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    RunWait('"' TESSERACT_EXE '" "' path '" "' PARTY_TEMP_OUT_BASE '" --psm 6 -c tessedit_char_whitelist="' whitelist '"', , "Hide")
    if !FileExist(PARTY_TEMP_OUT_BASE ".txt")
        return ""
    return FileRead(PARTY_TEMP_OUT_BASE ".txt", "UTF-8")
}

; percent-encodes a string for use in a URL query parameter (UTF-8 bytes)
f_url_encode(s) {
    static unreserved := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    len := StrPut(s, "UTF-8") - 1
    buf := Buffer(len)
    StrPut(s, buf, "UTF-8")
    out := ""
    loop len {
        b := NumGet(buf, A_Index - 1, "UChar")
        if (b < 128 && InStr(unreserved, Chr(b)))
            out .= Chr(b)
        else
            out .= Format("%{:02X}", b)
    }
    return out
}

f_json_unescape(s) {
    s := StrReplace(s, '\"', '"')
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\\", "\")
    return s
}

; escapes a string for embedding inside a JSON string literal (building a
; request body) - the inverse of f_json_unescape above.
f_json_escape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return s
}

; calls the free, unofficial translate.googleapis.com endpoint (no API key -
; the same endpoint used by many hobby AHK translation scripts). Requires
; internet access; this is the one part of the tool that isn't fully local.
; Returns {text, lang} - text is "" if the request or parsing failed.
; Real response shape (confirmed by hand):
;   [[["translated","original",null,null,3,null,null,[[],[]],
;      [[["<hash>","es_en_2023q1.md"]],[["<hash>","en_ru_2023q1.md"]]]
;     ], ...more sentence tuples...
;    ], null, "es", ...]
;
; Each per-sentence tuple carries internal model-version hash pairs
; ["<hash>","<model file>"] nested a few levels deep inside it - which,
; to a regex just scanning for `["str","str"`, look identical to the
; legitimate (translated, original) pair at the tuple's own start. That's
; what previously leaked a 64-char hex string onto the end of the visible
; translation. Fix: walk brackets with actual depth-tracking so only the
; FIRST string of each TOP-LEVEL sentence tuple is ever read, never
; anything nested inside it.

; splits "[item1,item2,...]" into ["item1","item2",...], honoring string
; contents and nested brackets (only depth-0 commas are split points).
f_split_top_level(arr) {
    out := []
    len := StrLen(arr)
    if (len < 2)
        return out
    depth := 0, inQuotes := false, elemStart := 2, i := 2
    while (i <= len) {
        c := SubStr(arr, i, 1)
        if inQuotes {
            if (c = "\")
                i += 1
            else if (c = '"')
                inQuotes := false
        } else if (c = '"') {
            inQuotes := true
        } else if (c = "[") {
            depth += 1
        } else if (c = "]") {
            if (depth = 0) {
                out.Push(SubStr(arr, elemStart, i - elemStart))
                return out
            }
            depth -= 1
        } else if (c = "," && depth = 0) {
            out.Push(SubStr(arr, elemStart, i - elemStart))
            elemStart := i + 1
        }
        i += 1
    }
    return out
}

; returns the substring of the first top-level array inside s (the
; sentence-tuple list), via the same depth-tracking as f_split_top_level.
f_extract_first_json_array(s) {
    start := InStr(s, "[")
    if !start
        return ""
    start := InStr(s, "[", , start + 1)
    if !start
        return ""
    depth := 0, inQuotes := false, len := StrLen(s), i := start
    while (i <= len) {
        c := SubStr(s, i, 1)
        if inQuotes {
            if (c = "\")
                i += 1
            else if (c = '"')
                inQuotes := false
        } else if (c = '"') {
            inQuotes := true
        } else if (c = "[") {
            depth += 1
        } else if (c = "]") {
            depth -= 1
            if (depth = 0)
                return SubStr(s, start, i - start + 1)
        }
        i += 1
    }
    return ""
}

; base64-encodes a file's raw bytes via CryptBinaryToStringW (no built-in
; base64 function in AHK v2) - needed for Gemini's inline_data image field.
; Shared by both the party-scan and chat-translate Gemini-vision paths.
f_file_to_base64(path) {
    f := FileOpen(path, "r")
    len := f.Length
    buf := Buffer(len)
    f.RawRead(buf, len)
    f.Close()

    CRYPT_STRING_BASE64_NOCRLF := 0x40000001
    outLen := 0
    DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", len, "uint", CRYPT_STRING_BASE64_NOCRLF, "ptr", 0, "uint*", &outLen)
    outBuf := Buffer(outLen * 2)
    DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", len, "uint", CRYPT_STRING_BASE64_NOCRLF, "ptr", outBuf, "uint*", &outLen)
    return StrGet(outBuf, outLen, "UTF-16")
}
