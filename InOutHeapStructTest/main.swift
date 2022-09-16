import Foundation

/*
 Investigating the performance tradeoffs between different methods of copying
 and mutating a struct. We started with the assumption that using a nonescaping
 closure that accepted an inout value would be measurably slower than
 */

// Need to perform about 10 million iterations of each loop for the whole thing
// to take more than 0.1s. M1 Macs are fast as hell.
let numberOfIterations = 10000000

// MARK: Mutable
protocol Mutable {}

extension Mutable {
    func mutate(transform: (inout Self) -> Void) -> Self {
        var newSelf = self
        transform(&newSelf)
        return newSelf
    }
    
    func mutateUnsafe(transform: (UnsafeMutablePointer<Self>) -> Void) -> Self {
        var newSelf = self
        transform(&newSelf)
        return newSelf
    }
}

// MARK: Data Types
// Making the assumption here that data types should be simple value
// types that the compiler would ordinarily allocate on the stack. Wrapping
// this in a struct so that if closures ARE copying back and forth to heap
// memory every time, it'll be a more noticable penalty than if we were
// working with a single scalar Int or whatever, as the copy in that case
// would entail moving 4 values instead of one.
struct SomeStruct: Mutable, Equatable {
    var a = 0
    var b = 0
    var c = 0
    var d = 0
}

// MARK: Global state
var i = 0
var start = CFAbsoluteTimeGetCurrent()
var foo = SomeStruct()
var bar = SomeStruct()

// MARK: Test Housekeeping
func reset() {
    i = 0
    start = CFAbsoluteTimeGetCurrent()
    foo = SomeStruct()
    bar = SomeStruct()
}

func report(_ methodName: String) {
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    print(String(format: "%.4fs : %@", elapsed, methodName))
}

// MARK: Test Variants

/*
 The basic algo here is just to do some addition between
 struct members, assign them back, then copy the whole struct
 again before the next loop iteration. I wanted to make sure
 that 1) the operation itself was fast enough that we weren't
 measuring the operation itself, and 2) we were forcing the
 compiler to execute the transformation and assign values,
 rather than something so trivial that it might just be
 optimized out altogether. I think this satisfies both of
 those constraints.
 
 I've toyed with different methods of doing this, and it
 doesn't seem to impact performance at all
 whether we add a constant to each member, add members together,
 or add `i` to each. I mostly wanted to ensure the compiler
 wasn't doing some optimization around constant values that
 would skew things, but in this loop, everything is likely
 just living in a register anyway.
 
 &+ is the addition with overflow operator, because we
 definitely do overflow with 10 million iterations.
 */

// Old school copy and assign. This should be the fastest.
reset()
while i < numberOfIterations {
    foo = bar
    foo.a = foo.a &+ i
    foo.b = foo.b &+ foo.a
    foo.c = foo.c &+ foo.b
    foo.d = foo.d &+ foo.c
    bar = foo
    i += 1
}
report("copy and assign")

// Remember our result here, to sanity-check that our other algos
// are actually doing real work.
let expectedFinalValue = bar

// Mutation via inout closures. This is expected to pay a heavy
// performance toll to capture values, and possibly for additional
// call overhead.
reset()
while i < 10000000 {
    foo = bar
        .mutate { $0.a = $0.a &+ i }
        .mutate { $0.b = $0.b &+ $0.a }
        .mutate { $0.c = $0.c &+ $0.b }
        .mutate { $0.d = $0.d &+ $0.c }
    bar = foo
    i += 1
}
report("Mutate")
assert(bar == expectedFinalValue)

// Just a subtle change from the plain Mutate loop - creating
// a new SomeStruct instance inside the loop, rather than
// reusing the globally-allocated var.
reset()
while i < 10000000 {
    let foo = bar
        .mutate { $0.a = $0.a &+ i }
        .mutate { $0.b = $0.b &+ $0.a }
        .mutate { $0.c = $0.c &+ $0.b }
        .mutate { $0.d = $0.d &+ $0.c }
    bar = foo
    i += 1
}
report("Mutate with struct creation in loop")
assert(bar == expectedFinalValue)

// Using UnsafeMutablePointer to pass values. If `inout` is copying
// values to the heap each time, this should be faster.
reset()
while i < 10000000 {
    foo = bar
        .mutateUnsafe { $0.pointee.a = $0.pointee.a &+ i }
        .mutateUnsafe { $0.pointee.b = $0.pointee.b &+ $0.pointee.a }
        .mutateUnsafe { $0.pointee.c = $0.pointee.c &+ $0.pointee.b }
        .mutateUnsafe { $0.pointee.d = $0.pointee.d &+ $0.pointee.c }
    bar = foo
    i += 1
}
report("Mutate Unsafe")
assert(bar == expectedFinalValue)

// Copy and assign with a more Swift-y loop structure
reset()
for i in 0 ..< 10000000 {
    foo = bar
    foo.a = foo.a &+ i
    foo.b = foo.b &+ foo.a
    foo.c = foo.c &+ foo.b
    foo.d = foo.d &+ foo.c
    bar = foo
}
report("copy and assign w/ for-in loop")
assert(bar == expectedFinalValue)

// No copying of values back and forth.
reset()
while i < numberOfIterations {
    foo.a = foo.a &+ i
    foo.b = foo.b &+ foo.a
    foo.c = foo.c &+ foo.b
    foo.d = foo.d &+ foo.c
    i += 1
}
bar = foo
report("assign with no copy")
assert(bar == expectedFinalValue)

// Mutate without copying values back and forth.
reset()
while i < 10000000 {
    foo = foo
        .mutate { $0.a = $0.a &+ i }
        .mutate { $0.b = $0.b &+ $0.a }
        .mutate { $0.c = $0.c &+ $0.b }
        .mutate { $0.d = $0.d &+ $0.c }
    i += 1
}
bar = foo
report("Mutate with no copy")
assert(bar == expectedFinalValue)
