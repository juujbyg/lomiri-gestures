#!/usr/bin/python3 -I
"""Press the Print key once through a temporary uinput device (run as root).
Lomiri takes a full screenshot of its own screen on Print, like Vol+ and Vol-."""
import fcntl, os, struct, time
UI_SET_EVBIT, UI_SET_KEYBIT, UI_DEV_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x40045564, 0x40045565, 0x405C5503, 0x5501, 0x5502
EV_SYN, EV_KEY, KEY_SYSRQ = 0, 1, 99

def ev(fd, t, c, v):
    os.write(fd, struct.pack("llHHi", 0, 0, t, c, v))

fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
fcntl.ioctl(fd, UI_SET_KEYBIT, KEY_SYSRQ)
fcntl.ioctl(fd, UI_DEV_SETUP, struct.pack("HHHH80sI", 0x06, 1, 4, 1, b"gesture-pack-test-print", 0))
fcntl.ioctl(fd, UI_DEV_CREATE)
time.sleep(1.0)
ev(fd, EV_KEY, KEY_SYSRQ, 1); ev(fd, EV_SYN, 0, 0)
time.sleep(0.03)
ev(fd, EV_KEY, KEY_SYSRQ, 0); ev(fd, EV_SYN, 0, 0)
time.sleep(1.5)
fcntl.ioctl(fd, UI_DEV_DESTROY)
os.close(fd)
