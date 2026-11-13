// Backdrop: sky strips, distant hills, the valley floor, the river section, its bridge and clouds.
// Ground line contract: the lane's top edge is row 10 of `ground` and of `river` (and the bridge deck).
include("lib.px.js")

const TAU = Math.PI * 2
// Ridge helper: fills from topFn(x) down to the bottom, colour chosen by depth below the crest.
const ridge = (c, topFn, paint) => {
  for (let x = 0; x < c.w; x++) {
    const top = Math.round(topFn(x))
    for (let y = Math.max(0, top); y < c.h; y++) c.px(x, y, paint(y - top, x, y))
  }
}

// ---------------------------------------------------------------- sky strips (tiled horizontally)
// Vertical gradients only, so any horizontal tiling is seamless by construction.
sprite("sky_day", { w: 16, h: 200 }, (c) => {
  c.grad(0, 0, 16, 200, "qQcp", "v", 0.6)
})
sprite("sky_dusk", { w: 16, h: 200 }, (c) => {
  c.grad(0, 0, 16, 186, "VvmpY", "v", 0.6)   // violet -> mauve -> peach
  c.rect(0, 186, 16, 3, "y")                 // thin gold band
  c.rect(0, 189, 16, 11, "l")                // lamplit haze at the valley floor
})

// ---------------------------------------------------------------- hills (400 wide, periodic)
// Sine periods are whole multiples of the width so the ridge line matches at both ends.
sprite("hills_far", { w: 400, h: 80 }, (c) => {
  // back range: palest, almost sky-coloured; crest catches the sun on the left
  ridge(c, (x) => 34 + 5 * Math.sin((TAU * 2 * x) / 400) + 2.5 * Math.sin((TAU * 5 * x) / 400 + 1.3),
    (d) => (d === 0 ? "Q" : d < 3 ? "n" : "n"))
  // front range: cooler, a little deeper, still hazy
  ridge(c, (x) => 52 + 4 * Math.sin((TAU * 3 * x) / 400 + 2.1) + 2 * Math.sin((TAU * 7 * x) / 400),
    (d) => (d === 0 ? "n" : "M"))
})

sprite("hills_mid", { w: 400, h: 96 }, (c) => {
  ridge(c, (x) => 36 + 6 * Math.sin((TAU * 2 * x) / 400 + 0.4) + 3 * Math.sin((TAU * 6 * x) / 400),
    (d) => (d === 0 ? "G" : d < 12 ? "g" : "F"))   // sunlit crest, mid-green slope, darker deep body
  // distant treeline: tiny rounded silhouettes on the crest, lit on their upper-left
  const rng = c.rng(7)
  for (let i = 0; i < 46; i++) {
    const x = Math.floor(rng() * 400), top = Math.round(36 + 6 * Math.sin((TAU * 2 * x) / 400 + 0.4) + 3 * Math.sin((TAU * 6 * x) / 400))
    const r = 1 + Math.floor(rng() * 2)
    c.circ(x, top - r + 1, r, "F")
    c.px(x - 1, top - r, "g")
  }
  // two far roofs on the crest, lit from the upper left
  for (const rx of [118, 286]) {
    const top = Math.round(36 + 6 * Math.sin((TAU * 2 * rx) / 400 + 0.4) + 3 * Math.sin((TAU * 6 * rx) / 400))
    c.poly([rx, top - 5, rx + 3, top - 8, rx + 6, top - 5, rx + 6, top], "r")
    c.poly([rx, top - 5, rx + 3, top - 8, rx + 3, top - 8, rx, top - 5], "o")
    c.rect(rx + 1, top - 4, 4, 4, "C")
    c.px(rx + 2, top - 2, "V")
  }
})

// ---------------------------------------------------------------- valley floor (400x64)
// Rows 0-9: verge with a tufted, uneven top (transparent above it).
// Row 10: the lane's top edge, dead straight: the ground line.
// Rows 11-23: packed earth lane. Rows 24-63: foreground meadow.
sprite("ground", { w: 400, h: 64 }, (c) => {
  const rng = c.rng(11)
  // verge: grass fills from each column's tuft height down to row 9
  for (let x = 0; x < 400; x++) {
    const tuft = [0, 1, 0, 2, 1, 0, 0, 3, 1, 0][Math.floor(x / 4) % 10]
    for (let y = tuft; y < 10; y++) c.px(x, y, y === tuft ? "G" : y < tuft + 2 ? "g" : "F")
    if (rng() < 0.12) c.px(x, tuft - 1 < 0 ? 0 : tuft - 1, "G")         // single bright tuft blade
  }
  // lane: straight edge, lit top row, earth below with shadowed base
  c.hline(0, 10, 400, "d")
  c.rect(0, 11, 400, 12, "d")
  c.hline(0, 10, 400, "y")                       // sun on the lane edge
  c.hline(0, 22, 400, "u")                       // earth falls into shadow
  c.hline(0, 23, 400, "t")
  for (let i = 0; i < 90; i++) {                 // pebbles: 2 px clusters, few
    const x = Math.floor(rng() * 398), y = 12 + Math.floor(rng() * 9)
    c.px(x, y, "s"); c.px(x + 1, y, "h")
  }
  for (let x = 0; x < 400; x += 1) if ((x * 7) % 11 === 0) c.px(x, 15, "u")   // wheel-rut dashes
  // meadow: sunlit crest, darker blades underneath, a few flower clusters
  c.rect(0, 24, 400, 40, "g")
  c.rect(0, 24, 400, 3, "G")
  c.rect(0, 27, 400, 6, "g")
  for (let x = 0; x < 400; x++) {
    const y = 30 + ((x * 3) % 7) * 3
    if (x % 3) c.px(x, y, "F")
  }
  c.rect(0, 58, 400, 6, "F")
  c.hline(0, 63, 400, "S")
  const bloom = (x, y, col) => { c.px(x, y, col); c.px(x - 1, y, col); c.px(x, y - 1, "c") }
  for (let i = 0; i < 26; i++) {
    const x = Math.floor(rng() * 396) + 2, y = 36 + Math.floor(rng() * 20)
    bloom(x, y, ["y", "m", "c", "i"][i % 4])
  }
})

