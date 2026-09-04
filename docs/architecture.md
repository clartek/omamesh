# Architecture

```text
Omarchy bar and panel
        |
        v
MeshCoreService.qml
  process lifecycle
  JSON validation
  normalized state
        |
        v
   meshcore-cli
   /     |     \
 BLE   USB    TCP/IP
```

The UI must not know transport-specific command details. It requests operations
from `MeshCoreService`, which owns connection state and converts backend output
into stable companion, node, channel, and message models.

Transport selection is normalized into an argument array before process
launch. USB uses `-s PORT` and TCP uses `-t HOST -p PORT`. The persistent
session, snapshots, messaging, and management state machines are shared across
the supported transports.

Manual BLE uses `-a TARGET` and optionally `-P` for OS pairing. The target is
validated before process launch and must be explicitly configured. Automatic
discovery remains separate because CLI 1.6.3 exposes its device list as
decorative terminal output rather than JSON.

Initial normalized state:

- `backendAvailable`
- `connectionState`: unavailable, disconnected, connecting, connected, error
- `transport`: ble, serial, tcp, or empty
- `companion`: local identity and firmware metadata
- `nodes`: stable ID, display name, role, signal, last seen
- `channels`: stable ID, display name, unread count
- `messages`: stable ID, channel, sender, timestamp, body, delivery state
- `lastError`: short user-safe explanation

Contact normalization retains validated advertised latitude, longitude, and
last-advert time. The first map layer projects those normalized coordinates
into a native QML overview without network access. Map tiles and geographic
context remain a replaceable visual layer and must not alter the normalized
contact model.

The first implementation should be read-only. Sending messages comes after the
installed CLI's exit codes, timeouts, streaming behavior, and JSON schema have
been captured in tests.

Mutating operations use bounded transactions on the persistent CLI session.
The service does not treat a zero exit status or an empty response as success.
Channel changes complete only when a subsequent normalized snapshot proves the
requested state. Secrets exist only long enough to construct the CLI command
and are not retained in service or UI state after submission.
