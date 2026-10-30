#Requires AutoHotkey v2.0
; ==============================================================================
; RunTests.ahk - Automated Verification & Test Suite for OhlalaKey
; ==============================================================================

OnError(HandleError)
HandleError(thrown, mode) {
    FileAppend("EXCEPTION: " . thrown.Message . "`nLine: " . thrown.Line . "`nFile: " . thrown.File . "`nStack:`n" . thrown.Stack . "`n", A_ScriptDir . "\test_results.txt")
    ExitApp(1)
}

#Include ..\OpenKeyPolyglot\lib\WordBuffer.ahk
#Include ..\OpenKeyPolyglot\lib\PolyglotEngine.ahk
#Include ..\OpenKeyPolyglot\lib\VietnameseEngine.ahk
#Include ..\OpenKeyPolyglot\lib\MacroManager.ahk

class SimulatedIME {
    wordBuf := unset
    polyglot := unset
    vietnamese := unset
    macroMgr := unset
    screen := ""
    maxBsInSingleEmit := 0
    totalBsEmitted := 0

    __New(method := "Telex", modernTone := true, autoRestore := true, polyglotEnabled := true) {
        this.screen := ""
        this.maxBsInSingleEmit := 0
        this.totalBsEmitted := 0
        this.wordBuf := WordBuffer(ObjBindMethod(this, "OnEmit"))
        this.polyglot := PolyglotEngine(method, polyglotEnabled)
        this.vietnamese := VietnameseEngine(method, modernTone, autoRestore)
        this.macroMgr := MacroManager(A_ScriptDir . "\..\OpenKeyPolyglot\macros.txt", true)
    }

    OnEmit(bsCount, text) {
        if (bsCount > this.maxBsInSingleEmit)
            this.maxBsInSingleEmit := bsCount
        this.totalBsEmitted += bsCount

        if (bsCount > 0) {
            if (StrLen(this.screen) >= bsCount) {
                this.screen := SubStr(this.screen, 1, StrLen(this.screen) - bsCount)
            } else {
                this.screen := ""
            }
        }
        if (text != "") {
            this.screen .= text
        }
    }

