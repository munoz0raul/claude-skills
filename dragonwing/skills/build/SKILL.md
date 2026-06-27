---
description: >
  Use this skill when the user wants to build a Qualcomm Linux image from source
  using Yocto/kas on the build server. Trigger phrases include "build the image",
  "build Qualcomm Linux", "run a Yocto build", "build from source", "kick off a build",
  "start a kas build", or "build for IQ-8275".
allowed-tools:
  - Bash(ssh *)
  - Bash(scp *)
---

Build a Qualcomm Linux image for the IQ-8275 EVK on the dedicated build server
using kas. All builds run remotely on `<build-server>`.

---

## Build server facts

| Field | Value |
|-------|-------|
| Host | `<build-server>` |
| OS | Ubuntu 24.04 |
| CPUs | 16 cores |
| RAM | 62 GB |
| Workspace | `/local/mnt/workspace/build/` |
| Home dir | `/home/<your-user>` (NOT the default home) |
| kas binary | `/home/<your-user>/.local/bin/kas` |
| Shell | tcsh — avoid `!` in inline SSH strings |

Shared caches (pre-populated, do not change):
- `DL_DIR=/local/mnt/workspace/build/downloads`
- `SSTATE_DIR=/local/mnt/workspace/build/sstate-cache`

---

## Step 1 — Confirm kas is installed

```bash
ssh <build-server> '/home/<your-user>/.local/bin/kas --version'
```

Expected: `kas 5.4`. If missing, install it:

```bash
ssh <build-server> 'pip install --user --break-system-packages kas'
```

---

## Step 2 — Choose a build name

Ask the user for a short build name (e.g. `my-build` or a date like `2026-06-26`).
The workspace will be at `/local/mnt/workspace/build/<build-name>`.

If the user does not specify one, use the current date: `YYYY-MM-DD`.

```bash
BUILD_NAME=<build-name>
KAS_WORK_DIR=/local/mnt/workspace/build/$BUILD_NAME
```

---

## Step 3 — Create the workspace and write the build script

The server shell is **tcsh** — inline nohup commands with multiple env vars fail.
Always write a shell script to the server and execute it.

```bash
ssh <build-server> "mkdir -p /local/mnt/workspace/build/$BUILD_NAME"
```

Write the build script:

```bash
ssh <build-server> "cat > /local/mnt/workspace/build/$BUILD_NAME/run-build.sh" << 'SCRIPT'
#!/bin/bash
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/<your-user>/.local/bin
export KAS_WORK_DIR=/local/mnt/workspace/build/BUILD_NAME_PLACEHOLDER
export DL_DIR=/local/mnt/workspace/build/downloads
export SSTATE_DIR=/local/mnt/workspace/build/sstate-cache
export BB_HASHSERVE_DB_DIR=/local/mnt/workspace/build/sstate-cache
umask 0022
cd /local/mnt/workspace/build/BUILD_NAME_PLACEHOLDER
kas build meta-qcom/ci/iq-8275-evk.yml:meta-qcom/ci/qcom-distro.yml:meta-qcom/ci/performance.yml
SCRIPT
```

Then patch the placeholder:

```bash
ssh <build-server> "sed -i 's/BUILD_NAME_PLACEHOLDER/$BUILD_NAME/g' /local/mnt/workspace/build/$BUILD_NAME/run-build.sh && chmod +x /local/mnt/workspace/build/$BUILD_NAME/run-build.sh"
```

---

## Step 4 — Start the build in the background

```bash
ssh <build-server> "nohup /local/mnt/workspace/build/$BUILD_NAME/run-build.sh > /local/mnt/workspace/build/$BUILD_NAME/build.log 2>&1 & echo \$!"
```

Note the PID printed. The build takes **60–90 minutes** on a warm sstate cache.

---

## Step 5 — Monitor progress

Tail the log to check progress:

```bash
ssh <build-server> "tail -50 /local/mnt/workspace/build/$BUILD_NAME/build.log"
```

The build is running normally when you see lines like:
```
NOTE: Running task X of Y (bitbake ...)
```

Check whether the build has finished:

```bash
ssh <build-server> "grep -E '(Build succeeded|ERROR:|build failed)' /local/mnt/workspace/build/$BUILD_NAME/build.log | tail -5"
```

---

## Step 6 — Verify the output artifact

When the build succeeds, confirm the flashable tarball exists:

```bash
ssh <build-server> "ls -lh /local/mnt/workspace/build/$BUILD_NAME/build/tmp/deploy/images/iq-8275-evk/qcom-multimedia-proprietary-image-iq-8275-evk.rootfs.qcomflash.tar.gz"
```

Expected: file present, size roughly 1–2 GB.

---

## Step 7 — Copy artifact to the Mac (optional)

If the user wants the image locally for flashing:

```bash
scp <build-server>:/local/mnt/workspace/build/$BUILD_NAME/build/tmp/deploy/images/iq-8275-evk/qcom-multimedia-proprietary-image-iq-8275-evk.rootfs.qcomflash.tar.gz ~/qualcomm-flash/
```

Then refer to the `flash` skill to flash it. The tarball must be extracted first:

```bash
mkdir -p ~/qualcomm-flash/image
tar -xzf ~/qualcomm-flash/qcom-multimedia-proprietary-image-iq-8275-evk.rootfs.qcomflash.tar.gz \
  -C ~/qualcomm-flash/image
```

Set `IMAGE_DIR` to the extracted directory and follow the `flash` skill from Step 4.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Please use a umask which allows a+rx and u+rwx` | `umask 0022` missing | Ensure the script sets `umask 0022` before `kas build` |
| `Waiting for hashserve` hangs | `BB_HASHSERVE_DB_DIR` not set | Add `BB_HASHSERVE_DB_DIR=/local/mnt/workspace/build/sstate-cache` |
| `kas: command not found` | PATH missing `/home/<your-user>/.local/bin` | Check PATH in the script |
| `Event not found` error | Using `!` in tcsh inline string | Always write a script file; never inline env vars |
| Build starts then immediately exits | Script not executable | Run `chmod +x` on the script before executing |
