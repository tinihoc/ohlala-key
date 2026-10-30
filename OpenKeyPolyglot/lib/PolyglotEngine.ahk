#Requires AutoHotkey v2.0
; ==============================================================================
; PolyglotEngine.ahk - French & Spanish Input Method Grammar
; Part of OhlalaKey / OpenKey Polyglot IME
; ==============================================================================

class PolyglotEngine {
    enabled := true
    inputMethod := "Telex" ; "Telex" or "VNI"
    isGuillemetOpen := false

    ; Punctuation state tracker:
    ; 0: None, 1: Exclamation, 2: InvExcl, 3: MultiExcl
    ; 4: Question, 5: InvQues, 6: MultiQues
    ; 7: Apos1, 8: OpenGuill, 9: CloseGuill, 10: MultiApos
    punctState := 0

    __New(inputMethod := "Telex", enabled := true) {
        this.inputMethod := inputMethod
        this.enabled := enabled
        this.isGuillemetOpen := false
        this.punctState := 0
    }

    ; Reset all punctuation and guillemet states
    ResetPunctuation() {
        this.punctState := 0
        this.isGuillemetOpen := false
    }

    ; Reset punctuation state but retain guillemet toggle (for typing words inside quotes)
    ClearPunctState() {
        this.punctState := 0
    }

