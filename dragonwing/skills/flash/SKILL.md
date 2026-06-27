---
description: >
  Use this skill when the user wants to flash the IQ-8275 EVK, mentions QDL,
  wants to flash a Qualcomm Linux image, asks about UFS provisioning, SAIL firmware,
  EDL mode, or asks how to update the device software. Trigger phrases include
  "flash the device", "flash the EVK", "flash an image", "provision UFS",
  "put device in EDL", or "update the firmware".
allowed-tools:
  - Bash(ls *)
  - Bash(find *)
  - Bash(mkdir *)
  - Bash(chmod *)
  - Bash(xattr *)
  - Bash(curl *)
  - Bash(unzip *)
  - Bash(cd *)
  - Bash(~/tools/qdl/QDL_2.7_Mac_ARM64/qdl *)
  - Bash(system_profiler *)
  - Bash(python3 *)
  - Read
---

Flash Qualcomm Linux onto the IQ-8275 EVK using QDL (Qualcomm Device Loader).
This is a macOS host workflow. Follow each step in order.

---

## Step 1 — Check QDL is installed

QDL lives at `~/tools/qdl/QDL_2.7_Mac_ARM64/qdl`. Check it exists and works:

```bash
~/tools/qdl/QDL_2.7_Mac_ARM64/qdl --version 2>&1 | head -2
```

**If missing:** QDL requires a Qualcomm account to download — Claude cannot fetch it automatically.
1. Ask the user to download **QDL 2.7 macOS ARM64** from the Qualcomm Software Center.
2. Extract the zip to `~/tools/qdl/` so the binary is at `~/tools/qdl/QDL_2.7_Mac_ARM64/qdl`.
3. Fix permissions and clear macOS quarantine:
   ```bash
   chmod -R u+w ~/tools/qdl/QDL_2.7_Mac_ARM64/
   xattr -dr com.apple.quarantine ~/tools/qdl/QDL_2.7_Mac_ARM64/
   ```
4. Re-run the version check above before continuing.

---

## Step 2 — Determine image source

Ask the user: **"Do you have a custom-built image, or should I download the pre-built Qualcomm Linux image?"**

- **Pre-built:** proceed to Step 3.
- **Custom-built:** ask for the path to the image directory. It must contain
  `prog_firehose_ddr.elf`, `rawprogram*.xml`, `patch*.xml`, and a `sail_nor/` subfolder.
  Set `IMAGE_DIR` to that path and skip Step 3.

---

## Step 3 — Download pre-built artifacts (skip if custom image)

Create the working directory and download both artifacts:

```bash
mkdir -p ~/qualcomm-flash
```

**Provision zip** (small, ~360 KB, public URL):
```bash
curl -L -o ~/qualcomm-flash/provision.zip \
  "https://artifacts.codelinaro.org/artifactory/codelinaro-le/Qualcomm_Linux/QCS8300/provision.zip"
unzip -q ~/qualcomm-flash/provision.zip -d ~/qualcomm-flash/provision
```

**OS image zip** (~1.5 GB, public URL):
```bash
curl -L -o ~/qualcomm-flash/qli-image.zip \
  "https://artifacts.codelinaro.org/artifactory/qli-ci/flashable-binaries/meta-qcom/iq-8275-evk/qli-2.0-rc3-qcom-multimedia-proprietary-image.zip"
unzip -q ~/qualcomm-flash/qli-image.zip -d ~/qualcomm-flash/image
```

Set paths:
```
PROVISION_DIR=~/qualcomm-flash/provision
IMAGE_DIR=~/qualcomm-flash/image/images/iq-8275-evk/qcom-multimedia-proprietary-image-iq-8275-evk
```

---

## Step 4 — Put the device in EDL mode

Tell the user to do these physical steps:
1. **Flip SW2-3 DIP switch UP** (EDL mode).
2. Connect **12V power supply** to the EVK.
3. Connect **USB-C cable from USB0** on the EVK to the Mac.
4. Toggle the **power switch ON**.

Confirm EDL mode:
```bash
system_profiler SPUSBDataType | grep -A4 -i qualcomm
```

Expected: `Manufacturer: Qualcomm CDMA Technologies MSM`. If the device doesn't appear, ask the user to recheck SW2-3 and the USB-C cable.

---

## Step 5 — Provision UFS

Run from the provision directory:
```bash
cd $PROVISION_DIR
~/tools/qdl/QDL_2.7_Mac_ARM64/qdl --storage ufs prog_firehose_ddr.elf provision_1_3.xml
```

Expected output: `UFS provisioning succeeded`

**After provisioning completes the device disconnects from USB.** Tell the user to:
- Toggle power switch OFF then ON to reboot back into EDL mode.
- Wait ~5 seconds, then confirm EDL mode again (Step 4 check command).

---

## Step 6 — Flash SAIL firmware

The Safety Island (SAIL) firmware must be flashed before the main image:

```bash
cd $IMAGE_DIR/sail_nor
~/tools/qdl/QDL_2.7_Mac_ARM64/qdl --storage spinor prog_firehose_ddr.elf rawprogram0.xml patch0.xml
```

Expected output:
```
flashed "SAIL_HYP" successfully
flashed "SAIL_SW1" successfully
flashed "SAIL_HYP_BKUP" successfully
flashed "SAIL_SW1_BKUP" successfully
11 patches applied
```

If the command says `Waiting for EDL device`, the device dropped off USB — power-cycle back into EDL and retry.

---

## Step 7 — Flash Qualcomm Linux

```bash
cd $IMAGE_DIR
~/tools/qdl/QDL_2.7_Mac_ARM64/qdl --storage ufs prog_firehose_ddr.elf rawprogram*.xml patch*.xml
```

Flash is complete when the final line reads: `partition 1 is now bootable`

Sector-truncation warnings (e.g. `zeros_33sectors.bin to big for apdp_a truncated`) are harmless.

---

## Step 8 — Boot the device

Tell the user to:
1. **Flip SW2-3 DIP switch back DOWN**.
2. Power-cycle the device.

The device will boot into the newly flashed Qualcomm Linux image.

To verify, use the `serial` or `ssh` skills to connect and run:
```bash
cat /etc/os-release   # expect: Qualcomm Linux Reference Distro 2.0
uname -a              # expect: aarch64
```
