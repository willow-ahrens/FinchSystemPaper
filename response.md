# Response

We thank the reviewers for their thorough feedback, as it will surely improve the work. We address high-level comments first, and more detailed comments in an explicit appendix.

## Relationship to Looplets

We began by clarifying the relationship between Finch and Looplets. Finch is the only framework to support such a broad range of single and multidimensional structured data and control flow. Looplets alone could not achieve these results without Finch. While Looplets provide a powerful mechanism to simplify structured loops, our paper shows how to make this functionality practical. Finch uses Looplets as a symbolic loop simplification engine. The precise choice and implementation of level structures, the lifecycle interface between levels and looplets, and the canonicalization of fancy indexing and masking operations all serve to recombine and utilize looplets to achieve efficient computation over structured tensors.

## Improving the Explanation of the Compiler
> **Reviewer B**: “it appears that all the magic has been squirreled away in the unfurl function”, “the concordization step described in Section 5.4 looks very expensive”

> **Reviewer C**: “some important parts, like the structure implementations, do not have detailed explanation.” "Does concordization impact performance? I ask because adding another loop level even with if-conditions might cause some slowdown."

Finch relies on multiple detailed parts that all interact. While each part is explained in detail, examples would help relate the parts to the whole. We take Reviewer B's advice and propose a new section (a draft of which is given in our appendix) which relates the disparate parts through a complete example of lowering.

To summarize here: The `unfurl` function returns a Looplet nest describing the hierarchical structure of the outermost dimension of the tensor. Looplets were chosen for this purpose as a symbolic engine to ensure certain simplifications take place, but another symbolic system could have been used. We chose Looplets because they reliably process structured iterators. Here is an simplified definition of `unfurl` for a SparseList vector. It is up to the implementer of the structured level to ensure that `unfurl` returns a correct Looplet nest.

```
unfurl(SubFiber(A.lvl::SparseList, pos)) = Thunk(
    # First, we initialize our position iterator
    preamble = (q = pos),
    # The stepper is analogous to a for-loop
    Stepper(
        # This fast forwards the loop to a specific iteration
        seek = (i) -> (q = binarysearch(A.lvl.idx, i)),
        # This tells us the boundary of the loop
        stop = A.lvl.idx[q],
        body = Spike(
            body = 0,
            tail = A.lvl.val[q]
        ),
        # This advances the loop to the next iteration
        next = (q += 1)
    )
)
```

In our new section or an appendix, we plan to add an enhanced description of each mask and structured level format in terms of the looplet nests returned by `unfurl`, relating looplets to the concrete data fields of the tensor such as (`idx`, `ofs`, and `pos`), and addressing the concerns of Reviewer C.

As an example, Looplets allow us to make concordization inexpensive because the concordized loop is lowered with a mask. For example, consider the following program to calculate `A[5]` when `A` is sparse:
```
for i = _
    if i == 5
        s[] = A[i]
    end
end
```
This would lower to the following:
```
q = binarysearch(A.lvl.idx, 5)
i = A.lvl.idx[q]
if i == 5
    s[] = A.lvl.val[q]
end
```
The lowered code runs in logarithmic time. We achieve the desired code because of (1) how SparseList communicates its structure in looplet nests via unfurl, (2) how wrapperization converts `i == 5` to a symbolic `DiagMask[i, 5]` tensor, also expressed in looplets, and (3) how the two looplet nests reliably combine to fast forward the sparse iterator and eliminate the `if false` branches.

This is an example of the productivity of Finch, as we were able to implement efficient scalar reads and writes for all combinations of formats by simply combining the `unfurl` definitions with a structured tensor.

Our language allows fairly complex programs to be expressed on fairly complex structures yet still have these optimizations happen in a predictable and reliable way. Our normal form, life cycles, concordization, and wrapperization are key ideas that allow us to boil our Finch language down to looplets so that the right looplet optimizations fire. 

> **Reviewer B**: “the use of wrappers ... appears to require materializing potentially expensive temporaries (e.g. Toeplitz matrices).”

None of the wrapper arrays are materialized, they are all lazy. Wrappers instead modify the behavior of `unfurl`, dimensionalization, and other looplet properties such as `stop`. To give an example in terms of the simpler `OffsetArray(1)`,

