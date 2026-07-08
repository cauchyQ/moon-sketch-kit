///|
test "quantile summary computes numeric statistics" {
  let summary = quantile_from_values([10, 5, 30, 20, 40])
  let stats = numeric_summary(summary)
  inspect(stats.count, content="5")
  debug_inspect(stats.min, content="Some(5)")
  debug_inspect(stats.max, content="Some(40)")
  debug_inspect(stats.p50, content="Some(20)")
}

///|
test "quantile summary parses text and renders reports" {
  let summary = quantile_from_text("10 20 bad 30 40")
  let markdown = numeric_summary_markdown(summary)
  let json = numeric_summary_json(summary)
  inspect(markdown.contains("# Numeric Summary"), content="true")
  inspect(markdown.contains("| count | 4 |"), content="true")
  inspect(json.contains("\"count\":4"), content="true")
  inspect(json.contains("\"p90\""), content="true")
}

///|
test "quantile drift compares baseline and candidate" {
  let report = quantile_compare_markdown(
    quantile_from_values([1, 2, 3]),
    quantile_from_values([2, 4, 6]),
  )
  inspect(report.contains("# Quantile Drift Report"), content="true")
  inspect(report.contains("| p50 | 2 | 4 | 2 |"), content="true")
}

///|
test "stream snapshot captures topk and bloom stats" {
  let snapshot = stream_snapshot("day-1", "login view login buy login")
  inspect(snapshot.name, content="day-1")
  inspect(snapshot.events, content="5")
  inspect(snapshot.exact_unique, content="3")
  inspect(snapshot.topk[0].key, content="login")
  inspect(snapshot.bloom.set_bits > 0, content="true")
}

///|
test "stream snapshot markdown and json render" {
  let snapshot = stream_snapshot("demo", "a b a c")
  let markdown = stream_snapshot_markdown(snapshot)
  let json = stream_snapshot_json(snapshot)
  inspect(markdown.contains("# Stream Snapshot: demo"), content="true")
  inspect(markdown.contains("| a | 2 |"), content="true")
  inspect(json.contains("\"name\":\"demo\""), content="true")
}

///|
test "stream drift reports event and unique deltas" {
  let drift = stream_drift("base", "a b c", "cand", "a b b d")
  inspect(drift.event_delta, content="1")
  inspect(drift.unique_delta, content="0")
  inspect(drift.top_overlap > 0.0, content="true")
}

///|
test "stream drift markdown and json render" {
  let markdown = stream_drift_markdown("base", "a b c", "cand", "a b b d")
  let json = stream_drift_json("base", "a b c", "cand", "a b b d")
  inspect(markdown.contains("# Stream Drift Report"), content="true")
  inspect(markdown.contains("## Baseline Top-K"), content="true")
  inspect(json.contains("\"event_delta\":1"), content="true")
  inspect(json.contains("\"unique_delta\":0"), content="true")
}
