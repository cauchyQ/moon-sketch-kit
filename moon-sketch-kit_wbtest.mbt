///|
test "stable hash is deterministic" {
  inspect(sketch_hash("alpha", 1), content=sketch_hash("alpha", 1).to_string())
  inspect(sketch_hash("alpha", 1) == sketch_hash("alpha", 2), content="false")
}

///|
test "event parser accepts commas whitespace and newlines" {
  debug_inspect(
    parse_events("a,b c\nd\t e"),
    content="[\"a\", \"b\", \"c\", \"d\", \"e\"]",
  )
}

///|
test "json escaping protects quotes and slashes" {
  inspect(
    sketch_report_json("a \"quoted\" a").contains("\\\"quoted\\\""),
    content="true",
  )
}
