# Values!

func `$`*(value: Value): string =
  case value.kind:
  of vkNil: "nil"
  of vkBool: $value.asBool
  of vkNumber: $value.asNumber
  of vkObj: $value.asObj

proc newValue*(value: float): Value =
  Value(kind: vkNumber, asNumber: value)

proc newValue*(value: bool): Value =
  Value(kind: vkBool, asBool: value)

proc newValue*(value: Obj): Value =
  Value(kind: vkObj, asObj: value)

proc newValueNil*(): Value =
  Value(kind: vkNil)

func isBool*(value: Value): bool {.inline.} = value.kind == vkBool
func isNumber*(value: Value): bool {.inline.} = value.kind == vkNumber
func isNil*(value: Value): bool {.inline.} = value.kind == vkNil
func isObj*(value: Value): bool {.inline.} = value.kind == vkObj

func isObjKind*(value: Value, kind: ObjKind): bool {.inline.} =
  value.isObj and value.asObj.kind == kind

func isString*(value: Value): bool {.inline.} =
  value.isObjKind(kString)

func isFalsey*(value: Value): bool =
  value.isNil or (value.isBool and not value.asBool)

func asObjString*(value: Value): ObjString {.inline.} =
  assert value.isObjKind(kString)
  cast[ObjString](value.asObj)

func asRawString*(value: Value): RawString {.inline.} =
  value.asObjString.rawString

func asString*(value: Value): string {.inline.} =
  $value.asRawString

func valuesEqual*(a, b: Value): bool =
  if a.kind != b.kind: return false
  return case a.kind:
  of vkBool: a.asBool == b.asBool
  of vkNil: true
  of vkNumber: a.asNumber == b.asNumber
  of vkObj: a.asString == b.asString
