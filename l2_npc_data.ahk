;===============================================================================
; NPC NAME DATABASE (from the client's own npcname-e.txt) - used to correct
; OCR misreads by snapping to the nearest known NPC name.
;===============================================================================

f_load_npc_names() {
    global NPC_NAMES_FILE, g_npc_names
    if !FileExist(NPC_NAMES_FILE)
        return
    for line in StrSplit(FileRead(NPC_NAMES_FILE, "UTF-8"), "`n", "`r") {
        line := Trim(line)
        if (line != "")
            g_npc_names.Push(line)
    }
}

;===============================================================================
; NPC STAT DATABASE (from System\DB.json, pre-flattened to a plain
; tab-separated file: name level hp mp patk pdef matk mdef atkspd critical
; race aggressive debuffs)
;===============================================================================

f_load_npc_info() {
    global NPC_INFO_FILE, g_npc_info
    if !FileExist(NPC_INFO_FILE)
        return
    for line in StrSplit(FileRead(NPC_INFO_FILE, "UTF-8"), "`n", "`r") {
        if (line = "")
            continue
        p := StrSplit(line, "`t")
        if (p.Length < 15)
            continue
        key := StrLower(p[1])
        g_npc_info[key] := { level: p[2], hp: p[3], mp: p[4], patk: p[5], pdef: p[6]
            , matk: p[7], mdef: p[8], atkspd: p[9], critical: p[10], race: p[11]
            , aggressive: p[12], debuffs: p[13], exp: p[14], sp: p[15] }
    }
}

f_load_npc_attributes() {
    global NPC_ATTR_FILE, g_npc_attr
    if !FileExist(NPC_ATTR_FILE)
        return
    for line in StrSplit(FileRead(NPC_ATTR_FILE, "UTF-8"), "`n", "`r") {
        if (line = "")
            continue
        p := StrSplit(line, "`t")
        if (p.Length < 4)
            continue
        key := StrLower(p[1])
        g_npc_attr[key] := { respawn: p[2], passive: p[3], active: p[4] }
    }
}

; user-editable corrections (right now just "aggressive") layered on top of
; npc_info.txt, so per-server tweaks survive re-generating the base DB dump.
g_npc_overrides := Map()   ; lowercase npc name -> "yes"/"no"

f_load_npc_overrides() {
    global NPC_OVERRIDES_FILE, g_npc_overrides, g_npc_info
    if !FileExist(NPC_OVERRIDES_FILE)
        return
    for line in StrSplit(FileRead(NPC_OVERRIDES_FILE, "UTF-8"), "`n", "`r") {
        if (line = "")
            continue
        p := StrSplit(line, "`t")
        if (p.Length < 2)
            continue
        key := StrLower(p[1])
        g_npc_overrides[key] := p[2]
        if g_npc_info.Has(key)
            g_npc_info[key].aggressive := p[2]
    }
}

; expand/collapse button click handler - toggles the detail panel and forces
; an immediate redraw on the next timer tick (same pattern as the aggro
; button: clear g_last_text so f_tick doesn't think nothing changed).
f_on_expand_click(*) {
    global g_panelExpanded, g_expandBtn, g_last_text, g_forceRedraw
    g_panelExpanded := !g_panelExpanded
    g_expandBtn.Text := g_panelExpanded ? "^" : "v"
    g_last_text := ""
    g_forceRedraw := true
}

; left-pads/truncates s to a fixed column width, for lightweight table-style alignment
f_col(s, width) {
    s := String(s)
    if (StrLen(s) >= width)
        return s . " "
    return s . SubStr("                    ", 1, width - StrLen(s))
}

; A "segment" is {t: text, c: 0/1} where c=1 means "value" (colored blue),
; c=0 means "label" (default/silver). f_format_info returns an array of
; lines, each line an array of segments, so the renderer can color just the
; numbers/values and not the label text.

f_lbl(t) {
    return { t: t, color: "Silver" }
}
f_val(t) {
    global COLOR_STAT
    return { t: t, color: COLOR_STAT }
}

; fixed-width label/value cell, so every "Label value" pair lines up in a
; strict grid regardless of how many digits the value has - same idea as
; the percent column in the drop/spoil rows.
f_cell(label, value, labelW, valueW) {
    l := label
    while (StrLen(l) < labelW)
        l .= " "
    v := String(value)
    while (StrLen(v) < valueW)
        v .= " "
    v .= "   "  ; guaranteed gap before the next cell, even if the value overran valueW
    return [f_lbl(l), f_val(v)]
}

; header line shown next to the target name, visible even when the detail
; panel is collapsed: "Name LV" and, if the NPC is aggressive, a trailing
; "*" (e.g. "Tamlin Ork Archer 42*").
f_npc_header(npcName) {
    global g_npc_info
    key := StrLower(npcName)
    if !g_npc_info.Has(key)
        return npcName
    i := g_npc_info[key]
    star := (i.aggressive = "yes") ? "*" : ""
    return npcName " " i.level star
}

f_format_info(npcName) {
    global g_npc_info, g_npc_attr
    key := StrLower(npcName)
    if !g_npc_info.Has(key)
        return []
    i := g_npc_info[key]
    lines := []

    line1 := []
    for seg in f_cell("Lv", i.level, 3, 4)
        line1.Push(seg)
    line1.Push(f_val(i.race))
    lines.Push(line1)

    rows := [["EXP", i.exp, "SP", i.sp]
        , ["HP", i.hp, "MP", i.mp]
        , ["P.Atk", i.patk, "M.Atk", i.matk]
        , ["P.Def", i.pdef, "M.Def", i.mdef]
        , ["Atk.Spd", i.atkspd, "Crit", i.critical]]
    for row in rows {
        line := []
        for seg in f_cell(row[1], row[2], 8, 9)
            line.Push(seg)
        for seg in f_cell(row[3], row[4], 6, 6)
            line.Push(seg)
        lines.Push(line)
    }

    if g_npc_attr.Has(key) && g_npc_attr[key].respawn != ""
        lines.Push([f_lbl("Respawn "), f_val(g_npc_attr[key].respawn)])

    return lines
}

;===============================================================================
; NPC DROP/SPOIL DATABASE (from System\DB.json, pre-flattened to a plain
; tab-separated file: name  type(drop/spoil)  item  chance  min  max)
;===============================================================================

f_load_npc_drops() {
    global NPC_DROPS_FILE, g_npc_drops
    if !FileExist(NPC_DROPS_FILE)
        return
    for line in StrSplit(FileRead(NPC_DROPS_FILE, "UTF-8"), "`n", "`r") {
        if (line = "")
            continue
        parts := StrSplit(line, "`t")
        if (parts.Length < 6)
            continue
        key := StrLower(parts[1])
        if !g_npc_drops.Has(key)
            g_npc_drops[key] := []
        ; keep the original "5.31"-style string for display (parts[4]) and a
        ; separate numeric copy only for sorting - converting to a plain
        ; AHK float and back to string reintroduces binary-float noise
        ; ("5.3099999999999996"), so the display value must stay a string.
        g_npc_drops[key].Push({ type: parts[2], item: parts[3], chanceStr: parts[4], chanceNum: parts[4] + 0, min: parts[5], max: parts[6] })
    }
}

f_sort_by_chance_desc(rows) {
    n := rows.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index
            if (rows[j].chanceNum < rows[j + 1].chanceNum) {
                tmp := rows[j]
                rows[j] := rows[j + 1]
                rows[j + 1] := tmp
            }
        }
    }
    return rows
}

