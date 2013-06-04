--- This file contains commands for factorization of polynomials over
--- a tower of irreducibles.

needs "quickGB.m2"

--- a few commands to make cartesian product of lists easier (and faster than using toList and set!)
List ** List := (xs,ys) -> flatten for y in ys list apply(xs, x -> {x,y})
-- compose all functions in a list
composeList := fs -> if #fs == 0 then identity else (first fs) @@ (composeList drop(fs,1))
-- takes the iterated cartesian product of a List of Lists.  Care is taken
-- to avoid flattening all the way, since the original list may be a list of lists.
cartProdList = method()
cartProdList List := xss -> (
    if #xss < 2 then return xss;
    if #xss == 2 then return (first xss) ** (last xss); 
    xsLengths := xss / length / (i -> toList(0..(i-1)));
    indexList := fold(xsLengths, (as,bs) -> (as ** bs) / flatten);
    apply(indexList, l -> apply(#l, i -> xss#i#(l#i)))
)

factorListToIdeal = method()
factorListToIdeal List := facs -> ideal gens gb ideal apply(facs, p -> (p#1)^(p#0))

idealToFactorList = method()
idealToFactorList Ideal := I -> flatten (I_* / factors / (l -> l / toList))

factorTower = method(Options => {Verbosity => 0})
factorTower List := opts -> polyList -> (
    -- partition the generators into linear and nonlinear terms
    E := partition(p -> hasLinearLeadTerm(p // leadCoefficient p), polyList);
    -- nothing to do, since all generators are linear
    if not E#?false then return {apply(polyList, p -> {1,p})};
    nonlinears := E#false;
    if #nonlinears <= 1 then return {apply(polyList, p -> {1,p})};
    -- keep for later - we will take them out of the computation and reinsert them.
    linears := if E#?true then E#true else {};
    -- here, we are using that nonlinears_0 is irreducible over the fraction field.
    retVal := {{{1,nonlinears_0}}};
    for i from 1 to #nonlinears - 1 do (
       retVal = flatten for facList in retVal list (
                   newFacs := factorOverTowerWorker(facList / last,nonlinears_i,opts);
                   apply(newFacs, newFac -> facList | {newFac})
                );
    );
    -- put the linear generators back in
    retVal / (C -> apply(linears, l -> {1,l}) | C)
)

factorTower Ideal := opts -> I -> (
   factorTower(I_*,opts) / factorListToIdeal
)

factorOverTower = method(Options => options factorTower)
factorOverTower (List,RingElement) := opts -> (tower,f) -> (
   --- This function just sets up the rings properly using makeFiberRings
   --- so that the calls in the worker function below will work properly.
   R := ring f;
   -- get the variables to invert.
   baseVars := support first independentSets (ideal tower + ideal f);
   (S,SF) := makeFiberRings(baseVars, R);
   -- need to make sure the monomial order is correct.  The
   -- variables need to be in the right order.
   towerS := flatten entries gens gb sub(tower,S);
   fS := sub(f,S);
   facs := factorOverTowerWorker(towerS, fS % (ideal towerS));
   -- now place back in the correct ring.
)

factorOverTowerWorker = method(Options => options factorTower)
factorOverTowerWorker (List,RingElement) := opts -> (tower,f) -> (
    -- Input : Irreducible tower over a ring of the form k(xs)[ys]
    --           (which was created from makeFiberRings) and another ring element.
    -- Output : The factors of f modulo the irreducible tower in the form
    --          {{power,irred},...}
    
    --- Checks first on the support of f and tower...
    vecdim := tower/(p -> (first degree leadTerm p))//product;  -- the vector space dimension of the extension of k(basevars) that the irred ideal gives
    IF := ideal gens gb ideal (tower | {f});
    L := ideal (IF_* / numerator);
    S := ring L;
    SF := ring IF;
    varsList := IF_* / leadTerm / support // flatten;
    lastVar := varsList#0; -- this is the smallest variable in the monomial order
    otherVars := drop(varsList, 1); 
    F := sum apply(otherVars, x -> (1 + random 10) * x);
    -- change coordinates
    IF1 := sub(IF, lastVar => lastVar + F);
    L1 := ideal(IF1_*/numerator);
    lastVar = numerator lastVar;      -- put lastVar in the correct ring
    otherVars = otherVars/numerator;  -- as well as the other variables
    -- as of now, we use quickGB if the base field is not a fraction field.
    -- use modPFracGB here too perhaps?
    G := if numgens coefficientRing S == 0 then
                 (quickEliminate(L1,otherVars))_0
              else
                 (eliminate(L1, otherVars))_0;
    completelySplit := degree(lastVar, G) === vecdim;
    if char ring f > 0 and char ring f <= vecdim and not completelySplit then (
       << endl;
       << "*** SplitTower called on ring of small characteristic relative to ideal." << endl;
       << "*** Take the answer with a grain of salt." << endl;
    );
    facs := factors G;
    facs1 := apply(facs, (mult,h) -> (mult,sub(h, lastVar => lastVar - (numerator F))));
    if opts.Verbosity >= 3 then (
       << "Factoring over tower: " << endl;
       print netList tower;
    );
    if opts.Verbosity >= 2 then (
      apply(facs1, f -> (ltf := leadTerm S.cache#"StoSF" f#1;
                         << "Variable : " << support ltf << "  LeadTerm : " << ltf << endl << endl;
                         << S.cache#"StoSF" f#1 << endl << endl;));
    );
    firstFacs := 1_SF;
    lastIrred := IF_(numgens IF - 1);
    -- sort the factors (by degree) and only compute GB for the first n-1 of them
    facs1 = (sort apply(#facs1, i -> (first degree facs1#i#1,facs1#i))) / last;
    -- select the factors which are nonunits of SF
    facs1 = select(facs1, f -> not isUnit(S.cache#"StoSF" f#1));
    if #facs1 == 0 then return {};  -- in this case, there are no nonunit factors of f.
    if (#facs1 == 1 and facs1#0#0 == 1) then return {(1,f)};
    j := 0;
    -- Note that the second condition forces the 'last factor' trick to not occur
    -- in case the polynomial is, for example, a pure power of an irreducible mod the tower
    retVal := while (j <= #facs1 - 2 or (j == #facs1-1 and facs1#j#0 > 1)) list (
                 fac := facs1#j;
                 j = j + 1;
                 G = (fac#1) % L;
                 if G == 0 then
                    error "Internal error.  Tried to add in zero element to ideal in factorTower.";
                 newFac := makeMonicOverTower(tower,S.cache#"StoSF" G);
                 C := ideal gens gb ideal (IF_* | {newFac});
                 {*
                 C := time if MONICTOWERTRICK then (
                         newFac := makeMonicOverTower(tower,S.cache#"StoSF" G);
                         ideal gens gb ideal (IF_* | {newFac})
                      )
                      else (
                         modPGB := modPFracGB(ideal G + L,gens coefficientRing SF / S.cache#"SFtoS");
                         ideal gens gb S.cache#"StoSF" modPGB
                      );
                 *}
                 if C == 1 then continue;
                 newFactor := {fac#0, first toList (set C_* - set IF_*)};
                 firstFacs = firstFacs * (newFactor#1)^(newFactor#0);
                 -- something like this command needs to go here...
                 -- if not completelySplit then factorOverTowerWorker(tower,newFactor#1)
                 newFactor
    );
    -- if we made it all the way through facs1, then we are done.  Else, we may use
    -- the previous computations to determine the final factor
    if j == #facs1 then retVal
    else (
       lastFactor := lastIrred // firstFacs;
       newFactor = {(last facs1)#0, lastFactor};
       --if not completelySplit then factorOverTowerWorker(tower,newFactor#1)
       append(retVal, newFactor)
    )
)

makeMonicOverTower = method()
makeMonicOverTower (List,RingElement) := (tower,f) -> (
   --- This function takes an irreducible tower in the ring k(xs)[ys]
   --- and an element f whose lead term is a variable in varf, and variables later
   --- than varf, and returns f with its lead coefficient inverted
   --- where 'inverse' is taken in the ring mod the tower.
   varf := first support leadTerm f;
   lcf := contract(varf^(degree(varf,f)),f);
   tempRing := (ring f)/(ideal tower);
   phi := map(tempRing,ring f);
   psi := map(ring f, tempRing);
   fTemp := phi f;
   lcfTemp := phi lcf;
   psi (fTemp*(lcfTemp)^(-1))
)

end

--- a very baby example for factorTower
restart
debug needsPackage "PD"
R = QQ[r,s]
(S,SF) = makeFiberRings({},R)
use S
f = r^2-3
g = s^2+5*s+22/4
factorOverTower({f},g)
factorTower({f,g})

--- a very baby example for factorTower
restart
debug needsPackage "PD"
R = QQ[r,s]
(S,SF) = makeFiberRings({},R)
use S
f = r^2-3
g = s^2+5*s+22/4
factorTower({f,g})
factorTower({f,g},"SplitIrred"=>true)
factorTower({f^2,g},"SplitIrred"=>true, "Minprimes"=>true)
factorTower({f^2,g},"SplitIrred"=>true, "Minprimes"=>false)
gbTrace = 3
-- problem here, caught in an infinite loop.
factorTower({f^2,g^2},"SplitIrred"=>true, "Minprimes"=>false)
primaryDecomposition ideal {f^2,g^2}

--- another
restart
debug needsPackage "PD"
R = QQ[z,y]
(S,SF) = makeFiberRings({},R)
use S
f = z^2+1
g = y^3+3*y^2*z-3*y-z
-- we have a problem!
factorTower2 {f,g}
splitTower ideal {f,g}
