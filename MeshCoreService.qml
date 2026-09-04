import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool backendAvailable: false
  property string connectionState: "unavailable"
  readonly property string transport: Model.transport(
    settings && settings.transport !== undefined ? settings.transport : "USB"
  )
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
  property int _sendCounter: 0
  property bool _sendCapturing: false
  property var _sendDocuments: []
  property bool _sendSawError: false
  property var _sendTransaction: null
  property bool sending: false
  property string sendState: "idle"
  property string sendError: ""
  property int _managementCounter: 0
  property bool _managementCapturing: false
  property bool _managementSawError: false
  property bool _managementAwaitingSnapshot: false
  property var _managementTransaction: null
  property bool managing: false
  property string managementState: "idle"
  property string managementError: ""

  readonly property int refreshIntervalSec: Model.clampRefreshInterval(
    settings && settings.refreshIntervalSec !== undefined ? settings.refreshIntervalSec : 10
  )
  readonly property int commandTimeoutSec: Model.clampCommandTimeout(
    settings && settings.commandTimeoutSec !== undefined ? settings.commandTimeoutSec : 12
  )
  readonly property string serialPort: Model.serialPort(
    settings && settings.serialPort !== undefined ? settings.serialPort : "/dev/ttyACM0"
  )
  readonly property string tcpHost: Model.tcpHost(
    settings && settings.tcpHost !== undefined ? settings.tcpHost : "127.0.0.1"
  )
  readonly property int tcpPort: Model.tcpPort(
    settings && settings.tcpPort !== undefined ? settings.tcpPort : 5000
  )
  readonly property string bleTarget: Model.bleTarget(
    settings && settings.bleTarget !== undefined ? settings.bleTarget : ""
  )
  readonly property bool blePair: settings && settings.blePair === true
  readonly property var connectionArgs: Model.connectionArguments(transport, {
    serialPort: serialPort,
    tcpHost: tcpHost,
    tcpPort: tcpPort,
    bleTarget: bleTarget,
    blePair: blePair
  })
  readonly property string statusText: Model.connectionLabel(connectionState)
  readonly property string transportText: transport === "tcp" ? "TCP" : (transport === "ble" ? "BLE" : "USB")
  readonly property string batteryText: companion ? Model.batteryLabel(companion.batteryMv) : ""
  readonly property string radioText: companion && companion.radio ? companion.radio.label : ""
  readonly property int unreadCount: Model.totalUnread(channels, nodes)
  readonly property bool busy: root._refreshPipeline || root._snapshotPending || root.sending || root.managing || backendProbe.running || companionProbe.running || dataProbe.running
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
    root.connectCompanion()
  }

  function connectCompanion() {
    if (root.busy) return
    if (root.transport === "ble" && root.connectionArgs.length === 0) {
      root.disconnectState("Configure a BLE companion address or name")
      return
    }
    root._timedOut = false
    root._refreshPipeline = true
    root._nameOutput = ""
    root._nameError = ""
    root.lastError = ""
    root.connectionState = "connecting"
    companionProbe.command = ["meshcore-cli", "-j"].concat(root.connectionArgs).concat(["get", "name"])
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
    eventSession.command = ["meshcore-cli", "-j", "-c", "off"].concat(root.connectionArgs).concat(["-i"])
    eventSession.running = true
    sessionStartTimeout.restart()
  }

  function requestSnapshot(force) {
    if (!eventSession.running || !root._sessionReady || root._snapshotPending) return
    if (!force && (root.sending || root.managing)) return
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
    message = Model.resolveMessageSender(message, root.nodes)
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

  function sendMessage(conversationId, body) {
    var built = Model.buildSendCommand(conversationId, body, root.companion ? root.companion.name : "")
    if (!built.ok) {
      root.sendState = "failed"
      root.sendError = built.error
      return false
    }
    if (!root.live || root.sending) {
      root.sendState = "failed"
      root.sendError = root.sending ? "Another message is still sending" : "The companion is not connected"
      return false
    }

    root._sendCounter += 1
    root._sendTransaction = {
      id: root._sendCounter,
      conversationId: String(conversationId),
      body: String(body),
      kind: built.kind,
      timestamp: Math.floor(Date.now() / 1000)
    }
    root._sendDocuments = []
    root._sendSawError = false
    root._sendCapturing = false
    root.sending = true
    root.sendState = "sending"
    root.sendError = ""
    sendTimeout.restart()

    eventSession.write("echo __OMAMESH_SEND_START_" + root._sendCounter + "__\n")
    eventSession.write(built.command + "\n")
    if (built.kind === "direct") eventSession.write("wait_ack\n")
    eventSession.write("echo __OMAMESH_SEND_END_" + root._sendCounter + "__\n")
    return true
  }

  function finishSend() {
    if (!root.sending || root._sendTransaction === null) return
    sendTimeout.stop()
    var transaction = root._sendTransaction
    var result = Model.parseSendResult(transaction.kind, root._sendDocuments, root._sendSawError)
    if (result.accepted) {
      root.messages = Model.appendUniqueMessage(
        root.messages,
        Model.outgoingMessage(transaction.conversationId, transaction.body,
                              transaction.timestamp, result.state, transaction.id),
        500
      )
    }
    root.sendState = result.state
    root.sendError = result.error
    root.sending = false
    root._sendCapturing = false
    root._sendDocuments = []
    root._sendSawError = false
    root._sendTransaction = null
    if (snapshotDebounce.running) snapshotDebounce.restart()
  }

  function failSend(message) {
    sendTimeout.stop()
    root.sendState = "failed"
    root.sendError = message
    root.sending = false
    root._sendCapturing = false
    root._sendDocuments = []
    root._sendSawError = false
    root._sendTransaction = null
  }

  function addChannel(name, secret) {
    var built = Model.buildAddChannelCommand(name, secret)
    if (!built.ok) {
      root.managementState = "failed"
      root.managementError = built.error
      return false
    }
    var wantedName = String(name || "").trim()
    for (var i = 0; i < root.channels.length; i++) {
      if (String(root.channels[i].name).toLowerCase() === wantedName.toLowerCase()) {
        root.managementState = "failed"
        root.managementError = "A channel with that name already exists"
        return false
      }
    }
    return root.startManagement(built.command, { kind: "add-channel", name: wantedName })
  }

  function resetManagementStatus() {
    if (root.managing) return
    root.managementState = "idle"
    root.managementError = ""
  }

  function removeChannel(index) {
    var built = Model.buildRemoveChannelCommand(index)
    if (!built.ok) {
      root.managementState = "failed"
      root.managementError = built.error
      return false
    }
    return root.startManagement(built.command, { kind: "remove-channel", index: Math.floor(Number(index)) })
  }

  function removeContact(keyPrefix) {
    var built = Model.buildRemoveContactCommand(keyPrefix)
    if (!built.ok) {
      root.managementState = "failed"
      root.managementError = built.error
      return false
    }
    return root.startManagement(built.command, {
      kind: "remove-contact",
      keyPrefix: String(keyPrefix).toLowerCase()
    })
  }

  function startManagement(command, transaction) {
    if (!root.live || root.managing || root.sending) {
      root.managementState = "failed"
      root.managementError = root.managing || root.sending
        ? "Another companion operation is still running"
        : "The companion is not connected"
      return false
    }
    root._managementCounter += 1
    transaction.id = root._managementCounter
    root._managementTransaction = transaction
    root._managementSawError = false
    root._managementCapturing = false
    root._managementAwaitingSnapshot = false
    root.managing = true
    root.managementState = "working"
    root.managementError = ""
    managementTimeout.restart()
    eventSession.write("echo __OMAMESH_MANAGE_START_" + transaction.id + "__\n")
    eventSession.write(command + "\n")
    eventSession.write("echo __OMAMESH_MANAGE_END_" + transaction.id + "__\n")
    return true
  }

  function verifyManagementSnapshot(phase) {
    if (!root.managing || !root._managementAwaitingSnapshot
        || root._managementTransaction === null) return
    var transaction = root._managementTransaction
    if (transaction.kind === "remove-contact" && phase !== "contacts") return
    if (transaction.kind !== "remove-contact" && phase !== "channels") return
    var matched = false
    var source = transaction.kind === "remove-contact" ? root.nodes : root.channels
    for (var i = 0; i < source.length; i++) {
      if (transaction.kind === "add-channel"
          && String(source[i].name).toLowerCase() === String(transaction.name).toLowerCase())
        matched = true
      if (transaction.kind === "remove-channel"
          && Number(source[i].index) === Number(transaction.index))
        matched = true
      if (transaction.kind === "remove-contact"
          && String(source[i].keyPrefix) === String(transaction.keyPrefix))
        matched = true
    }
    var succeeded = transaction.kind === "add-channel" ? matched : !matched
    if (succeeded) root.finishManagement()
    else root.failManagement("The companion did not apply the requested change")
  }

  function finishManagement() {
    managementTimeout.stop()
    root.managementState = "succeeded"
    root.managementError = ""
    root.managing = false
    root._managementCapturing = false
    root._managementSawError = false
    root._managementAwaitingSnapshot = false
    root._managementTransaction = null
  }

  function failManagement(message) {
    managementTimeout.stop()
    root.managementState = "failed"
    root.managementError = message
    root.managing = false
    root._managementCapturing = false
    root._managementSawError = false
    root._managementAwaitingSnapshot = false
    root._managementTransaction = null
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
    if (root._sendCapturing) {
      root._sendDocuments = root._sendDocuments.concat([value])
      return
    }
    if (root._managementCapturing) return
    if (Array.isArray(value) && root._expectedDocument === "") {
      for (var i = 0; i < value.length; i++) root.ingestMessage(value[i])
      return
    }
    if (root._expectedDocument === "contacts") {
      var contacts = Model.parseContacts(JSON.stringify(value))
      if (contacts.ok) {
        root.nodes = Model.preserveUnread(contacts.items, root.nodes, "keyPrefix")
        root.messages = Model.resolveMessageSenders(root.messages, root.nodes)
      }
      root._expectedDocument = ""
      if (contacts.ok) root.verifyManagementSnapshot("contacts")
      return
    }
    if (root._expectedDocument === "channels") {
      var channelResult = Model.parseChannels(JSON.stringify(value))
      if (channelResult.ok) root.channels = Model.preserveUnread(channelResult.items, root.channels, "index")
      root._expectedDocument = ""
      if (channelResult.ok) root.verifyManagementSnapshot("channels")
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
    if (root.managing && root._managementTransaction !== null) {
      var managementId = root._managementTransaction.id
      if (text.indexOf("__OMAMESH_MANAGE_START_" + managementId + "__") !== -1) {
        root._managementCapturing = true
        root._streamBuffer = ""
        return
      }
      if (text.indexOf("__OMAMESH_MANAGE_END_" + managementId + "__") !== -1) {
        root._managementCapturing = false
        if (root._managementSawError) {
          root.failManagement("meshcore-cli could not apply the requested change")
        } else {
          root._managementAwaitingSnapshot = true
          Qt.callLater(function() { root.requestSnapshot(true) })
        }
        return
      }
      if (root._managementCapturing
          && /^(?:[^>\n]{0,96}>\s*)?(?:Error adding channel|Error deleting channel|Error setting channel|Error removing contact)/i.test(text))
        root._managementSawError = true
    }
    if (root.sending && root._sendTransaction !== null) {
      var sendId = root._sendTransaction.id
      if (text.indexOf("__OMAMESH_SEND_START_" + sendId + "__") !== -1) {
        root._sendCapturing = true
        root._streamBuffer = ""
        return
      }
      if (text.indexOf("__OMAMESH_SEND_END_" + sendId + "__") !== -1) {
        root.finishSend()
        return
      }
      if (root._sendCapturing
          && /^(?:[^>\n]{0,96}>\s*)?(?:Error sending message:|Unknown destination |Timeout waiting ack)/i.test(text))
        root._sendSawError = true
    }
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
      ? ["meshcore-cli", "-j"].concat(root.connectionArgs).concat(["contacts"])
      : ["meshcore-cli", "-j"].concat(root.connectionArgs).concat(["get_channels"])
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
        root.companion = null
        root.lastError = "Install meshcore-cli to connect"
        root.connectionState = "unavailable"
        return
      }
      root.lastError = ""
      Qt.callLater(root.connectCompanion)
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
        root.disconnectState(Model.safeCliError("", true, root.transport))
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
        ? Model.safeCliError(root._nameError, false, root.transport)
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
        root.lastError = Model.safeCliError("", true, root.transport)
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
        root.lastError = root._dataError.trim() !== "" ? Model.safeCliError(root._dataError, false, root.transport) : "Could not refresh MeshCore data"
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
      if (root.sending) root.failSend("The companion connection was lost while sending")
      if (root.managing) root.failManagement("The companion connection was lost while applying the change")
      if (root._sessionStopping) {
        root._sessionStopping = false
        if (root._restartAfterStop) {
          root._restartAfterStop = false
          Qt.callLater(root.connectCompanion)
        }
        return
      }
      root.connectionState = "error"
      root.lastError = root.transportText + " companion connection was lost"
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
      root.lastError = "The " + root.transportText + " companion event session did not start"
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
    id: sendTimeout
    interval: Math.max(8000, root.commandTimeoutSec * 1000)
    repeat: false
    onTriggered: root.failSend("The message operation timed out")
  }

  Timer {
    id: managementTimeout
    interval: Math.max(10000, root.commandTimeoutSec * 1000)
    repeat: false
    onTriggered: root.failManagement("The management operation timed out")
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

  function restartForSettingsChange() {
    reconnectTimer.stop()
    if (eventSession.running) {
      root._sessionStopping = true
      root._restartAfterStop = true
      eventSession.running = false
    } else if (root._probeComplete) Qt.callLater(root.connectCompanion)
  }
  onTransportChanged: root.restartForSettingsChange()
  onSerialPortChanged: if (root.transport === "serial") root.restartForSettingsChange()
  onTcpHostChanged: if (root.transport === "tcp") root.restartForSettingsChange()
  onTcpPortChanged: if (root.transport === "tcp") root.restartForSettingsChange()
  onBleTargetChanged: if (root.transport === "ble") root.restartForSettingsChange()
  onBlePairChanged: if (root.transport === "ble") root.restartForSettingsChange()
  Component.onCompleted: refresh()
  Component.onDestruction: {
    backendTimeout.stop()
    commandTimeout.stop()
    sessionStartTimeout.stop()
    snapshotDebounce.stop()
    snapshotTimeout.stop()
    sendTimeout.stop()
    managementTimeout.stop()
    reconnectTimer.stop()
    root._sessionStopping = true
    if (backendProbe.running) backendProbe.running = false
    if (companionProbe.running) companionProbe.running = false
    if (dataProbe.running) dataProbe.running = false
    if (eventSession.running) eventSession.running = false
  }
}
