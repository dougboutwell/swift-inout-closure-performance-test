# swift-inout-closure-performance-test

Simple command-line app to investigate the performance tradeoffs between different methods of copying and mutating a struct. 

I started with the assumption that using a nonescaping closure that accepted an `inout` value would be measurably slower than an old-school copy and assign. Swift closures generally have overhead in capturing values, and `inout` by default are [copied in and out](https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID545) of their execution context. This should add up to a measurable performance penalty vs directly manipulating stack-local variables.

## Results

On my MacBook Pro (M1 Pro), the results were:

```
1.0694s : copy and assign
0.6949s : Mutate
0.5799s : Mutate with struct creation in loop
0.6929s : Mutate Unsafe
3.4349s : copy and assign w/ for-in loop
0.8210s : assign with no copy
0.5683s : Mutate with no copy
```

## Takeaways

- Clang is very, very smart
- The largest performance impact of the various methods I tried was actually in using a `for-in` loop structure instead of a `while`
- Closures were actually _faster_ in most cases, for reasons I can't fathom
- None of this matters unless you're in a hot inner loop of performance-critical code. For 99.9% of cases, choose what's syntactically clear.
- Don't try to outsmart the compiler.
