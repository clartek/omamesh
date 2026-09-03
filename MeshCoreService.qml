import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool backendAvailable: false
  property string connectionState: "unavailable"
  property string transport: ""
  property var companion: null
  property var nodes: []
  property var channels: []
  property var messages: []
  property string lastError: ""

  readonly property int refreshIntervalSec: Model.clampRefreshInterval(
    settings && settings.refreshIntervalSec !== undefined
      ? settings.refreshIntervalSec
      : 10
  )
  readonly property string statusText: Model.connectionLabel(connectionState)

  function refresh() {
    if (backendProbe.running) return
    probeOutput = ""
    backendProbe.running = true
  }

  property string probeOutput: ""

  Process {
    id: backendProbe
    command: ["which", "meshcore-cli"]
    stdout: SplitParser {
      onRead: data => root.probeOutput += data
    }
    onExited: function(exitCode) {
      root.backendAvailable = exitCode === 0 && root.probeOutput.trim() !== ""
      root.connectionState = root.backendAvailable ? "disconnected" : "unavailable"
      root.lastError = root.backendAvailable ? "" : "Install meshcore-cli to connect"
    }
  }

  Component.onCompleted: refresh()
}
