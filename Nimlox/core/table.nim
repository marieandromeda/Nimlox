const tableMaxLoad = 0.75

when tableMaxLoad >= 1.0:
  doAssert(tableMaxLoad < 1.0, "Bro stop it mang")

proc newTable*(): Table =
  Table(
    len: 0,
    capacity: 0,
    entries: newVec[Entry](),
  )

proc newEntry(): Entry =
  Entry()

proc free*(table: var Table) =
  table.entries.free()

func findEntry(entries: Vec[Entry], key: ObjString): ptr Entry =
  let capacity = entries.capacity
  var index = key.hash.int mod capacity
  var tombstone: ptr Entry = nil
  while true:
    let entry = entries.getPtr(index)
    if entry.key == nil:
      if entry.value.isNil:
        return if tombstone != nil: tombstone else: entry
      elif tombstone == nil: tombstone = entry
    elif entry.key == key:
      return entry
    index = (index + 1) mod capacity

func findEntry(table: Table, key: ObjString): ptr Entry =
  table.entries.findEntry(key)

proc adjustCapacity(table: var Table, capacity: int) =
  var entries = newVec[Entry]()
  entries.setLen(capacity)
  for i in 0 ..< capacity:
    entries[i] = newEntry()
  for i in 0 ..< table.entries.capacity:
    var entry = table.entries.getPtr(i)
    if entry.key == nil: continue
    var dest = table.findEntry(entry.key)
    dest.key = entry.key
    dest.value = entry.value
  table.entries.free()
  table.entries = entries

func `[]`*(table: Table, key: ObjString): ptr Value =
  let entry = table.findEntry(key)
  return if entry != nil: entry[].value.addr else: nil

proc set(table: var Table, key: ObjString, value: Value): bool =
  if table.entries.len + 1 > int(table.entries.capacity.float * tableMaxLoad):
    let capacity = growCapacity(table.entries.capacity)
    table.adjustCapacity(capacity)
  var entry = table.findEntry(key)
  result = entry.key == nil
  entry.key = key
  entry.value = value

proc `[]=`*(table: var Table, key: ObjString, value: Value) =
  discard table.set(key, value)

proc addAll(dest: var Table, src: Table) =
  for i in 0 ..< src.entries.capacity:
    var entry = src.entries.getPtr(i)
    if entry.key != nil:
      dest[entry.key] = entry.value

proc delete(table: var Table, key: ObjString): bool =
  if table.entries.len == 0: return false
  let entry = table.findEntry(key)
  if entry == nil: return false
  # TOMBSTONE!
  entry.key = nil
  entry.value = newValue(true)
  return true
