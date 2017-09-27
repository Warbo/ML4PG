with builtins;
with rec {
  # A known-good revision of nixpkgs is defined in default.nix, so use it here
  stable = import ./. { packageOnly = false; };
  pkgs   = stable.stablePkgs;

  # Greps through Emacs Lisp files in ./test to find the names of every test
  # (ugly, but lets us make per-test derivations without having to first build
  # Emacs, ML4PG, etc. or run the test suites at eval time).
  testNames = with pkgs; import (runCommand "testNames.nix" { dir = ./test; } ''
    set -e
    {
      # Write out an attribute set '{...}' to $out
      echo '{'
        # Each directory in $dir is a 'test suite'
        for S in "$dir"/*
        do
          [[ -d "$S" ]] || continue
          suite=$(basename "$S")

          # Write an attribute named $suite, with a list of names as its value
          echo "\"$suite\" = ["
            # Look for tests, use '|| true' to avoid errors when not found

            # Prefix name with 'ml4pg-' and wrap in double quotes
            { grep -hr '^(test-with'   "$dir/$suite" || true; } |
              awk '{print "\"ml4pg-"$2"\""}'

            # Wrap name in double quotes (these are already prefixed)
            { grep -hr '^(ert-deftest' "$dir/$suite" || true; } |
              awk '{print "\""$2"\""}'
          echo '];'
        done
      echo '}'
    } > "$out"
  '');

  # Individual test results. The tests are run in batches ('suites'), so these
  # pick out their result from the relevant suite's output.
  getTests = with pkgs; with lib; suite: output:
    genAttrs (getAttr suite testNames) (name:
      runCommand "test-result-${suite}-${name}"
        {
          inherit name output;
          allNames = writeScript "test-names"
            (concatStringsSep "\n" (getAttr suite testNames));
        }
        ''
          set -e
          function all { sort < "$allNames"; }
          function got { awk '{print $3}' < "$output/stdout" | sort; }

          echo "Checking test results match expected names" 1>&2
          cmp --silent <(all) <(got) || {
            echo "Name mismatch between '$allNames' and '$output/stdout'" 1>&2
            diff <(all) <(got)
            exit 1
          }

          echo "Looking up test result for '$name'" 1>&2
          PASS=$(awk -v n="$name" '$3 == n {print $1}' < "$output/stdout")

          [[ "x$PASS" = "xpassed" ]] || {
            cat "$output/stderr" 1>&2
            exit 1
          }

          echo pass > "$out"
        '');

  # Sanity check that the suites we run match those in testNames
  suitesMatch = outputs:
    sort lessThan (attrNames outputs) == sort lessThan (attrNames testNames) ||
    abort (toJSON {
      error = "Test suite mismatch";
      found = attrNames testNames;
      toRun = attrNames outputs;
    });

  # Adds individual test derivations to an ML4PG package set
  withTests = with pkgs.lib; mapAttrs (_: set: {
    inherit (set) ml4pg ml4pgUntested;
    tests = assert suitesMatch set.testOutputs;
            mapAttrs getTests set.testOutputs;
  });
};

withTests {
  # Uses the defaults defined in ./default.nix
  inherit stable;

  # Uses whatever we find in <nixpkgs>
  unstable = with import <nixpkgs> {}; callPackage ./. {
    emacsWithPG = emacsWithPackages [ emacsPackages.proofgeneral ];
    packageOnly = false;
  };
}
