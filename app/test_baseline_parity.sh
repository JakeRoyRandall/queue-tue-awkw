#!/bin/sh
set -eu
awk_bin=${AWK_BIN:-/usr/bin/awk}
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
active=$here/queue-tue.awk
if test "$#" -ne 1; then
    echo "usage: $0 BASELINE_AWK" >&2
    exit 2
fi
baseline=$1
test -r "$baseline"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/queue-tue-parity.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
input=$tmp/input.tsv
printf '0\t5\tA\n1\t2\tA\n2\t3\tB\n4\t1\tA\n' >"$input"
for options in \
    "" "-v summary=1" "-v warn_wait=3" "-v exclude=A" \
    "-v max_wait=3" "-v summary=1 -v max_wait=3" \
    "-v summary=1 -v utilization=1" \
    "-v summary=1 -v summary_only=1 -v max_wait=3 -v utilization=1" \
    "-v close_at=6" "-v open_at=3"; do
    # shellcheck disable=SC2086
    "$awk_bin" $options -f "$active" "$input" >"$tmp/active.out" 2>"$tmp/active.err" || active_status=$?
    active_status=${active_status:-0}
    # shellcheck disable=SC2086
    "$awk_bin" $options -f "$baseline" "$input" >"$tmp/base.out" 2>"$tmp/base.err" || base_status=$?
    base_status=${base_status:-0}
    test "$active_status" -eq "$base_status"
    cmp "$tmp/active.out" "$tmp/base.out"
    cmp "$tmp/active.err" "$tmp/base.err"
    unset active_status base_status
done
printf '0\t2\tA\n1\t1\tA\n' >"$tmp/invalid.tsv"
printf '0\t2\tA\n1\t1\n' >"$tmp/malformed.tsv"
printf '0\t3\tA\n1\t1\tA\n2\t1\tA\n' >"$tmp/all-closed.tsv"
{ i=1; while test "$i" -le 1000; do printf '0\t1000000\tA\n'; i=$((i + 1)); done; printf '0\t1000000\tA\n'; } >"$tmp/near-limit.tsv"
for options_file in \
    "-v max_wait=wat $tmp/invalid.tsv" \
    "-v max_wait=3 $tmp/malformed.tsv" \
    "-v summary=1 -v close_at=2 $tmp/all-closed.tsv" \
    "-v max_wait=999000000 $tmp/near-limit.tsv"; do
    options=${options_file% *}; input_file=${options_file##* }
    # shellcheck disable=SC2086
    "$awk_bin" $options -f "$active" "$input_file" >"$tmp/active.out" 2>"$tmp/active.err" || active_status=$?
    active_status=${active_status:-0}
    # shellcheck disable=SC2086
    "$awk_bin" $options -f "$baseline" "$input_file" >"$tmp/base.out" 2>"$tmp/base.err" || base_status=$?
    base_status=${base_status:-0}
    test "$active_status" -eq "$base_status"
    cmp "$tmp/active.out" "$tmp/base.out"
    cmp "$tmp/active.err" "$tmp/base.err"
    unset active_status base_status
done
echo 'queue-tue baseline parity: legacy option combinations match'
