# bfs-prolog

Breadth-first search Prolog-like tool

## Installation

Type `make` or `make bfs-prolog`.
You need ocaml to compile from the source code.

## Usage

### Commands

* `predicate(pattern, ...) :- proposition.` – Register a rule.
* `expression?` – One-by-one inquiry for solutions.
* `expression??` – Inquiry for all solutions.
  If you want to stop enumeration of solutions, press Ctrl+C.
* `@` - Exit.

The order of solutions may seem rather random,
but behind this is a simple algorithm of enumerating all solutions
by breadth-first search.

### Propositions

* `predicate(pattern, ...)` – Application of a predicate to patterns.
* `proposition1, proposition2` – Logical AND.
* `proposition1; proposition2` – Logical OR.
* `!proposition` – Logical NOT. You cannot negate propositions with variables.
* `=(pattern1, pattern2)` - Equality.
  For the sake of simplicity of parsing, it does not support `pattern1 = pattern2`.
* `true`, `false` – Logical TRUE and FALSE.

### Patterns

* `Variable` - Variable. It must start with a capital letter.
* `0`, `1`, `2`, etc. – Shorthand for `z`, `s(z)`, `s(s(z))`, etc.
* `0 + pattern`, `1 + pattern`, `2 + pattern`, etc.
  – Shorthand for `pattern`, `s(pattern)`, `s(s(pattern))`, etc.
* `[head | tail]` and `[a, b, c]` – List.

## Example

```
- nat(z).
- nat(s(N)) :- nat(N).
- nat_list([]).
- nat_list([N|X]) :- nat(N), nat_list(X).
- nat_list([1,3,2,4])??
()
No other solution.
- nat_list([X, Y, Z])?
(X = 0, Y = 0, Z = 0)
Do you want another solution? ("y"/otherwise)
y
(X = 1, Y = 0, Z = 0)
Do you want another solution? ("y"/otherwise)
y
(X = 2, Y = 0, Z = 0)
Do you want another solution? ("y"/otherwise)
y
(X = 0, Y = 1, Z = 0)
Do you want another solution? ("y"/otherwise)
n
- @
Goodbye.
```
