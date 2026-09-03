.pragma library

function clampRefreshInterval(value) {
  var parsed = parseInt(String(value), 10)
  if (!isFinite(parsed)) return 10
  return Math.max(2, Math.min(300, parsed))
}

function clampCommandTimeout(value) {
  var parsed = parseInt(String(value), 10)
  if (!isFinite(parsed)) return 12
  return Math.max(3, Math.min(60, parsed))
}

function serialPort(value) {
  var port = String(value === undefined || value === null ? "" : value).trim()
  if (!/^\/dev\/(ttyACM|ttyUSB)[A-Za-z0-9._-]*$/.test(port)) return "/dev/ttyACM0"
  return port
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

function parseCompanionName(raw) {
  var value
  try {
    value = JSON.parse(String(raw || "").trim())
  } catch (e) {
    return { ok: false, name: "" }
  }
  if (typeof value !== "string") return { ok: false, name: "" }
  var name = value.trim()
  if (name === "" || name.length > 96) return { ok: false, name: "" }
  return { ok: true, name: name }
}

function safeCliError(raw, timedOut) {
  if (timedOut) return "The USB companion did not respond in time"
  var value = String(raw || "")
  if (/permission denied|access denied/i.test(value))
    return "Permission denied for the USB serial device"
  if (/no such file|could not open port|cannot open/i.test(value))
    return "USB companion not found"
  if (/no response from meshcore node|serial companion/i.test(value))
    return "The serial device is not responding as a USB companion"
  return "Could not connect to the USB companion"
}

function safeArray(value) {
  return Array.isArray(value) ? value : []
}

function _parseJson(raw) {
  try { return JSON.parse(String(raw || "").trim()) }
  catch (e) { return null }
}

function _text(value, fallback, maxLength) {
  if (typeof value !== "string") return fallback
  var clean = value.trim()
  if (clean === "") return fallback
  return clean.substring(0, maxLength)
}

function contactTypeLabel(type) {
  switch (Number(type)) {
  case 1: return "Direct"
  case 2: return "Repeater"
  case 3: return "Room"
  case 4: return "Sensor"
  default: return "Node"
  }
}

function contactIcon(type) {
  return Number(type) === 1 ? "󰀄" : (Number(type) === 4 ? "󰔚" : "󰒍")
}

function _shortIdentifier(value) {
  var clean = typeof value === "string" ? value.replace(/[^0-9a-f]/gi, "") : ""
  if (clean.length < 12) return ""
  return clean.substring(0, 6).toLowerCase() + "…" + clean.substring(clean.length - 6).toLowerCase()
}

function _pathLabel(contact) {
  var hops = Number(contact && contact.out_path_len)
  if (!isFinite(hops) || hops < 0) return "Flood"
  if (hops === 0) return "Direct"
  return Math.floor(hops) + (Math.floor(hops) === 1 ? " hop" : " hops")
}

function parseContacts(raw) {
  var value = _parseJson(raw)
  if (value === null || typeof value !== "object" || Array.isArray(value))
    return { ok: false, items: [] }
  var items = []
  var keys = Object.keys(value)
  for (var i = 0; i < keys.length; i++) {
    var source = value[keys[i]]
    if (!source || typeof source !== "object" || Array.isArray(source)) continue
    var type = Number(source.type)
    if (!isFinite(type)) type = 0
    var publicKey = typeof source.public_key === "string" ? source.public_key : keys[i]
    items.push({
      name: _text(source.adv_name, "Unnamed node", 96),
      type: Math.floor(type),
      typeLabel: contactTypeLabel(type),
      icon: contactIcon(type),
      shortId: _shortIdentifier(publicKey),
      route: _pathLabel(source),
      unreadCount: 0
    })
  }
  items.sort(function(a, b) { return a.name.toLowerCase().localeCompare(b.name.toLowerCase()) })
  return { ok: true, items: items }
}

function parseChannels(raw) {
  var value = _parseJson(raw)
  if (!Array.isArray(value)) return { ok: false, items: [] }
  var items = []
  for (var i = 0; i < value.length; i++) {
    var source = value[i]
    if (!source || typeof source !== "object" || Array.isArray(source)) continue
    var index = Number(source.channel_idx)
    if (!isFinite(index) || index < 0 || index > 255) continue
    var name = typeof source.channel_name === "string" ? source.channel_name.trim() : ""
    if (name === "") continue
    items.push({
      index: Math.floor(index),
      name: name.substring(0, 64),
      kind: name === "Public" ? "Public channel" : (name.charAt(0) === "#" ? "Hashtag channel" : "Private channel"),
      unreadCount: 0
    })
  }
  items.sort(function(a, b) { return a.index - b.index })
  return { ok: true, items: items }
}

function totalUnread(channels) {
  var list = safeArray(channels)
  var count = 0
  for (var i = 0; i < list.length; i++) {
    var value = Number(list[i] && list[i].unreadCount)
    if (isFinite(value) && value > 0) count += Math.floor(value)
  }
  return count
}
