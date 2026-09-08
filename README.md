# Omamesh

Omamesh is an independent Omarchy Quattro bar plugin for MeshCore. It connects
to a companion through `meshcore-cli` and provides a compact status indicator
and an Omarchy-native panel inspired by the information hierarchy of the
official MeshCore mobile app.

## Status

Omamesh version 1.0 supports USB Serial, TCP companion, and BLE connections,
contact and channel management, incoming and outgoing messaging with
acknowledgments, sensor telemetry presentation, desktop notifications, and an
interactive map view with offline grid and optional online street map tiles.

| Feature | Status |
| --- | --- |
| Detect `meshcore-cli` | Working |
| USB Serial Companion connection | Working |
| TCP companion connection | Working |
| BLE companion connection | Working |
| Companion name and connection state | Working |
| Companion battery and radio status | Working |
| In-panel connection and transport inspector | Working |
| Persistent event session and reconnect | Working |
| Contact discovery and browsing | Working |
| Configured channel browsing | Working |
| Incoming direct and channel messages | Working |
| Direct and channel conversations | Working |
| Direct and channel sending with ACK tracking | Working |
| Add and remove channels | Working |
| Remove contacts | Working |
| Remote node sensor telemetry | Working |
| Advertised-coordinate overview | Working |
| Slippy street map with zoom and pan | Working |
| Desktop notifications for messages | Working |

## Requirements

- Omarchy Quattro with the Quickshell-based shell
- `meshcore-cli`
- a MeshCore USB Serial Companion, TCP companion endpoint, or BLE companion
- for USB, permission to read and write the companion's `/dev/ttyACM*` or
  `/dev/ttyUSB*` device

If `meshcore-cli` is missing, the plugin remains loaded and displays
`meshcore-cli not found`; it does not attempt companion commands. Install the
CLI and refresh the panel to retry.

## Installation

Clone the repository into Omarchy's user plugin directory:

```bash
git clone https://github.com/clartek/omamesh.git \
  ~/.config/omarchy/plugins/clartek.omamesh
omarchy plugin enable clartek.omamesh
omarchy restart shell
```

The widget defaults to the right side of the bar, USB transport, and
`/dev/ttyACM0`. Plugin settings can select TCP or BLE and configure connection
endpoints and timeout parameters.

## Controls

- Click the bar icon to open or close the panel.
- Middle-click the bar icon to refresh.
- Press `R` or `Enter` in the panel to refresh.
- Press `/` on Contacts or Channels to focus search.
- Click "󰒋" in the header to inspect active transport, endpoints, radio status,
  and battery voltage.
- Open a Direct contact or channel to compose a message. Direct messages show
  Delivered only after a matching acknowledgment. Channel messages show Sent
  after the companion accepts them.
- On Channels, use `+` to add a channel. Use the menu button on a channel to
  open its settings. Removal requires a second confirmation and is disabled
  for the public channel.
- Use the menu button on a contact to view its details, request sensor
  telemetry, or remove the contact. Contact removal also requires a second
  confirmation.
- On the Map tab, drag with the mouse to pan, use the floating zoom controls or
  mouse wheel to zoom, click recenter to fit all contacts, or press `T` to toggle
  between online street tiles and offline coordinate grid mode.
- Press `H`/`L` or `1`/`2`/`3` to switch between Contacts, Channels, and Map.
- Press `Tab`/`Shift+Tab` to switch Omarchy panels.
- Press `Escape` to close the panel or return from subviews.

## Network activity and privacy

Omamesh communicates with `meshcore-cli` locally on the system using argument
arrays without invoking a shell.

When online map tiles are enabled (`enableMapTiles: true`), Omamesh fetches
slippy map raster tiles over HTTPS from Esri
(`server.arcgisonline.com`, port 443) or OpenStreetMap
(`tile.openstreetmap.org`, port 443) according to the configured provider.
No credentials, tokens, cookies, or device identifiers are sent with tile
requests.

When online map tiles are disabled (`enableMapTiles: false`), Omamesh operates
entirely offline in coordinate grid mode and makes no outbound network requests.

Omamesh never logs message bodies, encryption keys, channel secrets, or
complete device identifiers.

## Removing

To remove the plugin:

```bash
omarchy plugin remove clartek.omamesh
```

This removes the plugin files in `~/.config/omarchy/plugins/clartek.omamesh`.
Plugin settings stored in Omarchy `shell.json` under `clartek.omamesh` are
managed by Omarchy.

Omamesh writes no files to `/tmp`, `/var`, `/etc`, or the desktop keyring, and
leaves no background daemons, units, or cron tasks running after removal.

## Validate

```bash
./scripts/check
```

The checks validate metadata and fixtures, run pure model tests, exercise a
deterministic persistent CLI session, test TCP and BLE transport argument
handling, verify send and management transactions, validate the plugin with
Omarchy, and check the working tree for whitespace errors.

## Architecture and security

`meshcore-cli` is the only backend boundary. Omamesh does not implement serial,
BLE, TCP, or MeshCore protocol handling directly in QML. Commands are passed to
Quickshell as argument arrays without invoking a shell.

CLI output is treated as untrusted input. The service validates JSON and
normalizes connection, contact, and channel data before exposing it to the UI.
Complete contact identifiers are shortened, and channel hashes and secrets are
discarded during normalization. Message bodies, keys, secrets, and complete
device identifiers must never be logged.

All QML Text sinks use explicit PlainText formatting to prevent rich text
markup injection. Process outputs are collected using bounded streaming parsers
with process-group termination and kill escalation.

See [`docs/architecture.md`](docs/architecture.md),
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md), and
[`docs/meshcore-cli-contract.md`](docs/meshcore-cli-contract.md) for details.

## Project layout

```text
BarWidget.qml                   bar indicator and panel host
Panel.qml                       keyboard-friendly dropdown surface
MeshCoreService.qml             process lifecycle and normalized state
Model.js                        pure validation and display helpers
manifest.json                   plugin manifest and settings schema
preview.png                     plugin marketplace preview image
fixtures/                       sanitized offline development data
tests/                          model and transport tests
scripts/check                   local validation
docs/architecture.md            transport and state design
docs/DEVELOPMENT.md             development guidance and security rules
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
