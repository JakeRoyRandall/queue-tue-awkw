#!/bin/sh
set -eu
awk_bin=/usr/bin/awk
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$here/queue-tue.awk"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/queue-tue.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
printf '0\t5\tA\n1\t2\tA\n2\t3\tB\n4\t1\tA\n' >"$tmp/in.tsv"
"$awk_bin" -f "$script" "$tmp/in.tsv" >"$tmp/out.tsv"
test "$(sed -n '2p' "$tmp/out.tsv")" = '0	5	A	0	0	5'
test "$(sed -n '3p' "$tmp/out.tsv")" = '1	2	A	4	5	7'
test "$(sed -n '4p' "$tmp/out.tsv")" = '2	3	B	0	2	5'
test "$(sed -n '5p' "$tmp/out.tsv")" = '4	1	A	3	7	8'
if printf '0\t1\tA\n-1\t2\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '3\t1\tA\n2\t2\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf 'x\t1\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\t   \n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '1000001\t1\tA\n' | "$awk_bin" -f "$script" >/dev/null 2>&1; then exit 1; fi
same=$(printf '0\t2\tA\n0\t3\tA\n' | "$awk_bin" -f "$script")
test "$(printf '%s\n' "$same" | sed -n '2p')" = '0	2	A	0	0	2'
test "$(printf '%s\n' "$same" | sed -n '3p')" = '0	3	A	2	2	5'
excluded=$(printf '0\t5\tA\n1\t2\tA\n2\t3\tB\n' | "$awk_bin" -v exclude=A -f "$script"); test "$(printf '%s\n' "$excluded" | wc -l | tr -d ' ')" -eq 2; test "$(printf '%s\n' "$excluded" | sed -n '2p')" = '2	3	B	0	2	5'
excluded_twice=$(printf '0\t5\tA\n1\t2\tA\n2\t3\tB\n' | "$awk_bin" -v exclude=A,A -f "$script"); test "$excluded" = "$excluded_twice"
if printf '0\t1\tA\n' | "$awk_bin" -v exclude=missing -f "$script" >/dev/null 2>&1; then exit 1; fi
summary=$(printf '0\t5\tA\n1\t2\tA\n2\t3\tB\n' | "$awk_bin" -v summary=1 -f "$script")
printf '%s\n' "$summary" | grep -q 'A	2	7	2.00	4	7'
printf '%s\n' "$summary" | grep -q 'B	1	3	0.00	0	5'
test "$(printf '' | "$awk_bin" -v summary=1 -f "$script" | tail -n 1)" = 'summary_lane	customers	total_service_min	mean_wait_min	max_wait_min	finish_min'
if printf '0\t1\tA\n' | "$awk_bin" -v summary=wat -f "$script" 2>/dev/null | grep -q summary_lane; then exit 1; fi
default=$(printf '0\t1\tA\n' | "$awk_bin" -f "$script")
test "$(printf '%s\n' "$default" | wc -l | tr -d ' ')" -eq 2
printf '0\t5\tA\n1\t2\tA\n' | "$awk_bin" -v warn_wait=4 -f "$script" >"$tmp/warn.out" 2>"$tmp/warn.err"
test "$(wc -l <"$tmp/warn.out" | tr -d ' ')" -eq 3
if grep -q warning: "$tmp/warn.err"; then exit 1; fi
grep -q 'warning_total	0' "$tmp/warn.err"
printf '0\t5\tA\n1\t2\tA\n' | "$awk_bin" -v warn_wait=3 -f "$script" >"$tmp/warn2.out" 2>"$tmp/warn2.err"
grep -q 'warning: record 2 lane A waited 4 minutes' "$tmp/warn2.err"
grep -q 'warning_total	1' "$tmp/warn2.err"
if printf '0\t1\tA\n' | "$awk_bin" -v warn_wait=-1 -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\tA\n' | "$awk_bin" -v warn_wait=wat -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\tA\n-1\t1\tA\n' | "$awk_bin" -v warn_wait=0 -f "$script" >"$tmp/bad.out" 2>"$tmp/bad.err"; then exit 1; fi
if grep -q warning_total "$tmp/bad.err"; then exit 1; fi
limited=$(printf '0\t5\tA\n1\t2\tA\n5\t1\tA\n' | "$awk_bin" -v max_wait=3 -f "$script")
test "$(printf '%s\n' "$limited" | sed -n '1p')" = 'arrival_min	service_min	lane	wait_min	start_min	end_min	status'
test "$(printf '%s\n' "$limited" | sed -n '2p')" = '0	5	A	0	0	5	served'
test "$(printf '%s\n' "$limited" | sed -n '3p')" = '1	2	A	4			left'
test "$(printf '%s\n' "$limited" | sed -n '4p')" = '5	1	A	0	5	6	served'
threshold=$(printf '0\t2\tA\n1\t1\tA\n' | "$awk_bin" -v max_wait=1 -f "$script")
test "$(printf '%s\n' "$threshold" | sed -n '3p')" = '1	1	A	1	2	3	served'
zero=$(printf '0\t2\tA\n1\t1\tA\n' | "$awk_bin" -v max_wait=0 -f "$script" -v summary=1)
printf '%s\n' "$zero" | grep -q '1	1	A	1			left'
printf '%s\n' "$zero" | grep -q 'A	1	1	2	0.00	0	2'
if printf '0\t1\tA\n' | "$awk_bin" -v max_wait=-1 -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\tA\n' | "$awk_bin" -v max_wait=wat -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\tA\n' | "$awk_bin" -v max_wait=1000000001 -f "$script" >/dev/null 2>&1; then exit 1; fi
near_limit=$({ i=1; while test "$i" -le 1000; do printf '0\t1000000\tA\n'; i=$((i + 1)); done; printf '0\t1000000\tA\n'; } | "$awk_bin" -v max_wait=999000000 -f "$script")
test "$(printf '%s\n' "$near_limit" | tail -n 1)" = '0	1000000	A	1000000000			left'
test "$(printf '%s\n' "$near_limit" | wc -l | tr -d ' ')" -eq 1002
util=$(printf '0\t2\tA\n0\t0\tB\n5\t1\tA\n' | "$awk_bin" -v summary=1 -v utilization=1 -f "$script")
printf '%s\n' "$util" | grep -q 'summary_lane	customers	total_service_min	mean_wait_min	max_wait_min	finish_min	busy_span_min	idle_min	utilization_percent'
printf '%s\n' "$util" | grep -q 'A	2	3	0.00	0	6	6	3	50.00'
printf '%s\n' "$util" | grep -q 'B	1	0	0.00	0	0	0	0	0.00'
left_util=$(printf '0\t5\tA\n1\t1\tA\n5\t1\tA\n' | "$awk_bin" -v summary=1 -v utilization=1 -v max_wait=3 -f "$script")
printf '%s\n' "$left_util" | grep -q 'A	2	1	6	0.00	0	6	6	0	100.00'
if printf '0\t1\tA\n' | "$awk_bin" -v utilization=1 -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\tA\n' | "$awk_bin" -v summary=1 -v utilization=wat -f "$script" >/dev/null 2>&1; then exit 1; fi
full_summary=$(printf '0\t2\tA\n1\t1\tA\n2\t3\tB\n' | "$awk_bin" -v summary=1 -v max_wait=0 -v utilization=1 -f "$script")
only_summary=$(printf '0\t2\tA\n1\t1\tA\n2\t3\tB\n' | "$awk_bin" -v summary=1 -v summary_only=1 -v max_wait=0 -v utilization=1 -f "$script")
test "$only_summary" = "$(printf '%s\n' "$full_summary" | tail -n 3)"
if printf '0\t1\tA\n' | "$awk_bin" -v summary_only=1 -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\tA\n' | "$awk_bin" -v summary=1 -v summary_only=wat -f "$script" >/dev/null 2>&1; then exit 1; fi
closing=$(printf '0\t2\tA\n2\t1\tA\n' | "$awk_bin" -v close_at=2 -f "$script")
test "$(printf '%s\n' "$closing" | sed -n '1p')" = 'arrival_min	service_min	lane	wait_min	start_min	end_min	status'
test "$(printf '%s\n' "$closing" | sed -n '2p')" = '0	2	A	0	0	2	served'
test "$(printf '%s\n' "$closing" | sed -n '3p')" = '2	1	A	0			closed'
after_close=$(printf '0\t3\tA\n1\t1\tA\n2\t1\tA\n3\t1\tA\n' | "$awk_bin" -v close_at=2 -f "$script")
test "$(printf '%s\n' "$after_close" | sed -n '3p')" = '1	1	A	0	1	2	served'
test "$(printf '%s\n' "$after_close" | sed -n '5p')" = '3	1	A	0			closed'
close_summary=$(printf '0\t3\tA\n1\t1\tA\n3\t1\tA\n' | "$awk_bin" -v summary=1 -v close_at=2 -f "$script")
printf '%s\n' "$close_summary" | grep -q 'A	1	0	2	1	0.00	0	2'
if printf '0\t1\tA\n' | "$awk_bin" -v close_at=-1 -f "$script" >/dev/null 2>&1; then exit 1; fi
if printf '0\t1\tA\n' | "$awk_bin" -v close_at=wat -f "$script" >/dev/null 2>&1; then exit 1; fi
echo 'queue-tue CLI tests: deterministic scheduling and 4 invalid-input checks passed'
