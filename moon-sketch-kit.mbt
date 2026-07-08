///|
/// Stable hash used by all sketches in this package.
///
/// The implementation is intentionally deterministic across targets. It is not
/// cryptographic; it is meant for repeatable sketch indexing, examples, and
/// tests.
pub fn sketch_hash(value : String, seed : Int) -> Int {
  let mut hash = 16777619 + seed * 65537
  for ch in value.iter() {
    hash = sketch_mix(hash, ch.to_int())
  }
  sketch_positive(hash)
}

///|
fn sketch_mix(hash : Int, value : Int) -> Int {
  let mut mixed = hash ^ value
  mixed = mixed * 16777619
  mixed = mixed ^ (mixed / 65536)
  sketch_positive(mixed)
}

///|
fn sketch_positive(value : Int) -> Int {
  if value < 0 {
    0 - value
  } else {
    value
  }
}

///|
fn sketch_index(value : String, seed : Int, width : Int) -> Int {
  if width <= 0 {
    0
  } else {
    sketch_hash(value, seed) % width
  }
}

///|
fn sketch_max(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn sketch_min(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn sketch_contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn sketch_escape_json(value : String) -> String {
  let out = StringBuilder()
  for ch in value.iter() {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn sketch_split_words(input : String) -> Array[String] {
  let words : Array[String] = Array::new()
  let current = StringBuilder()
  for ch in input.iter() {
    if ch == ',' || ch == '\n' || ch == '\r' || ch == '\t' || ch == ' ' {
      let word = current.to_string()
      if !word.is_empty() {
        words.push(word)
      }
      current.reset()
    } else {
      current.write_char(ch)
    }
  }
  let tail = current.to_string()
  if !tail.is_empty() {
    words.push(tail)
  }
  words
}

///|
fn sketch_double_text(value : Double) -> String {
  let rounded = value.to_int().to_double()
  if value == rounded {
    value.to_int().to_string()
  } else {
    value.to_string()
  }
}

///|
pub(all) struct CountMinSketch {
  width : Int
  depth : Int
  total : Int
  cells : Array[Int]
} derive(Eq, Debug)

///|
pub fn count_min_new(width : Int, depth : Int) -> CountMinSketch {
  let safe_width = sketch_max(1, width)
  let safe_depth = sketch_max(1, depth)
  {
    width: safe_width,
    depth: safe_depth,
    total: 0,
    cells: Array::make(safe_width * safe_depth, 0),
  }
}

///|
pub fn count_min_add(sketch : CountMinSketch, key : String) -> CountMinSketch {
  count_min_add_count(sketch, key, 1)
}

///|
pub fn count_min_add_count(
  sketch : CountMinSketch,
  key : String,
  count : Int,
) -> CountMinSketch {
  let amount = sketch_max(0, count)
  let cells = sketch.cells
  for row in 0..<sketch.depth {
    let col = sketch_index(key, row + 1, sketch.width)
    let offset = row * sketch.width + col
    cells[offset] += amount
  }
  {
    width: sketch.width,
    depth: sketch.depth,
    total: sketch.total + amount,
    cells,
  }
}

///|
pub fn count_min_estimate(sketch : CountMinSketch, key : String) -> Int {
  let mut best : Int? = None
  for row in 0..<sketch.depth {
    let col = sketch_index(key, row + 1, sketch.width)
    let offset = row * sketch.width + col
    best = Some(
      match best {
        Some(current) => sketch_min(current, sketch.cells[offset])
        None => sketch.cells[offset]
      },
    )
  }
  best.unwrap_or(0)
}

///|
pub fn count_min_from_items(
  items : Array[String],
  width : Int,
  depth : Int,
) -> CountMinSketch {
  let mut sketch = count_min_new(width, depth)
  for item in items {
    sketch = count_min_add(sketch, item)
  }
  sketch
}

///|
pub fn count_min_summary_markdown(
  sketch : CountMinSketch,
  keys : Array[String],
) -> String {
  let out = StringBuilder()
  out.write_string("# Count-Min Sketch Summary\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| width | " + sketch.width.to_string() + " |\n")
  out.write_string("| depth | " + sketch.depth.to_string() + " |\n")
  out.write_string("| total updates | " + sketch.total.to_string() + " |\n\n")
  out.write_string("| key | estimated frequency |\n| --- | ---: |\n")
  for key in keys {
    out.write_string(
      "| " + key + " | " + count_min_estimate(sketch, key).to_string() + " |\n",
    )
  }
  out.to_string()
}

///|
pub(all) struct TopKItem {
  key : String
  count : Int
  error : Int
} derive(Eq, Debug)

///|
pub(all) struct SpaceSavingTopK {
  capacity : Int
  total : Int
  items : Array[TopKItem]
} derive(Eq, Debug)

///|
pub fn topk_new(capacity : Int) -> SpaceSavingTopK {
  { capacity: sketch_max(1, capacity), total: 0, items: [] }
}

///|
pub fn topk_add(topk : SpaceSavingTopK, key : String) -> SpaceSavingTopK {
  let items = topk.items
  match sketch_topk_index(items, key) {
    Some(index) =>
      items[index] = {
        key,
        count: items[index].count + 1,
        error: items[index].error,
      }
    None =>
      if items.length() < topk.capacity {
        items.push({ key, count: 1, error: 0 })
      } else {
        let min_index = sketch_topk_min_index(items)
        let previous = items[min_index]
        items[min_index] = {
          key,
          count: previous.count + 1,
          error: previous.count,
        }
      }
  }
  sketch_topk_sort({ capacity: topk.capacity, total: topk.total + 1, items })
}

///|
pub fn topk_from_items(
  items : Array[String],
  capacity : Int,
) -> SpaceSavingTopK {
  let mut topk = topk_new(capacity)
  for item in items {
    topk = topk_add(topk, item)
  }
  topk
}

///|
fn sketch_topk_index(items : Array[TopKItem], key : String) -> Int? {
  for i in 0..<items.length() {
    if items[i].key == key {
      return Some(i)
    }
  }
  None
}

///|
fn sketch_topk_min_index(items : Array[TopKItem]) -> Int {
  let mut index = 0
  for i in 1..<items.length() {
    if items[i].count < items[index].count {
      index = i
    }
  }
  index
}

///|
fn sketch_topk_sort(topk : SpaceSavingTopK) -> SpaceSavingTopK {
  let items = topk.items
  for i in 0..<items.length() {
    for j in (i + 1)..<items.length() {
      if items[j].count > items[i].count ||
        (items[j].count == items[i].count && items[j].key < items[i].key) {
        let tmp = items[i]
        items[i] = items[j]
        items[j] = tmp
      }
    }
  }
  { capacity: topk.capacity, total: topk.total, items }
}

///|
pub fn topk_markdown(topk : SpaceSavingTopK) -> String {
  let out = StringBuilder()
  out.write_string("# Space-Saving Top-K\n\n")
  out.write_string("| key | count | max error |\n| --- | ---: | ---: |\n")
  for item in topk.items {
    out.write_string(
      "| " +
      item.key +
      " | " +
      item.count.to_string() +
      " | " +
      item.error.to_string() +
      " |\n",
    )
  }
  out.to_string()
}

///|
pub(all) struct ReservoirSampler {
  capacity : Int
  seen : Int
  samples : Array[String]
} derive(Eq, Debug)

///|
pub fn reservoir_new(capacity : Int) -> ReservoirSampler {
  { capacity: sketch_max(1, capacity), seen: 0, samples: [] }
}

///|
pub fn reservoir_add(
  sampler : ReservoirSampler,
  value : String,
) -> ReservoirSampler {
  let samples = sampler.samples
  let seen = sampler.seen + 1
  if samples.length() < sampler.capacity {
    samples.push(value)
  } else {
    let index = sketch_hash(value, seen) % seen
    if index < sampler.capacity {
      samples[index] = value
    }
  }
  { capacity: sampler.capacity, seen, samples }
}

///|
pub fn reservoir_from_items(
  items : Array[String],
  capacity : Int,
) -> ReservoirSampler {
  let mut sampler = reservoir_new(capacity)
  for item in items {
    sampler = reservoir_add(sampler, item)
  }
  sampler
}

///|
pub fn reservoir_markdown(sampler : ReservoirSampler) -> String {
  let out = StringBuilder()
  out.write_string("# Reservoir Sample\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| seen | " + sampler.seen.to_string() + " |\n")
  out.write_string(
    "| sample size | " + sampler.samples.length().to_string() + " |\n\n",
  )
  out.write_string("| index | value |\n| ---: | --- |\n")
  for i in 0..<sampler.samples.length() {
    out.write_string("| " + i.to_string() + " | " + sampler.samples[i] + " |\n")
  }
  out.to_string()
}

///|
pub(all) struct HyperLogLogLite {
  buckets : Int
  registers : Array[Int]
} derive(Eq, Debug)

///|
pub fn hll_new(buckets : Int) -> HyperLogLogLite {
  let safe = sketch_max(4, buckets)
  { buckets: safe, registers: Array::make(safe, 0) }
}

///|
pub fn hll_add(hll : HyperLogLogLite, value : String) -> HyperLogLogLite {
  let registers = hll.registers
  let hash = sketch_hash(value, 7001)
  let bucket = hash % hll.buckets
  let rank = sketch_rank(hash / hll.buckets)
  if rank > registers[bucket] {
    registers[bucket] = rank
  }
  { buckets: hll.buckets, registers }
}

///|
fn sketch_rank(value : Int) -> Int {
  let mut x = sketch_positive(value)
  let mut rank = 1
  while x > 0 && x % 2 == 0 {
    rank += 1
    x = x / 2
  }
  rank
}

///|
pub fn hll_from_items(items : Array[String], buckets : Int) -> HyperLogLogLite {
  let mut hll = hll_new(buckets)
  for item in items {
    hll = hll_add(hll, item)
  }
  hll
}

///|
pub fn hll_estimate(hll : HyperLogLogLite) -> Double {
  let m = hll.buckets.to_double()
  let mut harmonic = 0.0
  let mut zeros = 0
  for reg in hll.registers {
    if reg == 0 {
      zeros += 1
    }
    harmonic += 1.0 / sketch_pow2(reg)
  }
  let raw = sketch_hll_alpha(hll.buckets) * m * m / harmonic
  if raw <= 2.5 * m && zeros > 0 {
    m * sketch_ln(m / zeros.to_double())
  } else {
    raw
  }
}

///|
fn sketch_hll_alpha(buckets : Int) -> Double {
  if buckets == 16 {
    0.673
  } else if buckets == 32 {
    0.697
  } else if buckets == 64 {
    0.709
  } else {
    0.7213 / (1.0 + 1.079 / buckets.to_double())
  }
}

///|
fn sketch_pow2(exp : Int) -> Double {
  let mut value = 1.0
  for _ in 0..<exp {
    value *= 2.0
  }
  value
}

///|
fn sketch_ln(value : Double) -> Double {
  // Short Taylor-style approximation around 1. Good enough for the small-range
  // correction used in this educational HLL-lite implementation.
  if value <= 0.0 {
    0.0
  } else {
    let y = (value - 1.0) / (value + 1.0)
    let y2 = y * y
    let mut term = y
    let mut sum = 0.0
    let mut denom = 1
    for _ in 0..<12 {
      sum += term / denom.to_double()
      term *= y2
      denom += 2
    }
    2.0 * sum
  }
}

///|
pub(all) struct MinHashSignature {
  seeds : Int
  values : Array[Int]
} derive(Eq, Debug)

///|
pub fn minhash_new(seeds : Int) -> MinHashSignature {
  {
    seeds: sketch_max(1, seeds),
    values: Array::make(sketch_max(1, seeds), 2147483647),
  }
}

///|
pub fn minhash_add(
  signature : MinHashSignature,
  value : String,
) -> MinHashSignature {
  let values = signature.values
  for seed in 0..<signature.seeds {
    let hash = sketch_hash(value, 1009 + seed * 101)
    if hash < values[seed] {
      values[seed] = hash
    }
  }
  { seeds: signature.seeds, values }
}

///|
pub fn minhash_from_items(
  items : Array[String],
  seeds : Int,
) -> MinHashSignature {
  let mut signature = minhash_new(seeds)
  let seen : Array[String] = Array::new()
  for item in items {
    if !sketch_contains(seen, item) {
      seen.push(item)
      signature = minhash_add(signature, item)
    }
  }
  signature
}

///|
pub fn minhash_similarity(
  left : MinHashSignature,
  right : MinHashSignature,
) -> Double {
  let length = sketch_min(left.values.length(), right.values.length())
  if length == 0 {
    return 0.0
  }
  let mut same = 0
  for i in 0..<length {
    if left.values[i] == right.values[i] {
      same += 1
    }
  }
  same.to_double() / length.to_double()
}

///|
pub fn exact_jaccard(left : Array[String], right : Array[String]) -> Double {
  let union : Array[String] = Array::new()
  let intersection : Array[String] = Array::new()
  for item in left {
    if !sketch_contains(union, item) {
      union.push(item)
    }
  }
  for item in right {
    if !sketch_contains(union, item) {
      union.push(item)
    }
    if sketch_contains(left, item) && !sketch_contains(intersection, item) {
      intersection.push(item)
    }
  }
  if union.length() == 0 {
    1.0
  } else {
    intersection.length().to_double() / union.length().to_double()
  }
}

///|
pub(all) struct SketchReport {
  item_count : Int
  unique_count : Int
  hll_estimate : Double
  topk : SpaceSavingTopK
  sampler : ReservoirSampler
} derive(Eq, Debug)

///|
pub fn sketch_report(
  items : Array[String],
  topk_size : Int,
  sample_size : Int,
) -> SketchReport {
  let unique : Array[String] = Array::new()
  for item in items {
    if !sketch_contains(unique, item) {
      unique.push(item)
    }
  }
  {
    item_count: items.length(),
    unique_count: unique.length(),
    hll_estimate: hll_estimate(hll_from_items(items, 64)),
    topk: topk_from_items(items, topk_size),
    sampler: reservoir_from_items(items, sample_size),
  }
}

///|
pub fn sketch_report_markdown(input : String) -> String {
  let items = sketch_split_words(input)
  let report = sketch_report(items, 5, 5)
  let out = StringBuilder()
  out.write_string("# Moon Sketch Report\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| events | " + report.item_count.to_string() + " |\n")
  out.write_string(
    "| exact unique | " + report.unique_count.to_string() + " |\n",
  )
  out.write_string(
    "| hll-lite unique estimate | " +
    sketch_double_text(report.hll_estimate) +
    " |\n\n",
  )
  out.write_string(topk_markdown(report.topk))
  out.write_string("\n")
  out.write_string(reservoir_markdown(report.sampler))
  out.to_string()
}

///|
pub fn sketch_report_json(input : String) -> String {
  let items = sketch_split_words(input)
  let report = sketch_report(items, 5, 5)
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"events\":" + report.item_count.to_string() + ",")
  out.write_string("\"exact_unique\":" + report.unique_count.to_string() + ",")
  out.write_string(
    "\"hll_estimate\":" + sketch_double_text(report.hll_estimate) + ",",
  )
  out.write_string("\"topk\":[")
  for i in 0..<report.topk.items.length() {
    if i > 0 {
      out.write_string(",")
    }
    let item = report.topk.items[i]
    out.write_string(
      "{\"key\":\"" +
      sketch_escape_json(item.key) +
      "\",\"count\":" +
      item.count.to_string() +
      ",\"error\":" +
      item.error.to_string() +
      "}",
    )
  }
  out.write_string("],\"sample\":[")
  for i in 0..<report.sampler.samples.length() {
    if i > 0 {
      out.write_string(",")
    }
    out.write_string(
      "\"" + sketch_escape_json(report.sampler.samples[i]) + "\"",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn parse_events(input : String) -> Array[String] {
  sketch_split_words(input)
}

///|
pub fn jaccard_report(left_input : String, right_input : String) -> String {
  let left = sketch_split_words(left_input)
  let right = sketch_split_words(right_input)
  let exact = exact_jaccard(left, right)
  let estimated = minhash_similarity(
    minhash_from_items(left, 64),
    minhash_from_items(right, 64),
  )
  let out = StringBuilder()
  out.write_string("# MinHash Similarity Report\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| left events | " + left.length().to_string() + " |\n")
  out.write_string("| right events | " + right.length().to_string() + " |\n")
  out.write_string("| exact jaccard | " + sketch_double_text(exact) + " |\n")
  out.write_string(
    "| minhash estimate | " + sketch_double_text(estimated) + " |\n",
  )
  out.to_string()
}
