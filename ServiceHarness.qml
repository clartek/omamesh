import QtQuick
import Quickshell

ShellRoot {
  readonly property bool expectMessage: Quickshell.env("OMAMESH_EXPECT_MESSAGE") === "1"
  readonly property bool expectSend: Quickshell.env("OMAMESH_EXPECT_SEND") === "1"
  readonly property string sendKind: Quickshell.env("OMAMESH_SEND_KIND") || "direct"
  readonly property string expectedSendState: Quickshell.env("OMAMESH_SEND_STATE") || "delivered"
  readonly property string expectManagement: Quickshell.env("OMAMESH_EXPECT_MANAGEMENT")
  readonly property string transportSetting: Quickshell.env("OMAMESH_TRANSPORT") || "USB"
  property bool sendStarted: false
  property bool managementStarted: false

  MeshCoreService {
    id: service
    settings: ({
      transport: transportSetting,
      serialPort: "/dev/ttyACM0",
      tcpHost: "fixture.local",
      tcpPort: 5001,
      bleTarget: "MeshCore-Fixture",
      blePair: true,
      refreshIntervalSec: 300,
      commandTimeoutSec: 20
    })

    onConnectionStateChanged: {
      if (connectionState === "error" || connectionState === "unavailable") {
        console.error("OMAMESH_SMOKE_FAILED:" + connectionState + ":" + lastError)
        Qt.exit(1)
      }
    }

    onBusyChanged: {
      if (live && !busy && expectManagement !== "" && !managementStarted) {
        managementStarted = true
        var started
        if (expectManagement === "add") started = addChannel("#fixture", "")
        else if (expectManagement === "remove-contact") started = removeContact("001122334455")
        else started = removeChannel(1)
        if (!started) {
          console.error("OMAMESH_SMOKE_FAILED:management-rejected")
          Qt.exit(1)
        }
      } else if (live && !busy && expectSend && !sendStarted && messages.length === 1) {
        sendStarted = true
        var target = sendKind === "channel" ? "channel:0" : "contact:001122334455"
        if (!sendMessage(target, "fixture outgoing")) {
          console.error("OMAMESH_SMOKE_FAILED:send-rejected")
          Qt.exit(1)
        }
      } else if (live && !busy && !expectSend && (!expectMessage || messages.length === 1)) {
        console.info("OMAMESH_SMOKE_LIVE:contacts=" + nodes.length + ":channels=" + channels.length + ":messages=" + messages.length + ":unread=" + unreadCount + ":transport=" + transport)
        Qt.quit()
      }
    }

    onSendingChanged: {
      if (sendStarted && !sending) {
        if (sendState !== expectedSendState || messages.length !== 2) {
          console.error("OMAMESH_SMOKE_FAILED:send-state:" + sendState + ":messages=" + messages.length)
          Qt.exit(1)
          return
        }
        console.info("OMAMESH_SMOKE_SEND:kind=" + sendKind + ":state=" + sendState + ":messages=" + messages.length)
        Qt.quit()
      }
    }

    onManagingChanged: {
      if (managementStarted && !managing) {
        var expectedChannels = expectManagement === "add" ? 2 : 1
        var expectedNodes = expectManagement === "remove-contact" ? 0 : 1
        if (managementState !== "succeeded"
            || channels.length !== expectedChannels || nodes.length !== expectedNodes) {
          console.error("OMAMESH_SMOKE_FAILED:management-state:" + managementState + ":channels=" + channels.length + ":nodes=" + nodes.length)
          Qt.exit(1)
          return
        }
        console.info("OMAMESH_SMOKE_MANAGE:kind=" + expectManagement + ":state=" + managementState + ":channels=" + channels.length + ":nodes=" + nodes.length)
        Qt.quit()
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: false
    onTriggered: {
      console.error("OMAMESH_SMOKE_FAILED:harness-timeout")
      Qt.exit(1)
    }
  }
}
