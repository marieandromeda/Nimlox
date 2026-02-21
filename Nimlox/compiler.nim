import core
import chunk
import debug
import scanner
import std/strformat
import std/strutils

type
  Parser = object
    scanner: Scanner
    compilingChunk: Chunk
    vm: VM
    current: Token
    previous: Token
    hadError: bool
    panicMode: bool # TODO: Use exceptions mayhaps?

  Precedence = enum
    precNone,
    precAssignment,  # =
    precOr,          # or
    precAnd,         # and
    precEquality,    # == !=
    precComparison,  # < > <= >=
    precTerm,        # + -
    precFactor,      # * /
    precUnary,       # ! -
    precCall,        # . ()
    precPrimary,

  ParseRule = object
    prefix: proc(parser: var Parser)
    infix: proc(parser: var Parser)
    precedence: Precedence

proc newRule(prefix, infix: proc(parser: var Parser); precedence: Precedence): ParseRule =
  ParseRule(prefix: prefix, infix: infix, precedence: precedence)

# - 'eclarations
func rule(operatorKind: TokenKind): ParseRule
proc number(parser: var Parser)
proc binary(parser: var Parser)
proc expression(parser: var Parser)
proc grouping(parser: var Parser)
proc unary(parser: var Parser)

proc newParser(code: string, chunk: var Chunk, vm: var VM): Parser =
  let scanner = newScanner(code)
  result = Parser(
    scanner: scanner,
    compilingChunk: chunk,
    vm: vm,
  )

# - Parser infrastructure

func lexeme(parser: Parser, token: Token): string {.inline.} =
  parser.scanner.lexeme(token)

proc currentChunk(parser: var Parser): var Chunk =
  parser.compilingChunk

proc errorAt(parser: var Parser, token: Token, message: string) =
  if parser.panicMode: return
  parser.panicMode = true
  stderr.write &"[line {token.line}] Error"
  if token.kind == tEOF:
    stderr.write " at end"
  elif token.kind == tError:
    discard
  else:
    stderr.write &" at '{parser.lexeme(token)}'"
  stderr.write &": {message}\n"
  parser.hadError = true

proc error(parser: var Parser, message: string) =
  parser.errorAt(parser.previous, message)

proc errorAtCurrent(parser: var Parser, message: string) =
  parser.errorAt(parser.current, message)

proc advance(parser: var Parser) =
  parser.previous = parser.current
  while true:
    parser.current = parser.scanner.scanToken
    if parser.current.kind != tError: break
    parser.errorAtCurrent(parser.current.message)

proc consume(parser: var Parser, tokenKind: TokenKind, message: string) =
  if parser.current.kind == tokenKind:
    advance parser
    return
  parser.errorAtCurrent(message)

proc emit(parser: var Parser, byte: uint8, line: int = -1) =
  parser.compilingChunk.write(byte, max(line, parser.previous.line))

proc emit(parser: var Parser, opCode: OpCode, line: int = -1) =
  parser.compilingChunk.write(opCode, max(line, parser.previous.line))

proc emit(parser: var Parser, opCode: OpCode, byte: uint8, line: int = -1) =
  parser.emit(opCode, line)
  parser.emit(byte, line)

proc emit(parser: var Parser, opCode: OpCode, opCode2: OpCode, line: int = -1) =
  parser.emit(opCode, line)
  parser.emit(opCode2, line)

# - Constants

proc makeConstant(parser: var Parser, value: Value): uint8 =
  let constant = parser.currentChunk.addConstant(value)
  if constant > uint8.high.int:
    # TODO: add support for opConstant24
    parser.error("Too many constants in one chunk.")
    return 0
  return constant.uint8

proc emitConstant(parser: var Parser, value: Value) =
  parser.emit(opConstant, parser.makeConstant(value))

# - Parsing logic

proc parsePrecedence(parser: var Parser, precedence: Precedence) =
  advance parser
  # Prefix expressions
  let prefixRule = parser.previous.kind.rule.prefix
  if prefixRule == nil:
    parser.error("Expected expression.")
    return
  prefixRule(parser)
  # Infix expressions
  while precedence <= parser.current.kind.rule.precedence:
    advance parser
    let infixRule = parser.previous.kind.rule.infix
    infixRule(parser)

proc number(parser: var Parser) =
  let value = parseFloat(parser.scanner.lexeme(parser.previous))
  parser.emitConstant(newValue(value))

proc string(parser: var Parser) =
  let token = parser.previous
  # echo &"getting lexeme[1 .. {token.length} - 2] of {token}; scanner = {parser.scanner}"
  let text = parser.lexeme(token)[1 .. token.length - 2]
  let string = parser.vm.copyObjString(text.cstring)
  let value = newValue(cast[Obj](string))
  parser.emitConstant(value)

