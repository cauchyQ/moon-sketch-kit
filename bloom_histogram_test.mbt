///|
test "bloom filter accepts inserted values" {
  let filter = bloom_from_items(["alice", "bob", "alice"], 64, 3)
  inspect(bloom_might_contain(filter, "alice"), content="true")
  inspect(bloom_might_contain(filter, "bob"), content="true")
  inspect(filter.inserted, content="3")
}

///|
test "bloom stats report fill ratio" {
  let filter = bloom_from_items(["a", "b", "c"], 64, 3)
  let stats = bloom_stats(filter)
  inspect(stats.size, content="64")
  inspect(stats.hashes, content="3")
  inspect(stats.set_bits > 0, content="true")
  inspect(stats.fill_ratio > 0.0, content="true")
}

///|
test "bloom markdown renders probes" {
  let report = bloom_markdown(bloom_from_items(["a", "b"], 32, 2), ["a", "z"])
  inspect(report.contains("# Bloom Filter Report"), content="true")
  inspect(report.contains("| a | true |"), content="true")
}

///|
test "exact counter tracks totals and topk" {
  let counter = exact_counter_from_items(["a", "b", "a", "c", "a", "b"])
  inspect(counter.total, content="6")
  inspect(exact_counter_unique(counter), content="3")
  inspect(exact_counter_count(counter, "a"), content="3")
  let top = exact_counter_topk(counter, 2)
  inspect(top.length(), content="2")
  inspect(top[0].key, content="a")
}

///|
test "histogram buckets values into ranges" {
  let histogram = histogram_from_values([1, 2, 5, 8, 9, 20], 0, 10, 5)
  inspect(histogram.total, content="6")
  inspect(histogram.overflow, content="1")
  let buckets = histogram_buckets(histogram)
  inspect(buckets.length(), content="5")
  inspect(buckets[0].count, content="1")
}

///|
test "histogram approximate percentile returns bucket midpoint" {
  let histogram = histogram_from_values([1, 2, 3, 8, 9, 10], 0, 10, 5)
  let p50 = histogram_approx_percentile(histogram, 50)
  inspect(p50 != None, content="true")
}

///|
test "histogram markdown and json render" {
  let histogram = histogram_from_text("1 2 3 8 9 bad", 0, 10, 5)
  let markdown = histogram_markdown(histogram)
  let json = histogram_json(histogram)
  inspect(markdown.contains("# Histogram Report"), content="true")
  inspect(markdown.contains("| bucket | range | count | bar |"), content="true")
  inspect(json.contains("\"buckets\""), content="true")
}
