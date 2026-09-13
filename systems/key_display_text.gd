extends RefCounted
## Display-only normalization; key identifiers and lock matching stay intact.
static func clean(value: String) -> String:
	var accented := "áéíóúüñÁÉÍÓÚÜÑ"
	var plain := "aeiouunAEIOUUN"
	for index in accented.length():
		value = value.replace(accented[index], plain[index])
	for mark in ["\u0301", "\u0308", "\u0303"]:
		value = value.replace(mark, "")
	return value
