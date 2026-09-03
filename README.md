# OmaMesh

OmaMesh brings MeshCore companions to the Omarchy bar. The planned plugin
connects through `meshcore-cli` over BLE, USB/serial, or TCP/IP and provides a
compact status indicator plus an Omarchy-native panel for nodes and messages.

## Status

This repository currently contains the development scaffold. It deliberately
does not guess the `meshcore-cli` protocol: the next step is to install or
locate the intended CLI distribution and capture its supported machine-readable
commands.

## Requirements

- Omarchy Quattro with the Quickshell-based shell
- `meshcore-cli` (not currently installed on this development machine)
- Git

## Validate

```bash
./scripts/check
```

## Live development

The repository is the source of truth. Install a development checkout under
`~/.config/omarchy/plugins/clartek.omamesh`, enable it, and let Omarchy's shell
hot-reload QML changes. Do not copy or link it into the live directory until
the backend command contract has been reviewed.

Useful commands after the development checkout exists:

```bash
omarchy plugin validate .
omarchy-shell shell rescanPlugins
omarchy plugin enable clartek.omamesh
omarchy restart shell
```

## Structure

```text
BarWidget.qml         bar indicator and panel host
Panel.qml             keyboard-friendly dropdown surface
MeshCoreService.qml   meshcore-cli process boundary and normalized state
Model.js              pure data helpers
fixtures/             sanitized offline development data
scripts/check         local validation
docs/architecture.md  transport and state design
```

