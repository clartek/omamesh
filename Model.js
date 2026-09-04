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

function transport(value) {
  var selected = String(value || "").trim().toLowerCase()
  if (selected === "tcp") return "tcp"
  if (selected === "ble") return "ble"
  return "serial"
}

function tcpHost(value) {
  var host = String(value === undefined || value === null ? "" : value).trim()
  if (host === "" || host.length > 253 || /[\u0000-\u0020\u007f]/.test(host))
    return "127.0.0.1"
  if (!/^[A-Za-z0-9._:\-\[\]]+$/.test(host)) return "127.0.0.1"
  return host
}

function tcpPort(value) {
  var parsed = parseInt(String(value), 10)
  if (!isFinite(parsed) || parsed < 1 || parsed > 65535) return 5000
  return parsed
}

function bleTarget(value) {
  var target = String(value === undefined || value === null ? "" : value).trim()
  if (target === "" || target.length > 96 || /[\u0000-\u0020\u007f]/.test(target))
    return ""
  if (!/^[A-Za-z0-9._:\-]+$/.test(target)) return ""
  return target
}

function connectionArguments(selectedTransport, settings) {
  var selected = transport(selectedTransport)
  var values = settings || {}
  if (selected === "tcp")
    return ["-t", tcpHost(values.tcpHost), "-p", String(tcpPort(values.tcpPort))]
  if (selected === "ble") {
    var target = bleTarget(values.bleTarget)
    if (target === "") return []
    var result = ["-a", target]
    if (values.blePair === true) result.push("-P")
    return result
  }
  return ["-s", serialPort(values.serialPort)]
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

function safeCliError(raw, timedOut, selectedTransport) {
  var selected = transport(selectedTransport)
  if (timedOut) {
    if (selected === "tcp") return "The TCP companion did not respond in time"
    if (selected === "ble") return "The BLE companion did not respond in time"
    return "The USB companion did not respond in time"
  }
  var value = String(raw || "")
  if (/permission denied|access denied/i.test(value))
    return "Permission denied for the USB serial device"
  if (/no such file|could not open port|cannot open/i.test(value))
    return "USB companion not found"
  if (/no response from meshcore node|serial companion/i.test(value))
    return "The serial device is not responding as a USB companion"
  if (selected === "tcp") return "Could not connect to the TCP companion"
  if (selected === "ble") return "Could not connect to the BLE companion"
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

function _coordinate(value, minimum, maximum) {
  if (value === undefined || value === null || value === "") return null
  var number = Number(value)
  return isFinite(number) && number >= minimum && number <= maximum ? number : null
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
    var latitude = _coordinate(source.adv_lat, -90, 90)
    var longitude = _coordinate(source.adv_lon, -180, 180)
    var hasLocation = latitude !== null && longitude !== null
      && !(latitude === 0 && longitude === 0)
    var lastAdvert = Number(source.last_advert)
    if (!isFinite(lastAdvert) || lastAdvert <= 0 || lastAdvert > 4102444800)
      lastAdvert = 0
    items.push({
      name: _text(source.adv_name, "Unnamed node", 96),
      type: Math.floor(type),
      typeLabel: contactTypeLabel(type),
      icon: contactIcon(type),
      shortId: _shortIdentifier(publicKey),
      keyPrefix: _keyPrefix(publicKey),
      route: _pathLabel(source),
      lastAdvert: Math.floor(lastAdvert),
      hasLocation: hasLocation,
      latitude: hasLocation ? latitude : 0,
      longitude: hasLocation ? longitude : 0,
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
  var wireBody = value.text
  var body = wireBody
  var channelSender = ""
  if (type === "CHAN") {
    var separator = wireBody.indexOf(": ")
    if (separator > 0 && separator <= 32) {
      var candidateSender = wireBody.substring(0, separator).trim()
      var candidateBody = wireBody.substring(separator + 2)
      if (candidateSender !== "" && candidateBody !== ""
          && !/[\u0000-\u001f\u007f]/.test(candidateSender)
          && utf8ByteLength(candidateSender) <= 32) {
        channelSender = candidateSender
        body = candidateBody
      }
    }
  }
  var signaturePrefix = ""
  if (typeof value.signature === "string") {
    var signature = value.signature.replace(/[^0-9a-f]/gi, "").toLowerCase()
    if (signature.length === 8) signaturePrefix = signature
  }
  return {
    id: type + ":" + conversationId + ":" + Math.floor(timestamp) + ":" + _bodyHash(wireBody),
    conversationId: conversationId,
    kind: type === "PRIV" ? "direct" : "channel",
    contactKeyPrefix: prefix,
    channelIndex: channelIndex,
    timestamp: Math.floor(timestamp),
    body: body,
    incoming: true,
    senderKeyPrefix: signaturePrefix,
    senderName: channelSender,
    senderVerified: false,
    pathLength: isFinite(Number(value.path_len)) ? Math.floor(Number(value.path_len)) : -1
  }
}

function resolveMessageSender(message, nodes) {
  if (!message || typeof message !== "object") return message
  var copy = {}
  var keys = Object.keys(message)
  for (var i = 0; i < keys.length; i++) copy[keys[i]] = message[keys[i]]
  var list = safeArray(nodes)
  var wanted = String(message.senderKeyPrefix || "")
  if (wanted === "" && message.kind === "direct")
    wanted = String(message.contactKeyPrefix || "")
  copy.senderName = ""
  copy.senderVerified = false
  if (message.kind === "channel" && String(message.senderName || "") !== "") {
    copy.senderName = String(message.senderName)
    return copy
  }
  if (wanted !== "") {
    for (var j = 0; j < list.length; j++) {
      var prefix = String(list[j] && list[j].keyPrefix || "")
      if (prefix.indexOf(wanted) === 0 || wanted.indexOf(prefix) === 0) {
        copy.senderName = String(list[j].name || "")
        copy.senderVerified = true
        break
      }
    }
  }
  return copy
}

function resolveMessageSenders(messages, nodes) {
  var list = safeArray(messages)
  var result = []
  for (var i = 0; i < list.length; i++)
    result.push(resolveMessageSender(list[i], nodes))
  return result
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

function filterContacts(items, query, type) {
  var list = filterByText(items, query)
  var wanted = Number(type)
  if (!isFinite(wanted) || wanted < 0) return list
  var result = []
  for (var i = 0; i < list.length; i++) {
    var itemType = Number(list[i] && list[i].type)
    if (isFinite(itemType) && Math.floor(itemType) === Math.floor(wanted))
      result.push(list[i])
  }
  return result
}

function utf8ByteLength(value) {
  var text = String(value === undefined || value === null ? "" : value)
  var bytes = 0
  for (var i = 0; i < text.length; i++) {
    var code = text.charCodeAt(i)
    if (code < 0x80) bytes += 1
    else if (code < 0x800) bytes += 2
    else if (code >= 0xD800 && code <= 0xDBFF
             && i + 1 < text.length
             && text.charCodeAt(i + 1) >= 0xDC00
             && text.charCodeAt(i + 1) <= 0xDFFF) {
      bytes += 4
      i += 1
    } else bytes += 3
  }
  return bytes
}

function _cliQuote(value) {
  return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
}

function sendByteLength(conversationId, body, senderName) {
  var text = String(body === undefined || body === null ? "" : body)
  if (String(conversationId || "").indexOf("channel:") === 0)
    text = String(senderName === undefined || senderName === null ? "" : senderName).trim() + ": " + text
  return utf8ByteLength(text)
}

function buildSendCommand(conversationId, body, senderName) {
  var id = String(conversationId || "")
  var text = typeof body === "string" ? body : ""
  if (text.trim() === "") return { ok: false, command: "", error: "Enter a message" }
  if (/[\u0000-\u001f\u007f]/.test(text))
    return { ok: false, command: "", error: "Messages cannot contain control characters or line breaks" }
  if (utf8ByteLength(text) > 160)
    return { ok: false, command: "", error: "Messages are limited to 160 UTF-8 bytes" }

  if (id.indexOf("contact:") === 0) {
    var prefix = id.substring(8).toLowerCase()
    if (!/^[0-9a-f]{12}$/.test(prefix))
      return { ok: false, command: "", error: "The contact identifier is invalid" }
    return { ok: true, kind: "direct", command: "msg " + prefix + " " + _cliQuote(text), error: "" }
  }
  if (id.indexOf("channel:") === 0) {
    var indexText = id.substring(8)
    if (!/^\d{1,3}$/.test(indexText))
      return { ok: false, command: "", error: "The channel identifier is invalid" }
    var channelIndex = Number(indexText)
    if (!isFinite(channelIndex) || channelIndex < 0 || channelIndex > 255)
      return { ok: false, command: "", error: "The channel identifier is invalid" }
    var sender = typeof senderName === "string" ? senderName.trim() : ""
    if (sender === "" || /[\u0000-\u001f\u007f]/.test(sender) || utf8ByteLength(sender) > 32)
      return { ok: false, command: "", error: "The companion name cannot identify this channel message" }
    var channelText = sender + ": " + text
    if (sendByteLength(id, text, sender) > 160)
      return { ok: false, command: "", error: "The sender name and message are limited to 160 UTF-8 bytes" }
    return { ok: true, kind: "channel", command: "chan " + Math.floor(channelIndex) + " " + _cliQuote(channelText), error: "" }
  }
  return { ok: false, command: "", error: "The conversation identifier is invalid" }
}

function buildAddChannelCommand(name, secret) {
  var channelName = typeof name === "string" ? name.trim() : ""
  var channelSecret = typeof secret === "string" ? secret.trim().toLowerCase() : ""
  if (channelName === "")
    return { ok: false, command: "", error: "Enter a channel name" }
  if (/[\u0000-\u001f\u007f]/.test(channelName))
    return { ok: false, command: "", error: "Channel names cannot contain control characters" }
  if (utf8ByteLength(channelName) > 32)
    return { ok: false, command: "", error: "Channel names are limited to 32 UTF-8 bytes" }
  if (channelSecret !== "" && !/^[0-9a-f]{32}$/.test(channelSecret))
    return { ok: false, command: "", error: "Channel secrets must contain exactly 32 hexadecimal characters" }
  return {
    ok: true,
    command: "add_channel " + _cliQuote(channelName)
      + (channelSecret === "" ? "" : " " + channelSecret),
    error: "",
    derivedSecret: channelSecret === ""
  }
}

function buildRemoveChannelCommand(index) {
  var indexText = String(index === undefined || index === null ? "" : index)
  if (!/^\d{1,3}$/.test(indexText))
    return { ok: false, command: "", error: "The channel identifier is invalid" }
  var channelIndex = Number(indexText)
  if (!isFinite(channelIndex) || channelIndex < 0 || channelIndex > 255)
    return { ok: false, command: "", error: "The channel identifier is invalid" }
  if (channelIndex === 0)
    return { ok: false, command: "", error: "The public channel cannot be removed" }
  return { ok: true, command: "remove_channel " + Math.floor(channelIndex), error: "" }
}

function buildRemoveContactCommand(keyPrefix) {
  var prefix = String(keyPrefix || "").trim().toLowerCase()
  if (!/^[0-9a-f]{12}$/.test(prefix))
    return { ok: false, command: "", error: "The contact identifier is invalid" }
  return { ok: true, command: "remove_contact " + prefix, error: "" }
}

function parseSendResult(kind, documents, sawError) {
  var list = safeArray(documents)
  if (sawError) return { accepted: false, state: "failed", error: "meshcore-cli could not send the message" }
  if (kind === "channel") {
    if (list.length > 0 && list[0] && typeof list[0] === "object" && !Array.isArray(list[0])
        && list[0].error === undefined)
      return { accepted: true, state: "sent", error: "" }
    return { accepted: false, state: "failed", error: "The channel message was not accepted" }
  }
  if (kind === "direct") {
    var sent = list.length > 0 ? list[0] : null
    var ack = list.length > 1 ? list[1] : null
    var expected = sent && typeof sent.expected_ack === "string" ? sent.expected_ack.toLowerCase() : ""
    var received = ack && typeof ack.code === "string" ? ack.code.toLowerCase() : ""
    if (!/^[0-9a-f]{8}$/.test(expected))
      return { accepted: false, state: "failed", error: "The direct message was not accepted" }
    if (received === expected)
      return { accepted: true, state: "delivered", error: "" }
    return { accepted: true, state: "failed", error: "No matching delivery acknowledgment was received" }
  }
  return { accepted: false, state: "failed", error: "The message type is unsupported" }
}

function outgoingMessage(conversationId, body, timestamp, deliveryState, sequence) {
  var id = String(conversationId || "")
  var seconds = Number(timestamp)
  if (!isFinite(seconds) || seconds < 0) seconds = 0
  return {
    id: "OUT:" + id + ":" + Math.floor(seconds) + ":" + String(sequence || 0),
    conversationId: id,
    kind: id.indexOf("channel:") === 0 ? "channel" : "direct",
    contactKeyPrefix: id.indexOf("contact:") === 0 ? id.substring(8) : "",
    channelIndex: id.indexOf("channel:") === 0 ? Number(id.substring(8)) : -1,
    timestamp: Math.floor(seconds),
    body: String(body || ""),
    incoming: false,
    senderKeyPrefix: "",
    senderName: "",
    senderVerified: true,
    pathLength: -1,
    deliveryState: String(deliveryState || "failed")
  }
}

function relativeTimeLabel(timestamp, referenceTimestamp) {
  var seconds = Number(timestamp)
  var reference = Number(referenceTimestamp)
  if (!isFinite(seconds) || seconds <= 0) return "Unknown"
  if (!isFinite(reference) || reference <= 0)
    reference = Math.floor(Date.now() / 1000)
  var delta = Math.max(0, Math.floor(reference - seconds))
  if (delta < 60) return "Just now"
  if (delta < 3600) {
    var minutes = Math.floor(delta / 60)
    return minutes + (minutes === 1 ? " minute ago" : " minutes ago")
  }
  if (delta < 86400) {
    var hours = Math.floor(delta / 3600)
    return hours + (hours === 1 ? " hour ago" : " hours ago")
  }
  var days = Math.floor(delta / 86400)
  return days + (days === 1 ? " day ago" : " days ago")
}

function locationLabel(item) {
  if (!item || !item.hasLocation) return "Not advertised"
  var latitude = Number(item.latitude)
  var longitude = Number(item.longitude)
  if (!isFinite(latitude) || !isFinite(longitude)) return "Not advertised"
  return latitude.toFixed(5) + ", " + longitude.toFixed(5)
}

function mapPoints(items) {
  var list = safeArray(items)
  var located = []
  var latitudeSum = 0
  for (var i = 0; i < list.length; i++) {
    var item = list[i]
    if (!item || !item.hasLocation) continue
    var latitude = Number(item.latitude)
    var longitude = Number(item.longitude)
    if (!isFinite(latitude) || !isFinite(longitude)
        || latitude < -90 || latitude > 90
        || longitude < -180 || longitude > 180) continue
    located.push(item)
    latitudeSum += latitude
  }
  if (located.length === 0) return []

  var averageLatitude = latitudeSum / located.length
  var longitudeScale = Math.max(0.01, Math.cos(averageLatitude * Math.PI / 180))
  var minX = Infinity
  var maxX = -Infinity
  var minY = Infinity
  var maxY = -Infinity
  for (var j = 0; j < located.length; j++) {
    var projectedX = Number(located[j].longitude) * longitudeScale
    var projectedY = Number(located[j].latitude)
    minX = Math.min(minX, projectedX)
    maxX = Math.max(maxX, projectedX)
    minY = Math.min(minY, projectedY)
    maxY = Math.max(maxY, projectedY)
  }
  var centerX = (minX + maxX) / 2
  var centerY = (minY + maxY) / 2
  var span = Math.max(maxX - minX, maxY - minY, 0.01)
  var result = []
  for (var k = 0; k < located.length; k++) {
    var source = located[k]
    var copy = {}
    var keys = Object.keys(source)
    for (var keyIndex = 0; keyIndex < keys.length; keyIndex++)
      copy[keys[keyIndex]] = source[keys[keyIndex]]
    copy.mapX = 0.5 + ((Number(source.longitude) * longitudeScale - centerX) / span) * 0.82
    copy.mapY = 0.5 - ((Number(source.latitude) - centerY) / span) * 0.82
    result.push(copy)
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
