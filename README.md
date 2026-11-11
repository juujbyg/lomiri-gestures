# Lomiri Gestures & Shortcuts

Navigation in thumb reach, gestures and screenshots for Ubuntu Touch. Everything is chosen in **System Settings → Gestures**:

| Choice | What it does |
|---|---|
| **Navigation: Back button** | A small round Back button that floats over apps. |
| **Navigation: Back, Home and Apps** | A floating bar. Home opens the app drawer, Apps opens the app switcher. |
| **Screenshot button on the bar** | Adds a fourth button to the bar. |
| **Swipe with three fingers** | Left or right switches between open apps, up opens the app switcher, down closes it. |
| **Three fingers down for a screenshot** | Swipe down with three fingers in an app to take a screenshot. |
| **Lock screen: camera and flashlight** | Press and hold the bottom-left corner of the lock screen for the camera, or the bottom-right for the flashlight. |
| **Double tap to wake** | Double-tap the screen to wake the phone. Only shown on phones whose touch panel supports it (Pixel 3a and 3a XL). |

- Drag the button or bar where you like. The round button snaps to the left or right, and the bar also to the middle; both remember their height and move up when the keyboard opens.
- Press and hold the button or bar to take a screenshot, switch style or hide it.
- Navigation is hidden on the lock screen, in the app drawer and switcher, and in fullscreen apps. Screenshots never include the button or bar.
- One and two fingers always go to the app, so scrolling and pinch-to-zoom are unaffected. While three fingers are down, a label names the action; slide back before lifting to cancel.
- Screenshots go to `~/Pictures/Screenshots`, like Vol+ and Vol−, and open in the screenshot editor if it's on.

It's unofficial and needs root (`sudo`). It never writes to the read-only system: everything is mounted from `/run`, so a reboot (if not made permanent) or `off` gives you the stock shell back.

## Try it

You need Ubuntu Touch 24.04 on an arm64 phone, with Developer Mode on and a password set (for `sudo`).

1. Download the latest release (`lomiri-gestures-<version>.tar.gz`) on the phone. Then, in the Terminal app:
   ```sh
   cd ~/Downloads
   tar xf lomiri-gestures-*.tar.gz
   cd lomiri-gestures
   ```
2. Turn it on until the next reboot:
   ```sh
   sudo ./lomiri-gestures.sh on
   ```
   The shell restarts, which closes open apps. Unlock the phone when it comes back, and pick what you want in System Settings → Gestures.

To stop trying it: `sudo ./lomiri-gestures.sh off`, or just reboot.

## Make it permanent

When you're happy with it, keep it across reboots:

```sh
sudo ./lomiri-gestures.sh install
```

- It copies everything to `/root/lomiri-gestures` and adds `lomiri-gestures.service`, which sets everything up at each boot, before the shell starts. Your downloaded copy can be deleted afterwards.
- If it is already on, nothing restarts. Otherwise the shell restarts once.
- Your choices in System Settings are kept, in `~/.config/lomiri-gesture-pack/settings.conf`.
- Check it with `sudo /root/lomiri-gestures/lomiri-gestures.sh status`. It should say `on` and `installed (starts at boot)`.

**After a system update**, it makes its changes again from the updated files at the next boot. If a file has changed in a way it doesn't know, it leaves that part out rather than risk the shell: if the shell part is left out, you simply get the stock shell, and `status` says `off`. Check for a newer release then.

**To remove it** completely, including your choices:

```sh
sudo /root/lomiri-gestures/lomiri-gestures.sh uninstall
sudo rm -r /root/lomiri-gestures
```

The shell restarts once and is stock again.

From a terminal you can also set the navigation style: `./lomiri-gestures.sh mode off|button|bar`.

## How Back works

Back has to reach the app you're in. The shell can't reach into apps, so it presses a key, like a keyboard would:

- The GesturePack QML plugin (`plugin/gesturepack.cpp`) creates a virtual key device with `/dev/uinput`. On Ubuntu Touch, udev lets the logged-in user do this (`uaccess`), and AppArmor keeps confined apps out.
- The device has only five keys, so udev doesn't tag it as a keyboard, and Lomiri keeps showing the on-screen keyboard.
- Back is **Alt+Left**, Qt's standard Back shortcut (`StandardKey.Back`). Apps is **Super+W**, Lomiri's own shortcut for the app switcher. Home and Screenshot are done by the shell itself.
- Most Ubuntu Touch apps use the Lomiri UI toolkit, whose page header didn't listen for Back. Lomiri Gestures patches `PageHeader.qml` so that Back presses the visible page's own back or close arrow. That covers the toolkit's arrow and the ones apps add themselves. It never presses a menu (☰) icon.
- The Browser understands Alt+Left by itself.

Back does nothing where a page has no back arrow, and in apps not built with the Lomiri toolkit that don't handle Alt+Left. Please report those.

## Camera and flashlight on the lock screen

Two round buttons sit in the bottom corners of the lock screen and slide away with it. They need a press and hold, so they don't go off in a pocket; a tap only shows a reminder.

