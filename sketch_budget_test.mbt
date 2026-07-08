///|
test "budget planner derives sketch parameters from sample text" {
  let plan = sketch_budget_from_text("a b c a b d e f g h", 5)
  inspect(plan.expected_events, content="10")
  inspect(plan.expected_unique, content="8")
  assert_true(plan.count_min_width >= 32)
  assert_true(plan.bloom_bits >= 64)
  assert_true(sketch_budget_markdown(plan).contains("Sketch Budget Plan"))
  assert_true(sketch_budget_json(plan).contains("\"estimated_cells\""))
}

///|
test "budget planner clamps accuracy and explains recommendations" {
  let plan = sketch_budget_plan(100, 90, 99)
  inspect(plan.accuracy_level, content="10")
  assert_true(plan.hll_buckets <= 256)
  let recs = sketch_budget_recommendations(plan)
  assert_true(recs.length() > 0)
  assert_true(recommendations_markdown(recs).contains("Sketch Recommendations"))
}
