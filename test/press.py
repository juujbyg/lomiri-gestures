#!/usr/bin/python3 -I
"""Press Alt+Left N times through one uinput device: press.py [count] [interval_s]"""
import fcntl, os, struct, sys, time
UI_SET_EVBIT, UI_SET_KEYBIT, UI_DEV_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x40045564, 0x40045565, 0x405C5503, 0x5501, 0x5502
EV_SYN, EV_KEY, ALT, LEFT = 0, 1, 56, 105

def ev(fd, t, c, v):
    os.write(fd, struct.pack("llHHi", 0, 0, t, c, v))

n = int(sys.argv[1]) if len(sys.argv) > 1 else 1
gap = float(sys.argv[2]) if len(sys.argv) > 2 else 2.0
fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
for k in (ALT, LEFT):
    fcntl.ioctl(fd, UI_SET_KEYBIT, k)
fcntl.ioctl(fd, UI_DEV_SETUP, struct.pack("HHHH80sI", 0x06, 1, 2, 1, b"gesture-pack-test-keys", 0))
fcntl.ioctl(fd, UI_DEV_CREATE)
time.sleep(1.0)
for i in range(n):
    ev(fd, EV_KEY, ALT, 1); ev(fd, EV_KEY, LEFT, 1); ev(fd, EV_SYN, 0, 0)
    time.sleep(0.03)
    ev(fd, EV_KEY, LEFT, 0); ev(fd, EV_KEY, ALT, 0); ev(fd, EV_SYN, 0, 0)
    print(f"HB pressed Back {i + 1} at {time.strftime('%T')}", flush=True)
    time.sleep(gap)
fcntl.ioctl(fd, UI_DEV_DESTROY)
os.close(fd)
