# Arbitrary-chat direct prompt adapter

Do not depend on instructions inside an uploaded document to control an
arbitrary AI chat's response format. Some models intentionally treat behavioral
instructions in attachments as untrusted content.

Instead, place the artifact requirement in the user's direct message:

```bash
carson-prompt "Identify duplicate files in order to clean up storage space on the system"
```

The helper turns the task into a direct request for an ordinary downloadable
Termux `.sh`. If `termux-clipboard-set` is available, it also copies that direct
message to the Android clipboard.

Paste the generated direct message into an arbitrary chat that supports file
attachments. No CARSON routing or listener information is exposed to that chat.

After downloading the returned `.sh`, submit it locally with `carson-submit`.
