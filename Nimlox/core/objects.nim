# Objects!

proc newObj*[T](vm: var VM, kind: ObjKind): ptr T =
  result = cast[ptr T](loxAlloc("newObj", sizeof T))
  result.obj.kind = kind
  result.obj.next = vm.objects
  vm.objects = result.obj.addr

proc freeSubtypeData(os: ObjString) =
  free(os.rawString)

proc free*(obj: Obj) =
  # Free any Obj fields here
  case obj.kind:
  of kString:
    freeSubtypeData obj
  loxFree(&"Obj({$obj.kind})", obj, sizeof(ObjString)) # TODO: Figure out actual size here!

proc `$`*(obj: Obj): string =
  case obj.kind:
  of kString:
    $cast[ObjString](obj).rawString
