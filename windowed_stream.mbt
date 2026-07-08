///|
/// A logical batch inside a stream. Window text uses `|` or `;` as separators.
pub(all) struct EventWindow {
  index : Int
  label : String
  events : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct WindowSnapshot {
  index : Int
  label : String
  events : Int
  exact_unique : Int
  hll_unique : Double
  bloom_false_positive_rate : Double
  dominant_key : String
  dominant_count : Int
  topk : Array[TopKItem]
} derive(Eq, Debug)

///|
pub(all) struct WindowChange {
  index : Int
  previous_label : String
  current_label : String
  event_delta : Int
  unique_delta : Int
  top_overlap : Double
  minhash_similarity : Double
  dominant_key : String
  dominant_count : Int
} derive(Eq, Debug)

///|
pub(all) struct WindowedStreamReport {
  windows : Array[WindowSnapshot]
  changes : Array[WindowChange]
  total_events : Int
  max_event_spike : Int
  min_similarity : Double
} derive(Eq, Debug)

///|
pub fn parse_event_windows(input : String) -> Array[EventWindow] {
  let windows : Array[EventWindow] = Array::new()
  let token = StringBuilder()
  let mut current : Array[String] = Array::new()
  let mut index = 0
  for ch in input.iter() {
    if window_separator(ch) {
      window_flush_token(current, token)
      if current.length() > 0 {
        windows.push({ index, label: window_label(index), events: current })
        index += 1
      }
      current = Array::new()
    } else if window_token_separator(ch) {
      window_flush_token(current, token)
    } else {
      token.write_char(ch)
    }
  }
  window_flush_token(current, token)
  if current.length() > 0 {
    windows.push({ index, label: window_label(index), events: current })
  }
  windows
}

///|
pub fn windowed_report_from_text(input : String) -> WindowedStreamReport {
  windowed_report(parse_event_windows(input))
}

///|
pub fn windowed_report(windows : Array[EventWindow]) -> WindowedStreamReport {
  let snapshots : Array[WindowSnapshot] = Array::new()
  let changes : Array[WindowChange] = Array::new()
  let mut total = 0
  for window in windows {
    let snapshot = window_snapshot(window)
    total += snapshot.events
    snapshots.push(snapshot)
  }
  for i in 1..<snapshots.length() {
    changes.push(window_change(snapshots[i - 1], snapshots[i]))
  }
  {
    windows: snapshots,
    changes,
    total_events: total,
    max_event_spike: window_max_spike(changes),
    min_similarity: window_min_similarity(changes),
  }
}

///|
pub fn window_snapshot(window : EventWindow) -> WindowSnapshot {
  let counter = exact_counter_from_items(window.events)
  let topk = exact_counter_topk(counter, 5)
  let bloom = bloom_stats(bloom_from_items(window.events, 256, 4))
  let dominant = if topk.length() == 0 {
    { key: "", count: 0, error: 0 }
  } else {
    topk[0]
  }
  {
    index: window.index,
    label: window.label,
    events: window.events.length(),
    exact_unique: exact_counter_unique(counter),
    hll_unique: hll_estimate(hll_from_items(window.events, 64)),
    bloom_false_positive_rate: bloom.estimated_false_positive_rate,
    dominant_key: dominant.key,
    dominant_count: dominant.count,
    topk,
  }
}

///|
pub fn window_change(
  previous : WindowSnapshot,
  current : WindowSnapshot,
) -> WindowChange {
  {
    index: current.index,
    previous_label: previous.label,
    current_label: current.label,
    event_delta: current.events - previous.events,
    unique_delta: current.exact_unique - previous.exact_unique,
    top_overlap: window_top_overlap(previous.topk, current.topk),
    minhash_similarity: window_top_minhash(previous.topk, current.topk),
    dominant_key: current.dominant_key,
    dominant_count: current.dominant_count,
  }
}

///|
pub fn windowed_report_markdown(report : WindowedStreamReport) -> String {
  let out = StringBuilder()
  out.write_string("# Windowed Stream Report\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string(
    "| windows | " + report.windows.length().to_string() + " |\n",
  )
  out.write_string(
    "| total events | " + report.total_events.to_string() + " |\n",
  )
  out.write_string(
    "| max event spike | " + report.max_event_spike.to_string() + " |\n",
  )
  out.write_string(
    "| min top similarity | " +
    sketch_double_text(report.min_similarity) +
    " |\n\n",
  )
  out.write_string("## Windows\n\n")
  out.write_string(
    "| window | events | unique | hll estimate | dominant key | dominant count | bloom fpr |\n| --- | ---: | ---: | ---: | --- | ---: | ---: |\n",
  )
  for snapshot in report.windows {
    out.write_string(
      "| " +
      snapshot.label +
      " | " +
      snapshot.events.to_string() +
      " | " +
      snapshot.exact_unique.to_string() +
      " | " +
      sketch_double_text(snapshot.hll_unique) +
      " | " +
      snapshot.dominant_key +
      " | " +
      snapshot.dominant_count.to_string() +
      " | " +
      sketch_double_text(snapshot.bloom_false_positive_rate) +
      " |\n",
    )
  }
  out.write_string("\n## Changes\n\n")
  if report.changes.length() == 0 {
    out.write_string("No adjacent window changes.\n")
  } else {
    out.write_string(
      "| from | to | event delta | unique delta | top overlap | top minhash | dominant key |\n| --- | --- | ---: | ---: | ---: | ---: | --- |\n",
    )
    for change in report.changes {
      out.write_string(
        "| " +
        change.previous_label +
        " | " +
        change.current_label +
        " | " +
        change.event_delta.to_string() +
        " | " +
        change.unique_delta.to_string() +
        " | " +
        sketch_double_text(change.top_overlap) +
        " | " +
        sketch_double_text(change.minhash_similarity) +
        " | " +
        change.dominant_key +
        " |\n",
      )
    }
  }
  out.to_string()
}

///|
pub fn windowed_report_json(report : WindowedStreamReport) -> String {
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"windows\":[")
  for i in 0..<report.windows.length() {
    if i > 0 {
      out.write_string(",")
    }
    let snapshot = report.windows[i]
    out.write_string(
      "{\"label\":\"" +
      sketch_escape_json(snapshot.label) +
      "\",\"events\":" +
      snapshot.events.to_string() +
      ",\"unique\":" +
      snapshot.exact_unique.to_string() +
      ",\"hll_unique\":" +
      sketch_double_text(snapshot.hll_unique) +
      ",\"dominant_key\":\"" +
      sketch_escape_json(snapshot.dominant_key) +
      "\",\"dominant_count\":" +
      snapshot.dominant_count.to_string() +
      "}",
    )
  }
  out.write_string("],\"changes\":[")
  for i in 0..<report.changes.length() {
    if i > 0 {
      out.write_string(",")
    }
    let change = report.changes[i]
    out.write_string(
      "{\"from\":\"" +
      sketch_escape_json(change.previous_label) +
      "\",\"to\":\"" +
      sketch_escape_json(change.current_label) +
      "\",\"event_delta\":" +
      change.event_delta.to_string() +
      ",\"unique_delta\":" +
      change.unique_delta.to_string() +
      ",\"top_overlap\":" +
      sketch_double_text(change.top_overlap) +
      ",\"minhash_similarity\":" +
      sketch_double_text(change.minhash_similarity) +
      "}",
    )
  }
  out.write_string(
    "],\"total_events\":" +
    report.total_events.to_string() +
    ",\"max_event_spike\":" +
    report.max_event_spike.to_string() +
    ",\"min_similarity\":" +
    sketch_double_text(report.min_similarity) +
    "}",
  )
  out.to_string()
}

