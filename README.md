# tpopup

A tiny macOS popup that sends your selected text through OpenAI, triggered by a keyboard shortcut.

## Modes

- **`-translate`** — Shows source + translation side-by-side in a minimalist popup at screen center, with speaker and copy controls. Esc or click-outside dismisses.
- **`-grammar`** — Sends the clipboard to OpenAI, writes the corrected text to stdout. The Quick Action splices the result back into the editor via macOS Services — no extra UI, no Accessibility permission.

Each mode has its own tab in Settings (OpenAI key, model, prompt). Defaults: Russian ↔ American English for translate; American-English copy editor for grammar.

## Install

```sh
./deploy.sh
```

Drops `tpopup.app` into `/Applications`. Launch it once, fill in your OpenAI key + model name (e.g. `gpt-4o`) on both tabs, click OK.

Wire each mode to a keyboard shortcut by following the matching guide — instructions stay there so this file doesn't go stale:

- [docs/quick-action-translation.md](docs/quick-action-translation.md) — `Option+Cmd+T`
- [docs/quick-action-grammar.md](docs/quick-action-grammar.md) — `Option+Cmd+G`

## Better voices for read-aloud

The translation popup's speaker buttons use macOS's built-in TTS. The default system voices sound robotic; once you install something better, tpopup auto-picks the highest-quality voice installed for each language — no app config needed.

**System Settings → Accessibility → Read & Speak → tap ⓘ next to *System Voice* → pick a language → download any voice tagged *Premium* or *Enhanced*.**

Siri does **not** need to be enabled.

## Packaging

```sh
./pack.sh    # → dist/tpopup-<version>.dmg
```

Version is read from `CFBundleShortVersionString` in `BundleResources/Info.plist` — bump it there and the DMG name follows.
