#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------
;  AltShift - fix text typed with the wrong keyboard layout
;  Select the text  ->  press Ctrl+Alt+X
;  Converts EN<->AR by key position AND switches the input language
; ---------------------------------------------------------------

global LID_AR := "00000401"   ; Arabic (Saudi). Egypt = 00000c01
global LID_EN := "00000409"   ; English (US)

global en2ar := Map(
    "q","ض", "w","ص", "e","ث", "r","ق", "t","ف", "y","غ", "u","ع", "i","ه",
    "o","خ", "p","ح", "[","ج", "]","د",
    "a","ش", "s","س", "d","ي", "f","ب", "g","ل", "h","ا", "j","ت", "k","ن",
    "l","م", ";","ك", "'","ط",
    "z","ئ", "x","ء", "c","ؤ", "v","ر", "b","لا", "n","ى", "m","ة",
    ",","و", ".","ز", "/","ظ",
    "Q","َ", "W","ً", "E","ُ", "R","ٌ", "T","لإ", "Y","إ",
    "P","؛", "A","ِ", "S","ٍ", "G","لأ", "H","أ", "J","ـ", "K","،",
    "X","ْ", "B","لآ", "N","آ", "?","؟"
)

global ar2en := BuildReverse(en2ar)

if (A_Args.Length && A_Args[1] = "--selftest") {
    RunSelfTest()
    ExitApp
}


; ---------------- settings ----------------
global INI     := A_ScriptDir "\settings.ini"
global gHotkey := "^!x"
global gBadKey := ""
global gEnabled := true

LoadSettings()
try TraySetIcon(A_ScriptDir "\assets\altshift.ico")
InitTray()
if (gBadKey != "")
    TrayTip("اختصار غير صالح فى settings.ini: " gBadKey "`nتم الرجوع إلى Ctrl+Alt+X", "AltShift", "Icon!")

LoadSettings() {
    global gHotkey, gBadKey, LID_AR
    gHotkey := Trim(IniRead(INI, "General", "Hotkey", "^!x"))
    LID_AR  := Trim(IniRead(INI, "General", "ArabicLayout", "00000401"))
    if (gHotkey = "")
        gHotkey := "^!x"
    try {
        Hotkey("$" gHotkey, (*) => FixSelection())   ; $ forces the keyboard hook
    } catch {
        gBadKey := gHotkey
        gHotkey := "^!x"
        Hotkey("$^!x", (*) => FixSelection())
    }
    Hotkey("$^!r", (*) => Reload())      ; reload is fixed, it is a maintenance key
}

PrettyHotkey(hk) {
    mods := "", i := 1
    while (i <= StrLen(hk)) {
        c := SubStr(hk, i, 1)
        if (c = "^")
            mods .= "Ctrl+"
        else if (c = "!")
            mods .= "Alt+"
        else if (c = "+")
            mods .= "Shift+"
        else if (c = "#")
            mods .= "Win+"
        else
            break
        i++
    }
    return mods . StrUpper(SubStr(hk, i))
}

; ---------------- tray icon + menu ----------------
InitTray() {
    lbl := "تصحيح التحديد الآن`t" PrettyHotkey(gHotkey)
    t := A_TrayMenu
    t.Delete()
    t.Add(lbl, (*) => FixSelection())
    t.Default := lbl
    t.Add()
    t.Add("مُفعّل", ToggleEnabled)
    t.Check("مُفعّل")
    t.Add()
    t.Add("فتح الإعدادات", (*) => OpenSettings())
    t.Add("إعادة تحميل`tCtrl+Alt+R", (*) => Reload())
    t.Add()
    t.Add("خروج", (*) => ExitApp())
    SetTip()
}

OpenSettings() {
    if !FileExist(INI)
        FileAppend("[General]`n; Hotkey syntax: ^=Ctrl  !=Alt  +=Shift  #=Win`nHotkey=^!x`n; 00000401 = Arabic (Saudi), 00000c01 = Arabic (Egypt)`nArabicLayout=00000401`n", INI, "UTF-8")
    Run('notepad.exe "' INI '"')
}

SetTip() {
    A_IconTip := gEnabled ? "AltShift — " PrettyHotkey(gHotkey) : "AltShift — متوقف"
}

