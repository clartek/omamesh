# Omamesh development handoff

This document is a point-in-time handoff for continuing Omamesh development in
another coding environment. It reflects the repository state verified on
2026-09-08 in `/home/josh/Work/omamesh`.

## Product goal

Omamesh is an Omarchy Quattro bar plugin for MeshCore. The long-term goal is
feature parity with the official MeshCore mobile companion app by Liam Cottle,
adapted to Omarchy's visual and interaction conventions.

The plugin must use `meshcore-cli` as its only backend boundary. QML must not
implement MeshCore serial, BLE, TCP, radio, or protocol behavior directly.

The agreed development order is:

1. Robust persistent `meshcore-cli` event handling and companion status
2. Contacts
3. Incoming messages
4. Read-only direct and channel conversations
5. Sending with acknowledgment and failure states
6. Channel and contact management
7. Map and location presentation
8. TCP and BLE transports
9. Notifications, sharing, remote management, and parity polish

Do not commit or push an increment until `./scripts/check` passes and its live
claims are accurately documented.

## Non-negotiable project rules

Read and follow `AGENTS.md` before editing. Important constraints include:

- Keep `BarWidget.qml` small. It owns connection state, unread state, and the
  panel host.
- Put process lifecycle, CLI transactions, and normalized state in
  `MeshCoreService.qml`.
- Put pure validation, parsing, formatting, and transformation helpers in
  `Model.js`.
- Treat every CLI value as untrusted. Validate types, lengths, ranges, and
  missing fields.
- Prefer JSON mode. Never scrape decorative CLI output when structured output
  exists.
- Pass argument arrays to Quickshell `Process`. Never invoke a shell to build a
  command.
- Never log message bodies, channel keys, secrets, or complete device or
  contact identifiers.
- Never edit `/usr/share/omarchy`.
- The plugin ID is always `clartek.omamesh`.
- The product name is always `Omamesh`.
- Never use em dash characters in documentation.
- Preserve keyboard navigation, panel switching, and Escape-to-close.
- Use Omarchy `qs.Commons`, `qs.Ui`, `Style`, and `Color` conventions.
- Plugins run unsandboxed in a long-lived shell, so avoid privilege elevation
  and unnecessary external processes.

## Repository and Git state

- Repository: `https://github.com/clartek/omamesh.git`
- Branch: `main`
- Manifest version: `0.2.0`
- No Git tags or GitHub Releases exist yet.
- Remote tip: `e654909`, `Build out Omamesh 0.2.0 preview`
- Local tip: `f929b3d`, `Add contact telemetry requests and Cayenne LPP sensor display`
- Local `main` is one commit ahead of `origin/main`.
- Before this handoff file was created, the working tree was clean.
- `HANDOFF.md` is intentionally uncommitted and unpushed.

The local telemetry commit is fully covered by the fixture suite, but was not
pushed before handoff. Review it, validate its live UI if practical, update
README status, and then decide whether to push it.

Git author history was rewritten with the user's approval so GitHub can
associate commits with the account and avatar. Future Git identity is:

```text
clartek <1207147+clartek@users.noreply.github.com>
```

Do not rewrite the history again unless explicitly requested.

## Hardware and local environment

The development machine is running Omarchy with the Quickshell-based shell.
The verified hardware and software baseline is:

- `meshcore-cli` 1.6.3 at `/usr/bin/meshcore-cli`
- Python `meshcore` package 2.3.9.1
- Heltec V4 with USB Serial Companion firmware 1.17.1
- USB serial device normally at `/dev/ttyACM0`
- Companion name configured as `ClarTek-Test`
- USA radio configuration was requested, including the user's requested
  2-byte path-hash setting
- Live repeater advertisement discovery was verified

The normal installed development plugin is:

```text
~/.config/omarchy/plugins/clartek.omamesh
```

At handoff time, installed `BarWidget.qml`, `manifest.json`, and `qmldir`
matched the repository. Installed `Panel.qml`, `MeshCoreService.qml`, and
`Model.js` did not include local commit `f929b3d`. Therefore the running plugin
does not yet contain the newest telemetry UI and service code.

The Omarchy shell may already own `/dev/ttyACM0` through its persistent
`meshcore-cli` process. Do not start a second live serial session concurrently.
Either test through the installed plugin or intentionally stop/restart the
owning shell process using normal Omarchy development commands.

## Current implementation

### Backend and connection lifecycle

- Detects whether `meshcore-cli` exists and shows a safe unavailable state if
  it is missing.
- Probes companion identity with structured JSON before declaring success.
- Runs one persistent interactive JSON CLI session after initial validation.
- Uses marker commands to correlate pretty-printed JSON documents with
  contacts, channels, battery, radio, send, management, and telemetry
  transactions.
