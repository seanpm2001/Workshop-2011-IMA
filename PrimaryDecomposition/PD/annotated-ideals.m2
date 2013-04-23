-- part of PD.m2, uses code from there too

AnnotatedIdeal = new Type of MutableHashTable

-- An "annotated ideal" is a hash table with keys:
--   Ideal:  I
--   Linears: L
--   NonzeroDivisors: NZ
--   Inverted: inverteds
--   where 
--     (a) I is an ideal (in a subset of the variables)
--     (b) L is a list of (x, g, f), where 
--     (c) x is a variable (not appearing in I at all)
--     (d) g is a monic poly not involving x
--     (e) f = xg-h is in the original ideal (leadTerm f is not nec leadTerm(xg))
--     (f) h does not involve x.
--   NZ: list of known nonzero-divisors.  This is used only for performance:
--     once we know that e.g. A.Ideal : f == A.Ideal, then f can be placed on this list.
--   inverteds: Elements that have been 'inverted' in the calculation.  Need to saturate
--     with respect to these when reconstructing the associated ideal, assuming that
--     the ideal is not known to be prime already.
-- HOWEVER, if the keys IndependentSet, LexGBOverBase exist
--   then I is only contained in the associated ideal.
--   These keys contain the following info:
--     A.IndependentSet   This is a triple (basevars,S,SF) where S,SF are returned from makeFiberRings
--     A.LexGBOverBase  GB of ISF over SF
--     If one of these flags is set, both are, and the resulting ideal is equidimensional.
-- Other keys:
--   Finished Flags: if any of these flags exists, then that split
--   technique would have no further effect on the annotated ideal A.
--    A.Birational   
--    A.Linear
--    A.Factorization
--    A.IndependentSet
--    A.SplitTower
--    A.DecomposeMonomials
--    A.Trim
--    A.LexGBSplit is set once LexGBOverBase consists of irred polynomials over the base field.
--   A.isPrime: possible values: "YES", "NO", "UNKNOWN".  Usually "YES" or "UNKNOWN".
-- The associated ideal consists of 3 parts, with a potential saturation step:
--   (a) the linear polynomials in L
--   (b) the ideal I
--   (c) if LexGBOverBase is a key, then the contraction of (ideal A.LexGBOverBase) to the polynomial ring
-- the saturation is with respect to all g for each (x,g,f) in L.
-- See "ideal AnnotatedIdeal" for the exact formula.

