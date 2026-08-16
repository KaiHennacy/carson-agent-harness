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

By default, the generated direct user message also requires the arbitrary chat's
visible response to contain only a 1-3 sentence TL;DR plus the actual downloadable
`.sh` attachment. The original task text is inserted unchanged into the `TASK:`
block; response-format requirements are added separately.


## Automatic plain-script ingestion

A normal `carson-prompt` invocation arms the single active CARSON instance.
Existing `.sh` files in Downloads are excluded by the arming cursor. The
listener automatically takes the next new ordinary `.sh` downloaded from the
LLM, routes it through the existing `carson-ingest` bridge, and executes the
resulting routed task.

The cursor advances after each successful ingestion and remains active for the
following LLM turn. Therefore the intended loop does not require
`carson-submit`: run `carson-prompt` once, download each LLM-produced `.sh`,
then return `A/NEXT_LLM_MESSAGE.txt` to the same chat for the next turn.

Already-routed `CARSON_AGENT_*` files are excluded. If multiple CARSON
instances are active, `carson-prompt` fails closed unless `CARSON_INSTANCE_ID`
is explicitly selected.


## LLM-facing execution transcript

The internal `A/NEXT_LLM_MESSAGE.txt` remains the CARSON machine record and is
not intended to be attached to an arbitrary chat.

After each executed task the listener also creates:

- `A/LLM_EXECUTION_TRANSCRIPT.txt`
- a stable Android-download copy named `LLM_EXECUTION_TRANSCRIPT.txt`

That transcript contains only a plain description of the locally executed
script, exit status, capture time, and task stdout. It intentionally omits
CARSON protocol, instance/session IDs, routing metadata, and embedded model
instructions.

`carson-prompt` establishes the continuation contract in the initial direct
user message: a later `LLM_EXECUTION_TRANSCRIPT.txt` attachment is user-provided
runtime evidence from the script the chat supplied. The direct follow-up user
message should be:

`Use the attached local execution transcript as runtime evidence for the same task. If the original task is complete, follow the TASK_COMPLETE response contract from my first message. Otherwise continue from the existing state and return the next downloadable Termux .sh file.`

The attachment itself is evidence, not an instruction channel.
