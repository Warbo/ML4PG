{
  stable   = import ./. {};
  unstable = with import <nixpkgs> {};
             callPackage ./. { emacsWithPG = emacsWithPackages [
                                 emacsPackages.proofgeneral ]; };
}
