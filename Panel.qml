import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "clartek.omamesh"
  ipcTarget: "clartek.omamesh"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    meshcore.refresh()
    root.controller.show()
  }

  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function closeForPopoutSwitch() { root.close() }

  MeshCoreService {
    id: meshcore
    settings: root.settings
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Text {
          text: "OmaMesh"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.sizeXL
          font.bold: true
        }

        Text {
          text: meshcore.statusText
          color: meshcore.connectionState === "error" ? Color.urgent : root.foreground
          opacity: 0.72
          font.family: root.fontFamily
          font.pixelSize: Style.font.sizeS
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: meshcore.backendAvailable
            ? "Backend detected. Connection discovery is the next development step."
            : "Install meshcore-cli to begin BLE, USB, and TCP/IP integration."
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.sizeM
        }
      }
    }
  }
}

