---
description: >
  Use this skill when the user wants to SSH into the IQ-8275 EVK, access the device
  over the network, run commands remotely, or connect after the device has booted.
  Trigger phrases include "SSH into the EVK", "connect to the device", "access over SSH",
  "remote terminal", "run command on device", or "connect over network".
allowed-tools:
  - Bash(ssh *)
  - Bash(ssh-keyscan *)
  - Bash(sshpass *)
  - Bash(brew *)
  - Bash(ping *)
  - Bash(python3 *)
  - Bash(pip3 *)
  - Bash(ls *)
---

Connect to the IQ-8275 EVK over SSH. The device must be booted and on the same
network as the Mac.

---

## Step 1 — Get the device IP

If you already know the IP, skip to Step 2.

**From serial console** — use the `serial` skill to log in, then:
```bash
ip addr show end0   # Ethernet
ip addr show wlp1s0 # Wi-Fi
```
The `inet` value is the IP. Example: `192.168.15.86`

**Connect Wi-Fi** (if Ethernet is not available) — from the serial console:
```bash
nmcli dev wifi connect <SSID> password <password>
ip addr show wlp1s0
```

---

## Step 2 — Add the host key (first connection only)

```bash
ssh-keyscan -H <ip-address> >> ~/.ssh/known_hosts
```

---

## Step 3 — Connect interactively

```bash
ssh root@<ip-address>
```

Password: `oelinux123`

---

## Step 4 — Run commands non-interactively (for automation)

Install `sshpass` if not already present:
```bash
brew install sshpass
```

Run a single command:
```bash
sshpass -p 'oelinux123' ssh root@<ip-address> '<command>'
```

Example — verify the flashed image:
```bash
sshpass -p 'oelinux123' ssh root@192.168.15.86 'uname -a && cat /etc/os-release'
```

---

## Step 5 — Verify the device image

```bash
sshpass -p 'oelinux123' ssh root@<ip-address> 'cat /etc/os-release'
```

Expected output:
```
NAME="Qualcomm Linux Reference Distro"
VERSION="2.0"
```

```bash
sshpass -p 'oelinux123' ssh root@<ip-address> 'uname -a'
```

Expected: kernel `6.18.x`, architecture `aarch64`.

---

## Device credentials

| Field      | Value          |
|------------|----------------|
| Username   | `root`         |
| Password   | `oelinux123`   |
| Default IP | DHCP on `end0` (Ethernet) — check with `serial` skill if unknown |