```
A = Tensor(Dense(Element(0.0)))
B = Tensor(Dense(Element(0.0)))
@finch begin
    for i = 2:4
        B[i] = A[i + 1]
    end
end
```

Would lower to

```
for i = 2:4
    B.lvl.val[i] += A.lvl.val[i + 1]
end
```


## Clarifying the Evaluation

Reviewer A asks that we compare to another SpMV and SpGEMM implementation (in addition to TACO and Julia), we agree that this would strengthen the work and plan to include a comparison against Eigen, SparseTIR, or Cora on the datasets where it is relevant. Other related work is either specialized to different architectures (such as Taichi to GPUs) or is not open source (such as MKL or STUR).

Reviewer A also requests geo-mean speedups for our SpMV and SpGEMM implementations, which were _ and _, respectively. We plan to include geo-mean speedups.
The SpGEMM dataset was chosen to be the matrices in  [101]. We separated the matrices into small matrices and large matrices. Because of asymptotic slowdowns, we couldn’t run TACO outer products or inner products on the large matrices. However, since the matrices are organized by size in the small matrix plot, we can already see the beginnings of a trend where the performance of TACO outer products and inner products perform worse as the matrix size increases. We will include a dedicated scaling plot to make these relationships more clear.


> **Reviewer B**: “In Section 6.1, the text says that the program in Figure 14 is restricting its attention to the canonical triangle using masks, but it looks like all three flavors are looping over the bounds of i and j in their entirety?”

> **Reviewer C**: "Please quantify and comment upon the overheads due to extra book keeping code generated by the compiler inside loop nests."

To Reviewer B, this is a typo in the text. For symmetric SpMV, we found it is faster to pre-compute the strict triangle of the argument and re-use it within the kernel, to simplify the logic. It is of course possible to add an `if i < j` statement and compute the triangle on the fly without accessing the whole matrix, but the runtime of SpMV is impacted because this changes the exit condition of that loop.

In general, we have found Finch is quite adept at lifting conditionals to the highest level of the loop nest, but that there is a tradeoff between the branching between specialized routines and the benefits of such specialization. Specialization is better in cases where the specialized routine is much faster and much more frequent (such as the zero region of a sparse tensor, which becomes a no-op). In practice, this has led us to sometimes ask Finch to de-specialize certain conditional expressions, and is another example of how Finch can widen the design space for structured operators. We will include a discussion of this tradeoff in the paper.

> **Reviewer A**: Which features of your language are exercised by which case study? Can you indicate which features your baseline is lacking to reach the performance you are demonstrating.

> **Reviewer C**:  “I would have liked to see quantifying data like how many times you had to use Sequentially constructed levels over Nonsequentially Constructed Levels”

Our SpMV evaluation demonstrates the performance of the SparseList, SparseVBL, SparseBand, and Pattern level formats, as well as conditionals and multiple outputs in the symmetric kernel

Our SpMM evaluation shows off the importance of sparse intermediates (SparseBytemap and SparseHash are non-sequential) and the flexibility of our language for scheduling, doing all three matrix multiplication variants.

Our Graph applications demonstrate conditionals, complex loop structures, early breaks, and user-defined functions.

Our Image Morphology benchmarks demonstrate the flexibility of the language, as well as affine indexing and `sparseRLE` and `pattern` formats, as well as user-defined functions.

The Array API benchmark shows that the language is reliable and flexible enough to support autoscheduling. It also involves user-defined functions and `SparseHash, non-sequential` format.

> **Reviewer C**: I would like to know why the formats provide the speedup: Is it just due to looplets iterators at each level? Is it due to constructed levels and if so, how do they provide benefit over other constructed levels and why over TACO’s representation?

# Appendix

## Lowering Example Section

Though Finch programs look as if they are written for dense loops, Finch specializes the code during lowering so that only the necessary elements of structure need to be processed. We illustrate the lowering of a program which sums the upper triangle of an `m` by `n` matrix, `A`:

```
A = Tensor(Dense(SparseList(Element(0.0))), m, n)
s = Tensor(Element(0.0))
@finch begin
    s .= 0.0
    for j = _
        for i = _
            if i <= j
                s[] += A[i, j]
            end
        end
    end
end
```

