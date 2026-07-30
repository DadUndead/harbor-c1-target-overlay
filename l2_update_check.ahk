; compares two "X.Y.Z" version strings - returns 1 if a>b, -1 if a<b, 0 if equal
f_version_compare(a, b) {
    pa := StrSplit(a, "."), pb := StrSplit(b, ".")
    loop 3 {
        na := (A_Index <= pa.Length) ? Integer(pa[A_Index]) : 0
        nb := (A_Index <= pb.Length) ? Integer(pb[A_Index]) : 0
        if (na != nb)
            return (na > nb) ? 1 : -1
    }
    return 0
}

; checks GitHub's "latest release" once at startup - a single small GET, no
; API key needed. Silent no-op on any failure (no internet, GitHub down, rate
; limited) so a broken update check can never block the overlay from running.
f_check_for_update() {
    global APP_VERSION, UPDATE_GITHUB_OWNER, UPDATE_GITHUB_REPO
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/" UPDATE_GITHUB_OWNER "/" UPDATE_GITHUB_REPO "/releases/latest", false)
        whr.SetRequestHeader("User-Agent", "L2TargetOverlay-UpdateCheck")
        try whr.Option[9] := 0x00000800   ; SecureProtocols: TLS 1.2
        whr.SetTimeouts(3000, 3000, 5000, 5000)
        whr.Send()
        if (whr.Status != 200)
            return
        resp := whr.ResponseText
        if !RegExMatch(resp, '"tag_name"\s*:\s*"v?([\d.]+)"', &m)
            return
        latest := m[1]
        if (f_version_compare(latest, APP_VERSION) <= 0)
            return

        if !RegExMatch(resp, '"browser_download_url"\s*:\s*"([^"]+?\.zip)"', &am)
            return
        zipUrl := StrReplace(am[1], "\/", "/")

        result := MsgBox(
            f_fmt(T("update_available_msg"), latest, APP_VERSION),
            T("update_title"), "YesNo Icon!")
        if (result = "Yes")
            f_download_and_extract_update(zipUrl, latest)
    } catch {
        ; no internet / GitHub unreachable / rate-limited - fail silently
    }
}

f_download_and_extract_update(zipUrl, latest) {
    try {
        tmpZip := A_Temp "\L2TargetOverlay_update_" latest ".zip"
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", zipUrl, false)
        whr.SetRequestHeader("User-Agent", "L2TargetOverlay-UpdateCheck")
        try whr.Option[9] := 0x00000800
        whr.SetTimeouts(3000, 3000, 15000, 30000)
        whr.Send()
        if (whr.Status != 200) {
            MsgBox(f_fmt(T("update_download_failed_msg"), whr.Status), "L2 Target Overlay", "OK Icon!")
            return
        }
        stream := ComObject("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        stream.Write(whr.ResponseBody)
        stream.SaveToFile(tmpZip, 2)
        stream.Close()

        destFolder := A_ScriptDir "\update_v" latest
        try DirCreate(destFolder)

        ; extract via the Shell COM API - no external unzip tool needed.
        ; CopyHere() is asynchronous even with the "no UI" flags, so poll
        ; until the file count in the destination matches the archive
        ; before telling the user it's ready.
        shell := ComObject("Shell.Application")
        zipFolder := shell.NameSpace(tmpZip)
        destNS := shell.NameSpace(destFolder)
        expectedCount := zipFolder.Items().Count
        destNS.CopyHere(zipFolder.Items(), 4 + 16)   ; 4 = no progress dialog, 16 = yes-to-all on prompts
        loop 100 {
            if (shell.NameSpace(destFolder).Items().Count >= expectedCount)
                break
            Sleep(100)
        }

        MsgBox(
            f_fmt(T("update_ready_msg"), latest, destFolder),
            T("update_ready_title"), "OK Icon!")
        Run('explorer.exe "' destFolder '"')
    } catch as e {
        MsgBox(f_fmt(T("update_extract_error_msg"), e.Message), "L2 Target Overlay", "OK Icon!")
    }
}
