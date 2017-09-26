{
  stable   = import ./. { packageOnly = false; };
  unstable = with import <nixpkgs> {};
             callPackage ./. {
               emacsWithPG = emacsWithPackages [
                               emacsPackages.proofgeneral ];
               packageOnly = false;
             };
}
