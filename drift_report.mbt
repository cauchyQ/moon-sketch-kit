///|
/// Compact snapshot of one stream for release notes, CI checks, and demos.
pub(all) struct StreamSnapshot {
  name : String
  events : Int
  exact_unique : Int
  hll_unique : Double
  topk : Array[TopKItem]
  sample : Array[String]
  bloom : BloomStats
} derive(Eq, Debug)

///|
pub(all) struct StreamDrift {
  baseline : StreamSnapshot
  candidate : StreamSnapshot
  event_delta : Int
  unique_delta : Int
  top_overlap : Double
  minhash_similarity : Double
} derive(Eq, Debug)

///|
pub fn stream_snapshot(name : String, input : String) -> StreamSnapshot {
  let events = parse_events(input)
  let counter = exact_counter_from_items(events)
  let hll = hll_from_items(events, 64)
  let topk = exact_counter_topk(counter, 5)
  let sampler = reservoir_from_items(events, 5)
  let bloom = bloom_from_items(events, 256, 4)
  {
    name,
    events: events.length(),
    exact_unique: exact_counter_unique(counter),
    hll_unique: hll_estimate(hll),
    topk,
    sample: sampler.samples,
    bloom: bloom_stats(bloom),
  }
}

///|
pub fn stream_snapshot_markdown(snapshot : StreamSnapshot) -> String {
  let out = StringBuilder()
  out.write_string("# Stream Snapshot: " + snapshot.name + "\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| events | " + snapshot.events.to_string() + " |\n")
  out.write_string(
    "| exact unique | " + snapshot.exact_unique.to_string() + " |\n",
  )
  out.write_string(
    "| hll-lite unique estimate | " +
    sketch_double_text(snapshot.hll_unique) +
    " |\n",
  )
  out.write_string(
    "| bloom set bits | " + snapshot.bloom.set_bits.to_string() + " |\n",
  )
  out.write_string(
    "| bloom estimated false positive rate | " +
    sketch_double_text(snapshot.bloom.estimated_false_positive_rate) +
    " |\n\n",
  )
  out.write_string("| top key | count |\n| --- | ---: |\n")
  for item in snapshot.topk {
    out.write_string("| " + item.key + " | " + item.count.to_string() + " |\n")
  }
  out.write_string("\n| sample index | value |\n| ---: | --- |\n")
  for i in 0..<snapshot.sample.length() {
    out.write_string("| " + i.to_string() + " | " + snapshot.sample[i] + " |\n")
  }
  out.to_string()
}

