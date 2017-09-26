#!/usr/bin/env bash
set -e
set -o pipefail

# Wrapper script to run ML4PG's test suite

# Duplicate stdout, so we can capture to a variable whilst outputting
exec 5>&1

[[ -n "$TESTS"      ]] || TESTS="coq ssreflect"
[[ -n "$ML4PG_HOME" ]] || ML4PG_HOME="$PWD"
[[ -n "$ML4PG_TEST" ]] || ML4PG_TEST=$(dirname "$(readlink -f "$0")")

export ML4PG_HOME
export ML4PG_TEST

cd "$ML4PG_HOME" || {
    echo "Couldn't cd to '$ML4PG_HOME'" 1>&2
    exit 1
}

PATTERN='^ *passed\|FAILED *[[:digit:]]*/[[:digit:]]* *'

function filterOut {
    # Keep only pass/fail lines
    grep "$PATTERN"
}

function filterErr {
    # Keep everything except pass/fail lines
    grep -v "$PATTERN"
}

function split {
    # Duplicate stdin to stdout and stderr, then filter each
    tee >(filterErr 1>&2) | filterOut
}

function run {
    # Merge stdout and stderr and send to split
    emacs --quick --debug-init --script "$ML4PG_TEST/runner.el" 2>&1 | split
}

ERR=0
for TEST_SUITE in $TESTS
do
    export TEST_SUITE
    echo "Running $TEST_SUITE tests" 1>&2

    # Capture results, as well as sending to stdout
    RESULTS=$(run | tee >(cat >&5))

    # Look for failing tests
    if echo "$RESULTS" | grep 'FAILED' > /dev/null
    then
        ERR=1
    fi
done

# Exit code indicates if all tests passed (0) or not (1)
exit "$ERR"
