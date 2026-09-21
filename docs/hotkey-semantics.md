# Hex HotKey Semantics

## Overview

Hex uses a **threshold-based recording system** that behaves differently depending on whether your hotkey is **modifier-only** (e.g., Option) or **a regular hotkey** (e.g., Cmd+A).

The key insight: **Modifier-only hotkeys need protection from accidental triggers** (like quick Option taps for special characters), while regular hotkeys are inherently intentional.

---

## Quick Reference

### Modifier-Only Hotkeys (e.g., Option, Option+Command)

**Timeline: Press Option → START recording**

**Before minimumKeyTime (< S):**
- Release → DISCARD (silent)
- Click → DISCARD (silent)
- Press A → DISCARD (silent)
- Add Shift → DISCARD (silent)
- All actions trigger silent discard

**After minimumKeyTime (≥ S):**
- Release → STOP (transcribe)
- Click → NOP (ignore, keep recording)
- Press A → NOP (ignore, keep recording)
- Add Shift → NOP (ignore, keep recording)
- ESC → CANCEL (only way to stop)

**Key points:**
- **< minimumKeyTime**: Everything except ESC triggers **silent discard** (no sound)
- **≥ minimumKeyTime**: Only **ESC cancels** (with sound), everything else is **ignored**
- Recording continues until you release the modifier or press ESC

---

### Regular Hotkeys (e.g., Cmd+A, Option+K)

**Timeline: Press Cmd+A → START recording**

**Before 0.2s (< minimumKeyTime):**
- Release → DISCARD (silent)
- Click → DISCARD (silent)

**Between 0.2s - 1.0s:**
- Press different key (e.g., Cmd+B) → STOP (with sound)
- Add modifier (e.g., Shift) → STOP (with sound)

**After 1.0s (> 1.0s):**
- Press different key → NOP (ignore, keep recording)
- Add modifier → NOP (ignore, keep recording)
- Allows typing while recording

**Any time:**
- Release → STOP (transcribe if long enough)
- ESC → CANCEL

**Key points:**
- **< minimumKeyTime** (default 0.2s): **Silent discard**
- **0.2s - 1.0s**: Different key/modifier triggers **stop** (with sound)
- **> 1.0s**: Everything is **ignored** (allows typing while recording)
- Release or ESC always stops

---

## Constants & Thresholds

```swift
// For all hotkeys (user-configurable, governs modifier-only too)
minimumKeyTime = 0.2s (default)

// Other thresholds
doubleTapThreshold = 0.3s           // Max time between taps
pressAndHoldCancelThreshold = 1.0s  // For regular hotkeys only
```

### Effective Thresholds

The **actual threshold** used depends on the hotkey type:

```swift
// All hotkeys (modifier-only and regular alike)
effectiveThreshold = minimumKeyTime
// User sets 0.0s → instant (0.0s)
// User sets 0.1s → uses 0.1s
// User sets 0.5s → uses 0.5s
```

---

## Recording Decision Matrix

When you **release** the hotkey, should we transcribe the recording?

**Modifier-only (Option):**
- Duration < minimumKeyTime → Discard (silent)
- Duration ≥ minimumKeyTime → Transcribe

**Regular (Cmd+A):**
- Duration < 0.2s (or < minimumKeyTime) → Discard (silent)
- Duration ≥ 0.2s (or ≥ minimumKeyTime) → Transcribe

*Note: the minimumKeyTime slider governs every hotkey kind — 0.0 is instant, 0.7 holds until 0.7s.*

---

## Detailed Behaviors

### 1. Modifier-Only: Option

#### Scenario A: Quick tap (< minimumKeyTime)
```
User: Hold Option (0.1s) → Release
      ↓
  START ────→ DISCARD (silent)
  
Result: No transcription, no sound
Why: Likely accidental (Option+Click, Option+A for special chars)
```

