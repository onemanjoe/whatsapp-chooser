# Design: Homebrew formula for the WhatsApp Chooser native host

Date: 2026-06-23

## Problem

The Chrome Web Store distributes only the extension. The native messaging host
(the compiled C helper that runs `open -a "App"` to launch a specific WhatsApp
app) must be installed per-machine. Today that requires cloning the repo, having
Xcode Command Line Tools, and running `install.sh` in Terminal — a developer
workflow, not a consumer one. Without the host, the extension fails with
"Specified native messaging host not found" the moment a user clicks an account.

## Goal

A `brew install` path that needs no manual compiling and no Gatekeeper prompt.

## Why a formula, not a cask

A cask ships a pre-built binary; Homebrew quarantines downloaded binaries, and an
unsigned host launched by Chrome would be blocked by Gatekeeper — reintroducing
the very signing problem we want to avoid. A formula compiles `host.c` from
source on the user's machine, so the binary is never quarantined. No Apple
Developer account required.

## Components

1. **`host.c` change (backward-compatible).** Config lookup order:
   `~/.config/whatsapp-chooser/config.json` first, then fall back to a
   `config.json` next to the binary (legacy manual installs). Required because
   Homebrew wipes the Cellar on upgrade, so config must live outside it.

2. **`native-host/whatsapp-chooser-host`** — a bash CLI installed into Homebrew's
   `bin`, with subcommands:
   - `configure [--whatsapp NAME --business NAME]` → writes user config.
   - `register [EXTENSION_ID]` → writes the Chrome native-messaging manifest,
     `path` pointing at `$(brew --prefix whatsapp-chooser-host)/libexec/host`
     (stable across upgrades), `allowed_origins` = store ID (+ optional dev ID).
   - `unregister` → removes the manifest.
   - `status` → shows binary path, config, registration state.

3. **`Formula/whatsapp-chooser-host.rb`** — compiles `host.c` into `libexec`,
   installs the CLI into `bin`, prints `caveats` with the configure → register →
   restart-Chrome steps. Builds from the tagged release tarball.

4. **`native-host/HOMEBREW.md`** — end-user install steps and the maintainer
   publish procedure (tag, SHA256, tap).

## Scope boundaries (YAGNI)

- Chrome only. No Brave/Edge/Chromium auto-detection.
- No code-signing, no `.pkg`.
- The existing `install.sh` is unchanged and remains the non-Homebrew path.

## Validation

- `host.c` compiles cleanly with `cc -O2`.
- `whatsapp-chooser-host` passes `bash -n` (and shellcheck if available).
- `Formula/whatsapp-chooser-host.rb` passes `ruby -c` and `brew style`.
- Publishing (tag/release/SHA/tap push) is left to the maintainer; the formula
  carries a placeholder SHA256 until a release tarball exists.
