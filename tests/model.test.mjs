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
assert.equal(model.clampCommandTimeout(1), 3)
assert.equal(model.clampCommandTimeout(999), 60)
assert.equal(model.totalUnread([{ unreadCount: 2 }, { unreadCount: "3" }, null]), 5)
let contacts = model.parseContacts(JSON.stringify({
  secretMapKey: { adv_name: "Repeater One", type: 2, public_key: "00112233445566778899aabbccddeeff", out_path_len: 2 }
}))
assert.equal(contacts.ok, true)
assert.equal(contacts.items[0].name, "Repeater One")
assert.equal(contacts.items[0].typeLabel, "Repeater")
assert.equal(contacts.items[0].shortId, "001122…ddeeff")
assert.equal(Object.hasOwn(contacts.items[0], "publicKey"), false)
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
assert.equal(model.normalizeIncomingMessage({ type: "PRIV", text: "missing identity", sender_timestamp: 1 }), null)
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
assert.equal(
  model.safeCliError("permission denied for /dev/ttyACM0", false),
  "Permission denied for the USB serial device"
)

console.log("Model tests passed.")
