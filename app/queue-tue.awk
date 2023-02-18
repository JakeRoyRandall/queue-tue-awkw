#!/usr/bin/awk -f
# Queue Tue: a grocery queue receipt analyzer for awkward 2020 errands.
function fail(message) { failed=1; print "error: " message > "/dev/stderr"; exit 2 }
function validate_flag(value,name,maximum) { if (value != "" && (value !~ /^[0-9]+$/ || length(value)>10 || (value+0)>maximum)) fail(name " must be a nonnegative integer <= " maximum) }
function print_header() { if (summary_only==1) return; if (status_mode) print "arrival_min\tservice_min\tlane\twait_min\tstart_min\tend_min\tstatus"; else print "arrival_min\tservice_min\tlane\twait_min\tstart_min\tend_min" }
function print_summary_header() {
 header = "summary_lane\tcustomers"
 if (max_wait != "" || close_at != "") header = header "\tleft_customers"
 if (close_at != "") header = header "\tclosed_customers"
 header = header "\ttotal_service_min\tmean_wait_min\tmax_wait_min\tfinish_min"
 if (utilization == 1) header = header "\tbusy_span_min\tidle_min\tutilization_percent"
 print header
}
function print_customer(a,s,l,w,st,e) { if (summary_only==1) return; if (status_mode) printf "%d\t%d\t%s\t%d\t%d\t%d\tserved\n",a,s,l,w,st,e; else printf "%d\t%d\t%s\t%d\t%d\t%d\n",a,s,l,w,st,e }
function print_rejected(a,s,l,w,state) { if (summary_only!=1) printf "%d\t%d\t%s\t%d\t\t\t%s\n",a,s,l,w,state }
function print_summary_row(l,span,idle,percent) {
 if (utilization==1) { span=finish[l]-first_start[l]; idle=span-total_service[l]; percent=span>0 ? (total_service[l]*100)/span : 0 }
 line = l "\t" (customers[l] + 0)
 if (max_wait != "" || close_at != "") line = line "\t" (left[l] + 0)
 if (close_at != "") line = line "\t" (closed[l] + 0)
 mean = customers[l] ? total_wait[l] / customers[l] : 0
 line = line "\t" (total_service[l] + 0) "\t" sprintf("%.2f", mean) "\t" (lane_max_wait[l] + 0) "\t" (finish[l] + 0)
 if (utilization == 1) line = line "\t" (span + 0) "\t" (idle + 0) "\t" sprintf("%.2f", percent)
 print line
}
BEGIN {
 FS="\t"; OFS="\t"
 if (summary!="" && summary!=0 && summary!=1) fail("summary must be 0 or 1")
 if (summary_only!="" && summary_only!=0 && summary_only!=1) fail("summary_only must be 0 or 1")
 if (summary_only==1 && summary!=1) fail("summary_only requires summary=1")
 if (utilization!="" && utilization!=0 && utilization!=1) fail("utilization must be 0 or 1")
 if (utilization==1 && summary!=1) fail("utilization requires summary=1")
 validate_flag(warn_wait,"warn_wait",1000000000); validate_flag(max_wait,"max_wait",1000000000); validate_flag(close_at,"close_at",1000000000); validate_flag(open_at,"open_at",1000000000)
 if (open_at!="" && close_at!="" && (open_at+0)>(close_at+0)) fail("open_at must be <= close_at")
 status_mode=(max_wait!="" || close_at!="")
 if (exclude!="") { excluded_count=split(exclude,excluded_values,","); if (excluded_count>100) fail("at most 100 excluded lanes are supported"); for (i=1;i<=excluded_count;i++) { if (excluded_values[i] !~ /^[A-Za-z0-9_-]{1,32}$/) fail("exclude lanes must be 1-32 letters, digits, _ or -"); excluded[excluded_values[i]]=1 } }
 print_header(); previous=-1
}
{
 if (NF!=3) fail("each record must have exactly 3 tab-separated columns")
 if ($1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ || length($1)>7 || length($2)>7 || ($1+0)>1000000 || ($2+0)>1000000) fail("arrival and service must be integers from 0 to 1000000")
 if ($3 !~ /^[A-Za-z0-9_-]{1,32}$/) fail("lane must be 1-32 letters, digits, _ or -")
 arrival=$1+0; service=$2+0; lane=$3
 if (previous>=0 && arrival<previous) fail("arrival records must be nondecreasing; input order breaks stable tie ordering")
 previous=arrival; input_lanes[lane]=1; if (lane in excluded) next
 ready=arrival; if (open_at!="" && ready<open_at+0) ready=open_at+0
 start=(next_free[lane]>ready ? next_free[lane] : ready); wait=start-arrival; end=start+service
 if (!(lane in seen)) { seen[lane]=1; order[++lane_count]=lane }
 if (max_wait!="" && wait>max_wait+0) { left[lane]++; print_rejected(arrival,service,lane,wait,"left"); next }
 if (close_at!="" && end>close_at+0) { closed[lane]++; print_rejected(arrival,service,lane,wait,"closed"); next }
 if (end>1000000000) fail("lane schedule exceeds 1000000000 minutes")
 next_free[lane]=end; if (!(lane in first_start)) first_start[lane]=start
 customers[lane]++; total_service[lane]+=service; total_wait[lane]+=wait; if (wait>lane_max_wait[lane]) lane_max_wait[lane]=wait; finish[lane]=end
 print_customer(arrival,service,lane,wait,start,end)
 if (warn_wait!="" && wait>warn_wait+0) { print "warning: record " NR " lane " lane " waited " wait " minutes" > "/dev/stderr"; excessive++ }
}
END {
 if (!failed) for (lane in excluded) if (!(lane in input_lanes)) fail("excluded lane was not found in input: " lane)
 if (summary==1 && !failed) { print_summary_header(); for (i=1;i<=lane_count;i++) print_summary_row(order[i]) }
 if (warn_wait!="" && !failed) print "warning_total\t" (excessive+0) > "/dev/stderr"
}