#### Scenario B: Hold and click (< minimumKeyTime)
```
User: Hold Option (0.25s) → Click mouse
      ↓
  START ────→ DISCARD (silent)
  
Result: No transcription, no sound, click passes through
Why: Option+Click is for duplicating items in macOS
```

#### Scenario C: Hold and press A (< minimumKeyTime)
```
User: Hold Option (0.2s) → Press A
      ↓
  START ────→ DISCARD (silent)
  
Result: No transcription, Option+A passes through to macOS
Why: Option+A might be for special character "å"
```

#### Scenario D: Hold longer (≥ minimumKeyTime)
```
User: Hold Option (0.5s) → Release
      ↓
  START ───────────→ TRANSCRIBE
  
Result: Audio transcribed and pasted
```

#### Scenario E: Hold, then click (≥ minimumKeyTime)
```
User: Hold Option (0.5s) → Click mouse
      ↓
  START ───────────→ (ignored, keeps recording)
  
Result: Recording continues, click passes through
Why: After minimumKeyTime, we assume intentional recording
```

#### Scenario F: Hold, then add Shift (≥ minimumKeyTime)
```
User: Hold Option (0.5s) → Add Shift
      ↓
  START ───────────→ (ignored, keeps recording)
  
Result: Recording continues, Option+Shift passes through
Why: User might be pressing Shift for capital letters while speaking
```

#### Scenario G: ESC cancels anytime
```
User: Hold Option (any duration) → Press ESC
      ↓
  START ───────────→ CANCEL (with sound)
  
Result: Recording cancelled, cancel sound plays
Why: ESC is explicit "I want to cancel" gesture
```

---

### 2. Regular Hotkey: Cmd+A

#### Scenario A: Quick tap (< 0.2s)
```
User: Hold Cmd+A (0.1s) → Release
      ↓
  START ────→ DISCARD (silent)
```

#### Scenario B: Press different key within 1s
```
User: Hold Cmd+A (0.5s) → Press Cmd+B
      ↓
  START ───────────→ STOP (with sound)
  
Result: Recording stopped, audio discarded
Why: User is likely using other Cmd shortcuts
```

#### Scenario C: Press different key after 1s
```
User: Hold Cmd+A (1.5s) → Press Cmd+B
      ↓
  START ───────────────────→ (ignored, keeps recording)
  
Result: Recording continues, Cmd+B passes through
Why: After 1s, assume user is transcribing while typing
```

#### Scenario D: Add modifier (< 1s)
```
User: Hold Cmd+A (0.5s) → Add Shift (Cmd+Shift+A)
      ↓
  START ───────────→ STOP (with sound)
  
Result: Recording stopped
Why: Cmd+Shift+A is likely a different command
```

---

### 3. Multi-Modifier: Option+Command

**Behaves like single modifier** (uses minimumKeyTime):

```
User: Hold Option+Command (0.25s) → Add Shift
      ↓
  START ────→ DISCARD (silent)

User: Hold Option+Command (0.5s) → Add Shift
      ↓
  START ───────────→ (ignored, keeps recording)
```

**Partial release = full release:**
```
User: Hold Option+Command → Release Command (keep Option)
      ↓
  START ───────────→ STOP
  
Result: Recording stopped and transcribed (if ≥ minimumKeyTime)
Why: Releasing any part of the hotkey = release
```

---

## Double-Tap Lock

**Quick double-tap locks recording on** (hands-free mode)

### Timeline

```
0.0s: Tap hotkey ──────────→ START
0.1s: Release ─────────────→ STOP
0.2s: Tap again ───────────→ START
0.3s: Release ─────────────→ LOCK! (Δt = 0.2s < 0.3s)

Now recording is locked on:
- Release doesn't stop it
- Tap hotkey again to stop
- ESC also stops

5.0s: Tap hotkey ──────────→ STOP
```

### Sequence

