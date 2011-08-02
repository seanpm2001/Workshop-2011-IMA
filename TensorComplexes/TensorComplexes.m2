-- -*- coding: utf-8 -*-
--------------------------------------------------------------------------------
-- Copyright 2011  David Eisenbud, Daniel Erman, Gregory G. Smith and Dumitru Stamate
--
-- This program is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later
-- version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License along with
-- this program.  If not, see <http://www.gnu.org/licenses/>.
--------------------------------------------------------------------------------
{*Not needed now, but would be nice:
kk as an optional second argument
handling of rings (out put of pairs, so that ring name can be set)
facility for making tensors
exterior multiplication and contraction
Schur Functors
functoriality 
a code bettiTC that would tell you the Betti table of a tensor complex w/o computing the resolution
links to arXiv papers in the documentation
cleaning up tensorComplex1.  for instance, the balanced case should call the 
   non-balanced case, and compute w internally.
*}


newPackage(
  "TensorComplexes",
  AuxiliaryFiles => false,
  Version => "1.0",
  Date => "29 July 2011",
  Authors => {
    {	 
      Name => "David Eisenbud", 
      Email => "de@msri.org", 
      HomePage => "http://www.msri.org/~de/"},
    {
      Name => "Daniel Erman", 
      Email => "derman@math.stanford.edu", 
      HomePage => "http://math.stanford.edu/~derman/"},	     
    {
      Name => "Gregory G. Smith", 
      Email => "ggsmith@mast.queensu.ca", 
      HomePage => "http://www.mast.queensu.ca/~ggsmith"},
    {
      Name => "Dumitru Stamate", 
      Email => "dumitru.stamate@fmi.unibuc.ro"}},
  Headline => "multilinear algebra with labeled bases",
  DebuggingMode => true
  )

export {
  "LabeledModule",
  "LabeledModuleMap",
  "labeledModule",
  "underlyingModules",
  "basisList",
  "fromOrdinal",
  "toOrdinal",
  "multiSubsets",
  "tensorProduct",
  "symmetricMultiplication",
  "cauchyMap",
  "traceMap",
  "flattenedGenericTensor",
  "minorsMap",
  "tensorComplex1",
  "flattenedESTensor",
  "hyperdeterminant",
  "hyperdeterminantMatrix",
  "pureResTC1",
  "pureResTC",
  "pureResES1",
  "pureResES"
  }

--------------------------------------------------------------------------------
-- CODE
--------------------------------------------------------------------------------
-- constructing labeled modules
LabeledModule = new Type of HashTable
LabeledModule.synonym = "free module with labeled basis"

labeledModule = method(TypicalValue => LabeledModule)
labeledModule Module := M -> (
  if not isFreeModule M then error "expected a free module";
  new LabeledModule from {
    symbol module => M,
    symbol underlyingModules => {},
    symbol basisList => apply(rank M, i -> i),
    symbol cache => new CacheTable})
labeledModule Ring := S -> (
  new LabeledModule from {
    symbol module => S^1,
    symbol underlyingModules => {},
    symbol basisList => {{}},
    symbol cache => new CacheTable})

net LabeledModule := E -> net module E
LabeledModule#{Standard,AfterPrint} = 
LabeledModule#{Standard,AfterNoPrint} = E -> (
  << endl;				  -- double space
  << concatenate(interpreterDepth:"o") << lineNumber << " : free ";
  << ring E << "-module with labeled basis" << endl;)

module LabeledModule := E -> E.module
ring LabeledModule := E -> ring module E
rank LabeledModule := E -> rank module E
underlyingModules = method(TypicalValue => List)
underlyingModules LabeledModule := E -> E.underlyingModules
basisList = method(TypicalValue => List)
basisList LabeledModule := E -> E.basisList
fromOrdinal = method(TypicalValue => List)
fromOrdinal(ZZ, LabeledModule) := (i, E) -> (basisList E)#i
toOrdinal = method(TypicalValue => ZZ)
toOrdinal(Thing, LabeledModule) := (l, E) -> (
  position(basisList E, j -> j === l))

LabeledModule == LabeledModule := (E,F) -> (
  module E === module F 
  and underlyingModules E === underlyingModules F
  and basisList E === basisList F)

exteriorPower (ZZ, LabeledModule) := options -> (d,E) -> (
  S := ring E;
  r := rank E;
  if d < 0 or d > r then labeledModule S^0
  else if d === 0 then labeledModule S
  else new LabeledModule from {
      symbol module => S^(binomial(rank E, d)),
      symbol underlyingModules => {E},
      symbol basisList => subsets(basisList E, d),
      symbol cache => new CacheTable})

