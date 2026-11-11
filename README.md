# Lomiri Nav

Floating navigation for Ubuntu Touch, in thumb reach. On a tall phone, the back arrow in the top-left corner is the longest stretch your thumb can make. Lomiri Nav adds one of two styles, chosen in **System Settings → Gestures → Navigation**:

- **Back button**: a small round button that floats over apps.
- **Back, Home and Apps**: a floating bar. Home opens the app drawer, and Apps opens the app switcher.

Drag it where you like: the round button snaps to the left or right, and the bar also to the middle; both remember their height. They move up when the keyboard opens. Press and hold to switch style or hide it. Navigation is hidden on the lock screen, in the app drawer and switcher, and in fullscreen apps.

It's unofficial and needs root (`sudo`). It never writes to the read-only system: everything is mounted from `/run`, so a reboot (if not installed) or `off` gives you the stock shell back.

## Install

You need Ubuntu Touch 24.04 on an arm64 phone, with Developer Mode on and a password set (for `sudo`).

1. Download the latest release (`lomiri-nav-<version>.tar.gz`) on the phone. Then, in the Terminal app:
   ```sh
   cd ~/Downloads
   tar xf lomiri-nav-*.tar.gz
   cd lomiri-nav
   ```
2. Try it until the next reboot:
   ```sh
   sudo ./lomiri-nav.sh on
   ```
   The shell restarts, which closes open apps.
3. If you like it, keep it across reboots:
   ```sh
   sudo ./lomiri-nav.sh install
   ```

To remove it: `sudo /root/lomiri-nav/lomiri-nav.sh uninstall` if installed, or `sudo ./lomiri-nav.sh off` if only tried. To change the style from a terminal: `./lomiri-nav.sh mode off|button|bar`.

## How Back works

Back has to reach the app you're in. The shell can't reach into apps, so it presses a key, like a keyboard would:

- The LomiriNav QML plugin (`plugin/navkeys.cpp`) creates a virtual key device with `/dev/uinput`. On Ubuntu Touch, udev lets the logged-in user do this (`uaccess`), and AppArmor keeps confined apps out.
- The device has only five keys, so udev doesn't tag it as a keyboard, and Lomiri keeps showing the on-screen keyboard.
- Back is **Alt+Left**, Qt's standard Back shortcut (`StandardKey.Back`). Apps is **Super+W**, Lomiri's own shortcut for the app switcher. Home calls the shell directly.
- Most Ubuntu Touch apps use the Lomiri UI toolkit, whose page header didn't listen for Back. Lomiri Nav patches `PageHeader.qml` so that Back presses the visible page's own back or close arrow. That covers the toolkit's arrow and the ones apps add themselves. It never presses a menu (☰) icon.
- The Browser understands Alt+Left by itself.

Back does nothing where a page has no back arrow, and in apps not built with the Lomiri toolkit that don't handle Alt+Left. Please report those.

## What changes, and how

At each start, `lomiri-nav.sh` makes copies of three files from your phone, edits them and mounts the copies over the originals:

| File | Change | Made by |
|---|---|---|
| Lomiri's `Shell.qml` | A `Loader` for `files/Components/NavOverlay.qml` | `make-shell.py` |
| The UI toolkit's `PageHeader.qml` | Back presses the header's back or close action | `make-uitk.py` |
| System Settings' Gestures page | The Navigation choice | `make-settings.py` |

Safety:
- If a file doesn't look as expected (after a system update, for example), that part is left out, and the shell part stops the whole thing.
- The toolkit change is loaded in a test page before it's kept.
- After `on`, the new shell's log is checked, and the stock shell comes back by itself if it shows an error.
- The overlay sits behind a `Loader`, so even a broken overlay can't break the shell.

The plugin goes on a small root-owned tmpfs at `/run/lomiri-nav-lib`, and a drop-in in `/run/systemd/user` gives only the shell its import path. Running as root, the script never writes in your home folder: the settings file is written as your user.

The settings (style, side, height) are in `~/.config/lomiri-nav/settings.conf`. The plugin watches that file, so changes show at once.

`install` copies the files to `/root/lomiri-nav` and adds `lomiri-nav.service`, which mounts everything at boot before the shell starts.

## Building the plugin

The release includes a prebuilt `LomiriNav/libLomiriNav.so` (arm64, Qt 5.15). To build it yourself, with Docker and the clickable image:

```sh
cd plugin && sh build.sh
```

## Tests

- `test/check-patches.sh` (on a PC): `make-*.py` must turn the stock files from 24.04-2.x in `test/stock/` into exactly `test/expected/`, and must refuse to patch twice.
- On the phone, as root, while it's on and the phone is unlocked:
  - `test/plugin-test.sh` checks that a focused app receives Back from the plugin, and that udev doesn't tag the device as a keyboard.
  - `test/header-test.sh` checks a page with the toolkit's back, an app-made back, and a menu icon that Back must leave alone.

Tested on a Pixel 3a XL with Ubuntu Touch 24.04-2.x (daily, Lomiri 0.5.0).

## License

GPL-3.0. `Shell.qml` and the System Settings page are GPL-3.0, and the UI toolkit's `PageHeader.qml` is LGPL-3.0; the patches change copies of them on your phone.

*Built with help from an AI coding assistant, and tested on my own phone.*
