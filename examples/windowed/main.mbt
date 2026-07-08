///|
fn main {
  let report = @sketch.windowed_report_from_text(
    "login login view | view cart cart checkout | checkout refund refund",
  )
  println(@sketch.windowed_report_markdown(report))
  println(
    @sketch.recommendations_markdown(
      @sketch.recommendations_from_windowed(report),
    ),
  )
}
