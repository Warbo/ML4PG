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
  xdg_utils   ? stablePkgs.xdg_utils,

  # This option lets us return the inner implementation details, if desired
  packageOnly ? true }:

  with lib;
with rec {
  # The real content of ML4PG comes from the 'ml4pgUntested' package, but (as
  # its name suggests) that hasn't been checked. Hence we add the 'testResults'
  # packages as dependencies, which will cause the test suites to run and fail
  # the build if any test fails.
  ml4pg = overrideDerivation ml4pgUntested (old: {
    extraDeps = attrValues testResults;
  });

  # This provides an 'ml4pg' command, with all of its dependencies, etc. It only
  # depends on ./src, so we're free to play around with the README, packaging,
  # test suite, etc. without triggering a rebuild.
  ml4pgUntested = stdenv.mkDerivation {
    name        = "ml4pg";
    src         = ./src;
    buildInputs = [ makeWrapper ];
    ## FIXME: Weka is in Nix

    # The ML4PG command
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

    # Convenience script for setting ML4PG_HOME, etc. vars for nix-shell
    shellHook = ''
      export ML4PG_HOME="$PWD/"
    '';
  };

  # The raw output of the test suites
  testOutputs = genAttrs [ "coq" "ssreflect" ]
    (suite: runCommand "ml4pg-test-${suite}"
      {
        src         = ./src;
        test        = ./test;
        buildInputs = [ ml4pgUntested ];
        TESTS       = suite;
      }
      ''
        set -e

        echo "Making mutable copy of ML4PG_HOME" 1>&2
        export ML4PG_HOME="$PWD/src"
        cp -r "$src" "$ML4PG_HOME"
        chmod +w -R "$ML4PG_HOME"

        echo "Running tests" 1>&2
        cd "$ML4PG_HOME"

        mkdir "$out"

        # Even if the test suite fails, this derivation should still build
        if "$test/runner.sh" > "$out/stdout"
        then
          echo "true"  > "$out/pass"
        else
          echo "false" > "$out/pass"
        fi
      '');

  # Checkers for the test suite output: fail to build if any test failed.
  testResults = mapAttrs
    (suite: output: runCommand "ml4pg-check-${suite}" { inherit output; } ''
      set -e
      PASSED=$(cat "$output/pass")
      [[ "x$PASSED" = "xtrue" ]] || {
        echo "PASSED: $PASSED" 1>&2
        exit 1
      fi

      echo "$PASSED" > "$out"
    '')
    testOutputs;

  # Useful debug stuff follows, unused by the actual package

  tests = mapAttrs
    (suite: output: import (runCommand "ml4pg-${suite}-tests.nix"
      { inherit output; }
      ''
        set -e

        {
          echo 'with import <nixpkgs> {}; {'
            sed -e 's/  */ /g' < "$output/stdout" | while read -r LINE
            do
              if echo "$LINE" | cut -d ' ' -f1 | grep 'passed' > /dev/null
              then
                CODE=0
              else
                CODE=1
              fi

              N=$(echo "$LINE" | cut -d ' ' -f3)

              echo "$N = runCommand \"$N\" {} \"mkdir \$out; exit $CODE\";"
            done
          echo '}'
        } > "$out"
      ''))
    testOutputs;
};

if packageOnly
   then ml4pg
   else {
     # Allow access to our internals, for debugging, etc.
     inherit ml4pg ml4pgUntested tests;
   }