; returns {drop: [...], spoil: [...]}, each sorted by chance descending
f_get_drops(npcName) {
    global g_npc_drops
    key := StrLower(npcName)
    if !g_npc_drops.Has(key)
        return { drop: [], spoil: [] }

    dropRows := [], spoilRows := []
    for r in g_npc_drops[key] {
        if (r.type = "spoil")
            spoilRows.Push(r)
        else
            dropRows.Push(r)
    }
    return { drop: f_sort_by_chance_desc(dropRows), spoil: f_sort_by_chance_desc(spoilRows) }
}

f_divider(label, width) {
    dashes := width - StrLen(label) - 1
    if (dashes < 1)
        dashes := 1
    out := label " "
    loop dashes
        out .= "-"
    return out
}

; splits a Prima-guide attribute string (clauses separated by "; ") into
; trimmed, non-empty clauses.
f_split_attr_clauses(text) {
    out := []
    for part in StrSplit(text, ";") {
        p := Trim(part)
        if (p != "")
            out.Push(p)
    }
    return out
}

; simplifies verbose clauses like "+95% Def vs. earth type attacks" or
; "-10% Def vs. bows" down to "+95% vs earth" / "-10% vs bows". Returns the
; simplified text and whether a leading sign was found (and which).
f_simplify_attr_text(clause) {
    if RegExMatch(clause, "i)^([+-]\d+)%\s*(?:P\.?\s*Def\.?|M\.?\s*Def\.?|Def\.?|Atk\.?)?\s*if attacker can\s*(detect .+? weakness)\.?$", &m)
        return { t: m[1] "% vs " Trim(m[2]), sign: SubStr(m[1], 1, 1) }
    if RegExMatch(clause, "i)^([+-]\d+)%\s*(?:P\.?\s*Def\.?|M\.?\s*Def\.?|Def\.?|Atk\.?)?\s*(?:vs\.?|against)\s*([A-Za-z][A-Za-z\s]*?)(?:\s+type\s+attacks?)?\.?$", &m)
        return { t: m[1] "% vs " Trim(m[2]), sign: SubStr(m[1], 1, 1) }
    if RegExMatch(clause, "^([+-])\d+%", &m2)
        return { t: clause, sign: m2[1] }
    return { t: clause, sign: "" }
}

