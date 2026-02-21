## Implements all scanning and tokenization phases for Nimlox.

import std/strformat

type
  Scanner* = object
    source: string
    start: int = 0
    current: int = 0
    line: int = 1

  TokenKind* = enum
    # Symbols
    tLeftParen, tRightParen,
    tLeftBrace, tRightBrace,
    tComma, tDot, tMinus, tPlus,
    tSemicolon, tSlash, tStar,
    tBang, tBangEqual,
    tEqual, tEqualEqual,
    tGreater, tGreaterEqual,
    tLess, tLessEqual,
    # Variable-length tokens
    tIdentifier, tString, tNumber,
    # Keywords
    tAnd, tClass, tElse, tFalse,
    tFor, tFun, tIf, tNil, tOr,
    tPrint, tReturn, tSuper, tThis,
    tTrue, tVar, tWhile,
    # Special boys
    tError, tEOF,

  Token* = object
    line*: int
    case kind*: TokenKind
    of tError:
      message*: string
    else:
      start*: int
      length*: int

proc newScanner*(source: string): Scanner =
  result = Scanner(source: source)

func isAtEnd(scanner: Scanner): bool =
  scanner.current >= scanner.source.len

proc makeToken*(scanner: Scanner; kind: TokenKind): Token =
  assert kind != tError, "internal scanner error (use makeErrorToken)"
  result = Token(line: scanner.line, kind: kind)
  case kind:
  of tEOF, tError: return
  else:
    result.start = scanner.start
    result.length = scanner.current - scanner.start

proc makeErrorToken(message: string): Token =
  Token(kind: tError, message: message)

# This creates a copy of the lexeme that the caller owns.
func lexeme*(scanner: Scanner, token: Token): string =
  case token.kind:
  of tError:
    result = token.message
  else:
    result = scanner.source[token.start ..< token.start + token.length]

proc advance(scanner: var Scanner): char =
  result = scanner.source[scanner.current]
  inc scanner.current

proc skip(scanner: var Scanner) =
  inc scanner.current

func peek(scanner: var Scanner): char =
  if scanner.isAtEnd: return '\0'
  scanner.source[scanner.current]

func peekNext(scanner: var Scanner): char =
  if scanner.current + 1 >= scanner.source.len: return '\0'
  scanner.source[scanner.current + 1]

proc match(scanner: var Scanner, expected: char): bool =
  if scanner.peek != expected: return false
  inc scanner.current
  return true

func isDigit(c: char): bool =
  c >= '0' and c <= '9'

func isAlpha(c: char): bool =
  (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_'

func isAlphanumeric(c: char): bool =
  c.isDigit or c.isAlpha

func checkKeyword(scanner: Scanner, start: int, length: int, rest: string, kind: TokenKind): TokenKind =
  # debugEcho &"start={start} length={length} rest={rest} scanner.current={scanner.current} scanner.start={scanner.start}"
  if scanner.source[scanner.start + start ..< scanner.current] == rest:
    return kind
  return tIdentifier

func identifierKind(scanner: var Scanner): TokenKind =
  return case scanner.source[scanner.start]:
  of 'a': scanner.checkKeyword(1, 2, "nd", tAnd)
  of 'c': scanner.checkKeyword(1, 4, "lass", tClass)
  of 'e': scanner.checkKeyword(1, 3, "lse", tElse)
  of 'f':
    if scanner.current - scanner.start > 1:
      case scanner.source[scanner.start + 1]:
      of 'a': scanner.checkKeyword(2, 3, "lse", tFalse)
      of 'o': scanner.checkKeyword(2, 1, "r", tFor)
      of 'u': scanner.checkKeyword(2, 1, "n", tFun)
      else: tIdentifier
    else: tIdentifier
  of 'i': scanner.checkKeyword(1, 1, "f", tIf)
  of 'n': scanner.checkKeyword(1, 2, "il", tNil)
  of 'o': scanner.checkKeyword(1, 1, "r", tOr)
  of 'p': scanner.checkKeyword(1, 4, "rint", tPrint)
  of 'r': scanner.checkKeyword(1, 5, "eturn", tReturn)
  of 's': scanner.checkKeyword(1, 4, "uper", tSuper)
  of 't':
    if scanner.current - scanner.start > 1:
      case scanner.source[scanner.start + 1]:
      of 'h': scanner.checkKeyword(2, 2, "is", tThis)
      of 'r': scanner.checkKeyword(2, 2, "ue", tTrue)
      else: tIdentifier
    else: tIdentifier
  of 'v': scanner.checkKeyword(1, 2, "ar", tVar)
  of 'w': scanner.checkKeyword(1, 4, "hile", tWhile)
  else: tIdentifier

proc skipWhitespaceAndComments(scanner: var Scanner) =
  while true:
    case scanner.peek:
    of ' ', '\r', '\t': scanner.skip
    of '\n':
      inc scanner.line
      scanner.skip
    of '/':
      if scanner.peekNext == '/': # A comment goes until the end of the line.
        while not scanner.isAtEnd and scanner.peek != '\n':
          scanner.skip
      else:
        return
    else:
      return

proc scanString(scanner: var Scanner): Token =
  while scanner.peek != '"':
    if scanner.peek == '\n': inc scanner.line
    scanner.skip
  if scanner.isAtEnd: return makeErrorToken("Unterminated string.")
  scanner.skip # Skip the closing quote we matched via process of elimination
  return scanner.makeToken(tString)

proc scanNumber(scanner: var Scanner): Token =
  while scanner.peek.isDigit: scanner.skip
  # Look for a fractional part
  if scanner.peek == '.' and scanner.peekNext.isDigit:
    scanner.skip # Consume the "."
    while scanner.peek.isDigit: scanner.skip
  scanner.makeToken(tNumber)

proc scanIdentifier(scanner: var Scanner): Token =
  while scanner.peek.isAlphanumeric: scanner.skip
  scanner.makeToken(scanner.identifierKind)

proc scanToken*(scanner: var Scanner): Token =
  scanner.skipWhitespaceAndComments
  scanner.start = scanner.current
  if scanner.isAtEnd:
    return Token(kind: tEOF)
  let c = advance scanner
  if c.isAlpha: return scanner.scanIdentifier
  if c.isDigit: return scanner.scanNumber
  case c:
  of '(': return scanner.makeToken(tLeftParen)
  of ')': return scanner.makeToken(tRightParen)
  of '{': return scanner.makeToken(tLeftBrace)
  of '}': return scanner.makeToken(tRightBrace)
  of ';': return scanner.makeToken(tSemicolon)
  of ',': return scanner.makeToken(tComma)
  of '.': return scanner.makeToken(tDot)
  of '-': return scanner.makeToken(tMinus)
  of '+': return scanner.makeToken(tPlus)
  of '/': return scanner.makeToken(tSlash)
  of '*': return scanner.makeToken(tStar)
  of '!': return scanner.makeToken(if scanner.match('='): tBangEqual else: tBang)
  of '=': return scanner.makeToken(if scanner.match('='): tEqualEqual else: tEqual)
  of '<': return scanner.makeToken(if scanner.match('='): tLessEqual else: tLess)
  of '>': return scanner.makeToken(if scanner.match('='): tGreaterEqual else: tGreater)
  of '"': return scanner.scanString
  else:
    return makeErrorToken(&"Unexpected character '{c}'")
