///|
pub(all) struct TokenProfile {
  total : Int
  unique : Int
  numeric : Int
  alphabetic : Int
  alphanumeric : Int
  mixed : Int
  min_length : Int
  max_length : Int
  average_length : Double
  length_histogram : IntHistogram
  prefix_topk : Array[TopKItem]
} derive(Eq, Debug)

///|
pub fn token_profile_from_text(
  input : String,
  prefix_length : Int,
) -> TokenProfile {
  token_profile(parse_events(input), prefix_length)
}

///|
pub fn token_profile(
  items : Array[String],
  prefix_length : Int,
) -> TokenProfile {
  let counter = exact_counter_from_items(items)
  let lengths : Array[Int] = Array::new()
  let mut numeric = 0
  let mut alphabetic = 0
  let mut alphanumeric = 0
  let mut mixed = 0
  let mut min_length = 0
  let mut max_length = 0
  let mut total_length = 0
  let mut prefixes = exact_counter_new()
  for item in items {
    let length = token_length(item)
    lengths.push(length)
    total_length += length
    if min_length == 0 || length < min_length {
      min_length = length
    }
    if length > max_length {
      max_length = length
    }
    prefixes = exact_counter_add(prefixes, token_prefix(item, prefix_length))
    match token_kind(item) {
      "numeric" => numeric += 1
      "alphabetic" => alphabetic += 1
      "alphanumeric" => alphanumeric += 1
      _ => mixed += 1
    }
  }
  let average = if items.length() == 0 {
    0.0
  } else {
    total_length.to_double() / items.length().to_double()
  }
  {
    total: items.length(),
    unique: exact_counter_unique(counter),
    numeric,
    alphabetic,
    alphanumeric,
    mixed,
    min_length,
    max_length,
    average_length: average,
    length_histogram: histogram_from_values(
      lengths,
      0,
      sketch_max(1, max_length),
      8,
    ),
    prefix_topk: exact_counter_topk(prefixes, 8),
  }
}

///|
pub fn token_profile_markdown(profile : TokenProfile) -> String {
  let out = StringBuilder()
  out.write_string("# Token Profile\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| total | " + profile.total.to_string() + " |\n")
  out.write_string("| unique | " + profile.unique.to_string() + " |\n")
  out.write_string("| numeric | " + profile.numeric.to_string() + " |\n")
  out.write_string("| alphabetic | " + profile.alphabetic.to_string() + " |\n")
  out.write_string(
    "| alphanumeric | " + profile.alphanumeric.to_string() + " |\n",
  )
  out.write_string("| mixed | " + profile.mixed.to_string() + " |\n")
  out.write_string("| min length | " + profile.min_length.to_string() + " |\n")
  out.write_string("| max length | " + profile.max_length.to_string() + " |\n")
  out.write_string(
    "| average length | " +
    sketch_double_text(profile.average_length) +
    " |\n\n",
  )
  out.write_string("## Length Histogram\n\n")
  out.write_string(histogram_markdown(profile.length_histogram))
  out.write_string("\n## Prefix Top-K\n\n")
  out.write_string("| prefix | count |\n| --- | ---: |\n")
  for item in profile.prefix_topk {
    out.write_string("| " + item.key + " | " + item.count.to_string() + " |\n")
  }
  out.to_string()
}

///|
pub fn token_profile_json(profile : TokenProfile) -> String {
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"total\":" + profile.total.to_string())
  out.write_string(",\"unique\":" + profile.unique.to_string())
  out.write_string(",\"numeric\":" + profile.numeric.to_string())
  out.write_string(",\"alphabetic\":" + profile.alphabetic.to_string())
  out.write_string(",\"alphanumeric\":" + profile.alphanumeric.to_string())
  out.write_string(",\"mixed\":" + profile.mixed.to_string())
  out.write_string(",\"min_length\":" + profile.min_length.to_string())
  out.write_string(",\"max_length\":" + profile.max_length.to_string())
  out.write_string(
    ",\"average_length\":" + sketch_double_text(profile.average_length),
  )
  out.write_string(",\"prefix_topk\":[")
  for i in 0..<profile.prefix_topk.length() {
    if i > 0 {
      out.write_string(",")
    }
    let item = profile.prefix_topk[i]
    out.write_string(
      "{\"prefix\":\"" +
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
pub fn token_profile_recommendations(
  profile : TokenProfile,
) -> Array[SketchRecommendation] {
  let items : Array[SketchRecommendation] = Array::new()
  if profile.total == 0 {
    items.push(
      sketch_recommendation(
        "warning", "empty-token-profile", "No tokens to profile", "The input stream did not contain parseable tokens.",
        "Check separators or run the parser against a smaller sample.",
      ),
    )
    return items
  }
  if profile.unique * 2 > profile.total {
    items.push(
      sketch_recommendation(
        "info", "high-cardinality", "High-cardinality stream", "More than half of the observed tokens are unique.",
        "Use HyperLogLog and MinHash outputs to monitor uniqueness cheaply.",
      ),
    )
  }
  if profile.max_length > profile.average_length.to_int() * 4 + 8 {
    items.push(
      sketch_recommendation(
        "warning", "long-token-tail", "A long-token tail exists", "The longest token is much larger than the average length.",
        "Inspect whether IDs, URLs, or stack traces should be normalized first.",
      ),
    )
  }
  if profile.mixed > profile.alphabetic + profile.numeric + profile.alphanumeric {
    items.push(
      sketch_recommendation(
        "info", "mixed-token-dominates", "Mixed tokens dominate", "Most tokens contain punctuation or non-alphanumeric characters.",
        "Consider extracting a stable key before building sketches.",
      ),
    )
  }
  if items.length() == 0 {
    items.push(
      sketch_recommendation(
        "info", "token-profile-normal", "Token profile looks regular", "No strong high-cardinality or long-tail signal was detected.",
        "Keep this profile as a fixture for future regression checks.",
      ),
    )
  }
  items
}

///|
fn token_kind(value : String) -> String {
  let mut digits = 0
  let mut letters = 0
  let mut other = 0
  for ch in value.iter() {
    if token_is_digit(ch) {
      digits += 1
    } else if token_is_letter(ch) {
      letters += 1
    } else {
      other += 1
    }
  }
  if other == 0 && digits > 0 && letters == 0 {
    "numeric"
  } else if other == 0 && letters > 0 && digits == 0 {
    "alphabetic"
  } else if other == 0 && letters > 0 && digits > 0 {
    "alphanumeric"
  } else {
    "mixed"
  }
}

///|
fn token_prefix(value : String, size : Int) -> String {
  let limit = sketch_max(1, size)
  let out = StringBuilder()
  let mut seen = 0
  for ch in value.iter() {
    if seen < limit {
      out.write_char(ch)
      seen += 1
    }
  }
  out.to_string()
}

///|
fn token_length(value : String) -> Int {
  let mut length = 0
  for _ in value.iter() {
    length += 1
  }
  length
}

///|
fn token_is_digit(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 48 && code <= 57
}

///|
fn token_is_letter(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}
