# Use this system's <nixpkgs> to fetch a known-good version (release 16.03)
with rec {
  origPkgs = import <nixpkgs> { config = {}; };
  pkgsSrc  = origPkgs.fetchFromGitHub {
    owner  = "NixOS";
    repo   = "nixpkgs";
    rev    = "d231868"; # 16.03 release
    sha256 = "0m2b5ignccc5i5cyydhgcgbyl8bqip4dz32gw0c6761pd4kgw56v";
  };
  stablePkgs = import "${pkgsSrc}" { config = {}; };
};

# Allow dependencies to be overridden, but default to known-good version above
{ bash        ? stablePkgs.bash,
  coq         ? stablePkgs.coq,
  emacsWithPG ? (stablePkgs.emacsWithPackages [
                    stablePkgs.emacs24Packages.proofgeneral ]),
  graphviz    ? stablePkgs.graphviz,
  jre         ? stablePkgs.jre,
  lib         ? stablePkgs.lib,
  makeWrapper ? stablePkgs.makeWrapper,
  runCommand  ? stablePkgs.runCommand,
  stdenv      ? stablePkgs.stdenv,
  writeScript ? stablePkgs.writeScript,
  xdg_utils   ? stablePkgs.xdg_utils }:
with rec {
  pkg      = stdenv.mkDerivation {
    name = "ml4pg";
    src  = ./.;
    buildInputs = [ makeWrapper ];

    ## FIXME: Weka is in Nix
    doCheck = true;
    checkPhase = ''

    '';

    runner = writeScript "ml4pg-runner" ''
      #!/usr/bin/env bash
      [[ -n "$ML4PG_HOME" ]] || ML4PG_HOME="$ml4pg/share/ml4pg"
      export ML4PG_HOME
      emacs -l "$ml4pg/share/ml4pg/ml4pg.el" "$@"
    '';

    installPhase = ''
      mkdir -p "$out/share"
      cp -ra . "$out/share/ml4pg"
      mkdir -p "$out/bin"

      # Wrap Emacs with all of the required dependencies
      makeWrapper "${emacsWithPG}/bin/emacs" "$out/bin/emacs" \
        --prefix PATH : "${bash}/bin"                         \
        --prefix PATH : "${coq}/bin"                          \
        --prefix PATH : "${emacsWithPG}/bin"                  \
        --prefix PATH : "${graphviz}/bin"                     \
        --prefix PATH : "${jre}/bin"                          \
        --prefix PATH : "${xdg_utils}/bin"

      # Wrap our runner script with our wrapped commands
      makeWrapper "$runner" "$out/bin/ml4pg" \
        --prefix PATH : "$out/bin" \
        --set ml4pg "$out"
    '';

    shellHook = ''
      export ML4PG_HOME="$PWD/"
    '';
  };

  test = runCommand "ml4pg-test"
    {
      ML4PG_HOME  = ./.;
      buildInputs = [ pkg ];
    }
    ''
      "$ML4PG_HOME/test/runner.sh"
    '';
};

lib.overrideDerivation pkg (old: {
  extraDeps = [ test ];
})
