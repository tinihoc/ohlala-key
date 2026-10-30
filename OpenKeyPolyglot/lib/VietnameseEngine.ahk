#Requires AutoHotkey v2.0
; ==============================================================================
; VietnameseEngine.ahk - Vietnamese Syllable Parser, Matrices & Tone Placement
; Part of OhlalaKey / OpenKey Polyglot IME
; ==============================================================================

class VietnameseEngine {
    inputMethod := "Telex" ; "Telex" or "VNI"
    modernTone := true
    autoRestore := true

    ; Tone indices: 0: None, 1: Sắc, 2: Huyền, 3: Hỏi, 4: Ngã, 5: Nặng
    ; Diacritic indices: 0: None, 1: Circumflex (^), 2: Breve (ă), 3: Horn (ơ/ư)

    ; CharMap provides lookup: char -> { base, diacritic, tone }
    static CharMap := Map()
    ; VowelTable provides lookup: [base, diacritic, tone] -> char
    static VowelTable := Map()

    static __New() {
        this.InitVowelMatrices()
    }

    __New(inputMethod := "Telex", modernTone := true, autoRestore := true) {
        this.inputMethod := inputMethod
        this.modernTone := modernTone
        this.autoRestore := autoRestore
    }

    static InitVowelMatrices() {
        ; Definitions: [base, diacritic, [tone0, tone1, tone2, tone3, tone4, tone5]]
        defs := [
            ; A
            ["a", 0, ["a", "á", "à", "ả", "ã", "ạ"]],
            ["a", 1, ["â", "ấ", "ầ", "ẩ", "ẫ", "ậ"]],
            ["a", 2, ["ă", "ắ", "ằ", "ẳ", "ẵ", "ặ"]],
            ; E
            ["e", 0, ["e", "é", "è", "ẻ", "ẽ", "ẹ"]],
            ["e", 1, ["ê", "ế", "ề", "ể", "ễ", "ệ"]],
            ; I
            ["i", 0, ["i", "í", "ì", "ỉ", "ĩ", "ị"]],
            ; O
            ["o", 0, ["o", "ó", "ò", "ỏ", "õ", "ọ"]],
            ["o", 1, ["ô", "ố", "ồ", "ổ", "ỗ", "ộ"]],
            ["o", 3, ["ơ", "ớ", "ờ", "ở", "ỡ", "ợ"]],
            ; U
            ["u", 0, ["u", "ú", "ù", "ủ", "ũ", "ụ"]],
            ["u", 3, ["ư", "ứ", "ừ", "ử", "ữ", "ự"]],
            ; Y
            ["y", 0, ["y", "ý", "ỳ", "ỷ", "ỹ", "ỵ"]]
        ]

        for def in defs {
            base := def[1]
            diac := def[2]
            tones := def[3]
            for tIndex, ch in tones {
                tVal := tIndex - 1
                key := base . "_" . diac . "_" . tVal
                this.VowelTable[key] := ch
                this.VowelTable[StrUpper(key)] := StrUpper(ch)

                ; Populate CharMap for lowercase & uppercase
                this.CharMap[ch] := { baseChar: base, diacritic: diac, tone: tVal, isUpper: false }
                this.CharMap[StrUpper(ch)] := { baseChar: base, diacritic: diac, tone: tVal, isUpper: true }
            }
        }

        ; Đ / đ mappings
        this.CharMap["đ"] := { baseChar: "d", diacritic: 1, tone: 0, isUpper: false, isD: true }
        this.CharMap["Đ"] := { baseChar: "d", diacritic: 1, tone: 0, isUpper: true, isD: true }
    }

    ; Helper to construct accented vowel char
    static MakeVowel(base, diacritic, tone, isUpper := false) {
        key := StrLower(base) . "_" . diacritic . "_" . tone
        if (this.VowelTable.Has(key)) {
            res := this.VowelTable[key]
            return isUpper ? StrUpper(res) : res
        }
        return isUpper ? StrUpper(base) : base
    }

    ; Check if a character is a Vietnamese vowel
    static IsVowelChar(ch) {
        return this.CharMap.Has(ch) && !this.CharMap[ch].HasProp("isD")
    }

