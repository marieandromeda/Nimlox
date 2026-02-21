# For internal type safety, we only convert from RawString to Vec,
# not the other way around!
converter toVec*(s: var RawString): var Vec[char] = Vec[char](s)
converter toVec*(s: RawString): Vec[char] = Vec[char](s)

# Any Obj "subclasses" should be able to be "downcast" to Obj.
converter asObj*(obj: ObjString): Obj = cast[Obj](obj)

# "Upcasting" is fine too, but the caller is responsible for checking the type.
converter asObjString*(obj: Obj): ObjString = cast[ObjString](obj)

converter asString*(objString: ObjString): string = $objString.rawString