    TypeChar(char) {
        ; 1. Visible mode passes character to screen first
        this.screen .= char

        ; 2. Word boundary Space
        if (char == " ") {
            expanded := this.macroMgr.CheckAndExpand(this.wordBuf, " ")
            if (!expanded) {
                this.wordBuf.Reset()
                this.polyglot.ClearPunctState()
            }
            return
        }

        this.wordBuf.AppendRaw(char)

        ; 3. Punctuation Handling (!, ?, ')
        if (char == "!" || char == "?" || char == "'") {
            if (this.polyglot.HandlePunctuation(char, this.wordBuf))
                return
        }

        ; 4. Polyglot Foreign Rules
        if (this.polyglot.enabled) {
            if (this.polyglot.Process(char, this.wordBuf))
                return
        }

        ; 5. Vietnamese Rules
        if (!this.polyglot.isGuillemetOpen) {
            if (this.vietnamese.Process(char, this.wordBuf))
                return
        }

        ; 6. Normal key
        isUpper := (char == StrUpper(char) && char !== StrLower(char))
        this.wordBuf.PushChar(char, char, isUpper)
    }

    TypeSequence(str) {
        loop Parse, str {
            this.TypeChar(A_LoopField)
        }
        return this.screen
    }
}

; ------------------------------------------------------------------------------
; Test Runner
; ------------------------------------------------------------------------------
totalTests := 0
passedTests := 0
failedTests := 0
failures := []

global OutFile := A_ScriptDir . "\test_results.txt"
try FileDelete(OutFile)

AssertTest(testName, inputSeq, expectedOutput, method := "Telex", modernTone := true, polyglot := true) {
    global totalTests, passedTests, failedTests, failures, OutFile
    totalTests++

    ime := SimulatedIME(method, modernTone, true, polyglot)
    actual := ime.TypeSequence(inputSeq)

    if (actual == expectedOutput) {
        passedTests++
        FileAppend("[PASS] " . testName . " ('" . inputSeq . "' -> '" . actual . "')`n", OutFile)
    } else {
        failedTests++
        msg := "[FAIL] " . testName . ": input='" . inputSeq . "', expected='" . expectedOutput . "', got='" . actual . "'"
        failures.Push(msg)
        FileAppend(msg . "`n", OutFile)
    }
    return ime
}

FileAppend("=== RUNNING OHLALAKEY IME TEST SUITE ===`n", OutFile)

; 1. Modern vs Classic Tone Placement (Issue 4 alignment)
; Modern: nucleus 2nd vowel (hoá, thuý). Classic: 1st vowel (hóa, thúy).
AssertTest("Vietnamese Telex: hoas (modern)", "hoas", "hoá", "Telex", true)
AssertTest("Vietnamese Telex: hoas (classic)", "hoas", "hóa", "Telex", false)
AssertTest("Vietnamese VNI: hoa1 (modern)", "hoa1", "hoá", "VNI", true)
AssertTest("Vietnamese VNI: hoa1 (classic)", "hoa1", "hóa", "VNI", false)
AssertTest("Vietnamese Telex: toans", "toans", "toán", "Telex", true)
AssertTest("Vietnamese Telex: tieengs", "tieengs", "tiếng", "Telex", true)

; 2. Initial Consonant Isolation (Issue 2: no forced d -> đ hack)
AssertTest("Consonant Isolation: duongw -> dương", "duongw", "dương", "Telex")
AssertTest("Consonant Isolation: dduongwf -> đường", "dduongwf", "đường", "Telex")
AssertTest("Consonant Isolation: dduongws -> đướng", "dduongws", "đướng", "Telex")
AssertTest("Consonant Isolation: du7o7ng2 -> dường", "du7o7ng2", "dường", "VNI")
AssertTest("Consonant Isolation: d9u7o7ng2 -> đường", "d9u7o7ng2", "đường", "VNI")
AssertTest("Vietnamese Telex: dd", "dd", "đ", "Telex")
AssertTest("Vietnamese Telex: ddd (undo)", "ddd", "dd", "Telex")
AssertTest("Vietnamese VNI: d9", "d9", "đ", "VNI")
AssertTest("Vietnamese VNI: d99 (undo)", "d99", "d9", "VNI")

; 3. Telex Tone Toggle & Token Synchronization (Issue 1)
totalTests++
imeToggle := SimulatedIME("Telex", true, true, true)
imeToggle.TypeSequence("toanss")
if (imeToggle.screen == "toans" && imeToggle.wordBuf.tokens.Length == 5) {
    passedTests++
    FileAppend("[PASS] Telex Tone Toggle: toans + s -> toans (tokens synced: 5)`n", OutFile)
} else {
    failedTests++
    msg := "[FAIL] Telex Tone Toggle: screen='" . imeToggle.screen . "', tokens.Length=" . imeToggle.wordBuf.tokens.Length . " (expected 'toans' and 5)"
    failures.Push(msg)
    FileAppend(msg . "`n", OutFile)
}

; 4. Case Preservation & Extended Foreign Grammar
AssertTest("Case Preservation: Noel -> Noël", "Noel", "Noël", "Telex")
AssertTest("Case Preservation: NOEL -> NOËL", "NOEL", "NOËL", "Telex")
AssertTest("French: coeur -> cœur", "coeur", "cœur", "Telex")
AssertTest("French: COEUR -> CŒUR", "COEUR", "CŒUR", "Telex")
AssertTest("French: cca -> ça", "cca", "ça", "Telex")
AssertTest("French: nailve -> naïve", "nailve", "naïve", "Telex")
AssertTest("French: nalive -> naïve", "nalive", "naïve", "Telex")
AssertTest("French Grave: ouf -> où", "ouf", "où", "Telex")
AssertTest("French Grave Continuity: oufs -> oùs", "oufs", "oùs", "Telex")
AssertTest("French Guillemets: ''bonjour''", "''bonjour''", "«" . Chr(0x00A0) . "bonjour" . Chr(0x00A0) . "»", "Telex")

; 5. Spanish Grammar
AssertTest("Spanish: espannol -> español", "espannol", "español", "Telex")
AssertTest("Spanish: ESPANNOL -> ESPAÑOL", "ESPANNOL", "ESPAÑOL", "Telex")
AssertTest("Spanish Inverted Excl: !!Hola!", "!!Hola!", "¡Hola!", "Telex")
AssertTest("Spanish Inverted Ques Reversion: ???", "???", "???", "Telex")

; 6. Word Boundary Backspacing Underflow Protection (Issue 3)
totalTests++
imeUnderflow := SimulatedIME("Telex", true, true, true)
imeUnderflow.TypeSequence("w")
if (imeUnderflow.screen == "ư" && imeUnderflow.maxBsInSingleEmit <= 1) {
    passedTests++
    FileAppend("[PASS] Word Boundary Backspacing: standalone 'w' at boundary emits <= 1 BS`n", OutFile)
} else {
    failedTests++
    msg := "[FAIL] Word Boundary Backspacing: screen='" . imeUnderflow.screen . "', maxBs=" . imeUnderflow.maxBsInSingleEmit . " (expected 'ư' and maxBs <= 1)"
    failures.Push(msg)
    FileAppend(msg . "`n", OutFile)
}

; 7. English Rollback & Auto-Restore
AssertTest("English Rollback: oll -> oll", "oll", "oll", "Telex")
AssertTest("English Rollback: oill -> oill", "oill", "oill", "Telex")

; 8. Macro Expansion Tests
AssertTest("Macro: vn + Space", "vn ", "Việt Nam ", "Telex")
AssertTest("Macro: ok + Space", "ok ", "OhlalaKey ", "Telex")

FileAppend("`n=== SUMMARY ===`n", OutFile)
FileAppend("Total: " . totalTests . ", Passed: " . passedTests . ", Failed: " . failedTests . "`n", OutFile)

if (failedTests > 0) {
    FileAppend("`nFailures detail:`n", OutFile)
    for f in failures {
        FileAppend(" - " . f . "`n", OutFile)
    }
    ExitApp(1)
} else {
    FileAppend("ALL TESTS PASSED SUCCESSFULLY!`n", OutFile)
    ExitApp(0)
}
