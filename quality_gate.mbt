///|
pub(all) struct SketchQualityPolicy {
  max_event_delta : Int
  max_unique_delta : Int
  min_top_overlap : Double
  min_minhash_similarity : Double
  max_bloom_false_positive_rate : Double
} derive(Eq, Debug)

///|
pub(all) struct SketchGateIssue {
  severity : String
  rule : String
  metric : String
  message : String
} derive(Eq, Debug)

///|
pub(all) struct SketchGateReport {
  passed : Bool
  policy : SketchQualityPolicy
  drift : StreamDrift
  issues : Array[SketchGateIssue]
} derive(Eq, Debug)

///|
pub(all) struct CountMinError {
  key : String
  exact : Int
  estimated : Int
  overestimate : Int
} derive(Eq, Debug)

///|
pub(all) struct CountMinErrorReport {
  total : Int
  max_overestimate : Int
  average_overestimate : Double
  rows : Array[CountMinError]
} derive(Eq, Debug)

///|
pub fn sketch_quality_policy_default() -> SketchQualityPolicy {
  {
    max_event_delta: 1000,
    max_unique_delta: 1000,
    min_top_overlap: 0.25,
    min_minhash_similarity: 0.25,
    max_bloom_false_positive_rate: 0.20,
  }
}

///|
pub fn sketch_quality_policy_strict() -> SketchQualityPolicy {
  {
    max_event_delta: 100,
    max_unique_delta: 100,
    min_top_overlap: 0.50,
    min_minhash_similarity: 0.50,
    max_bloom_false_positive_rate: 0.10,
  }
}

///|
pub fn evaluate_stream_gate(
  baseline_name : String,
  baseline_input : String,
  candidate_name : String,
  candidate_input : String,
  policy : SketchQualityPolicy,
) -> SketchGateReport {
  let drift = stream_drift(
    baseline_name, baseline_input, candidate_name, candidate_input,
  )
  let issues : Array[SketchGateIssue] = Array::new()
  if sketch_abs(drift.event_delta) > policy.max_event_delta {
    issues.push(
      sketch_gate_issue(
        "error",
        "max_event_delta",
        "events",
        "Event count delta " +
        drift.event_delta.to_string() +
        " is above allowed " +
        policy.max_event_delta.to_string() +
        ".",
      ),
    )
  }
  if sketch_abs(drift.unique_delta) > policy.max_unique_delta {
    issues.push(
      sketch_gate_issue(
        "error",
        "max_unique_delta",
        "unique",
        "Unique count delta " +
        drift.unique_delta.to_string() +
        " is above allowed " +
        policy.max_unique_delta.to_string() +
        ".",
      ),
    )
  }
  if drift.top_overlap < policy.min_top_overlap {
    issues.push(
      sketch_gate_issue(
        "warning",
        "min_top_overlap",
        "topk",
        "Top-K overlap " +
        sketch_double_text(drift.top_overlap) +
        " is below required " +
        sketch_double_text(policy.min_top_overlap) +
        ".",
      ),
    )
  }
  if drift.minhash_similarity < policy.min_minhash_similarity {
    issues.push(
      sketch_gate_issue(
        "warning",
        "min_minhash_similarity",
        "similarity",
        "MinHash similarity " +
        sketch_double_text(drift.minhash_similarity) +
        " is below required " +
        sketch_double_text(policy.min_minhash_similarity) +
        ".",
      ),
    )
  }
  if drift.candidate.bloom.estimated_false_positive_rate >
    policy.max_bloom_false_positive_rate {
    issues.push(
      sketch_gate_issue(
        "warning",
        "max_bloom_false_positive_rate",
        "bloom",
        "Candidate bloom false positive estimate " +
        sketch_double_text(drift.candidate.bloom.estimated_false_positive_rate) +
        " is above allowed " +
        sketch_double_text(policy.max_bloom_false_positive_rate) +
        ".",
      ),
    )
  }
  { passed: sketch_gate_error_count(issues) == 0, policy, drift, issues }
}

///|
pub fn evaluate_stream_gate_default(
  baseline_input : String,
  candidate_input : String,
) -> SketchGateReport {
  evaluate_stream_gate(
    "baseline",
    baseline_input,
    "candidate",
    candidate_input,
    sketch_quality_policy_default(),
  )
}

