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

    __New(method := "Telex", modernTone := true, autoRestore := true, polyglotEnabled := true) {
        this.screen := ""
        this.wordBuf := WordBuffer(ObjBindMethod(this, "OnEmit"))
        this.polyglot := PolyglotEngine(method, polyglotEnabled)
        this.vietnamese := VietnameseEngine(method, modernTone, autoRestore)
        this.macroMgr := MacroManager(A_ScriptDir . "\..\OpenKeyPolyglot\macros.txt", true)
    }

    OnEmit(bsCount, text) {
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
        isUpper := (char == StrUpper(char) && char != StrLower(char))
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
}

FileAppend("=== RUNNING OHLALAKEY IME TEST SUITE ===`n", OutFile)

; Vietnamese Telex Tests
AssertTest("Vietnamese Telex: duongws", "duongws", "đường", "Telex")
AssertTest("Vietnamese Telex: hoas (modern)", "hoas", "hóa", "Telex", true)
AssertTest("Vietnamese Telex: hoas (classic)", "hoas", "hoá", "Telex", false)
AssertTest("Vietnamese Telex: dd", "dd", "đ", "Telex")
AssertTest("Vietnamese Telex: ddd (undo)", "ddd", "dd", "Telex")
AssertTest("Vietnamese Telex: toans", "toans", "toán", "Telex")
AssertTest("Vietnamese Telex: tieengs", "tieengs", "tiếng", "Telex")

; Vietnamese VNI Tests
AssertTest("Vietnamese VNI: du7o7ng2", "du7o7ng2", "đường", "VNI")
AssertTest("Vietnamese VNI: d9", "d9", "đ", "VNI")
AssertTest("Vietnamese VNI: hoa1 (modern)", "hoa1", "hóa", "VNI", true)
AssertTest("Vietnamese VNI: hoa1 (classic)", "hoa1", "hoá", "VNI", false)

; French Tests
AssertTest("French: coeur -> cœur", "coeur", "cœur", "Telex")
AssertTest("French: cca -> ça", "cca", "ça", "Telex")
AssertTest("French: nailve -> naïve", "nailve", "naïve", "Telex")
AssertTest("French: nalive -> naïve", "nalive", "naïve", "Telex")
AssertTest("French: Noel -> Noël", "Noel", "Noël", "Telex")
AssertTest("French Guillemets: ''bonjour''", "''bonjour''", "«" . Chr(0x00A0) . "bonjour" . Chr(0x00A0) . "»", "Telex")

; Spanish Tests
AssertTest("Spanish: espannol -> español", "espannol", "español", "Telex")
AssertTest("Spanish Inverted Excl: !!Hola!", "!!Hola!", "¡Hola!", "Telex")
AssertTest("Spanish Inverted Ques Reversion: ???", "???", "???", "Telex")

; English Rollback
AssertTest("English Rollback: oll -> oll", "oll", "oll", "Telex")
AssertTest("English Rollback: oill -> oill", "oill", "oill", "Telex")

; Macro Expansion Tests
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

