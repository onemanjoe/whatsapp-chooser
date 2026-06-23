# Distributing the native host via Homebrew

The Chrome Web Store ships only the extension. The native messaging host (the
small compiled helper that actually launches WhatsApp / WhatsApp Business) has
to be installed on each user's Mac. Homebrew is the install path that needs no
manual compiling and no Terminal gymnastics.

This repo ships a formula at [`Formula/whatsapp-chooser-host.rb`](../Formula/whatsapp-chooser-host.rb).
It compiles [`native-host/host.c`](host.c) **from source on the user's machine**,
so there is no code-signing or Gatekeeper problem, and installs a
`whatsapp-chooser-host` command that manages Chrome registration and app-name
config.

## End-user install

```bash
brew tap onemanjoe/whatsapp-chooser https://github.com/onemanjoe/whatsapp-chooser
brew install whatsapp-chooser-host
whatsapp-chooser-host configure   # set your app names (one-time)
whatsapp-chooser-host register    # wire it into Chrome
# then quit Chrome (Cmd+Q) and reopen
```

Plus install the **WhatsApp Chooser** extension from the Chrome Web Store.

Managing an existing install:

```bash
whatsapp-chooser-host status       # show config + registration
whatsapp-chooser-host unregister   # remove from Chrome
```

## Publishing a new version (maintainer)

The formula builds from a tagged release tarball, so each release needs a tag
and the tarball's SHA256.

1. Commit your changes (including any `host.c` edits).
2. Tag and push a release (bump the version as needed):

   ```bash
   git tag v1.2
   git push origin v1.2
   ```

3. Get the SHA256 of the release tarball:

   ```bash
   curl -sL https://github.com/onemanjoe/whatsapp-chooser/archive/refs/tags/v1.2.tar.gz | shasum -a 256
   ```

4. In `Formula/whatsapp-chooser-host.rb`, set the `url` to the matching tag and
   replace `REPLACE_WITH_TARBALL_SHA256` with that SHA256. Commit and push.

Because the formula lives in this same repo, users tap it directly with the URL
form shown above; no separate `homebrew-tap` repo is required. If you later want
the shorter `brew install onemanjoe/tap/whatsapp-chooser-host`, create a repo
named `homebrew-tap` and copy `Formula/whatsapp-chooser-host.rb` into its
`Formula/` directory.

## How it fits together

- `host.c` reads app names from `~/.config/whatsapp-chooser/config.json` first
  (written by `configure`), falling back to a `config.json` next to the binary
  for legacy manual installs. The user config lives outside the Homebrew Cellar
  so it survives `brew upgrade`.
- `register` writes the Chrome native-messaging manifest pointing `path` at
  `$(brew --prefix whatsapp-chooser-host)/libexec/host`, a stable location that
  also survives upgrades.

The manual path (`./install.sh`) still works for anyone not using Homebrew.
