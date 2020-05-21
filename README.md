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

The parser accepts integer minutes from 0 through 1,000,000 and lane identifiers of 1–32 letters, digits, `_`, or `-`. A lane may not accumulate beyond 1,000,000,000 minutes. It rejects malformed columns, negative or nonnumeric values, and out-of-order arrivals. It does not infer missing people, model breaks or priority lanes, or read CSV quoting; later feature stages can add those deliberately.
