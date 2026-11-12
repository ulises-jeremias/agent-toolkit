// Hornero Valley at golden hour: the one shared palette. pal + ramps only.
// Every other file include()s this (through lib.px.js), so it must stay safe to run repeatedly.
// Shadows shift toward violet/blue, highlights toward yellow: ramps are not plain darkening.
use([])
pal({
  k: "#1c1a24",                                                   // ink: every outline, never pure black
  // foliage and grass
  S: "#16302b", F: "#2f5d43", g: "#5f9c4a", G: "#a9c95a", Y: "#d6dc74",
  // straw, earth, timber (one long warm ramp: thatch, lane, planks)
  T: "#4a2f20", t: "#7a4e2d", u: "#a9743f", d: "#cfa368", y: "#e9cf7a",
  // lamplight
  l: "#f2b85c", w: "#fff3d0",
  // terracotta roof and brick
  P: "#55283a", R: "#8a3d32", r: "#c4623e", o: "#e2895a",
  // plaster
  e: "#a18a84", C: "#cdb898", c: "#f0e2c2",
  // stone and slate
  N: "#3b4252", D: "#5f6b74", s: "#8f9aa0", h: "#bcc5c0",
  // river
  B: "#2f6f8a", b: "#4fa3b8", a: "#9ad4d0",
  // sky: day blues, dusk violets, the shared peach horizon
  q: "#8ec4dc", Q: "#c9e3e0", p: "#f3b48a", m: "#a0688c", v: "#5a4a7a", V: "#33294e",
  // distance haze (far ridges) and lavender (flowers, cool cloud bellies)
  n: "#a9c6c9", M: "#7fa99b", i: "#a593c8",
  // lamplight spill for the *_lit overlays only: the same lamplight at two alphas
  1: "#f2b85c8c", 2: "#f2b85c40",
})
// dark -> light. A key steps along the FIRST ramp that lists it.
ramps(
  "kSFgGY",        // foliage
  "kTtudyw",       // timber -> earth -> straw
  "kPRrop",        // brick -> terracotta -> sunlit tile
  "VveCcw",        // plaster falls into dusk violet
  "kVNDshw",       // stone / slate
  "NBbaQ",         // water
  "olw",           // lamplight
  "Vvmp", "qQ", "DMnQ", "vi")