///|
pub fn windowed_topk_timeline_markdown(report : WindowedStreamReport) -> String {
  let out = StringBuilder()
  out.write_string("# Top-K Timeline\n\n")
  out.write_string(
    "| window | rank | key | count |\n| --- | ---: | --- | ---: |\n",
  )
  for snapshot in report.windows {
    for i in 0..<snapshot.topk.length() {
      let item = snapshot.topk[i]
      out.write_string(
        "| " +
        snapshot.label +
        " | " +
        (i + 1).to_string() +
        " | " +
        item.key +
        " | " +
        item.count.to_string() +
        " |\n",
      )
    }
  }
  out.to_string()
}

///|
fn window_flush_token(events : Array[String], token : StringBuilder) -> Unit {
  let value = token.to_string()
  if !value.is_empty() {
    events.push(value)
    token.reset()
  }
}

///|
fn window_label(index : Int) -> String {
  "window-" + (index + 1).to_string()
}

///|
fn window_separator(ch : Char) -> Bool {
  ch == '|' || ch == ';'
}

///|
fn window_token_separator(ch : Char) -> Bool {
  ch == ',' || ch == '\n' || ch == '\r' || ch == '\t' || ch == ' '
}

///|
fn window_max_spike(changes : Array[WindowChange]) -> Int {
  let mut spike = 0
  for change in changes {
    if change.event_delta > spike {
      spike = change.event_delta
    }
  }
  spike
}

///|
fn window_min_similarity(changes : Array[WindowChange]) -> Double {
  if changes.length() == 0 {
    return 1.0
  }
  let mut value = 1.0
  for change in changes {
    if change.minhash_similarity < value {
      value = change.minhash_similarity
    }
  }
  value
}

///|
fn window_top_overlap(
  left : Array[TopKItem],
  right : Array[TopKItem],
) -> Double {
  if left.length() == 0 && right.length() == 0 {
    return 1.0
  }
  let union : Array[String] = Array::new()
  let intersection : Array[String] = Array::new()
  for item in left {
    if !sketch_contains(union, item.key) {
      union.push(item.key)
    }
  }
  for item in right {
    if !sketch_contains(union, item.key) {
      union.push(item.key)
    }
    if window_top_has_key(left, item.key) &&
      !sketch_contains(intersection, item.key) {
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
fn window_top_minhash(
  left : Array[TopKItem],
  right : Array[TopKItem],
) -> Double {
  let left_keys : Array[String] = Array::new()
  let right_keys : Array[String] = Array::new()
  for item in left {
    left_keys.push(item.key)
  }
  for item in right {
    right_keys.push(item.key)
  }
  minhash_similarity(
    minhash_from_items(left_keys, 32),
    minhash_from_items(right_keys, 32),
  )
}

///|
fn window_top_has_key(items : Array[TopKItem], key : String) -> Bool {
  for item in items {
    if item.key == key {
      return true
    }
  }
  false
}