///|
pub fn sketch_gate_markdown(report : SketchGateReport) -> String {
  let out = StringBuilder()
  let status = if report.passed { "pass" } else { "fail" }
  out.write_string("# Sketch Quality Gate\n\n")
  out.write_string("## Summary\n\n")
  out.write_string("- Status: " + status + "\n")
  out.write_string(
    "- Event delta: " + report.drift.event_delta.to_string() + "\n",
  )
  out.write_string(
    "- Unique delta: " + report.drift.unique_delta.to_string() + "\n",
  )
  out.write_string(
    "- Top-K overlap: " + sketch_double_text(report.drift.top_overlap) + "\n",
  )
  out.write_string(
    "- MinHash similarity: " +
    sketch_double_text(report.drift.minhash_similarity) +
    "\n\n",
  )
  out.write_string("## Policy\n\n")
  out.write_string("| rule | value |\n| --- | ---: |\n")
  out.write_string(
    "| max_event_delta | " + report.policy.max_event_delta.to_string() + " |\n",
  )
  out.write_string(
    "| max_unique_delta | " +
    report.policy.max_unique_delta.to_string() +
    " |\n",
  )
  out.write_string(
    "| min_top_overlap | " +
    sketch_double_text(report.policy.min_top_overlap) +
    " |\n",
  )
  out.write_string(
    "| min_minhash_similarity | " +
    sketch_double_text(report.policy.min_minhash_similarity) +
    " |\n",
  )
  out.write_string(
    "| max_bloom_false_positive_rate | " +
    sketch_double_text(report.policy.max_bloom_false_positive_rate) +
    " |\n\n",
  )
  out.write_string("## Issues\n\n")
  if report.issues.length() == 0 {
    out.write_string("No gate issues.\n")
  } else {
    out.write_string(
      "| severity | rule | metric | message |\n| --- | --- | --- | --- |\n",
    )
    for issue in report.issues {
      out.write_string(
        "| " +
        issue.severity +
        " | " +
        issue.rule +
        " | " +
        issue.metric +
        " | " +
        issue.message +
        " |\n",
      )
    }
  }
  out.to_string()
}

///|
pub fn sketch_gate_json(report : SketchGateReport) -> String {
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"passed\":" + report.passed.to_string())
  out.write_string(",\"event_delta\":" + report.drift.event_delta.to_string())
  out.write_string(",\"unique_delta\":" + report.drift.unique_delta.to_string())
  out.write_string(
    ",\"top_overlap\":" + sketch_double_text(report.drift.top_overlap),
  )
  out.write_string(
    ",\"minhash_similarity\":" +
    sketch_double_text(report.drift.minhash_similarity),
  )
  out.write_string(",\"issues\":[")
  for i in 0..<report.issues.length() {
    if i > 0 {
      out.write_string(",")
    }
    let issue = report.issues[i]
    out.write_string(
      "{\"severity\":\"" +
      sketch_escape_json(issue.severity) +
      "\",\"rule\":\"" +
      sketch_escape_json(issue.rule) +
      "\",\"metric\":\"" +
      sketch_escape_json(issue.metric) +
      "\",\"message\":\"" +
      sketch_escape_json(issue.message) +
      "\"}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn count_min_error_report(
  items : Array[String],
  probes : Array[String],
  width : Int,
  depth : Int,
) -> CountMinErrorReport {
  let exact = exact_counter_from_items(items)
  let sketch = count_min_from_items(items, width, depth)
  let rows : Array[CountMinError] = Array::new()
  let mut total_over = 0
  let mut max_over = 0
  for key in probes {
    let exact_count = exact_counter_count(exact, key)
    let estimated = count_min_estimate(sketch, key)
    let over = estimated - exact_count
    total_over += over
    if over > max_over {
      max_over = over
    }
    rows.push({ key, exact: exact_count, estimated, overestimate: over })
  }
  let average = if rows.length() == 0 {
    0.0
  } else {
    total_over.to_double() / rows.length().to_double()
  }
  {
    total: rows.length(),
    max_overestimate: max_over,
    average_overestimate: average,
    rows,
  }
}

///|
pub fn count_min_error_markdown(report : CountMinErrorReport) -> String {
  let out = StringBuilder()
  out.write_string("# Count-Min Error Report\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| probes | " + report.total.to_string() + " |\n")
  out.write_string(
    "| max overestimate | " + report.max_overestimate.to_string() + " |\n",
  )
  out.write_string(
    "| average overestimate | " +
    sketch_double_text(report.average_overestimate) +
    " |\n\n",
  )
  out.write_string(
    "| key | exact | estimated | overestimate |\n| --- | ---: | ---: | ---: |\n",
  )
  for row in report.rows {
    out.write_string(
      "| " +
      row.key +
      " | " +
      row.exact.to_string() +
      " | " +
      row.estimated.to_string() +
      " | " +
      row.overestimate.to_string() +
      " |\n",
    )
  }
  out.to_string()
}

///|
pub fn sketch_gate_issue(
  severity : String,
  rule : String,
  metric : String,
  message : String,
) -> SketchGateIssue {
  { severity, rule, metric, message }
}

///|
fn sketch_gate_error_count(issues : Array[SketchGateIssue]) -> Int {
  let mut count = 0
  for issue in issues {
    if issue.severity == "error" {
      count += 1
    }
  }
  count
}

///|
fn sketch_abs(value : Int) -> Int {
  if value < 0 {
    0 - value
  } else {
    value
  }
}