To begin, the wrapperization pass replaces `i <= j` with `UpTriMask[i, j]`. The dimensionalization pass assigns `i`, and `j` the dimensions `m` and `n`, respectively. All accesses are already concordant, and after adding lifecycle statements we have:

```
@finch begin
    @declare(s, 0.0)
    for j = 1:n
        for i = 1:m
            if UpTriMask[i, j]
                s[] += A[i, j]
            end
        end
    end
    @freeze(s)
end
```

We then begin lowering the program. The `@declare` statement on `y` results in a simple initialization of the `val` array, `s.lvl.val[1] = 0.0`. To process the `j` loop, we unfurl both tensors which access `j`. `unfurl(UpTriMask)` returns `Lookup(body = (j) -> UpTriMaskCol(j))`, and `unfurl(A::DenseLevel)` returns `Lookup(body = (j) -> SubFiber(A.lvl.lvl, j))`. Thus, we are left with:
```
s.lvl.val[1] = 0.0
@finch begin
    for j = 1:n
        for i = 1:m
               if (Lookup(...)[j])[i]
                 s[] += (Lookup(...)[j])[i]
            end
        end
    end
    @freeze(s)
end
```

Since we can lower Lookup looplets with a for-loop, our loop becomes:
```
s.lvl.val[1] = 0.0
for j = 1:n
    @finch begin
        for i = 1:m
            if UpTriMaskCol(j)[i]
                s[] += SubFiber(A.lvl.lvl, j)[i]
            end
        end
    end
end
@finch @freeze(s)
```

Next, we process the `i` loop. We Unfurl the tensors, replacing them with the follwing nests of looplets:

```
unfurl(UpTriMaskCol(j)) = Sequence(
    Phase(
        stop = j,
        Run(true)
    ),
    Phase(
        Run(False)
    )
)
```

```
unfurl(SubFiber(A.lvl.lvl::SparseListLevel, j)) = Thunk(
    # First, we initialize our position iterator
    preamble = (q = 1),
    # The stepper is analogous to a for-loop
    Stepper(
        # This fast forwards the loop to a specific iteration
        seek = (i) -> (q = binarysearch(A.lvl.lvl.idx, i)),
        # This tells us the boundary of the loop
        stop = A.lvl.lvl.idx[q],
        body = Spike(
            body = 0,
            tail = A.lvl.lvl.val[q]
        ),
        # This advances the loop to the next iteration
        next = (q += 1)
    )
)
```

Substituting the results of `unfurl` into the expression, we are left with:
```
s.lvl.val[1] = 0.0
for j = 1:n
    @finch begin
        for i = 1:m
            if Sequence(...)[i]
                s[] += Thunk(...)[i]
            end
        end
    end
end
@finch @freeze(s)
```

The highest lowering priority is for the Thunk, then we lower the Sequence looplet, leaving us with:
```
s.lvl.val[1] = 0.0
for j = 1:n
    q = 1
    @finch for i = 1:j
        if true
            s[] += Stepper(...)[i]
        end
    end
    @finch for i = j+1:m
        if false
            s[] += Stepper(...)[i]
        end
    end
end
@finch @freeze(s)
```

We can simplify the latter phase to a no-op, and lower the stepper in the first phase to a while loop. The Spike inside the stepper lowers similarly to a sequence, leaving us with

```
s.lvl.val[1] = 0.0
for j = 1:n
    q = 1
    i_loop = 1
    while i_loop < j
        i_loop_2 = A.lvl.lvl.idx[q]
        @finch for i = i_loop:min(i_loop_2, j)
                s[] += 0
        end
        i = i_loop_2
        @finch if i < j
                s[] += A.lvl.lvl.val[q]
        end
        q += 1
    end
end
@finch @freeze(s)
```
Finally, we simplify the first case and lower the final freeze (which is a no-op), obtaining:

```
s.lvl.val[1] = 0.0
for j = 1:n
    q = 1
    i_loop = 1
    while i_loop < j
        i_loop_2 = A.lvl.lvl.idx[q]
            i = i_loop_2
        if i < j
            s[] += A.lvl.lvl.val[q]
        end
        q += 1
    end
end
```

The final program accesses only the upper triangle of A, though the original code looks as though it loops over all `i` and `j`.