# Omamesh

Omamesh is an independent Omarchy Quattro bar plugin for MeshCore. It connects
to a companion through `meshcore-cli` and provides a compact status indicator
and an Omarchy-native panel inspired by the information hierarchy of the
official MeshCore mobile app.

> [!IMPORTANT]
> Omamesh is an early development preview. USB contact and channel browsing
> works, but messaging, maps, BLE, and TCP are not implemented yet.

## Current status

The current USB milestone has been tested with:

- `meshcore-cli` 1.6.3
- a Heltec V4 running USB Serial Companion firmware 1.17.1
- live discovery of a repeater advertisement

| Feature | Status |
| --- | --- |
| Detect `meshcore-cli` | Working |
| USB Serial Companion connection | Working |
| Companion name and connection state | Working |
| Contact discovery and browsing | Working |
| Configured channel browsing | Working |
| Direct and channel messages | Not implemented |
| Sending messages | Not implemented |
| Network map | Placeholder |
| BLE and TCP companions | Not implemented |

## Requirements

- Omarchy Quattro with the Quickshell-based shell
- `meshcore-cli`
- a MeshCore USB Serial Companion
- permission to read and write the companion's `/dev/ttyACM*` or
  `/dev/ttyUSB*` device

If `meshcore-cli` is missing, the plugin remains loaded and displays
`meshcore-cli not found`; it does not attempt USB commands. Install the CLI and
refresh the panel to retry.

## Install for development

Clone the repository into Omarchy's user plugin directory:

```bash
git clone https://github.com/clartek/omamesh.git \
  ~/.config/omarchy/plugins/clartek.omamesh
omarchy plugin enable clartek.omamesh
omarchy restart shell
```

The widget defaults to the right side of the bar and `/dev/ttyACM0`. Use the
Omarchy plugin settings when the companion is on a different supported serial
device.

## Controls

- Click the bar icon to open or close the panel.
- Middle-click the bar icon to refresh.
- Press `R` or `Enter` in the panel to refresh.
- Press `H`/`L` or `1`/`2`/`3` to switch between Contacts, Channels, and Map.
- Press `Tab`/`Shift+Tab` to switch Omarchy panels.
- Press `Escape` to close the panel.

## Validate

```bash
./scripts/check
```

The checks validate metadata and fixtures, run the pure model tests, validate
the plugin with Omarchy, and check the working tree for whitespace errors.
`ServiceHarness.qml` provides an additional live USB smoke test for developers.

## Architecture and security

`meshcore-cli` is the only backend boundary. Omamesh does not implement serial,
BLE, TCP, or MeshCore protocol handling directly in QML. Commands are passed to
Quickshell as argument arrays without invoking a shell.

CLI output is treated as untrusted input. The service validates JSON and
normalizes connection, contact, and channel data before exposing it to the UI.
Complete contact identifiers are shortened, and channel hashes and secrets are
discarded during normalization. Message bodies, keys, secrets, and complete
device identifiers must never be logged.

See [`docs/architecture.md`](docs/architecture.md) and
[`docs/meshcore-cli-contract.md`](docs/meshcore-cli-contract.md) for details.

## Roadmap

1. Persistent CLI event handling and complete companion status
2. Contact search, filtering, details, paths, and telemetry
3. Incoming message synchronization, local history, and unread state
4. Read-only direct and channel conversations
5. Direct and channel message sending with acknowledgment and failure states
6. Channel and contact management
7. Location-aware network map
8. TCP and BLE companion transports through `meshcore-cli`
9. Notifications, QR workflows, remote management, and parity polish

## Project layout

```text
BarWidget.qml                   bar indicator and panel host
Panel.qml                       keyboard-friendly dropdown surface
MeshCoreService.qml             process lifecycle and normalized state
Model.js                        pure validation and display helpers
fixtures/                       sanitized offline development data
tests/                          model tests
scripts/check                   local validation
docs/architecture.md            transport and state design
docs/meshcore-cli-contract.md   verified backend behavior
```

## Acknowledgments

Omamesh is not affiliated with or endorsed by MeshCore or Liam Cottle. Its
visual direction is inspired by Liam Cottle's official MeshCore companion app.
Behavior and protocol semantics are checked first against the official MeshCore
documentation, the installed `meshcore-cli` implementation, and
[`meshcore.js`](https://github.com/meshcore-dev/meshcore.js). The MIT-licensed
[`meshcore-open`](https://github.com/zjs81/meshcore-open) project is a secondary
reference for application-level behavior where upstream documentation is
silent.

## License

Omamesh is available under the [MIT License](LICENSE).
