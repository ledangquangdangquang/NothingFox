# NothingFirefoxCss

A minimal `userChrome.css` / `userContent.css` theme for Firefox: auto-hiding toolbars, a **single-line** layout (URL bar and tabs on the same row), and black backgrounds for internal pages (New Tab, Settings, Add-ons).

> Based on code from [Bali10050/FirefoxCSS](https://github.com/Bali10050/FirefoxCSS).

## Screenshots

**Toolbars hidden**: only the page content is visible

![Toolbars hidden](screenshots/hidden.png)

**Toolbars visible** (hover the top edge of the window, or pin them with `Ctrl+Shift+B`): URL bar on the left, tabs on the right, all in one row

![Single-line toolbar](screenshots/toolbar.png)

**about:addons**: compact layout, black background

![Add-ons](screenshots/addons.png)

**about:preferences**: black background

![Settings](screenshots/preferences.png)

## Features

- Tab bar, nav bar and bookmarks bar are hidden when not in use. **Hover the top edge of the window** to reveal them.
- **`Ctrl+Shift+B`** pins the tabs and URL bar so they stay visible (the bookmarks bar stays hidden). Press it again to return to auto-hide.
- Single-line layout when the window is at least 950px wide; narrower windows fall back to two rows.
- Hides rarely used buttons: ☰ menu, forward, reload, star, reader mode, PiP, translate, all-tabs.
- Tab close buttons only appear on hover.
- Black background for New Tab, Home, Private Browsing, `about:preferences` and `about:addons`.

## Installation

### Windows

1. Download the repo (Code → Download ZIP) and extract it.
2. Double-click **`install.bat`**.
3. Pick a profile (Enter = default profile, `A` = all profiles).
4. If Firefox is running, the script asks whether to close it. Answer `Y` and Firefox is closed, then reopened after the install.

You can also run it from `cmd` with arguments:

```bat
install.bat                          :: pick a profile
install.bat --all                    :: install into every profile
install.bat "C:\path\to\profile"     :: install into a specific profile
install.bat --uninstall              :: remove the theme
install.bat --uninstall --all
```

### Linux (and macOS)

```bash
git clone <repo-url> NothingFirefoxCss
cd NothingFirefoxCss
chmod +x install.sh
./install.sh            # pick a profile
./install.sh --all      # install into every profile
./install.sh ~/.mozilla/firefox/xxxx.default-release
./install.sh --uninstall
```

The script looks for profiles in these locations:

| Firefox install type | Directory |
|---|---|
| deb / rpm / tarball | `~/.mozilla/firefox` |
| XDG (newer Firefox) | `~/.config/mozilla/firefox` |
| Snap | `~/snap/firefox/common/.mozilla/firefox` |
| Flatpak | `~/.var/app/org.mozilla.firefox/.mozilla/firefox` |
| macOS | `~/Library/Application Support/Firefox` |

### What the scripts do

1. If the profile already has `chrome/userChrome.css`, the whole `chrome` folder is backed up to `chrome.backup-<date-time>`.
2. `userChrome.css` and `userContent.css` are copied into `<profile>/chrome/`.
3. These prefs are written to `<profile>/user.js` (any existing line for the same pref is replaced, so nothing is duplicated):
   ```js
   user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // enable userChrome.css
   user_pref("browser.toolbars.bookmarks.visibility", "always");          // bookmarks bar shows on hover
   ```

### Manual installation

1. Open `about:support` → **Profile Folder** → **Open Folder**.
2. Create a `chrome` folder there and copy `userChrome.css` and `userContent.css` into it.
3. Open `about:config` and set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`.
4. Restart Firefox.

## Uninstall

Run `install.bat --uninstall` (Windows) or `./install.sh --uninstall` (Linux). This deletes the two CSS files from `chrome/`. To restore your previous theme, copy the contents of a `chrome.backup-*` folder back into `chrome`.

## Customization

Edit `userChrome.css` (either the copy in this repo, then rerun the script, or the one in `<profile>/chrome/`) and restart Firefox:

| Variable / selector | Purpose | Default |
|---|---|---|
| `--NavbarWidth` | URL bar width (% of window width) | `36` |
| `--TabsHeight` | Tab height | `25` |
| `--tab-border-radius` | Tab corner radius | `15px` |
| `#navigator-toolbox { background }` | Toolbar background color | `#181825` |

To bring back a hidden button (e.g. reload), remove or comment out its selector (`#reload-button`) in the `display: none` block.

## Troubleshooting

- **Theme has no effect**: in `about:config`, `toolkit.legacyUserProfileCustomizations.stylesheets` must be `true`. Also make sure you installed into the profile you actually use (see `about:profiles`).
- **Installed into the wrong profile**: rerun the script and choose the one marked `(default)`, or use `--all`.
- **Toolbars don't appear on hover**: move the mouse to the very top edge of the window, or press `Ctrl+Shift+B` to pin them.
- **Snap/Flatpak Firefox**: the profile lives inside the sandbox, which the script already supports. If it isn't found, pass the profile path directly.
