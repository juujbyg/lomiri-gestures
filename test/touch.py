#!/usr/bin/python3 -I
"""A virtual touchscreen for tests on the phone (run as root). One finger:

    touch.py hold X Y MS     press at X,Y (screen pixels), hold MS milliseconds, lift
    touch.py tap X Y

The device covers the screen (1080x2160 by default, or W and H in the
environment) and is removed when the script ends.
"""
import fcntl, os, struct, sys, time

UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT, UI_SET_PROPBIT = 0x40045564, 0x40045565, 0x40045567, 0x4004556E
UI_DEV_SETUP, UI_ABS_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405C5503, 0x401C5504, 0x5501, 0x5502
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
BTN_TOUCH, INPUT_PROP_DIRECT = 0x14A, 1
ABS_X, ABS_Y, ABS_MT_SLOT, ABS_MT_X, ABS_MT_Y, ABS_MT_ID = 0x00, 0x01, 0x2F, 0x35, 0x36, 0x39

W = int(os.environ.get("W", 1080))
H = int(os.environ.get("H", 2160))


def ev(fd, t, c, v):
    os.write(fd, struct.pack("llHHi", 0, 0, t, c, v))


def abs_setup(fd, code, maximum):
    fcntl.ioctl(fd, UI_SET_ABSBIT, code)
    fcntl.ioctl(fd, UI_ABS_SETUP, struct.pack("HH6i", code, 0, 0, 0, maximum, 0, 0, 0))


def main():
    cmd, x, y = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    ms = int(sys.argv[4]) if cmd == "hold" else 60
    fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
    fcntl.ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_ABS)
    fcntl.ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT)
    abs_setup(fd, ABS_X, W - 1)
    abs_setup(fd, ABS_Y, H - 1)
    abs_setup(fd, ABS_MT_SLOT, 9)
    abs_setup(fd, ABS_MT_X, W - 1)
    abs_setup(fd, ABS_MT_Y, H - 1)
    abs_setup(fd, ABS_MT_ID, 65535)
    fcntl.ioctl(fd, UI_DEV_SETUP, struct.pack("HHHH80sI", 0x06, 1, 3, 1, b"gesture-pack-test-touch", 0))
    fcntl.ioctl(fd, UI_DEV_CREATE)
    time.sleep(1.5)   # let the compositor pick the device up
    try:
        ev(fd, EV_ABS, ABS_MT_SLOT, 0); ev(fd, EV_ABS, ABS_MT_ID, 1)
        ev(fd, EV_ABS, ABS_MT_X, x); ev(fd, EV_ABS, ABS_MT_Y, y)
        ev(fd, EV_KEY, BTN_TOUCH, 1); ev(fd, EV_ABS, ABS_X, x); ev(fd, EV_ABS, ABS_Y, y)
        ev(fd, EV_SYN, 0, 0)
        print(f"TOUCH down {x},{y} at {time.strftime('%T')}", flush=True)
        end = time.time() + ms / 1000
        while time.time() < end:        # a resting finger still reports now and then
            time.sleep(0.05)
            ev(fd, EV_ABS, ABS_MT_X, x); ev(fd, EV_SYN, 0, 0)
        ev(fd, EV_ABS, ABS_MT_ID, -1); ev(fd, EV_KEY, BTN_TOUCH, 0); ev(fd, EV_SYN, 0, 0)
        print(f"TOUCH up after {ms} ms", flush=True)
        time.sleep(0.5)
    finally:
        fcntl.ioctl(fd, UI_DEV_DESTROY)
        os.close(fd)


if __name__ == "__main__":
    main()
