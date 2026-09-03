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

function extractJsonDocuments(raw) {
  var input = String(raw || "")
  var documents = []
  var cursor = 0
  while (cursor < input.length) {
    var objectStart = input.indexOf("{", cursor)
    var arrayStart = input.indexOf("[", cursor)
    var start
    if (objectStart < 0) start = arrayStart
    else if (arrayStart < 0) start = objectStart
    else start = Math.min(objectStart, arrayStart)
    if (start < 0) return { documents: documents, remainder: "" }

    var stack = []
    var quoted = false
    var escaped = false
    var complete = -1
    for (var i = start; i < input.length; i++) {
      var ch = input.charAt(i)
      if (quoted) {
        if (escaped) escaped = false
        else if (ch === "\\") escaped = true
        else if (ch === '"') quoted = false
        continue
      }
      if (ch === '"') quoted = true
      else if (ch === "{" || ch === "[") stack.push(ch)
      else if (ch === "}" || ch === "]") {
        if (stack.length === 0) break
        var opener = stack.pop()
        if ((opener === "{" && ch !== "}") || (opener === "[" && ch !== "]")) break
        if (stack.length === 0) { complete = i + 1; break }
      }
    }
    if (complete < 0) return { documents: documents, remainder: input.substring(start) }
    var candidate = input.substring(start, complete)
    try { documents.push(JSON.parse(candidate)) }
    catch (e) {}
    cursor = complete
  }
  return { documents: documents, remainder: "" }
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

function _keyPrefix(value) {
  var clean = typeof value === "string" ? value.replace(/[^0-9a-f]/gi, "").toLowerCase() : ""
  return clean.length >= 12 ? clean.substring(0, 12) : ""
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
      keyPrefix: _keyPrefix(publicKey),
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

function parseBattery(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null
  var millivolts = Number(value.battery_mv !== undefined ? value.battery_mv : value.level)
  if (!isFinite(millivolts) || millivolts < 0 || millivolts > 10000) return null
  return Math.round(millivolts)
}

function parseRadio(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null
  var frequency = Number(value.radio_freq)
  var bandwidth = Number(value.radio_bw)
  var spreadingFactor = Number(value.radio_sf)
  var codingRate = Number(value.radio_cr)
  if (!isFinite(frequency) || frequency < 100 || frequency > 1000) return null
  if (!isFinite(bandwidth) || bandwidth <= 0 || bandwidth > 1000) return null
  if (!isFinite(spreadingFactor) || spreadingFactor < 5 || spreadingFactor > 12) return null
  if (!isFinite(codingRate) || codingRate < 5 || codingRate > 8) return null
  return {
    frequencyMHz: frequency,
    bandwidthKHz: bandwidth,
    spreadingFactor: Math.floor(spreadingFactor),
    codingRate: Math.floor(codingRate),
    label: frequency.toFixed(3).replace(/0+$/, "").replace(/\.$/, "") + " MHz · BW "
      + bandwidth + " · SF" + Math.floor(spreadingFactor) + " · CR" + Math.floor(codingRate)
  }
}

function batteryLabel(millivolts) {
  var value = Number(millivolts)
  if (!isFinite(value) || value <= 0) return ""
  return (value / 1000).toFixed(2) + " V"
}

function _bodyHash(text) {
  var hash = 2166136261
  for (var i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i)
    hash = Math.imul(hash, 16777619)
  }
  return (hash >>> 0).toString(16)
}

function normalizeIncomingMessage(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null
  var type = String(value.type || "")
  if (type !== "PRIV" && type !== "CHAN") return null
  if (typeof value.text !== "string" || value.text.length === 0 || value.text.length > 4096) return null
  var timestamp = Number(value.sender_timestamp)
  if (!isFinite(timestamp) || timestamp < 0 || timestamp > 4102444800) return null

  var prefix = ""
  var channelIndex = -1
  var conversationId
  if (type === "PRIV") {
    prefix = _keyPrefix(value.pubkey_prefix)
    if (prefix === "") return null
    conversationId = "contact:" + prefix
  } else {
    channelIndex = Number(value.channel_idx)
    if (!isFinite(channelIndex) || channelIndex < 0 || channelIndex > 255) return null
    channelIndex = Math.floor(channelIndex)
    conversationId = "channel:" + channelIndex
  }
  var body = value.text
  return {
    id: type + ":" + conversationId + ":" + Math.floor(timestamp) + ":" + _bodyHash(body),
    conversationId: conversationId,
    kind: type === "PRIV" ? "direct" : "channel",
    contactKeyPrefix: prefix,
    channelIndex: channelIndex,
    timestamp: Math.floor(timestamp),
    body: body,
    incoming: true,
    pathLength: isFinite(Number(value.path_len)) ? Math.floor(Number(value.path_len)) : -1
  }
}

function appendUniqueMessage(messages, message, limit) {
  var list = safeArray(messages).slice()
  if (!message || typeof message.id !== "string") return list
  for (var i = 0; i < list.length; i++)
    if (list[i] && list[i].id === message.id) return list
  list.push(message)
  var cap = Math.max(1, Math.min(5000, Number(limit) || 500))
  return list.length > cap ? list.slice(list.length - cap) : list
}

function incrementUnread(items, propertyName, value) {
  var list = safeArray(items)
  var result = []
  for (var i = 0; i < list.length; i++) {
    var source = list[i] || {}
    var copy = {}
    var keys = Object.keys(source)
    for (var j = 0; j < keys.length; j++) copy[keys[j]] = source[keys[j]]
    if (String(source[propertyName]) === String(value))
      copy.unreadCount = Math.max(0, Number(source.unreadCount) || 0) + 1
    result.push(copy)
  }
  return result
}

function clearUnread(items, propertyName, value) {
  var list = safeArray(items)
  var result = []
  for (var i = 0; i < list.length; i++) {
    var source = list[i] || {}
    var copy = {}
    var keys = Object.keys(source)
    for (var j = 0; j < keys.length; j++) copy[keys[j]] = source[keys[j]]
    if (String(source[propertyName]) === String(value)) copy.unreadCount = 0
    result.push(copy)
  }
  return result
}

function preserveUnread(freshItems, previousItems, propertyName) {
  var fresh = safeArray(freshItems)
  var previous = safeArray(previousItems)
  var counts = {}
  for (var i = 0; i < previous.length; i++) {
    var oldItem = previous[i] || {}
    counts[String(oldItem[propertyName])] = Math.max(0, Number(oldItem.unreadCount) || 0)
  }
  var result = []
  for (var j = 0; j < fresh.length; j++) {
    var source = fresh[j] || {}
    var copy = {}
    var keys = Object.keys(source)
    for (var k = 0; k < keys.length; k++) copy[keys[k]] = source[keys[k]]
    var id = String(source[propertyName])
    if (counts[id] !== undefined) copy.unreadCount = counts[id]
    result.push(copy)
  }
  return result
}

function messagesForConversation(messages, conversationId) {
  var list = safeArray(messages)
  var result = []
  var wanted = String(conversationId || "")
  for (var i = 0; i < list.length; i++)
    if (list[i] && list[i].conversationId === wanted) result.push(list[i])
  result.sort(function(a, b) { return Number(a.timestamp) - Number(b.timestamp) })
  return result
}

function filterByText(items, query) {
  var list = safeArray(items)
  var needle = String(query || "").trim().toLowerCase()
  if (needle === "") return list.slice()
  var result = []
  for (var i = 0; i < list.length; i++) {
    var item = list[i] || {}
    var haystack = String(item.name || "") + " " + String(item.typeLabel || "")
      + " " + String(item.kind || "") + " " + String(item.shortId || "")
    if (haystack.toLowerCase().indexOf(needle) !== -1) result.push(item)
  }
  return result
}

function timeLabel(timestamp) {
  var seconds = Number(timestamp)
  if (!isFinite(seconds) || seconds <= 0) return ""
  var date = new Date(seconds * 1000)
  if (isNaN(date.getTime())) return ""
  var hours = date.getHours()
  var minuteValue = date.getMinutes()
  var minutes = (minuteValue < 10 ? "0" : "") + minuteValue
  var suffix = hours >= 12 ? "PM" : "AM"
  var displayHour = hours % 12
  if (displayHour === 0) displayHour = 12
  return displayHour + ":" + minutes + " " + suffix
}

function totalUnread(channels, nodes) {
  var list = safeArray(channels).concat(safeArray(nodes))
  var count = 0
  for (var i = 0; i < list.length; i++) {
    var value = Number(list[i] && list[i].unreadCount)
    if (isFinite(value) && value > 0) count += Math.floor(value)
  }
  return count
}
