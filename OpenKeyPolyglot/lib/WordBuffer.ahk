#Requires AutoHotkey v2.0
; ==============================================================================
; WordBuffer.ahk - Rolling Token Buffer & State Tracking
; Part of OhlalaKey / OpenKey Polyglot IME
; ==============================================================================

class CharToken {
    char := ""
    rawKey := ""
    isUpper := false
    tone := 0          ; 0: None, 1: Sắc, 2: Huyền, 3: Hỏi, 4: Ngã, 5: Nặng
    diacritic := 0     ; 0: None, 1: Circumflex ^, 2: Breve ă, 3: Horn ơ/ư, 4: Tréma ¨
    isSpecial := false ; ç, ñ, œ, æ, ¡, ¿, guillemets

    __New(char := "", rawKey := "", isUpper := false, tone := 0, diacritic := 0, isSpecial := false) {
        this.char := char
        this.rawKey := (rawKey != "") ? rawKey : char
        this.isUpper := isUpper
        this.tone := tone
        this.diacritic := diacritic
        this.isSpecial := isSpecial
    }

    Clone() {
        return CharToken(this.char, this.rawKey, this.isUpper, this.tone, this.diacritic, this.isSpecial)
    }
}

class WordBuffer {
    tokens := []
    rawSequence := ""
    emitter := "" ; Custom callback (bsCount, text) => void for headless testing

    __New(customEmitter := "") {
        this.tokens := []
        this.rawSequence := ""
        if (customEmitter != "" && HasMethod(customEmitter))
            this.emitter := customEmitter
        else
            this.emitter := ""
    }

    ; Property returning token count
    Length => this.tokens.Length

    ; Append raw typed keystroke
    AppendRaw(char) {
        this.rawSequence .= char
    }

    ; Append a new character token
    PushChar(ch, raw := "", isUpper := false, tone := 0, diacritic := 0, isSpecial := false) {
        if (raw == "")
            raw := ch
        token := CharToken(ch, raw, isUpper, tone, diacritic, isSpecial)
        this.tokens.Push(token)
        return token
    }

    ; Push an existing CharToken instance
    PushToken(token) {
        this.tokens.Push(token)
    }

    ; Pop last token (e.g. on Backspace key)
    Pop() {
        if (this.tokens.Length == 0) {
            if (StrLen(this.rawSequence) > 0)
                this.rawSequence := SubStr(this.rawSequence, 1, StrLen(this.rawSequence) - 1)
            return
        }

        token := this.tokens.Pop()
        if (StrLen(this.rawSequence) > 0)
            this.rawSequence := SubStr(this.rawSequence, 1, StrLen(this.rawSequence) - 1)
        return token
    }

    ; Return currently visible string on screen
    GetText() {
        str := ""
        for token in this.tokens {
            str .= token.char
        }
        return str
    }

    ; Return unaltered typed sequence
    GetRaw() {
        return this.rawSequence
    }

    ; Calculates exact {Backspace count} needed and emits SendText newString
    Replace(count, newString, newTokens := unset) {
        ; Send backspaces
        if (count > 0) {
            this.EmitBackspace(count)
            ; The newly typed character was rendered on screen but has not yet been pushed
            ; to this.tokens. Thus, the number of existing tokens to pop is count - 1.
            tokensToRemove := count - 1
            loop tokensToRemove {
                if (this.tokens.Length > 0)
                    this.tokens.Pop()
            }
        }

        ; Send new string
        if (newString != "") {
            this.EmitText(newString)
            if (IsSet(newTokens) && (newTokens is Array)) {
                for tok in newTokens {
                    this.tokens.Push(tok)
                }
            } else {
                ; Create simple tokens for the newly emitted characters
                loop Parse, newString {
                    ch := A_LoopField
                    isUp := (ch == StrUpper(ch) && ch != StrLower(ch))
                    this.tokens.Push(CharToken(ch, ch, isUp))
                }
            }
        }
    }

    ; Emit backspaces either via custom emitter or SendInput
    EmitBackspace(count) {
        if (this.emitter != "" && HasMethod(this.emitter)) {
            this.emitter.Call(count, "")
        } else {
            SendInput("{BS " . count . "}")
        }
    }

    ; Emit text either via custom emitter or SendText
    EmitText(str) {
        if (this.emitter != "" && HasMethod(this.emitter)) {
            this.emitter.Call(0, str)
        } else {
            SendText(str)
        }
    }

    ; Flush the state upon encountering a word boundary
    Reset() {
        this.tokens := []
        this.rawSequence := ""
    }
}
