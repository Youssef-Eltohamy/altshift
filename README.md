<div align="center">

<img src="assets/preview-256.png" width="120" alt="AltShift">

# AltShift

**Fix text you typed with the wrong keyboard layout — Arabic ⇄ English — with one shortcut.**

*Named after the muscle memory it replaces.*

[![License: MIT](https://img.shields.io/badge/License-MIT-FC6710.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D4.svg)](#)
[![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2-2ea44f.svg)](https://www.autohotkey.com/)

</div>

---

## The problem

You start typing in Arabic, but the keyboard was still on English. You end up with:

```
hgsghl ugd;l
```

...instead of `السلام عليكم`. Or the reverse — English typed while the layout was Arabic:

```
اثممخ صخقمي        →  hello world
```

Today you delete it and retype. **AltShift** re-maps it by key position instead.

## Usage

1. Select the mistyped text.
2. Press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>X</kbd>.

The text is replaced in place **and the window's input language is switched**, so you can keep typing
correctly — exactly as if you had pressed <kbd>Alt</kbd>+<kbd>Shift</kbd> and retyped the whole thing.

The direction is detected automatically from the selection: mostly Arabic → convert to English,
mostly Latin → convert to Arabic. Your clipboard is restored afterwards.

<!-- Record a short screen capture (ScreenToGif) and drop it here as assets/demo.gif -->
<!-- ![demo](assets/demo.gif) -->

## Install

**One line in PowerShell:**

```powershell
irm https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main/install.ps1 | iex
```

Prefer to read a script before running it? Good instinct — download it first:

```powershell
irm https://raw.githubusercontent.com/Youssef-Eltohamy/altshift/main/install.ps1 -OutFile install.ps1
```

The installer only touches your machine: it installs AutoHotkey v2 through `winget` if it is missing,
copies the files to `%LOCALAPPDATA%\AltShift`, adds a Startup shortcut, and launches it.

**Manual:** install [AutoHotkey v2](https://www.autohotkey.com/), clone this repo, double-click `AltShift.ahk`.

## Settings

Right-click the tray icon → **فتح الإعدادات**, or edit `settings.ini`:

```ini
[General]
; ^ = Ctrl   ! = Alt   + = Shift   # = Win
Hotkey=^!x

; 00000401 = Arabic (Saudi Arabia),  00000c01 = Arabic (Egypt)
ArabicLayout=00000401
```

Press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd> to reload after editing.
If the hotkey is invalid the script falls back to <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>X</kbd> and tells you.

## How it works

The two layouts put different characters on the same physical keys. `h` on a US layout and `ا` on
Arabic 101 are the same key, so the fix is a character-for-character re-map, not a translation.

Two details that are easy to get wrong:

- **Ligature keys.** On Arabic 101, `b` produces two characters (`لا`), and <kbd>Shift</kbd>+`g/t/b`
  produce `لأ` / `لإ` / `لآ`. The reverse pass reads two characters ahead before falling back to one.
- **Copy/paste uses scan codes, not letters.** The script changes the active keyboard layout, and
  AutoHotkey resolves `Send "^c"` *through the active layout* — under an Arabic layout there is no
  `c` key to resolve, so the copy silently fails. `Send "^{sc02E}"` addresses the physical key and is
  immune to this. Without it the tool breaks itself on the second use.

## Known limitations

`ل` followed by `ا` is genuinely ambiguous in the Arabic → English direction: the same two characters
come from either the single key `b` or the pair `g`+`h`. The script prefers `b`, since a lone `b` is far
more common in English than the digraph `gh`. This is covered by an explicit test rather than hidden.

Symbols and digits are deliberately left untouched — you rarely want `2024` or `@gmail.com` rewritten.

## Development

```powershell
# unit tests - the character maps, both directions
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" AltShift.ahk --selftest

# end-to-end - drives a real edit control through the real hotkey
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" AltShift.test.ahk

# regenerate the icon set
pwsh -File assets/build-icon.ps1
```

## License

MIT — see [LICENSE](LICENSE).

---

<div dir="rtl">

## بالعربى

بتبدأ تكتب عربى والكيبورد لسه على الإنجليزى، فيطلع كلام مكرقط زى `hgsghl ugd;l` بدل «السلام عليكم».

**الحل:** حدّد الجملة واضغط <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>X</kbd>. النص بيتصلح مكانه، ولغة الإدخال بتتبدّل كمان عشان تكمل كتابة صح — كأنك ضغطت <kbd>Alt</kbd>+<kbd>Shift</kbd> وكتبت الجملة تانى.

الاتجاه بيتحدد أوتوماتيك حسب نوع الحروف فى التحديد، والكليبورد بيرجع لحالته بعد العملية.

**التسطيب:** سطر واحد فى `PowerShell` موجود فوق فى قسم `Install`، وبيسطّب `AutoHotkey v2` لوحده لو مش موجود.

**الإعدادات:** كليك يمين على أيقونة شريط المهام ← «فتح الإعدادات». تقدر تغيّر الاختصار، وتختار العربية المصرية `00000c01` بدل السعودية.

</div>
