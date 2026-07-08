///|
pub(all) struct SketchRecommendation {
  severity : String
  code : String
  title : String
  detail : String
  action : String
} derive(Eq, Debug)

///|
pub fn recommendations_from_gate(
  report : SketchGateReport,
) -> Array[SketchRecommendation] {
  let items : Array[SketchRecommendation] = Array::new()
  if report.issues.length() == 0 {
    items.push(
      sketch_recommendation(
        "info", "gate-clean", "Quality gate passed", "The compared streams stayed inside the configured policy.",
        "Keep this policy in CI and tighten thresholds when the data becomes stable.",
      ),
    )
  } else {
    for issue in report.issues {
      items.push(recommendation_from_gate_issue(issue))
    }
  }
  if report.drift.candidate.bloom.fill_ratio > 0.70 {
    items.push(
      sketch_recommendation(
        "warning", "bloom-saturated", "Bloom filter is getting saturated", "The candidate bloom filter has a high bit fill ratio.",
        "Increase the bit array size or use more selective keys.",
      ),
    )
  }
  items
}

///|
pub fn recommendations_from_windowed(
  report : WindowedStreamReport,
) -> Array[SketchRecommendation] {
  let items : Array[SketchRecommendation] = Array::new()
  if report.windows.length() == 0 {
    items.push(
      sketch_recommendation(
        "warning", "empty-windowed-stream", "No windows were parsed", "The input did not contain any non-empty event window.",
        "Check whether the input uses spaces, commas, `|`, or `;` as separators.",
      ),
    )
    return items
  }
  if report.max_event_spike > 0 {
    items.push(
      sketch_recommendation(
        "info",
        "event-spike",
        "Window traffic changed",
        "At least one adjacent window increased by " +
        report.max_event_spike.to_string() +
        " events.",
        "Inspect the Top-K timeline to see whether the increase is concentrated in a few keys.",
      ),
    )
  }
  if report.min_similarity < 0.40 {
    items.push(
      sketch_recommendation(
        "warning",
        "low-window-similarity",
        "Top-K composition shifted",
        "The minimum adjacent-window MinHash similarity is " +
        sketch_double_text(report.min_similarity) +
        ".",
        "Treat this as a drift candidate and compare the raw examples for the affected window.",
      ),
    )
  }
  for snapshot in report.windows {
    if snapshot.bloom_false_positive_rate > 0.20 {
      items.push(
        sketch_recommendation(
          "warning",
          "window-bloom-fpr",
          "Bloom filter may be too small",
          snapshot.label +
          " has estimated false positive rate " +
          sketch_double_text(snapshot.bloom_false_positive_rate) +
          ".",
          "Use a larger bloom size for this event volume.",
        ),
      )
    }
  }
  if items.length() == 0 {
    items.push(
      sketch_recommendation(
        "info", "windowed-stable", "Windowed stream looks stable", "No strong spike, similarity drop, or bloom saturation was detected.",
        "Use the JSON output as a compact regression fixture.",
      ),
    )
  }
  items
}

///|
pub fn recommendations_from_weighted(
  summary : WeightedStreamSummary,
) -> Array[SketchRecommendation] {
  let items : Array[SketchRecommendation] = Array::new()
  if summary.event_rows == 0 {
    items.push(
      sketch_recommendation(
        "warning", "empty-weighted-stream", "No weighted events were parsed", "The input has no valid `key:weight` or `key=weight` token.",
        "Use tokens such as `login:12 checkout:3`.",
      ),
    )
    return items
  }
  if summary.total_weight > summary.event_rows * 20 {
    items.push(
      sketch_recommendation(
        "info",
        "heavy-weighted-updates",
        "Weights dominate row count",
        "The stream contains " +
        summary.event_rows.to_string() +
        " rows but " +
        summary.total_weight.to_string() +
        " total updates.",
        "Prefer weighted updates instead of expanding rows in application code.",
      ),
    )
  }
  if summary.topk.length() > 0 {
    let top = summary.topk[0]
    if top.count * 2 >= summary.total_weight {
      items.push(
        sketch_recommendation(
          "warning",
          "single-key-dominates",
          "One key dominates the weighted stream",
          top.key +
          " contributes " +
          top.count.to_string() +
          " out of " +
          summary.total_weight.to_string() +
          " weighted updates.",
          "Check whether this is expected traffic or a data-quality issue.",
        ),
      )
    }
  }
  if items.length() == 0 {
    items.push(
      sketch_recommendation(
        "info", "weighted-balanced", "Weighted stream is balanced", "No single key dominates and the row-to-weight ratio is moderate.",
        "Use the Count-Min table as a compact monitoring snapshot.",
      ),
    )
  }
  items
}

///|
pub fn recommendations_markdown(items : Array[SketchRecommendation]) -> String {
  let out = StringBuilder()
  out.write_string("# Sketch Recommendations\n\n")
  out.write_string(
    "| severity | code | title | action |\n| --- | --- | --- | --- |\n",
  )
  for item in items {
    out.write_string(
      "| " +
      item.severity +
      " | " +
      item.code +
      " | " +
      item.title +
      " | " +
      item.action +
      " |\n",
    )
  }
  out.to_string()
}

///|
pub fn recommendations_json(items : Array[SketchRecommendation]) -> String {
  let out = StringBuilder()
  out.write_string("[")
  for i in 0..<items.length() {
    if i > 0 {
      out.write_string(",")
    }
    let item = items[i]
    out.write_string(
      "{\"severity\":\"" +
      sketch_escape_json(item.severity) +
      "\",\"code\":\"" +
      sketch_escape_json(item.code) +
      "\",\"title\":\"" +
      sketch_escape_json(item.title) +
      "\",\"detail\":\"" +
      sketch_escape_json(item.detail) +
      "\",\"action\":\"" +
      sketch_escape_json(item.action) +
      "\"}",
    )
  }
  out.write_string("]")
  out.to_string()
}

///|
pub fn sketch_recommendation(
  severity : String,
  code : String,
  title : String,
  detail : String,
  action : String,
) -> SketchRecommendation {
  { severity, code, title, detail, action }
}

///|
fn recommendation_from_gate_issue(
  issue : SketchGateIssue,
) -> SketchRecommendation {
  let action = match issue.rule {
    "max_event_delta" =>
      "Check ingestion volume and decide whether the baseline should be updated."
    "max_unique_delta" =>
      "Inspect new key sources and look for accidental high-cardinality values."
    "min_top_overlap" =>
      "Compare Top-K tables and verify whether dominant traffic shifted."
    "min_minhash_similarity" =>
      "Sample both streams and inspect whether the population changed."
    "max_bloom_false_positive_rate" =>
      "Increase bloom filter size or lower the number of inserted keys per filter."
    _ => "Review the metric and add a project-specific rule if needed."
  }
  sketch_recommendation(
    issue.severity,
    issue.rule,
    "Gate issue: " + issue.metric,
    issue.message,
    action,
  )
}
