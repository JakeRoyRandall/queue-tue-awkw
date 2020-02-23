# Queue Tue: a grocery queue receipt analyzer

`app/queue-tue.awk` reads local tab-separated grocery queue records with exactly three columns: `arrival minute`, `service minutes`, and `lane`. It prints a receipt with wait, start, and end minutes. Each lane is scheduled independently; records are processed in input order, so arrivals must be nondecreasing and equal-minute records keep their stated order.

Created September 2026 as retrospective author artwork for the calendar garden, not historical work from 2020. The grocery queue joke is original to this exercise.

```sh
/usr/bin/awk -f app/queue-tue.awk <<'EOF'
0	5	A
1	2	A
2	3	B
4	1	A
EOF
sh app/test_queue_tue.sh
```

Pass `-v summary=1` for a second receipt section with per-lane customer count, total service, mean wait to two decimals, maximum wait, and finish minute. Other summary values are rejected; the default output is unchanged.

Pass `-v warn_wait=N` to emit stderr warnings for waits strictly greater than the nonnegative threshold `N` (up to 1,000,000,000), including source record number and lane, followed by a warning total. Equal waits do not warn; omitting the option emits no warnings or total. Invalid input suppresses the final total.

Pass `-v exclude=LANE[,LANE...]` to omit one or more existing lanes before scheduling. Exclusions are deduplicated, bounded to 100 lanes, and validated against the input; excluded records do not advance any lane clock or appear in summaries.

Pass `-v max_wait=N` to mark customers whose wait would be strictly greater than the nonnegative threshold `N` (up to 1,000,000,000) as `left`. A left customer has blank start/end fields and does not occupy the lane, so later customers are scheduled from the unchanged lane clock. This mode adds a `status` column and, with `summary=1`, a `left_customers` column; wait warnings apply only to served customers. The default output remains unchanged when `max_wait` is omitted.

Pass `-v utilization=1` together with `-v summary=1` for three additional per-lane metrics: `busy_span_min` from the first served start through the last served finish, `idle_min` inside that span after served service is removed, and `utilization_percent`. Left customers do not affect these metrics. A zero-length span reports zero idle time and 0.00 percent; the option is rejected without a summary or with another value.

The parser accepts integer minutes from 0 through 1,000,000 and lane identifiers of 1–32 letters, digits, `_`, or `-`. A lane may not accumulate beyond 1,000,000,000 minutes. It rejects malformed columns, negative or nonnumeric values, and out-of-order arrivals. It does not infer missing people, model breaks or priority lanes, or read CSV quoting; later feature stages can add those deliberately.
