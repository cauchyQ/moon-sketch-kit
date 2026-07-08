///|
/// Exact-backed quantile summary for small to medium samples.
///
/// It uses the same reporting interface that a future approximate quantile
/// sketch can keep, so examples and CI workflows do not need to change.
pub(all) struct QuantileSummary {
  values : Array[Int]
  sorted : Bool
} derive(Eq, Debug)

///|
pub(all) struct NumericSummary {
  count : Int
  min : Int?
  max : Int?
  sum : Int
  mean : Double?
  p50 : Int?
  p90 : Int?
  p99 : Int?
} derive(Eq, Debug)

///|
pub fn quantile_new() -> QuantileSummary {
  { values: [], sorted: true }
}

///|
pub fn quantile_add(summary : QuantileSummary, value : Int) -> QuantileSummary {
  let values = summary.values
  values.push(value)
  { values, sorted: false }
}

///|
pub fn quantile_from_values(values : Array[Int]) -> QuantileSummary {
  let mut summary = quantile_new()
  for value in values {
    summary = quantile_add(summary, value)
  }
  quantile_sorted(summary)
}

///|
pub fn quantile_from_text(input : String) -> QuantileSummary {
  let values : Array[Int] = Array::new()
  for token in parse_events(input) {
    match quantile_parse_int(token) {
      Some(value) => values.push(value)
      None => ()
    }
  }
  quantile_from_values(values)
}

///|
pub fn quantile_sorted(summary : QuantileSummary) -> QuantileSummary {
  if summary.sorted {
    return summary
  }
  let values = summary.values
  for i in 0..<values.length() {
    for j in (i + 1)..<values.length() {
      if values[j] < values[i] {
        let tmp = values[i]
        values[i] = values[j]
        values[j] = tmp
      }
    }
  }
  { values, sorted: true }
}

///|
pub fn quantile_value(summary : QuantileSummary, percentile : Int) -> Int? {
  let sorted = quantile_sorted(summary)
  if sorted.values.length() == 0 {
    return None
  }
  let pct = if percentile < 0 {
    0
  } else if percentile > 100 {
    100
  } else {
    percentile
  }
  let index = ((sorted.values.length() - 1) * pct + 50) / 100
  Some(sorted.values[index])
}

///|
pub fn numeric_summary(summary : QuantileSummary) -> NumericSummary {
  let sorted = quantile_sorted(summary)
  let count = sorted.values.length()
  if count == 0 {
    return {
      count,
      min: None,
      max: None,
      sum: 0,
      mean: None,
      p50: None,
      p90: None,
      p99: None,
    }
  }
  let mut sum = 0
  for value in sorted.values {
    sum += value
  }
  {
    count,
    min: Some(sorted.values[0]),
    max: Some(sorted.values[count - 1]),
    sum,
    mean: Some(sum.to_double() / count.to_double()),
    p50: quantile_value(sorted, 50),
    p90: quantile_value(sorted, 90),
    p99: quantile_value(sorted, 99),
  }
}

///|
pub fn numeric_summary_markdown(summary : QuantileSummary) -> String {
  let stats = numeric_summary(summary)
  let out = StringBuilder()
  out.write_string("# Numeric Summary\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string("| count | " + stats.count.to_string() + " |\n")
  out.write_string("| min | " + quantile_optional_int(stats.min) + " |\n")
  out.write_string("| max | " + quantile_optional_int(stats.max) + " |\n")
  out.write_string("| sum | " + stats.sum.to_string() + " |\n")
  out.write_string("| mean | " + quantile_optional_double(stats.mean) + " |\n")
  out.write_string("| p50 | " + quantile_optional_int(stats.p50) + " |\n")
  out.write_string("| p90 | " + quantile_optional_int(stats.p90) + " |\n")
  out.write_string("| p99 | " + quantile_optional_int(stats.p99) + " |\n")
  out.to_string()
}

///|
pub fn numeric_summary_json(summary : QuantileSummary) -> String {
  let stats = numeric_summary(summary)
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"count\":" + stats.count.to_string())
  out.write_string(",\"min\":" + quantile_json_int(stats.min))
  out.write_string(",\"max\":" + quantile_json_int(stats.max))
  out.write_string(",\"sum\":" + stats.sum.to_string())
  out.write_string(",\"mean\":" + quantile_json_double(stats.mean))
  out.write_string(",\"p50\":" + quantile_json_int(stats.p50))
  out.write_string(",\"p90\":" + quantile_json_int(stats.p90))
  out.write_string(",\"p99\":" + quantile_json_int(stats.p99))
  out.write_string("}")
  out.to_string()
}

///|
pub fn quantile_compare_markdown(
  baseline : QuantileSummary,
  candidate : QuantileSummary,
) -> String {
  let base = numeric_summary(baseline)
  let cand = numeric_summary(candidate)
  let out = StringBuilder()
  out.write_string("# Quantile Drift Report\n\n")
  out.write_string(
    "| metric | baseline | candidate | delta |\n| --- | ---: | ---: | ---: |\n",
  )
  quantile_compare_row(out, "count", base.count, cand.count)
  quantile_compare_option_row(out, "min", base.min, cand.min)
  quantile_compare_option_row(out, "max", base.max, cand.max)
  quantile_compare_option_row(out, "p50", base.p50, cand.p50)
  quantile_compare_option_row(out, "p90", base.p90, cand.p90)
  quantile_compare_option_row(out, "p99", base.p99, cand.p99)
  out.to_string()
}

///|
fn quantile_compare_row(
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

///|
fn quantile_compare_option_row(
  out : StringBuilder,
  label : String,
  baseline : Int?,
  candidate : Int?,
) -> Unit {
  match (baseline, candidate) {
    (Some(b), Some(c)) => quantile_compare_row(out, label, b, c)
    _ =>
      out.write_string(
        "| " +
        label +
        " | " +
        quantile_optional_int(baseline) +
        " | " +
        quantile_optional_int(candidate) +
        " |  |\n",
      )
  }
}

///|
fn quantile_optional_int(value : Int?) -> String {
  match value {
    Some(v) => v.to_string()
    None => ""
  }
}

///|
fn quantile_optional_double(value : Double?) -> String {
  match value {
    Some(v) => sketch_double_text(v)
    None => ""
  }
}

///|
fn quantile_json_int(value : Int?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "null"
  }
}

///|
fn quantile_json_double(value : Double?) -> String {
  match value {
    Some(v) => sketch_double_text(v)
    None => "null"
  }
}

///|
fn quantile_parse_int(token : String) -> Int? {
  try @string.parse_int(token) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}
