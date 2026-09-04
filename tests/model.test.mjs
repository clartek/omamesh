import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../Model.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\s*/, "")
const model = {}
vm.createContext(model)
vm.runInContext(source, model, { filename: "Model.js" })

let parsed = model.parseCompanionName('"Radio"')
assert.equal(parsed.ok, true)
assert.equal(parsed.name, "Radio")
parsed = model.parseCompanionName("{}")
assert.equal(parsed.ok, false)
assert.equal(parsed.name, "")
parsed = model.parseCompanionName("not json")
assert.equal(parsed.ok, false)
assert.equal(parsed.name, "")
assert.equal(model.serialPort("/dev/ttyUSB2"), "/dev/ttyUSB2")
assert.equal(model.serialPort("/tmp/not-a-device"), "/dev/ttyACM0")
assert.equal(model.transport("TCP"), "tcp")
assert.equal(model.transport("unknown"), "serial")
assert.equal(model.tcpHost("mesh.local"), "mesh.local")
assert.equal(model.tcpHost("bad host"), "127.0.0.1")
assert.equal(model.tcpPort(65535), 65535)
assert.equal(model.tcpPort(70000), 5000)
assert.equal(model.bleTarget("MeshCore-Fixture"), "MeshCore-Fixture")
assert.equal(model.bleTarget("bad target"), "")
assert.deepEqual(
  Array.from(model.connectionArguments("tcp", { tcpHost: "mesh.local", tcpPort: 5001 })),
  ["-t", "mesh.local", "-p", "5001"]
)
assert.deepEqual(
  Array.from(model.connectionArguments("serial", { serialPort: "/dev/ttyUSB2" })),
  ["-s", "/dev/ttyUSB2"]
)
assert.deepEqual(
  Array.from(model.connectionArguments("ble", { bleTarget: "MeshCore-Fixture", blePair: true })),
  ["-a", "MeshCore-Fixture", "-P"]
)
assert.equal(model.clampCommandTimeout(1), 3)
assert.equal(model.clampCommandTimeout(999), 60)
assert.equal(model.totalUnread([{ unreadCount: 2 }, { unreadCount: "3" }, null]), 5)
let contacts = model.parseContacts(JSON.stringify({
  secretMapKey: {
    adv_name: "Repeater One", type: 2,
    public_key: "00112233445566778899aabbccddeeff", out_path_len: 2,
    last_advert: 1000, adv_lat: 41.2565, adv_lon: -95.9345
  }
}))
assert.equal(contacts.ok, true)
assert.equal(contacts.items[0].name, "Repeater One")
assert.equal(contacts.items[0].typeLabel, "Repeater")
assert.equal(contacts.items[0].shortId, "001122…ddeeff")
assert.equal(contacts.items[0].lastAdvert, 1000)
assert.equal(contacts.items[0].hasLocation, true)
assert.equal(model.locationLabel(contacts.items[0]), "41.25650, -95.93450")
assert.equal(model.relativeTimeLabel(1000, 1065), "1 minute ago")
let points = model.mapPoints(contacts.items)
assert.equal(points.length, 1)
assert.equal(points[0].mapX, 0.5)
assert.equal(points[0].mapY, 0.5)
points = model.mapPoints([
  { name: "West", hasLocation: true, latitude: 41, longitude: -96 },
  { name: "East", hasLocation: true, latitude: 41, longitude: -95 }
])
assert.equal(points.length, 2)
assert.ok(points[0].mapX < points[1].mapX)
assert.ok(points.every(point => point.mapX >= 0 && point.mapX <= 1 && point.mapY >= 0 && point.mapY <= 1))
assert.equal(Object.hasOwn(contacts.items[0], "publicKey"), false)
let noLocation = model.parseContacts(JSON.stringify({
  fixture: { adv_name: "No Location", type: 1, adv_lat: 0, adv_lon: 0 }
}))
assert.equal(noLocation.items[0].hasLocation, false)
assert.equal(model.locationLabel(noLocation.items[0]), "Not advertised")
assert.equal(model.parseContacts("[]").ok, false)
let streamed = model.extractJsonDocuments('Radio> {\n"name":"brace } inside"\n}\nRadio> [{"ok":true}]')
assert.equal(streamed.documents.length, 2)
assert.equal(streamed.documents[0].name, "brace } inside")
assert.equal(streamed.documents[1][0].ok, true)
assert.equal(streamed.remainder, "")
streamed = model.extractJsonDocuments('prompt {"partial":')
assert.equal(streamed.documents.length, 0)
assert.equal(streamed.remainder, '{"partial":')
let channels = model.parseChannels(JSON.stringify([
  { channel_idx: 0, channel_name: "Public", channel_secret: "must-not-escape" },
  { channel_idx: 1, channel_name: "#local", channel_secret: "must-not-escape" }
]))
assert.equal(channels.ok, true)
assert.equal(channels.items[0].kind, "Public channel")
assert.equal(channels.items[1].kind, "Hashtag channel")
assert.equal(Object.hasOwn(channels.items[0], "channel_secret"), false)
assert.equal(model.parseBattery({ level: 3650 }), 3650)
assert.equal(model.parseBattery({ level: "invalid" }), null)
let radio = model.parseRadio({ radio_freq: 910.525, radio_bw: 62.5, radio_sf: 7, radio_cr: 5 })
assert.equal(radio.frequencyMHz, 910.525)
assert.equal(radio.label, "910.525 MHz · BW 62.5 · SF7 · CR5")
assert.equal(model.parseRadio({ radio_freq: 910.525 }), null)
assert.equal(model.batteryLabel(3650), "3.65 V")
let incoming = model.normalizeIncomingMessage({
  type: "PRIV", pubkey_prefix: "001122334455", sender_timestamp: 1234,
  text: "hello", path_len: 1
})
assert.equal(incoming.conversationId, "contact:001122334455")
assert.equal(incoming.body, "hello")
incoming = model.resolveMessageSender(incoming, contacts.items)
assert.equal(incoming.senderName, "Repeater One")
assert.equal(model.normalizeIncomingMessage({ type: "PRIV", text: "missing identity", sender_timestamp: 1 }), null)
let signedIncoming = model.normalizeIncomingMessage({
  type: "PRIV", pubkey_prefix: "ffeeddccbbaa", signature: "00112233",
  sender_timestamp: 1234, text: "signed"
})
signedIncoming = model.resolveMessageSender(signedIncoming, contacts.items)
assert.equal(signedIncoming.senderName, "Repeater One")
let anonymousChannel = model.normalizeIncomingMessage({
  type: "CHAN", channel_idx: 0, sender_timestamp: 1234, text: "channel"
})
anonymousChannel = model.resolveMessageSender(anonymousChannel, contacts.items)
assert.equal(anonymousChannel.senderName, "")
let namedChannel = model.normalizeIncomingMessage({
  type: "CHAN", channel_idx: 0, sender_timestamp: 1234, text: "Casey: hello mesh"
})
assert.equal(namedChannel.senderName, "Casey")
assert.equal(namedChannel.body, "hello mesh")
assert.equal(namedChannel.senderVerified, false)
let history = model.appendUniqueMessage([], incoming, 10)
history = model.appendUniqueMessage(history, incoming, 10)
assert.equal(history.length, 1)
let unreadNodes = model.incrementUnread(contacts.items, "keyPrefix", "001122334455")
assert.equal(unreadNodes[0].unreadCount, 1)
assert.equal(model.totalUnread(channels.items, unreadNodes), 1)
unreadNodes = model.clearUnread(unreadNodes, "keyPrefix", "001122334455")
assert.equal(unreadNodes[0].unreadCount, 0)
let refreshedNodes = model.preserveUnread(contacts.items, model.incrementUnread(contacts.items, "keyPrefix", "001122334455"), "keyPrefix")
assert.equal(refreshedNodes[0].unreadCount, 1)
let secondMessage = { ...incoming, id: "later", timestamp: 2000 }
let conversation = model.messagesForConversation([secondMessage, incoming], incoming.conversationId)
assert.equal(conversation[0].timestamp, 1234)
assert.match(model.timeLabel(Math.floor(Date.now() / 1000)), /^\d{1,2}:\d{2} (AM|PM)$/)
assert.equal(model.filterByText(contacts.items, "repeater").length, 1)
assert.equal(model.filterByText(contacts.items, "does-not-exist").length, 0)
assert.equal(model.filterContacts(contacts.items, "", 2).length, 1)
assert.equal(model.filterContacts(contacts.items, "", 1).length, 0)
assert.equal(model.filterContacts(contacts.items, "repeater", -1).length, 1)
assert.equal(model.utf8ByteLength("hello"), 5)
assert.equal(model.utf8ByteLength("rocket 🚀"), 11)
assert.equal(model.sendByteLength("channel:0", "hello", "Radio"), 12)
let sendCommand = model.buildSendCommand("contact:001122334455", "it's ready")
assert.equal(sendCommand.ok, true)
assert.equal(sendCommand.kind, "direct")
assert.equal(sendCommand.command, "msg 001122334455 'it'\"'\"'s ready'")
sendCommand = model.buildSendCommand("channel:7", "hello #mesh", "ClarTek-Test")
assert.equal(sendCommand.command, "chan 7 'ClarTek-Test: hello #mesh'")
assert.equal(model.buildSendCommand("contact:bad", "hello").ok, false)
assert.equal(model.buildSendCommand("channel:256", "hello").ok, false)
assert.equal(model.buildSendCommand("channel:0", "line\nbreak", "Radio").ok, false)
assert.equal(model.buildSendCommand("channel:0", "🚀".repeat(41), "Radio").ok, false)
assert.equal(model.buildSendCommand("channel:0", "hello", "").ok, false)
let addChannel = model.buildAddChannelCommand("#omaha", "")
assert.equal(addChannel.ok, true)
assert.equal(addChannel.command, "add_channel '#omaha'")
assert.equal(addChannel.derivedSecret, true)
addChannel = model.buildAddChannelCommand("Private team", "00112233445566778899aabbccddeeff")
assert.equal(addChannel.command, "add_channel 'Private team' 00112233445566778899aabbccddeeff")
assert.equal(addChannel.derivedSecret, false)
assert.equal(model.buildAddChannelCommand("Too long " + "x".repeat(32), "").ok, false)
assert.equal(model.buildAddChannelCommand("Private", "not-a-key").ok, false)
assert.equal(model.buildRemoveChannelCommand(4).command, "remove_channel 4")
assert.equal(model.buildRemoveChannelCommand(0).ok, false)
assert.equal(model.buildRemoveChannelCommand(256).ok, false)
assert.equal(model.buildRemoveContactCommand("001122334455").command, "remove_contact 001122334455")
assert.equal(model.buildRemoveContactCommand("not-a-key").ok, false)
let sendResult = model.parseSendResult("direct", [
  { type: 0, expected_ack: "4802ed93", suggested_timeout: 2970 },
  { code: "4802ed93" }
], false)
assert.equal(sendResult.state, "delivered")
assert.equal(model.parseSendResult("direct", [{ expected_ack: "4802ed93" }, { code: "00000000" }], false).state, "failed")
assert.equal(model.parseSendResult("channel", [{}], false).state, "sent")
let outgoing = model.outgoingMessage("channel:7", "hello", 1234, "sent", 1)
assert.equal(outgoing.incoming, false)
assert.equal(outgoing.deliveryState, "sent")
assert.equal(
  model.safeCliError("permission denied for /dev/ttyACM0", false),
  "Permission denied for the USB serial device"
)
assert.equal(model.safeCliError("", true, "tcp"), "The TCP companion did not respond in time")
assert.equal(model.safeCliError("", true, "ble"), "The BLE companion did not respond in time")

console.log("Model tests passed.")
