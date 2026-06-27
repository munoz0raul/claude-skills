---
description: >
  Use this skill when the user wants to access the serial console or UART terminal
  of the IQ-8275 EVK, wants to log in to the device directly, wants to check the
  device boot output, or needs to get the device IP address before SSH is available.
  Trigger phrases include "open serial console", "connect to UART", "serial terminal",
  "connect to device console", "get device IP", or "check boot logs".
allowed-tools:
  - Bash(ls *)
  - Bash(pip3 *)
  - Bash(python3 *)
  - Bash(screen *)
---

Access the IQ-8275 EVK debug UART serial console from macOS. The EVK exposes
four serial ports over a single micro-USB connection; the main console is always
the second port.

---

## Step 1 — Connect the cable

Connect a **micro-USB cable** from the micro-USB port on the EVK to the Mac.

---

## Step 2 — Find the serial port

```bash
ls /dev/cu.usbserial*
```

Expected output (4 ports): `/dev/cu.usbserial-<ID>P0` through `P3`

The **main console is `P1`** (the second port). Use the ID from the output above,
for example: `/dev/cu.usbserial-NNNUP457006P1`

If no ports appear, check the micro-USB cable and that the EVK is powered on.

---

## Step 3 — Connect interactively

For an interactive terminal session:

```bash
screen /dev/cu.usbserial-<ID>P1 115200
```

- Press **Enter** to get a login prompt.
- Login: **username** `root`, **password** `oelinux123`
- To exit screen: `Ctrl-A` then `K`, confirm with `y`.

---

## Step 4 — Connect via script (for automation)

When Claude needs to run commands on the device over serial (e.g. to get the IP),
use Python + pyserial:

```bash
pip3 install pyserial -q
```

Example — log in and get the IP address:

```python
import serial, time

PORT = "/dev/cu.usbserial-<ID>P1"  # replace <ID> with actual value from Step 2

def cmd(s, command, wait=2):
    s.write((command + '\n').encode())
    time.sleep(wait)
    return s.read(s.in_waiting).decode(errors='replace')

with serial.Serial(PORT, 115200, timeout=3) as s:
    time.sleep(0.5)
    s.reset_input_buffer()
    s.write(b'\n')
    time.sleep(1.5)
    out = s.read(s.in_waiting).decode(errors='replace')

    if 'login:' in out or 'Login:' in out:
        s.write(b'root\n'); time.sleep(1)
        s.read(s.in_waiting)
        s.write(b'oelinux123\n'); time.sleep(1.5)
        s.read(s.in_waiting)

    print(cmd(s, 'ip addr show end0 2>/dev/null; ip addr show wlp1s0 2>/dev/null'))
```

---

## Step 5 — Get the IP address

After logging in (interactive or scripted), run:

```bash
# Ethernet (usually has IP automatically via DHCP)
ip addr show end0

# Wi-Fi (only if configured)
ip addr show wlp1s0
```

The `inet` value is the device IP. Example: `inet 192.168.15.86/24`

Once you have the IP, use the `ssh` skill for all subsequent access.

---

## Device credentials

| Field    | Value        |
|----------|--------------|
| Username | `root`       |
| Password | `oelinux123` |
| Baud     | `115200`     |
| Port     | Second port (`P1`) of the micro-USB FTDI adapter |