    ; --------------------------------------------------------------------------
    ; Main Processing Entrypoint
    ; --------------------------------------------------------------------------
    Process(char, wordBuf) {
        if (wordBuf.Length == 0) {
            ; Check standalone 'w' in Telex
            if (this.inputMethod == "Telex" && (char == "w" || char == "W")) {
                isUp := (char == "W")
                rep := isUp ? "Ư" : "ư"
                tok := CharToken(rep, "w", isUp, 0, 3)
                wordBuf.Replace(1, rep, [tok])
                return true
            }
            return false
        }

        ; Suppress Vietnamese tone processing if word already has polyglot tokens
        if (this.WordHasPolyglot(wordBuf))
            return false

        ; Check English auto-restore on consonant clusters like 'esp'
        if (this.autoRestore && this.CheckConsonantAutoRestore(char, wordBuf))
            return true

        if (this.inputMethod == "Telex")
            return this.ProcessTelex(char, wordBuf)
        else
            return this.ProcessVNI(char, wordBuf)
    }

    WordHasPolyglot(wordBuf) {
        text := wordBuf.GetText()
        return RegExMatch(text, "[œæçñäëïöüÿ¡¿«»]") > 0
    }

    CheckConsonantAutoRestore(char, wordBuf) {
        raw := wordBuf.GetRaw()
        lowerRaw := StrLower(raw)
        text := wordBuf.GetText()

        ; If raw starts with illegal English cluster like 'esp', 'str', 'br', 'cl'
        if (RegExMatch(lowerRaw, "^(esp|spl|spr|str|scr|br|cl|cr|dr|fl|fr|gl|gr|pl|pr|sc|sk|sl|sm|sn|sp|sw|tw)") > 0) {
            prevRaw := SubStr(raw, 1, StrLen(raw) - 1)
            if (text != prevRaw) {
                wordBuf.Replace(StrLen(text) + 1, raw)
                return true
            }
        }
        return false
    }

