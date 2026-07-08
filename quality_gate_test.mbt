///|
test "default stream gate passes similar streams" {
  let report = evaluate_stream_gate_default("a b c a", "a b c a b")
  inspect(report.passed, content="true")
  inspect(report.issues.length(), content="0")
}

///|
test "stream gate flags large event delta" {
  let report = evaluate_stream_gate(
    "base",
    "a b",
    "candidate",
    "a b c d e f g h",
    {
      max_event_delta: 2,
      max_unique_delta: 10,
      min_top_overlap: 0.0,
      min_minhash_similarity: 0.0,
      max_bloom_false_positive_rate: 1.0,
    },
  )
  inspect(report.passed, content="false")
  inspect(report.issues[0].rule, content="max_event_delta")
}

///|
test "gate markdown and json render issues section" {
  let report = evaluate_stream_gate_default("a b c", "x y z")
  let markdown = sketch_gate_markdown(report)
  let json = sketch_gate_json(report)
  inspect(markdown.contains("# Sketch Quality Gate"), content="true")
  inspect(markdown.contains("## Policy"), content="true")
  inspect(json.contains("\"passed\""), content="true")
  inspect(json.contains("\"issues\""), content="true")
}

///|
test "count min error report compares exact and approximate counts" {
  let report = count_min_error_report(
    ["a", "b", "a", "c", "a", "b"],
    ["a", "b", "missing"],
    64,
    4,
  )
  inspect(report.total, content="3")
  inspect(report.max_overestimate >= 0, content="true")
  let markdown = count_min_error_markdown(report)
  inspect(markdown.contains("# Count-Min Error Report"), content="true")
  inspect(markdown.contains("| a | 3 |"), content="true")
}
