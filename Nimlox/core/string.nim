# Strings!

import std/strformat

# Pure function that returns a simple hash from a RawString.
# This uses the classic and simple FNV-1a hash function.
func hash(string: RawString): RawHash =
  result = 2166136261u32
  for i in 0 ..< string.len:
    let c = string.data[i]
    if c == '\0': # Sometimes the string is null-terminated, but we don't want that in the hash.
      break
    let h = c.RawHash
    result = (result xor h) * 16777619u32
  debugEcho &"hash({string}[{string.len}]) -> {result}"

# Computes the `hash` field from the rawString.
proc computeHash*(string: var ObjString) =
  string.hash = string.rawString.hash

# Creates a new ObjString that takes ownership of `chars`.
proc takeObjString*(vm: var VM, chars: ptr UncheckedArray[char], length: int): ObjString =
  result = newObj[ObjStringRec](vm, kString)
  result.rawString.takeData(chars, length)
  result.computeHash()

# Creates a copy of the given cstring and stores it in an ObjString,
proc copyObjString*(vm: var VM; chars: cstring): ObjString =
  let length = chars.len + 1
  var heapChars = cast[ptr UncheckedArray[char]](loxAlloc("copyObjString", length))
  heapChars[length] = '\0'
  copyMem(heapChars, chars, length)
  return vm.takeObjString(heapChars, length)

# - Conversions

func peek*(v: Vec[char]): ptr UncheckedArray[char] =
  cast[ptr UncheckedArray[char]](v.getPtr(0))