ToggleEnabled(name, pos, m) {
    global gEnabled
    gEnabled := !gEnabled
    gEnabled ? m.Check(name) : m.Uncheck(name)
    SetTip()
}

BuildReverse(m) {
    r := Map()
    for k, v in m
        if (RegExMatch(v, "[\x{0600}-\x{06FF}]") && !r.Has(v))
            r[v] := k
    return r
}

IsArabicChar(c) => RegExMatch(c, "[\x{0600}-\x{06FF}]") ? true : false
IsLatinChar(c)  => RegExMatch(c, "[A-Za-z]") ? true : false

EnToAr(s) {
    out := ""
    Loop Parse s
        out .= en2ar.Has(A_LoopField) ? en2ar[A_LoopField] : A_LoopField
    return out
}

ArToEn(s) {
    out := "", i := 1, len := StrLen(s)
    while (i <= len) {
        two := SubStr(s, i, 2)
        if (StrLen(two) = 2 && ar2en.Has(two)) {
            out .= ar2en[two]
            i += 2
            continue
        }
        one := SubStr(s, i, 1)
        out .= ar2en.Has(one) ? ar2en[one] : one
        i += 1
    }
    return out
}

SetLayout(lid) {
    hwnd := WinExist("A")
    if !hwnd
        return
    hkl := DllCall("LoadKeyboardLayout", "Str", lid, "UInt", 0x00000001, "Ptr")
    if hkl
        PostMessage(0x0050, 0, hkl, , "ahk_id " hwnd)   ; WM_INPUTLANGCHANGEREQUEST
}

FixSelection() {
    if !gEnabled
        return
    saved := ClipboardAll()
    A_Clipboard := ""
    Send "^{sc02E}"          ; scan code for C - immune to the active keyboard layout
    Sleep 60
    if !ClipWait(1.5, 1) {
        A_Clipboard := saved
        ToolTip "لم يتم تحديد نص"
        SetTimer () => ToolTip(), -1200
        return
    }
    txt := A_Clipboard
    ar := 0, en := 0
    Loop Parse txt {
        if IsArabicChar(A_LoopField)
            ar++
        else if IsLatinChar(A_LoopField)
            en++
    }
    if (ar = 0 && en = 0) {
        A_Clipboard := saved
        return
    }
    if (ar > en) {
        out := ArToEn(txt)
        target := LID_EN
    } else {
        out := EnToAr(txt)
        target := LID_AR
    }
    A_Clipboard := out
    ClipWait(1.0)
    Send "^{sc02F}"          ; scan code for V - same reason
    Sleep 350                ; let the paste land before the clipboard is restored
    A_Clipboard := saved
    SetLayout(target)
}



RunSelfTest() {
    fails := 0
    Check(label, got, want) {
        ok := (got = want)
        FileAppend((ok ? "PASS  " : "FAIL  ") . label . "  got=[" got "] want=[" want "]`n", "*", "UTF-8")
        return ok
    }
    if !Check("en->ar salam",      EnToAr("hgsghl ugd;l"), "السلام عليكم")
        fails++
    if !Check("ar->en hello",      ArToEn("اثممخ"), "hello")
        fails++
    if !Check("en->ar hello",      EnToAr("hello"), "اثممخ")
        fails++
    if !Check("en->ar word",       EnToAr("hglahv;m"), "المشاركة")
        fails++
    if !Check("ligature b",        EnToAr("b"), "لا")
        fails++
    if !Check("ligature rev",      ArToEn("لا"), "b")
        fails++
    if !Check("hamza G",           EnToAr("G"), "لأ")
        fails++
    if !Check("hamza G rev",       ArToEn("لأ"), "G")
        fails++
    ; lam+alef is ambiguous by design: prefers the single key "b" over "gh"
    if !Check("ambiguity documented", ArToEn("السلام"), "hgsbl")
        fails++
    if !Check("roundtrip clean",   ArToEn(EnToAr("ugd;l w,vm")), "ugd;l w,vm")
        fails++
    if !Check("digits kept",       EnToAr("2024"), "2024")
        fails++
    if !Check("mixed kept",        EnToAr("go 5"), "لخ 5")
        fails++
    if !Check("harakat",           EnToAr("QWERA"), "ًٌَُِ")
        fails++
    FileAppend("`n" (fails ? fails " FAILED" : "ALL TESTS PASSED") "`n", "*", "UTF-8")
}
