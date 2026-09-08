# Changelog

## 1.0.0 - 2026-09-08

- Added official MeshCore vector icon to the bar widget and panel header.
- Added desktop notifications for incoming direct and channel messages.
- Hardened for Omarchy marketplace security review (all text pinned to PlainText, bounded stream parsing, process kill escalation).
- Added watermark-free Esri World Dark Gray Canvas basemap with pan/zoom and node markers.
- Refined channel messaging to send pure message text without sender name prefixing.
- Added marketplace preview asset and safe removal documentation.

## 0.2.0 - 2026-09-03

- Added persistent USB event synchronization and reconnect handling.
- Added contact, channel, conversation, unread, and coordinate overview UI.
- Added direct and channel sending with transaction and failure states.
- Added channel creation, channel removal, and contact removal workflows.
- Added remote node telemetry requests and Cayenne LPP sensor display.
- Added interactive slippy map canvas with street tiles, pan and zoom, and node pins.
- Added configurable TCP and manual BLE companion transports.
- Added fixture coverage for transports, messaging, management, and telemetry.

Sending, management, TCP, and manual BLE remain preview features pending live
validation. BLE discovery is not yet implemented.

## 0.1.0

- Added the initial Omamesh plugin shell and USB companion integration.
