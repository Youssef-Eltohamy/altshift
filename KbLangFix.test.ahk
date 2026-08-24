#Requires AutoHotkey v2.0
SendLevel 1
SetKeyDelay 40, 40
g := Gui("+AlwaysOnTop", "KbLangFix Integration Test")
ed := g.Add("Edit", "w420 h90")
g.Show()
WinWaitActive("KbLangFix Integration Test", , 5)
Sleep 600

Trial(input, expect, label) {
    global ed
    ed.Value := input
    ed.Focus()
    Sleep 400
    SendEvent "^{sc01E}"
    Sleep 400
    ; press the hotkey with fully explicit down/up so no modifier stays latched
    SendEvent "{Ctrl down}{Alt down}x{Alt up}{Ctrl up}"
    Sleep 150
    SendEvent "{Ctrl up}{Alt up}{Shift up}"
    Sleep 2200
    got := ed.Value
    ok := (got = expect)
    FileAppend((ok ? "PASS  " : "FAIL  ") label "  got=[" got "] want=[" expect "]`n", "*", "UTF-8")
    return ok
}

f := 0
if !Trial("hgsghl ugd;l", "السلام عليكم", "EN layout -> Arabic")
    f++
if !Trial("اثممخ صخقمي", "hello world", "AR layout -> English")
    f++
if !Trial("hgladv jl jsgdli", "المشير تم تسليمه", "long EN -> Arabic")
    f++
FileAppend("`n" (f ? f " INTEGRATION FAILURES" : "INTEGRATION PASSED") "`n", "*", "UTF-8")
ExitApp
