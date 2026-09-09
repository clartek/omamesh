import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "clartek.omamesh"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property string connectionState: panelLoader.item ? panelLoader.item.connectionState : "unavailable"
  readonly property int unreadCount: panelLoader.item ? panelLoader.item.unreadCount : 0
  readonly property real openPanelIndicatorWidth: button.width

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }
  function openConnection() { if (panelLoader.item) { panelLoader.item.open(); panelLoader.item.openConnectionDetails() } }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var panel = panelLoader.item
    if (!panel) return
    panel.bar = root.bar
    panel.settings = root.settings
    panel.anchorItem = button
    panel.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "clartek.omamesh"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.connectionState === "connected" ? "Omamesh connected" : "Omamesh disconnected"
    iconComponent: Component {
      Item {
        implicitWidth: iconRow.implicitWidth
        implicitHeight: iconRow.implicitHeight

        Row {
          id: iconRow
          anchors.centerIn: parent
          spacing: Style.space(4)

          MeshCoreIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconSize: Math.round(Style.font.icon * 0.85)
            color: root.unreadCount > 0
              ? Color.accent
              : (root.connectionState === "connected"
                  ? (root.bar ? root.bar.barForeground : Color.foreground)
                  : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.55))
          }

          Text {
            visible: root.unreadCount > 0
            text: String(root.unreadCount)
            textFormat: Text.PlainText
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else if (mouseButton === Qt.LeftButton) root.togglePanel()
    }
  }
}
