extends Node

func get_signed_komi_hash(path:String) -> int: return Gob.new().get_signed_komi_hash(path)
func get_unsigned_komi_hash(path:String) -> String: return Gob.new().get_unsigned_komi_hash(path)
