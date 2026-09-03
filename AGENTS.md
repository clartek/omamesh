# Omamesh development guidance

## Product

Omamesh is an Omarchy Quattro bar plugin for MeshCore. It uses
`meshcore-cli` as its only backend boundary and will support BLE, USB/serial,
and TCP/IP companion connections. The visual language should recall the
official MeshCore mobile app while using Omarchy typography, spacing, color,
panel, focus, and keyboard conventions.

## Architecture

- Keep `BarWidget.qml` small: connection state, unread state, and panel host.
- Put process lifecycle and backend normalization in `MeshCoreService.qml`.
- Keep pure display and transformation helpers in `Model.js`.
- Treat `meshcore-cli` output as untrusted input. Validate types and tolerate
  missing fields, old versions, malformed output, and a disconnected device.
- Prefer structured machine-readable CLI output. Do not scrape decorative
  terminal output when a JSON mode exists.
- Never invoke a shell to build commands. Pass argument arrays to `Process`.
- Never log message bodies, keys, secrets, or complete device identifiers.
- Do not add direct BLE, serial, or TCP implementations to QML. Transport
  behavior belongs to `meshcore-cli`.

## Omarchy constraints

- Never edit `/usr/share/omarchy`.
- Never use em dashes in documentation.
- The plugin ID is `clartek.omamesh`; keep it consistent everywhere.
- Use `qs.Commons`, `qs.Ui`, and Omarchy `Style`/`Color` tokens.
- Preserve keyboard navigation, panel switching, and Escape-to-close behavior.
- Plugins execute unsandboxed inside the long-running Omarchy shell. Avoid
  privilege elevation and minimize external commands.
- Run `./scripts/check` before handing off a change.

## Development phases

1. Confirm and document the installed `meshcore-cli` command contract.
2. Implement connection discovery and one transport at a time.
3. Normalize companion, node, channel, and message data behind the service.
4. Build read-only UI states using fixtures before enabling send actions.
5. Add messaging only after identity, channel, and error semantics are tested.
