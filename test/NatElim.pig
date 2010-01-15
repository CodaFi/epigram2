make NatD := con ['arg (Enum ['zero 'suc]) [ (con ['done]) (con ['ind1 con ['done]]) ] ] : Desc ;
make Nat := (Mu NatD) : Set ;
make suc := (\ x -> con ['suc x]) : Nat -> Nat ;
make zero := [] : Nat ;
make one := (suc zero) : Nat ;
make two := (suc one) : Nat ;
make add := ? : Nat -> Nat -> Nat ;
in ;
lambda x ;
lambda y ;
elim elimOp NatD x ;
give con ? ;
give [ ? ? ] ;
give con con ? ;
give y ;
lambda r ;
give con ? ;
lambda xy ;
give con ? ;
give (suc xy) ;
root ;
elab add two two 