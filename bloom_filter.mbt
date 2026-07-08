///|
/// Compact membership sketch with deterministic hashes.
pub(all) struct BloomFilter {
  size : Int
  hashes : Int
  inserted : Int
  bits : Array[Bool]
} derive(Eq, Debug)

///|
pub(all) struct BloomStats {
  size : Int
  hashes : Int
  inserted : Int
  set_bits : Int
  fill_ratio : Double
  estimated_false_positive_rate : Double
} derive(Eq, Debug)

///|
pub fn bloom_new(size : Int, hashes : Int) -> BloomFilter {
  let safe_size = sketch_max(8, size)
  let safe_hashes = sketch_max(1, hashes)
  {
    size: safe_size,
    hashes: safe_hashes,
    inserted: 0,
    bits: Array::make(safe_size, false),
  }
}

///|
pub fn bloom_add(filter : BloomFilter, value : String) -> BloomFilter {
  let bits = filter.bits
  for i in 0..<filter.hashes {
    bits[bloom_index(value, i, filter.size)] = true
  }
  {
    size: filter.size,
    hashes: filter.hashes,
    inserted: filter.inserted + 1,
    bits,
  }
}

///|
pub fn bloom_add_many(
  filter : BloomFilter,
  values : Array[String],
) -> BloomFilter {
  let mut next = filter
  for value in values {
    next = bloom_add(next, value)
  }
  next
}

///|
pub fn bloom_from_items(
  values : Array[String],
  size : Int,
  hashes : Int,
) -> BloomFilter {
  bloom_add_many(bloom_new(size, hashes), values)
}

///|
pub fn bloom_might_contain(filter : BloomFilter, value : String) -> Bool {
  for i in 0..<filter.hashes {
    if !filter.bits[bloom_index(value, i, filter.size)] {
      return false
    }
  }
  true
}

///|
pub fn bloom_set_bits(filter : BloomFilter) -> Int {
  let mut count = 0
  for bit in filter.bits {
    if bit {
      count += 1
    }
  }
  count
}

///|
pub fn bloom_stats(filter : BloomFilter) -> BloomStats {
  let set_bits = bloom_set_bits(filter)
  let fill_ratio = set_bits.to_double() / filter.size.to_double()
  {
    size: filter.size,
    hashes: filter.hashes,
    inserted: filter.inserted,
    set_bits,
    fill_ratio,
    estimated_false_positive_rate: bloom_pow(fill_ratio, filter.hashes),
  }
}

///|
pub fn bloom_markdown(filter : BloomFilter, probes : Array[String]) -> String {
  let stats = bloom_stats(filter)
  let out = StringBuilder()
  out.write_string("# Bloom Filter Report\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| bits | " + stats.size.to_string() + " |\n")
  out.write_string("| hash functions | " + stats.hashes.to_string() + " |\n")
  out.write_string("| inserted | " + stats.inserted.to_string() + " |\n")
  out.write_string("| set bits | " + stats.set_bits.to_string() + " |\n")
  out.write_string(
    "| fill ratio | " + sketch_double_text(stats.fill_ratio) + " |\n",
  )
  out.write_string(
    "| estimated false positive rate | " +
    sketch_double_text(stats.estimated_false_positive_rate) +
    " |\n\n",
  )
  out.write_string("| value | might contain |\n| --- | --- |\n")
  for probe in probes {
    out.write_string(
      "| " +
      probe +
      " | " +
      bloom_might_contain(filter, probe).to_string() +
      " |\n",
    )
  }
  out.to_string()
}

///|
pub fn bloom_json(filter : BloomFilter) -> String {
  let stats = bloom_stats(filter)
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"size\":" + stats.size.to_string())
  out.write_string(",\"hashes\":" + stats.hashes.to_string())
  out.write_string(",\"inserted\":" + stats.inserted.to_string())
  out.write_string(",\"set_bits\":" + stats.set_bits.to_string())
  out.write_string(",\"fill_ratio\":" + sketch_double_text(stats.fill_ratio))
  out.write_string(
    ",\"estimated_false_positive_rate\":" +
    sketch_double_text(stats.estimated_false_positive_rate),
  )
  out.write_string("}")
  out.to_string()
}

///|
fn bloom_index(value : String, salt : Int, size : Int) -> Int {
  sketch_hash(value, 9109 + salt * 7919) % size
}

///|
fn bloom_pow(base : Double, exp : Int) -> Double {
  let mut value = 1.0
  for _ in 0..<exp {
    value *= base
  }
  value
}

///|
pub(all) struct ExactCounter {
  keys : Array[String]
  counts : Array[Int]
  total : Int
} derive(Eq, Debug)

///|
pub fn exact_counter_new() -> ExactCounter {
  { keys: [], counts: [], total: 0 }
}

///|
pub fn exact_counter_add(counter : ExactCounter, key : String) -> ExactCounter {
  let keys = counter.keys
  let counts = counter.counts
  match exact_counter_index(keys, key) {
    Some(index) => counts[index] += 1
    None => {
      keys.push(key)
      counts.push(1)
    }
  }
  { keys, counts, total: counter.total + 1 }
}

///|
pub fn exact_counter_from_items(items : Array[String]) -> ExactCounter {
  let mut counter = exact_counter_new()
  for item in items {
    counter = exact_counter_add(counter, item)
  }
  counter
}

///|
pub fn exact_counter_count(counter : ExactCounter, key : String) -> Int {
  match exact_counter_index(counter.keys, key) {
    Some(index) => counter.counts[index]
    None => 0
  }
}

///|
pub fn exact_counter_unique(counter : ExactCounter) -> Int {
  counter.keys.length()
}

///|
pub fn exact_counter_topk(counter : ExactCounter, k : Int) -> Array[TopKItem] {
  let items : Array[TopKItem] = Array::new()
  for i in 0..<counter.keys.length() {
    items.push({ key: counter.keys[i], count: counter.counts[i], error: 0 })
  }
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
  let limit = sketch_min(sketch_max(0, k), items.length())
  let out : Array[TopKItem] = Array::new()
  for i in 0..<limit {
    out.push(items[i])
  }
  out
}

///|
pub fn exact_counter_markdown(counter : ExactCounter, k : Int) -> String {
  let out = StringBuilder()
  out.write_string("# Exact Counter Summary\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| total | " + counter.total.to_string() + " |\n")
  out.write_string("| unique | " + counter.keys.length().to_string() + " |\n\n")
  out.write_string("| key | count |\n| --- | ---: |\n")
  for item in exact_counter_topk(counter, k) {
    out.write_string("| " + item.key + " | " + item.count.to_string() + " |\n")
  }
  out.to_string()
}

///|
fn exact_counter_index(keys : Array[String], key : String) -> Int? {
  for i in 0..<keys.length() {
    if keys[i] == key {
      return Some(i)
    }
  }
  None
}