monicUniqueFactors = polyList -> (
    polyList1 := polyList/factors//flatten;
    polyList2 := select(polyList1, g -> #g > 0);
    polyList2 / last // unique
)

annotatedIdeal = method()
annotatedIdeal(Ideal, List, List, List) := (I, linears, nzds, inverted) -> (
    -- See above for the definition of an annotated ideal and its keys
    -- The arguments are named the same thing as in that description
    -- nzds is a list of polynomials which are nzds's of the associated ideal
    -- inverted is a list of elements such that we ignore the minimal primes
    --   that contain any of these elements
    -- The associated ideal is:
    --   saturate(I + ideal(linears/last), product unique join((linears / (x -> x#1)),inverted))
    new AnnotatedIdeal from {
        symbol Ideal => I, 
        symbol Linears => linears, 
        symbol NonzeroDivisors => monicUniqueFactors nzds,
        symbol Inverted => monicUniqueFactors inverted
        }
    )

gb AnnotatedIdeal := opts -> (I) -> I.Ideal = gb(I.Ideal, opts)

-- getGB is used for finding a lower bound on the codim of the ideal I
-- The idea is that sometimes the GB computation is too huge, and we
-- don't want to undertake that.  But, if it is there, we want to take
-- advantage of it.  It could even be a partial Groebner basis.
-- codimLowerBound below uses whatever lead terms we can find in the ideal
-- to get some lower bound on the codimension.
getGB = method()
getGB Ideal := (I) -> (
     cached := keys I.generators.cache;
     pos := select(1, cached, k -> instance(k, GroebnerBasisOptions));
     if #pos === 0 then null
     else
       I.generators.cache#(first pos)
     )

codim AnnotatedIdeal := options(codim,Ideal) >> opts -> (I) -> (
     if I.?LexGBOverBase then (
         S := ring I.LexGBOverBase#0; -- should be of the form kk(indepvars)[fibervars]
         # I.Linears + numgens S
         )
     else 
         # I.Linears + codim(I.Ideal)
     )

codimLowerBound = method()
codimLowerBound AnnotatedIdeal := (I) -> (
     if I.?LexGBOverBase then (
         S := ring I.LexGBOverBase#0; -- should be of the form kk(indepvars)[fibervars]
         # I.Linears + numgens S
         )
     else (
          GB := getGB I.Ideal;
          if GB =!= null then (
             # I.Linears + codim(monomialIdeal leadTerm GB)
             )
          else if numgens I.Ideal === 1 and I.Ideal_0 != 0 then
             # I.Linears + 1
          else
             # I.Linears
         )
     )

{*
annotatedIdeal Ideal := (I) -> (
     -- input: ideal I in a polynomial ring R
     linears := for x in gens ring I list (
         k := position(I_*, f -> first degree contract(x,f) == 0);
         if k === null then continue;
         m := makeLinearElement(x, I_k);
         I = replaceVariable(I,m);
         m);
     newI := annotatedIdeal(I, linears, {}, {});
     if #linears === 0 then newI.Linear = true;
     newI
     )
*}

{*
net AnnotatedIdeal := (I) -> (
    net new HashTable from {
        "Ideal" => if numgens I.Ideal === 0 then net I.Ideal else netList (I.Ideal)_*, 
        "Linears" => netList (I.Linears)}
    )
*}
net AnnotatedIdeal := (I) -> peek I

ring AnnotatedIdeal := (I) -> ring I.Ideal

-- The associated ideal to an annotated ideal I is
-- defined at the top of this file.
-- TODO Notes (23 April 2013):
--  (1) Possibly split the linears into two groups, and add the ones with denom=1
--      after the saturation is done.
--  (2) Should we be saturating with the I.Inverted \ I.NonzeroDivisors polynomials? 
--    Answer should be yes: but if we know the ideal is prime, then 
--    we think we can avoid this.  BUT: we need to be very precise about
--    this logic.
ideal AnnotatedIdeal := (I) -> (
    --F := product unique join(I.Linears / (x -> x#1),I.Inverted);
    F := product unique (I.Linears / (x -> x#1));
    I1 := ideal(I.Linears/last);
    I2 := if I.?IndependentSet then (
            S := (I.IndependentSet)#1;
            phi := S.cache#"StoR";
            phi contractToPolynomialRing ideal I.LexGBOverBase
         )
          else
            I.Ideal;
    I3 := if numgens I1 === 0 then I2 else if numgens I2 === 0 then I1 else I1+I2;
    if F == 1 then I3 else saturate(I3, F)
    )

-- Note that if I.IndependentSet is set, then I.Ideal is not the entire ideal.
-- However in this case, I.isPrime will (TODO: check this!) have previously
-- been set to "UNKNOWN", or maybe to "YES" during the IndependentSet or
-- SplitTower computatations.
isPrime AnnotatedIdeal := (I) -> (
    if I.?IndependentSet and not I.?isPrime 
      then error "our isPrime logic is wrong";
    if not I.?isPrime or I.isPrime === "UNKNOWN" then (
        I.isPrime = if numgens I.Ideal == 0 then "YES" else
                    if I.?Factorization and numgens I.Ideal == 1 then "YES" else
                    "UNKNOWN";
       );
    I.isPrime
    )

partitionPrimes = method()
partitionPrimes List := Is -> (
   P := partition(I -> isPrime I === "YES",Is);
   -- have to check to see if there are any true/false at all before '#'
   (if P#?true then P#true else {},if P#?false then P#false else {})
)

partitionPrimes AnnotatedIdeal := I -> partitionPrimes {I}

flagIsPrime = method()
flagIsPrime AnnotatedIdeal := I -> (isPrime I; I)

--- this is so that we can add in generators to I and keep track of
--- how the annotation changes
--- TODO: make sure that this method is only being used where I.NonzeroDivisors
--   should be considered non-zero-divisors for the sum.
AnnotatedIdeal + Ideal := (I,J) -> (
   annotatedIdeal(J + I.Ideal,
                  I.Linears,  -- 'linear' generators
                  {},        -- clear out nonzerodivisor list
                  unique join(I.NonzeroDivisors,I.Inverted)) -- move nonzerodivisors to inverted list
)

trim AnnotatedIdeal := opts -> I -> (
    I.Ideal = trim I.Ideal;
    I
)

squarefreeGenerators AnnotatedIdeal := opts -> I -> (
   if I.?Squarefree then return I; 
   nonzeros := set I.Inverted;
   J := I.Ideal;
   n := opts#"SquarefreeFactorSize";
   madeChanges := false;
   J1 := ideal for g in J_* list (
              if size g > n then g
              else (
                nonzeroFacs := set ((factors g) / last) - nonzeros;
                h := product toList nonzeroFacs;
                if g != h then madeChanges = true;
                h
              )
         );
   if madeChanges then
      -- note that the NonzeroDivisor list is empty below since elements
      -- can become zerodivisors when removing powers of generators
      annotatedIdeal(J1,I.Linears,{},unique join(I.NonzeroDivisors,I.Inverted))
   else 
      I
)

splitLexGB AnnotatedIdeal := I -> (
    if not I.?IndependentSet then return {I};
    if I.?LexGBSplit then return {I};
    IF := ideal I.LexGBOverBase;
    L := IF_*;
    for f in L do (
        facs := factors f;
        if #facs == 1 and facs#0#0 == 1 then continue;
        return flatten for fac in facs list (
               J := ideal gens gb ((ideal fac#1) + IF);
               Jann := new AnnotatedIdeal from I;
               Jann.LexGBOverBase = J_*;
               splitLexGB Jann
            )
        );
    -- At this point, all generators of IF_* are irreducible over the base field
    I.isPrime = if #select(L, f -> sum first exponents leadTerm f > 1) <= 1 then
       "YES"
    else
       "UNKNOWN";
    I.LexGBSplit = true;
    {I}
    )

nzds = method()
nzds AnnotatedIdeal := (I) -> I.NonzeroDivisors
------------------------------------------------------------
-- splitIdeal code

splitIdeal = method(Options => {Strategy=>defaultStrat,
                                Verbosity=>0,
                                "CodimensionLimit" => null,
                                "SquarefreeFactorSize" => 1})
  -- possible Strategy values:
  --  Linear     -- Eliminates variables where a generator is of the form x - g
                 -- for g not containing x
  --  Birational         -- Tries to eliminates variables where a generator is of
                         -- the form g*x - h for g,h not containing x.
                         -- If g is a nzd mod I, this eliminates x.  Else,
                         -- if g is in the radical of I, add in g to I and return
                         -- else, split with g as: (sat(I,g), (I:sat(I,g)))
  --  IndependentSet     -- Find an independent set (annotate this), find a flattener,
                         -- and split using flattener
  --  SplitTower         -- For an ideal which has LexGBSplit set to true, this splits the
                         -- ideal into prime (annotated) ideals
  --  Factorization -
  --  CharacteristicSets -

splitFunction = new MutableHashTable
-- each function should like like this:
-- splitFunction#MyStrategy = (I, opts) -> ...
    -- I is an AnnotatedIdeal
    -- opts is from options of splitIdeal
    -- return value is tuple (I1s, I2s), where
    --   I1s is a list of AnnotatedIdeal's, known to be prime
    --   I2s is a list of AnnotatedIdeal's, primality unknown

splitFunction#Trim = (I, opts) -> if I.?Trim then {I} else {trim I}

splitFunction#Linear = (I, opts) -> (
    if I.?Linear then return {I};
    J := I.Ideal;
    linears := for x in gens ring J list (
        k := position(J_*, f -> first degree contract(x,f) == 0);
        if k === null then continue;
        m := makeLinearElement(x, J_k);
        J = replaceVariable(J,m);
        m);
    newJ := if #linears === 0 then (
              I.Linear = true;
              I 
            )
            else
              annotatedIdeal(J, join(I.Linears, linears), I.NonzeroDivisors, I.Inverted);
    {newJ}
    )

splitFunction#Birational = (I, opts) -> (
      if I.?Birational then return {I};
      if I.Ideal == 1 then error "got a bad ideal";
      m := findGoodBirationalPoly I.Ideal;
        -- either null or a list {x, g, f=xg-h}, with f in ideal
      if m === null then (
          I.Birational = true;
          return {I};
          );
      splitt := if member(m#1, I.NonzeroDivisors) then null else splitBy(I.Ideal,m#1);
      if splitt === null then (
          -- in this case, m#1 is a nonzerodivisor
          -- we eliminate m#0
          J := eliminateLinear(I.Ideal, m);
          newI := annotatedIdeal(J, 
                                 append(I.Linears, m), 
                                 unique append(I.NonzeroDivisors, m#1),
                                 I.Inverted);
          -- if we wanted to, we could also place newI onto the "prime" list
          -- if newI.Ideal is generatedby one irreducible element
          return {newI};
          );

      (J1,J2) := splitt;  -- two ideals.  The first has m#1 as a non-zero divisor.
      if J1 == 1 then (
          -- i.e. m#1 is in the radical of I.Ideal
          g := m#1//factors/last//product; -- squarefree part of m#1
          if g == 1 then error "also a bad error";
          newI = ideal compress((gens I.Ideal) % g) + ideal g;
          newI = annotatedIdeal(newI, I.Linears, I.NonzeroDivisors, I.Inverted);
          return {newI};
          );

      {annotatedIdeal(J1, I.Linears, unique append(I.NonzeroDivisors, m#1), I.Inverted), 
       annotatedIdeal(J2, I.Linears, I.NonzeroDivisors, I.Inverted)}
    )


splitFunction#Factorization = (I,opts) -> (
    if I.?Factorization then return {I};
    J := I.Ideal;
    --- originally taken from facGB0 in PD.m2 -- 12/18/2012
    (f, facs) := findElementThatFactors J_*; -- chooses a generator of I that factors
    if #facs == 0 then ( 
        --<< "no elements found that factor" << endl; << "ideal is " << toString I << endl; 
        I.Factorization = true;
        return {I};
    );
    nonzeros := set I.Inverted;
    prev := set{};
    nonzeroFacs := toList(set facs - nonzeros);
    if #nonzeroFacs == 1 and nonzeroFacs#0 != f then
       return {annotatedIdeal(trim(ideal nonzeroFacs#0 + J),
                              I.Linears,
                              I.NonzeroDivisors,
                              I.Inverted)};
    L := for g in nonzeroFacs list (
          -- colon or sum?
          -- Try and fix UseColon?  May not be fixable...
          {*if opts#"UseColon" then (
          --   -- TODO: Find the components that are missing when using colons!
          --   --       This process will miss any component for which g is in I for all g.
          --   J = I:(f // g);
          *}
          {*
          J = (ideal(g) + I.Ideal);
          J = trim ideal apply(J_*, f -> (
                product toList (set ((factors f)/last) - nonzeros)
              ));
          *}
          J = I + ideal(g);
          J = trim squarefreeGenerators(J,"SquarefreeFactorSize" => opts#"SquarefreeFactorSize");
          J.Inverted = toList (set(J.Inverted) + prev);
          prev = prev + set{g};
          if numgens J.Ideal === 1 and J.Ideal_0 == 1 then continue else J
    );
    L
)

splitFunction#IndependentSet = (I,opts) -> (
    -- what do we need to stash in the answer from independentSets?
    -- does this really belong in the annotated ideal framework?
    -- create two annotated ideals:
    if isPrime I === "YES" then return {I};
    if I.?IndependentSet then return {I};
    J := I.Ideal;
    if J == 1 then error "Internal error: Input should not be unit ideal.";
    R := ring J;
    hf := if isHomogeneous J then poincare J else null;
    indeps := independentSets(J, Limit=>1);
    basevars := support first indeps;
    if opts.Verbosity >= 3 then 
        << "  Choosing: " << basevars << endl;
    (S, SF) := makeFiberRings(basevars,R);
    JS := S.cache#"RtoS" J;
    -- if basevars is empty, then return I, but put in the lex ring.
    -- return value not correct form yet
    if #basevars == 0 then (
        I.IndependentSet = ({},S,SF);
        I.LexGBOverBase = (ideal gens gb JS)_*;
        return splitLexGB I;
    );
    -- otherwise compute over the fraction field.
    if hf =!= null then gb(JS, Hilbert=>hf) else gb JS;
    --gens gb IS;
    (JSF, coeffs) := minimalizeOverFrac(JS, SF);
    if coeffs == {} then (
        I.IndependentSet = (basevars,S,SF);
        I.LexGBOverBase = JSF;
        splitLexGB I
    )
    else (
       facs := (factors product coeffs)/last;
       G := product facs;
       if opts.Verbosity >= 3 then
           << "  the factors of the flattener: " << netList(facs) << endl;
       G = S.cache#"StoR" G;
       J1 := saturate(J, G);
       J1ann := annotatedIdeal(J1,I.Linears,unique join(I.NonzeroDivisors,facs),I.Inverted);
       J1ann.IndependentSet = (basevars,S,SF);
       J1ann.LexGBOverBase = JSF;
       if J1 == J then
          splitLexGB J1ann
       else (
          J2 := trim (J : J1);
          J2ann := annotatedIdeal(J2,I.Linears,I.NonzeroDivisors,I.Inverted);
          join(splitLexGB J1ann,{J2ann})
       )
    )
)

splitFunction#SplitTower = (I,opts) -> (
    -- what do we need to stash in the answer from independentSets?
    -- does this really belong in the annotated ideal framework?
    -- create two annotated ideals:
    if isPrime I === "YES" then return {I};
    if I.?SplitTower then return {I};
    if not I.?IndependentSet or not I.?LexGBSplit then return {I};
    -- Finally we can try to split this ideal into primes
    L := I.LexGBOverBase;  -- L is the lex GB over the fraction field base
    --facsL := factorTower(L, Verbosity=>opts.Verbosity, "SplitIrred"=>true, "Minprimes"=>true);
    facsL := factorTower2(L, Verbosity=>opts.Verbosity);
    -- facsL is currently a list of lists:
    --   each list is of the form {exponent, poly}.  Here, we need to remove these exponents.
    if opts.Verbosity >= 4 then (
         << "SplitTower: Input: " << L << endl;
         << "           Output: " << netList facsL << endl;
         );
    didSplit := #facsL > 1 or any(facsL#0, s -> s#0 > 1);
    if not didSplit then (
         I.SplitTower = true;
         I.isPrime = "YES";
         {I}
         )
    else (
         for fac in facsL list (
              newI := new AnnotatedIdeal from I;
              --temp := fac / last;
              --if set temp =!= set flatten entries gens gb ideal (fac/last) then error "err";
              newI.LexGBOverBase = flatten entries gens gb ideal (fac/last);
              newI.SplitTower = true;
              newI.isPrime = "YES";
              newI
              )
         )
    )

splitFunction#DecomposeMonomials = (I,opts) -> (
    if isPrime I === "YES" then return {I};
    if I.?DecomposeMonomials or I.?IndependentSet then return {I};
    -- get all of the monomial generators of I,
    -- find all minimal primes of those, and return lots of annotated ideals adding these monomial generators
    monoms := select(I.Ideal_*, f -> size f === 1);
    if #monoms === 0 then (
        I.DecomposeMonomials = true;
        return {I};
        );
    comps := decompose monomialIdeal monoms;
    R := ring I;
    for c in comps list (
        newI := flatten entries compress ((gens I.Ideal) % c);
        J := if #newI === 0 
             then ideal matrix(R, {{}})
             else trim(ideal newI);
        newlinears := for x in c_* list (x, leadCoefficient x, x);
        annJ := annotatedIdeal(J, join(I.Linears, newlinears), I.NonzeroDivisors, I.Inverted);
        if #newI === 0 then annJ.isPrime = "YES";
        annJ
        )
    )

isStrategyDone = method()
isStrategyDone (List,Symbol) := (L,strat) ->
  all(L, I -> I#?strat or (I.?isPrime and I.isPrime === "YES"))

-------------------------------------------------------------------------
--- Begin new nested strategy code

-- format for strategy:
-- a strategy is one of the following:
--  1. Symbol (allowed: Linear, Factorization, ...)
--  2. (strategy, #times)
--  3. list of strategies
-- If no #times is given (e.g. in (1) or (3), then 1 is assumed)

-- each of the splitIdeals routines:
--  takes a list of annotated ideals, and returns a similar list
--  
splitIdeals = method(Options => options splitIdeal)

strategySet = strat -> (
    if instance(strat, Symbol) then set {strat}
    else if instance(strat, List) then sum(strat/strategySet)
    else if instance(strat, Sequence) then strategySet first strat
    )

separateDone = (L, strats) -> (
    -- L is a list of annotated ideals
    H := partition(f -> all(strats, s -> isStrategyDone({f}, s)), L);
    (if H#?true then H#true else {}, if H#?false then H#false else {})
    )

separatePrime = (L) -> (
    -- L is a list of annotated ideals
    -- returns (L1,L2), where L1 is the list of elements of L which are known to be prime
    -- and L2 are the rest
    H := partition(I -> (I.?isPrime and I.isPrime === "YES"), L);
    (if H#?true then H#true else {}, if H#?false then H#false else {})
    )

splitIdeals(List, Symbol) := opts -> (L, strat) -> (
    -- L is a list of annotated ideals
    -- process each using strategy 'strat'.
    -- return (L1, L2), where L1 consists of the ideals
    --   that are either prime, or are done using this method
    --   (i.e. running it through this strategy again would have no effect).
    -- and L2 are ideals which may or may not be done, but we don't know that yet.
    if not member(strat,{
            Linear,
            Birational,
            Factorization,
            IndependentSet,
            SplitTower,
            DecomposeMonomials,
            Trim
            }) then
          error ("Unknown strategy " | toString strat | " given.");
    flatten for f in L list (
        if opts.Verbosity >= 2 then (
            << "  Strategy: " << pad(toString strat,18) << flush;
            );
        tim := timing splitFunction#strat(f, opts);
        ans := tim#1;
        numOrig := #ans;
        if opts#"CodimensionLimit" =!= null then 
            ans = select(ans, i -> codimLowerBound i <= opts#"CodimensionLimit");
        if opts.Verbosity >= 2 then << pad("(time " | toString (tim#0) | ") ", 16);
        if opts.Verbosity >= 2 then (
            knownPrimes := #select(ans, I -> isPrime I === "YES");
            << " #primes = " << knownPrimes << " #prunedViaCodim = " << numOrig - #ans << endl;
            );
        ans
        )
    )
splitIdeals(List, Sequence) := opts -> (L, strat) -> (
    (strategy, n) := strat;
    strategies := toList strategySet strat;
    (L1,L2) := separateDone(L, strategies);
    while n > 0 and #L2 != 0 do (
        M := splitIdeals(L2, strategy, opts);
        (M1,M2) := separateDone(M, strategies);
        L1 = join(L1, M1);
        L2 = M2;
        n = n-1;
        );
    join(L1,L2)
    )
splitIdeals(List, List) := opts -> (L, strat) -> (
    strategies := toList strategySet strat;
    (L1,L2) := separateDone(L, strategies);
    for s from 0 to #strat-1 do (
         L2 = splitIdeals(L2, strat#s, opts);
         (M1,M2) := separateDone(L2, strategies);
         L1 = join(L1, M1);
         L2 = M2;
         );
    join(L1,L2)
    )
splitIdeal(Ideal) := opts -> (I) -> (
    splitIdeals({annotatedIdeal(I,{},{},{})}, opts.Strategy, opts)
    )
splitIdeal(AnnotatedIdeal) := opts -> (I) -> (
    splitIdeals({I}, opts.Strategy, opts)
    )

stratEnd = {(IndependentSet,infinity),SplitTower}

minprimesWithStrategy = method(Options => options splitIdeals)
minprimesWithStrategy(Ideal) := opts -> (I) -> (
    newstrat := {opts.Strategy, stratEnd};
    if opts#"CodimensionLimit" === null then 
      opts = opts ++ {"CodimensionLimit" => numgens I};
    M := splitIdeals({annotatedIdeal(I,{},{},{})}, newstrat, opts);
    numRawPrimes := #M;
    M = select(M, i -> codim i <= opts#"CodimensionLimit");
    (M1,M2) := separatePrime(M);
    if #M2 > 0 then (
         ( << "warning: ideal did not split completely: " << #M2 << " did not split!" << endl;);
         error "answer not complete";
         );
    if opts#Verbosity>=2 then (
       << "Converting annotated ideals to ideals and selecting minimal primes." << endl;
    );
    answer := M/ideal//selectMinimalIdeals;
    if opts.Verbosity >= 2 then (
         if #answer < numRawPrimes then (
              << "#minprimes=" << #answer << ", #underCodimLimit=" << #M << " #computed=" << numRawPrimes << endl;
              );
         );
    answer
    )

----- End new nested strategy code

end

restart
debug needsPackage "PD"
R1 = QQ[d, f, j, k, m, r, t, A, D, G, I, K];
I1 = ideal ( I*K-K^2, r*G-G^2, A*D-D^2, j^2-j*t, d*f-f^2, d*f*j*k - m*r, A*D - G*I*K);
time minprimes(I1, "CodimensionLimit"=>6, Verbosity=>2)
time minprimes(I1, "CodimensionLimit"=>7, Verbosity=>2)
time minprimes(I1, "CodimensionLimit"=>6, Verbosity=>2);