proc binary(parser: var Parser) =
  let operatorKind = parser.previous.kind
  let rule = rule(operatorKind)
  parser.parsePrecedence(rule.precedence.succ)
  case operatorKind
    of tBangEqual: parser.emit(opEqual, opNot)
    of tEqualEqual: parser.emit(opEqual)
    of tGreater: parser.emit(opGreater)
    of tGreaterEqual: parser.emit(opLess, opNot)
    of tLess: parser.emit(opLess)
    of tLessEqual: parser.emit(opGreater, opNot)
    of tPlus: parser.emit(opAdd)
    of tMinus: parser.emit(opSubtract)
    of tStar: parser.emit(opMultiply)
    of tSlash: parser.emit(opDivide)
    else: return # TODO: Unreachable if code is sane, maybe raise an error?

proc literal(parser: var Parser) =
  parser.emit case parser.previous.kind:
  of tFalse: opFalse
  of tNil: opNil
  of tTrue: opTrue
  else: return # TODO: Unreachable if code is sane, maybe raise an error?

proc expression(parser: var Parser) =
  parser.parsePrecedence(precAssignment)

proc grouping(parser: var Parser) =
  parser.expression()
  parser.consume(tRightParen, "Expected ')' after expression.")

proc unary(parser: var Parser) =
  let operatorKind = parser.previous.kind
  let line = parser.previous.line
  parser.parsePrecedence(precUnary)
  case operatorKind:
  of tBang: parser.emit(opNot, line)
  of tMinus: parser.emit(opNegate, line)
  else: return # TODO: Unreachable if code is sane, maybe raise an error?

const rules: array[40, ParseRule] = [
  tLeftParen:    newRule(grouping, nil,    precNone),
  tRightParen:   newRule(   nil,   nil,    precNone),
  tLeftBrace:    newRule(  nil,    nil,    precNone),
  tRightBrace:   newRule(  nil,    nil,    precNone),
  tComma:        newRule(   nil,   nil,    precNone),
  tDot:          newRule(   nil,   nil,    precNone),
  tMinus:        newRule(unary,    binary, precTerm),
  tPlus:         newRule(nil,      binary, precTerm),
  tSemicolon:    newRule(nil,      nil,    precNone),
  tSlash:        newRule(nil,      binary, precFactor),
  tStar:         newRule( nil,     binary, precFactor),
  tBang:         newRule(unary,    nil,    precNone),
  tBangEqual:    newRule(   nil,   binary, precEquality),
  tEqual:        newRule(    nil,  nil,    precNone),
  tEqualEqual:   newRule(     nil, binary, precEquality),
  tGreater:      newRule(     nil, binary, precComparison),
  tGreaterEqual: newRule(     nil, binary, precComparison),
  tLess:         newRule(     nil, binary, precComparison),
  tLessEqual:    newRule(    nil,  binary, precComparison),
  tIdentifier:   newRule(   nil,   nil,    precNone),
  tString:       newRule(string,   nil,    precNone),
  tNumber:       newRule(number,   nil,    precNone),
  tAnd:          newRule(  nil,    nil,    precNone),
  tClass:        newRule( nil,     nil,    precNone),
  tElse:         newRule(  nil,    nil,    precNone),
  tFalse:        newRule(literal,  nil,    precNone),
  tFor:          newRule(   nil,   nil,    precNone),
  tFun:          newRule(  nil,    nil,    precNone),
  tIf:           newRule(  nil,    nil,    precNone),
  tNil:          newRule(literal,  nil,    precNone),
  tOr:           newRule(   nil,   nil,    precNone),
  tPrint:        newRule(  nil,    nil,    precNone),
  tReturn:       newRule( nil,     nil,    precNone),
  tSuper:        newRule( nil,     nil,    precNone),
  tThis:         newRule(  nil,    nil,    precNone),
  tTrue:         newRule(literal,  nil,    precNone),
  tVar:          newRule(  nil,    nil,    precNone),
  tWhile:        newRule( nil,     nil,    precNone),
  tError:        newRule(nil,      nil,    precNone),
  tEOF:          newRule(nil,      nil,    precNone),
]

func rule(operatorKind: TokenKind): ParseRule =
  rules[operatorKind.ord]

# - Compilation

proc endCompiler(parser: var Parser) =
  parser.emit(opReturn)
  when debugPrintCode:
    if not parser.hadError:
      parser.currentChunk.disassemble("code")

proc compile*(vm: var VM, code: string, chunk: var Chunk): bool =
  var parser = newParser(code, chunk, vm)
  parser.advance
  parser.expression()
  parser.consume(tEOF, "Expected end of expression.")
  parser.endCompiler()
  chunk = parser.compilingChunk
  not parser.hadError
