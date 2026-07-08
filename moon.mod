// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "sketchkit/moon-sketch-kit"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/cauchyQ/moon-sketch-kit"

license = "Apache-2.0"

keywords = [
  "sketch",
  "streaming",
  "analytics",
  "bloom-filter",
  "count-min",
  "moonbit",
]

preferred_target = "wasm-gc"

description = "MoonBit streaming sketch toolkit for approximate analytics, drift checks, and compact data reports."
