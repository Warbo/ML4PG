#!/usr/bin/env bash
set -e
set -o pipefail

[[ -n "$TESTS"      ]] || TESTS="coq ssreflect"
[[ -n "$ML4PG_HOME" ]] || ML4PG_HOME="$PWD"

cd "$ML4PG_HOME" || {
    echo "Couldn't cd to '$ML4PG_HOME'" 1>&2
    exit 1
}

for TEST_SUITE in $TESTS
do
    export TEST_SUITE
    echo "Running $TEST_SUITE tests" 1>&2
    OUTPUT=$(emacs --quick --debug-init --script ./test/runner.el 2>&1 |
             grep -v "^Loading.*\.\.\.$" > >(tee >(cat 1>&2)))
    if echo "$OUTPUT" | grep 'FAILED' > /dev/null
    then
        echo "Detected 'FAILED' in output, assuming test failure" 1>&2
        exit 1
    fi
done

exit 0
