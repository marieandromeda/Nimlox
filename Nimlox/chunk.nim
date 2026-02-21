import core

func newChunk*(): Chunk =         # managed
  result = Chunk(
    code: newVec[uint8](),        # owned
    count: 0,
    constants: newVec[Value](),   # owned
    lines: newVec[int]()          # owned
  )

proc free*(chunk: var Chunk) =
  chunk.code.free()
  chunk.constants.free()
  chunk.lines.free()

proc write*(chunk: var Chunk, byte: uint8, line: int) =
  chunk.code.add(byte)
  chunk.lines.add(line)
  inc chunk.count

proc write*(chunk: var Chunk, opcode: OpCode, line: int) =
  chunk.write(opcode.ord.uint8, line)

iterator items*(chunk: Chunk): uint8 =
  var i = 0
  while i < chunk.count:
    yield chunk.code[i]
    inc i

proc addConstant*(chunk: var Chunk, value: Value): int =
  chunk.constants.add(value)
  return chunk.constants.len - 1

proc getConstant*(chunk: Chunk, offset: int): Value =
  return chunk.constants[offset]