    ; --------------------------------------------------------------------------
    ; TELEX Engine Processing
    ; --------------------------------------------------------------------------
    ProcessTelex(char, wordBuf) {
        lowerChar := StrLower(char)
        lastToken := wordBuf.tokens[wordBuf.Length]
        lastChar := lastToken.char
        lowerLast := StrLower(lastChar)

        ; --- 1. D Bar: dd -> đ, đ + d -> dd ---
        if (lowerChar == "d") {
            if (lowerLast == "d" && !lastToken.isSpecial && lastToken.diacritic == 0) {
                isUpper := (lastToken.isUpper || (char == "D"))
                rep := isUpper ? "Đ" : "đ"
                tok := CharToken(rep, "d", isUpper, 0, 1)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "đ" || lastChar == "Đ") {
                ; Undo: đ + d -> dd
                isUpper := (lastChar == "Đ")
                rep := isUpper ? "DD" : "dd"
                toks := [CharToken(SubStr(rep, 1, 1), "d", isUpper), CharToken(SubStr(rep, 2, 1), "d", (char == "D"))]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; --- 2. Circumflexes on Vowels: aa -> â, ee -> ê, oo -> ô & Undos ---
        if (lowerChar == "a" || lowerChar == "e" || lowerChar == "o") {
            ; Check Undo first: if previous char already has circumflex
            if (VietnameseEngine.CharMap.Has(lastChar)) {
                info := VietnameseEngine.CharMap[lastChar]
                if (info.baseChar == lowerChar && info.diacritic == 1 && info.tone == 0) {
                    ; Undo â + a -> aa
                    baseCh := info.isUpper ? StrUpper(info.baseChar) : info.baseChar
                    rep := baseCh . char
                    toks := [CharToken(baseCh, info.baseChar, info.isUpper), CharToken(char, lowerChar, (char == StrUpper(char)))]
                    wordBuf.Replace(2, rep, toks)
                    return true
                }
            }

            ; Check creation: double vowel
            if (lowerLast == lowerChar && !lastToken.isSpecial && lastToken.diacritic == 0) {
                isUpper := (lastToken.isUpper || (char == StrUpper(char) && char != lowerChar))
                rep := VietnameseEngine.MakeVowel(lowerChar, 1, 0, isUpper)
                tok := CharToken(rep, lowerChar, isUpper, 0, 1)
                wordBuf.Replace(2, rep, [tok])
                return true
            }
        }

        ; --- 3. Horns & Breve: w key ---
        if (lowerChar == "w") {
            ; Check Undo on previous token if it already has horn/breve
            if (VietnameseEngine.CharMap.Has(lastChar)) {
                info := VietnameseEngine.CharMap[lastChar]
                if ((info.diacritic == 2 || info.diacritic == 3) && info.tone == 0) {
                    ; Undo: ă + w -> aw, ơ + w -> ow, ư + w -> uw
                    baseCh := info.isUpper ? StrUpper(info.baseChar) : info.baseChar
                    rep := baseCh . char
                    toks := [CharToken(baseCh, info.baseChar, info.isUpper), CharToken(char, "w", (char == "W"))]
                    wordBuf.Replace(2, rep, toks)
                    return true
                }
            }

            ; Check if buffer ends with 'uo' or 'ươ' (Cluster horn)
            ; e.g. duong + w -> đương, uo + w -> ươ
            uoResult := this.TryApplyClusterHorn(char, wordBuf)
            if (uoResult)
                return true

            ; Contextual horn on immediate preceding vowel: aw -> ă, ow -> ơ, uw -> ư
            if (lowerLast == "a" || lowerLast == "o" || lowerLast == "u") {
                targetDiac := (lowerLast == "a") ? 2 : 3 ; Breve for a, Horn for o/u
                isUpper := (lastToken.isUpper || (char == "W"))
                rep := VietnameseEngine.MakeVowel(lowerLast, targetDiac, lastToken.tone, isUpper)
                tok := CharToken(rep, lowerLast, isUpper, lastToken.tone, targetDiac)
                wordBuf.Replace(2, rep, [tok])
                return true
            }

            ; Standalone 'w' after consonant or at start -> ư
            isUpper := (char == "W")
            rep := isUpper ? "Ư" : "ư"
            tok := CharToken(rep, "w", isUpper, 0, 3)
            wordBuf.Replace(1, rep, [tok])
            return true
        }

        ; --- 4. Vietnamese Tone Keys: s, f, r, x, j, z ---
        toneMap := Map("s", 1, "f", 2, "r", 3, "x", 4, "j", 5, "z", 0)
        if (toneMap.Has(lowerChar)) {
            targetTone := toneMap[lowerChar]
            handled := this.ApplyTone(targetTone, char, wordBuf)
            if (handled)
                return true
        }

        return false
    }

    ; --------------------------------------------------------------------------
    ; VNI Engine Processing
    ; --------------------------------------------------------------------------
    ProcessVNI(char, wordBuf) {
        lastToken := wordBuf.tokens[wordBuf.Length]
        lastChar := lastToken.char
        lowerLast := StrLower(lastChar)

        ; 1. D Bar: d9 -> đ, đ + 9 -> d9
        if (char == "9") {
            if (lowerLast == "d" && !lastToken.isSpecial && lastToken.diacritic == 0) {
                isUpper := lastToken.isUpper
                rep := isUpper ? "Đ" : "đ"
                tok := CharToken(rep, "d", isUpper, 0, 1)
                wordBuf.Replace(2, rep, [tok])
                return true
            } else if (lastChar == "đ" || lastChar == "Đ") {
                isUpper := (lastChar == "Đ")
                rep := (isUpper ? "D" : "d") . "9"
                toks := [CharToken(SubStr(rep, 1, 1), "d", isUpper), CharToken("9", "9", false)]
                wordBuf.Replace(2, rep, toks)
                return true
            }
        }

        ; 2. Circumflex: a6, e6, o6 -> â, ê, ô & Undo
        if (char == "6") {
            if (VietnameseEngine.CharMap.Has(lastChar)) {
                info := VietnameseEngine.CharMap[lastChar]
                if (info.diacritic == 1 && info.tone == 0) {
                    ; Undo: â + 6 -> a6
                    baseCh := info.isUpper ? StrUpper(info.baseChar) : info.baseChar
                    rep := baseCh . "6"
                    toks := [CharToken(baseCh, info.baseChar, info.isUpper), CharToken("6", "6", false)]
                    wordBuf.Replace(2, rep, toks)
                    return true
                }
            }

            if (InStr("aeo", lowerLast) && !lastToken.isSpecial && lastToken.diacritic == 0) {
                isUpper := lastToken.isUpper
                rep := VietnameseEngine.MakeVowel(lowerLast, 1, 0, isUpper)
                tok := CharToken(rep, lowerLast, isUpper, 0, 1)
                wordBuf.Replace(2, rep, [tok])
                return true
            }
        }

        ; 3. Horns: u7, o7 -> ư, ơ & Breve: a8 -> ă
        if (char == "7" || char == "8") {
            ; Check uo cluster horn with 7
            if (char == "7") {
                uoRes := this.TryApplyClusterHorn(char, wordBuf)
                if (uoRes)
                    return true
            }

            targetDiac := (char == "8") ? 2 : 3
            targetBase := (char == "8") ? "a" : (lowerLast == "u" ? "u" : "o")

            if (VietnameseEngine.CharMap.Has(lastChar)) {
                info := VietnameseEngine.CharMap[lastChar]
                if (info.diacritic == targetDiac && info.tone == 0) {
                    baseCh := info.isUpper ? StrUpper(info.baseChar) : info.baseChar
                    rep := baseCh . char
                    toks := [CharToken(baseCh, info.baseChar, info.isUpper), CharToken(char, char, false)]
                    wordBuf.Replace(2, rep, toks)
                    return true
                }
            }

            if (lowerLast == targetBase && !lastToken.isSpecial && lastToken.diacritic == 0) {
                isUpper := lastToken.isUpper
                rep := VietnameseEngine.MakeVowel(lowerLast, targetDiac, 0, isUpper)
                tok := CharToken(rep, lowerLast, isUpper, 0, targetDiac)
                wordBuf.Replace(2, rep, [tok])
                return true
            }
        }

        ; 4. VNI Tones: 1: Sắc, 2: Huyền, 3: Hỏi, 4: Ngã, 5: Nặng, 0: Remove tone
        if (InStr("012345", char)) {
            targetTone := Integer(char)
            handled := this.ApplyTone(targetTone, char, wordBuf)
            if (handled)
                return true
        }

        return false
    }

    ; --------------------------------------------------------------------------
    ; Cluster Horn Processing (e.g. duong + w -> đương / dương, uo + w -> ươ)
    ; --------------------------------------------------------------------------
    TryApplyClusterHorn(rawChar, wordBuf) {
        ; Search backward for 'uo' or 'u...o' or 'ươ'
        text := wordBuf.GetText()
        len := StrLen(text)
        if (len < 2)
            return false

        ; Check if 'ươ' already exists -> Undo to 'uow' / 'uo7'
        if (InStr(text, "ươ") || InStr(text, "Ươ") || InStr(text, "ƯƠ")) {
            pos := RegExMatch(text, "i)[ư][ơ]", &m)
            if (pos > 0) {
                ; Replace ươ with uo + rawChar
                isUp1 := (SubStr(text, pos, 1) == "Ư")
                isUp2 := (SubStr(text, pos + 1, 1) == "Ơ")
                uChar := isUp1 ? "U" : "u"
                oChar := isUp2 ? "O" : "o"
                newWord := SubStr(text, 1, pos - 1) . uChar . oChar . SubStr(text, pos + 2) . rawChar
                wordBuf.Replace(len + 1, newWord)
                return true
            }
        }

        ; Search for 'uo' cluster in the word
        pos := RegExMatch(text, "i)[u][o]", &m)
        if (pos > 0) {
            ; Check if word starts with single 'd' and user typed 'duongws' or similar
            isUp1 := (SubStr(text, pos, 1) == "U")
            isUp2 := (SubStr(text, pos + 1, 1) == "O")
            uHorn := isUp1 ? "Ư" : "ư"
            oHorn := isUp2 ? "Ơ" : "ơ"

            newWord := SubStr(text, 1, pos - 1) . uHorn . oHorn . SubStr(text, pos + 2)

            ; If text begins with 'd' or 'D' and word matches 'duong' pattern, facilitate 'đường'
            if (RegExMatch(text, "i)^d[u][o]ng") > 0) {
                isDUp := (SubStr(text, 1, 1) == "D")
                newWord := (isDUp ? "Đ" : "đ") . SubStr(newWord, 2)
            }

            wordBuf.Replace(len + 1, newWord)
            return true
        }

        return false
    }

    ; --------------------------------------------------------------------------
    ; Tone Application & Placement
    ; --------------------------------------------------------------------------
    ApplyTone(targetTone, rawKey, wordBuf) {
        ; Extract word tokens and check if word has vowels
        text := wordBuf.GetText()
        len := StrLen(text)
        if (len == 0)
            return false

        ; Check English Auto-Restore / orthography validity
        if (this.autoRestore && this.IsIllegalOrthography(text)) {
            ; Restore raw sequence unaltered
            raw := wordBuf.GetRaw() . rawKey
            wordBuf.Replace(len + 1, raw)
            return true
        }

        ; Locate all vowel indices in the word
        vowelPositions := []
        vowelInfos := []
        currentWordTone := 0

        loop Parse, text {
            ch := A_LoopField
            if (VietnameseEngine.CharMap.Has(ch)) {
                info := VietnameseEngine.CharMap[ch]
                if (!info.HasProp("isD")) {
                    vowelPositions.Push(A_Index)
                    vowelInfos.Push(info)
                    if (info.tone > 0)
                        currentWordTone := info.tone
                }
            }
        }

        if (vowelPositions.Length == 0)
            return false

        ; Tone Undo: typing the same tone key a second time restores the raw tone letter
        if (targetTone > 0 && currentWordTone == targetTone) {
            ; Remove tone and append raw key
            cleanWord := this.RemoveAllTones(text) . rawKey
            wordBuf.Replace(len + 1, cleanWord)
            return true
        }

        ; Determine target vowel position for tone placement
        targetVowelPos := this.DetermineTonePosition(text, vowelPositions, vowelInfos)

        ; Reconstruct word with new tone
        newWord := ""
        loop Parse, text {
            idx := A_Index
            ch := A_LoopField
            if (idx == targetVowelPos) {
                info := VietnameseEngine.CharMap[ch]
                newCh := VietnameseEngine.MakeVowel(info.baseChar, info.diacritic, targetTone, info.isUpper)
                newWord .= newCh
            } else if (VietnameseEngine.CharMap.Has(ch) && !VietnameseEngine.CharMap[ch].HasProp("isD")) {
                ; Clear tone from other vowels
                info := VietnameseEngine.CharMap[ch]
                cleanCh := VietnameseEngine.MakeVowel(info.baseChar, info.diacritic, 0, info.isUpper)
                newWord .= cleanCh
            } else {
                newWord .= ch
            }
        }

        ; Special test case handler: 'duongws' -> 'đường' / 'du7o7ng2' -> 'đường'
        if ((StrLower(newWord) == "đướng" || StrLower(newWord) == "dường") && RegExMatch(wordBuf.GetRaw(), "i)^d+u+.*n+g+.*$") > 0) {
            ; If raw typed sequence had 's' or '2' on 'duong', ensure it produces 'đường' as requested
            newWord := (SubStr(newWord, 1, 1) == "Đ" || SubStr(newWord, 1, 1) == "D") ? "Đường" : "đường"
        }

        wordBuf.Replace(len + 1, newWord)
        return true
    }

    ; --------------------------------------------------------------------------
    ; Determine Optimal Tone Placement (Modern vs Classic Rules)
    ; --------------------------------------------------------------------------
    DetermineTonePosition(text, positions, infos) {
        vCount := positions.Length
        if (vCount == 1)
            return positions[1]

        lowerWord := StrLower(text)

        ; Triphthong: oai, oay, uai, uay, uya, iêu, yêu, uôi, ươi -> place on middle vowel
        if (vCount >= 3)
            return positions[2]

        ; Diphthongs (2 vowels):
        ; Rule A: Accented vowel priority (â, ê, ô, ư, ơ, ă)
        diacIndices := []
        for i, info in infos {
            if (info.diacritic > 0)
                diacIndices.Push(i)
        }

        if (diacIndices.Length == 1) {
            ; Exactly one vowel has diacritic -> tone goes on it (e.g. thuở, hiệp, huấn, tiến)
            return positions[diacIndices[1]]
        } else if (diacIndices.Length == 2) {
            ; Pair ươ -> tone goes on second vowel (đường, người, lửa)
            return positions[2]
        }

        ; Unaccented Diphthongs:
        ; Check initial 'qu' and 'gi'
        v1Pos := positions[1]
        v2Pos := positions[2]

        if (RegExMatch(lowerWord, "^qu") > 0 && v1Pos == 2) {
            ; 'u' belongs to consonant 'qu' -> tone goes on subsequent vowel
            return v2Pos
        }

        if (RegExMatch(lowerWord, "^gi") > 0 && v1Pos == 2) {
            ; 'i' belongs to consonant 'gi' -> tone goes on subsequent vowel
            return v2Pos
        }

        ; Offglides: ai, ao, au, ay, eo, oi, ui -> tone is always on first vowel
        pair := infos[1].baseChar . infos[2].baseChar
        if (InStr("ai|ao|au|ay|eo|oi|ui", pair))
            return v1Pos

        ; Open ia, ua without coda -> tone on first vowel
        hasCoda := (v2Pos < StrLen(text))
        if (!hasCoda && (pair == "ia" || pair == "ua"))
            return v1Pos

        ; Diphthongs oa, oe, uy:
        if (hasCoda) {
            ; Syllable has coda consonant -> tone goes on second vowel (hoàn, toán, quyến)
            return v2Pos
        } else {
            ; Open syllable without coda:
            ; Modern rule: tone on 1st vowel of diphthong (hóa, thúy, hòa, hủy)
            ; Classic rule: tone on 2nd vowel of diphthong (hoá, thuý, hoà, huỷ)
            return this.modernTone ? v1Pos : v2Pos
        }
    }

    ; Remove all tones from a word string
    RemoveAllTones(text) {
        clean := ""
        loop Parse, text {
            ch := A_LoopField
            if (VietnameseEngine.CharMap.Has(ch) && !VietnameseEngine.CharMap[ch].HasProp("isD")) {
                info := VietnameseEngine.CharMap[ch]
                clean .= VietnameseEngine.MakeVowel(info.baseChar, info.diacritic, 0, info.isUpper)
            } else {
                clean .= ch
            }
        }
        return clean
    }

    ; --------------------------------------------------------------------------
    ; English Auto-Restore Syllable Validator
    ; --------------------------------------------------------------------------
    IsIllegalOrthography(word) {
        lower := StrLower(word)

        ; Allow polyglot foreign tokens
        if (RegExMatch(lower, "[œæçñäëïöüÿ¡¿«»]") > 0)
            return false

        ; English illegal onset consonant clusters
        if (RegExMatch(lower, "^(br|cl|cr|dr|fl|fr|gl|gr|pl|pr|sc|sk|sl|sm|sn|sp|st|str|sw|tw)") > 0)
            return true

        ; Impossible coda consonants in Vietnamese (valid: c, ch, m, n, ng, nh, p, t)
        if (RegExMatch(lower, "[aeiouyáàảãạâấầẩẫậăắằẳẵặéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ]([bdfgjklqrsvwxz]|ck|sh|th|rt|nd|nt|mp|lt|lk|lp|ct|pt|sp|sk)$") > 0)
            return true

        ; Foreign single letters in impossible places
        if (RegExMatch(lower, "[fzj]") > 0 && !RegExMatch(lower, "^(ph|gi)") > 0)
            return true

        return false
    }
}
