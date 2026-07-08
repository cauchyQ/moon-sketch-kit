///|
fn main {
  println(sketch_cli_run(sketch_drop_program_name(@env.args())))
}

///|
fn sketch_cli_run(args : Array[String]) -> String {
  if args.length() == 0 {
    return sketch_cli_help()
  }
  match args[0] {
    "help" | "--help" | "-h" => sketch_cli_help()
    "version" | "--version" => "moon-sketch-kit 0.1.0"
    "report" => sketch_cli_report(args)
    "json" => sketch_cli_json(args)
    "topk" => sketch_cli_topk(args)
    "count" => sketch_cli_count(args)
    "sample" => sketch_cli_sample(args)
    "similarity" => sketch_cli_similarity(args)
    "bloom" => sketch_cli_bloom(args)
    "histogram" => sketch_cli_histogram(args)
    "quantile" => sketch_cli_quantile(args)
    "drift" => sketch_cli_drift(args)
    "gate" => sketch_cli_gate(args)
    "weighted" => sketch_cli_weighted(args)
    "windows" => sketch_cli_windows(args)
    "timeline" => sketch_cli_timeline(args)
    "profile" => sketch_cli_profile(args)
    "budget" => sketch_cli_budget(args)
    other => "Unknown command: " + other + "\n\n" + sketch_cli_help()
  }
}

///|
fn sketch_cli_help() -> String {
  (
    #|moon-sketch-kit - streaming sketch utilities for MoonBit
    #|
    #|Usage:
    #|  moon run cmd/main -- report <events>
    #|  moon run cmd/main -- json <events>
    #|  moon run cmd/main -- topk <events> [k]
    #|  moon run cmd/main -- count <events> <key>
    #|  moon run cmd/main -- sample <events> [size]
    #|  moon run cmd/main -- similarity <left-events> <right-events>
    #|  moon run cmd/main -- bloom <events>
    #|  moon run cmd/main -- histogram <numbers> [min] [max] [buckets]
    #|  moon run cmd/main -- quantile <numbers>
    #|  moon run cmd/main -- drift <baseline-events> <candidate-events>
    #|  moon run cmd/main -- gate <baseline-events> <candidate-events>
    #|  moon run cmd/main -- weighted <key:weight-events>
    #|  moon run cmd/main -- windows <events|events|events>
    #|  moon run cmd/main -- timeline <events|events|events>
    #|  moon run cmd/main -- profile <events> [prefix-length]
    #|  moon run cmd/main -- budget <events> [accuracy-level]
    #|
    #|Events can be separated by spaces, commas, tabs, or newlines.
    #|Window commands also accept `|` or `;` as window separators.
  )
}

///|
fn sketch_cli_report(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => @sketch.sketch_report_markdown(sketch_decode_newlines(input))
    None => "Usage: moon run cmd/main -- report <events>"
  }
}

///|
fn sketch_cli_json(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => @sketch.sketch_report_json(sketch_decode_newlines(input))
    None => "Usage: moon run cmd/main -- json <events>"
  }
}

///|
fn sketch_cli_topk(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => {
      let k = sketch_cli_int_arg(args, 2, 5)
      @sketch.topk_markdown(
        @sketch.topk_from_items(
          @sketch.parse_events(sketch_decode_newlines(input)),
          k,
        ),
      )
    }
    None => "Usage: moon run cmd/main -- topk <events> [k]"
  }
}

///|
fn sketch_cli_count(args : Array[String]) -> String {
  match (sketch_cli_arg(args, 1), sketch_cli_arg(args, 2)) {
    (Some(input), Some(key)) => {
      let sketch = @sketch.count_min_from_items(
        @sketch.parse_events(sketch_decode_newlines(input)),
        64,
        5,
      )
      @sketch.count_min_summary_markdown(sketch, [key])
    }
    _ => "Usage: moon run cmd/main -- count <events> <key>"
  }
}

///|
fn sketch_cli_sample(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => {
      let size = sketch_cli_int_arg(args, 2, 5)
      @sketch.reservoir_markdown(
        @sketch.reservoir_from_items(
          @sketch.parse_events(sketch_decode_newlines(input)),
          size,
        ),
      )
    }
    None => "Usage: moon run cmd/main -- sample <events> [size]"
  }
}

///|
fn sketch_cli_similarity(args : Array[String]) -> String {
  match (sketch_cli_arg(args, 1), sketch_cli_arg(args, 2)) {
    (Some(left), Some(right)) =>
      @sketch.jaccard_report(
        sketch_decode_newlines(left),
        sketch_decode_newlines(right),
      )
    _ => "Usage: moon run cmd/main -- similarity <left-events> <right-events>"
  }
}

///|
fn sketch_cli_bloom(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => {
      let events = @sketch.parse_events(sketch_decode_newlines(input))
      @sketch.bloom_markdown(@sketch.bloom_from_items(events, 512, 4), events)
    }
    None => "Usage: moon run cmd/main -- bloom <events>"
  }
}

