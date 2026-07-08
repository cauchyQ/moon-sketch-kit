///|
fn main {
  let plan = @sketch.sketch_budget_from_text(
    "login view login cart checkout refund user42 user43", 6,
  )
  println(@sketch.sketch_budget_markdown(plan))
}
