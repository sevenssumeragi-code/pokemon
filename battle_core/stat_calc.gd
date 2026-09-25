class_name StatCalc
extends RefCounted
## Main-series stat formulas (Gen 3+).

const STATS := ["hp", "atk", "def", "spa", "spd", "spe"]
const BOOSTABLE := ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]

static func calc_hp(base: int, iv: int, ev: int, level: int) -> int:
	if base == 1: # Shedinja rule
		return 1
	return int(floor((2 * base + iv + int(floor(ev / 4.0))) * level / 100.0)) + level + 10

static func calc_stat(base: int, iv: int, ev: int, level: int, nature_mult: float) -> int:
	var v := int(floor((2 * base + iv + int(floor(ev / 4.0))) * level / 100.0)) + 5
	return int(floor(v * nature_mult))

static func nature_multiplier(nature_id: String, stat: String) -> float:
	var n = GameData.natures.get(nature_id)
	if n == null:
		return 1.0
	if n.get("plus") == stat:
		return 1.1
	if n.get("minus") == stat:
		return 0.9
	return 1.0

## Stage multiplier for atk/def/spa/spd/spe as (num, den).
static func boost_fraction(stage: int) -> Vector2i:
	stage = clampi(stage, -6, 6)
	if stage >= 0:
		return Vector2i(2 + stage, 2)
	return Vector2i(2, 2 - stage)

## Apply a boost stage to a stat value (Gen 5+: floor(stat * num / den)).
static func apply_boost(stat: int, stage: int) -> int:
	var f := boost_fraction(stage)
	return int(floor(stat * f.x / float(f.y)))

## Accuracy/evasion stage multiplier as (num, den) with base 3.
static func acc_fraction(stage: int) -> Vector2i:
	stage = clampi(stage, -6, 6)
	if stage >= 0:
		return Vector2i(3 + stage, 3)
	return Vector2i(3, 3 - stage)

## Compute all six stats from a set.
static func compute_stats(base: Dictionary, ivs: Dictionary, evs: Dictionary, level: int, nature: String) -> Dictionary:
	var out := {}
	out["hp"] = calc_hp(int(base.get("hp", 0)), int(ivs.get("hp", 31)), int(evs.get("hp", 0)), level)
	for s in ["atk", "def", "spa", "spd", "spe"]:
		out[s] = calc_stat(int(base.get(s, 0)), int(ivs.get(s, 31)), int(evs.get(s, 0)), level, nature_multiplier(nature, s))
	return out
