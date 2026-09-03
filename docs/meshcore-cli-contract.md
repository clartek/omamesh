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

Relevant global options reported by 1.6.3 are:

- `-v`: print the CLI version
- `-j`: JSON output and no init-file execution
- `-s PORT`: connect to a serial companion
- `-b BAUD`: override the serial baud rate
- `-T SECONDS`: discovery timeout

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
include fields such as `adv_name`, `type`, `public_key`, and `out_path_len`.
Omamesh immediately maps these records to display-only objects and retains only
a shortened identifier; it does not expose the object key or complete public
key to the UI.

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

The service runs identity, contacts, and channels sequentially because each
CLI invocation independently owns the serial connection.

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

## Still to verify

Before adding message views and actions, capture:

- command names and JSON schemas for message history and events
- exit codes for success, missing port, permission denial, timeout, and malformed
  output
- whether each command terminates or remains attached for events
- behavior across disconnect and reconnect
- compatibility with older supported CLI versions