///|
fn sketch_cli_histogram(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) =>
      @sketch.histogram_markdown(
        @sketch.histogram_from_text(
          sketch_decode_newlines(input),
          sketch_cli_int_arg(args, 2, 0),
          sketch_cli_int_arg(args, 3, 100),
          sketch_cli_int_arg(args, 4, 10),
        ),
      )
    None =>
      "Usage: moon run cmd/main -- histogram <numbers> [min] [max] [buckets]"
  }
}

///|
fn sketch_cli_quantile(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) =>
      @sketch.numeric_summary_markdown(
        @sketch.quantile_from_text(sketch_decode_newlines(input)),
      )
    None => "Usage: moon run cmd/main -- quantile <numbers>"
  }
}

///|
fn sketch_cli_drift(args : Array[String]) -> String {
  match (sketch_cli_arg(args, 1), sketch_cli_arg(args, 2)) {
    (Some(baseline), Some(candidate)) =>
      @sketch.stream_drift_markdown(
        "baseline",
        sketch_decode_newlines(baseline),
        "candidate",
        sketch_decode_newlines(candidate),
      )
    _ =>
      "Usage: moon run cmd/main -- drift <baseline-events> <candidate-events>"
  }
}

///|
fn sketch_cli_gate(args : Array[String]) -> String {
  match (sketch_cli_arg(args, 1), sketch_cli_arg(args, 2)) {
    (Some(baseline), Some(candidate)) => {
      let report = @sketch.evaluate_stream_gate_default(
        sketch_decode_newlines(baseline),
        sketch_decode_newlines(candidate),
      )
      @sketch.sketch_gate_markdown(report) +
      "\n" +
      @sketch.recommendations_markdown(
        @sketch.recommendations_from_gate(report),
      )
    }
    _ => "Usage: moon run cmd/main -- gate <baseline-events> <candidate-events>"
  }
}

///|
fn sketch_cli_weighted(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => {
      let summary = @sketch.weighted_summary_from_text(
        sketch_decode_newlines(input),
      )
      @sketch.weighted_summary_markdown(summary) +
      "\n" +
      @sketch.recommendations_markdown(
        @sketch.recommendations_from_weighted(summary),
      )
    }
    None => "Usage: moon run cmd/main -- weighted <key:weight-events>"
  }
}

///|
fn sketch_cli_windows(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => {
      let report = @sketch.windowed_report_from_text(
        sketch_decode_newlines(input),
      )
      @sketch.windowed_report_markdown(report) +
      "\n" +
      @sketch.recommendations_markdown(
        @sketch.recommendations_from_windowed(report),
      )
    }
    None => "Usage: moon run cmd/main -- windows <events|events|events>"
  }
}

///|
fn sketch_cli_timeline(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) =>
      @sketch.windowed_topk_timeline_markdown(
        @sketch.windowed_report_from_text(sketch_decode_newlines(input)),
      )
    None => "Usage: moon run cmd/main -- timeline <events|events|events>"
  }
}

///|
fn sketch_cli_profile(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => {
      let profile = @sketch.token_profile_from_text(
        sketch_decode_newlines(input),
        sketch_cli_int_arg(args, 2, 3),
      )
      @sketch.token_profile_markdown(profile) +
      "\n" +
      @sketch.recommendations_markdown(
        @sketch.token_profile_recommendations(profile),
      )
    }
    None => "Usage: moon run cmd/main -- profile <events> [prefix-length]"
  }
}

///|
fn sketch_cli_budget(args : Array[String]) -> String {
  match sketch_cli_arg(args, 1) {
    Some(input) => {
      let plan = @sketch.sketch_budget_from_text(
        sketch_decode_newlines(input),
        sketch_cli_int_arg(args, 2, 5),
      )
      @sketch.sketch_budget_markdown(plan) +
      "\n" +
      @sketch.recommendations_markdown(
        @sketch.sketch_budget_recommendations(plan),
      )
    }
    None => "Usage: moon run cmd/main -- budget <events> [accuracy-level]"
  }
}

///|
fn sketch_cli_arg(args : Array[String], index : Int) -> String? {
  if args.length() > index {
    Some(args[index])
  } else {
    None
  }
}

///|
fn sketch_cli_int_arg(args : Array[String], index : Int, fallback : Int) -> Int {
  match sketch_cli_arg(args, index) {
    Some(value) =>
      try @string.parse_int(value) catch {
        _ => fallback
      } noraise {
        parsed => parsed
      }
    None => fallback
  }
}

///|
fn sketch_decode_newlines(value : String) -> String {
  let out = StringBuilder()
  let mut slash = false
  for ch in value.iter() {
    if slash {
      if ch == 'n' {
        out.write_char('\n')
      } else if ch == 't' {
        out.write_char('\t')
      } else {
        out.write_char('\\')
        out.write_char(ch)
      }
      slash = false
    } else if ch == '\\' {
      slash = true
    } else {
      out.write_char(ch)
    }
  }
  if slash {
    out.write_char('\\')
  }
  out.to_string()
}

///|
fn sketch_drop_program_name(args : Array[String]) -> Array[String] {
  if args.length() <= 1 {
    []
  } else {
    let rest : Array[String] = Array::new()
    for i in 1..<args.length() {
      rest.push(args[i])
    }
    rest
  }
}
