#!/usr/bin/awk -f
# Queue Tue: a grocery queue receipt analyzer for awkward 2020 errands.
BEGIN { FS = "\t"; OFS = "\t"; if (summary != "" && summary != 0 && summary != 1) fail("summary must be 0 or 1"); if (warn_wait != "" && (warn_wait !~ /^[0-9]+$/ || length(warn_wait) > 10 || (warn_wait + 0) > 1000000000)) fail("warn_wait must be a nonnegative integer <= 1000000000"); print "arrival_min\tservice_min\tlane\twait_min\tstart_min\tend_min"; previous = -1 }
function fail(message) { failed = 1; print "error: " message > "/dev/stderr"; exit 2 }
{
    if (NF != 3) fail("each record must have exactly 3 tab-separated columns")
    if ($1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ || length($1) > 7 || length($2) > 7 || ($1 + 0) > 1000000 || ($2 + 0) > 1000000) fail("arrival and service must be integers from 0 to 1000000")
    if ($3 !~ /^[A-Za-z0-9_-]{1,32}$/) fail("lane must be 1-32 letters, digits, _ or -")
    arrival = $1 + 0; service = $2 + 0; lane = $3
    if (previous >= 0 && arrival < previous) fail("arrival records must be nondecreasing; input order breaks stable tie ordering")
    previous = arrival
    start = (next_free[lane] > arrival ? next_free[lane] : arrival)
    wait = start - arrival; end = start + service; if (end > 1000000000) fail("lane schedule exceeds 1000000000 minutes"); next_free[lane] = end
    if (!(lane in seen)) { seen[lane] = 1; order[++lane_count] = lane }
    customers[lane]++; total_service[lane] += service; total_wait[lane] += wait; if (wait > max_wait[lane]) max_wait[lane] = wait; finish[lane] = end
    printf "%d\t%d\t%s\t%d\t%d\t%d\n", arrival, service, lane, wait, start, end
    if (warn_wait != "" && wait > warn_wait + 0) { print "warning: record " NR " lane " lane " waited " wait " minutes" > "/dev/stderr"; excessive++ }
}
END {
    if (summary == 1 && !failed) {
        print "summary_lane\tcustomers\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min"
        for (i = 1; i <= lane_count; i++) { lane = order[i]; printf "%s\t%d\t%d\t%.2f\t%d\t%d\n", lane, customers[lane], total_service[lane], total_wait[lane] / customers[lane], max_wait[lane], finish[lane] }
    }
    if (warn_wait != "" && !failed) print "warning_total\t" (excessive + 0) > "/dev/stderr"
}
