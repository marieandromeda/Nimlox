import chunk
import core
import std/strformat

const debugPrintCode* = true
const debugTraceExecution* = true

proc simpleInstruction(name: string, offset: int): int =
  echo name
  return offset + 1

proc constantInstruction(name: string, chunk: Chunk, offset: int, length: int): int =
  var constant: int
  for i in 1..length:
    constant = (constant shl 8) + chunk.code[offset + i].int
  stdout.write &"{name:-16s} 0x{constant:.6X} '"
  stdout.write chunk.getConstant(constant.int)
  stdout.write "'\n"
  return offset + length + 1

proc disassembleInstruction*(chunk: Chunk, offset: int): int =
  stdout.write &"{offset:04} "

  if offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]:
    stdout.write "   | "
  else:
    stdout.write &"{chunk.lines[offset]:4d} "

  let raw = chunk.code[offset].int
  if raw > OpCode.high.ord:
    echo &"Unknown opcode 0x{raw:02x}"
    return offset + 1

  let instruction = OpCode(raw)
  return case instruction:
  of opReturn:
    simpleInstruction("Return", offset)
  of opConstant:
    constantInstruction("Constant", chunk, offset, 1)
  of opConstant24:
    constantInstruction("Constant24", chunk, offset, 3)
  of opNil:
    simpleInstruction("Nil", offset)
  of opTrue:
    simpleInstruction("True", offset)
  of opFalse:
    simpleInstruction("False", offset)
  of opEqual:
    simpleInstruction("Equal", offset)
  of opGreater:
    simpleInstruction("Greater", offset)
  of opLess:
    simpleInstruction("Less", offset)
  of opAdd:
    simpleInstruction("Add", offset)
  of opSubtract:
    simpleInstruction("Subtract", offset)
  of opMultiply:
    simpleInstruction("Multiply", offset)
  of opDivide:
    simpleInstruction("Divide", offset)
  of opNot:
    simpleInstruction("Not", offset)
  of opNegate:
    simpleInstruction("Negate", offset)

proc disassemble*(chunk: Chunk, name: string) =
  echo &"====== {name} ======"
  echo &"Code: {chunk.code}"
  var offset = 0
  while offset < chunk.count:
    offset = disassembleInstruction(chunk, offset)