tomultisubset = x -> apply(#x, i -> x#i - i)
multiSubsets = method(TypicalValue => List)
multiSubsets (ZZ,ZZ) := (n,d) -> apply(subsets(n+d-1,d), tomultisubset)
multiSubsets (List,ZZ) := (L,d) -> apply(multiSubsets(#L,d), i -> L_i)

symmetricPower (ZZ, LabeledModule) := (d,E) -> (
  S := ring E;
  if d < 0 then labeledModule S^0
  else if d === 0 then labeledModule S
  else new LabeledModule from {
    symbol module => (ring E)^(binomial(rank E + d - 1, d)),
    symbol underlyingModules => {E},
    symbol basisList => multiSubsets(basisList E, d),
    symbol cache => new CacheTable})

productList = L -> (
  --L is supposed to be a list of lists
  n := #L;
  if n === 0 then {}
  else if n === 1 then apply(L#0, i -> {i})
  else if n === 2 then flatten table(L#0, L#1, (i,j) -> {i} | {j})
  else flatten table(productList drop(L,-1), last L, (i,j) -> i | {j}))

-- This code probably belongs in the core of Macaulay2
tensorProduct = method(Dispatch => Thing)
tensorProduct List := args -> tensorProduct toSequence args
tensorProduct Sequence := args -> (
  if #args === 0 then  error "expected more than 0 arguments"; -- note: can't return, since we don't know the ring!
  y := youngest args;
  key := (tensorProduct, args);
  if y =!= null and y#?key then y#key else (
    type := apply(args, class);
    if not same type then error "incompatible objects in tensor product";
    type = first type;
    meth := lookup(symbol tensorProduct, type);
    if meth === null then error "no method for tensor product";
    S := meth args;
    if y =!= null then y#key = S;
    S))
tensor(Matrix, Matrix) := Matrix => options -> (f,g) -> f**g;

LabeledModule.tensorProduct = T -> (
  L := toList T;
  num := #L;
  if num < 0 then error "expected a nonempty list";
  S := ring L#0;
  if num === 0 then labeledModule S
  else (
    if any(L, l -> ring l =!= S) then error "expected modules over the same ring";
    new LabeledModule from {
      symbol module => S^(product apply(L, l -> rank l)),
      symbol underlyingModules => L,
      symbol basisList => productList apply(L, l -> basisList l),
      symbol cache => new CacheTable}))
LabeledModule ** LabeledModule := tensorProduct
tensor(LabeledModule, LabeledModule) := LabeledModule => o -> (F,E) -> F ** E

LabeledModuleMap = new Type of HashTable
LabeledModuleMap.synonym = "map of labeled modules"
ring LabeledModuleMap := f->f.ring
source LabeledModuleMap := f->f.source
target LabeledModuleMap := f->f.target
matrix LabeledModuleMap := o-> f->f.matrix




map(LabeledModule, LabeledModule, Matrix) := o-> (E,F,f) ->
new LabeledModuleMap from {
  symbol ring => ring F,
  symbol source => F,
  symbol target => E,
  symbol matrix => map(module E,module F,f)}
map(LabeledModule, LabeledModule, Function) := o-> (E,F,f) ->
new LabeledModuleMap from {
  symbol ring => ring F,
  symbol source => F,
  symbol target => E,
  symbol matrix => map(module E,module F,f)}
map(LabeledModule, LabeledModule, List) := o -> (E,F,L) ->
new LabeledModuleMap from {
  symbol ring => ring F,
  symbol source => F,
  symbol target => E,
  symbol matrix => map(module E,module F,L)}
map(LabeledModule,LabeledModule,ZZ) := LabeledModuleMap => o -> 
(E,F,i) -> map(E,F,matrix map(module E, module F, i))
map(LabeledModule,LabeledModule,LabeledModuleMap) := LabeledModuleMap => o -> 
(E,F,f) -> map(E,F, matrix f)

net LabeledModuleMap := g -> net matrix g
LabeledModuleMap#{Standard,AfterPrint} = 
LabeledModuleMap#{Standard,AfterNoPrint} = f -> (
  << endl;				  -- double space
  << concatenate(interpreterDepth:"o") << lineNumber << " : Matrix";
  << " " << target f << " <--- " << source f;
  << endl;)

coker LabeledModuleMap := Module => f -> coker matrix f
rank LabeledModuleMap := ZZ => f -> rank matrix f
transpose LabeledModuleMap := LabeledModuleMap => f ->
map(source f,target f, transpose matrix f)

--want a betti command!
--betti(LabeledModuleMap) := HashTable => o-> f -> betti map(target f, source f, matrix f)
LabeledModule#id = E -> map(E,E,1)

LabeledModuleMap * LabeledModuleMap := LabeledModuleMap => (f,g) -> 
map(target f, source g, matrix f * matrix g)

tensor(LabeledModuleMap,LabeledModuleMap) := LabeledModuleMap => o -> (m,n) -> 
map((target m)**(target n), (source m)**(source n), (matrix m)**(matrix n))
LabeledModuleMap ** LabeledModuleMap := LabeledModuleMap => (f,g) -> tensor(f,g)

LabeledModuleMap.tensorProduct = T -> fold(tensor, T)
     
traceMap = method()
traceMap LabeledModule := LabeledModuleMap => E -> (
  S := ring E;
  T := E ** E;
  map(T, labeledModule S^1, (i,j) -> (
      I := fromOrdinal(i,T);
      if I_0 == I_1 then 1_S else 0_S)))

{*multisetToMonomial = (l,m) -> (
  seen := new MutableHashTable;
  scan(m, i -> if seen#?i then seen#i = seen#i +1 else seen#i = 1);
  apply(l, i -> if seen#?i then seen#i else 0))
monomialToMultiset = (l,e) -> flatten apply(#e, i -> toList(e#i:l#i))
*}


symmetricMultiplication = method(TypicalValue => LabeledModuleMap)
symmetricMultiplication (LabeledModule,ZZ,ZZ) := (F,d,e) -> (
  --make the map Sym^d(F)\otimes Sym^e F \to Sym^(d+e) F
  --Caveat: for large examples it would probably be better to make this as a sparse matrix!
  S := ring F;
  Sd := symmetricPower(d,F);
  Se := symmetricPower(e,F);
  Sde := symmetricPower(d+e,F);
  SdSe := tensorProduct {Sd,Se};
  map(Sde,SdSe, 
    (i,j) -> if fromOrdinal (i,Sde) == sort flatten fromOrdinal(j, SdSe) 
    then 1_S else 0_S))

cauchyMap = method(TypicalValue => LabeledModuleMap)
cauchyMap (ZZ, LabeledModule) := (b,E) -> (
  sour := exteriorPower(b,E);
  L := underlyingModules E;
  L10 := {exteriorPower(b,L#0)};
  L11 := apply(#L-1, j -> symmetricPower(b,L#(j+1)));
  L = L10 | L11;
  targ := tensorProduct L;
  M := mutableMatrix(ring E, rank targ, rank sour);
  local j;
  for i in basisList sour do (
    j = transpose i;
    if j#0 == unique j#0 then (
      j = apply(j, l -> sort l);
      M_(toOrdinal(j,targ), toOrdinal(i,sour)) = 1));
  map(targ, sour, matrix M))

flattenedGenericTensor = method()
flattenedGenericTensor (List, Ring) := LabeledModuleMap => (L,kk)->(
  --make ring of generic tensor
  if #L === 0 then error "expected a nonempty list";
  inds := productList apply(#L, i -> toList(0..L#i-1));
  x := symbol x;
  vrbls := apply(inds,i -> x_(toSequence i));
  local S;
  if #L === 1 then S=kk[x_0..x_(L_0-1)] 
  else S = kk[vrbls];
  --make generic tensor (flattened)
  Blist := apply(#L, i->labeledModule S^(L_i));
  --B = tensor product of all but Blist_0
  if #L === 1 then map(labeledModule S,Blist_0, vars S)
  else(
    B := tensorProduct apply(#L-1, i -> Blist_(i+1));     
    map(B, Blist_0, 
      (i,j) -> x_(toSequence({fromOrdinal(j, Blist_0)}| fromOrdinal(i, B))))))

minorsMap = method()
-- Since we may not need the "full" minors map, we may be able
-- to speed up this method.
minorsMap(Matrix, LabeledModule):= LabeledModuleMap => (f,E) -> (
  --Assumes that E has the form 
  --E = wedge^b((source f)^*) ** wedge^b(target f)
  --where source f and target f are labeled free modules.
  S := ring f;
  b := #((basisList E)_0_0);
  if b != #((basisList E)_0_1) or #((basisList E)_0) != 2
  then error "E doesn't have the right format";
  J := basisList E;
  sour := (underlyingModules((underlyingModules E)_0))_0;
  tar := (underlyingModules((underlyingModules E)_1))_0;
  map(labeledModule S, E, (i,j)-> (
      p := J_j;
      det submatrix(f, apply(p_1, k-> toOrdinal(k, tar)),
	apply(p_0, k-> toOrdinal(k, sour))))))

minorsMap(LabeledModuleMap, LabeledModule) := LabeledModuleMap => (f,E) ->
     minorsMap(matrix f, E)


isBalanced = f-> rank source f == sum ((underlyingModules target f)/rank)

tensorComplex1 = method()


{*
Make the first map of a generic tensor complex:
Given (over a ring R)
free modules Bi of ranks bi\geq 1,
a free module A, of rank a = sum bi.
a map A <--- \otimes_j Bj,
set d = (d0=0, d1=b1, d2 = b1+b2...). 

The desired map is the composite

F1= wedge^b1 A ** wedge^b1 B1* ** \otimes_{i\geq 2} S^{d_{j-1}-b1} Bj
by "trace" to 

G1=wedge^b1 A ** wedge^b1 B1* ** [ (\otimes_{j\geq 2} S^b1 Bj)* ** (\otimes_{j\geq 2} S^b1 Bj)]  \otimes_{i\geq 2} S^{d_{j-1}-b1} Bj
to (by reassociating)

G2=wedge^b1 A ** [wedge^b1 B1* **  (\otimes_{j\geq 2} S^b1 Bj)*] ** [(\otimes_{j\geq 2} S^b1 Bj)]  \otimes_{i\geq 2} S^{d_{j-1}-b1} Bj]
to (by the wedge ** sym to wedge map and multiplication in Sym

G3=wedge^b1 A ** [wedge^b1 \wedge_b1(\otimes_{j\geq 1} Bj*] ** \otimes_{i\geq 2} S^{d_{j-1}} Bj]
to (by the minors)

F0=R ** \otimes_{i\geq 2} S^{d_{j-1}} Bj]
*}


tensorComplex1 LabeledModuleMap := LabeledModuleMap => f -> (
  -- NOTE: local variables names following the notation from the
  -- Berkesch-Erman-Kummini-Sam "Tensor Complexes" paper
  -- 
  -- The input is f: A --> B1** B2** ... Bn, where f corresponds to 'phi^{\flat}'
  -- from the BEKS paper.
  --
  -- The output is the first map F0 <- F1 of the balanced tensor complex.
  -- If f is not balanced this outputs an error.  
  -- In the non-balanced case, there should be a weight vector as a second input.
  -- See below.
  if not isBalanced f then error "The map f is not a balanced tensor. Need to add a weight vector as a second input.";
  S := ring f;  
  B := {S^0} | underlyingModules target f;
  A := source f;
  n := #B-1;
  b := B / rank; -- {0, b1, b2,..,bn}
  d := accumulate(plus, {0} | b); --{0, b1, b1+b2...}
  if n === 0 then f
  else if n === 1 then 
    map(exteriorPower(b_1,B_1),exteriorPower(b_1,A)**labeledModule(S^{ -d_1}),{{det matrix f}})
  else(
    -- source of output map
    F1 := tensorProduct({exteriorPower(b_1,A), exteriorPower(b_1,B_1)} |
      apply(toList(2..n), j-> symmetricPower(d_(j-1)-b_1,B_j)));
    -- target of output map
    F0 := tensorProduct apply(n-1, j-> symmetricPower(d_(j+1), B_(j+2)));
    trMap := traceMap tensorProduct apply(toList(2..n), 
      j -> symmetricPower(b_1,B_j));
    G1 := tensorProduct(target trMap, F1);
    g0 := map(G1, F1, trMap ** id_F1); -- tc1
    G1factors := flatten(
      ((underlyingModules target trMap) | {F1}) / underlyingModules );
    -- G2 and G1 are isomorphic as free modules with ordered basis but different
    -- as labeled modules.  G2 is obtained from G1 by dropping parentheses in 
    -- the tensor product.
    G2 := tensorProduct G1factors;
    -- g1 is the isomorphism induced by dropping all parentheses in the tensor product.
    -- Due to indexing conventions, matrix(g1) is just an identity matrix.
    g1 := map(G2, G1, id_(S^(rank G1)));
    perm := join({2*n-2, 2*n-1}, toList(0..n-2), 
      flatten apply(n-1, j -> {j+n-1, j+2*n}));
    G3factors := G1factors_perm;
    G3 := tensorProduct G3factors;
    -- G3 is obtained from G2 by reordering the factors in the tensor product.
    -- g2 is the isomorphism induced by reordering the factors of the tensor product.
    -- The reordering is given by the permutation 'perm'.  
    permMatrix := mutableMatrix(S, rank G3, rank G2);
    for J in basisList G2 do permMatrix_(toOrdinal(J_perm,G3),toOrdinal(J,G2)) = 1;
    g2 := map(G3, G2, matrix permMatrix);
    --  G3=G3a**G3b**G3c. The map g3: G3->G4 is defined as the tensor product of 3 maps.
    G3a := G3factors_0;
    G3b := tensorProduct G3factors_(toList(1..n));
    G3c := tensorProduct G3factors_(toList(n+1..#G3factors-1));
    prodB := tensorProduct apply(n,i -> B_(i+1));  
    -- G4=G3a**G4b**G3c.
    -- We omit the isomorphism of G4 with (G3a**G4b)**G3c, since this corresponds to
    -- the identity matrix.  In other words target(g3) does not equal source (g4)
    -- as labeledModules.
    G4b := exteriorPower(b_1, prodB);
    dualCauchyMap := map (G4b, G3b, transpose cauchyMap(b_1, prodB));
    g3 := id_(G3a) ** dualCauchyMap ** id_(G3c); 
    symMultMap := map(F0, G3c, tensorProduct apply(n-1, 
      	j -> symmetricMultiplication(B_(j+2),b_1,d_(j+1)-b_1)));
    minMap := minorsMap(f, tensorProduct(G3a, G4b));
    g4 := minMap ** symMultMap;
    map(F0, F1 ** labeledModule S^{ -b_2}, g4 * g3 * g2 * g1 * g0)))


-- When f is a balanced tensor, then this reproduces the tensor
-- used by Eisenbud and Schreyer in their original construction of
-- pure resolutions.  For instance tensorComplex f will equal to their
-- pure resolution.  However, this function works even in the nonbalanced
-- case.  In that case, it produces the `natural' analogue of their tensor.

flattenedESTensor = method()
flattenedESTensor (List, Ring) := LabeledModuleMap => (L,kk)->(
  --make ring of generic tensor
  if #L === 0 then error "expected a nonempty list";
  if #L === 1 then error "expected a balanced tensor";
  n:=#L-1;
  x:=symbol x;
  S:=kk[x_0..x_(n-1)];
  Blist := apply(#L, i->labeledModule S^(L_i));
  --B = tensor product of all but Blist_0
  B := tensorProduct apply(#L-1, i -> Blist_(i+1));     
  map(B, Blist_0, 
      (i,j) -> if 0<=j-sum fromOrdinal(i,B) then if j-sum fromOrdinal(i,B)<n 
      then x_(j-sum fromOrdinal(i,B)) else 0 else 0)
 )


tensorComplex1 (LabeledModuleMap,List) := LabeledModuleMap => (f,w) -> (
  -- NOTE: local variables names following the notation from the
  -- Berkesch-Erman-Kummini-Sam "Tensor Complexes" paper
  -- 
  -- f: A --> B1** B2** ... Bn
  -- makes the map F0 <- F1 as above.
  -- w = (0,w1,...).  w must satisfy some technical conditions that are checked below.
  -- These technical conditions also appear in the documentation node for this function.
  if not w_0 == 0 and w_1 >=0 and min apply(toList(2..#w), i-> w_i-w_(i-1)) > 0 then 
      error "w not of the form (0,non-neg,increasing)";
  
  S := ring f;  
  B := {S^0} | underlyingModules target f;
  A := source f;
  a := rank A;
  n := #B-1;
  if #w != n+1 then error"weight vector has wrong length";
  b := B / rank; -- {0, b1, b2,..,bn}
  
  d1 := if w_1>0 then 1 else b_1;
  r1 := # select(w, wj -> wj < d1);
  if r1>2 then error "r1>2 is a case we can't handle";
  if n === 0 or n===1 and r1 ===1 then return f;
  if n === 1 and r1 === 2
      then return map(exteriorPower(b_1,B_1),exteriorPower(b_1,A)**labeledModule(S^{ -d1}), gens minors(b_1,matrix f));

    F1 := tensorProduct({exteriorPower(d1,A)}|
	 apply(toList(1..r1-1),j-> exteriorPower(b_j,B_j)) | -- r1 = 1 or 2
      apply(toList(r1..n), j-> symmetricPower(w_j-d1,B_j)));
    -- target of output map
    F0 := tensorProduct apply(n, j-> symmetricPower(w_(j+1), B_(j+1)));
    trMap := id_(labeledModule S);
--  I don't think these n>1 workarounds are needed anymore.  There's another one below.
    if n>1 then trMap = traceMap tensorProduct apply(toList(r1..n), 
      j -> symmetricPower(d1,B_j));
    G1 := tensorProduct(target trMap, F1);
    g0 := map(G1, F1, trMap ** id_F1);
    G1factors := flatten(
      ((underlyingModules target trMap) | {F1}) / underlyingModules );
    -- G2 and G1 are isomorphic as free modules with ordered basis but different
    -- as labeled modules
    G2 := tensorProduct G1factors;
    -- g1 is the map induced by dropping all parentheses in the tensor product  
---
    g1 := map(G2, G1, id_(S^(rank G1)));
    perm := {};
    if r1==2 then perm = join({2*n-2, 2*n-1}, toList(0..n-2), 
      flatten apply(n-1, j -> {j+n-1, j+2*n}))
    else  perm ={2*n}|toList(0..n-1)|flatten apply(n, j -> {j+n, j+2*n+1});
    G3factors := G1factors_perm;
    G3 := tensorProduct G3factors;
    -- g2 is an isomorphism obtain by reordering the factors of a tensor product.
    -- The reordering is given by the permutation 'perm'  
    permMatrix := mutableMatrix(S, rank G3, rank G2);
    for J in basisList G2 do permMatrix_(toOrdinal(J_perm,G3),toOrdinal(J,G2)) = 1;
    g2 := map(G3, G2, matrix permMatrix);
    G3a := G3factors_0;
    G3b := tensorProduct G3factors_(toList(1..n));
    G3c := labeledModule S; -- case n==1
    if n>1 then
        G3c = tensorProduct G3factors_(toList(n+1..#G3factors-1));
    prodB := tensorProduct apply(n,i -> B_(i+1));  
    G4b := exteriorPower(d1, prodB);
    dualCauchyMap := map (G4b, G3b, transpose cauchyMap(d1, prodB));
    g3 := id_(G3a) ** dualCauchyMap ** id_(G3c); 
--if r1 > n then symMultMap := id
    symMultMap := map(F0, G3c, tensorProduct apply(toList(r1..n), 
      	j -> symmetricMultiplication(B_j,d1,w_j-d1)));

    minMap := minorsMap(f, tensorProduct(G3a, G4b));
    g4 := minMap ** symMultMap;
    map(F0, F1 ** labeledModule S^{ -d1}, g4 * g3 * g2 * g1 * g0))

hyperdeterminant = method()
hyperdeterminant LabeledModuleMap := f -> (
     --hyperdeterminant of a boundaryformat tensor f
     --check boundary format
     b := apply(underlyingModules target f, M -> rank M);
     if not rank source f == 1 + sum b - #b then
     	  error"not boundary format!";
     w := {0,1}|apply(toList(2..#b), i-> sum(toList(0..i-2), j-> b_j)-(i-2));
     det matrix tensorComplex1 (f,w))

-- Gives a matrix of linear forms whose determinant equals the desired hyperdeterminant.
-- This only works for hyperdeterminants of boundary format.
hyperdeterminantMatrix = method()
hyperdeterminantMatrix LabeledModuleMap := f -> (
     --check boundary format
     b := apply(underlyingModules target f, M -> rank M);
     if not rank source f == 1 + sum b - #b then
     	  error"not boundary format!";
     w := {0,1}|apply(toList(2..#b), i-> sum(toList(0..i-2), j-> b_j)-(i-2));
     matrix tensorComplex1 (f,w))

-- There is a bijection between degree sequences and balanced tensor complexes.
-- This code takes a degree sequence to the first map of the corresponding
-- balanced tensor complex.
pureResTC1=method()     
pureResTC1 (List,Ring) := LabeledModuleMap =>(d,kk)->(
     b := apply(#d-1,i-> d_(i+1)-d_i);
     if min b<=0 then error"d is not strictly increasing";
     a := d_(#b) - d_0;
     f := flattenedGenericTensor({a}|b,kk);
     tensorComplex1(f)
     )


pureResTC=method()
pureResTC (List,Ring):=ChainComplex => (d,kk)->(
     res coker matrix pureResTC1(d,kk)
     ) 


--  This code takes a degree sequence and a base field as an input, and
--  it outputs the first map of the Eisenbud-Schreyer pure resolution 
--  corresponding to that degree sequence.
pureResES1=method()     
pureResES1 (List,Ring) := LabeledModuleMap =>(d,kk)->(
     b := apply(#d-1,i-> d_(i+1)-d_i);
     if min b<=0 then error"d is not strictly increasing";
     a := d_(#b) - d_0;
     f := flattenedESTensor({a}|b,kk);
     tensorComplex1(f)
     )

pureResES=method()
pureResES (List,Ring):=ChainComplex => (d,kk)->(
     res coker matrix pureResES1(d,kk)
     ) 

--------------------------------------------------------------------------------
-- DOCUMENTATION
--------------------------------------------------------------------------------
beginDocumentation()

doc ///
   Key 
      TensorComplexes
   Headline 
      multilinear algebra for the construction of tensor complexes
   Description
    Text
      A $b_1\times \cdots\times  b_n$ tensor with coefficients in a ring S may 
      be thought of as a multilinear linear form on 
      $X := Proj(Spec S \times \mathbb P^{b_1-1}\times \cdots \times \mathbb P^{b_n-1})$.
      (If $S$ is graded, we may replace $Spec S$ by $Proj S$.)
         
      This package provides a family of definitions around the notion of {\it LabeledModule} 
      that makes it convenient to manipulate complicated multilinear constructions with tensors. 
      We implement one such construction, that of Tensor Complexes, from the paper 
      ``Tensor Complexes: Multilinear free resolutions constructed from higher tensors''
      of Berkesch, Erman, Kummini and Sam (BEKS), which extends the construction of 
      pure resolutions in the paper ``Betti numbers of graded modules and cohomology of vector bundles''
      of Eisenbud and Schreyer. This itself is an instance of the technique of ``collapsing homogeneous
      vector bundles'' developed by Kempf and described, for example, in the book ``Cohomology of
      vector bundles and syzygies'' of Weyman. 
      
      Tensor complexes specialize to several well-known constructions including: the Eagon-Northcott 
      and Buchsbaum-Rim complexes, and the others in this family described by Eisenbud and Buchsbaum 
      (see Eisenbud ``Commutative algebra with a view towards algebraic geometry'', A2.6), 
      and the {\it hyperdeterminants} of Weyman and Zelevinsky.
  
      A collection of $a$ tensors of type $b_1\times \dots \times b_n$ 
      may be regarded as a map $E := \mathcal O_X^a(-1,-1,\dots,-1) \to \mathcal O_X$ (with $X$ as above). 
      Equivalently, we may think of this as a single $a \times b_1 \times \cdots \times b_n$ tensor.
      
      One important construction made from such a collection of tensors is the Koszul complex 
      $$
      \mathbf K := \cdots \wedge^2 \oplus_1^a O_X(-1,\dots, -1) \to  O_X  \to 0.
      $$
      Let $\mathcal O_X(d, e_1,\dots e_n)$ be the tensor product of the pull-backs to $X$ 
      of the line bundles $\mathcal O_{\mathbb P^n}(d)$ and  $\mathcal O_{\mathbb P^{b_i-1}}(-1)$.  
      If we twist the Koszul complex by $O_X(0, -w_1, \dots -w_n)$ 
      and then push it forward to $Spec S$ we get the tensor complex 
      $F(\phi,w)$ of BEKS. 
      
      Each map $\partial_i$ in the tensor complex can be defined by
      a rather involved construct in multilinear algebra. This package implements the 
      construction of $\partial_1$ in the range of cases described explicitly in BEKS 
      (Sections 4 and 12).
      This range includes the hyperdeterminants of boundary format, 
      the construction of the first map of the pure resolutions of Eisenbud-Schreyer, 
      and the first map in most of the much larger family of generic pure resolutions of BEKS.
///

doc ///
   Key 
    tensorComplex1
    (tensorComplex1, LabeledModuleMap, List)
    (tensorComplex1, LabeledModuleMap)
   Headline
    computes the first map of the tensor complex
   Usage
    tensorComplex1(f,w)
    tensorComplex1 f
   Inputs
    f: LabeledModuleMap
    w: List 
       of ZZ
   Outputs
    : LabeledModuleMap
   Description
    Text
      Let $X := Proj(Spec S \times \mathbb P^{b_1-1}\times \cdots \times \mathbb P^{b_n-1})$,
      and let
      $$
      \mathbf K := \cdots \wedge^2 \oplus_1^a O_X(-1,\dots, -1) \to  O_X  \to 0
      $$
      be the Koszul complex of the multilinear forms corresponding to f, on $X$.
      The output of {\tt tensorComplex1(f,w)} is the first map of the complex obtained
      by pushing $\mathbf K \otimes {\mathcal O}_X(w_1,\dots,w_n)$ down to $Spec S$.

      This script implements the construction of tensor complexes from the paper 
      ``Tensor Complexes: Multilinear free resolutions constructed from higher tensors''
      of Berkesch, Erman, Kummini and Sam (BEKS).
      
      The program requires that $f$ is a flattened tensor, 
      that is, a map $A \to B_1\otimes\cdots\otimes B_n$.
      Returns the first map in the tensor complex $F(f,w)$ of BEKS, requiring
      that $w$ satisfies:
      $$
      w_0 = 0, w_1 \geq 0, w_2 \geq w_1+b_1, \ {\rm and }\  w_i>w_{i-1} \ {\rm for }\ i\geq 2.
      $$
      
      When $rank A=\sum rank B_i$, that is, $L_0 = \sum_{i=1}^n L_i$ then
      we are in the ``balanced case'' discussed in Section 3 of BEKS. In
      this case giving a weight vector is unnecessary, and one can use the format
      {\tt tensorComplex1 f}.
      
      The example from section 12 of BEKS appears below.
      
    Example
      f = flattenedGenericTensor({4,2,2},ZZ/32003)
      S = ring f;
      g = tensorComplex1(f,{0,0,2})
      g1 = tensorComplex1 f
      betti matrix g
      betti matrix g1
      betti res coker g
    
    Text
      We can recover the Eagon-Northcott complex as follows. 
   
    Example
      f = flattenedGenericTensor({6,2}, ZZ/32003) 
      S = ring f;
      g = tensorComplex1(f,{0,0});
      transpose g
      betti res coker g
      betti eagonNorthcott matrix f
      
    Text
      The following example is taken from the introduction to BEKS.
    
    Example
      f = flattenedGenericTensor({7,1,2,1,2,1},ZZ/32003);
      S = ring f;
      g = tensorComplex1 f;
      betti res coker g

    Text
      The input map need not be generic.
    
    Example
      S = QQ[x,y,z];
      F = labeledModule S^5
      G = tensorProduct(labeledModule S^2, labeledModule S^2)
      f = map(G,F, (i,j) -> random(1,S))
      g = tensorComplex1(f, {0,0,2});
      betti res coker g
      
   Caveat
     Unlike BEKS, this method does not work with arbitrary weight vectors {\tt w}.
      
   SeeAlso
    flattenedGenericTensor
    flattenedESTensor
    hyperdeterminant
    hyperdeterminantMatrix
///

doc ///
   Key 
     LabeledModule
   Headline 
     the class of free modules with a labeled basis
   Description
    Text
      A labeled module $F$ is a free module together with two additional pieces of data:
      a @TO basisList@ which corresponds to the basis of $F$, and
      a list of @TO underlyingModules@ which were used in the construction of $F$. The constructor
      @TO labeledModule@ can be used to construct a labeled module from a free module. The call
      {\tt labeledModule E}, where $E$ is a free module, returns a labeled module with @TO basisList@
      $\{1,\dots, rank E\}$ and @TO underlyingModules@ $\{E\}$.ß
      
      For example if $A,B$ are of type LabeledModule, then
      {\tt F=tensorProduct(A,B)} constructs the LabeledModule $F=A\otimes B$ with 
      @TO basisList@ equal to the list of pairs $\{a,b\}$ where $a$ belongs to the basis list
      of $A$ and $b$ belongs to the basis list of $b$. The list of @TO underlyingModules@ of $F$
      is $\{A,B\}$.
      
      Certain functors which are the identity in the category of modules are non-trivial
      isomorphisms in the category of labeled modules.  For example, if {\tt F} is a labeled
      module with basis list {\tt \{0,1\}} then {\tt tensorProduct F} is a labeled free module
      with basis list {\tt \{\{ 0\},\{ 1\}\} }.  Similarly, one must be careful when applying the functors
      @TO exteriorPower@ and @TO symmetricPower@.  For a ring $S$, the multiplicative unit 
      for tensor product is the rank 1 free $S$-module whose generator is labeled by {\tt \{\} }. 
      This is constructed by {\tt labeledModule S}.
///



doc ///
   Key 
     labeledModule
     (labeledModule,Module)
     (labeledModule,Ring)   
   Headline
     makes a labeled module     
   Usage
     labeledModule M
     labeledModule R
   Inputs
     M: Module
       which is free
     R: Ring  
   Outputs
     : LabeledModule
   Description
    Text
      This is the basic construction for a @TO LabeledModule@.  Given a free module $M$ of rank $r$,
      this constructs a labeled module with basis labeled by $\{0,..,r-1\}$ and
      no underlying modules.
    Example
      S = ZZ/101[a,b,c];
      E = labeledModule S^3
      basisList E
      underlyingModules E
      module E
      rank E
    
    Text
      For technical reasons, it is often convenient to construct a rank $1$ free module
      whose generator is labeled by the empty set. This is constructed by {\tt labeledModule S}.
      
      
    Example
      S = ZZ/101[a,b,c];
      F = labeledModule S
      basisList F
      underlyingModules F
      module F
      E = labeledModule S^1
      basisList E
      underlyingModules E 
///
doc ///
   Key 
    tensorProduct
   Headline
    tensor product of Modules and LabeledModules, Matrices, Maps and LabeledModuleMaps
   Usage
    tensorProduct L
    (tensorProduct List)
    (tensorProduct Sequence)
   Inputs
    L: List
     or @TO Sequence@ of objects of type @TO Matrix@, @TO Module@, @TO LabeledModule@ or @TO LabeledModuleMap@
   Outputs
    :Matrix
     or, in general, an object of the same type as the inputs.
   Description
    Text
     Forms the tensor product of the objects in the input list or sequence. 
     In the case where the inputs are of type @TO LabeledModule@, the output is a labeled module
     whose basis list is the set of tuples of elements of the basis lists of the input modules
    Example
     S = ZZ/101[x,y]
     M = labeledModule(S^4)
     basisList M
     E = exteriorPower(2,M)
     basisList E
     underlyingModules E
     N = tensorProduct(E,labeledModule(S^2))
     basisList N
     underlyingModules N
   SeeAlso
    basisList
    underlyingModules
    LabeledModule
    LabeledModuleMap
    "**"
///


doc ///
   Key
     hyperdeterminant
     (hyperdeterminant, LabeledModuleMap)
   Headline
     computes the hyperdeterminant of a boundary format tensor
   Usage
     hyperdeterminant f
   Inputs
     f: LabeledModuleMap
   Outputs
     : RingElement
   Description
    Text
      This constructs the hyperdeterminant of a tensor of {\em boundary format}, where
      we say that a $a\times b_1\times \dots \times b_n$ has boundary format if
      $$
      a-\sum_{i=1}^n (b_i-1)=1.
      $$
      We construct the hyperdeterminant as the determinant of a certain square matrix
      derived from $f$.  The {\tt hyperdeterminant} function outputs the hyperdeterminant
      itself, whereas the @TO hyperdeterminantMatrix@ function outputs the matrix used to
      compute the hyperdeterminant.  (For background on computing hyperdeterminants, see
      Section 14.3 of the book ``Discriminants, resultants, and multidimensional
      determinants '' by Gelfand-Kapranov-Zelevinsky.)
      
      The following constructs the generic hyperdetermiant of format $3\times 2\times 2$,
      which is a polynomial of degree 6 consisting of 66 monomials.
    
    Example
      f=flattenedGenericTensor({3,2,2},QQ);
      S=ring f;
      h=hyperdeterminant f;
      degree h
      #terms h    
      
   Caveat
     There is bug involving the graded structure of the output. Namely, the code assumes that
     all entries of {\tt f} have degree 1, and gives the wrong graded structure if this is not
     the case. If {\tt ring f} is not graded, then 
     the code gives an error.  
     
   SeeAlso
     hyperdeterminantMatrix
///

doc ///
   Key
     hyperdeterminantMatrix
     (hyperdeterminantMatrix, LabeledModuleMap)
   Headline
     computes a matrix whose determinant equals the hyperdeterminant of a boundary format tensor
   Usage
     hyperdeterminantMatrix f
   Inputs
     f: LabeledModuleMap
   Outputs
     : LabeledModuleMap
   Description
    Text
      This constructs a matrix whose determinant equals 
      the hyperdeterminant of a tensor of {\em boundary format}, where
      we say that a $a\times b_1\times \dots \times b_n$ has boundary format if
      $$
      a-\sum_{i=1}^n (b_i-1)=1.
      $$
      The entries of the output matrix correspond to entries of the input tensor.

    Example
      f=flattenedGenericTensor({3,2,2},QQ);
      S=ring f;
      M=hyperdeterminantMatrix f
      det(M)==hyperdeterminant f
    
   Caveat
     There is bug involving the graded structure of the output. Namely, the code assumes that
     all entries of {\tt f} have degree 1, and gives the wrong graded structure if this is not
     the case. If {\tt ring f} is not graded, then 
     the code gives an error.  
     
   SeeAlso
     hyperdeterminant
///



doc ///
   Key 
    --exteriorPower
    (exteriorPower, ZZ, LabeledModule)
   Headline 
    Exterior power of a @TO LabeledModule@
   Usage 
    E = exteriorPower(i,M)
   Inputs 
    i: ZZ
    M: LabeledModule
   Outputs
    E: LabeledModule
   Consequences
    Item
   Description
    Text
    Example
   SeeAlso
///


doc ///
   Key
     pureResES1
   Headline
     computes the first map of the Eisenbud--Schreyer pure resolution of a given type
   Usage
     pureResES1(d,kk)
   Inputs
     d: List
     kk: Ring
   Outputs
     : LabeledModuleMap
   Description
    Text
      Given a degree sequence $d\in \mathbb Z^{n+1}$ and a field $k$ of arbtirary characteristic, 
      this produces the first map of pure resolution of type d as constructed by
      Eisenbud and Schreyer in Section 5 of ``Betti numbers of graded modules and cohomology 
      of vector bundles''.  The cokernel of this map is a module of finite of length over a
      polynomial ring in $n$ variables.
      
      The code gives an error if d is not strictly increasing with $d_0=0$.
      
    Example
      d={0,2,4,5};
      p=pureResES1(d,ZZ/32003)
      betti res coker p
      dim coker p
   
   SeeAlso
     pureResES
///


doc ///
   Key
     pureResES
   Headline
     constructs the Eisenbud--Schreyer pure resolution of a given type
   Usage
     pureResES(d,kk)
   Inputs
     d: List
     kk: Ring
   Outputs
     : ChainComplex
   Description
    Text
      Given a degree sequence $d$, this function returns the pure resolution of
      type $d$ constructed in by Eisenbud and Schreyer in Section 5 of 
      ``Betti numbers of graded modules and cohomology of vector bundles''.  The
      function operates by resolving the output of {\tt pureResES1(d,kk)}.
      
    Example
      d={0,2,4,5};
      FF=pureResES(d,ZZ/32003)
      betti FF
      
   SeeAlso
     pureResES1
///


doc ///
   Key
     pureResTC1
   Headline
     computes the first map of a balanced tensor complex with pure resolution of a given type
   Usage
     pureResTC1(d,kk)
   Inputs
     d: List
     kk: Ring
   Outputs
     : LabeledModuleMap
   Description
    Text
      Given a degree sequence $d\in \mathbb Z^{n+1}$ and a field $k$ of arbtirary characteristic, 
      this produces the first map of a balanced tensor complex with a 
      pure resolution of type d, as constructed in Section 3
      of the paper ``Tensor Complexes: Multilinear free resolutions constructed from higher tensors
      by Berkesch-Erman-Kummini-Sam.  The cokernel of the output is an indecomposable
      module of codimension $n$.

      The code gives an error if d is not strictly increasing with $d_0=0$.
      
    Example
      d={0,2,4,5};
      p=pureResTC1(d,ZZ/32003)
      betti res coker p
   
   SeeAlso
     pureResTC
///


doc ///
   Key
     pureResTC
   Headline
     constructs the balanced tensor complex of a given type
   Usage
     pureResTC(d,kk)
   Inputs
     d: List
     kk: Ring
   Outputs
     : ChainComplex
   Description
    Text
      Given a degree sequence $d$, this function returns a balanced tensor complex
      that is a  pure resolution of type $d$, as constructed in Section 3
      of the paper ``Tensor Complexes: Multilinear free resolutions constructed from higher tensors
      by Berkesch-Erman-Kummini-Sam.
      The function operates by resolving the output of {\tt pureResTC1(d,kk)}.
      
      The code gives an error if d is not strictly increasing with $d_0=0$.

    Example
      d={0,2,4,5};
      FF=pureResTC(d,ZZ/32003)
      betti FF
      
   SeeAlso
     pureResTC1
///




doc ///
   Key 
    flattenedGenericTensor
    (flattenedGenericTensor, List, Ring)
   Headline 
    Make a generic tensor of given format
   Usage
    flattenedGenericTensor(L,kk)
   Inputs
    L: List
     of positive ZZ
    kk: Ring
     Name of ground field (or ring)
   Outputs
    f: LabeledModuleMap
   Description
    Text
     Given a list $L = \{a, b_1,\dots, b_n\}$ of positive integers 
     with
     $
     a= sum_i b_i,
     $
     and a field (or ring of integers) kk,
     the script creates a polynomial ring $S$ over $kk$ with $a\times b_1\times\cdots\times b_n$ variables,
     and a generic map
     $$
     f: A \to B_1\otimes\cdots \otimes B_n
     $$
     of @TO LabeledModule@s over $S$, where 
     $A$ is a free LabeledModule of rank $a$ and 
     $B_i$ is a free LabeledModule of rank $b_i$.
     We think of $f$ as representing a tensor of type $(a,b_1,\dots,b_n)$
     made from the elementary symmetric functions.
     
     The format of $F$ is the one required
     by @TO tensorComplex1@, namely $f: A \to B_1\otimes \cdots \otimes B_n$, with
     $a = rank A, b_i = rank B_i$.
    Example
     kk = ZZ/101
     f = flattenedGenericTensor({5,2,1,2},kk)
     numgens ring f
     betti matrix f
     S = ring f
     tensorComplex1 f
   SeeAlso
    flattenedESTensor
    tensorComplex1
///
doc ///
   Key 
    flattenedESTensor
   Headline
    make a flattened tensor from elementary symmetric functions
   Usage
    flattenedESTensor(L,kk)
   Inputs
    L: List
     of positive ZZ
    kk: Ring
     Name of ground field (or ring)
   Outputs
    f: LabeledModuleMap
   Description
    Text
     Given a list $L = \{a, b_1,\dots, b_n\}$ of positive integers 
     with
     $
     a= sum_i b_i,
     $
     and a field (or ring of integers) kk,
     the script creates a ring $S = kk[x_1,\dots,x_n]$ and a map
     $$
     f: A \to B_1\otimes\cdots \otimes B_n
     $$
     of @TO LabeledModule@s over $S$, where 
     $A$ is a free LabeledModule of rank $a$ and 
     $B_i$ is a free LabeledModule of rank $b_i$.
     The map $f$ is constructed from symmetric functions, and 
     corresponds to collection of linear forms on $P^{b_1-1}\times\cdots\timesß P^{b_n-1}$
     as used in the construction of 
     pure resolutions in the paper 
     ``Betti numbers of graded modules and cohomology of vector bundles''
     of Eisenbud and Schreyer.
     
     The format of $F$ is the one required
     by @TO tensorComplex1@, namely $f: A \to B_1\otimes \cdots \otimes B_n$, with
     $a = rank A, b_i = rank B_i$.
    Example
     kk = ZZ/101
     f = flattenedESTensor({5,2,1,2},kk)
     numgens ring f
     betti matrix f
     S = ring f
     g = tensorComplex1 f
     betti res coker g
   SeeAlso
    flattenedGenericTensor
    tensorComplex1
///


doc ///
   Key
     LabeledModuleMap
   Headline
     the class of maps between LabeledModules
   Description
    Text
      A map between two labeled modules remembers the labeled module structure of the
     source of target.  
     Some, but not all methods available for maps have been extended to
     this class.  In these cases, one should apply the method to the underlying
     matrix.  See @TO (rank,LabeledModuleMap)@.

///


doc ///
   Key
     (map,LabeledModule,LabeledModule,Function)
   Headline
     create a LabeledModuleMap by specifying a function that gives each entry
   Usage
     map(F,G,f)
   Inputs
     F: LabeledModule
     G: LabeledModule
     f: Function
   Outputs
     : LabeledModuleMap
   Description
    Text
      This function produces essentially the same output as 
      {\tt map(Module,Module,Function)}, except that the output map
      belongs to the class LabeledModuleMap, and thus remembers the labeled
      module structure of the source and target. 
    Example
      S=QQ[x,y,z];
      F=labeledModule(S^3)
      f=map(F,F,(i,j)->(S_i)^j)      
   SeeAlso
      (map,Module,Module,Function)
///


doc ///
   Key
     (map,LabeledModule,LabeledModule,LabeledModuleMap)
   Headline
     creates a new LabeledModuleMap from a given LabeledModuleMap
   Usage
     map(F,G,f)
   Inputs
     F: LabeledModule
     G: LabeledModule
     f: LabeledModuleMap
   Outputs
     : LabeledModuleMap
   Description
    Text
      This function produces has the same output {\tt map(F,G,matrix f)}.
      This function is most useful when the either source/target of $f$ is
      isomorphic to $F/G$ as a module with basis, 
      but not as a labeled module.  
     
    Example
      S=QQ[x,y,z];
      A=labeledModule(S^2)
      F=(A**A)**A
      G=A**(A**A)
      f=map(F,G,id_(F))      
   SeeAlso
      (map,LabeledModule,LabeledModule,Matrix)
      (map,Module,Module,Matrix)
///


doc ///
   Key
     (map,LabeledModule,LabeledModule,Matrix)
   Headline
     creates a LabeledModuleMap from a matrix
   Usage
     map(F,G,M)
   Inputs
     F: LabeledModule
     G: LabeledModule
     M: Matrix
   Outputs
     : LabeledModuleMap
   Description
    Text
      This function produces essentially the same output as 
      {\tt map(Module,Module,Matrix)}, except that the output map
      belongs to the class LabeledModuleMap, and thus remembers the labeled
      module structure of the source and target. 
    Example
      S=QQ[x,y,z];
      F=labeledModule(S^3)
      M=matrix{{1,2,3},{x,y,z},{3*x^2,x*y,z^2}}
      g=map(F,F,M)      
      source g
   SeeAlso
      (map,Module,Module,Matrix)
///




doc ///
   Key
     (map,LabeledModule,LabeledModule,List)
   Headline
     creates a LabeledModuleMap from a list
   Usage
     map(F,G,L)
   Inputs
     F: LabeledModule
     G: LabeledModule
     L: List
   Outputs
     : LabeledModuleMap
   Description
    Text
      This function produces essentially the same output as 
      @TO (map,Module,Module,List)@, except that the output map
      belongs to the class LabeledModuleMap, and thus remembers the labeled
      module structure of the source and target. 
    Example
      S=QQ[x,y,z];
      F=labeledModule(S^3)
      L={{1,2,3},{x,y,z},{3*x^2,x*y,z^2}}
      g=map(F,F,L)      
      source g
   SeeAlso
      (map,Module,Module,List)
///


doc ///
   Key
     (map,LabeledModule,LabeledModule,ZZ)
   Headline
     creates scalar multiplication by an integer as a LabeledModuleMap
   Usage
     map(F,G,m)
   Inputs
     F: LabeledModule
     G: LabeledModule
     m: ZZ
   Outputs
     : LabeledModuleMap
   Description
    Text
      This function produces essentially the same output as 
      @TO (map,Module,Module,ZZ)@, except that the output map
      belongs to the class LabeledModuleMap, and thus remembers the labeled
      module structure of the source and target.  If $m=0$ then the output is
      the zero map.  If $m\ne 0$, then $F$ and $G$ must have the same rank.
    Example
      S=QQ[x,y,z];
      F=labeledModule(S^3);
      G=labeledModule(S^2);
      g=map(F,G,0)      
      h=map(F,F,1)
   SeeAlso
      (map,Module,Module,ZZ)
///



{*
doc ///
   Key
     (coker,LabeledModuleMap)
     (rank,LabeledModuleMap)
     (transpose,LabeledModuleMap)
     (symbol *, LabeledModule,LabeledModule)
     (symbol **, LabeledModule,LabeledModule)
   Headline
     a number of methods for maps have been extended to the class LabeledModuleMap
   Usage
     coker(f)
     rank(f)
     transpose(f)
   Inputs
     f: LabeledModuleMap
   Outputs
     : Thing
   Description
    Text
      A number of methods that apply to maps have been extend the class LabeledModuleMap.
      Where this is the case, the syntax is exactly the same.
    Example
      R=ZZ/101[a,b];
      F=labeledModule(R^3);
      f=map(F,F,(i,j)->a^i+b^j);
      rank f
      coker f
    Text
      Many methods have not been extended.  In these cases, one will see an error message,
      and should apply the method to {\tt matrix f} instead of directly to {\tt f}.
    Example
      R=ZZ/101[a,b];
      F=labeledModule(R^2);
      f=map(F,F,(i,j)->a^i+b^j);
      entries matrix f     
///
*}

doc ///
   Key
     underlyingModules
     (underlyingModules, LabeledModule)     
   Headline
     gives the list of underlying modules of a labeled module
   Usage
     underlyingModules(F)
   Inputs
     F: LabeledModule
   Outputs
    : List
   Description
    Text
      One of the key features of a labeled module is that it comes equipped
      with a list of modules used in its construction.  For instance, if $F$
      is the tensor product of $A$ and $B$, then the underlying modules of
      $F$ would be the set $\{ A,B\}$.  Similarly, if $G=\wedge^2 A$, then
      $A$ is the only underlying module of $G$.
    
    Example
      S=ZZ/101[x,y,z];
      A=labeledModule(S^2);
      B=labeledModule(S^5);
      F=A**B
      underlyingModules(F)
      G=exteriorPower(2,A)
      underlyingModules(G)
///


doc ///
   Key
     basisList
     (basisList, LabeledModule)     
   Headline
     gives the list used to label the basis elements of a labeled module
   Usage
     basisList(F)
   Inputs
     F: LabeledModule
   Outputs
    : List
   Description
    Text
      One of the key features of a labeled module of rank $r$
      is that the basis can be labeled by any list of cardinality $r$.
      This is particularly convenient when working with tensor products, symmetric
      powers, and exterior powers.  For instance, if $A$ is a labeled module with
      basis labeled by $\{0,\dots, r-1\}$ then it is natural to think of
      $\wedge^2 A$ as a labeled module with a basis labeled by elements of the
      lists
      $$
      \{(i,j)| 0\leq i<j\leq r-1\}.
      $$
      When you use apply the functions @TO tensorProduct@, @TO symmetricPower@
      and @TO exteriorPower@ to a labeled module, the output is a labeled
      module with a natural basis list.
          
    Example
      S=ZZ/101[x,y,z];
      A=labeledModule(S^2);
      B=labeledModule(S^4);
      F=A**B
      basisList(F)
      G=exteriorPower(2,B)
      basisList(G)
///

{*
doc ///
   Key
   Headline
   Usage
   Inputs
   Outputs
   Consequences
    Item
   Description
    Text
    Code
    Pre
    Example
   Subnodes
   Caveat
   SeeAlso
///
*}

///
print docTemplate
///
{*beginDocumentation()

undocumented { (net, LabeledModule), (net, LabeledModuleMap) }


document { 
  Key => {underlyingModules, (underlyingModules, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {basisList, (basisList, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {fromOrdinal, (fromOrdinal, ZZ, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {toOrdinal, (toOrdinal, Thing, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (ring, LabeledModule),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (module, LabeledModule),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (rank, LabeledModule),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (symbol ==, LabeledModule, LabeledModule),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (exteriorPower, ZZ, LabeledModule),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {multiSubsets, (multiSubsets, ZZ, ZZ), (multiSubsets, List, ZZ)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (symmetricPower, ZZ, LabeledModule),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {tensorProduct, (tensorProduct, List), (tensorProduct, Sequence)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {(symbol **, LabeledModule, LabeledModule), 
    (tensor,LabeledModule, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {symmetricMultiplication, 
    (symmetricMultiplication, LabeledModule, ZZ, ZZ)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {cauchyMap, (cauchyMap, ZZ, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {traceMap, (traceMap, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {minorsMap, (minorsMap, LabeledModuleMap, LabeledModule), 
    (minorsMap, Matrix, LabeledModule)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {flattenedGenericTensor, 
    (flattenedGenericTensor, List, Ring)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => LabeledModuleMap,
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {(map,LabeledModule,LabeledModule,Matrix),
    (map,LabeledModule,LabeledModule,List),    
    (map,LabeledModule,LabeledModule,Function)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (source, LabeledModuleMap),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (target, LabeledModuleMap),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (matrix, LabeledModuleMap),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (ring, LabeledModuleMap),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (rank, LabeledModuleMap),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (transpose, LabeledModuleMap),
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => {(tensor, LabeledModuleMap, LabeledModuleMap),
    (symbol **, LabeledModuleMap, LabeledModuleMap)},
  Headline => "???",
  "Blah, blah, blah.",
  }

document { 
  Key => (symbol *, LabeledModuleMap, LabeledModuleMap),
  Headline => "???",
  "Blah, blah, blah.",
  }
*}
-------------------------------------------------------------------------------- 
-- TEST
--------------------------------------------------------------------------------

-- test 0
TEST ///
S = ZZ/101[a,b,c];
E = labeledModule S^4
assert(basisList E  == apply(4, i -> i))
assert(underlyingModules E == {})
assert(module E == S^4)
assert(fromOrdinal(2,E) == 2)
assert(toOrdinal(1,E) == 1)
F = labeledModule S
assert(basisList F == {{}})
assert(rank F == 1)
F' = labeledModule S^0
assert(basisList F' == {})
///

-- test 1
TEST ///
S = ZZ/101[a,b,c];
F = labeledModule S^4
E = exteriorPower(2,F)
assert(rank E == 6)
assert(#basisList E == 6)
assert(exteriorPower(0,E) == labeledModule S)
assert(basisList exteriorPower(1,E) == apply(basisList E, i -> {i}))
assert(exteriorPower(-1,E) == labeledModule S^0)
E' = exteriorPower(2,E)
assert(#basisList E' == 15)
assert(#multiSubsets(basisList E,2) == binomial(6+2-1,2))
assert(#multiSubsets({0,1,2},2) == binomial(3+2-1,2))
///

-- test 2
TEST ///
S = ZZ/101[a,b,c];
F = labeledModule S^4
E = symmetricPower(2,F)
assert(#basisList E == binomial(4+2-1,2))
assert(toOrdinal({0,3},E) == 6)
assert(fromOrdinal(7,E) == {1,3})
assert(symmetricPower(0,E) == labeledModule S)
assert(symmetricPower(-1,E) == labeledModule S^0)
assert(basisList symmetricPower(1,E) == apply(basisList E, i -> {i}))
///

-- test 3
TEST ///
S = ZZ/101[a,b,c];
F1 = labeledModule S^2
F2 = labeledModule S^3
F3 = labeledModule S^5
assert(tensor(F1,F2) == F1 ** F2)
E = tensorProduct {F1,F2,F3}
assert(rank E == product {rank F1, rank F2, rank F3})
assert(basisList E == sort basisList E)
assert((underlyingModules E)#0 == F1)
assert((underlyingModules E)#1 == F2)
assert((underlyingModules E)#2 == F3)
F = tensorProduct {labeledModule S^1, F2}
assert(F != F2)
assert((underlyingModules F)#0 == labeledModule S^1)
assert((underlyingModules F)#1 == F2)
assert(toOrdinal({0,1}, F) == 1)
assert(fromOrdinal(5,E) == {0,1,0})
///

-- test 4
TEST ///
S = ZZ/101[a,b,c];
F = labeledModule S^2
assert(matrix symmetricMultiplication(F,1,1) == matrix{
    {1_S,0,0,0},{0,1,1,0},{0,0,0,1}})
assert(rank symmetricMultiplication(F,2,1) == 4)
assert(matrix symmetricMultiplication(F,2,0) == id_(S^3))
///

-- test 5
TEST ///
S = ZZ/101[a,b,c];
F2 = labeledModule S^2;
F3 = labeledModule S^3;
F5 = labeledModule S^5;
F30 = tensorProduct {F2,F3,F5}
assert(rank cauchyMap(2,F30)  == 90)
F2' =  tensorProduct {F2, labeledModule S^1}
assert(matrix cauchyMap(1,F2') == id_(S^2))
///

--test 6
TEST///
kk=ZZ/101;
f=flattenedGenericTensor({4,1,2,1},kk);
BD=new BettiTally from {(0,{0},0) => 2, (1,{1},1) => 4, (2,{3},3) => 4, (3,{4},4) => 2};
assert(betti res coker matrix tensorComplex1 f==BD)
f=flattenedESTensor({4,1,2,1},kk);
assert(betti res coker matrix tensorComplex1 f==BD)
assert(betti pureResTC({0,1,3,4},kk)==BD)
assert(betti pureResES({0,1,3,4},kk)==BD)
f = flattenedGenericTensor({3,3},kk)
assert( (betti res coker tensorComplex1 f) === new BettiTally from {(1,{3},3) => 1, (0,{0},0) => 1} )
f = flattenedGenericTensor({3,2,2},kk)
assert(hyperdeterminant f ==  det matrix tensorComplex1 (f,{0,1,2}))
f = flattenedGenericTensor({3,3},kk)
assert(hyperdeterminant f ==  det matrix tensorComplex1 (f,{0,1}))
assert(hyperdeterminant f ==  det matrix tensorComplex1 (f,{0,0}))
f=flattenedESTensor({3,2,2},kk)
assert(hyperdeterminant f ==  det matrix tensorComplex1 (f,{0,1,2}))

///

--add further tests!! esp of the non balanced case.
--
end
--------------------------------------------------------------------------------
-- SCRATCH SPACE
--------------------------------------------------------------------------------

restart
uninstallPackage "TensorComplexes"
-- path=append(path,"~/IMA-2011/TensorComplexes/")
installPackage "TensorComplexes"
viewHelp TensorComplexes
check "TensorComplexes"

kk=ZZ/101;
f = flattenedGenericTensor({4,2,2,2},kk)
hyperdeterminantMatrix(f)
betti res coker tensorComplex1 (f, {0,0})

betti pureResTC({0,1,3,4,6,7},ZZ/101)
hyperdeterminant  flattenedESTensor({5,3,2,2},ZZ/2) 

kk = ZZ/101;
f=flattenedGenericTensor({7,2,2},kk)
S=ring f;
p1=tensorComplex1(f,{0,1,4});
I=ann coker p1;



f=flattenedESTensor({7,1,2,1,2,1},kk)
betti res coker tensorComplex1 f


f = flattenedGenericTensor({6,2},ZZ/32003)

betti res coker tensorComplex1(f,{0,0})

f = flattenedGenericTensor({3},kk)
betti res coker tensorComplex1 f

g = tensorComplex1 f

betti res coker matrix g
cokermatrix f

restart
uninstallPackage "TensorComplexes"
installPackage "TensorComplexes"
viewHelp "TensorComplexes"
check "TensorComplexes"