1. **Tap 1** (t=0.0s) → START recording
2. **Release** (t=0.1s) → STOP (normal behavior)
3. **Tap 2** (t=0.2s, within 0.3s window) → START recording again
4. **Release** (t=0.3s, Δt=0.2s < 0.3s) → **LOCK!** (hands-free mode)
5. Recording continues until:
   - Tap hotkey again → STOP
   - Press ESC → STOP

### Rules

1. **Timing window**: 2nd tap must be within **0.3s** of 1st release
2. **Lock engages**: On **2nd release**, not 2nd press
3. **Exit lock**: Tap hotkey again OR press ESC
4. **Too slow**: If 2nd tap > 0.3s after 1st release, treated as new recording

---

## Output Types

- **`.discard`** (silent)
  - Stop recording
  - Discard audio
  - Pass keys through to macOS

- **`.stop`** (with stop sound)
  - Stop recording
  - Transcribe if duration ≥ threshold

- **`.cancel`** (with cancel sound)
  - Stop recording
  - Discard audio
  - Play cancel sound

---

## Key Interception

**When does Hex intercept (block) key events from reaching other apps?**

**Key Interception Rules:**

- **Press modifier-only hotkey (Option)** → No (passes through)
- **Press regular hotkey (Cmd+A)** → Yes (blocked)
- **`.discard` output** → No (passes through) ← CRITICAL!
- **`.cancel` output** → Yes (blocked)
- **Mouse clicks** → Never intercepted (always pass through)

**Example:**
```
User: Press Option (0.1s) → Press A
      ↓
  START → DISCARD (passes through)
  
Result: Hex discards recording silently
        macOS sees Option+A
        Special character dialog appears ✅
```

---

## Dirty State

**Prevents re-triggering until full release**

### What triggers dirty?

**Modifier-only (Option):**
- Add extra modifier within minimumKeyTime → dirty
- Press any key within minimumKeyTime → dirty
- Click mouse within minimumKeyTime → dirty

**Regular (Cmd+A):**
- Press different key within 1s → dirty
- Change modifiers within 1s → dirty

### Dirty behavior

```
User: Hold Option (0.1s) → Add Shift → Release Shift → Press Option again
      ↓
  START → DISCARD (dirty=true) → (ignored) → (ignored)
  
  User must release EVERYTHING (∅) to clear dirty
  
  → Release all keys → Now Option works again
```

### State Flow

**CLEAN** → [trigger dirty condition] → **DIRTY** → [full release (all keys)] → **CLEAN**

- **CLEAN**: Accepts hotkey input
- **DIRTY**: Ignores all input until full release (all keys released)

---

## Decision Tree

**Processing order:**

1. **Is ESC pressed?**
   - YES → CANCEL (exit)

2. **Are we dirty?**
   - YES → Ignore input (unless full release)

3. **Does chord match hotkey exactly?**
   - NO → Check if recording active
     - Recording active → Handle based on elapsed time
     - Not recording → Ignore input
   - YES → Continue to step 4

4. **Is recording active?**
   - NO → START recording
   - YES → Check hotkey type and elapsed time

5. **If recording active:**
   - **Modifier-only?**
     - YES → Check elapsed < minimumKeyTime
       - YES → DISCARD
       - NO → (ignore)
   - **Regular hotkey?**
     - Check elapsed < 1s
       - YES → Check elapsed < minimumKeyTime
         - YES → DISCARD
         - NO → STOP
       - NO → (ignore)

6. **Final action:**
   - START or STOP (depending on current state)

---

## State Machine

**States:**

- **IDLE**
  - Transition: chord matches hotkey → PRESS & HOLD

- **PRESS & HOLD** (recording)
  - On release (normal):
    - Check elapsed time
    - If < minimumKeyTime → DISCARD
    - If ≥ threshold → Check last tap timing
      - If Δt < 0.3s → LOCK
      - Otherwise → STOP → IDLE
  - On other input:
    - Check elapsed time
    - If < minimumKeyTime → DISCARD → IDLE
    - If ≥ minimumKeyTime → (ignore, keep recording)

