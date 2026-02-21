import Nimlox/core
import Nimlox/vm
import std/cmdline
import std/rdstdin

proc repl(vm: var VM) =
  var line: string
  while true:
    let ok = readLineFromStdin("> ", line)
    if not ok:
      break # ctrl-C or ctrl-D will cause a break
    if line.len > 0:
      discard vm.interpret(line)

proc runFile(vm: var VM, path: string) =
  let source = readFile(path)
  let result = vm.interpret(source)
  if result == irCompileError: quit(65)
  if result == irRuntimeError: quit(70)

when isMainModule:
  var mainVM = newVM()
  let args = commandLineParams()
  if args.len == 0:
    mainVM.repl()
  elif args.len == 1:
    mainVM.runFile(args[0])
  else:
    stderr.write "Usage: nimlox [path]\n"
    quit(64)
  mainVM.free()
