import chunk
import compiler
import debug
import core
import std/strformat

proc newVM*(chunk: Chunk = newChunk()): VM =
  result = VM(
    chunk: chunk,
    ip: chunk.code.getPtr,
    objects: nil,
  )

proc freeObjects(vm: var VM) =
  var obj = vm.objects
  while obj != nil:
    let next = obj.next
    free obj
    obj = next

proc free*(vm: var VM) =
  vm.chunk.free()
  vm.freeObjects()
  memoryReport()

proc resetStack(vm: var VM) =
  vm.stackTop = 0

func peek(vm: var VM, distance: int = 0): Value =
  return vm.stack[vm.stackTop.int - 1 - distance]

proc push(vm: var VM, value: Value) =
  vm.stack[vm.stackTop] = value
  inc vm.stackTop

proc pop(vm: var VM): Value =
  dec vm.stackTop
  return vm.stack[vm.stackTop]

proc next(vm: var VM): uint8 {.inline.} =
  result = vm.ip[]
  vm.ip = cast[ptr uint8](cast[uint](vm.ip) + 1'u)

proc prev(vm: var VM, offset: uint = 1): uint8 {.inline.} =
  result = vm.ip[]
  vm.ip = cast[ptr uint8](cast[uint](vm.ip) - offset)

proc runtimeError(vm: var VM, error: string): InterpretResult =
  stderr.write error & "\n"
  # The interpreter advances past each instruction before executing it. At the
  # point that we call runtimeError(), the failed instruction is the previous one.
  let line = vm.chunk.lines[vm.prev.int]
  stderr.write &"[line {line}] in script\n"
  vm.resetStack()

proc concatenate(vm: var VM) =
  let (b, a) = (vm.pop.asString, vm.pop.asString)
  let length = a.len + b.len
  var chars = cast[ptr UncheckedArray[char]](loxAlloc("concatenate", length + 1))
  copyMem(chars, a.cstring, a.len)
  copyMem(cast[ptr UncheckedArray[char]](cast[uint](chars) + a.len.uint), b.cstring, b.len)
  chars[length] = '\0'
  let result = vm.takeObjString(chars, length)
  vm.push(newValue(result))

proc run(vm: var VM): InterpretResult =
  while true:
    when debugTraceExecution:
      stdout.write "          "
      for slot in 0..<vm.stackTop:
        stdout.write &"[ {vm.stack[slot]} ]"
      echo ""
      discard disassembleInstruction(vm.chunk, int(cast[uint](vm.ip) - cast[uint](vm.chunk.code.getPtr)))
    let instruction = vm.next.OpCode
    case instruction:
    of opReturn:
      echo vm.pop
      return irOK
    of opConstant:
      let constant = vm.chunk.getConstant(vm.next.int)
      vm.push constant
    of opConstant24:
      let (a, b, c) = ((vm.next.int shl 16), (vm.next.int shl 8), (vm.next.int))
      let offset = a + b + c
      let constant = vm.chunk.getConstant(offset)
      vm.push constant
    of opNil: vm.push newValueNil()
    of opTrue: vm.push newValue(true)
    of opFalse: vm.push newValue(false)
    of opEqual:
      let (b, a) = (vm.pop, vm.pop)
      vm.push(newValue(valuesEqual(a, b)))
    of opGreater:
      if not vm.peek(0).isNumber or not vm.peek(1).isNumber:
        return vm.runtimeError("Operands must be numbers.")
      let (b, a) = (vm.pop.asNumber, vm.pop.asNumber)
      vm.push(newValue(a > b))
    of opLess:
      if not vm.peek(0).isNumber or not vm.peek(1).isNumber:
        return vm.runtimeError("Operands must be numbers.")
      let (b, a) = (vm.pop.asNumber, vm.pop.asNumber)
      vm.push(newValue(a < b))
    of opAdd:
      if vm.peek(0).isString and vm.peek(1).isString:
        vm.concatenate()
      elif vm.peek(0).isNumber and vm.peek(1).isNumber:
        let (b, a) = (vm.pop.asNumber, vm.pop.asNumber)
        vm.push(newValue(a + b))
      else:
        return vm.runtimeError("Operands must be two numbers or two strings.")
    of opSubtract:
      if not vm.peek(0).isNumber or not vm.peek(1).isNumber:
        return vm.runtimeError("Operands must be numbers.")
      let (b, a) = (vm.pop.asNumber, vm.pop.asNumber)
      vm.push(newValue(a - b))
    of opMultiply:
      if not vm.peek(0).isNumber or not vm.peek(1).isNumber:
        return vm.runtimeError("Operands must be numbers.")
      let (b, a) = (vm.pop.asNumber, vm.pop.asNumber)
      vm.push(newValue(a * b))
    of opDivide:
      if not vm.peek(0).isNumber or not vm.peek(1).isNumber:
        return vm.runtimeError("Operands must be numbers.")
      let (b, a) = (vm.pop.asNumber, vm.pop.asNumber)
      vm.push(newValue(a / b))
    of opNot:
      vm.push(newValue(vm.pop.isFalsey))
    of opNegate:
      if not vm.peek.isNumber:
        return vm.runtimeError("Operand must be a number.")
      vm.push(newValue(-vm.pop.asNumber))

proc interpret*(vm: var VM, chunk: Chunk): InterpretResult =
  vm.chunk = chunk
  vm.ip = vm.chunk.code.getPtr
  return vm.run

proc interpret*(vm: var VM, code: string): InterpretResult =
  var chunk = newChunk()
  if not vm.compile(code, chunk):
    free chunk
    return irCompileError
  vm.chunk = chunk
  vm.ip = vm.chunk.code.getPtr
  result = vm.run()
  free chunk
