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
  property bool _probeComplete: false
  property bool _timedOut: false
  property string _nameOutput: ""
  property string _nameError: ""
  property string _dataOutput: ""
  property string _dataError: ""
  property string _phase: ""
  property bool _refreshPipeline: false

  readonly property int refreshIntervalSec: Model.clampRefreshInterval(
    settings && settings.refreshIntervalSec !== undefined ? settings.refreshIntervalSec : 10
  )
  readonly property int commandTimeoutSec: Model.clampCommandTimeout(
    settings && settings.commandTimeoutSec !== undefined ? settings.commandTimeoutSec : 12
  )
  readonly property string serialPort: Model.serialPort(
    settings && settings.serialPort !== undefined ? settings.serialPort : "/dev/ttyACM0"
  )
  readonly property string statusText: Model.connectionLabel(connectionState)
  readonly property int unreadCount: Model.totalUnread(channels)
  readonly property bool busy: root._refreshPipeline || backendProbe.running || companionProbe.running || dataProbe.running

  function refresh() {
    if (root.busy) return
    if (!root._probeComplete || !root.backendAvailable) {
      root.lastError = ""
      root.connectionState = "connecting"
      backendProbe.command = ["meshcore-cli", "-v"]
      backendProbe.running = true
      backendTimeout.restart()
      return
    }
    root.connectUsb()
  }

  function connectUsb() {
    if (root.busy) return
    root._timedOut = false
    root._refreshPipeline = true
    root._nameOutput = ""
    root._nameError = ""
    root.transport = "serial"
    root.lastError = ""
    root.connectionState = "connecting"
    companionProbe.command = ["meshcore-cli", "-j", "-s", root.serialPort, "get", "name"]
    companionProbe.running = true
    commandTimeout.restart()
  }

  function disconnectState(message) {
    root._refreshPipeline = false
    root.companion = null
    root.nodes = []
    root.channels = []
    root.messages = []
    root.lastError = message
    root.connectionState = "error"
  }

  function runDataPhase(phase) {
    root._phase = phase
    root._dataOutput = ""
    root._dataError = ""
    dataProbe.command = phase === "contacts"
      ? ["meshcore-cli", "-j", "-s", root.serialPort, "contacts"]
      : ["meshcore-cli", "-j", "-s", root.serialPort, "get_channels"]
    dataProbe.running = true
    commandTimeout.restart()
  }

  Process {
    id: backendProbe
    command: []
    onExited: function(exitCode) {
      backendTimeout.stop()
      root._probeComplete = true
      root.backendAvailable = exitCode === 0
      if (!root.backendAvailable) {
        root.transport = ""
        root.companion = null
        root.lastError = "Install meshcore-cli to connect"
        root.connectionState = "unavailable"
        return
      }
      root.lastError = ""
      Qt.callLater(root.connectUsb)
    }
  }

  Timer {
    id: backendTimeout
    interval: 3000
    repeat: false
    onTriggered: {
      if (root._probeComplete) return
      if (backendProbe.running) backendProbe.running = false
      root._probeComplete = true
      root.backendAvailable = false
      root.transport = ""
      root.companion = null
      root.lastError = "Install meshcore-cli to connect"
      root.connectionState = "unavailable"
    }
  }

  Process {
    id: companionProbe
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._nameOutput = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._nameError = String(text || "")
    }
    onExited: function(exitCode) {
      commandTimeout.stop()
      if (root._timedOut) {
        root.disconnectState(Model.safeCliError("", true))
        return
      }
      var parsed = Model.parseCompanionName(root._nameOutput)
      if (exitCode === 0 && parsed.ok) {
        root.companion = { name: parsed.name }
        root.lastError = ""
        root.connectionState = "connected"
        Qt.callLater(function() { root.runDataPhase("contacts") })
        return
      }
      root.disconnectState(root._nameError.trim() !== ""
        ? Model.safeCliError(root._nameError, false)
        : "meshcore-cli returned invalid companion data")
    }
  }


  Process {
    id: dataProbe
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._dataOutput = String(text || "")
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._dataError = String(text || "")
    }
    onExited: function(exitCode) {
      commandTimeout.stop()
      if (root._timedOut) {
        root._refreshPipeline = false
        root.lastError = Model.safeCliError("", true)
        return
      }
      if (root._phase === "contacts") {
        var contacts = Model.parseContacts(root._dataOutput)
        if (exitCode === 0 && contacts.ok) root.nodes = contacts.items
        Qt.callLater(function() { root.runDataPhase("channels") })
        return
      }
      var channelResult = Model.parseChannels(root._dataOutput)
      if (exitCode === 0 && channelResult.ok) root.channels = channelResult.items
      if (!(exitCode === 0 && channelResult.ok))
        root.lastError = root._dataError.trim() !== "" ? Model.safeCliError(root._dataError, false) : "Could not refresh MeshCore data"
      root._refreshPipeline = false
    }
  }

  Timer {
    id: commandTimeout
    interval: root.commandTimeoutSec * 1000
    repeat: false
    onTriggered: {
      if (!companionProbe.running && !dataProbe.running) return
      root._timedOut = true
      root._refreshPipeline = false
      if (companionProbe.running) companionProbe.running = false
      if (dataProbe.running) dataProbe.running = false
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  onSerialPortChanged: if (root._probeComplete) Qt.callLater(root.refresh)
  Component.onCompleted: refresh()
  Component.onDestruction: {
    backendTimeout.stop()
    commandTimeout.stop()
    if (backendProbe.running) backendProbe.running = false
    if (companionProbe.running) companionProbe.running = false
    if (dataProbe.running) dataProbe.running = false
  }
}
