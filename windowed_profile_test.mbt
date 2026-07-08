///|
test "windowed stream parses windows and detects changes" {
  let report = windowed_report_from_text("a a b | a c c c | z z z z")
  inspect(report.windows.length(), content="3")
  inspect(report.total_events, content="11")
  inspect(report.max_event_spike, content="1")
  inspect(report.windows[1].dominant_key, content="c")
  assert_true(
    windowed_report_markdown(report).contains("Windowed Stream Report"),
  )
  assert_true(windowed_report_json(report).contains("\"changes\""))
}

///|
test "top-k timeline is stable markdown" {
  let report = windowed_report_from_text("login login view | view view buy")
  let timeline = windowed_topk_timeline_markdown(report)
  assert_true(timeline.contains("Top-K Timeline"))
  assert_true(timeline.contains("login"))
  assert_true(timeline.contains("view"))
}

///|
test "recommendations explain windowed and weighted reports" {
  let windowed = windowed_report_from_text("a a a | z z z z z")
  let window_recs = recommendations_from_windowed(windowed)
  assert_true(window_recs.length() > 0)
  assert_true(
    recommendations_markdown(window_recs).contains("Sketch Recommendations"),
  )
  let weighted = weighted_summary_from_text("hot:100 cold:2 warm:3")
  let weighted_recs = recommendations_from_weighted(weighted)
  assert_true(weighted_recs.length() > 0)
  assert_true(
    recommendations_json(weighted_recs).contains("single-key-dominates"),
  )
}

///|
test "gate recommendations include issue-specific actions" {
  let policy : SketchQualityPolicy = {
    max_event_delta: 1,
    max_unique_delta: 1,
    min_top_overlap: 0.9,
    min_minhash_similarity: 0.9,
    max_bloom_false_positive_rate: 0.01,
  }
  let gate = evaluate_stream_gate("base", "a a b", "cand", "z z z z z", policy)
  let recs = recommendations_from_gate(gate)
  assert_true(recs.length() > 0)
  assert_true(recommendations_markdown(recs).contains("Gate issue"))
}

///|
test "token profile classifies shapes and emits recommendations" {
  let profile = token_profile_from_text(
    "login user42 123 /api/v1 alpha beta9", 3,
  )
  inspect(profile.total, content="6")
  inspect(profile.numeric, content="1")
  inspect(profile.alphabetic, content="2")
  inspect(profile.alphanumeric, content="2")
  inspect(profile.mixed, content="1")
  assert_true(token_profile_markdown(profile).contains("Token Profile"))
  assert_true(token_profile_json(profile).contains("\"prefix_topk\""))
  assert_true(token_profile_recommendations(profile).length() > 0)
}