; passive attribute line: colored red for a leading "+", green for a
; leading "-". Clauses without a signed percentage (e.g. "Aggro range x4")
; keep their original text in the default label color.
f_format_attr_line(clause) {
    global COLOR_ATTR_POS, COLOR_ATTR_NEG
    s := f_simplify_attr_text(clause)
    if (s.sign = "-")
        return { t: s.t, color: COLOR_ATTR_NEG }
    if (s.sign = "+")
        return { t: s.t, color: COLOR_ATTR_POS }
    return f_lbl(s.t)
}

; active ability line: always orange, regardless of sign.
f_format_attr_line_active(clause) {
    global COLOR_ATTR_ACTIVE
    s := f_simplify_attr_text(clause)
    return { t: s.t, color: COLOR_ATTR_ACTIVE }
}

f_levenshtein(a, b) {
    a := StrLower(a)
    b := StrLower(b)
    la := StrLen(a), lb := StrLen(b)
    if (la = 0)
        return lb
    if (lb = 0)
        return la

    prev := []
    for j in Range(0, lb)
        prev.Push(j)

    loop la {
        i := A_Index
        cur := [i]
        ca := SubStr(a, i, 1)
        loop lb {
            j := A_Index
            cb := SubStr(b, j, 1)
            cost := (ca = cb) ? 0 : 1
            del := prev[j + 1] + 1
            ins := cur[j] + 1
            sub := prev[j] + cost
            m := del
            if (ins < m)
                m := ins
            if (sub < m)
                m := sub
            cur.Push(m)
        }
        prev := cur
    }
    return prev[lb + 1]
}

Range(startN, endN) {
    arr := []
    loop (endN - startN + 1)
        arr.Push(startN + A_Index - 1)
    return arr
}

f_best_npc_match(text) {
    global g_npc_names, FUZZY_MAX_RATIO
    if (text = "" || g_npc_names.Length = 0)
        return { name: text, matched: false, dist: -1 }

    bestName := ""
    bestDist := 999999
    for name in g_npc_names {
        ; quick length-based pruning before the expensive full distance calc
        if (Abs(StrLen(name) - StrLen(text)) > bestDist)
            continue
        d := f_levenshtein(text, name)
        if (d < bestDist) {
            bestDist := d
            bestName := name
        }
    }

    maxAllowed := Max(1, Round(StrLen(text) * FUZZY_MAX_RATIO))
    if (bestDist <= maxAllowed)
        return { name: bestName, matched: true, dist: bestDist }
    return { name: text, matched: false, dist: bestDist }
}

