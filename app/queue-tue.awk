#!/usr/bin/awk -f
# Queue Tue: a grocery queue receipt analyzer for awkward 2020 errands.
BEGIN { FS = "\t"; OFS = "\t"; if (summary != "" && summary != 0 && summary != 1) fail("summary must be 0 or 1"); if (summary_only != "" && summary_only != 0 && summary_only != 1) fail("summary_only must be 0 or 1"); if (summary_only == 1 && summary != 1) fail("summary_only requires summary=1"); if (utilization != "" && utilization != 0 && utilization != 1) fail("utilization must be 0 or 1"); if (utilization == 1 && summary != 1) fail("utilization requires summary=1"); if (warn_wait != "" && (warn_wait !~ /^[0-9]+$/ || length(warn_wait) > 10 || (warn_wait + 0) > 1000000000)) fail("warn_wait must be a nonnegative integer <= 1000000000"); if (max_wait != "" && (max_wait !~ /^[0-9]+$/ || length(max_wait) > 10 || (max_wait + 0) > 1000000000)) fail("max_wait must be a nonnegative integer <= 1000000000"); if (close_at != "" && (close_at !~ /^[0-9]+$/ || length(close_at) > 10 || (close_at + 0) > 1000000000)) fail("close_at must be a nonnegative integer <= 1000000000"); status_mode = (max_wait != "" || close_at != ""); if (exclude != "") { excluded_count = split(exclude, excluded_values, ","); if (excluded_count > 100) fail("at most 100 excluded lanes are supported"); for (i = 1; i <= excluded_count; i++) { if (excluded_values[i] !~ /^[A-Za-z0-9_-]{1,32}$/) fail("exclude lanes must be 1-32 letters, digits, _ or -"); excluded[excluded_values[i]] = 1 } } if (summary_only != 1) { if (status_mode) print "arrival_min\tservice_min\tlane\twait_min\tstart_min\tend_min\tstatus"; else print "arrival_min\tservice_min\tlane\twait_min\tstart_min\tend_min" } previous = -1 }
function fail(message) { failed = 1; print "error: " message > "/dev/stderr"; exit 2 }
{
    if (NF != 3) fail("each record must have exactly 3 tab-separated columns")
    if ($1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ || length($1) > 7 || length($2) > 7 || ($1 + 0) > 1000000 || ($2 + 0) > 1000000) fail("arrival and service must be integers from 0 to 1000000")
    if ($3 !~ /^[A-Za-z0-9_-]{1,32}$/) fail("lane must be 1-32 letters, digits, _ or -")
    arrival = $1 + 0; service = $2 + 0; lane = $3
    if (previous >= 0 && arrival < previous) fail("arrival records must be nondecreasing; input order breaks stable tie ordering")
    previous = arrival; input_lanes[lane] = 1
    if (lane in excluded) next
    start = (next_free[lane] > arrival ? next_free[lane] : arrival)
    wait = start - arrival; end = start + service
    if (!(lane in seen)) { seen[lane] = 1; order[++lane_count] = lane }
    if (max_wait != "" && wait > max_wait + 0) { left[lane]++; if (summary_only != 1) printf "%d\t%d\t%s\t%d\t\t\tleft\n", arrival, service, lane, wait; next }
    if (close_at != "" && end > close_at + 0) { closed[lane]++; if (summary_only != 1) printf "%d\t%d\t%s\t%d\t\t\tclosed\n", arrival, service, lane, wait; next }
    if (end > 1000000000) fail("lane schedule exceeds 1000000000 minutes")
    next_free[lane] = end
    if (!(lane in first_start)) first_start[lane] = start
    customers[lane]++; total_service[lane] += service; total_wait[lane] += wait; if (wait > lane_max_wait[lane]) lane_max_wait[lane] = wait; finish[lane] = end
    if (summary_only != 1) { if (status_mode) printf "%d\t%d\t%s\t%d\t%d\t%d\tserved\n", arrival, service, lane, wait, start, end; else printf "%d\t%d\t%s\t%d\t%d\t%d\n", arrival, service, lane, wait, start, end }
    if (warn_wait != "" && wait > warn_wait + 0) { print "warning: record " NR " lane " lane " waited " wait " minutes" > "/dev/stderr"; excessive++ }
}
END {
    if (!failed) for (lane in excluded) if (!(lane in input_lanes)) fail("excluded lane was not found in input: " lane)
    if (summary == 1 && !failed) {
        if (close_at != "") { if (utilization == 1) print "summary_lane\tcustomers\tleft_customers\tclosed_customers\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min\tbusy_span_min\tidle_min\tutilization_percent"; else print "summary_lane\tcustomers\tleft_customers\tclosed_customers\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min" }
        else if (max_wait != "") { if (utilization == 1) print "summary_lane\tcustomers\tleft_customers\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min\tbusy_span_min\tidle_min\tutilization_percent"; else print "summary_lane\tcustomers\tleft_customers\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min" }
        else { if (utilization == 1) print "summary_lane\tcustomers\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min\tbusy_span_min\tidle_min\tutilization_percent"; else print "summary_lane\tcustomers\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min" }
        for (i = 1; i <= lane_count; i++) { lane = order[i]; if (utilization == 1) { span = finish[lane] - first_start[lane]; idle = span - total_service[lane]; percent = span > 0 ? (total_service[lane] * 100) / span : 0 } if (close_at != "") { if (utilization == 1) printf "%s\t%d\t%d\t%d\t%d\t%.2f\t%d\t%d\t%d\t%d\t%.2f\n", lane, customers[lane], left[lane] + 0, closed[lane] + 0, total_service[lane], customers[lane] ? total_wait[lane] / customers[lane] : 0, lane_max_wait[lane], finish[lane] + 0, span, idle, percent; else printf "%s\t%d\t%d\t%d\t%d\t%.2f\t%d\t%d\n", lane, customers[lane], left[lane] + 0, closed[lane] + 0, total_service[lane], customers[lane] ? total_wait[lane] / customers[lane] : 0, lane_max_wait[lane], finish[lane] + 0 } else if (max_wait != "") { if (utilization == 1) printf "%s\t%d\t%d\t%d\t%.2f\t%d\t%d\t%d\t%d\t%.2f\n", lane, customers[lane], left[lane] + 0, total_service[lane], customers[lane] ? total_wait[lane] / customers[lane] : 0, lane_max_wait[lane], finish[lane] + 0, span, idle, percent; else printf "%s\t%d\t%d\t%d\t%.2f\t%d\t%d\n", lane, customers[lane], left[lane] + 0, total_service[lane], customers[lane] ? total_wait[lane] / customers[lane] : 0, lane_max_wait[lane], finish[lane] + 0 } else { if (utilization == 1) printf "%s\t%d\t%d\t%.2f\t%d\t%d\t%d\t%d\t%.2f\n", lane, customers[lane], total_service[lane], total_wait[lane] / customers[lane], lane_max_wait[lane], finish[lane], span, idle, percent; else printf "%s\t%d\t%d\t%.2f\t%d\t%d\n", lane, customers[lane], total_service[lane], total_wait[lane] / customers[lane], lane_max_wait[lane], finish[lane] } }
    }
    if (warn_wait != "" && !failed) print "warning_total\t" (excessive + 0) > "/dev/stderr"
}
