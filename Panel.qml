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
  property int contactTypeFilter: -1
  readonly property var conversationMessages: Model.messagesForConversation(meshcore.messages, conversationId)
  readonly property var filteredNodes: Model.filterContacts(meshcore.nodes, searchQuery, contactTypeFilter)
  readonly property var filteredChannels: Model.filterByText(meshcore.channels, searchQuery)
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
  function selectTab(index) { root.selectedTab = Math.max(0, Math.min(2, index)) }
  function openConversation(id, title) {
    root.detailNode = null
    root.conversationId = String(id || "")
    root.conversationTitle = String(title || "Conversation")
    meshcore.markConversationRead(root.conversationId)
  }
  function openNode(item) {
    if (Number(item.type) === 1) root.openConversation("contact:" + item.keyPrefix, item.name)
    else { root.conversationId = ""; root.detailNode = item }
  }
  function leaveSubview() { root.conversationId = ""; root.conversationTitle = ""; root.detailNode = null }
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
      onReturnRequested: if (root.conversationId === "") meshcore.refresh()
      onCloseRequested: (root.conversationId !== "" || root.detailNode !== null) ? root.leaveSubview() : root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") meshcore.refresh()
        else if (text === "h" || text === "H") root.selectTab(root.selectedTab - 1)
        else if (text === "l" || text === "L") root.selectTab(root.selectedTab + 1)
        else if (text === "1") root.selectTab(0)
        else if (text === "2") root.selectTab(1)
        else if (text === "3") root.selectTab(2)
        else if (text === "/" && root.conversationId === "" && root.detailNode === null && root.selectedTab < 2) searchField.forceActiveFocus()
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
            Text { anchors.centerIn: parent; text: "󰛳"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
          }
          Column {
            width: parent.width - refreshButton.width - Style.space(58)
            anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(2)
            Text { width: parent.width; textFormat: Text.PlainText; text: meshcore.companion ? meshcore.companion.name : "Omamesh"; color: root.foreground; elide: Text.ElideRight; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text {
              width: parent.width; textFormat: Text.PlainText
              text: meshcore.connectionState === "connected"
                ? (meshcore.batteryText ? meshcore.batteryText + "  ·  " : "") + "USB connected  ·  " + meshcore.nodes.length + (meshcore.nodes.length === 1 ? " contact" : " contacts")
                : (meshcore.lastError || meshcore.statusText)
              color: meshcore.connectionState === "error" ? root.urgent : root.dim
              elide: Text.ElideRight; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
            }
          }
          Rectangle {
            id: refreshButton
            width: Style.space(34); height: width; radius: Style.cornerRadius
            color: refreshArea.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
            Text {
              anchors.centerIn: parent; text: "󰑐"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon
              RotationAnimator on rotation { running: meshcore.busy; from: 0; to: 360; duration: 850; loops: Animation.Infinite }
            }
            MouseArea { id: refreshArea; anchors.fill: parent; enabled: !meshcore.busy; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: meshcore.refresh() }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Style.hoverFillFor(root.foreground, Color.accent) }

        Row {
          width: parent.width
          visible: root.conversationId === "" && root.detailNode === null && root.selectedTab < 2 && meshcore.connectionState === "connected"
          height: Style.space(40)
          spacing: Style.space(6)

          TextField {
            id: searchField
            width: parent.width - (contactFilterButton.visible ? contactFilterButton.width + parent.spacing : 0)
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
              Text { text: "󰈲"; color: root.contactTypeFilter === -1 ? root.dim : Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
              Text { text: root.contactFilterLabel(); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            }
            MouseArea {
              id: contactFilterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cycleContactFilter()
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - Style.space(searchField.visible ? 156 : 116)
          Column {
            anchors.centerIn: parent; width: parent.width; visible: meshcore.connectionState !== "connected"; spacing: Style.space(8)
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "󰛳"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.space(40) }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: meshcore.statusText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: meshcore.lastError || "Connect a USB Serial Companion to begin."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
          }

          ListView {
            id: contactList
            anchors.fill: parent; visible: meshcore.connectionState === "connected" && root.conversationId === "" && root.detailNode === null && root.selectedTab === 0
            clip: true; model: root.filteredNodes; spacing: Style.space(3)
            header: Text { width: contactList.width; height: Style.space(32); textFormat: Text.PlainText; text: meshcore.nodes.length === 0 ? "Listening for nearby contacts…" : (root.filteredNodes.length === 0 ? "NO MATCHING CONTACTS" : (root.contactTypeFilter === -1 && meshcore.radioText ? "CONTACTS  ·  " + meshcore.radioText : root.contactFilterLabel().toUpperCase())); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1; elide: Text.ElideRight }
            delegate: Rectangle {
              required property var modelData
              width: contactList.width; height: Style.space(66); radius: Style.cornerRadius
              color: rowMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(11)
                Rectangle { width: Style.space(42); height: width; radius: width / 2; color: Color.accent; anchors.verticalCenter: parent.verticalCenter
                  Text { anchors.centerIn: parent; text: modelData.icon; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column { width: parent.width - Style.space(88); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(3)
                  Text { width: parent.width; text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { width: parent.width; text: (modelData.shortId ? modelData.shortId + "  ·  " : "") + modelData.route + "  ·  " + modelData.typeLabel; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
                Rectangle {
                  visible: Number(modelData.unreadCount) > 0
                  width: Style.space(27); height: width; radius: width / 2
                  color: root.urgent; anchors.verticalCenter: parent.verticalCenter
                  Text { anchors.centerIn: parent; text: Math.min(99, Number(modelData.unreadCount)); color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                }
              }
              MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openNode(modelData) }
            }
          }

          ListView {
            id: channelList
            anchors.fill: parent; visible: meshcore.connectionState === "connected" && root.conversationId === "" && root.detailNode === null && root.selectedTab === 1
            clip: true; model: root.filteredChannels; spacing: Style.space(3)
            header: Text { width: channelList.width; height: Style.space(32); text: meshcore.channels.length === 0 ? "No configured channels" : (root.filteredChannels.length === 0 ? "NO MATCHING CHANNELS" : "CHANNELS"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
            delegate: Rectangle {
              required property var modelData
              width: channelList.width; height: Style.space(64); radius: Style.cornerRadius
              color: channelMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(11)
                Rectangle { width: Style.space(42); height: width; radius: width / 2; color: Color.accent; anchors.verticalCenter: parent.verticalCenter
                  Text { anchors.centerIn: parent; text: "󰒍"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column { width: parent.width - Style.space(88); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(3)
                  Text { width: parent.width; text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { width: parent.width; text: modelData.kind + "  ·  Slot " + modelData.index; textFormat: Text.PlainText; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
                Rectangle {
                  visible: Number(modelData.unreadCount) > 0
                  width: Style.space(27); height: width; radius: width / 2
                  color: root.urgent; anchors.verticalCenter: parent.verticalCenter
                  Text { anchors.centerIn: parent; text: Math.min(99, Number(modelData.unreadCount)); color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                }
              }
              MouseArea { id: channelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openConversation("channel:" + modelData.index, modelData.name) }
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
                Text { anchors.centerIn: parent; text: "󰁍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.leaveSubview() }
              }
              Column {
                width: parent.width - Style.space(42); anchors.verticalCenter: parent.verticalCenter
                Text { width: parent.width; text: root.conversationTitle; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                Text { width: parent.width; text: root.conversationId.indexOf("channel:") === 0 ? "Channel messages" : "Direct messages"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }

            Item {
              width: parent.width; height: parent.height - Style.space(100)
              Text {
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
                    width: Math.min(messageList.width * 0.78, messageText.implicitWidth + Style.space(24))
                    height: messageText.implicitHeight + Style.space(16)
                    radius: Style.cornerRadius
                    color: modelData.incoming ? Style.hoverFillFor(root.foreground, Color.accent) : Color.accent
                    Text {
                      id: messageText
                      anchors.centerIn: parent; width: Math.min(messageList.width * 0.7, implicitWidth)
                      text: modelData.body; textFormat: Text.PlainText; wrapMode: Text.Wrap
                      color: modelData.incoming ? root.foreground : Color.background
                      font.family: root.fontFamily; font.pixelSize: Style.font.body
                    }
                  }
                  Text {
                    id: messageTime
                    anchors.top: messageBubble.bottom
                    anchors.left: modelData.incoming ? parent.left : undefined
                    anchors.right: modelData.incoming ? undefined : parent.right
                    text: Model.timeLabel(modelData.timestamp); color: root.dim
                    font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            Rectangle {
              width: parent.width; height: Style.space(46); radius: Style.cornerRadius
              color: Style.hoverFillFor(root.foreground, Color.accent)
              Text { anchors.centerIn: parent; text: "Read-only preview · Sending is next"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            }
          }

          Column {
            anchors.fill: parent
            visible: meshcore.connectionState === "connected" && root.detailNode !== null
            spacing: Style.space(12)

            Row {
              width: parent.width; height: Style.space(38); spacing: Style.space(8)
              Rectangle {
                width: Style.space(34); height: width; radius: Style.cornerRadius
                color: detailBackMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Text { anchors.centerIn: parent; text: "󰁍"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                MouseArea { id: detailBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.leaveSubview() }
              }
              Text { width: parent.width - Style.space(42); anchors.verticalCenter: parent.verticalCenter; text: "Contact details"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            }

            Rectangle {
              width: parent.width; height: detailIdentity.implicitHeight + Style.space(28); radius: Style.cornerRadius
              color: Style.hoverFillFor(root.foreground, Color.accent)
              Row {
                id: detailIdentity
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(14); spacing: Style.space(12)
                Rectangle { width: Style.space(48); height: width; radius: width / 2; color: Color.accent
                  Text { anchors.centerIn: parent; text: root.detailNode ? root.detailNode.icon : ""; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column { width: parent.width - Style.space(60); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(4)
                  Text { width: parent.width; text: root.detailNode ? root.detailNode.name : ""; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { width: parent.width; text: root.detailNode ? root.detailNode.typeLabel : ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
              }
            }

            Column {
              width: parent.width; spacing: Style.space(8)
              Text { text: "IDENTIFIER"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
              Text { width: parent.width; text: root.detailNode ? root.detailNode.shortId : ""; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Text { text: "ROUTE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1 }
              Text { width: parent.width; text: root.detailNode ? root.detailNode.route : ""; textFormat: Text.PlainText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
            }

            Text { width: parent.width; wrapMode: Text.WordWrap; text: root.detailNode && Number(root.detailNode.type) === 2 ? "Repeater telemetry and remote management are planned for a later milestone." : "Telemetry and node actions are planned for a later milestone."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          }

          Column {
            anchors.centerIn: parent; width: parent.width; visible: meshcore.connectionState === "connected" && root.conversationId === "" && root.detailNode === null && root.selectedTab === 2; spacing: Style.space(8)
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "󰆋"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.space(42) }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Network map"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: "Location data and map rendering are coming after contact discovery."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
          }
        }

        Row {
          width: parent.width; height: Style.space(48); spacing: Style.space(4); visible: root.conversationId === "" && root.detailNode === null
          Repeater {
            model: [ { label: "Contacts", icon: "󰀄" }, { label: "Channels", icon: "󰒍" }, { label: "Map", icon: "󰆋" } ]
            delegate: Rectangle {
              required property int index
              required property var modelData
              width: (parent.width - Style.space(8)) / 3; height: parent.height; radius: Style.cornerRadius
              color: root.selectedTab === index ? Style.hoverFillFor(root.foreground, Color.accent) : (tabMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
              Column { anchors.centerIn: parent; spacing: Style.space(2)
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: root.selectedTab === index ? Color.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.icon }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.selectedTab === index ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
              MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectTab(index) }
            }
          }
        }
      }
    }
  }
}
