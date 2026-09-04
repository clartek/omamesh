# `meshcore-cli` contract

This document records behavior verified against the locally installed CLI and a
USB Serial Companion. It is the compatibility baseline for
`MeshCoreService.qml`, not a claim that every CLI release has the same schema.

## Verified environment

- CLI: `meshcore-cli` 1.6.3
- Transport: USB CDC serial
- Linux device class: `/dev/ttyACM*`
- Device access: the shell user must be able to read and write the serial node

USB device names such as `/dev/ttyACM0` are not stable across reconnects. The
service must discover or accept a configured port rather than assuming a fixed
number. Complete USB identifiers must not be logged.

## Invocation

Quickshell `Process` must receive an argument array; no shell is involved:

```text
["meshcore-cli", "-j", "-s", PORT, "get", "name"]
```

TCP uses the same command and JSON contracts with a different connection
argument prefix:

```text
["meshcore-cli", "-j", "-t", HOST, "-p", PORT, "get", "name"]
```

Hosts, ports, and transport selection are normalized before constructing the
argument array. TCP lifecycle behavior is covered by the deterministic
companion but still requires validation against a live TCP endpoint.

Manual BLE selection uses:

```text
["meshcore-cli", "-j", "-a", TARGET, "get", "name"]
```

`-P` is appended only when the user enables OS pairing. Targets may be a BLE
address, platform UUID, or MeshCore device-name fragment accepted by the CLI.
Omamesh rejects empty targets, whitespace, controls, and punctuation outside
the backend's supported address and name forms.

CLI 1.6.3 device listing through `-l` is decorative text even when `-j` is
present. It must not be fed into the structured event parser. Manual BLE
lifecycle behavior is fixture-tested; live BLE and discovery remain pending.

Relevant global options reported by 1.6.3 are:

- `-v`: print the CLI version
- `-j`: JSON output and no init-file execution
- `-s PORT`: connect to a serial companion
- `-b BAUD`: override the serial baud rate
- `-T SECONDS`: discovery timeout
- `-i`: remain in an interactive command loop
- `-c on/off`: control decorative color output

The long option `--version` is not supported. Use `-v`.

## Confirmed read-only commands

`get name` exits successfully and writes one JSON string followed by a newline:

```json
"sanitized-companion-name"
```

Treat the value as untrusted input. A successful parse still requires a string;
reject objects, arrays, numbers, booleans, `null`, and empty values for the
normalized companion name.

`contacts` exits after returning a JSON object keyed by a contact identifier.
On a device with no discovered contacts, the result is `{}`. Contact records
include fields such as `adv_name`, `type`, `public_key`, `out_path_len`,
`last_advert`, `adv_lat`, and `adv_lon`.
Omamesh immediately maps these records to display-only objects and retains only
a shortened identifier; it does not expose the object key or complete public
key to the UI. Coordinates and timestamps are retained only after range and
type validation. The firmware's default coordinate pair of zero, zero is
treated as no advertised location.

```text
["meshcore-cli", "-j", "-s", PORT, "contacts"]
```

`get_channels` exits after returning a JSON array. Version 1.6.3 records contain
`channel_idx`, `channel_name`, `channel_hash`, and `channel_secret`. Omamesh
keeps only the validated index and name. Hashes and secrets are discarded at
the normalization boundary.

```text
["meshcore-cli", "-j", "-s", PORT, "get_channels"]
```

The service runs identity, contacts, and channels sequentially during initial
validation because each one-shot CLI invocation independently owns the serial
connection. It then starts one persistent session:

```text
["meshcore-cli", "-j", "-c", "off", "-s", PORT, "-i"]
```

The service enables advert, new-contact, and path-update events, subscribes to
messages, and requests contacts, channels, battery, and radio snapshots through
that session. Marker commands correlate pretty-printed JSON documents with
their request without depending on terminal prompts or ANSI formatting.

Observed battery data reports millivolts in `level`. Observed radio data uses
`radio_freq`, `radio_bw`, `radio_sf`, and `radio_cr`. Every field remains
optional at the normalization boundary.

Incoming direct and channel records use `PRIV` and `CHAN` type values. Omamesh
validates and bounds message history before exposing it to the UI. It never
logs message bodies.

Direct records identify the contact with a 6-byte public-key prefix. Some
signed direct or room-forwarded records also contain a 4-byte `signature`
prefix, which Omamesh resolves against normalized contacts when possible.
Ordinary channel records do not carry a cryptographic sender identity. The
official group-message convention puts `sender name: message` in plaintext.
Omamesh separates that prefix for display but labels it unverified, since any
holder of the channel key can choose the name.

Advert, new-contact, and path-update events trigger a debounced snapshot rather
than being trusted as complete contact records. A terminated persistent session
enters an error state and reconnects after a bounded delay. This reconnect path
has been verified against the USB companion.

## Confirmed failure behavior

When a serial device exists but does not expose the companion protocol, the CLI
waits before reporting errors on stderr. Observed diagnostics include:

```text
No response from meshcore node, disconnecting
Are you sure your node is a serial companion ?
```

The service therefore needs a bounded process timeout and must not infer a
working companion merely because the serial node opened. User-facing errors
should be normalized and must not reproduce complete device identifiers.

Version 1.6.3 was also observed printing a traceback and an error to stderr but
exiting with status zero when the configured serial path did not exist. A zero
exit status is therefore insufficient evidence of success. The service accepts
the command only when stdout parses to the expected JSON type and value.

## Confirmed send command parsing

Version 1.6.3 accepts `msg CONTACT MESSAGE` for direct messages and
`chan INDEX MESSAGE` for channel messages. A hexadecimal contact key prefix is
resolved before a display name, which avoids ambiguous contact names. The CLI
parses interactive commands with POSIX `shlex`. Omamesh single-quotes message
arguments, escapes embedded quotes, rejects control characters and line breaks,
and limits messages to 160 UTF-8 bytes.

For channel sends, Omamesh prepends the local companion name and separator
required by the group-message convention. The visible byte counter includes
that prefix.

The deterministic companion verifies direct acceptance followed by a matching
acknowledgment, mismatched acknowledgment failure, and channel acceptance. Live
radio validation is still required before sending is considered stable.

## Still to verify

Before enabling message send actions, capture:

- direct and channel send result schemas
- acknowledgment correlation and timeout behavior
- payload length and Unicode behavior
- permission denial and malformed-output behavior
- compatibility with older supported CLI versions

## Channel management

Version 1.6.3 accepts `add_channel NAME [KEY]` and
`remove_channel INDEX`. Names are limited by the backend to 32 UTF-8 bytes.
Explicit keys are 16 bytes represented by exactly 32 hexadecimal characters.
When no key is supplied, the backend deterministically derives one from the
channel name.

Successful channel mutations do not produce a reliable structured success
document. Omamesh therefore requests a fresh `get_channels` snapshot and
verifies that the named channel appeared or the indexed channel disappeared.
The public channel at index zero cannot be removed. Add and remove paths are
covered by the deterministic companion but still require live-device
validation.

## Contact management

Version 1.6.3 accepts `remove_contact CONTACT` and resolves a hexadecimal key
prefix before trying a display name. Omamesh uses the normalized 12-character
key prefix so duplicate or changing display names cannot select the wrong
contact.

As with channels, removal success is not inferred from process status. A fresh
`contacts` snapshot must prove that the key prefix disappeared. The
deterministic companion covers this path, while live-device validation remains
pending. Contact removal requires a second confirmation in the UI.