///|
pub fn stream_snapshot_json(snapshot : StreamSnapshot) -> String {
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"name\":\"" + sketch_escape_json(snapshot.name) + "\"")
  out.write_string(",\"events\":" + snapshot.events.to_string())
  out.write_string(",\"exact_unique\":" + snapshot.exact_unique.to_string())
  out.write_string(",\"hll_unique\":" + sketch_double_text(snapshot.hll_unique))
  out.write_string(",\"topk\":[")
  for i in 0..<snapshot.topk.length() {
    if i > 0 {
      out.write_string(",")
    }
    let item = snapshot.topk[i]
    out.write_string(
      "{\"key\":\"" +
      sketch_escape_json(item.key) +
      "\",\"count\":" +
      item.count.to_string() +
      "}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn stream_drift(
  baseline_name : String,
  baseline_input : String,
  candidate_name : String,
  candidate_input : String,
) -> StreamDrift {
  let baseline = stream_snapshot(baseline_name, baseline_input)
  let candidate = stream_snapshot(candidate_name, candidate_input)
  {
    baseline,
    candidate,
    event_delta: candidate.events - baseline.events,
    unique_delta: candidate.exact_unique - baseline.exact_unique,
    top_overlap: stream_top_overlap(baseline.topk, candidate.topk),
    minhash_similarity: minhash_similarity(
      minhash_from_items(parse_events(baseline_input), 64),
      minhash_from_items(parse_events(candidate_input), 64),
    ),
  }
}

///|
pub fn stream_drift_markdown(
  baseline_name : String,
  baseline_input : String,
  candidate_name : String,
  candidate_input : String,
) -> String {
  let drift = stream_drift(
    baseline_name, baseline_input, candidate_name, candidate_input,
  )
  let out = StringBuilder()
  out.write_string("# Stream Drift Report\n\n")
  out.write_string(
    "| metric | baseline | candidate | delta |\n| --- | ---: | ---: | ---: |\n",
  )
  out.write_string(
    "| events | " +
    drift.baseline.events.to_string() +
    " | " +
    drift.candidate.events.to_string() +
    " | " +
    drift.event_delta.to_string() +
    " |\n",
  )
  out.write_string(
    "| exact unique | " +
    drift.baseline.exact_unique.to_string() +
    " | " +
    drift.candidate.exact_unique.to_string() +
    " | " +
    drift.unique_delta.to_string() +
    " |\n",
  )
  out.write_string(
    "| top-k overlap | " + sketch_double_text(drift.top_overlap) + " |  |  |\n",
  )
  out.write_string(
    "| minhash similarity | " +
    sketch_double_text(drift.minhash_similarity) +
    " |  |  |\n\n",
  )
  out.write_string("## Baseline Top-K\n\n")
  out.write_string(stream_top_table(drift.baseline.topk))
  out.write_string("\n## Candidate Top-K\n\n")
  out.write_string(stream_top_table(drift.candidate.topk))
  out.to_string()
}

///|
pub fn stream_drift_json(
  baseline_name : String,
  baseline_input : String,
  candidate_name : String,
  candidate_input : String,
) -> String {
  let drift = stream_drift(
    baseline_name, baseline_input, candidate_name, candidate_input,
  )
  let out = StringBuilder()
  out.write_string("{")
  out.write_string(
    "\"baseline\":\"" + sketch_escape_json(drift.baseline.name) + "\"",
  )
  out.write_string(
    ",\"candidate\":\"" + sketch_escape_json(drift.candidate.name) + "\"",
  )
  out.write_string(",\"event_delta\":" + drift.event_delta.to_string())
  out.write_string(",\"unique_delta\":" + drift.unique_delta.to_string())
  out.write_string(",\"top_overlap\":" + sketch_double_text(drift.top_overlap))
  out.write_string(
    ",\"minhash_similarity\":" + sketch_double_text(drift.minhash_similarity),
  )
  out.write_string("}")
  out.to_string()
}

///|
fn stream_top_table(items : Array[TopKItem]) -> String {
  let out = StringBuilder()
  out.write_string("| key | count |\n| --- | ---: |\n")
  for item in items {
    out.write_string("| " + item.key + " | " + item.count.to_string() + " |\n")
  }
  out.to_string()
}

///|
fn stream_top_overlap(
  left : Array[TopKItem],
  right : Array[TopKItem],
) -> Double {
  if left.length() == 0 && right.length() == 0 {
    return 1.0
  }
  let union : Array[String] = Array::new()
  let intersection : Array[String] = Array::new()
  for item in left {
    if !stream_contains_key(union, item.key) {
      union.push(item.key)
    }
  }
  for item in right {
    if !stream_contains_key(union, item.key) {
      union.push(item.key)
    }
    if stream_top_has_key(left, item.key) &&
      !stream_contains_key(intersection, item.key) {
      intersection.push(item.key)
    }
  }
  if union.length() == 0 {
    0.0
  } else {
    intersection.length().to_double() / union.length().to_double()
  }
}

///|
fn stream_top_has_key(items : Array[TopKItem], key : String) -> Bool {
  for item in items {
    if item.key == key {
      return true
    }
  }
  false
}

///|
fn stream_contains_key(items : Array[String], key : String) -> Bool {
  for item in items {
    if item == key {
      return true
    }
  }
  false
}