- **LOCK** (hands-free recording)
  - Transition: Tap hotkey again OR press ESC → STOP → IDLE

---

## Examples with Full Explanations

### Example 1: Quick Option tap for special character

```
Goal: Type "å" (Option+A)

Timeline:
  t=0.0s  Press Option          → START recording
  t=0.15s Press A               → DISCARD (< minimumKeyTime)
                                  Option+A passes to macOS
  
macOS sees: Option+A
Result: Special character dialog appears ✅
Hex: Silent discard, no transcription
```

**Why this works:**
- Recording starts immediately (responsive)
- But discarded if < minimumKeyTime (safety)
- Keys pass through (Option+A reaches macOS)

---

### Example 2: Intentional voice recording with Option

```
Goal: Record a voice note

Timeline:
  t=0.0s  Press Option          → START recording
  t=0.5s  Still holding...      (recording audio)
  t=2.0s  Release Option        → STOP, TRANSCRIBE
  
Result: Audio transcribed and pasted ✅
```

---

### Example 3: Option-click to duplicate

```
Goal: Duplicate file in Finder

Timeline:
  t=0.0s  Press Option          → START recording
  t=0.2s  Click file            → DISCARD (< minimumKeyTime)
                                  Click passes through
  
Finder sees: Option+Click
Result: File duplicated ✅
Hex: Silent discard
```

---

### Example 4: Recording while typing

```
Goal: Dictate code comments while typing

Timeline:
  t=0.0s  Press Option          → START recording
  t=0.5s  Still talking...      (recording)
  t=2.0s  Press Cmd+Tab         → IGNORED (> minimumKeyTime)
                                  Cmd+Tab passes through
  t=3.0s  Type some code        → IGNORED
  t=5.0s  Release Option        → STOP, TRANSCRIBE
  
Result: Audio transcribed ✅
        Cmd+Tab worked ✅
        Typing worked ✅
```

**Why:** After minimumKeyTime, Hex assumes you're intentionally recording and ignores other input (except ESC).

---

### Example 5: Accidental recording cancellation

```
Goal: Cancel accidental recording

Timeline:
  t=0.0s  Press Option          → START recording
  t=1.0s  "Oh no, accident!"
  t=1.5s  Press ESC             → CANCEL (with sound)
  
Result: Recording cancelled ✅
        Cancel sound plays
```

---

## Summary Table

**Modifier-only (Option):**

- **Time < minimumKeyTime:**
  - Release → Discard
  - Click → Discard
  - Press key → Discard
  - Add modifier → Discard

- **Time ≥ minimumKeyTime:**
  - Release → Transcribe
  - Click → Ignore (keep recording)
  - Press key → Ignore (keep recording)
  - Add modifier → Ignore (keep recording)
  - ESC → Cancel

**Regular (Cmd+A):**

- **Time < minimumKeyTime:**
  - Release → Discard

- **Time: minimumKeyTime - 1s:**
  - Other key → Stop
  - Add modifier → Stop

- **Time > 1s:**
  - Other key → Ignore (keep recording)
  - Add modifier → Ignore (keep recording)

- **Any time:**
  - Release → Transcribe (if long enough)
  - ESC → Cancel

---

## Implementation Files

- **Core Logic**: `HexCore/Sources/HexCore/Logic/HotKeyProcessor.swift`
- **Recording Decision**: `HexCore/Sources/HexCore/Logic/RecordingDecision.swift`
- **Feature Integration**: `Hex/Features/Transcription/TranscriptionFeature.swift`
- **Tests**: `HexCore/Tests/HexCoreTests/HotKeyProcessorTests.swift`

---

**Document Version:** 2.0  
**Last Updated:** 2025-11-14  
**Total Tests:** 46 passing ✅
