///|
pub(all) struct SketchBudgetPlan {
  expected_events : Int
  expected_unique : Int
  accuracy_level : Int
  count_min_width : Int
  count_min_depth : Int
  bloom_bits : Int
  bloom_hashes : Int
  hll_buckets : Int
  topk_capacity : Int
  reservoir_size : Int
  estimated_cells : Int
} derive(Eq, Debug)

///|
pub fn sketch_budget_from_text(
  input : String,
  accuracy_level : Int,
) -> SketchBudgetPlan {
  let events = parse_events(input)
  let counter = exact_counter_from_items(events)
  sketch_budget_plan(
    events.length(),
    exact_counter_unique(counter),
    accuracy_level,
  )
}

///|
pub fn sketch_budget_plan(
  expected_events : Int,
  expected_unique : Int,
  accuracy_level : Int,
) -> SketchBudgetPlan {
  let events = sketch_max(0, expected_events)
  let unique = sketch_max(0, expected_unique)
  let level = sketch_budget_clamp(accuracy_level, 1, 10)
  let width = sketch_next_power_of_two(sketch_max(32, unique * level + 31))
  let depth = sketch_budget_clamp(2 + level / 2, 3, 8)
  let bloom_bits = sketch_next_power_of_two(sketch_max(64, unique * level * 8))
  let bloom_hashes = sketch_budget_clamp(2 + level / 2, 2, 8)
  let hll_buckets = sketch_next_power_of_two(
    sketch_budget_clamp(level * 16, 16, 256),
  )
  let topk = sketch_budget_clamp(unique / 10 + level, 5, 100)
  let reservoir = sketch_budget_clamp(level * 10 + events / 100, 10, 250)
  {
    expected_events: events,
    expected_unique: unique,
    accuracy_level: level,
    count_min_width: width,
    count_min_depth: depth,
    bloom_bits,
    bloom_hashes,
    hll_buckets,
    topk_capacity: topk,
    reservoir_size: reservoir,
    estimated_cells: width * depth +
    bloom_bits +
    hll_buckets +
    topk * 3 +
    reservoir,
  }
}

///|
pub fn sketch_budget_markdown(plan : SketchBudgetPlan) -> String {
  let out = StringBuilder()
  out.write_string("# Sketch Budget Plan\n\n")
  out.write_string("| metric | value |\n| --- | ---: |\n")
  out.write_string(
    "| expected events | " + plan.expected_events.to_string() + " |\n",
  )
  out.write_string(
    "| expected unique | " + plan.expected_unique.to_string() + " |\n",
  )
  out.write_string(
    "| accuracy level | " + plan.accuracy_level.to_string() + " |\n",
  )
  out.write_string(
    "| estimated cells | " + plan.estimated_cells.to_string() + " |\n\n",
  )
  out.write_string("## Suggested Parameters\n\n")
  out.write_string("| sketch | parameter | value |\n| --- | --- | ---: |\n")
  out.write_string(
    "| Count-Min | width | " + plan.count_min_width.to_string() + " |\n",
  )
  out.write_string(
    "| Count-Min | depth | " + plan.count_min_depth.to_string() + " |\n",
  )
  out.write_string("| Bloom | bits | " + plan.bloom_bits.to_string() + " |\n")
  out.write_string(
    "| Bloom | hashes | " + plan.bloom_hashes.to_string() + " |\n",
  )
  out.write_string(
    "| HLL-lite | buckets | " + plan.hll_buckets.to_string() + " |\n",
  )
  out.write_string(
    "| Space-Saving | capacity | " + plan.topk_capacity.to_string() + " |\n",
  )
  out.write_string(
    "| Reservoir | size | " + plan.reservoir_size.to_string() + " |\n",
  )
  out.to_string()
}

///|
pub fn sketch_budget_json(plan : SketchBudgetPlan) -> String {
  let out = StringBuilder()
  out.write_string("{")
  out.write_string("\"expected_events\":" + plan.expected_events.to_string())
  out.write_string(",\"expected_unique\":" + plan.expected_unique.to_string())
  out.write_string(",\"accuracy_level\":" + plan.accuracy_level.to_string())
  out.write_string(",\"count_min_width\":" + plan.count_min_width.to_string())
  out.write_string(",\"count_min_depth\":" + plan.count_min_depth.to_string())
  out.write_string(",\"bloom_bits\":" + plan.bloom_bits.to_string())
  out.write_string(",\"bloom_hashes\":" + plan.bloom_hashes.to_string())
  out.write_string(",\"hll_buckets\":" + plan.hll_buckets.to_string())
  out.write_string(",\"topk_capacity\":" + plan.topk_capacity.to_string())
  out.write_string(",\"reservoir_size\":" + plan.reservoir_size.to_string())
  out.write_string(",\"estimated_cells\":" + plan.estimated_cells.to_string())
  out.write_string("}")
  out.to_string()
}

///|
pub fn sketch_budget_recommendations(
  plan : SketchBudgetPlan,
) -> Array[SketchRecommendation] {
  let items : Array[SketchRecommendation] = Array::new()
  if plan.expected_events == 0 {
    items.push(
      sketch_recommendation(
        "warning", "empty-budget-input", "Budget is based on empty input", "No events were observed when deriving sketch parameters.",
        "Run the planner on a representative sample before publishing defaults.",
      ),
    )
    return items
  }
  if plan.expected_unique * 2 > plan.expected_events {
    items.push(
      sketch_recommendation(
        "info", "budget-high-cardinality", "High-cardinality budget", "The unique count is large compared with total events.",
        "Prefer HLL-lite and Bloom sizing guidance over exact in-memory maps.",
      ),
    )
  }
  if plan.estimated_cells > 10000 {
    items.push(
      sketch_recommendation(
        "warning",
        "budget-large-memory",
        "The suggested plan is relatively large",
        "The current settings require " +
        plan.estimated_cells.to_string() +
        " integer/boolean cells.",
        "Lower the accuracy level for browser demos or increase it for backend checks.",
      ),
    )
  }
  if items.length() == 0 {
    items.push(
      sketch_recommendation(
        "info", "budget-balanced", "Budget looks balanced", "The suggested parameters are moderate for the observed sample.",
        "Use this plan as default CLI output and tune with a higher accuracy level if needed.",
      ),
    )
  }
  items
}

///|
fn sketch_next_power_of_two(value : Int) -> Int {
  let mut result = 1
  let target = sketch_max(1, value)
  while result < target {
    result *= 2
  }
  result
}

///|
fn sketch_budget_clamp(value : Int, low : Int, high : Int) -> Int {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}
