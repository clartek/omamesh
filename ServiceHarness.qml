import QtQuick
import Quickshell

ShellRoot {
  MeshCoreService {
    id: service
    property bool sawConnected: false
    settings: ({
      serialPort: "/dev/ttyACM0",
      refreshIntervalSec: 300,
      commandTimeoutSec: 20
    })

    onConnectionStateChanged: {
      if (connectionState === "connected") {
        sawConnected = true
      } else if (connectionState === "error" || connectionState === "unavailable") {
        console.error("OMAMESH_SMOKE_FAILED:" + connectionState + ":" + lastError)
        Qt.exit(1)
      }
    }

    onBusyChanged: {
      if (sawConnected && !busy) {
        console.info("OMAMESH_SMOKE_CONNECTED:contacts=" + nodes.length + ":channels=" + channels.length)
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
