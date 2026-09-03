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
let channels = model.parseChannels(JSON.stringify([
  { channel_idx: 0, channel_name: "Public", channel_secret: "must-not-escape" },
  { channel_idx: 1, channel_name: "#local", channel_secret: "must-not-escape" }
]))
assert.equal(channels.ok, true)
assert.equal(channels.items[0].kind, "Public channel")
assert.equal(channels.items[1].kind, "Hashtag channel")
assert.equal(Object.hasOwn(channels.items[0], "channel_secret"), false)
assert.equal(
  model.safeCliError("permission denied for /dev/ttyACM0", false),
  "Permission denied for the USB serial device"
)

console.log("Model tests passed.")
