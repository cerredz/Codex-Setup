● 100 Python Best Practices for Backend Development

Assignment & Variables

1. Use tuple unpacking instead of index access: a, b = get_pair() not result = get_pair(); a = result[0]
2. Use _ for throwaway values: name, _, age = get_record() when you don't need middle value
3. Use extended unpacking: first, \*rest, last = items to capture head/tail patterns
4. Avoid mutable default arguments: def f(items=None): items = items or [] not def f(items=[])
5. Use None as sentinel, not [] or {}: Mutable defaults are shared across calls
6. Chain comparisons: 0 < x < 10 not x > 0 and x < 10
7. Use walrus operator for assign-and-test: if (n := len(items)) > 10: when you need the value
8. Swap without temp: a, b = b, a
9. Use augmented assignment: count += 1 not count = count + 1
10. Avoid single-letter names except for: i/j/k (indices), x/y/z (coordinates), e (exception), f (file), k/v (key/value)

Collections & Data Structures

11. Use defaultdict instead of checking key existence: defaultdict(list) not if key not in d: d[key] = []
12. Use Counter for counting: Counter(items) not manual dict incrementing
13. Use deque for O(1) append/pop from both ends, not list
14. Use set for membership testing O(1), not list O(n)
15. Use frozenset when you need a hashable set (dict keys, set of sets)
16. Use namedtuple or dataclass instead of plain tuples for structured data
17. Prefer dataclass(frozen=True) for immutable value objects
18. Use dict.get(key, default) instead of key in dict checks
19. Use dict.setdefault for get-or-insert patterns: d.setdefault(k, []).append(v)
20. Use | operator for dict merge (3.9+): merged = d1 | d2
21. Use ChainMap to search multiple dicts without copying
22. Prefer tuple over list for fixed-size heterogeneous data
23. Use heapq for priority queue, not sorted list
24. Use bisect for maintaining sorted lists with insertions
25. Use OrderedDict only when you need move_to_end - regular dicts preserve order since 3.7

Comprehensions & Iteration

26. Use list comprehension over map/filter when readable: [x*2 for x in items]
27. Use generator expressions for large sequences: sum(x*2 for x in items) not sum([x*2 for x in items])
28. Don't nest more than 2 levels in comprehensions - use a regular loop
29. Use enumerate: for i, item in enumerate(items) not manual counter
30. Use zip for parallel iteration: for a, b in zip(list1, list2)
31. Use zip(strict=True) (3.10+) when lengths must match
32. Use itertools.zip_longest when sequences differ in length
33. Use reversed() not [::-1]\*\* for iteration (no copy created)
34. Use any() and all() for boolean aggregation with short-circuit
35. Use itertools.chain to flatten one level: chain.from_iterable(nested)
36. Use itertools.groupby on pre-sorted data for grouping
37. Use itertools.islice to slice iterators without materializing
38. Use itertools.takewhile/dropwhile for conditional iteration
39. Use dict comprehension: {k: v for k, v in pairs} not dict(pairs) when filtering/transforming
40. Use set comprehension: {x.lower() for x in names} for unique transformed values

Functions

41. Use \*args and \*\*kwargs for delegation, not flexibility abuse
42. Force keyword-only args with _: def f(a, _, b, c): prevents positional mistakes
43. Force positional-only args with / (3.8+): def f(a, b, /, c): for API stability
44. Return early to reduce nesting: if not valid: return None at top
45. Return consistent types: Don't return list sometimes and None other times - return empty list
46. Use functools.lru_cache for expensive pure functions
47. Use functools.cache (3.9+) for simpler unbounded cache
48. Use functools.partial to fix arguments: partial(func, arg1=val)
49. Use functools.singledispatch for type-based dispatch instead of isinstance chains
50. Use operator module for simple lambdas: operator.itemgetter(0) not lambda x: x[0]
51. Small functions over long ones: If it needs a comment explaining a block, extract it
52. Avoid boolean parameters: process(dry_run=True) not process(True)
53. Use _ to prevent accidental positional expansion: def f(_, items): forces f(items=[...])

Classes

54. Use **slots** for memory-heavy classes with fixed attributes
55. Use @property for computed attributes, not getter methods
56. Use @cached_property (3.8+) for expensive computed attributes
57. Prefer composition over inheritance: Contain objects, don't subclass
58. Use **str** for user output, **repr** for debugging - always implement **repr**
59. Make **repr** eval-able when possible: f"{self.**class**.**name**}({self.x!r})"
60. Use @dataclass instead of manual **init**, **repr**, **eq**
61. Use dataclass(slots=True) (3.10+) for memory efficiency
62. Use @staticmethod only when method doesn't need class/instance - otherwise @classmethod
63. Use @classmethod for alternative constructors: User.from_dict(d)
64. Implement **hash** and **eq** together or not at all
65. Use **bool** to define truthiness: empty containers should be falsy
66. Use **contains** to support in operator
67. Use **getitem** with slices support for sequence types
68. Prefer ABC and @abstractmethod over duck typing for interfaces
69. Use **init_subclass** for subclass registration patterns
70. Use **class_getitem** for generic type hints on custom classes

String Handling

71. Use f-strings over .format() or %: f"Hello {name}"
72. Use !r in f-strings for debugging: f"Got {value!r}" shows quotes/escapes
73. Use str.join for concatenation: ', '.join(items) not + in loop
74. Use str.removeprefix/removesuffix (3.9+) not slicing with len()
75. Use str.split(maxsplit=1) when you only need first split
76. Use str.partition when splitting on first occurrence and need all parts
77. Use raw strings for regex: r'\d+' not '\\d+'
78. Use textwrap.dedent for multiline strings in code
79. Use str.casefold() for case-insensitive comparison, not .lower()
80. Use str.translate for character replacement, faster than chained .replace()

Error Handling

81. Catch specific exceptions: except ValueError not bare except
82. Use except Exception only when you genuinely handle all errors
83. Re-raise with raise ... from e to preserve exception chain
84. Use raise ... from None to suppress original exception intentionally
85. Use else clause on try: Code that runs only if no exception
86. Use context managers (with) for resource cleanup, not try/finally
87. Create custom exceptions inheriting from domain-specific base
88. Use contextlib.suppress for ignoring specific exceptions: with suppress(FileNotFoundError):
89. Use ExceptionGroup (3.11+) for multiple simultaneous errors
90. Don't use exceptions for flow control in hot paths - check conditions first

Type Hints & Safety

91. Use Optional[X] or X | None (3.10+) for nullable types
92. Use TypedDict for dict with known string keys
93. Use Literal for fixed string/int values: Literal["read", "write"]
94. Use Final for constants: MAX_SIZE: Final = 100
95. Use Protocol for structural subtyping (duck typing with types)
96. Use TypeVar for generic functions: T = TypeVar('T'); def first(items: list[T]) -> T
97. Use @overload to type functions with different return types based on input
98. Use cast() only when you know better than the type checker
99. Use TYPE_CHECKING guard for import-only-for-types to avoid circular imports
100.  Use assert for invariants in dev, not input validation - assertions can be disabled

---