- Subscribes to incoming messages and enables advert, new-contact, and
  path-update events.
- Debounces contact refreshes after advert and path events.
- Bounds startup, snapshot, send, management, and telemetry operations with
  timers.
- Detects a lost session, presents a normalized error, and reconnects after a
  bounded delay.
- Uses mutual exclusion so snapshots, sends, management changes, and telemetry
  requests do not corrupt each other's stream parsing.

### Companion status

- Companion name
- Connection and transport state
- Battery voltage
- Radio frequency, bandwidth, spreading factor, and coding rate summary
- Manual refresh and periodic refresh

### Contacts

- Live USB contact discovery was verified with a repeater advert.
- Normalizes contact name, role, shortened identifier, route/hop count, advert
  time, and advertised coordinates.
- Supports search and role filtering.
- Supports contact detail view.
- Never exposes the full contact public key to QML UI state.
- Supports contact removal with a second confirmation. This is fixture-tested,
  not live-device validated.

### Telemetry

Local commit `f929b3d` adds on-demand `req_telemetry CONTACT` requests from the
contact detail view. It validates Cayenne LPP records and displays supported
sensor labels, values, channels, and units. It includes bounded timeouts,
concurrency protection, error states, fixture CLI behavior, model tests, and a
Quickshell smoke test.

Telemetry is fixture-tested only. It has not been validated against a remote
radio node, and it is not deployed into the installed plugin at handoff time.

### Channels and conversations

- Lists configured channels while discarding hashes and secrets at the service
  boundary.
- Synchronizes incoming direct and channel messages.
- Maintains bounded in-memory history with duplicate suppression.
- Resolves direct sender prefixes against contacts when possible.
- Parses the MeshCore group convention `sender name: message` for channel
  messages and marks the sender name unverified.
- Shows unread counts and clears them when a conversation opens.
- Provides read-only direct and channel conversation views.

History is currently in memory only and is lost when the plugin reloads.

### Sending

- Direct messages use `msg CONTACT MESSAGE`, followed by `wait_ack`.
- Direct delivery is shown only after the received acknowledgment matches the
  CLI's expected acknowledgment.
- Channel messages use `chan INDEX MESSAGE` and show Sent after acceptance.
- Channel payloads prepend the companion name according to the official group
  convention.
- Payloads reject controls and line breaks and are limited to 160 UTF-8 bytes.
- POSIX-compatible quoting is implemented for interactive CLI parsing.
- The UI has sending, delivered, sent, and failed states.

Direct and channel sending are fixture-tested but not live-radio validated.
Do not describe sending as stable until a deliberate live test confirms the
actual result and timeout schemas.

### Management

- Add a channel with an optional 16-byte secret represented by 32 hex digits.
- Allow backend-derived channel secrets without retaining them in UI state.
- Remove non-public channels with confirmation.
- Remove contacts with confirmation.
- Verify every mutation by requesting a fresh snapshot and proving that the
  target appeared or disappeared.

Management is fixture-tested but not live-device validated. Avoid destructive
live contact tests unless the target and recovery plan are known.

### Map

- Provides an advertised-coordinate overview using normalized contact
  latitude and longitude.
- Handles absent, invalid, and zero-zero coordinates.
- Map markers open contact details.

This is not a street map. QtLocation was not available in the environment, so
geographic tiles and normal pan/zoom behavior remain unimplemented.

### Transports

- USB serial is the default and is live-validated.
- TCP uses exact `meshcore-cli -t HOST -p PORT` argument arrays and is
  fixture-tested only.
- Manual BLE uses exact `meshcore-cli -a TARGET` arguments with optional `-P`
  pairing and is fixture-tested only.
- BLE discovery is not implemented because CLI 1.6.3 `-l` output is decorative
  text even when JSON mode is requested.

## UI direction

The attached reference screenshots in the original development conversation
showed these official mobile app patterns:

- A dark top application header with companion name, battery, radio state,
  settings, and overflow actions
- A searchable Contacts list with role icons, shortened identifiers, route
  state, timestamps, unread badges, and row menus
- Direct message screens with outgoing blue bubbles, incoming gray bubbles,
  timestamps, delivery state, and a 160-character composer
- Channel message screens with visible sender names and sent state
- A map tab with contact and repeater markers
- Bottom Contacts, Channels, and Map navigation

Omamesh should recall this information hierarchy without copying mobile chrome
literally. It must continue to use Omarchy panel spacing, colors, typography,
focus behavior, keyboard shortcuts, and right-side dropdown positioning.

The panel positioning bug was previously fixed by using the Quattro plugin
panel host conventions. Keep the widget's default section as `right`.

## Source and attribution decisions

