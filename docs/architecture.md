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

Initial normalized state:

- `backendAvailable`
- `connectionState`: unavailable, disconnected, connecting, connected, error
- `transport`: ble, serial, tcp, or empty
- `companion`: local identity and firmware metadata
- `nodes`: stable ID, display name, role, signal, last seen
- `channels`: stable ID, display name, unread count
- `messages`: stable ID, channel, sender, timestamp, body, delivery state
- `lastError`: short user-safe explanation

The first implementation should be read-only. Sending messages comes after the
installed CLI's exit codes, timeouts, streaming behavior, and JSON schema have
been captured in tests.

