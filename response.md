# Response

We thank the reviewers for their thorough feedback, as it will surely improve the work. Our response addresses high-level comments first, followed by an appendix which contains a proposed "example of compilation" section and a detailed response to each reviewer.

## Relationship to Looplets

We began by clarifying the relationship between Finch and Looplets. Finch is the only framework to support such a broad range of single and multidimensional structured data and control flow. Looplets alone could not achieve these results without Finch. While Looplets provide a powerful mechanism to simplify structured loops, our paper shows how to make this functionality practical. Finch uses Looplets as a symbolic loop simplification engine. The precise choice and implementation of level structures, the lifecycle interface between levels and looplets, and the canonicalization of fancy indexing and masking operations all serve to recombine and utilize looplets to achieve efficient computation over structured tensors. We will illustrate this further in the next section.

## Improving the Explanation of the Compiler
> **Reviewer B**: “it appears that all the magic has been squirreled away in the unfurl function”, “the concordization step described in Section 5.4 looks very expensive”

> **Reviewer C**: “some important parts, like the structure implementations, do not have detailed explanation.” "Does concordization impact performance? I ask because adding another loop level even with if-conditions might cause some slowdown."

Finch relies on multiple detailed parts that all interact. While each part is explained in detail, we agree with Reviewer B that an example would help relate the parts to the whole. We propose a new section which relates the disparate parts through a complete example of lowering. A complete draft is given in the appendix, and we summarize here:

The `unfurl` function returns a Looplet nest describing the hierarchical structure of the outermost dimension of the tensor. Looplets were chosen for this purpose as a symbolic engine to ensure certain simplifications take place, but another symbolic system could have been used (e.g. polyhedral [102] or e-graph search [77]). We chose Looplets because they reliably process structured iterators, predictably eliminating zero regions, using faster lookups when available, and utilizing repeated work. Here is an simplified definition of `unfurl` for a SparseList vector.

