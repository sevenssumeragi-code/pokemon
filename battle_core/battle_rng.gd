class_name BattleRNG
extends RefCounted
## Seedable RNG wrapper so battles are fully reproducible.

var _rng := RandomNumberGenerator.new()
var seed_value: int = 0
var call_count: int = 0

func _init(seed: int = 0) -> void:
	reseed(seed)

func reseed(seed: int) -> void:
	seed_value = seed
	_rng.seed = seed
	call_count = 0

## Integer in [0, n)
func next(n: int) -> int:
	call_count += 1
	if n <= 1:
		return 0
	return _rng.randi_range(0, n - 1)

## Integer in [lo, hi] inclusive
func range_int(lo: int, hi: int) -> int:
	call_count += 1
	return _rng.randi_range(lo, hi)

## True with probability num/den
func chance(num: int, den: int) -> bool:
	return next(den) < num

func random_float() -> float:
	call_count += 1
	return _rng.randf()

func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := next(i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

func sample(arr: Array):
	if arr.is_empty():
		return null
	return arr[next(arr.size())]
