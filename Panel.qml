import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "." 1.0

Panel {
  id: root
  moduleName: "clartek.omamesh"
  ipcTarget: "clartek.omamesh"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property int selectedTab: 0
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
      onReturnRequested: meshcore.refresh()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") meshcore.refresh()
        else if (text === "h" || text === "H") root.selectTab(root.selectedTab - 1)
        else if (text === "l" || text === "L") root.selectTab(root.selectedTab + 1)
        else if (text === "1") root.selectTab(0)
        else if (text === "2") root.selectTab(1)
        else if (text === "3") root.selectTab(2)
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
              text: meshcore.connectionState === "connected" ? "USB connected  ·  " + meshcore.nodes.length + " contacts" : (meshcore.lastError || meshcore.statusText)
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

        Item {
          width: parent.width; height: parent.height - Style.space(116)
          Column {
            anchors.centerIn: parent; width: parent.width; visible: meshcore.connectionState !== "connected"; spacing: Style.space(8)
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "󰛳"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.space(40) }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: meshcore.statusText; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: meshcore.lastError || "Connect a USB Serial Companion to begin."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
          }

          ListView {
            id: contactList
            anchors.fill: parent; visible: meshcore.connectionState === "connected" && root.selectedTab === 0
            clip: true; model: meshcore.nodes; spacing: Style.space(3)
            header: Text { width: contactList.width; height: Style.space(32); textFormat: Text.PlainText; text: meshcore.nodes.length === 0 ? "Listening for nearby contacts…" : "CONTACTS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
            delegate: Rectangle {
              required property var modelData
              width: contactList.width; height: Style.space(66); radius: Style.cornerRadius
              color: rowMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(11)
                Rectangle { width: Style.space(42); height: width; radius: width / 2; color: Color.accent; anchors.verticalCenter: parent.verticalCenter
                  Text { anchors.centerIn: parent; text: modelData.icon; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column { width: parent.width - Style.space(54); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(3)
                  Text { width: parent.width; text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { width: parent.width; text: (modelData.shortId ? modelData.shortId + "  ·  " : "") + modelData.route + "  ·  " + modelData.typeLabel; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
              }
              MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }
          }

          ListView {
            id: channelList
            anchors.fill: parent; visible: meshcore.connectionState === "connected" && root.selectedTab === 1
            clip: true; model: meshcore.channels; spacing: Style.space(3)
            header: Text { width: channelList.width; height: Style.space(32); text: meshcore.channels.length === 0 ? "No configured channels" : "CHANNELS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
            delegate: Rectangle {
              required property var modelData
              width: channelList.width; height: Style.space(64); radius: Style.cornerRadius
              color: channelMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
              Row {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(11)
                Rectangle { width: Style.space(42); height: width; radius: width / 2; color: Color.accent; anchors.verticalCenter: parent.verticalCenter
                  Text { anchors.centerIn: parent; text: "󰒍"; color: Color.background; font.family: root.fontFamily; font.pixelSize: Style.font.iconLarge }
                }
                Column { width: parent.width - Style.space(54); anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(3)
                  Text { width: parent.width; text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { width: parent.width; text: modelData.kind + "  ·  Slot " + modelData.index; textFormat: Text.PlainText; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
                }
              }
              MouseArea { id: channelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }
          }

          Column {
            anchors.centerIn: parent; width: parent.width; visible: meshcore.connectionState === "connected" && root.selectedTab === 2; spacing: Style.space(8)
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "󰆋"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.space(42) }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Network map"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: "Location data and map rendering are coming after contact discovery."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.body }
          }
        }

        Row {
          width: parent.width; height: Style.space(48); spacing: Style.space(4)
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
