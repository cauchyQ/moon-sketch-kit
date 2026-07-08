///|
/// Fixed-width integer histogram for quick distribution previews.
pub(all) struct IntHistogram {
  min : Int
  max : Int
  buckets : Int
  counts : Array[Int]
  underflow : Int
  overflow : Int
  total : Int
} derive(Eq, Debug)

///|
pub(all) struct HistogramBucket {
  index : Int
  start : Int
  end : Int
  count : Int
} derive(Eq, Debug)

///|
pub(all) struct HistogramStats {
  total : Int
  underflow : Int
  overflow : Int
  non_empty_buckets : Int
  mode_bucket : Int
  mode_count : Int
} derive(Eq, Debug)

///|
pub fn histogram_new(min : Int, max : Int, buckets : Int) -> IntHistogram {
  let safe_buckets = sketch_max(1, buckets)
  let safe_max = if max <= min { min + safe_buckets } else { max }
  {
    min,
    max: safe_max,
    buckets: safe_buckets,
    counts: Array::make(safe_buckets, 0),
    underflow: 0,
    overflow: 0,
    total: 0,
  }
}

///|
pub fn histogram_add(histogram : IntHistogram, value : Int) -> IntHistogram {
  let counts = histogram.counts
  let mut underflow = histogram.underflow
  let mut overflow = histogram.overflow
  if value < histogram.min {
    underflow += 1
  } else if value > histogram.max {
    overflow += 1
  } else {
    let index = histogram_index(histogram, value)
    counts[index] += 1
  }
  {
    min: histogram.min,
    max: histogram.max,
    buckets: histogram.buckets,
    counts,
    underflow,
    overflow,
    total: histogram.total + 1,
  }
}

///|
pub fn histogram_from_values(
  values : Array[Int],
  min : Int,
  max : Int,
  buckets : Int,
) -> IntHistogram {
  let mut histogram = histogram_new(min, max, buckets)
  for value in values {
    histogram = histogram_add(histogram, value)
  }
  histogram
}

///|
pub fn histogram_from_text(
  input : String,
  min : Int,
  max : Int,
  buckets : Int,
) -> IntHistogram {
  let values : Array[Int] = Array::new()
  for token in parse_events(input) {
    match histogram_parse_int(token) {
      Some(value) => values.push(value)
      None => ()
    }
  }
  histogram_from_values(values, min, max, buckets)
}

///|
pub fn histogram_bucket_width(histogram : IntHistogram) -> Int {
  let span = histogram.max - histogram.min + 1
  let width = span / histogram.buckets
  if width <= 0 {
    1
  } else {
    width
  }
}

///|
pub fn histogram_index(histogram : IntHistogram, value : Int) -> Int {
  let width = histogram_bucket_width(histogram)
  let raw = (value - histogram.min) / width
  if raw < 0 {
    0
  } else if raw >= histogram.buckets {
    histogram.buckets - 1
  } else {
    raw
  }
}

///|
pub fn histogram_buckets(histogram : IntHistogram) -> Array[HistogramBucket] {
  let width = histogram_bucket_width(histogram)
  let out : Array[HistogramBucket] = Array::new()
  for i in 0..<histogram.buckets {
    let start = histogram.min + i * width
    let mut end = start + width - 1
    if i == histogram.buckets - 1 {
      end = histogram.max
    }
    out.push({ index: i, start, end, count: histogram.counts[i] })
  }
  out
}

///|
pub fn histogram_stats(histogram : IntHistogram) -> HistogramStats {
  let mut non_empty = 0
  let mut mode_bucket = 0
  let mut mode_count = 0
  for i in 0..<histogram.counts.length() {
    let count = histogram.counts[i]
    if count > 0 {
      non_empty += 1
    }
    if count > mode_count {
      mode_bucket = i
      mode_count = count
    }
  }
  {
    total: histogram.total,
    underflow: histogram.underflow,
    overflow: histogram.overflow,
    non_empty_buckets: non_empty,
    mode_bucket,
    mode_count,
  }
}

///|
pub fn histogram_approx_percentile(
  histogram : IntHistogram,
  percentile : Int,
) -> Int? {
  let in_range = histogram.total - histogram.underflow - histogram.overflow
  if in_range <= 0 {
    return None
  }
  let pct = if percentile < 0 {
    0
  } else if percentile > 100 {
    100
  } else {
    percentile
  }
  let target = sketch_max(1, (in_range * pct + 99) / 100)
  let mut seen = 0
  for bucket in histogram_buckets(histogram) {
    seen += bucket.count
    if seen >= target {
      return Some((bucket.start + bucket.end) / 2)
    }
  }
  Some(histogram.max)
}

///|
pub fn histogram_markdown(histogram : IntHistogram) -> String {
  let stats = histogram_stats(histogram)
  let out = StringBuilder()
  out.write_string("# Histogram Report\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| total | " + stats.total.to_string() + " |\n")
  out.write_string("| underflow | " + stats.underflow.to_string() + " |\n")
  out.write_string("| overflow | " + stats.overflow.to_string() + " |\n")
  out.write_string(
    "| non-empty buckets | " + stats.non_empty_buckets.to_string() + " |\n",
  )
  out.write_string("| mode bucket | " + stats.mode_bucket.to_string() + " |\n")
  out.write_string("| mode count | " + stats.mode_count.to_string() + " |\n\n")
  out.write_string(
    "| bucket | range | count | bar |\n| ---: | --- | ---: | --- |\n",
  )
  for bucket in histogram_buckets(histogram) {
    out.write_string(
      "| " +
      bucket.index.to_string() +
      " | " +
      bucket.start.to_string() +
      ".." +
      bucket.end.to_string() +
      " | " +
      bucket.count.to_string() +
      " | " +
      histogram_bar(bucket.count, stats.mode_count) +
      " |\n",
    )
  }
  out.to_string()
}

///|
pub fn histogram_json(histogram : IntHistogram) -> String {
  let stats = histogram_stats(histogram)
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"total\":" + stats.total.to_string() + ",")
  out.write_string("\"underflow\":" + stats.underflow.to_string() + ",")
  out.write_string("\"overflow\":" + stats.overflow.to_string() + ",")
  out.write_string("\"buckets\":[")
  let buckets = histogram_buckets(histogram)
  for i in 0..<buckets.length() {
    if i > 0 {
      out.write_string(",")
    }
    let bucket = buckets[i]
    out.write_string(
      "{\"index\":" +
      bucket.index.to_string() +
      ",\"start\":" +
      bucket.start.to_string() +
      ",\"end\":" +
      bucket.end.to_string() +
      ",\"count\":" +
      bucket.count.to_string() +
      "}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn histogram_bar(count : Int, max_count : Int) -> String {
  if count <= 0 || max_count <= 0 {
    return ""
  }
  let width = sketch_max(1, (count * 12 + max_count - 1) / max_count)
  let out = StringBuilder()
  for _ in 0..<width {
    out.write_char('#')
  }
  out.to_string()
}

///|
fn histogram_parse_int(token : String) -> Int? {
  try @string.parse_int(token) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}
