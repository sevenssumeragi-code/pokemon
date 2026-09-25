class_name TestCase
extends RefCounted
## Minimal unit-test base class. Subclasses define `test_*` methods.
## Assertions record failures instead of aborting so a whole file runs.

var _failures: Array[String] = []
var _assert_count: int = 0
var _current: String = ""

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func _fail(msg: String) -> void:
	_failures.append("%s: %s" % [_current, msg])

func assert_true(cond: bool, msg: String = "") -> void:
	_assert_count += 1
	if not cond:
		_fail("expected true. " + msg)

func assert_false(cond: bool, msg: String = "") -> void:
	_assert_count += 1
	if cond:
		_fail("expected false. " + msg)

func assert_eq(a, b, msg: String = "") -> void:
	_assert_count += 1
	if not _deep_eq(a, b):
		_fail("expected %s == %s. %s" % [str(a), str(b), msg])

func assert_ne(a, b, msg: String = "") -> void:
	_assert_count += 1
	if _deep_eq(a, b):
		_fail("expected %s != %s. %s" % [str(a), str(b), msg])

func assert_approx(a: float, b: float, eps: float = 0.0001, msg: String = "") -> void:
	_assert_count += 1
	if absf(a - b) > eps:
		_fail("expected %s ~= %s (eps %s). %s" % [a, b, eps, msg])

func assert_in_range(v, lo, hi, msg: String = "") -> void:
	_assert_count += 1
	if v < lo or v > hi:
		_fail("expected %s in [%s, %s]. %s" % [str(v), str(lo), str(hi), msg])

func assert_has(container, item, msg: String = "") -> void:
	_assert_count += 1
	if not container.has(item):
		_fail("expected %s to contain %s. %s" % [str(container), str(item), msg])

func assert_not_null(v, msg: String = "") -> void:
	_assert_count += 1
	if v == null:
		_fail("expected non-null. " + msg)

func _deep_eq(a, b) -> bool:
	if typeof(a) != typeof(b):
		# allow int/float comparison
		if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
			return float(a) == float(b)
		return false
	return a == b
