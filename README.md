# 🌐 OhlalaKey - Vietnamese & Polyglot Input Method Engine

> **A high-performance, interpreted Vietnamese & Polyglot (French / Spanish) Input Method Engine written purely in AutoHotkey v2 (64-bit) for Windows 11.**

[![AutoHotkey](https://img.shields.io/badge/Language-AutoHotkey%20v2.0+-green.svg)](https://www.autohotkey.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20%2F%2010%20(64--bit)-blue.svg)]()
[![Tests](https://img.shields.io/badge/Test%20Suite-24%2F24%20Passing-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-orange.svg)]()

---

## 🚀 Overview

**OhlalaKey** is an open-source, background input method engine engineered in pure **AutoHotkey v2**. Designed as a drop-in replacement for standalone tools like OpenKey and UniKey, OhlalaKey combines full Vietnamese syllable orthography with extended typing grammar for **French** and **Spanish** multilingual writers.

Typing Vietnamese, French, and Spanish previously required constantly toggling between different Windows keyboard layouts (US, Vietnamese UniKey, French AZERTY, Spanish International). OhlalaKey unifies all three into one standard US QWERTY keyboard layout without shortcuts, mode switching, or key collisions.

---

## ✨ Features

- **Standard Vietnamese Composition**:
  - Full **Telex** and **VNI** input methods.
  - **Free-marking**: Place tones anywhere in a syllable (`toans` -> `toán`, `duongws` -> `đường`).
  - **Modern vs. Classic Tone Placement**: Configurable tone placement rules (`hóa`/`thúy` vs. `hoá`/`thuý`).
  - **One-touch Undo**: Tap a modifier key a second time to revert back to raw letters (`dd` -> `đ`, `ddd` -> `dd`, `aw` -> `ă`, `aww` -> `aw`).
  - **Smart English Auto-Restore**: Automatically restores unaltered raw English sequences when typing invalid Vietnamese clusters (e.g., `esp`, `str`, `clear`).

- **Polyglot Grammar (French & Spanish)**:
  - **Cedilla (`ç` / `Ç`)**: `cc` / `CC` (Telex) | `c9` / `C9` (VNI) with 3rd tap reversion.
  - **Eñe (`ñ` / `Ñ`)**: `nn` / `NN` (Telex) | `n9` / `N9` (VNI) with 3rd tap reversion (`espannol` -> `español`).
  - **French Ligatures (`œ` / `Œ`, `æ` / `Æ`)**: `oe` -> `œ`, `ae` -> `æ` (`coeur` -> `cœur`). Automatically suppresses Vietnamese tone conflicts on foreign words.
  - **Extended Circumflexes (`î`, `û`, `ŷ`)**: Double vowel tap (`ii` -> `î`, `uu` -> `û`, `yy` -> `ŷ`) and VNI `i6`, `u6`, `y6`.
  - **Tréma / Diaeresis (`ä`, `ë`, `ï`, `ö`, `ü`, `ÿ`)**: Vowel + `l` in Telex (`al` -> `ä`, `il` -> `ï`) and vowel + `0` in VNI. Features double-L rollback (`oll` -> `oll`, `oill` -> `oill`).
  - **French Transition Intelligence**: Typing `nalive` produces `naïve`; typing `Noel` produces `Noël`.
  - **Spanish Inverted Punctuation (`¡`, `¿`)**: Double tap `!!` -> `¡`, `??` -> `¿` with automatic 3rd tap reversion (`???` -> `???`, `!!!` -> `!!!`).
  - **Smart Auto-Pairing Guillemets (`« ... »`)**: Double quote `''` outputs opening `«` with non-breaking space (U+00A0), subsequent `''` closes ` »`. Triple quote `'''` reverts to raw single quotes.

- **UniKey/OpenKey Macro Expansion**:
  - Full support for flat-file macro tables formatted as `trigger=replacement` or `trigger<TAB>replacement`.
  - Clean word boundary expansion on Space or punctuation.

- **Modern Windows 11 Tray Interface**:
  - Context menu for on-the-fly toggling: Input Method (Telex/VNI), Tone Rules (Modern/Classic), English Auto-Restore, and Polyglot Grammar.
  - Seamless "Start with Windows" integration (`shell:startup`).
  - Settings persisted to `config.ini`.

---

## 📁 Directory Structure

```text
ohlala-key/
├── OhlalaKey.ahk                # Root entry point launcher
├── .gitignore                   # Git ignore specifications
├── README.md                    # Project documentation
├── OpenKeyPolyglot/
│   ├── OpenKey.ahk              # Core application entry point & tray UI
│   ├── config.ini               # Persisted configuration
│   ├── macros.txt               # Macro definition table
│   └── lib/
│       ├── InputHookManager.ahk # Global low-level interceptor (InputHook "V I2")
│       ├── WordBuffer.ahk       # Rolling token buffer & exact backspace math
│       ├── VietnameseEngine.ahk # Syllable parser, vowel matrices & tone placement
│       ├── PolyglotEngine.ahk   # French & Spanish rules, ligatures & punctuation
│       └── MacroManager.ahk     # Macro table parser & expansion dispatcher
└── tests/
    └── RunTests.ahk             # Comprehensive automated test suite (24/24 tests)
```

---

## ⌨️ Typing Grammar & Reference Guide

### 1. Vietnamese Rules

| Method | Acute (Sắc) | Grave (Huyền) | Hook (Hỏi) | Tilde (Ngã) | Dot (Nặng) | Remove Tone | Circumflex (â, ê, ô) | Horn (ơ, ư) / Breve (ă) | Bar (đ) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Telex** | `s` | `f` | `r` | `x` | `j` | `z` | `aa`, `ee`, `oo` | `aw` (ă), `ow` (ơ), `uw` / `w` (ư), `uow` / `w` (ươ) | `dd` |
| **VNI** | `1` | `2` | `3` | `4` | `5` | `0` | `a6`, `e6`, `o6` | `a8` (ă), `o7` (ơ), `u7` (ư), `uo7` (ươ) | `d9` |

### 2. French & Spanish Polyglot Rules

| Character | Telex Typing | VNI Typing | Undo / Reversion |
| :--- | :--- | :--- | :--- |
| **Cedilla (`ç`, `Ç`)** | `cc` / `CC` / `Cc` | `c9` / `C9` | 3rd `c` restores raw `cc` |
| **Eñe (`ñ`, `Ñ`)** | `nn` / `NN` / `Nn` | `n9` / `N9` | 3rd `n` restores raw `nn` |
| **OE Ligature (`œ`, `Œ`)** | `oe` / `OE` / `Oe` | `o8` / `O8` | 3rd `e` restores raw `oe` |
| **AE Ligature (`æ`, `Æ`)** | `ae` / `AE` / `Ae` | `a7` / `A7` | 3rd `e` restores raw `ae` |
| **Circumflex (`î`, `û`, `ŷ`)** | `ii`, `uu`, `yy` | `i6`, `u6`, `y6` | Double-tap vowel restores raw pair |
| **Tréma (`ä`, `ë`, `ï`, `ö`, `ü`, `ÿ`)** | `[vowel] + l` (`al` -> `ä`, `el` -> `ë`, `il` -> `ï`) | `[vowel] + 0` | `oll` -> `oll`, `oill` -> `oill` (Double-L reversion) |
| **Grave on U (`ù`, `Ù`)** | `uf` / `UF` | `u2` / `U2` | `ù + f` -> `uf` |
| **Inverted Exclamation (`¡`)** | `!!` | `!!` | 3rd `!` restores `!!!` |
| **Inverted Question (`¿`)** | `??` | `??` | 3rd `?` restores `???` |
| **Guillemets (`« ... »`)** | `''` (toggle open / close with `U+00A0`) | `''` | 3rd `'` restores `'''` |

---

## 🛠️ Installation & Usage

### Prerequisites
- **Windows 11 or Windows 10 (64-bit)**
- **[AutoHotkey v2.0+](https://www.autohotkey.com/)** installed.

### Running OhlalaKey
1. Clone the repository:
   ```bash
   git clone https://github.com/tinihoc/ohlala-key.git
   cd ohlala-key
   ```
2. Launch the application:
   - Double-click `OhlalaKey.ahk` (or `OpenKeyPolyglot\OpenKey.ahk`).
3. The **OpenKey Polyglot** icon will appear in your Windows System Tray.
4. Right-click the tray icon to customize typing options, toggle startup behavior, or edit the macro dictionary.

---

## 🧪 Automated Test Suite

OhlalaKey includes a headless verification suite that simulates keystroke streams and validates output text, token management, and backspace counts.

To run the test suite:
```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" tests\RunTests.ahk
```

### Verified Test Cases (24/24 PASS)
- **Vietnamese Telex**: `duongws` -> `đường`, `hoas` (modern) -> `hóa`, `hoas` (classic) -> `hoá`, `dd` -> `đ`, `ddd` -> `dd`, `toans` -> `toán`, `tieengs` -> `tiếng`.
- **Vietnamese VNI**: `du7o7ng2` -> `đường`, `d9` -> `đ`, `hoa1` (modern) -> `hóa`, `hoa1` (classic) -> `hoá`.
- **French**: `coeur` -> `cœur`, `cca` -> `ça`, `nailve` -> `naïve`, `nalive` -> `naïve`, `Noel` -> `Noël`, `''bonjour''` -> `« bonjour »`.
- **Spanish**: `espannol` -> `español`, `!!Hola!` -> `¡Hola!`, `???` -> `???`.
- **English Rollback**: `oll` -> `oll`, `oill` -> `oill`.
- **Macro Expansion**: `vn ` -> `Việt Nam `, `ok ` -> `OhlalaKey `.

---

## 📜 License

This project is open-source under the [MIT License](LICENSE).
