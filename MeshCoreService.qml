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
  property bool _sessionReady: false
  property bool _sessionStopping: false
  property bool _restartAfterStop: false
  property bool _snapshotPending: false
  property string _streamBuffer: ""
  property string _expectedDocument: ""

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
  readonly property string batteryText: companion ? Model.batteryLabel(companion.batteryMv) : ""
  readonly property string radioText: companion && companion.radio ? companion.radio.label : ""
  readonly property int unreadCount: Model.totalUnread(channels, nodes)
  readonly property bool busy: root._refreshPipeline || root._snapshotPending || backendProbe.running || companionProbe.running || dataProbe.running
  readonly property bool live: eventSession.running && root._sessionReady

  function refresh() {
    if (root.busy) return
    if (eventSession.running) {
      if (root._sessionReady) root.requestSnapshot()
      return
    }
    if (!root._probeComplete || !root.backendAvailable) {
      root.lastError = ""
      root.connectionState = "connecting"
      backendProbe.command = ["meshcore-cli", "-v"]
      backendProbe.running = true
      backendTimeout.restart()
      return
    }
    reconnectTimer.stop()
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

  function startEventSession() {
    if (eventSession.running) return
    root._sessionStopping = false
    root._sessionReady = false
    root._snapshotPending = false
    root._streamBuffer = ""
    root._expectedDocument = ""
    eventSession.command = ["meshcore-cli", "-j", "-c", "off", "-s", root.serialPort, "-i"]
    eventSession.running = true
    sessionStartTimeout.restart()
  }

  function requestSnapshot() {
    if (!eventSession.running || !root._sessionReady || root._snapshotPending) return
    root._snapshotPending = true
    snapshotTimeout.restart()
    eventSession.write("echo __OMAMESH_CONTACTS__\n")
    eventSession.write("contacts\n")
    eventSession.write("echo __OMAMESH_CHANNELS__\n")
    eventSession.write("get_channels\n")
    eventSession.write("echo __OMAMESH_BATTERY__\n")
    eventSession.write("get bat\n")
    eventSession.write("echo __OMAMESH_RADIO__\n")
    eventSession.write("get radio\n")
  }

  function scheduleSnapshot() {
    if (!snapshotDebounce.running) snapshotDebounce.restart()
  }

  function ingestMessage(value) {
    var message = Model.normalizeIncomingMessage(value)
    if (message === null) return
    var nextMessages = Model.appendUniqueMessage(root.messages, message, 500)
    if (nextMessages.length === root.messages.length) return
    root.messages = nextMessages
    if (message.kind === "direct")
      root.nodes = Model.incrementUnread(root.nodes, "keyPrefix", message.contactKeyPrefix)
    else
      root.channels = Model.incrementUnread(root.channels, "index", message.channelIndex)
  }

  function markConversationRead(conversationId) {
    var id = String(conversationId || "")
    if (id.indexOf("contact:") === 0)
      root.nodes = Model.clearUnread(root.nodes, "keyPrefix", id.substring(8))
    else if (id.indexOf("channel:") === 0)
      root.channels = Model.clearUnread(root.channels, "index", id.substring(8))
  }

  function handleStreamDocument(value) {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      if (value.event === "advert" || value.event === "new_contact" || value.event === "path_update") {
        root.scheduleSnapshot()
        return
      }
      if (value.type === "PRIV" || value.type === "CHAN") {
        root.ingestMessage(value)
        return
      }
      if (value.cmd !== undefined) return
    }
    if (Array.isArray(value) && root._expectedDocument === "") {
      for (var i = 0; i < value.length; i++) root.ingestMessage(value[i])
      return
    }
    if (root._expectedDocument === "contacts") {
      var contacts = Model.parseContacts(JSON.stringify(value))
      if (contacts.ok) root.nodes = Model.preserveUnread(contacts.items, root.nodes, "keyPrefix")
      root._expectedDocument = ""
      return
    }
    if (root._expectedDocument === "channels") {
      var channelResult = Model.parseChannels(JSON.stringify(value))
      if (channelResult.ok) root.channels = Model.preserveUnread(channelResult.items, root.channels, "index")
      root._expectedDocument = ""
      return
    }
    if (root._expectedDocument === "battery") {
      var batteryMv = Model.parseBattery(value)
      if (batteryMv !== null && root.companion)
        root.companion = { name: root.companion.name, batteryMv: batteryMv, radio: root.companion.radio || null }
      root._expectedDocument = ""
      return
    }
    if (root._expectedDocument === "radio") {
      var radio = Model.parseRadio(value)
      if (radio !== null && root.companion)
        root.companion = { name: root.companion.name, batteryMv: root.companion.batteryMv || 0, radio: radio }
      root._expectedDocument = ""
      root._snapshotPending = false
      snapshotTimeout.stop()
    }
  }

  function handleStreamLine(line) {
    var text = String(line || "")
    if (text.indexOf("__OMAMESH_READY__") !== -1) {
      root._sessionReady = true
      root.lastError = ""
      root.connectionState = "connected"
      sessionStartTimeout.stop()
      Qt.callLater(root.requestSnapshot)
    }
    if (text.indexOf("__OMAMESH_CONTACTS__") !== -1)
      root._expectedDocument = "contacts"
    if (text.indexOf("__OMAMESH_CHANNELS__") !== -1)
      root._expectedDocument = "channels"
    if (text.indexOf("__OMAMESH_BATTERY__") !== -1)
      root._expectedDocument = "battery"
    if (text.indexOf("__OMAMESH_RADIO__") !== -1)
      root._expectedDocument = "radio"

    root._streamBuffer += text + "\n"
    if (root._streamBuffer.length > 262144) root._streamBuffer = ""
    var parsed = Model.extractJsonDocuments(root._streamBuffer)
    root._streamBuffer = parsed.remainder
    for (var i = 0; i < parsed.documents.length; i++)
      root.handleStreamDocument(parsed.documents[i])
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
      Qt.callLater(root.startEventSession)
    }
  }

  Process {
    id: eventSession
    command: []
    stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.handleStreamLine(line) } }
    stderr: StdioCollector { waitForEnd: true }
    onStarted: {
      write("set print_adverts on\n")
      write("set print_new_contacts on\n")
      write("set print_path_updates on\n")
      write("msgs_subscribe\n")
      write("echo __OMAMESH_READY__\n")
    }
    onExited: function(exitCode) {
      sessionStartTimeout.stop()
      root._sessionReady = false
      root._snapshotPending = false
      root._expectedDocument = ""
      root._streamBuffer = ""
      snapshotTimeout.stop()
      if (root._sessionStopping) {
        root._sessionStopping = false
        if (root._restartAfterStop) {
          root._restartAfterStop = false
          Qt.callLater(root.connectUsb)
        }
        return
      }
      root.connectionState = "error"
      root.lastError = "USB companion connection was lost"
      reconnectTimer.restart()
    }
  }

  Timer {
    id: sessionStartTimeout
    interval: root.commandTimeoutSec * 1000
    repeat: false
    onTriggered: {
      if (root._sessionReady) return
      root._sessionStopping = true
      if (eventSession.running) eventSession.running = false
      root.connectionState = "error"
      root.lastError = "The USB companion event session did not start"
      reconnectTimer.restart()
    }
  }

  Timer {
    id: snapshotDebounce
    interval: 350
    repeat: false
    onTriggered: root.requestSnapshot()
  }

  Timer {
    id: snapshotTimeout
    interval: root.commandTimeoutSec * 1000
    repeat: false
    onTriggered: {
      root._snapshotPending = false
      root._expectedDocument = ""
      root._streamBuffer = ""
      root.lastError = "Could not refresh companion data"
    }
  }

  Timer {
    id: reconnectTimer
    interval: 5000
    repeat: false
    onTriggered: {
      root._sessionStopping = false
      root.startEventSession()
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

  onSerialPortChanged: {
    reconnectTimer.stop()
    if (eventSession.running) {
      root._sessionStopping = true
      root._restartAfterStop = true
      eventSession.running = false
    } else if (root._probeComplete) Qt.callLater(root.connectUsb)
  }
  Component.onCompleted: refresh()
  Component.onDestruction: {
    backendTimeout.stop()
    commandTimeout.stop()
    sessionStartTimeout.stop()
    snapshotDebounce.stop()
    snapshotTimeout.stop()
    reconnectTimer.stop()
    root._sessionStopping = true
    if (backendProbe.running) backendProbe.running = false
    if (companionProbe.running) companionProbe.running = false
    if (dataProbe.running) dataProbe.running = false
    if (eventSession.running) eventSession.running = false
  }
}
