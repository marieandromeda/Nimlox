# Vec is a simple dynamic array type.
#
# I chose to implement this type independently and not use `seq[]` because I
# wanted to be able to more closely mirror the book, as well as have full
# control over the implementation.
#
# TODO: Might be nice to fully separate this code from the other core code,
# depending only on memory.nim.

type
  Vec*[T] = object
    data*: ptr UncheckedArray[T]
    len*: int
    capacity*: int

# - Low-level helpers

template elemPtr[T](v: Vec[T], i: int): ptr T =
  cast[ptr T](cast[uint](v.data) + uint(i * sizeof(T)))

proc reserveRaw[T](v: var Vec[T], newCapacity: int) =
  if newCapacity <= v.capacity: return
  let size = newCapacity * sizeof(T)
  if v.data.isNil:
    v.data = cast[ptr UncheckedArray[T]](loxAlloc("Vec[" & $T & "].data", size))
  else:
    v.data = cast[ptr UncheckedArray[T]](loxRealloc("Vec[" & $T & "].data", cast[pointer](v.data), size, v.capacity * sizeof(T)))
  if v.data.isNil:
    raise newException(OutOfMemDefect, "Vec reserve failed")
  v.capacity = newCapacity

func growCapacity*(oldCapacity: int): int =
  if oldCapacity < 8: 8 else: oldCapacity + oldCapacity shr 1   # ~1.5x growth

# - Public API

proc newVec*[T](): Vec[T] =
  Vec[T](data: nil, len: 0, capacity: 0)

proc free*[T](v: var Vec[T]) =
  # Call destructors if T has one.
  when compiles(proc(x: var T) = `=destroy`(x)):
    for i in 0 ..< v.len:
      var tmp = v.elemPtr(i)[]
      `=destroy`(tmp)
  if not v.data.isNil:
    loxFree("Vec[" & $T & "].data", v.data, v.capacity * sizeof(T))
    v.data = nil
    v.len = 0
    v.capacity = 0

# Replace the contents of the vector with the passed in `data`.
# The Vec will own the memory management of this value from now on. This should
# only be used when the data has been allocated but will not be manually freed.
proc takeData*[T](v: var Vec[T], data: ptr UncheckedArray[T], len: int) =
  v.data = data
  v.capacity = len
  v.len = len

# Produce a human-readable string like: [a, b, c].
proc `$`*[T](v: Vec[T]): string =
  result = "["
  for i in 0 ..< v.len:
    if i > 0:
      result.add(", ")
    result.add($v.data[i])
  result.add("]")

# Special case for strings
proc `$`*(v: Vec[char]): string =
  $cast[cstring](v.data[])

# Force an increase to the capacity
proc reserve*[T](v: var Vec[T], minCapacity: int) =
  if minCapacity > v.capacity: v.reserveRaw(minCapacity)

proc shrinkToFit*[T](v: var Vec[T]) =
  if v.len == 0:
    if not v.data.isNil:
      loxFree("Vec.data", cast[pointer](v.data))
    v.data = nil
    v.capacity = 0
  elif v.len < v.capacity:
    let size = v.len * sizeof(T)
    v.data = cast[ptr UncheckedArray[T]](
      loxRealloc(cast[pointer](v.data), size, v.capacity * sizeof(T))
    )
    v.capacity = v.len

# Add one element to the vector.
proc add*[T](v: var Vec[T], x: sink T) =
  if v.len == v.capacity:
    v.reserveRaw(growCapacity(v.capacity))
  v.elemPtr(v.len)[] = x
  inc v.len

proc pop*[T](v: var Vec[T]): T =
  doAssert v.len > 0, "pop on empty Vec"
  dec v.len
  result = v.elemPtr(v.len)[]      # move out
  when compiles(proc (x: var T) = `=destroy`(x)):
    # clear the slot to help destructors if needed
    var tmp = default(T)
    v.elemPtr(v.len)[] = tmp

# Grows or shrinks length; newly grown items are default(T).
proc setLen*[T](v: var Vec[T], newLen: int) =
  doAssert newLen >= 0
  if newLen > v.capacity: v.reserveRaw(newLen)
  when compiles(proc (x: var T) = `=destroy`(x)):
    if newLen < v.len:
      # run destructors on trailing slice
      for i in countdown(v.len - 1, newLen):
        var tmp = v.elemPtr(i)[]
        `=destroy`(tmp)
  if newLen > v.len:
    # default-initialize new tail
    for i in v.len ..< newLen:
      v.elemPtr(i)[] = default(T)
  v.len = newLen

proc getPtr*[T](v: Vec[T], i: int = 0): ptr T =
  v.elemPtr(i)

proc `[]`*[T](v: Vec[T], i: int): lent T =
  assert 0 <= i and i < v.len, "Attempted to access Vec out of bounds!"
  v.elemPtr(i)[]

template `[]`*[T](v: ptr Vec[T], i: int): ptr T = v[][i].addr

proc `[]=`*[T](v: var Vec[T], i: int, x: sink T) =
  doAssert 0 <= i and i < v.len
  v.elemPtr(i)[] = x

proc clear*[T](v: var Vec[T]) =
  v.setLen(0)

# Remove without preserving order (fast)
proc removeSwap*[T](v: var Vec[T], i: int) =
  doAssert 0 <= i and i < v.len
  let last = v.len - 1
  if i != last:
    v.elemPtr(i)[] = v.elemPtr(last)[]
  dec v.len
  when compiles(proc (x: var T) = `=destroy`(x)):
    var tmp = default(T)
    v.elemPtr(v.len)[] = tmp

# - Tests

when isMainModule:
  var v = newVec[uint8]()
  for i in 0u8 .. 20u8: v.add(i)
  echo "len=", v.len, " capacity=", v.capacity
  doAssert v.len == 21
  echo "v[3]=", v[3]
  doAssert v[3] == 3
  let popped = v.pop()
  echo "v.pop() ", popped, " len=", v.len
  doAssert popped == 20 and v.len == 20
  v.setLen(5)
  echo "len=", v.len, " capacity=", v.capacity
  doAssert v.len == 5
  v.shrinkToFit()
  echo "len=", v.len, " capacity=", v.capacity
  doAssert v.capacity == v.len and v.len == 5
  v.free()
  doAssert v.len == 0
  v.reserve(100)
  echo "len=", v.len, " capacity=", v.capacity
  doAssert v.capacity == 100 and v.len == 0
