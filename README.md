# Lomiri multi-finger gestures

Trackpad-style gestures for [Lomiri](https://gitlab.com/ubports/development/core/lomiri), the Ubuntu Touch shell, so moving between apps works like a Mac trackpad.

| Fingers | Gesture | Does |
|---|---|---|
| 3 | swipe left / right | next / previous app, in the order the apps were opened |
| 3 | swipe up | app switcher |
| 3 | swipe down (in the switcher) | closes the switcher |
| 4 | tap | app drawer (Lomiri already did this) |

- While the fingers are down, a label in the middle of the screen names the action. Slide back before lifting to cancel.
- One and two fingers always go to the app, so scrolling and pinch-to-zoom are unaffected.
- With an external screen, Lomiri switches to windowed mode, where it already uses 3 fingers to move windows. The gestures need 4 fingers there.

The recognizer also reports swipe down outside the switcher, pinch in and spread out, but those do nothing for now.

Tested on a Pixel 3a XL (`bonito`) running Ubuntu Touch 24.04-2.x daily (build 283, Lomiri `0.5.0+0~20260910085057.5+ubports24.04.2~1.gbp0bd07c`).

## Trying it on a phone

The root filesystem is read-only, so `lomiri-gestures.sh` doesn't change it. Instead it copies `/usr/share/lomiri` to `/run`, swaps in the three changed files and bind-mounts the copy over the original. A reboot, or `off`, brings the stock shell back.

```
scp -r lomiri-gestures.sh files phablet@<phone>:gestures/
ssh -t phablet@<phone> sudo /home/phablet/gestures/lomiri-gestures.sh on
```

There are also `reload` (new versions of the files), `off` and `status`.

- Each of these restarts the shell, which closes open apps.
- Stock Lomiri sometimes hangs for 90 seconds while shutting down, until systemd kills it, so the screen can stay black for that long.
- The script only runs if `Shell.qml` and `Stage/Stage.qml` match the build the files were made from, so after a system update the change has to be applied to the new files.
- If the new shell logs an error from the changed files, the script goes back to stock by itself.

## What's in here

- `lomiri-multifinger-gestures.patch`: the change against Lomiri `main` (`26870fa`), for upstream.
- `files/`: the same change applied to the phone's build. `Components/MultiFingerGestures.qml` is new, `Shell.qml` uses it in place of the old 4-finger tap area, and `Stage/Stage.qml` gets `gestureSwitchApp`, `gestureShowSpread`, `gestureMinimize` and `gestureShowDesktop`.
- `test/`: a C++ driver that sends real Qt multi-touch events to the recognizer and checks what it reports (19 cases: each gesture, cancelling, staggered lifts, 5 fingers, an app underneath still getting two-finger drags). The phone has no `qmltestrunner`, so it's cross-built for arm64 in the clickable image:

```
docker run --rm -v $PWD/test:/t clickable/amd64-ut24.04-1.x-arm64 bash -c 'cd /t && \
  export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig && \
  aarch64-linux-gnu-g++ -O1 -fPIC -std=c++17 gesturetest.cpp -o gesturetest \
  $(pkg-config --cflags --libs Qt5Quick Qt5Test Qt5Gui)'
```

  Then on the phone, with `harness.qml` and `lomiri/Components/MultiFingerGestures.qml` next to the binary:

```
QML2_IMPORT_PATH=/usr/lib/aarch64-linux-gnu/lomiri/qml QT_QPA_PLATFORM=offscreen \
  QT_QUICK_BACKEND=software ./gesturetest harness.qml
```

## How it works

`MultiFingerGestures` is a Lomiri `TouchGestureArea` that claims touches only once 3 or 4 fingers are down within its recognition period. It tracks the fingers' centre and spread, and re-bases them when a finger is added or lifted, so that jump doesn't read as movement. It commits when fewer than three fingers are left, because `TouchGestureArea` only returns to `WaitingForTouch` after its `releaseRejectPeriod`, which would add lag.

## Fingerprint unlock on the Pixel 3a XL

This needs no code. `biometryd` and the vendor's FPC fingerprint service already run on this image. Set a passcode, then go to System Settings → Security & Privacy → Locking and unlocking → Fingerprint, add a finger and switch it on.

## License

GPL-3.0, like Lomiri. `files/Shell.qml` and `files/Stage/Stage.qml` are Lomiri's own files (Canonical Ltd. and UBports Foundation) with the changes above.