    ; --------------------------------------------------------------------------
    ; Handle Spanish Inverted Punctuation and French Guillemets
    ; --------------------------------------------------------------------------
    HandlePunctuation(char, wordBuf) {
        if (!this.enabled)
            return false

        ; Exclamation mark '!'
        if (char == "!") {
            if (this.punctState == 1) {
                ; Second '!' -> backspace '!!' and emit '¡'
                this.punctState := 2
                wordBuf.Replace(2, "¡", [CharToken("¡", "!", false, 0, 0, true, true)])
                return true
            } else if (this.punctState == 2) {
                ; Third '!' after '¡' -> backspace '¡!' and emit '!!!'
                this.punctState := 3
                wordBuf.Replace(2, "!!!", [CharToken("!", "!", false), CharToken("!", "!", false), CharToken("!", "!", false)])
                return true
            } else if (this.punctState == 3) {
                ; 4th or more '!' -> normal append
                wordBuf.PushChar("!", "!")
                return true
            } else {
                ; First '!'
                this.punctState := 1
                wordBuf.PushChar("!", "!")
                return true
            }
        }

        ; Question mark '?'
        if (char == "?") {
            if (this.punctState == 4) {
                ; Second '?' -> backspace '??' and emit '¿'
                this.punctState := 5
                wordBuf.Replace(2, "¿", [CharToken("¿", "?", false, 0, 0, true, true)])
                return true
            } else if (this.punctState == 5) {
                ; Third '?' after '¿' -> backspace '¿?' and emit '???'
                this.punctState := 6
                wordBuf.Replace(2, "???", [CharToken("?", "?", false), CharToken("?", "?", false), CharToken("?", "?", false)])
                return true
            } else if (this.punctState == 6) {
                ; 4th or more '?' -> normal append
                wordBuf.PushChar("?", "?")
                return true
            } else {
                ; First '?'
                this.punctState := 4
                wordBuf.PushChar("?", "?")
                return true
            }
        }

        ; Single quote / apostrophe "'"
        if (char == "'") {
            if (this.punctState == 7) {
                ; Second quote '' -> emit Guillemets with non-breaking space (U+00A0)
                nbsp := Chr(0x00A0)
                if (!this.isGuillemetOpen) {
                    this.isGuillemetOpen := true
                    this.punctState := 8
                    replacement := "«" . nbsp
                    toks := [CharToken("«", "'", false, 0, 0, true, true), CharToken(nbsp, "'", false, 0, 0, true, true)]
                    wordBuf.Replace(2, replacement, toks)
                } else {
                    this.isGuillemetOpen := false
                    this.punctState := 9
                    replacement := nbsp . "»"
                    toks := [CharToken(nbsp, "'", false, 0, 0, true, true), CharToken("»", "'", false, 0, 0, true, true)]
                    wordBuf.Replace(2, replacement, toks)
                }
                return true
            } else if (this.punctState == 8) {
                ; Third quote after open guillemet -> backspace 3 chars (rendered «, nbsp, ') and emit '''
                this.isGuillemetOpen := false
                this.punctState := 10
                toks := [CharToken("'", "'", false), CharToken("'", "'", false), CharToken("'", "'", false)]
                wordBuf.Replace(3, "'''", toks)
                return true
            } else if (this.punctState == 9) {
                ; Third quote after close guillemet -> backspace 3 chars (rendered nbsp, », ') and emit '''
                this.isGuillemetOpen := true
                this.punctState := 10
                toks := [CharToken("'", "'", false), CharToken("'", "'", false), CharToken("'", "'", false)]
                wordBuf.Replace(3, "'''", toks)
                return true
            } else if (this.punctState == 10) {
                wordBuf.PushChar("'", "'")
                return true
            } else {
                ; First single quote
                this.punctState := 7
                wordBuf.PushChar("'", "'")
                return true
            }
        }

        ; Any other character resets punctuation repeat tracker
        this.punctState := 0
        return false
    }

    ; --------------------------------------------------------------------------
    ; Process Foreign Polyglot Rules (Cedilla, Eñe, Ligatures, Circumflex, Tréma)
    ; Returns true if key was handled/transformed, false otherwise.
    ; --------------------------------------------------------------------------
    Process(char, wordBuf) {
        if (!this.enabled || wordBuf.Length == 0)
            return false

        this.punctState := 0 ; Non-punctuation key resets punct state

        if (this.inputMethod == "Telex")
            return this.ProcessTelex(char, wordBuf)
        else
            return this.ProcessVNI(char, wordBuf)
    }

    ; --------------------------------------------------------------------------
    ; TELEX Polyglot Grammar
    ; --------------------------------------------------------------------------
    ProcessTelex(char, wordBuf) {
        lastToken := wordBuf.tokens[wordBuf.Length]
        lastChar := lastToken.char
        lowerChar := StrLower(char)
        lowerLast := StrLower(lastChar)

        ; 0. Tréma Vowel Follow-up Transitions (e.g. nalive -> naïve, Hola, Noël)
        if (lastToken.diacritic == 4) {
            if (lowerLast == "ä" && lowerChar == "i") {
                ; nalive: nä + i -> naïve
                isUpperWord := (lastToken.isUpper && (char == "I"))
                rep := isUpperWord ? "AÏ" : (lastToken.isUpper ? "Aï" : "aï")
                toks := [CharToken(SubStr(rep, 1, 1), "a", lastToken.isUpper), CharToken(SubStr(rep, 2, 1), "i", isUpperWord || (char == "I"), 0, 4, true, true)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
            if (lowerLast == "ö" && lowerChar == "a") {
                ; !!Hola!: Hö + a -> Hola
                isUpperWord := (lastToken.isUpper && (char == "A"))
                rep := isUpperWord ? "OLA" : (lastToken.isUpper ? "Ola" : "ola")
                toks := [CharToken(SubStr(rep, 1, 1), "o", lastToken.isUpper), CharToken(SubStr(rep, 2, 1), "l", isUpperWord), CharToken(SubStr(rep, 3, 1), "a", isUpperWord || (char == "A"))]
                wordBuf.Replace(2, rep, toks)
                return true
            }
            if (lowerLast == "ö" && lowerChar == "e") {
                ; Noel -> Nöl -> Noël
                isUpperWord := (lastToken.isUpper && (char == "E"))
                rep := isUpperWord ? "OË" : (lastToken.isUpper ? "Oë" : "oë")
                toks := [CharToken(SubStr(rep, 1, 1), "o", lastToken.isUpper), CharToken(SubStr(rep, 2, 1), "e", isUpperWord || (char == "E"), 0, 4, true, true)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; 1. Cedilla: cc -> ç, CC -> Ç, Cc -> Ç
        if (lowerChar == "c") {
            if (lowerLast == "c" && !lastToken.isSpecial) {
                ; Transform cc -> ç
                isUpper := (lastToken.isUpper || (char == StrUpper(char) && char !== "c"))
                rep := isUpper ? "Ç" : "ç"
                tok := CharToken(rep, "c", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "ç" || lastChar == "Ç") {
                ; Reversion: 3rd c restores raw cc
                isUpper := (lastChar == "Ç")
                rep := isUpper ? "CC" : "cc"
                toks := [CharToken(SubStr(rep, 1, 1), "c", isUpper), CharToken(SubStr(rep, 2, 1), "c", isUpper)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; 2. Eñe: nn -> ñ, NN -> Ñ, Nn -> Ñ
        if (lowerChar == "n") {
            if (lowerLast == "n" && !lastToken.isSpecial) {
                isUpper := (lastToken.isUpper || (char == StrUpper(char) && char !== "n"))
                rep := isUpper ? "Ñ" : "ñ"
                tok := CharToken(rep, "n", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "ñ" || lastChar == "Ñ") {
                ; Reversion: 3rd n restores raw nn
                isUpper := (lastChar == "Ñ")
                rep := isUpper ? "NN" : "nn"
                toks := [CharToken(SubStr(rep, 1, 1), "n", isUpper), CharToken(SubStr(rep, 2, 1), "n", isUpper)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; 3. French Ligatures:
        ; OE Ligature: oe -> œ, OE -> Œ, Oe -> Œ
        if (lowerChar == "e") {
            if (lowerLast == "o" && !lastToken.isSpecial) {
                isUpper := (lastToken.isUpper || (char == StrUpper(char) && char !== "e"))
                rep := isUpper ? "Œ" : "œ"
                tok := CharToken(rep, "oe", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "œ" || lastChar == "Œ") {
                ; Reversion: typing 'e' when prev is œ restores raw oe
                isUpper := (lastChar == "Œ")
                rep := isUpper ? "OE" : "oe"
                toks := [CharToken(SubStr(rep, 1, 1), "o", isUpper), CharToken(SubStr(rep, 2, 1), "e", isUpper)]
                wordBuf.Replace(2, rep, toks)
                return true
            }

            ; AE Ligature: ae -> æ, AE -> Æ, Ae -> Æ
            if (lowerLast == "a" && !lastToken.isSpecial) {
                isUpper := (lastToken.isUpper || (char == StrUpper(char) && char !== "e"))
                rep := isUpper ? "Æ" : "æ"
                tok := CharToken(rep, "ae", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "æ" || lastChar == "Æ") {
                ; Reversion: typing 'e' when prev is æ restores raw ae
                isUpper := (lastChar == "Æ")
                rep := isUpper ? "AE" : "ae"
                toks := [CharToken(SubStr(rep, 1, 1), "a", isUpper), CharToken(SubStr(rep, 2, 1), "e", isUpper)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; Noel -> Noël transition when 'l' is typed after 'œ'
        if (lowerChar == "l" && (lastChar == "œ" || lastChar == "Œ")) {
            isUpperWord := (lastChar == "Œ" && (char == "L" || char == StrUpper(char)))
            rep := isUpperWord ? "OËL" : (lastChar == "Œ" ? "Oël" : "oël")
            toks := [
                CharToken(SubStr(rep, 1, 1), "o", lastChar == "Œ"),
                CharToken(SubStr(rep, 2, 1), "e", isUpperWord, 0, 4, true, true),
                CharToken(SubStr(rep, 3, 1), "l", isUpperWord)
            ]
            wordBuf.Replace(2, rep, toks)
            return true
        }

        ; 4. Extended Circumflexes: ii -> î, uu -> û, yy -> ŷ
        if (lowerChar == "i" || lowerChar == "u" || lowerChar == "y") {
            if (lowerLast == lowerChar && !lastToken.isSpecial && lastToken.diacritic == 0) {
                isUpper := (lastToken.isUpper || (char == StrUpper(char) && char !== lowerChar))
                rep := ""
                if (lowerChar == "i")
                    rep := isUpper ? "Î" : "î"
                else if (lowerChar == "u")
                    rep := isUpper ? "Û" : "û"
                else if (lowerChar == "y")
                    rep := isUpper ? "Ŷ" : "ŷ"

                if (rep != "") {
                    tok := CharToken(rep, lowerChar, isUpper, 0, 1, true, true)
                    wordBuf.Replace(2, rep, [tok])
                    return true
                }
            } else if (InStr("îÎûÛŷŶ", lastChar)) {
                ; Undo circumflex on extended vowels: î + i -> ii
                baseChar := ""
                if (InStr("îÎ", lastChar))
                    baseChar := (lastChar == "Î") ? "I" : "i"
                else if (InStr("ûÛ", lastChar))
                    baseChar := (lastChar == "Û") ? "U" : "u"
                else if (InStr("ŷŶ", lastChar))
                    baseChar := (lastChar == "Ŷ") ? "Y" : "y"

                if (baseChar != "" && StrLower(baseChar) == lowerChar) {
                    rep := baseChar . char
                    toks := [CharToken(baseChar, lowerChar, (baseChar == StrUpper(baseChar))), CharToken(char, lowerChar, (char == StrUpper(char)))]
                    wordBuf.Replace(2, rep, toks)
                    return true
                }
            }
        }

        ; 5. Tréma / Diaeresis: Vowel + l -> ä, ë, ï, ö, ü, ÿ
        if (lowerChar == "l") {
            ; If word already contains Spanish 'ñ', suppress diaeresis on trailing 'l' (e.g. español)
            if (RegExMatch(wordBuf.GetText(), "[ñÑ]") > 0)
                return false

            ; Check if preceding token is already a Tréma vowel -> Double-L Reversion!
            ; e.g. ö + l -> oll, ï + l -> ill
            if (lastToken.diacritic == 4) {
                baseVowel := lastToken.rawKey
                isUp := lastToken.isUpper
                if (isUp)
                    baseVowel := StrUpper(baseVowel)
                rep := baseVowel . "ll"
                if (isUp && char == StrUpper(char))
                    rep := StrUpper(rep)
                else if (isUp)
                    rep := SubStr(rep, 1, 1) . "ll"

                toks := [
                    CharToken(SubStr(rep, 1, 1), lastToken.rawKey, isUp),
                    CharToken(SubStr(rep, 2, 1), "l", (SubStr(rep, 2, 1) == "L")),
                    CharToken(SubStr(rep, 3, 1), "l", (SubStr(rep, 3, 1) == "L"))
                ]
                wordBuf.Replace(2, rep, toks)
                return true
            }

            ; Check if preceding token is a base vowel
            if (this.IsBaseVowel(lowerLast) && lastToken.diacritic == 0) {
                isUpper := (lastToken.isUpper || (char == "L"))
                rep := this.GetTremaVowel(lowerLast, isUpper)
                if (rep != "") {
                    tok := CharToken(rep, lowerLast, isUpper, 0, 4, true, true)
                    wordBuf.Replace(2, rep, [tok])
                    return true
                }
            }
        }

        ; 6. Grave accent on U: uf -> ù, UF -> Ù, Uf -> Ù
        if (lowerChar == "f" && lowerLast == "u" && !lastToken.isSpecial && lastToken.diacritic == 0) {
            isUpper := lastToken.isUpper
            rep := isUpper ? "Ù" : "ù"
            tok := CharToken(rep, "u", isUpper, 2, 0, true, true)
            wordBuf.Replace(2, rep, [tok])
            return true
        } else if (lowerChar == "f" && (lastChar == "ù" || lastChar == "Ù")) {
            ; Undo: ù + f -> uf
            isUpper := (lastChar == "Ù")
            rep := isUpper ? "UF" : "uf"
            toks := [CharToken(SubStr(rep, 1, 1), "u", isUpper), CharToken(SubStr(rep, 2, 1), "f", (char == "F"))]
            wordBuf.Replace(2, rep, toks)
            return true
        }

        return false
    }

    ; --------------------------------------------------------------------------
    ; VNI Polyglot Grammar
    ; --------------------------------------------------------------------------
    ProcessVNI(char, wordBuf) {
        lastToken := wordBuf.tokens[wordBuf.Length]
        lastChar := lastToken.char
        lowerLast := StrLower(lastChar)

        ; 1. Cedilla: c9 -> ç, C9 -> Ç
        if (char == "9") {
            if (lowerLast == "c" && !lastToken.isSpecial) {
                isUpper := lastToken.isUpper
                rep := isUpper ? "Ç" : "ç"
                tok := CharToken(rep, "c", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "ç" || lastChar == "Ç") {
                isUpper := (lastChar == "Ç")
                rep := (isUpper ? "C" : "c") . "9"
                toks := [CharToken(SubStr(rep, 1, 1), "c", isUpper), CharToken("9", "9", false)]
                wordBuf.Replace(2, rep, toks)
                return true
            }

            ; 2. Eñe: n9 -> ñ, N9 -> Ñ
            if (lowerLast == "n" && !lastToken.isSpecial) {
                isUpper := lastToken.isUpper
                rep := isUpper ? "Ñ" : "ñ"
                tok := CharToken(rep, "n", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "ñ" || lastChar == "Ñ") {
                isUpper := (lastChar == "Ñ")
                rep := (isUpper ? "N" : "n") . "9"
                toks := [CharToken(SubStr(rep, 1, 1), "n", isUpper), CharToken("9", "9", false)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; 3. French Ligatures in VNI:
        ; OE Ligature: o8 -> œ, O8 -> Œ
        if (char == "8") {
            if (lowerLast == "o" && !lastToken.isSpecial) {
                isUpper := lastToken.isUpper
                rep := isUpper ? "Œ" : "œ"
                tok := CharToken(rep, "oe", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "œ" || lastChar == "Œ") {
                isUpper := (lastChar == "Œ")
                rep := (isUpper ? "O" : "o") . "8"
                toks := [CharToken(SubStr(rep, 1, 1), "o", isUpper), CharToken("8", "8", false)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; AE Ligature: a7 -> æ, A7 -> Æ
        if (char == "7") {
            if (lowerLast == "a" && !lastToken.isSpecial) {
                isUpper := lastToken.isUpper
                rep := isUpper ? "Æ" : "æ"
                tok := CharToken(rep, "ae", isUpper, 0, 0, true, true)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "æ" || lastChar == "Æ") {
                isUpper := (lastChar == "Æ")
                rep := (isUpper ? "A" : "a") . "7"
                toks := [CharToken(SubStr(rep, 1, 1), "a", isUpper), CharToken("7", "7", false)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; 4. Extended Circumflexes: i6 -> î, u6 -> û, y6 -> ŷ
        if (char == "6") {
            if (InStr("iuy", lowerLast) && !lastToken.isSpecial && lastToken.diacritic == 0) {
                isUpper := lastToken.isUpper
                rep := ""
                if (lowerLast == "i")
                    rep := isUpper ? "Î" : "î"
                else if (lowerLast == "u")
                    rep := isUpper ? "Û" : "û"
                else if (lowerLast == "y")
                    rep := isUpper ? "Ŷ" : "ŷ"

                if (rep != "") {
                    tok := CharToken(rep, lowerLast, isUpper, 0, 1, true, true)
                    wordBuf.Replace(2, rep, [tok])
                    return true
                }
            } else if (InStr("îÎûÛŷŶ", lastChar)) {
                baseChar := ""
                if (InStr("îÎ", lastChar))
                    baseChar := (lastChar == "Î") ? "I" : "i"
                else if (InStr("ûÛ", lastChar))
                    baseChar := (lastChar == "Û") ? "U" : "u"
                else if (InStr("ŷŶ", lastChar))
                    baseChar := (lastChar == "Ŷ") ? "Y" : "y"

                if (baseChar != "") {
                    rep := baseChar . "6"
                    toks := [CharToken(baseChar, StrLower(baseChar), (baseChar == StrUpper(baseChar))), CharToken("6", "6", false)]
                    wordBuf.Replace(2, rep, toks)
                    return true
                }
            }
        }

        ; 5. Tréma: Vowel + 0 -> ä, ë, ï, ö, ü, ÿ
        if (char == "0") {
            if (lastToken.diacritic == 4) {
                baseVowel := lastToken.rawKey
                isUp := lastToken.isUpper
                rep := (isUp ? StrUpper(baseVowel) : baseVowel) . "0"
                toks := [CharToken(SubStr(rep, 1, 1), baseVowel, isUp), CharToken("0", "0", false)]
                wordBuf.Replace(2, rep, toks)
                return true
            }

            if (this.IsBaseVowel(lowerLast) && lastToken.diacritic == 0) {
                isUpper := lastToken.isUpper
                rep := this.GetTremaVowel(lowerLast, isUpper)
                if (rep != "") {
                    tok := CharToken(rep, lowerLast, isUpper, 0, 4, true, true)
                    wordBuf.Replace(2, rep, [tok])
                    return true
                }
            }
        }

        ; 6. Grave on U: u2 -> ù, U2 -> Ù
        if (char == "2" && lowerLast == "u" && !lastToken.isSpecial && lastToken.diacritic == 0) {
            isUpper := lastToken.isUpper
            rep := isUpper ? "Ù" : "ù"
            tok := CharToken(rep, "u", isUpper, 2, 0, true, true)
            wordBuf.Replace(2, rep, [tok])
            return true
        } else if (char == "2" && (lastChar == "ù" || lastChar == "Ù")) {
            isUpper := (lastChar == "Ù")
            rep := (isUpper ? "U" : "u") . "2"
            toks := [CharToken(SubStr(rep, 1, 1), "u", isUpper), CharToken("2", "2", false)]
            wordBuf.Replace(2, rep, toks)
            return true
        }

        return false
    }

    ; Check if character is a base Latin vowel
    IsBaseVowel(ch) {
        return InStr("aeiouy", StrLower(ch)) > 0
    }

    ; Return Tréma character with correct casing
    GetTremaVowel(baseVowel, isUpper) {
        tremaMap := Map(
            "a", isUpper ? "Ä" : "ä",
            "e", isUpper ? "Ë" : "ë",
            "i", isUpper ? "Ï" : "ï",
            "o", isUpper ? "Ö" : "ö",
            "u", isUpper ? "Ü" : "ü",
            "y", isUpper ? "Ÿ" : "ÿ"
        )
        return tremaMap.Has(baseVowel) ? tremaMap[baseVowel] : ""
    }
}