```
unfurl(SubFiber(A.lvl::SparseList, pos)) = Thunk(
    # First, we initialize our position iterator
    preamble = (q = pos),
    # The stepper is analogous to a for-loop
    Stepper(
        # This fast forwards the loop to a specific iteration
        seek = (i) -> (q = binarysearch(A.lvl.idx, i)),
        # This tells us the last index in each iteration
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

In our new section, we plan to add an enhanced description of each mask and structured level format in terms of the looplet nests returned by `unfurl`, relating looplets to the concrete data fields of the tensor such as (`idx`, `ofs`, and `pos`), and addressing the concerns of Reviewer C.

Looplets allow us to make concordization inexpensive because the concordized loop is lowered with a mask. For example, consider the following program to calculate `A[5]` when `A` is sparse:
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
The lowered code runs in logarithmic time. We achieve the desired code because of (1) how SparseList communicates its structure in looplet nests via unfurl, (2) how wrapperization converts `i == 5` to a symbolic `DiagMask[i, 5]` which also uses looplets, and (3) how the two looplet nests combine to fast forward the sparse iterator and eliminate the `if false` branches.

This demonstrates the productivity of Finch, as we were able to implement efficient scalar reads and writes for all combinations of formats by simply combining the `unfurl` definitions with a structured tensor.

Our language allows fairly complex programs to be expressed on fairly complex structures because these optimizations happen in a predictable and reliable way. Our normal form, life cycles, concordization, and wrapperization are key ideas that allow us to boil our Finch language down to looplets so that the right looplet optimizations fire. 

> **Reviewer B**: “the use of wrappers ... appears to require materializing potentially expensive temporaries (e.g. Toeplitz matrices).”

We appreciate this concern, and assure Reviewer B that none of the wrapper arrays are materialized, they are all lazy. Wrappers instead modify the behavior of `unfurl`, dimensionalization, and other looplet properties such as `stop`. We plan to expand the section on wrapperization and masks to show the interface and clarify how they are allowed to modify Looplets. To give an example in terms of the simpler `OffsetArray(1)`,

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

## Improving the Evaluation

Reviewer A asks that we compare to another SpMV and SpGEMM implementation (in addition to TACO and Julia), we agree that this would strengthen the work and plan to include a comparison against Eigen, SparseTIR, or Cora on the datasets where it is relevant. Other related work is either specialized to different architectures (such as Taichi to GPUs) or is not open source (such as MKL or STUR).

As suggested by Reviewer A, we also plan to report our geo-mean speedups, which were as follows:

- For SpMV, Finch achieves 1.08x and 1.09x geomean speedups over julia_stdlib and TACO, respectively.

- For SpGEMM, for the small dataset (Figure 18 left), Finch's inner, outer, and Gustavson achieves 1.03x, 2.92x, 1.38x geomean speedups over TACO's inner, outer, and Gustavson, respectively. For the large dataset (Figure 18 right), Finch's Gustavson achieves 1.24x geomean speedup over TACO's Gustavson.

- For BFS, Finch's pull-push achieves 3.01x and 0.88x geomean speedups over Graphs.jl and GraphBLAS, respectively. For SSSP, Finch achieves 1.71x and 3.43x geomean speedups over Graphs.jl and GraphBLAS, respectively.

- For Triangle Count, SDDMM, and (A+B)*C kernels, Finch achieves 14.43x, 6.50x, and 19.58x geomean speedups over DuckDB, respectively.

## Tradeoffs between Specialization and Conditional Overhead

> **Reviewer B**: “In Section 6.1, the text says that the program in Figure 14 is restricting its attention to the canonical triangle using masks, but it looks like all three flavors are looping over the bounds of i and j in their entirety?”

> **Reviewer C**: "Please quantify and comment upon the overheads due to extra book keeping code generated by the compiler inside loop nests."

To Reviewer B, this is a typo in the text. For symmetric SpMV, we found it is faster to pre-compute the strict triangle of the argument and re-use it within the kernel, to simplify the logic. It is of course possible to add an `if i < j` statement and compute the triangle on the fly without accessing the whole matrix, but the runtime of SpMV is impacted because this changes the exit condition of the innermost loop.

Finch makes specialization more convenient than ever before. We have begun to find that there is a tradeoff between branching and more complicated loop structures and the benefits of such specialization. Specialization is better in cases where the specialized routine is much faster and the common case (such as the zero region of a sparse tensor, which becomes a no-op). In practice, this has led us to sometimes ask Finch to de-specialize certain conditional expressions, which is another example of how Finch can widen the design space for structured operators. We will include a discussion of this tradeoff in the paper.

## Freeze and Thaw

We do not intend the user to insert freeze/thaw manually, but we include them in the language because it allows us to handle lifecycles with a separate, simpler, compiler pass, rather than all at once. Tensors can only change between read and write mode in the scope in which they were defined, so we can insert freeze/thaw automatically by checking whether the tensor is being read or written to in each child scope. We error if a tensor appears on both the left hand and right hand sides within the same child scope. We will clarify this in the paper.

## Breaks

As Reviewer B suggests, we plan to include a larger discussion of how breaks integrate into the language. To integrate better with other structured arguments, Finch handles breaks as a structural simplification, rather than with a `break` statement. The following example uses a short circuit scalar to find the first negative value in A:

```
p = ShortCircuitScalar{0}()
@finch begin
    p .= 0
    for j=_
        if A[j] < 0
            p[] <<choose(0)>>= j
        end
    end
