import std/strformat
import std/sets

type
  LoxAllocator = object
    count: int
    bytes: int
    allocations: HashSet[uint]

var allocator = LoxAllocator()

proc update(allocator: var LoxAllocator; bytes, count: int) =
  allocator.bytes += bytes
  allocator.count += count

proc alloc(allocator: var LoxAllocator; name: string; bytes: int): pointer =
  result = alloc(bytes)
  let up = cast[uint](result)
  if result.isNil: raise newException(OutOfMemDefect, "alloc failed")
  when debugMemory:
    echo &"+++++   ALLOC {name}\t({bytes} bytes)\t0x{up:x}"
    allocator.update(bytes, 1)
    allocator.allocations.incl(up)

proc free(allocator: var LoxAllocator; name: string; p: pointer; bytes: int) =
  if p != nil:
    let up = cast[uint](p)
    dealloc(p)
    when debugMemory:
      echo &"-----    FREE {name}\t({bytes} bytes)\t#{up:#x}"
      allocator.update(-bytes, -1)
      allocator.allocations.excl(up)

proc realloc(allocator: var LoxAllocator; name: string; p: pointer; size, oldSize: int): pointer =
  if p.isNil: return allocator.alloc(name, size)
  let offset = size - oldSize
  let up = cast[uint](p)
  result = realloc(p, size)
  let ur = cast[uint](result)
  if result.isNil: raise newException(OutOfMemDefect, "realloc failed")
  when debugMemory:
    echo &"===== REALLOC {name}\t({size} - {oldSize} = {offset} bytes)\t0x{up:x}\t=>\t0x{ur:x}"
    allocator.update(offset, 0)
    allocator.allocations.excl(up)
    allocator.allocations.incl(ur)

proc memoryReport*() =
  when debugMemory:
    let alive = allocator.allocations.map(proc (x: uint): string = &"0x{x:x}")
    echo &"""
    +-================-+
    | TRACKER ANALYSIS |
    +-================-+
        BYTES: {allocator.bytes}
        COUNT: {allocator.count}
        ALIVE: {alive}
    """
  else: discard

# Lox shims to low-level alloc functions (gives us a hook for GC later)

proc loxAlloc*(name: string, size: int): pointer =
  result = allocator.alloc(name, size)

proc loxRealloc*(name: string, p: pointer, size: int, oldSize: int): pointer =
  result = allocator.realloc(name, p, size, oldSize)

proc loxFree*(name: string, p: pointer, size: int) =
  allocator.free(name, p, size)# sizeof(p))
