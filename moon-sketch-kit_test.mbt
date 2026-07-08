///|
test "count min sketch estimates repeated events" {
  let sketch = count_min_from_items(
    ["login", "view", "login", "buy", "login"],
    32,
    4,
  )
  inspect(count_min_estimate(sketch, "login"), content="3")
  inspect(count_min_estimate(sketch, "view"), content="1")
  inspect(sketch.total, content="5")
}

///|
test "topk keeps heavy hitters" {
  let topk = topk_from_items(["a", "b", "a", "c", "a", "b"], 2)
  inspect(topk.items.length(), content="2")
  inspect(topk.items[0].key, content="a")
  inspect(topk.items[0].count, content="3")
}

///|
test "reservoir sample is deterministic and bounded" {
  let sampler = reservoir_from_items(["a", "b", "c", "d", "e", "f"], 3)
  inspect(sampler.seen, content="6")
  inspect(sampler.samples.length(), content="3")
}

///|
test "hll estimate tracks unique count directionally" {
  let hll = hll_from_items(["a", "b", "c", "a", "b", "d"], 64)
  let estimate = hll_estimate(hll)
  inspect(estimate > 2.0, content="true")
  inspect(estimate < 8.0, content="true")
}

///|
test "minhash similarity detects overlap" {
  let left = minhash_from_items(["a", "b", "c", "d"], 64)
  let right = minhash_from_items(["a", "b", "x", "y"], 64)
  let estimate = minhash_similarity(left, right)
  inspect(estimate > 0.0, content="true")
  inspect(estimate < 1.0, content="true")
}

///|
test "exact jaccard handles empty and overlapping sets" {
  inspect(exact_jaccard([], []), content="1")
  inspect(exact_jaccard(["a", "b"], ["b", "c"]) > 0.3, content="true")
  inspect(exact_jaccard(["a", "b"], ["b", "c"]) < 0.4, content="true")
}

///|
test "report markdown includes key sections" {
  let markdown = sketch_report_markdown("login view login buy login view")
  inspect(markdown.contains("# Moon Sketch Report"), content="true")
  inspect(markdown.contains("# Space-Saving Top-K"), content="true")
  inspect(markdown.contains("# Reservoir Sample"), content="true")
  inspect(markdown.contains("| login | 3 | 0 |"), content="true")
}

///|
test "report json includes topk and sample" {
  let json = sketch_report_json("login view login")
  inspect(json.contains("\"events\":3"), content="true")
  inspect(json.contains("\"exact_unique\":2"), content="true")
  inspect(json.contains("\"topk\""), content="true")
  inspect(json.contains("\"sample\""), content="true")
}

///|
test "jaccard report renders exact and estimated values" {
  let report = jaccard_report("a b c", "b c d")
  inspect(report.contains("# MinHash Similarity Report"), content="true")
  inspect(report.contains("| left events | 3 |"), content="true")
  inspect(report.contains("| right events | 3 |"), content="true")
}
