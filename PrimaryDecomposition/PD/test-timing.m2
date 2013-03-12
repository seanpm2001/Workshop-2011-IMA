-- Code to check the timing of a list of examples, and save the times
-- Then, we can compare different algorithms on these examples

-- the following package is not in the M2 binary distribution (as it is very rough still)
restart
needsPackage "ExampleIdeals"
debug needsPackage "PD"

--ETable = getExampleFile("minprimes-examples.m2")

-- need the following functions:
-- (1) get table
-- (2) run the examples, get timings, save to a file
-- (3) display several different timings next to each other
-- (4) boldface the best?

runExamples = (ETable, Keys, filename, beginString, fcn) -> (
    K := if Keys === null then sort keys ETable else Keys;
    F := openOut filename;
    F << beginString << endl;
    for k in K do (
        -- run example, with timing
        -- append info to file
        I := value (ETable#k#1);  -- evaluates to an ideal, at least we expect that
        if not instance(I, Ideal) then error "expected an ideal";
        << "running: " << k;
        t := timing (fcn I);
        << "  " << t#0 << endl;
        F << "\"" << ETable#k#0 << "\" => " << t#0 << endl;
        );
    close F;
    )

readResults = method()
readResults String := (filename) -> (
    L := lines get filename;
    LV := L/value;
    header := substring(L#0, 2, #L#0-2);
    (header, hashTable select(LV, f -> f =!= null)))

num2str = (n) -> (
    -- n should be a non-negative real number.  Returns a string rep of the number
    -- where there are exactly 3 digits after the .
    -- 
    m := round(n * 1000.);
    s := toString m;
    if m < 0 then error("expected non-negative number, but received "|s);
    if #s < 3 then (
        "." | concatenate((3-#s):"0")  | s)
    else (
        substring(s, 0, #s-3) | "." | substring(s, #s-3, 3)
    ))

combineResults = method()
combineResults List := (L) -> (
    -- L is a list of filenames (later, could be hash tables of results?)
    R := L/readResults;
    k := R/last/keys//join//flatten//unique//sort;
    firstrow := prepend("", R/first);
    prepend(firstrow, for k1 in k list (
        prepend(toString k1, 
        for i from 0 to #L-1 list (
            if R#i#1#?k1 then num2str(R#i#1#k1) else ""
            ))
        ))
    )
view = method()
view List := (L) -> (
    -- L is a list of file names
    -- each file consists of timings for a specific algorithm
    --
    netList(L, Alignment=>Right)
    )
end

restart
load "test-timing.m2"
ETable = getExampleFile("minprimes-examples.m2")
fcn = (I) -> minprimes I
stratA = (Strategy=>{({Linear,DecomposeMonomials,(Factorization,3)},infinity),(Birational,infinity), (Minprimes, 1)});
stratB = (Strategy=>{({Linear,DecomposeMonomials,(Factorization,3)},infinity),(Birational,infinity), IndependentSet,(Minprimes, 1)});
fcnA = (I) -> mikeIdeal(I, stratA) 
fcnB = (I) -> mikeIdeal(I, stratB) 
runExamples(ETable, null, "foo-minprimes", "--minprimes", fcn)
runExamples(ETable, null, "foo-stratA", "--stratA", fcnA)
runExamples(ETable, null, "foo-stratB", "--stratB", fcnB)
runExamples(ETable, null, "foo-decompose", "--decompose", decompose)
combineResults{"foo-decompose", "foo-minprimes", "foo-stratA", "foo-stratB"}
view oo
view transpose ooo