The official Liam Cottle MeshCore mobile app is closed source and is used only
as a visual and behavioral reference from screenshots and observed behavior.

Preferred sources, in order:

1. Official MeshCore documentation and firmware behavior
2. The exact installed `meshcore-cli` source and observed JSON contract
3. `https://github.com/meshcore-dev/meshcore.js`
4. MIT-licensed `https://github.com/zjs81/meshcore-open` as a secondary
   application-level reference where upstream documentation is silent

Do not use `offbandmesh` as a design or architectural source. The user
explicitly rejected it as low quality and wants behavior kept as close to
upstream MeshCore sources as possible.

README attribution currently says Omamesh is independent, is not affiliated
with or endorsed by MeshCore or Liam Cottle, and credits the official app for
visual direction. Preserve that wording and cite any copied MIT-licensed code
more specifically if code is ever incorporated rather than merely studied.

## Verified `meshcore-cli` contract

See `docs/meshcore-cli-contract.md` for the detailed contract. Important
invocation forms are:

```text
["meshcore-cli", "-j", "-s", PORT, "get", "name"]
["meshcore-cli", "-j", "-t", HOST, "-p", PORT, "get", "name"]
["meshcore-cli", "-j", "-a", TARGET, "get", "name"]
["meshcore-cli", "-j", "-c", "off", CONNECTION_ARGS..., "-i"]
```

Important one-shot or interactive commands include:

```text
contacts
get_channels
get bat
get radio
msgs_subscribe
msg CONTACT MESSAGE
wait_ack
chan INDEX MESSAGE
add_channel NAME [KEY]
remove_channel INDEX
remove_contact CONTACT
req_telemetry CONTACT
```

CLI 1.6.3 can print an error and traceback while exiting with status zero for
some failures. Never trust exit status alone. Require the expected JSON shape.

## Validation status

The full validation suite passed on 2026-09-08 at local commit `f929b3d`:

```text
Model tests passed.
Persistent CLI smoke test passed.
TCP companion smoke test passed.
BLE companion smoke test passed.
Message transaction smoke test passed.
Channel and contact management smoke tests passed.
Node telemetry smoke test passed.
meshcore-cli: /usr/bin/meshcore-cli
Omamesh checks passed.
```

Run it after every meaningful increment:

```bash
./scripts/check
```

The suite includes pure model tests, a deterministic persistent fake CLI,
transport argument checks, send and acknowledgment cases, management snapshot
verification, telemetry parsing and transactions, metadata checks, QML smoke
tests, and Git whitespace validation.

Fixture success is not evidence of live radio success. Keep those statuses
separate in code comments, README, changelog, and release notes.

## Recommended next actions

1. Read `AGENTS.md`, this handoff, `README.md`, `docs/architecture.md`, and
   `docs/meshcore-cli-contract.md`.
2. Inspect local commit `f929b3d` and its UI diff.
3. Update README's feature table to mention telemetry as fixture-tested.
4. Deploy `Panel.qml`, `MeshCoreService.qml`, and `Model.js` from `f929b3d` to
   the user plugin directory using the normal Omarchy development workflow.
5. Restart the shell and visually inspect contact details, telemetry loading,
   empty, success, error, and overflow states.
6. If a known telemetry-capable remote node is available, run one intentional
   live telemetry request and record the sanitized schema and outcome.
7. Run `./scripts/check` again.
8. Push `f929b3d` only if the UI and documentation are accurate. Decide whether
   `HANDOFF.md` belongs in the repository or should remain a local transfer
   artifact.
9. Live-validate sending next with a known recipient and controlled payload.
10. Live-validate reversible channel management. Test contact removal only with
    a known way to recover the contact.
11. Continue map work, transport validation, BLE discovery research,
    notifications, sharing and QR flows, and remote management in that order.

## Known gaps and risks

- No persistent message database or history across shell restarts
- No desktop notifications
- No QR import/export or channel/contact sharing
- No live validation of send, management, TCP, manual BLE, or telemetry
- No automatic USB port discovery
- No BLE discovery
- No geographic tile map
- No path trace visualization or historical telemetry
- No repeater login, status, ACL, or remote administration UI
- No comprehensive compatibility matrix for older or newer CLI versions
- No formal prerelease tags or GitHub Releases
- README status does not yet mention the locally committed telemetry feature
- The installed plugin is behind local commit `f929b3d`

## Release approach discussed

There are no formal releases yet. The recommended policy was:

- Treat 0.2.0 as a development checkpoint, not a GitHub Release.
- Begin formal prereleases after live sending and management validation, for
  example `v0.3.0-alpha.1`.
- Reserve `v1.0.0` for a stable documented feature set with USB, TCP, and BLE
  tested to the supported scope.

Do not tag the current branch merely because fixture checks pass.

