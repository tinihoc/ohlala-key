#Requires AutoHotkey v2.0
; ==============================================================================
; MacroManager.ahk - Flat-File Macro Parser & Expansion Dispatcher
; Part of OhlalaKey / OpenKey Polyglot IME
; ==============================================================================

class MacroManager {
    filePath := ""
    macros := Map()
    enabled := true

    __New(filePath := "", enabled := true) {
        this.enabled := enabled
        this.macros := Map()
        if (filePath != "") {
            this.filePath := filePath
            this.Load(filePath)
        }
    }

    ; --------------------------------------------------------------------------
    ; Load Macro Flat File (trigger=replacement or trigger\treplacement)
    ; --------------------------------------------------------------------------
    Load(filePath) {
        this.filePath := filePath
        this.macros.Clear()

        if (!FileExist(filePath))
            return

        content := FileRead(filePath, "UTF-8")
        loop Parse, content, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line == "" || SubStr(line, 1, 1) == ";" || SubStr(line, 1, 1) == "#")
                continue

            delimPos := InStr(line, "=")
            if (delimPos == 0)
                delimPos := InStr(line, "`t")

            if (delimPos > 0) {
                trigger := Trim(SubStr(line, 1, delimPos - 1))
                replacement := Trim(SubStr(line, delimPos + 1))
                if (trigger != "")
                    this.macros[trigger] := replacement
            }
        }
    }

    ; --------------------------------------------------------------------------
    ; Check and Expand Macro on Word Boundary
    ; --------------------------------------------------------------------------
    CheckAndExpand(wordBuf, terminator := "") {
        if (!this.enabled || wordBuf.Length == 0)
            return false

        word := wordBuf.GetText()
        if (word == "")
            return false

        replacement := ""
        if (this.macros.Has(word)) {
            replacement := this.macros[word]
        } else if (this.macros.Has(StrLower(word))) {
            ; Case matching: if typed word is all-caps, upper the replacement
            rep := this.macros[StrLower(word)]
            if (word == StrUpper(word) && word != StrLower(word))
                replacement := StrUpper(rep)
            else
                replacement := rep
        }

        if (replacement != "") {
            ; Terminator has already been rendered by InputHook("V")
            ; So backspace (word.Length + terminator.Length) and emit replacement + terminator
            bsCount := StrLen(word) + StrLen(terminator)
            wordBuf.Replace(bsCount, replacement . terminator)
            wordBuf.Reset()
            return true
        }

        return false
    }

    ; Check if a trigger exists in table
    Has(trigger) {
        return this.macros.Has(trigger)
    }

    ; Get replacement for trigger
    Get(trigger) {
        return this.macros.Has(trigger) ? this.macros[trigger] : ""
    }
}
