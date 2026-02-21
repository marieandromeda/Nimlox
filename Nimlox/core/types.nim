##  Shared types go in here. This helps to prevent circular module references.
##  To keep everything kosher, add new types here, and new modules to core.nim.
##
##  We treat RawString as a distinct type from Vec[char] to keep the API more
##  type-safe. There are methods here that only apply to mutable RawStrings,
##  and some conversions for ergonomics.
## FIXME: The above is currently untrue.

type
  RawString* = Vec[char]
  RawHash* = uint32

  ObjKind* = enum
    kString,

  ObjRec* = object
    kind*: ObjKind
    next*: ptr ObjRec           # unowned

  Obj* = ptr ObjRec             # owned

  ObjStringRec* = object
    obj*: ObjRec
    rawString*: RawString
    hash*: RawHash

  ObjString* = ptr ObjStringRec # owned

  Entry* = object
    key*: ObjString
    value*: Value

  Table* = object
    len*: int
    capacity*: int
    entries*: Vec[Entry]

  OpCode* = enum
    opReturn,
    opConstant,
    opConstant24,
    opNil,
    opTrue,
    opFalse,
    opEqual,
    opGreater,
    opLess,
    opAdd,
    opSubtract,
    opMultiply,
    opDivide,
    opNot,
    opNegate,

  Chunk* = object
    code*: Vec[uint8]           #owned
    count*: int
    constants*: Vec[Value]      #owned
    lines*: Vec[int]            #owned

  VM* = object
    chunk*: Chunk
    ip*: ptr uint8              # unowned
    stack*: array[stackMax, Value]
    stackTop*: uint
    objects*: Obj

  InterpretResult* = enum
    irOK,
    irCompileError,
    irRuntimeError,

  # - Value

  ValueKind* = enum
    vkBool,
    vkNil,
    vkNumber,
    vkObj,

  Value* = object
    case kind*: ValueKind
    of vkBool:
      asBool*: bool
    of vkNumber:
      asNumber*: float
    of vkNil:
      nil # nil ! nil !!! NIL!!!!
    of vkObj:
      asObj*: Obj