- **Flashlight** (right): the same switch as in the battery menu, so it works while locked. The button lights up while the flashlight is on.
- **Camera** (left): asks for your passcode or fingerprint, then opens the Camera app. It doesn't open over the lock screen, because the Camera app's gallery would show all your photos to whoever is holding the phone.

## Double tap to wake

Some phones' touch panels (Synaptics DSX, as on the Pixel 3a and 3a XL) have a `wake_gesture` switch, but Ubuntu Touch doesn't offer it, and switching it on by hand sometimes leaves the touchscreen dead after waking. `addons/dt2w` runs as a small root service while Lomiri Gestures is on. It follows your setting, and after every screen-on it puts the panel back in normal mode the way the driver itself does, so touch always comes back. It only changes the panel while the screen is on. On phones without the switch, the choice doesn't appear and nothing runs.

## What changes, and how

At each start, `lomiri-gestures.sh` makes copies of these files from your phone, edits them and mounts the copies over the originals:

| File | Change | Made by |
|---|---|---|
| Lomiri's `Shell.qml` | A `Loader` for `files/Components/GesturePackOverlay.qml`, screenshots, and `MultiFingerGestures` in place of the four-finger tap area | `make-shell.py` |
| Lomiri's `Stage/Stage.qml` | Switching apps in opening order, and opening the switcher | `make-stage.py` |
| Lomiri's `Greeter/GreeterView.qml` | A `Loader` for `files/Components/GesturePackLockButtons.qml` on the lock screen's cover page | `make-greeter.py` |
| The UI toolkit's `PageHeader.qml` | Back presses the header's back or close action | `make-uitk.py` |
| System Settings' Gestures page | The choices | `make-settings.py` |

Safety:
- If a file doesn't look as expected (after a system update, for example), that part is left out, and the shell parts stop the whole thing.
- The toolkit change is loaded in a test page before it's kept.
- After `on`, the new shell's log is checked, and the stock shell comes back by itself if it shows an error.
- Shell.qml never imports the plugin. The overlay sits behind a `Loader`, so even a broken overlay or a missing plugin can't break the shell; the gestures then fall back to the stock four-finger tap.
- The plugin goes on a small root-owned tmpfs at `/run/gesture-pack-lib`, and a drop-in in `/run/systemd/user` gives only the shell its import path. Running as root, the script never writes in your home folder: the settings file is written as your user, and the double-tap service reads it as your user.

The plugin watches the settings file, so changes show at once.

## Building the plugin

The release includes a prebuilt `GesturePack/libGesturePack.so` (arm64, Qt 5.15). To build it yourself, with Docker and the clickable image:

```sh
cd plugin && sh build.sh
```

## Tests

- `test/check-patches.sh` (on a PC): `make-*.py` must turn the stock files from 24.04-2.x in `test/stock/` into exactly `test/expected/`, and must refuse to patch twice.
- On the phone, as root, while it is on and the phone is unlocked:
  - `test/plugin-test.sh` checks that a focused app receives Back from the plugin, and that udev doesn't tag the device as a keyboard.
  - `test/header-test.sh` checks a page with the toolkit's back, an app-made back, and a menu icon that Back must leave alone.

Tested on a Pixel 3a XL with Ubuntu Touch 24.04-2.x (daily, Lomiri 0.5.0).

## Upstream

- `upstream/lomiri-multifinger-gestures.patch` is the three-finger gesture change against Lomiri `main` (`26870fa`), for a merge request.
- `test/gestures/` is a C++ driver that sends real Qt multi-touch events to the recognizer (`MultiFingerGestures.qml`) and checks what it reports: each gesture, cancelling, staggered lifts, five fingers, and an app underneath still getting two-finger drags. The phone has no `qmltestrunner`, so it's cross-built for arm64 in the clickable image:
  ```sh
  docker run --rm -v $PWD/test/gestures:/t clickable/amd64-ut24.04-1.x-arm64 bash -c 'cd /t &&     export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig &&     aarch64-linux-gnu-g++ -O1 -fPIC -std=c++17 gesturetest.cpp -o gesturetest     $(pkg-config --cflags --libs Qt5Quick Qt5Test Qt5Gui)'
  ```
  Then on the phone, with `harness.qml` and `lomiri/Components/MultiFingerGestures.qml` next to the binary:
  ```sh
  QML2_IMPORT_PATH=/usr/lib/aarch64-linux-gnu/lomiri/qml QT_QPA_PLATFORM=offscreen     QT_QUICK_BACKEND=software ./gesturetest harness.qml
  ```

## History

Version 0.1 of this repository was the three-finger gestures alone, as whole replacement files for one Lomiri build. 0.2 joins them with a floating Back button (once a separate project, Lomiri Nav), screenshots, lock screen shortcuts and double tap to wake. They all change the same shell files, so they couldn't run side by side. The changes are now made at each start from the phone's own files, so small system updates no longer stop them.

## License

GPL-3.0. `Shell.qml`, `Stage.qml` and the System Settings page are GPL-3.0, and the UI toolkit's `PageHeader.qml` is LGPL-3.0; the patches change copies of them on your phone.

*Built with help from an AI coding assistant, and tested on my own phone.*