// ---------------------------------------------------------------- the river segment (64x64)
// Same ground line as `ground`. Rows 0-9 are bank, row 10 is the water's top edge.
// Water is horizontal bands that get longer toward the viewer, like a river running at us.
sprite("river", { w: 64, h: 64 }, (c) => {
  for (let x = 0; x < 64; x++) {
    const tuft = [1, 0, 2, 0][Math.floor(x / 4) % 4]
    for (let y = tuft; y < 10; y++) c.px(x, y, y === tuft ? "G" : "F")
  }
  c.hline(0, 10, 64, "F")                        // bank lip: shadowed edge
  c.rect(0, 11, 64, 53, "b")
  c.rect(0, 11, 64, 3, "a")                      // sunlit far water
  c.rect(0, 40, 64, 24, "B")                     // deep water toward the viewer
  c.rect(0, 40, 64, 6, "b")
  // flow streaks: longer and lower as they come forward
  for (let y = 14; y < 64; y += 5) {
    const len = 4 + Math.floor((y - 14) / 6)
    for (let x = ((y * 13) % 17); x < 64; x += 21 + (y % 9)) c.hline(x, y, Math.min(len, 64 - x), "a")
  }
  // reeds: small fans rising from the bank line on both sides
  for (const [x0, y0] of [[1, 10], [60, 10], [3, 11]]) {
    c.vline(x0, y0 - 5, 6, "G"); c.vline(x0 + 1, y0 - 6, 7, "g"); c.px(x0 + 2, y0 - 7, "G")
  }
  // stones half in the water
  for (const [x, y] of [[20, 52], [45, 58]]) {
    c.rect(x, y, 5, 3, "s"); c.hline(x, y, 5, "h"); c.hline(x, y + 2, 5, "D")
  }
})

// ---------------------------------------------------------------- footbridge (80x28)
// Deck top is row 10 so it sits on the lane line. Posts and rail above, piers into the water.
sprite("bridge", { w: 80, h: 28 }, (c) => {
  c.rect(0, 10, 80, 5, "t")                      // deck
  c.hline(0, 10, 80, "u")                        // sunlit top board
  c.hline(0, 14, 80, "T")                        // plank shadow
  for (let x = 0; x < 80; x += 5) c.vline(x, 11, 3, "T")
  c.hline(2, 15, 76, "C")                        // underside shadow catches the water
  // rail: posts and two bars
  for (const x of [2, 20, 39, 58, 76]) { c.rect(x, 3, 2, 7, "t"); c.vline(x, 3, 7, "u") }
  c.hline(2, 4, 76, "u"); c.hline(2, 7, 76, "T")
  // piers (stone) reaching into the water
  for (const x of [10, 52]) { c.rect(x, 15, 9, 13, "s"); c.hline(x, 15, 9, "h"); c.hline(x, 19, 9, "D"); c.hline(x, 24, 9, "D") ; c.vline(x + 8, 16, 11, "D") }
  c.rect(4, 23, 72, 2, "B")                      // water lapping at the piers
})

// ---------------------------------------------------------------- clouds (lit upper-left)
// Silhouette from circles and a flat base. Upper-left edges get the highlight, underside is cool.
const cloud = (c, blobs) => {
  c.clip(undefined, () => {})                    // no-op: keeps helper visible in the call graph
  for (const [cx, cy, r] of blobs) c.circ(cx, cy, r, "c")
  // flat base: a rect along the bottom of the mass
  const bottoms = blobs.map(([, cy, r]) => cy + r - 1)
  const base = Math.max(...bottoms)
  for (const [x, y] of [[0, 0]]) c.px(x, y, ".")
  c.rect(blobs[0][0] - blobs[0][2], base - 2, (blobs[blobs.length - 1][0] + blobs[blobs.length - 1][2]) - (blobs[0][0] - blobs[0][2]), 2, "c")
  for (let y = 0; y < c.h; y++)
    for (let x = 0; x < c.w; x++) {
      if (c.is(x, y, ".")) continue
      if (c.is(x, y + 1, ".")) c.px(x, y, "Q")          // underside
      else if (c.is(x - 1, y - 1, ".") || c.is(x, y - 1, ".")) c.px(x, y, "w")  // sunward rim
    }
}
sprite("cloud_1", { w: 48, h: 16 }, (c) => cloud(c, [[12, 9, 5], [21, 6, 6], [31, 9, 5], [38, 11, 3]]))
sprite("cloud_2", { w: 64, h: 20 }, (c) => cloud(c, [[16, 12, 6], [27, 8, 8], [40, 11, 7], [52, 13, 5]]))
sprite("cloud_3", { w: 36, h: 12 }, (c) => cloud(c, [[9, 7, 4], [18, 5, 5], [26, 7, 4]]))
