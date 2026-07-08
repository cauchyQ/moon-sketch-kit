///|
test "weighted token parser supports colon equals and defaults" {
  debug_inspect(
    parse_weighted_token("login:3"),
    content="Some({ key: \"login\", weight: 3 })",
  )
  debug_inspect(
    parse_weighted_token("view=2"),
    content="Some({ key: \"view\", weight: 2 })",
  )
  debug_inspect(
    parse_weighted_token("buy"),
    content="Some({ key: \"buy\", weight: 1 })",
  )
}

///|
test "weighted event parser ignores empty invalid keys" {
  let events = parse_weighted_events("login:3 view=2 buy :5")
  inspect(events.length(), content="3")
  inspect(events[0].key, content="login")
  inspect(events[0].weight, content="3")
}

///|
test "weighted summary updates exact and count min counts" {
  let summary = weighted_summary_from_text("login:3 view=2 login:2 buy")
  inspect(summary.event_rows, content="4")
  inspect(summary.total_weight, content="8")
  inspect(summary.unique_keys, content="3")
  inspect(weighted_estimate(summary, "login"), content="5")
}

///|
test "weighted summary renders markdown and json" {
  let summary = weighted_summary_from_text("login:3 view=2 login:2 buy")
  let markdown = weighted_summary_markdown(summary)
  let json = weighted_summary_json(summary)
  inspect(markdown.contains("# Weighted Stream Summary"), content="true")
  inspect(markdown.contains("| login | 5 | 5 |"), content="true")
  inspect(json.contains("\"total_weight\":8"), content="true")
  inspect(json.contains("\"key\":\"login\""), content="true")
}

///|
test "weighted comparison reports deltas" {
  let baseline = weighted_summary_from_text("login:2 view:1")
  let candidate = weighted_summary_from_text("login:4 buy:2")
  let report = weighted_compare_markdown(baseline, candidate)
  inspect(report.contains("# Weighted Stream Comparison"), content="true")
  inspect(report.contains("| total weight | 3 | 6 | 3 |"), content="true")
  inspect(report.contains("## Candidate Top-K"), content="true")
}
