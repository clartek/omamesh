import QtQuick
import Quickshell

ShellRoot {
  readonly property bool expectMessage: Quickshell.env("OMAMESH_EXPECT_MESSAGE") === "1"

  MeshCoreService {
    id: service
    settings: ({
      serialPort: "/dev/ttyACM0",
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
      if (live && !busy && (!expectMessage || messages.length === 1)) {
        console.info("OMAMESH_SMOKE_LIVE:contacts=" + nodes.length + ":channels=" + channels.length + ":messages=" + messages.length + ":unread=" + unreadCount)
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
