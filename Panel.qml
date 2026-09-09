import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "." 1.0
import "Model.js" as Model

Panel {
  id: root
  moduleName: "clartek.omamesh"
  ipcTarget: "clartek.omamesh"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property int selectedTab: 0
  property string conversationId: ""
  property string conversationTitle: ""
  property var detailNode: null
  property string searchQuery: ""
  property string draftMessage: ""
  property int contactTypeFilter: -1
  property string managementView: ""
  property var managedChannel: null
  property string newChannelName: ""
  property string newChannelSecret: ""
  property bool confirmRemoval: false
  property double mapCenterLat: 41.2565
  property double mapCenterLon: -95.9345
  property int mapZoom: 12
  property bool mapUserPanned: false
  property string editTransport: "USB"
  property string editTcpHost: "127.0.0.1"
  property string editTcpPort: "5000"
  property string lastConfiguredTcpHost: ""
  property string lastConfiguredTcpPort: ""
  property string editSerialPort: "/dev/ttyACM0"
  property string editBleTarget: ""
  property bool editBlePair: false

  onSettingsChanged: {
    if (root.settings) {
      if (root.settings.tcpHost && root.settings.tcpHost !== "127.0.0.1") {
        root.lastConfiguredTcpHost = root.settings.tcpHost
      }
      if (root.settings.tcpPort) {
        root.lastConfiguredTcpPort = String(root.settings.tcpPort)
      }
    }
  }

  Component.onCompleted: {
    if (root.settings) {
      if (root.settings.tcpHost && root.settings.tcpHost !== "127.0.0.1") {
        root.lastConfiguredTcpHost = root.settings.tcpHost
      }
      if (root.settings.tcpPort) {
        root.lastConfiguredTcpPort = String(root.settings.tcpPort)
      }
    }
    root.initConnectionEditor()
  }
  property bool mapTilesActive: root.settings && root.settings.enableMapTiles !== undefined ? root.settings.enableMapTiles : true
  readonly property string mapTileProvider: root.settings && root.settings.mapTileProvider ? root.settings.mapTileProvider : "carto-dark"
  readonly property var mapLocatedNodes: Model.filterContacts(meshcore.nodes, "").filter(function(n) { return n && n.hasLocation })
  readonly property var mapProjectedNodes: Model.projectMapNodes(
    meshcore.nodes,
    root.mapCenterLat,
    root.mapCenterLon,
    root.mapZoom,
    coordinateMap ? coordinateMap.width : 400,
    coordinateMap ? coordinateMap.height : 350
  )
  readonly property var mapTiles: root.mapTilesActive && root.selectedTab === 2
    ? Model.calculateTileGrid(
        root.mapCenterLat,
        root.mapCenterLon,
        root.mapZoom,
        coordinateMap ? coordinateMap.width : 400,
        coordinateMap ? coordinateMap.height : 350,
        root.mapTileProvider
      )
    : []
  readonly property bool hasSubview: root.conversationId !== "" || root.detailNode !== null || root.managementView !== ""
  readonly property var conversationMessages: Model.messagesForConversation(meshcore.messages, conversationId)
  readonly property var filteredNodes: Model.filterContacts(meshcore.nodes, searchQuery, contactTypeFilter)
  readonly property var filteredChannels: Model.filterByText(meshcore.channels, searchQuery)
  readonly property var mappedNodes: Model.mapPoints(meshcore.nodes)
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string connectionState: meshcore.connectionState
  readonly property int unreadCount: meshcore.unreadCount
  readonly property bool backendAvailable: meshcore.backendAvailable

  function open() { meshcore.refresh(); root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function closeForPopoutSwitch() { root.close() }
  function refresh() { meshcore.refresh() }
  function selectTab(index) {
    root.selectedTab = Math.max(0, Math.min(2, index))
    if (root.selectedTab === 2 && !root.mapUserPanned) root.recenterMap()
  }
  function recenterMap() {
    var bounds = Model.calculateMapBounds(
      meshcore.nodes,
      coordinateMap ? coordinateMap.width : 400,
      coordinateMap ? coordinateMap.height : 350
    )
    root.mapCenterLat = bounds.centerLat
    root.mapCenterLon = bounds.centerLon
    root.mapZoom = bounds.zoom
    root.mapUserPanned = false
  }
  function zoomMap(delta) {
    var nextZoom = Math.max(3, Math.min(18, root.mapZoom + delta))
    if (nextZoom !== root.mapZoom) {
      root.mapZoom = nextZoom
      root.mapUserPanned = true
    }
  }
  function panMap(deltaPixelX, deltaPixelY) {
    if (deltaPixelX === 0 && deltaPixelY === 0) return
    var centerPt = Model.latLonToWorld(root.mapCenterLat, root.mapCenterLon, root.mapZoom)
    var newCoords = Model.worldToLatLon(centerPt.x - deltaPixelX, centerPt.y - deltaPixelY, root.mapZoom)
    root.mapCenterLat = newCoords.latitude
    root.mapCenterLon = newCoords.longitude
    root.mapUserPanned = true
  }
  function toggleMapTiles() {
    root.mapTilesActive = !root.mapTilesActive
  }
  function openConversation(id, title) {
    root.detailNode = null
    root.managementView = ""
    root.managedChannel = null
    root.conversationId = String(id || "")
    root.conversationTitle = String(title || "Conversation")
    root.draftMessage = ""
    meshcore.markConversationRead(root.conversationId)
  }
  function openNode(item) {
    if (Number(item.type) === 1) root.openConversation("contact:" + item.keyPrefix, item.name)
    else root.openNodeDetails(item)
  }
  function openNodeDetails(item) {
    root.conversationId = ""
    root.managementView = ""
    root.detailNode = item
    root.confirmRemoval = false
    meshcore.resetManagementStatus()
  }
  function openAddChannel() {
    root.conversationId = ""
    root.detailNode = null
    root.managedChannel = null
    root.managementView = "add-channel"
    root.newChannelName = ""
    root.newChannelSecret = ""
    meshcore.resetManagementStatus()
  }
  function initConnectionEditor() {
    var curTransport = meshcore.transport
    root.editTransport = curTransport === "tcp" ? "TCP" : (curTransport === "ble" ? "BLE" : "USB")
    var rememberedHost = (root.settings && root.settings.tcpHost && root.settings.tcpHost !== "127.0.0.1")
      ? root.settings.tcpHost
      : (root.lastConfiguredTcpHost || (meshcore.tcpHost && meshcore.tcpHost !== "127.0.0.1" ? meshcore.tcpHost : (root.editTcpHost || "127.0.0.1")))
    root.editTcpHost = rememberedHost
    root.lastConfiguredTcpHost = rememberedHost

    var rememberedPort = (root.settings && root.settings.tcpPort)
      ? String(root.settings.tcpPort)
      : (root.lastConfiguredTcpPort || String(meshcore.tcpPort || root.editTcpPort || 5000))
    root.editTcpPort = rememberedPort
    root.lastConfiguredTcpPort = rememberedPort

    root.editSerialPort = meshcore.serialPort || (root.settings && root.settings.serialPort ? root.settings.serialPort : "/dev/ttyACM0")
    root.editBleTarget = meshcore.bleTarget || (root.settings && root.settings.bleTarget ? root.settings.bleTarget : "")
    root.editBlePair = meshcore.blePair || (root.settings && root.settings.blePair === true)
  }
  function saveSettings(updated) {
    var entry = { id: root.moduleName }
    if (root.settings) {
      for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    }
    for (var k in updated) entry[k] = updated[k]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }
  function applyConnectionSettings() {
    var rawHost = root.editTcpHost.trim()
    var rawPort = root.editTcpPort.trim()
    var parsed = Model.normalizeTcpEndpoint(rawHost, rawPort)
    root.editTcpHost = parsed.host
    root.editTcpPort = String(parsed.port)
    root.lastConfiguredTcpHost = parsed.host
    root.lastConfiguredTcpPort = String(parsed.port)

    var updated = {
      transport: root.editTransport,
      serialPort: Model.serialPort(root.editSerialPort.trim()),
      tcpHost: parsed.host,
      tcpPort: parsed.port,
      bleTarget: Model.bleTarget(root.editBleTarget.trim()),
      blePair: root.editBlePair
    }

    root.saveSettings(updated)
    meshcore.restartForSettingsChange()
  }
  function openConnectionDetails() {
    root.conversationId = ""
    root.detailNode = null
    root.managedChannel = null
    root.managementView = "connection"
    root.confirmRemoval = false
    root.initConnectionEditor()
  }
  function openChannelManagement(item) {
    root.conversationId = ""
    root.detailNode = null
    root.managedChannel = item
    root.managementView = "channel"
    root.confirmRemoval = false
    meshcore.resetManagementStatus()
  }
  function leaveSubview() {
    root.conversationId = ""
    root.conversationTitle = ""
    root.detailNode = null
    root.managementView = ""
    root.managedChannel = null
    root.newChannelSecret = ""
    root.confirmRemoval = false
  }
  function createChannel() {
    var secret = root.newChannelSecret
    root.newChannelSecret = ""
    meshcore.addChannel(root.newChannelName, secret)
  }
  function confirmChannelRemoval() {
    if (!root.confirmRemoval) {
      root.confirmRemoval = true
      return
    }
    if (root.managedChannel) meshcore.removeChannel(root.managedChannel.index)
  }
  function confirmContactRemoval() {
    if (!root.confirmRemoval) {
      root.confirmRemoval = true
      return
    }
    if (root.detailNode) meshcore.removeContact(root.detailNode.keyPrefix)
  }
  function sendDraft() {
    if (meshcore.sendMessage(root.conversationId, root.draftMessage))
      root.draftMessage = ""
  }
  function cycleContactFilter() {
    var values = [-1, 1, 2, 3, 4]
    var index = values.indexOf(root.contactTypeFilter)
    root.contactTypeFilter = values[(index + 1) % values.length]
  }
  function contactFilterLabel() {
    if (root.contactTypeFilter === 1) return "Direct"
    if (root.contactTypeFilter === 2) return "Repeaters"
    if (root.contactTypeFilter === 3) return "Rooms"
    if (root.contactTypeFilter === 4) return "Sensors"
    return "All"
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  MeshCoreService { id: meshcore; settings: root.settings }
  Connections {
    target: meshcore
    function onManagingChanged() {
      if (!meshcore.managing && meshcore.managementState === "succeeded")
        root.leaveSubview()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(Style.space(580))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onReturnRequested: if (!root.hasSubview) meshcore.refresh()
      onCloseRequested: root.hasSubview ? root.leaveSubview() : root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") meshcore.refresh()
        else if (text === "c" || text === "C") {
          if (root.selectedTab === 2) root.recenterMap()
          else root.openConnectionDetails()
        }
        else if (text === "h" || text === "H") root.selectTab(root.selectedTab - 1)
        else if (text === "l" || text === "L") root.selectTab(root.selectedTab + 1)
        else if (text === "1") root.selectTab(0)
        else if (text === "2") root.selectTab(1)
        else if (text === "3") root.selectTab(2)
        else if (text === "+" || text === "=") { if (root.selectedTab === 2) root.zoomMap(1) }
        else if (text === "-" || text === "_") { if (root.selectedTab === 2) root.zoomMap(-1) }
        else if (text === "0") { if (root.selectedTab === 2) root.recenterMap() }
        else if (text === "t" || text === "T") { if (root.selectedTab === 2) root.toggleMapTiles() }
        else if (text === "/" && !root.hasSubview && root.selectedTab < 2) searchField.forceActiveFocus()
      }

      Column {
        anchors.fill: parent
        spacing: Style.space(10)

        Row {
          width: parent.width; height: Style.space(46); spacing: Style.space(10)
          Rectangle {
            width: Style.space(38); height: width; radius: width / 2
            color: Style.hoverFillFor(root.foreground, Color.accent)
            anchors.verticalCenter: parent.verticalCenter
            MeshCoreIcon {
              anchors.centerIn: parent
              iconSize: Style.space(20)
              color: root.foreground
            }
          }
          Item {
            width: parent.width - refreshButton.width - connectionButton.width - Style.space(68)
            height: headCol.implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            Column {
              id: headCol
              width: parent.width
              spacing: Style.space(2)
              Text { width: parent.width; textFormat: Text.PlainText; text: meshcore.companion ? meshcore.companion.name : "Omamesh"; color: root.foreground; elide: Text.ElideRight; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
              Text {
                width: parent.width; textFormat: Text.PlainText
                text: meshcore.connectionState === "connected"
                  ? (meshcore.batteryText ? meshcore.batteryText + "  ·  " : "") + meshcore.transportText + " connected  ·  " + meshcore.nodes.length + (meshcore.nodes.length === 1 ? " contact" : " contacts")
                  : (meshcore.lastError || meshcore.statusText)
                color: meshcore.connectionState === "error" ? root.urgent : root.dim
                elide: Text.ElideRight; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.managementView === "connection") root.leaveSubview()
                else root.openConnectionDetails()
              }
            }
          }
          Rectangle {
            id: connectionButton
            width: Style.space(34); height: width; radius: Style.cornerRadius
            color: root.managementView === "connection" || connectionArea.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent; text: "󰒋"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon
            }
            MouseArea {
              id: connectionArea
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.managementView === "connection") root.leaveSubview()
                else root.openConnectionDetails()
              }
            }
          }
          Rectangle {
            id: refreshButton
            width: Style.space(34); height: width; radius: Style.cornerRadius
            color: refreshArea.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent; text: "󰑐"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon
              RotationAnimator on rotation { running: meshcore.busy; from: 0; to: 360; duration: 850; loops: Animation.Infinite }
            }
            MouseArea { id: refreshArea; anchors.fill: parent; enabled: !meshcore.busy; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: meshcore.refresh() }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Style.hoverFillFor(root.foreground, Color.accent) }

        Row {
          width: parent.width
          visible: !root.hasSubview && root.selectedTab < 2 && meshcore.connectionState === "connected"
          height: Style.space(40)
          spacing: Style.space(6)

          TextField {
            id: searchField
            width: parent.width
              - (contactFilterButton.visible ? contactFilterButton.width + parent.spacing : 0)
              - (addChannelButton.visible ? addChannelButton.width + parent.spacing : 0)
            height: parent.height
            placeholderText: root.selectedTab === 0 ? "Search contacts…" : "Search channels…"
            text: root.searchQuery
            foreground: root.foreground
            accent: Color.accent
            onTextChanged: root.searchQuery = text
          }

          Rectangle {
            id: contactFilterButton
            visible: root.selectedTab === 0
            width: Style.space(94)
            height: parent.height
            radius: Style.cornerRadius
            color: root.contactTypeFilter !== -1 || contactFilterMouse.containsMouse
              ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
            border.width: 1
            border.color: Style.hoverFillFor(root.foreground, Color.accent)
            Row {
              anchors.centerIn: parent
              spacing: Style.space(5)
              Text { textFormat: Text.PlainText; text: "󰈲"; color: root.contactTypeFilter === -1 ? root.dim : Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
              Text { textFormat: Text.PlainText; text: root.contactFilterLabel(); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            }
            MouseArea {
              id: contactFilterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cycleContactFilter()
            }
          }

          Rectangle {
            id: addChannelButton
            visible: root.selectedTab === 1
            width: Style.space(40)
            height: parent.height
            radius: Style.cornerRadius
            color: addChannelMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
            border.width: 1
            border.color: Style.hoverFillFor(root.foreground, Color.accent)
            Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "+"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            MouseArea {
              id: addChannelMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openAddChannel()
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - Style.space(searchField.visible ? 156 : 116)
          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(32)
            visible: meshcore.connectionState !== "connected" && !root.hasSubview
            spacing: Style.space(10)
            Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "󰛳"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.space(40) }
            Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: meshcore.statusText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: meshcore.lastError || "Connect a companion radio or configure TCP/IP endpoint."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }

            Rectangle {
              height: Style.space(36)
              width: configConnBtnText.implicitWidth + Style.space(28)
              radius: Style.cornerRadius
              anchors.horizontalCenter: parent.horizontalCenter
              color: configConnMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              border.width: 1
              border.color: Color.accent

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  textFormat: Text.PlainText
                  text: "󰒋"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconSmall
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  id: configConnBtnText
                  textFormat: Text.PlainText
                  text: "Configure Connection"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: configConnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openConnectionDetails()
              }
            }
          }

          ListView {
            id: contactList
            anchors.fill: parent; visible: meshcore.connectionState === "connected" && !root.hasSubview && root.selectedTab === 0
            clip: true; model: root.filteredNodes; spacing: Style.space(3)
            header: Text { width: contactList.width; height: Style.space(32); textFormat: Text.PlainText; text: meshcore.nodes.length === 0 ? "Listening for nearby contacts…" : (root.filteredNodes.length === 0 ? "NO MATCHING CONTACTS" : (root.contactTypeFilter === -1 && meshcore.radioText ? "CONTACTS  ·  " + meshcore.radioText : root.contactFilterLabel().toUpperCase())); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1; elide: Text.ElideRight }
            delegate: Rectangle {
              required property var modelData
              width: contactList.width; height: Style.space(66); radius: Style.cornerRadius
              color: rowMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(11)
                Rectangle { width: Style.space(42); height: width; radius: width / 2; color: Color.accent; anchors.verticalCenter: parent.verticalCenter
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: modelData.icon; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column { width: parent.width - Style.space(118); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(3)
                  Text { width: parent.width; text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { width: parent.width; text: (modelData.shortId ? modelData.shortId + "  ·  " : "") + modelData.route + "  ·  " + modelData.typeLabel; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
                Rectangle {
                  visible: Number(modelData.unreadCount) > 0
                  width: Style.space(27); height: width; radius: width / 2
                  color: root.urgent; anchors.verticalCenter: parent.verticalCenter
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: Math.min(99, Number(modelData.unreadCount)); color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                }
              }
              MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openNode(modelData) }
              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Style.space(6)
                width: Style.space(30)
                height: width
                radius: Style.cornerRadius
                z: 2
                color: contactManageMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰇙"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea {
                  id: contactManageMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openNodeDetails(modelData)
                }
              }
            }
          }

          ListView {
            id: channelList
            anchors.fill: parent; visible: meshcore.connectionState === "connected" && !root.hasSubview && root.selectedTab === 1
            clip: true; model: root.filteredChannels; spacing: Style.space(3)
            header: Text { textFormat: Text.PlainText; width: channelList.width; height: Style.space(32); text: meshcore.channels.length === 0 ? "No configured channels" : (root.filteredChannels.length === 0 ? "NO MATCHING CHANNELS" : "CHANNELS"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
            delegate: Rectangle {
              required property var modelData
              width: channelList.width; height: Style.space(64); radius: Style.cornerRadius
              color: channelMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(11)
                Rectangle { width: Style.space(42); height: width; radius: width / 2; color: Color.accent; anchors.verticalCenter: parent.verticalCenter
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰒍"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column { width: parent.width - Style.space(118); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(3)
                  Text { width: parent.width; text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { width: parent.width; text: modelData.kind + "  ·  Slot " + modelData.index; textFormat: Text.PlainText; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
                Rectangle {
                  visible: Number(modelData.unreadCount) > 0
                  width: Style.space(27); height: width; radius: width / 2
                  color: root.urgent; anchors.verticalCenter: parent.verticalCenter
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: Math.min(99, Number(modelData.unreadCount)); color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                }
              }
              MouseArea { id: channelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openConversation("channel:" + modelData.index, modelData.name) }
              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Style.space(6)
                width: Style.space(30)
                height: width
                radius: Style.cornerRadius
                z: 2
                color: channelManageMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰇙"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea {
                  id: channelManageMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openChannelManagement(modelData)
                }
              }
            }
          }

          Column {
            anchors.fill: parent
            visible: meshcore.connectionState === "connected" && root.conversationId !== ""
            spacing: Style.space(8)

            Row {
              width: parent.width; height: Style.space(38); spacing: Style.space(8)
              Rectangle {
                width: Style.space(34); height: width; radius: Style.cornerRadius
                color: backMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰁍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.leaveSubview() }
              }
              Column {
                width: parent.width - Style.space(42); anchors.verticalCenter: parent.verticalCenter
                Text { width: parent.width; text: root.conversationTitle; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                Text { textFormat: Text.PlainText; width: parent.width; text: root.conversationId.indexOf("channel:") === 0 ? "Channel messages" : "Direct messages"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }

            Item {
              width: parent.width; height: parent.height - Style.space(122)
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent; visible: root.conversationMessages.length === 0
                text: "No messages yet"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body
              }
              ListView {
                id: messageList
                anchors.fill: parent; visible: root.conversationMessages.length > 0
                clip: true; spacing: Style.space(8); model: root.conversationMessages
                onCountChanged: if (count > 0) positionViewAtEnd()
                delegate: Item {
                  required property var modelData
                  width: messageList.width; height: messageBubble.height + messageTime.height + Style.space(5)
                  Rectangle {
                    id: messageBubble
                    anchors.left: modelData.incoming ? parent.left : undefined
                    anchors.right: modelData.incoming ? undefined : parent.right
                    width: Math.min(messageList.width * 0.78,
                      Math.max(messageText.implicitWidth, senderText.implicitWidth) + Style.space(24))
                    height: messageText.implicitHeight
                      + (senderText.visible ? senderText.implicitHeight + Style.space(3) : 0)
                      + Style.space(16)
                    radius: Style.cornerRadius
                    color: modelData.incoming ? Style.hoverFillFor(root.foreground, Color.accent) : Color.accent
                    Column {
                      anchors.fill: parent
                      anchors.margins: Style.space(8)
                      spacing: Style.space(3)
                      Text {
                        id: senderText
                        width: parent.width
                        visible: modelData.incoming && String(modelData.senderName || "") !== ""
                        text: modelData.senderName || ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                      Text {
                        id: messageText
                        width: parent.width
                        text: modelData.body; textFormat: Text.PlainText; wrapMode: Text.Wrap
                        color: modelData.incoming ? root.foreground : Color.background
                        font.family: root.fontFamily; font.pixelSize: Style.font.body
                      }
                    }
                  }
                  Text {
                    textFormat: Text.PlainText
                    id: messageTime
                    anchors.top: messageBubble.bottom
                    anchors.left: modelData.incoming ? parent.left : undefined
                    anchors.right: modelData.incoming ? undefined : parent.right
                    text: Model.timeLabel(modelData.timestamp)
                      + (modelData.incoming ? "" : "  ·  " + String(modelData.deliveryState || "sent").charAt(0).toUpperCase() + String(modelData.deliveryState || "sent").substring(1))
                    color: !modelData.incoming && modelData.deliveryState === "failed" ? root.urgent : root.dim
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(3)
              Row {
                width: parent.width
                height: Style.space(44)
                spacing: Style.space(6)
                TextField {
                  id: messageInput
                  width: parent.width - sendButton.width - parent.spacing
                  height: parent.height
                  placeholderText: "Send a message…"
                  text: root.draftMessage
                  maximumLength: 160
                  foreground: root.foreground
                  accent: Color.accent
                  enabled: meshcore.live && !meshcore.sending
                  onTextChanged: root.draftMessage = text
                  onAccepted: root.sendDraft()
                }
                Rectangle {
                  id: sendButton
                  width: Style.space(44)
                  height: width
                  radius: Style.cornerRadius
                  color: sendMouse.containsMouse || meshcore.sending
                    ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                  opacity: messageInput.enabled && root.draftMessage.trim() !== "" ? 1 : 0.45
                  Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: meshcore.sending ? "󰔟" : "󰒊"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.iconLarge
                  }
                  MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    enabled: messageInput.enabled && root.draftMessage.trim() !== ""
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.sendDraft()
                  }
                }
              }
              Row {
                width: parent.width
                Text {
                  width: parent.width - byteCount.width
                  text: meshcore.sendError
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  textFormat: Text.PlainText
                  id: byteCount
                  text: Model.sendByteLength(root.conversationId, root.draftMessage, meshcore.companion ? meshcore.companion.name : "") + "/160"
                  color: Model.sendByteLength(root.conversationId, root.draftMessage, meshcore.companion ? meshcore.companion.name : "") > 160 ? root.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          Column {
            anchors.fill: parent
            visible: root.managementView === "connection"
            spacing: Style.space(8)

            Row {
              width: parent.width; height: Style.space(38); spacing: Style.space(8)
              Rectangle {
                width: Style.space(34); height: width; radius: Style.cornerRadius
                color: connBackMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰁍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea { id: connBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.leaveSubview() }
              }
              Text { textFormat: Text.PlainText; width: parent.width - Style.space(80); anchors.verticalCenter: parent.verticalCenter; text: "Connection & Transport"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
              Rectangle {
                width: Style.space(34); height: width; radius: Style.cornerRadius
                color: connReloadMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent; text: "󰑐"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.iconSmall
                  RotationAnimator on rotation { running: meshcore.busy; from: 0; to: 360; duration: 850; loops: Animation.Infinite }
                }
                MouseArea { id: connReloadMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
              }
            }

            Flickable {
              id: connFlickable
              width: parent.width
              height: parent.height - Style.space(46)
              contentWidth: width
              contentHeight: connContent.implicitHeight + Style.space(12)
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: connContent
                width: parent.width
                spacing: Style.space(10)

                Rectangle {
                  width: parent.width
                  implicitHeight: activeSummaryCol.implicitHeight + Style.space(20)
                  radius: Style.cornerRadius
                  color: Style.hoverFillFor(root.foreground, Color.accent)

                  Column {
                    id: activeSummaryCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(12)
                    spacing: Style.space(4)

                    Row {
                      width: parent.width; spacing: Style.space(8)
                      Rectangle {
                        width: Style.space(10); height: width; radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: meshcore.connectionState === "connected"
                          ? Color.accent
                          : (meshcore.connectionState === "connecting"
                              ? "#e5c07b"
                              : (meshcore.connectionState === "error" ? root.urgent : root.dim))
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: meshcore.companion ? meshcore.companion.name : (meshcore.connectionState === "connected" ? "Connected Node" : "No Companion Active")
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: "· " + meshcore.statusText
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    Row {
                      width: parent.width; spacing: Style.space(8)
                      Text { textFormat: Text.PlainText; text: "Active:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                      Text {
                        textFormat: Text.PlainText
                        text: meshcore.transportText + "  (" + (meshcore.transport === "tcp"
                          ? (meshcore.tcpHost + ":" + meshcore.tcpPort)
                          : (meshcore.transport === "ble"
                              ? (meshcore.bleTarget || "Not configured")
                              : meshcore.serialPort)) + ")"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                      }
                    }

                    Row {
                      width: parent.width; spacing: Style.space(12)
                      visible: meshcore.connectionState === "connected"
                      Row {
                        spacing: Style.space(4)
                        Text { textFormat: Text.PlainText; text: "Radio:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: meshcore.radioText || "Ready"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                      }
                      Row {
                        spacing: Style.space(4)
                        Text { textFormat: Text.PlainText; text: "Battery:"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: meshcore.batteryText || "—"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                      }
                    }
                  }
                }

                Text { textFormat: Text.PlainText; text: "SELECT TRANSPORT"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }

                Row {
                  width: parent.width
                  height: Style.space(36)
                  spacing: Style.space(6)

                  Repeater {
                    model: [
                      { id: "USB", label: "USB Serial", icon: "󱐌" },
                      { id: "TCP", label: "TCP / IP", icon: "󰌗" },
                      { id: "BLE", label: "Bluetooth", icon: "󰂯" }
                    ]
                    delegate: Rectangle {
                      id: transportBtn
                      width: (parent.width - Style.space(12)) / 3
                      height: parent.height
                      radius: Style.cornerRadius
                      color: root.editTransport === modelData.id
                        ? Color.accent
                        : (tMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
                      border.width: root.editTransport === modelData.id ? 0 : 1
                      border.color: root.editTransport === modelData.id ? "transparent" : Style.hoverFillFor(root.foreground, Color.accent)

                      Row {
                        anchors.centerIn: parent
                        spacing: Style.space(4)
                        Text {
                          textFormat: Text.PlainText
                          text: modelData.icon
                          color: root.editTransport === modelData.id ? Color.background : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.iconSmall
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          textFormat: Text.PlainText
                          text: modelData.label
                          color: root.editTransport === modelData.id ? Color.background : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          font.bold: root.editTransport === modelData.id
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }

                      MouseArea {
                        id: tMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editTransport = modelData.id
                      }
                    }
                  }
                }

                Column {
                  width: parent.width
                  visible: root.editTransport === "TCP"
                  spacing: Style.space(6)

                  Text { textFormat: Text.PlainText; text: "TCP HOST / IP ADDRESS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  TextField {
                    id: tcpHostField
                    width: parent.width
                    placeholderText: "127.0.0.1 or 192.168.1.50"
                    text: root.editTcpHost
                    maximumLength: 253
                    foreground: root.foreground
                    accent: Color.accent
                    onTextChanged: {
                      if (root.editTcpHost !== text) {
                        root.editTcpHost = text
                        if (text.trim() !== "") root.lastConfiguredTcpHost = text.trim()
                      }
                    }
                    onAccepted: root.applyConnectionSettings()
                  }

                  Text { textFormat: Text.PlainText; text: "TCP PORT"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  TextField {
                    id: tcpPortField
                    width: parent.width
                    placeholderText: "5000"
                    text: root.editTcpPort
                    maximumLength: 5
                    foreground: root.foreground
                    accent: Color.accent
                    onTextChanged: {
                      if (root.editTcpPort !== text) {
                        root.editTcpPort = text
                        if (text.trim() !== "") root.lastConfiguredTcpPort = text.trim()
                      }
                    }
                    onAccepted: root.applyConnectionSettings()
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Rectangle {
                      height: Style.space(24)
                      width: tcpLocalPresetText.implicitWidth + Style.space(16)
                      radius: Style.cornerRadius
                      color: tcpLocalPresetMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                      border.width: 1
                      border.color: Style.hoverFillFor(root.foreground, Color.accent)
                      Text {
                        id: tcpLocalPresetText
                        anchors.centerIn: parent
                        text: "127.0.0.1:5000"
                        textFormat: Text.PlainText
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                      MouseArea {
                        id: tcpLocalPresetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.editTcpHost = "127.0.0.1"
                          root.editTcpPort = "5000"
                          root.lastConfiguredTcpHost = "127.0.0.1"
                          root.lastConfiguredTcpPort = "5000"
                        }
                      }
                    }

                    Rectangle {
                      height: Style.space(24)
                      width: tcpDefaultPortText.implicitWidth + Style.space(16)
                      radius: Style.cornerRadius
                      color: tcpDefaultPortMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                      border.width: 1
                      border.color: Style.hoverFillFor(root.foreground, Color.accent)
                      Text {
                        id: tcpDefaultPortText
                        anchors.centerIn: parent
                        text: "Default Port 5000"
                        textFormat: Text.PlainText
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                      MouseArea {
                        id: tcpDefaultPortMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.editTcpPort = "5000"
                          root.lastConfiguredTcpPort = "5000"
                        }
                      }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Connect to a MeshCore node running over a TCP network socket (e.g. WiFi bridge or remote headless node)."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Column {
                  width: parent.width
                  visible: root.editTransport === "USB"
                  spacing: Style.space(6)

                  Text { textFormat: Text.PlainText; text: "SERIAL DEVICE PORT"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  TextField {
                    width: parent.width
                    placeholderText: "/dev/ttyACM0"
                    text: root.editSerialPort
                    maximumLength: 64
                    foreground: root.foreground
                    accent: Color.accent
                    onTextChanged: root.editSerialPort = text
                    onAccepted: root.applyConnectionSettings()
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Repeater {
                      model: ["/dev/ttyACM0", "/dev/ttyACM1", "/dev/ttyUSB0"]
                      delegate: Rectangle {
                        height: Style.space(24)
                        width: devChipText.implicitWidth + Style.space(16)
                        radius: Style.cornerRadius
                        color: root.editSerialPort === modelData
                          ? Color.accent
                          : (chipMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
                        border.width: root.editSerialPort === modelData ? 0 : 1
                        border.color: Style.hoverFillFor(root.foreground, Color.accent)
                        Text {
                          id: devChipText
                          anchors.centerIn: parent
                          text: modelData
                          textFormat: Text.PlainText
                          color: root.editSerialPort === modelData ? Color.background : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        MouseArea {
                          id: chipMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.editSerialPort = modelData
                        }
                      }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Direct USB serial connection to your companion radio (e.g. Heltec V3, T-Beam, RAK)."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Column {
                  width: parent.width
                  visible: root.editTransport === "BLE"
                  spacing: Style.space(6)

                  Text { textFormat: Text.PlainText; text: "BLUETOOTH DEVICE NAME OR ADDRESS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  TextField {
                    width: parent.width
                    placeholderText: "MeshCore-xxxx or Bluetooth MAC"
                    text: root.editBleTarget
                    maximumLength: 96
                    foreground: root.foreground
                    accent: Color.accent
                    onTextChanged: root.editBleTarget = text
                    onAccepted: root.applyConnectionSettings()
                  }

                  Row {
                    width: parent.width
                    height: Style.space(30)
                    spacing: Style.space(8)

                    Rectangle {
                      width: Style.space(18); height: width; radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: root.editBlePair ? Color.accent : "transparent"
                      border.width: 1
                      border.color: root.editBlePair ? Color.accent : root.dim
                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "✓"
                        color: Color.background
                        visible: root.editBlePair
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editBlePair = !root.editBlePair
                      }
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: "Request OS Bluetooth pairing (-P)"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editBlePair = !root.editBlePair
                      }
                    }
                  }
                }

                Rectangle {
                  width: parent.width
                  visible: meshcore.lastError !== ""
                  implicitHeight: errorRow.implicitHeight + Style.space(16)
                  radius: Style.cornerRadius
                  color: Style.hoverFillFor(root.urgent, root.urgent)
                  border.width: 1
                  border.color: root.urgent

                  Row {
                    id: errorRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(10)
                    spacing: Style.space(8)

                    Text {
                      textFormat: Text.PlainText
                      text: "󰅚"
                      color: root.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.iconSmall
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      width: parent.width - Style.space(32)
                      textFormat: Text.PlainText
                      wrapMode: Text.WordWrap
                      text: meshcore.lastError
                      color: root.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(42)
                  radius: Style.cornerRadius
                  color: applyConnMouse.containsMouse || meshcore.connectionState === "connecting"
                    ? Style.hoverFillFor(root.foreground, Color.accent)
                    : "transparent"
                  border.width: 1
                  border.color: Color.accent
                  opacity: meshcore.connectionState === "connecting" ? 0.6 : 1.0

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(8)
                    Text {
                      visible: meshcore.connectionState === "connecting"
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰑐"
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.iconSmall
                      RotationAnimator on rotation { running: meshcore.connectionState === "connecting"; from: 0; to: 360; duration: 850; loops: Animation.Infinite }
                    }
                    Text {
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: meshcore.connectionState === "connecting"
                        ? "Connecting…"
                        : (meshcore.connectionState === "connected" && meshcore.transport === (root.editTransport === "TCP" ? "tcp" : (root.editTransport === "BLE" ? "ble" : "serial"))
                            ? "Reconnect " + root.editTransport
                            : "Connect " + root.editTransport)
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: applyConnMouse
                    anchors.fill: parent
                    enabled: meshcore.connectionState !== "connecting"
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.applyConnectionSettings()
                  }
                }
              }
            }
          }

          Column {
            anchors.fill: parent
            visible: meshcore.connectionState === "connected" && root.managementView === "add-channel"
            spacing: Style.space(12)

            Row {
              width: parent.width; height: Style.space(38); spacing: Style.space(8)
              Rectangle {
                width: Style.space(34); height: width; radius: Style.cornerRadius
                color: addBackMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰁍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea { id: addBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.leaveSubview() }
              }
              Text { textFormat: Text.PlainText; width: parent.width - Style.space(42); anchors.verticalCenter: parent.verticalCenter; text: "Add channel"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Create a channel in the next free companion slot. Names and keys are sent only to meshcore-cli and are not logged."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text { textFormat: Text.PlainText; text: "CHANNEL NAME"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
            TextField {
              id: channelNameInput
              width: parent.width
              placeholderText: "#omaha or Private team"
              text: root.newChannelName
              maximumLength: 32
              foreground: root.foreground
              accent: Color.accent
              enabled: !meshcore.managing
              onTextChanged: root.newChannelName = text
            }
            Text { textFormat: Text.PlainText; text: "OPTIONAL 16-BYTE KEY"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
            TextField {
              width: parent.width
              placeholderText: "32 hexadecimal characters"
              text: root.newChannelSecret
              maximumLength: 32
              password: true
              foreground: root.foreground
              accent: Color.accent
              enabled: !meshcore.managing
              onTextChanged: root.newChannelSecret = text
              onAccepted: root.createChannel()
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.WordWrap
              text: root.newChannelSecret.trim() === ""
                ? "Without an explicit key, MeshCore derives the channel key deterministically from its name."
                : "The key stays masked and is discarded from plugin state when you submit."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              width: parent.width
              text: meshcore.managementError
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Rectangle {
              width: parent.width
              height: Style.space(42)
              radius: Style.cornerRadius
              color: createChannelMouse.containsMouse || meshcore.managing
                ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              border.width: 1
              border.color: Color.accent
              opacity: root.newChannelName.trim() !== "" && !meshcore.managing ? 1 : 0.45
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: meshcore.managing ? "Applying…" : "Add channel"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              MouseArea {
                id: createChannelMouse
                anchors.fill: parent
                enabled: root.newChannelName.trim() !== "" && !meshcore.managing
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.createChannel()
              }
            }
          }

          Column {
            anchors.fill: parent
            visible: meshcore.connectionState === "connected" && root.managementView === "channel"
            spacing: Style.space(12)

            Row {
              width: parent.width; height: Style.space(38); spacing: Style.space(8)
              Rectangle {
                width: Style.space(34); height: width; radius: Style.cornerRadius
                color: channelBackMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰁍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea { id: channelBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.leaveSubview() }
              }
              Text { textFormat: Text.PlainText; width: parent.width - Style.space(42); anchors.verticalCenter: parent.verticalCenter; text: "Channel settings"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            }

            Rectangle {
              width: parent.width
              height: Style.space(84)
              radius: Style.cornerRadius
              color: Style.hoverFillFor(root.foreground, Color.accent)
              Row {
                anchors.fill: parent; anchors.margins: Style.space(12); spacing: Style.space(12)
                Rectangle {
                  width: Style.space(46); height: width; radius: width / 2; color: Color.accent
                  anchors.verticalCenter: parent.verticalCenter
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰒍"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column {
                  width: parent.width - Style.space(58); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(4)
                  Text { width: parent.width; text: root.managedChannel ? root.managedChannel.name : ""; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { textFormat: Text.PlainText; width: parent.width; text: root.managedChannel ? root.managedChannel.kind + "  ·  Slot " + root.managedChannel.index : ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.WordWrap
              text: root.managedChannel && Number(root.managedChannel.index) === 0
                ? "The public channel is built in and cannot be removed."
                : (root.confirmRemoval
                    ? "Press Remove channel again to confirm. This removes the channel from the companion."
                    : "Removing a channel also removes access to its message stream on this companion.")
              color: root.confirmRemoval ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              width: parent.width
              text: meshcore.managementError
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Rectangle {
              width: parent.width
              height: Style.space(42)
              radius: Style.cornerRadius
              visible: root.managedChannel && Number(root.managedChannel.index) !== 0
              color: removeChannelMouse.containsMouse || root.confirmRemoval
                ? Style.hoverFillFor(root.foreground, root.urgent) : "transparent"
              border.width: 1
              border.color: root.urgent
              opacity: meshcore.managing ? 0.45 : 1
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: meshcore.managing ? "Removing…" : (root.confirmRemoval ? "Confirm removal" : "Remove channel")
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              MouseArea {
                id: removeChannelMouse
                anchors.fill: parent
                enabled: !meshcore.managing
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.confirmChannelRemoval()
              }
            }
          }

          Column {
            anchors.fill: parent
            visible: meshcore.connectionState === "connected" && root.detailNode !== null
            spacing: Style.space(8)

            Row {
              width: parent.width; height: Style.space(38); spacing: Style.space(8)
              Rectangle {
                width: Style.space(34); height: width; radius: Style.cornerRadius
                color: detailBackMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰁍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea { id: detailBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.leaveSubview() }
              }
              Text { textFormat: Text.PlainText; width: parent.width - Style.space(42); anchors.verticalCenter: parent.verticalCenter; text: "Contact details"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            }

            Flickable {
              id: detailFlickable
              width: parent.width
              height: parent.height - Style.space(46)
              contentWidth: width
              contentHeight: detailContent.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: detailContent
                width: parent.width
                spacing: Style.space(12)

                Rectangle {
                  width: parent.width; height: detailIdentity.implicitHeight + Style.space(28); radius: Style.cornerRadius
                  color: Style.hoverFillFor(root.foreground, Color.accent)
                  Row {
                    id: detailIdentity
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(14); spacing: Style.space(12)
                    Rectangle { width: Style.space(48); height: width; radius: width / 2; color: Color.accent
                      Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: root.detailNode ? root.detailNode.icon : ""; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                    }
                    Column { width: parent.width - Style.space(60); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(4)
                      Text { width: parent.width; text: root.detailNode ? root.detailNode.name : ""; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                      Text { textFormat: Text.PlainText; width: parent.width; text: root.detailNode ? root.detailNode.typeLabel : ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                    }
                  }
                }

                Rectangle {
                  visible: root.detailNode !== null && Number(root.detailNode.type) === 1
                  width: parent.width; height: Style.space(38); radius: Style.cornerRadius
                  color: messageContactMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                  border.width: 1
                  border.color: Color.accent
                  Row {
                    anchors.centerIn: parent; spacing: Style.space(6)
                    Text { textFormat: Text.PlainText; text: "󰍡"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                    Text { textFormat: Text.PlainText; text: "Send direct message"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  }
                  MouseArea {
                    id: messageContactMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.detailNode) root.openConversation("contact:" + root.detailNode.keyPrefix, root.detailNode.name)
                  }
                }

                Column {
                  width: parent.width; spacing: Style.space(8)
                  Text { textFormat: Text.PlainText; text: "IDENTIFIER"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  Text { width: parent.width; text: root.detailNode ? root.detailNode.shortId : ""; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                  Text { textFormat: Text.PlainText; text: "ROUTE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  Text { width: parent.width; text: root.detailNode ? root.detailNode.route : ""; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                  Text { textFormat: Text.PlainText; text: "LAST ADVERT"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  Text { width: parent.width; text: root.detailNode ? Model.relativeTimeLabel(root.detailNode.lastAdvert) : ""; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                  Text { textFormat: Text.PlainText; text: "ADVERTISED LOCATION"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
                  Text { width: parent.width; text: root.detailNode ? Model.locationLabel(root.detailNode) : ""; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                }

                Column {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    width: parent.width; height: Style.space(26)
                    Text {
                      textFormat: Text.PlainText
                      width: parent.width - telemReqBtn.width
                      anchors.verticalCenter: parent.verticalCenter
                      text: "TELEMETRY" + (meshcore.telemetryNodePrefix === (root.detailNode ? root.detailNode.keyPrefix : "") && meshcore.telemetryUpdatedAt > 0 ? "  ·  " + Model.relativeTimeLabel(meshcore.telemetryUpdatedAt) : "")
                      color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1
                    }
                    Rectangle {
                      id: telemReqBtn
                      width: telemReqText.implicitWidth + Style.space(16); height: Style.space(26); radius: Style.cornerRadius
                      color: telemReqMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                      border.width: 1
                      border.color: Style.hoverFillFor(root.foreground, Color.accent)
                      opacity: (meshcore.requestingTelemetry || meshcore.busy) ? 0.45 : 1
                      Text {
                        textFormat: Text.PlainText
                        id: telemReqText
                        anchors.centerIn: parent
                        text: meshcore.requestingTelemetry ? "Requesting…" : "Request"
                        color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                      }
                      MouseArea {
                        id: telemReqMouse
                        anchors.fill: parent
                        enabled: !meshcore.requestingTelemetry && !meshcore.busy && root.detailNode !== null
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (root.detailNode) meshcore.requestTelemetry(root.detailNode.keyPrefix)
                      }
                    }
                  }

                  Text {
                    visible: meshcore.telemetryNodePrefix === (root.detailNode ? root.detailNode.keyPrefix : "") && meshcore.telemetryState === "failed"
                    width: parent.width
                    text: meshcore.telemetryError || "The node did not return telemetry"
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  Text {
                    textFormat: Text.PlainText
                    visible: meshcore.requestingTelemetry && meshcore.telemetryNodePrefix === (root.detailNode ? root.detailNode.keyPrefix : "")
                    width: parent.width
                    text: "Querying companion radio for telemetry data…"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  Repeater {
                    model: (meshcore.telemetryNodePrefix === (root.detailNode ? root.detailNode.keyPrefix : "") && meshcore.telemetryState === "succeeded")
                      ? meshcore.telemetryRows : []
                    delegate: Rectangle {
                      required property var modelData
                      width: detailContent.width
                      height: Style.space(34)
                      radius: Style.cornerRadius
                      color: Style.hoverFillFor(root.foreground, Color.accent)
                      Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label + (Number(modelData.channel) > 0 ? " (Ch " + modelData.channel + ")" : "")
                        textFormat: Text.PlainText
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }
                      Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.value
                        textFormat: Text.PlainText
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }
                    }
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  wrapMode: Text.WordWrap
                  text: root.confirmRemoval
                    ? "Press Remove contact again to confirm. Existing in-memory messages remain until the plugin reloads."
                    : (root.detailNode && Number(root.detailNode.type) === 2
                        ? "Remote repeater configuration is planned for a later milestone."
                        : "")
                  visible: text !== ""
                  color: root.confirmRemoval ? root.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  width: parent.width
                  text: meshcore.managementError
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  visible: text !== ""
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Rectangle {
                  width: parent.width
                  height: Style.space(42)
                  radius: Style.cornerRadius
                  color: removeContactMouse.containsMouse || root.confirmRemoval
                    ? Style.hoverFillFor(root.foreground, root.urgent) : "transparent"
                  border.width: 1
                  border.color: root.urgent
                  opacity: meshcore.managing ? 0.45 : 1
                  Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: meshcore.managing ? "Removing…" : (root.confirmRemoval ? "Confirm removal" : "Remove contact")
                    color: root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                  MouseArea {
                    id: removeContactMouse
                    anchors.fill: parent
                    enabled: !meshcore.managing
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.confirmContactRemoval()
                  }
                }
              }
            }
          }

          Column {
            anchors.fill: parent
            visible: meshcore.connectionState === "connected" && !root.hasSubview && root.selectedTab === 2
            spacing: Style.space(8)

            Row {
              width: parent.width
              height: Style.space(32)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                width: parent.width - mapControlsRow.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "NETWORK POSITIONS"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Row {
                id: mapControlsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.mapLocatedNodes.length + " LOCATED"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Rectangle {
                  width: Style.space(26); height: width; radius: Style.cornerRadius
                  color: mapFitMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                  border.width: 1
                  border.color: root.mapUserPanned ? Color.accent : Style.hoverFillFor(root.foreground, Color.accent)
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰍉"; color: root.mapUserPanned ? Color.accent : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  MouseArea {
                    id: mapFitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.recenterMap()
                  }
                }

                Rectangle {
                  width: Style.space(26); height: width; radius: Style.cornerRadius
                  color: mapModeMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                  border.width: 1
                  border.color: root.mapTilesActive ? Color.accent : Style.hoverFillFor(root.foreground, Color.accent)
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: root.mapTilesActive ? "󰆋" : "󰙀"; color: root.mapTilesActive ? Color.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  MouseArea {
                    id: mapModeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMapTiles()
                  }
                }
              }
            }

            Rectangle {
              id: coordinateMap
              width: parent.width
              height: parent.height - Style.space(40)
              radius: Style.cornerRadius
              color: root.mapTilesActive ? "#0e1014" : Style.hoverFillFor(root.foreground, Color.accent)
              clip: true

              Item {
                id: tileContainer
                anchors.fill: parent
                visible: root.mapTilesActive

                Repeater {
                  model: root.mapTiles
                  delegate: Image {
                    required property var modelData
                    x: modelData.x
                    y: modelData.y
                    width: 256
                    height: 256
                    source: modelData.url
                    fillMode: Image.Stretch
                    asynchronous: true
                    cache: true
                  }
                }
              }

              Repeater {
                model: 5
                Rectangle {
                  required property int index
                  x: coordinateMap.width * (index + 1) / 6
                  width: 1
                  height: coordinateMap.height
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.mapTilesActive ? 0.04 : 0.08)
                }
              }
              Repeater {
                model: 7
                Rectangle {
                  required property int index
                  y: coordinateMap.height * (index + 1) / 8
                  width: coordinateMap.width
                  height: 1
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.mapTilesActive ? 0.04 : 0.08)
                }
              }

              MouseArea {
                id: mapDragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real lastX: 0
                property real lastY: 0
                onPressed: function(mouse) {
                  lastX = mouse.x
                  lastY = mouse.y
                }
                onPositionChanged: function(mouse) {
                  if (pressed) {
                    var dx = mouse.x - lastX
                    var dy = mouse.y - lastY
                    lastX = mouse.x
                    lastY = mouse.y
                    root.panMap(dx, dy)
                  }
                }
                onWheel: function(wheel) {
                  if (wheel.angleDelta.y > 0) root.zoomMap(1)
                  else if (wheel.angleDelta.y < 0) root.zoomMap(-1)
                }
              }

              Column {
                anchors.centerIn: parent
                width: parent.width - Style.space(40)
                visible: root.mapLocatedNodes.length === 0
                spacing: Style.space(8)
                Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "󰆋"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.space(42) }
                Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "No advertised locations"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                Text { textFormat: Text.PlainText; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: "Nodes appear here when their adverts include coordinates."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              }

              Repeater {
                model: root.mapProjectedNodes
                delegate: Item {
                  required property var modelData
                  visible: modelData.inView
                  width: Style.space(90)
                  height: Style.space(56)
                  x: modelData.pixelX - width / 2
                  y: modelData.pixelY - Style.space(38) / 2
                  z: markerMouse.containsMouse ? 20 : 5

                  Rectangle {
                    id: pinBadge
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Style.space(36)
                    height: width
                    radius: width / 2
                    color: markerMouse.containsMouse
                      ? Color.accent
                      : (Number(modelData.type) === 2 ? Color.warning : Color.accent)
                    border.width: 2
                    border.color: root.foreground
                    Text {
                      textFormat: Text.PlainText
                      anchors.centerIn: parent
                      text: modelData.icon || "󰒍"
                      color: Color.background
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.icon
                    }
                  }

                  Rectangle {
                    anchors.top: pinBadge.bottom
                    anchors.topMargin: Style.space(2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, nodeNameText.implicitWidth + Style.space(8))
                    height: nodeNameText.implicitHeight + Style.space(3)
                    radius: Style.cornerRadius
                    color: Qt.rgba(0, 0, 0, 0.82)
                    Text {
                      id: nodeNameText
                      anchors.centerIn: parent
                      width: parent.width - Style.space(6)
                      horizontalAlignment: Text.AlignHCenter
                      text: modelData.name
                      textFormat: Text.PlainText
                      elide: Text.ElideRight
                      color: Color.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: markerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openNodeDetails(modelData)
                  }
                }
              }

              Column {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Style.space(8)
                spacing: Style.space(4)
                z: 30

                Rectangle {
                  width: Style.space(28); height: width; radius: Style.cornerRadius
                  color: zoomInMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : Qt.rgba(0, 0, 0, 0.65)
                  border.width: 1
                  border.color: Style.hoverFillFor(root.foreground, Color.accent)
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "+"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  MouseArea {
                    id: zoomInMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomMap(1)
                  }
                }

                Rectangle {
                  width: Style.space(28); height: width; radius: Style.cornerRadius
                  color: zoomOutMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : Qt.rgba(0, 0, 0, 0.65)
                  border.width: 1
                  border.color: Style.hoverFillFor(root.foreground, Color.accent)
                  Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "-"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  MouseArea {
                    id: zoomOutMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.zoomMap(-1)
                  }
                }
              }

              Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)
                z: 25

                Text {
                  textFormat: Text.PlainText
                  width: parent.width - mapAttrText.implicitWidth
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.locationLabel({ hasLocation: true, latitude: root.mapCenterLat, longitude: root.mapCenterLon }) + "  ·  z" + root.mapZoom
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  textFormat: Text.PlainText
                  id: mapAttrText
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.mapTilesActive ? (root.mapTileProvider === "osm" ? "OpenStreetMap" : "CartoDB") : "Offline Grid"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }

        Row {
          width: parent.width; height: Style.space(48); spacing: Style.space(4); visible: !root.hasSubview
          Repeater {
            model: [ { label: "Contacts", icon: "󰀄" }, { label: "Channels", icon: "󰒍" }, { label: "Map", icon: "󰆋" } ]
            delegate: Rectangle {
              required property int index
              required property var modelData
              width: (parent.width - Style.space(8)) / 3; height: parent.height; radius: Style.cornerRadius
              color: root.selectedTab === index ? Style.hoverFillFor(root.foreground, Color.accent) : (tabMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
              Column { anchors.centerIn: parent; spacing: Style.space(2)
                Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: root.selectedTab === index ? Color.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.selectedTab === index ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
              MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectTab(index) }
            }
          }
        }
      }
    }
  }
}