end
```

# Appendix

## Proposed Section with an Example of Compilation

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

We then begin lowering the program. The `@declare` statement on `s` results in a simple initialization of the `val` array, `s.lvl.val[1] = 0.0`. To process the `j` loop, we unfurl both tensors which access `j`. `unfurl(UpTriMask)` returns `Lookup(body = (j) -> UpTriMaskCol(j))`, and `unfurl(A::DenseLevel)` returns `Lookup(body = (j) -> SubFiber(A.lvl.lvl, j))`. Thus, we are left with:
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

Next, we process the `i` loop. We Unfurl the tensors, replacing them with the following nests of looplets:

```
unfurl(UpTriMaskCol(j)) = 
    Sequence(
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
    preamble = (q = A.lvl.lvl.ptr[j]),
    Stepper(
        seek = (i) -> (q = binarysearch(A.lvl.lvl.idx, i)),
        stop = A.lvl.lvl.idx[q],
        body = Spike(
            body = 0,
            tail = A.lvl.lvl.val[q]
        ),
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
    q = A.lvl.lvl.ptr[j]
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
    q = A.lvl.lvl.ptr[j]
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
    q = A.lvl.lvl.ptr[j]
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

## Detailed Comments

### Reviewer A

> Which features of your language are exercised by which case study? Can you indicate which features your baseline is lacking to reach the performance you are demonstrating.

The baseline implementation usually uses a combination of SparseList and Dense formats, which do not specialize at all to the particular structures we tested against.

- SpMV exercises SparseVBL, SparseBand, and Pattern formats, as well as multiple outputs in the symmetric kernel.

- SpMM exercises SparseBytemap and SparseHash formats, as well as sparse intermediates, and demonstrates the flexibility of our language for scheduling all three matrix multiplication variants.

- Graph Applications exercise SparseBytemap and Pattern formats, and conditionals, complex loop structures, early breaks, and user-defined functions.

- Image Morphology exercises SparseRLE and Pattern formats, as well as affine indexing, padding, and user-defined functions, and demonstrates the flexibility of our language.

- The Array API scheduler exercises SparseHash format and user-defined functions, and shows that the language is reliable and flexible enough to support autoscheduling.

> It is unclear how the [SpGEMM] dataset has been selected. A reference to a standard matrix dataset would be appreciated

The SpGEMM dataset was chosen to be the matrices in [101], a matrix test set designed to reveal asymptotic differences in SpGEMM algorithms. We separated the matrices into small matrices and large matrices. Because of asymptotic slowdowns, we couldn’t run TACO outer products or inner products on the large matrices. However, since the matrices are organized by size in the small matrix plot, we can already see the beginnings of a trend where the TACO outer products and inner products perform worse as the matrix size increases. We will include a dedicated scaling plot to make these relationships more clear. 

> Do you report here the 'geo mean' or 'arith mean' speedup?

We report the arithmetic mean in the paper.

> I wonder if the indirection through Julia had a performance cost. I would have preferred to compare with GraphBLAS natively.

We compared with the native C implementation of LAGraph, which calls GraphBLAS using the native C bindings.

> I appreciate that you mention this timeout and would be curious who timed out? Finch, Graphblas, ...? Are there previously reported numbers on GAP-road and why does this time a timeout occur?

[98] does not measure Bellman-Ford, which is a more expensive algorithm. In the implementations we tested, the number of iterations of Bellman-Ford is bounded by the diameter of the graph. GAP-road has a very large diameter. For example, soc-orkut has 212.7M edges and a diameter of 9. GAP-road has 577.1M edges and a diameter of 6809. If each iteration ran in `O(nnz)`, this would result in a factor of 2059  increase in expected runtime. We stopped measuring LAGraph/GraphBLAS after an hour. We will add a note to the paper.

> [98] evaluates on 11 datasets, but this work only on 6. I am unsure why the others are omitted.

Thank you for pointing out this discrepancy. We were sourcing our matrices from the University of Florida sparse matrix collection. Based on the labels in Figure 7, we could not locate `h09` and `i04`. However, upon re-reading, we see that Table 3 indicates these graphs were actually `LAW/hollywood-2009` and `LAW/indochina-04`, and we will add these to our evaluation. The other matrices weren't in the collection because they were randomly generated. We also plan to generate these and add them to the evaluation.

### Reviewer B

> First, Figure 7 defines DECLARE, FREEZE, and THAW, but they aren't referred to anywhere else? 

Thank you for this correction, DECLARE, FREEZE, and THAW should have been added as options to STMT in Figure 7.

> Does "consistently better" on line 751 mean "better in every single case"?

Yes, it does.

> Section 6.5 looks to be introducing yet another language and an interpreter ... why is it stuffed into one page in the evaluation of Finch?

This section demonstrates the potential use of Finch as a backend for higher-level languages. We will include more details of the high-level language in the appendix.

### Reviewer C

> Please check figure 13 since it appears freeze has been placed wrongly before l-value of x and y are encountered.

Thank you for this correction, both freeze statements in Figure 13 need to be moved downward.

> Due to these spreading of case studies, each study also feel quite high-level and should be discussed in details.

As mentioned above, we plan to include additional details in an appendix.

> The speedups and slowdowns are highlighted and typically simple explanations are given for these performance results like 787-788 for SparseList or Sparse-List Pattern formats.

In this particular instance, the speedup on the symmetric kernel is because we reuse reads to the upper triangle of the matrix. We will include this explanation in the paper.

> I would have liked to see quantifying data like how many times you had to use Sequentially constructed levels over Nonsequentially Constructed Levels

SparseBytemap and SparseHash are the two nonsequential levels we used. They were used in outer products and Gustavson SpGeMM, the frontier in our graph applications, and as a conservative output format in the Array API scheduler.

> I would like to know why the formats provide the speedup

In general, the sparse list format stores the locations of nonzeros and values individually. Other structured formats improve on this through specialization. For example, the SparseBand format stores the location of a contiguous group of nonzeros only once. Iterating through a sparse list produces a while loop that looks up each nonzero index from memory, while iterating through a sparse band produces a for-loop over the range of indices in the band. We will measure operation counts to help further explain these speedups.