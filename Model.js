.pragma library

function clampRefreshInterval(value) {
  var parsed = parseInt(String(value), 10)
  if (!isFinite(parsed)) return 10
  return Math.max(2, Math.min(300, parsed))
}

function connectionLabel(state) {
  switch (String(state || "")) {
  case "connected": return "Connected"
  case "connecting": return "Connecting…"
  case "error": return "Connection error"
  case "unavailable": return "meshcore-cli not found"
  default: return "Disconnected"
  }
}

function safeArray(value) {
  return Array.isArray(value) ? value : []
}

