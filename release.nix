{
  stable   = import ./. {};
  unstable = import ./. { pkgs = import <nixpkgs> {}; };
}