; same fuzzy-match logic as f_best_npc_match, generalized to take any name
; list - used for matching OCR'd party-member nicknames against the player
; database instead of NPC names.
f_best_name_match(text, namesList, maxRatio) {
    if (text = "" || namesList.Length = 0)
        return { name: text, matched: false, dist: -1 }
    bestName := ""
    bestDist := 999999
    for name in namesList {
        if (Abs(StrLen(name) - StrLen(text)) > bestDist)
            continue
        d := f_levenshtein(text, name)
        if (d < bestDist) {
            bestDist := d
            bestName := name
        }
    }
    maxAllowed := Max(1, Round(StrLen(text) * maxRatio))
    if (bestDist <= maxAllowed)
        return { name: bestName, matched: true, dist: bestDist }
    return { name: text, matched: false, dist: bestDist }
}

;===============================================================================
; PARTY MEMBER CLASS DATABASE (player_classes.txt, exported from the
; server: nick, class, level, clan - only nick/class matter here). Manual
; corrections/additions from the class-selector dropdowns go into a
; separate override file that layers on top, so they survive the base file
; being re-exported/updated.
;===============================================================================

; AHK v2 arrays have no .Sort() method - the built-in Sort() function only
; sorts lines of a delimited string, so round-trip through one.
f_sort_array(arr) {
    s := ""
    for v in arr
        s .= v "`n"
    s := Trim(s, "`n")
    if (s = "")
        return []
    return StrSplit(Sort(s), "`n")
}

f_load_player_classes() {
    global PLAYER_CLASSES_FILE, g_player_classes, g_class_list, g_player_nick_list
    if !FileExist(PLAYER_CLASSES_FILE)
        return
    classSet := Map()
    for line in StrSplit(FileRead(PLAYER_CLASSES_FILE, "UTF-8"), "`n", "`r") {
        if (line = "")
            continue
        p := StrSplit(line, "`t")
        if (p.Length < 2 || p[1] = "" || p[2] = "")
            continue
        g_player_classes[StrLower(p[1])] := p[2]
        g_player_nick_list.Push(p[1])
        classSet[p[2]] := true
    }
    list := []
    for cls in classSet
        list.Push(cls)
    g_class_list := f_sort_array(list)
}

f_load_player_class_overrides() {
    global PLAYER_CLASS_OVERRIDES_FILE, g_player_class_overrides, g_class_list, g_player_classes, g_player_nick_list
    if !FileExist(PLAYER_CLASS_OVERRIDES_FILE)
        return
    changed := false
    for line in StrSplit(FileRead(PLAYER_CLASS_OVERRIDES_FILE, "UTF-8"), "`n", "`r") {
        if (line = "")
            continue
        p := StrSplit(line, "`t")
        if (p.Length < 2 || p[1] = "" || p[2] = "")
            continue
        key := StrLower(p[1])
        g_player_class_overrides[key] := p[2]
        if !g_player_classes.Has(key)
            g_player_nick_list.Push(p[1])
        ; a hand-picked class not already in the base DB should still show
        ; up as an option in every other row's dropdown
        found := false
        for cls in g_class_list
            if (cls = p[2])
                found := true
        if !found {
            g_class_list.Push(p[2])
            changed := true
        }
    }
    if changed
        g_class_list := f_sort_array(g_class_list)
}

f_save_player_class_override(nick, cls) {
    global PLAYER_CLASS_OVERRIDES_FILE, g_player_class_overrides, g_class_list, g_player_classes, g_player_nick_list
    key := StrLower(nick)
    if (!g_player_classes.Has(key) && !g_player_class_overrides.Has(key))
        g_player_nick_list.Push(nick)
    g_player_class_overrides[key] := cls
    found := false
    for c in g_class_list
        if (c = cls)
            found := true
    if !found {
        g_class_list.Push(cls)
        g_class_list := f_sort_array(g_class_list)
    }
    lines := []
    for nickKey, c in g_player_class_overrides
        lines.Push(nickKey "`t" c)
    try FileDelete(PLAYER_CLASS_OVERRIDES_FILE)
    text := ""
    for l in lines
        text .= l "`n"
    FileAppend(text, PLAYER_CLASS_OVERRIDES_FILE, "UTF-8")
}

; overrides win over the base DB - that's the whole point of being able to
; fix a wrong/missing entry from the dropdown.
f_get_player_class(nick) {
    global g_player_classes, g_player_class_overrides
    key := StrLower(nick)
    if g_player_class_overrides.Has(key)
        return g_player_class_overrides[key]
    if g_player_classes.Has(key)
        return g_player_classes[key]
    return ""
}
