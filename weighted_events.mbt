///|
pub(all) struct WeightedEvent {
  key : String
  weight : Int
} derive(Eq, Debug)

///|
pub(all) struct WeightedStreamSummary {
  event_rows : Int
  total_weight : Int
  unique_keys : Int
  count_min : CountMinSketch
  exact : ExactCounter
  topk : Array[TopKItem]
} derive(Eq, Debug)

///|
pub fn weighted_event(key : String, weight : Int) -> WeightedEvent {
  { key, weight: sketch_max(0, weight) }
}

///|
pub fn parse_weighted_events(input : String) -> Array[WeightedEvent] {
  let events : Array[WeightedEvent] = Array::new()
  for token in parse_events(input) {
    match parse_weighted_token(token) {
      Some(event) => events.push(event)
      None => ()
    }
  }
  events
}

///|
pub fn parse_weighted_token(token : String) -> WeightedEvent? {
  let key = StringBuilder()
  let value = StringBuilder()
  let mut seen_sep = false
  for ch in token.iter() {
    if !seen_sep && (ch == ':' || ch == '=') {
      seen_sep = true
    } else if seen_sep {
      value.write_char(ch)
    } else {
      key.write_char(ch)
    }
  }
  let key_text = key.to_string()
  if key_text.is_empty() {
    return None
  }
  if !seen_sep {
    return Some({ key: key_text, weight: 1 })
  }
  let value_text = value.to_string()
  let weight = try @string.parse_int(value_text) catch {
    _ => 1
  } noraise {
    parsed => parsed
  }
  Some({ key: key_text, weight: sketch_max(0, weight) })
}

///|
pub fn weighted_summary(
  events : Array[WeightedEvent],
  width : Int,
  depth : Int,
  k : Int,
) -> WeightedStreamSummary {
  let mut cms = count_min_new(width, depth)
  let mut exact = exact_counter_new()
  let expanded : Array[String] = Array::new()
  let mut total_weight = 0
  for event in events {
    total_weight += event.weight
    cms = count_min_add_count(cms, event.key, event.weight)
    for _ in 0..<event.weight {
      exact = exact_counter_add(exact, event.key)
      expanded.push(event.key)
    }
  }
  {
    event_rows: events.length(),
    total_weight,
    unique_keys: exact_counter_unique(exact),
    count_min: cms,
    exact,
    topk: exact_counter_topk(exact, k),
  }
}

///|
pub fn weighted_summary_from_text(input : String) -> WeightedStreamSummary {
  weighted_summary(parse_weighted_events(input), 128, 5, 5)
}

///|
pub fn weighted_estimate(summary : WeightedStreamSummary, key : String) -> Int {
  count_min_estimate(summary.count_min, key)
}

///|
pub fn weighted_summary_markdown(summary : WeightedStreamSummary) -> String {
  let out = StringBuilder()
  out.write_string("# Weighted Stream Summary\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| event rows | " + summary.event_rows.to_string() + " |\n")
  out.write_string(
    "| total weight | " + summary.total_weight.to_string() + " |\n",
  )
  out.write_string(
    "| unique keys | " + summary.unique_keys.to_string() + " |\n",
  )
  out.write_string(
    "| sketch width | " + summary.count_min.width.to_string() + " |\n",
  )
  out.write_string(
    "| sketch depth | " + summary.count_min.depth.to_string() + " |\n\n",
  )
  out.write_string(
    "| key | exact count | estimated count |\n| --- | ---: | ---: |\n",
  )
  for item in summary.topk {
    out.write_string(
      "| " +
      item.key +
      " | " +
      item.count.to_string() +
      " | " +
      count_min_estimate(summary.count_min, item.key).to_string() +
      " |\n",
    )
  }
  out.to_string()
}

///|
pub fn weighted_summary_json(summary : WeightedStreamSummary) -> String {
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"event_rows\":" + summary.event_rows.to_string())
  out.write_string(",\"total_weight\":" + summary.total_weight.to_string())
  out.write_string(",\"unique_keys\":" + summary.unique_keys.to_string())
  out.write_string(",\"topk\":[")
  for i in 0..<summary.topk.length() {
    if i > 0 {
      out.write_string(",")
    }
    let item = summary.topk[i]
    out.write_string(
      "{\"key\":\"" +
      sketch_escape_json(item.key) +
      "\",\"exact\":" +
      item.count.to_string() +
      ",\"estimated\":" +
      count_min_estimate(summary.count_min, item.key).to_string() +
      "}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn weighted_compare_markdown(
  baseline : WeightedStreamSummary,
  candidate : WeightedStreamSummary,
) -> String {
  let out = StringBuilder()
  out.write_string("# Weighted Stream Comparison\n\n")
  out.write_string(
    "| metric | baseline | candidate | delta |\n| --- | ---: | ---: | ---: |\n",
  )
  weighted_compare_row(
    out,
    "event rows",
    baseline.event_rows,
    candidate.event_rows,
  )
  weighted_compare_row(
    out,
    "total weight",
    baseline.total_weight,
    candidate.total_weight,
  )
  weighted_compare_row(
    out,
    "unique keys",
    baseline.unique_keys,
    candidate.unique_keys,
  )
  out.write_string("\n## Candidate Top-K\n\n")
  out.write_string(
    "| key | exact count | estimated count |\n| --- | ---: | ---: |\n",
  )
  for item in candidate.topk {
    out.write_string(
      "| " +
      item.key +
      " | " +
      item.count.to_string() +
      " | " +
      weighted_estimate(candidate, item.key).to_string() +
      " |\n",
    )
  }
  out.to_string()
}

///|
fn weighted_compare_row(
  out : StringBuilder,
  label : String,
  baseline : Int,
  candidate : Int,
) -> Unit {
  out.write_string(
    "| " +
    label +
    " | " +
    baseline.to_string() +
    " | " +
    candidate.to_string() +
    " | " +
    (candidate - baseline).to_string() +
    " |\n",
  )
}
