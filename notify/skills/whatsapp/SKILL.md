---
description: >
  Use this skill when you are blocked and need human input to continue, when a
  long-running task finishes and the user should be notified, when you encounter
  an error you cannot resolve autonomously, or when the user asks you to send
  them a WhatsApp message. Trigger phrases include "notify me", "message me on
  WhatsApp", "let me know when done", "ping me if stuck", or "send me a message".
allowed-tools:
  - Bash(curl *)
---

Send a WhatsApp message to the owner via the CallMeBot API.

---

## When to use this skill

- You are **blocked** and cannot proceed without a decision from the user
- A **long background task** (build, deploy, test run) has completed or failed
- You hit an **unrecoverable error** and need the user to intervene
- The user explicitly asks you to send them a message

---

## Step 1 — Compose the message

Keep the message short and specific. Include:
- What you were doing
- What happened (blocked / finished / failed)
- What decision or action you need from the user (if any)

Example: `Build qli-2.0 finished successfully. Artifact ready at ~/qualcomm-flash/.`
Example: `Blocked on flashing step 4 — device not detected in EDL mode. Please check SW2-3 and USB-C cable.`

---

## Step 2 — Send the message

```bash
curl -s "https://api.callmebot.com/whatsapp.php?phone=OWNER_PHONE&text=<url-encoded-message>&apikey=OWNER_APIKEY"
```

URL-encode the message text (spaces → `+`, special chars → `%XX`).

Simple encoding with Python:
```bash
MSG="Your message here"
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$MSG'))")
curl -s "https://api.callmebot.com/whatsapp.php?phone=OWNER_PHONE&text=${ENCODED}&apikey=OWNER_APIKEY"
```

---

## Step 3 — Confirm delivery

A response of `Message queued. Sending in progress.` means the message was accepted.

If you get an error, check:
- The message text is properly URL-encoded
- Network access to `api.callmebot.com` is available

---

## Credentials

| Field   | Value           |
|---------|-----------------|
| Phone   | `OWNER_PHONE`   |
| API key | `OWNER_APIKEY`  |
