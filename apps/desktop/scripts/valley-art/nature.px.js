// Trees, shrubs, flowers, reeds and small props. Every sprite sits on its bottom row (the ground).
// Canopy volumes are shaded from the upper-left: sunward rim gets the highlight, the far rim the
// shadow. Canopies and trunks are drawn in that order so the trunk disappears into the leaves.
include("lib.px.js")

{
  const VA = globalThis.VA
  const { outline, halo } = VA

  /** Leaf mass from circles: base colour, sunward rim light, shadow rim on the lower right. */
  const canopy = (c, blobs, base = "F", hi = "G", lo = "S") => {
    // each lobe: base colour, then a lighter lobe pushed toward the sun, then the brightest core
    for (const [x, y, r] of blobs) {
      c.circ(x, y, r, base)
      if (r >= 4) c.circ(x - 1, y - 1, r - 2, hi === "G" ? "g" : hi)
      if (r >= 7) c.circ(x - 2, y - 2, r - 5, hi)
    }
    for (let y = 0; y < c.h; y++)
      for (let x = 0; x < c.w; x++) {
        if (c.is(x, y, ".")) continue
        if (c.is(x - 1, y - 1, ".") || c.is(x, y - 1, ".") && !c.is(x - 1, y, ".")) c.px(x, y, hi)
        else if (c.is(x + 1, y + 1, ".") || c.is(x + 1, y, ".") && c.is(x, y + 1, ".")) c.px(x, y, lo)
      }
  }
  /** Leaf clusters: small darker and lighter dabs so the mass reads as foliage, not a blob. */
  const leaves = (c, pts) => { for (const [x, y, k] of pts) c.px(x, y, k) }

  // ================================================================ tree_oak (48x64)
  sprite("tree_oak", { w: 48, h: 64 }, (c) => {
    // root flare and trunk, with a low fork
    c.rect(20, 40, 8, 20, "t"); c.vline(20, 40, 20, "u"); c.vline(26, 40, 20, "T")
    c.poly([20, 58, 16, 63, 32, 63, 28, 58], "t")
    c.line(22, 44, 14, 36, "t", 2)                                       // limb to the left
    c.line(26, 44, 34, 36, "T", 2)                                       // limb to the right, in shade
    canopy(c, [[14, 22, 12], [34, 22, 12], [24, 12, 13], [24, 30, 14], [9, 34, 8], [39, 34, 8], [24, 40, 8]])
    leaves(c, [[11, 18, "G"], [20, 8, "G"], [30, 18, "g"], [17, 30, "g"], [35, 27, "S"], [28, 36, "S"], [6, 36, "g"]])
  }, outline)

  // ================================================================ tree_pine (32x64)
  sprite("tree_pine", { w: 32, h: 64 }, (c) => {
    c.rect(14, 50, 4, 13, "t"); c.vline(14, 50, 13, "u")
    c.poly([10, 63, 8, 63, 9, 60, 23, 60, 24, 63, 22, 63], "t")
    // three stacked tiers, each a triangle with a skirt
    const tiers = [[16, 4, 26, 26], [16, 14, 29, 40], [16, 24, 31, 53]]
    for (const [x, top, halfW, base] of tiers) c.poly([x, top, x - halfW / 2, base, x + halfW / 2, base], "F")
    for (const [x, top, halfW, base] of tiers) {
      c.clip([x, top, x - halfW / 2, base, x + halfW / 2, base], () => {
        for (let y = top; y < base; y++) {
          c.hline(x - halfW / 2, y, Math.round(halfW / 2) - Math.round((y - top) * 0.0), "G")  // sunlit left half
          c.hline(x + 1, y, halfW, "S")                                       // shadowed right half
        }
      })
      c.hline(x - halfW / 2, base, halfW, "S")                                 // skirt
    }
    c.clip([16, 4, 3, 53, 29, 53], () => { for (let y = 8; y < 52; y += 6) c.hline(0, y, 32, "S") })
  }, outline)

  // ================================================================ tree_birch (28x56)
  sprite("tree_birch", { w: 28, h: 56 }, (c) => {
    c.rect(12, 28, 3, 28, "c"); c.vline(14, 28, 28, "C")                   // trunk runs up into the crown                  // white bark, shade side
    for (const [x, y] of [[12, 42], [13, 48], [12, 53], [14, 34]]) c.px(x, y, "T")  // bark marks
    c.poly([10, 55, 8, 55, 9, 53, 19, 53, 20, 55, 18, 55], "t")
    canopy(c, [[9, 16, 7], [19, 16, 7], [14, 9, 7], [14, 24, 8], [7, 26, 5], [21, 26, 5]], "g", "G", "F")
    leaves(c, [[11, 12, "G"], [17, 20, "F"], [9, 22, "F"], [20, 12, "F"], [15, 28, "F"]])
  }, outline)

  // ================================================================ shrubs and flowers
  sprite("bush_1", { w: 20, h: 12 }, (c) => {
    c.rect(1, 9, 18, 2, "F")
    canopy(c, [[6, 7, 5], [13, 7, 5], [10, 5, 4]], "g", "G", "F")
    leaves(c, [[4, 4, "G"], [9, 3, "G"], [14, 6, "F"]])
    c.rect(0, 10, 20, 2, "S")
  }, outline)
  sprite("bush_2", { w: 28, h: 14 }, (c) => {
    c.rect(1, 11, 26, 2, "F")
    canopy(c, [[7, 8, 6], [14, 6, 6], [21, 8, 6], [14, 10, 5]], "F", "g", "S")
    leaves(c, [[5, 5, "G"], [12, 3, "G"], [19, 5, "G"], [16, 9, "g"]])
    // a few flowers on the crown: they earn their place as the valley's accent colour
    for (const [x, y, k] of [[8, 7, "m"], [15, 9, "y"], [22, 6, "c"]]) c.px(x, y, k)
    c.rect(0, 12, 28, 2, "S")
  }, outline)
  // flowers: short stems with a few blooms, straw and mauve
  sprite("flowers_1", { w: 16, h: 8 }, (c) => {
    for (const x of [2, 6, 10, 13]) c.vline(x, 4, 4, "g")
    c.px(2, 4, "G"); c.px(10, 5, "G")
    for (const [x, y, k] of [[2, 3, "y"], [6, 3, "m"], [10, 4, "y"], [13, 3, "c"]]) { c.px(x, y, k); c.px(x, y - 1, "c") }
    c.hline(0, 7, 16, "S")
  }, outline)
  sprite("flowers_2", { w: 16, h: 8 }, (c) => {
    for (const x of [3, 7, 11, 14]) c.vline(x, 4, 4, "F")
    for (const [x, y, k] of [[3, 3, "m"], [7, 2, "c"], [11, 3, "i"], [14, 4, "y"]]) { c.px(x, y, k); c.px(x - 1, y, k) }
    c.px(7, 3, "y")
    c.hline(0, 7, 16, "S")
  }, outline)

  // ================================================================ reeds (16x16)
  sprite("reeds", { w: 16, h: 16 }, (c) => {
    for (const [x, top, lean] of [[3, 2, 0], [7, 0, 1], [11, 4, -1], [14, 6, 0]]) {
      c.vline(x, top + 3, 16 - top - 3, "g")
      c.vline(x + 1, top + 4, 16 - top - 4, "F")
      c.rect(x - 1, top + 1, 2, 2, "t")                                  // cattail spike
      c.px(x + lean, top, "u")
    }
    c.hline(0, 15, 16, "S")
  }, outline)

  // ================================================================ rock_1 (14x9)
  sprite("rock_1", { w: 14, h: 9 }, (c) => {
    c.poly([1, 8, 2, 3, 6, 1, 11, 2, 13, 8], "s")
    c.poly([3, 2, 6, 1, 11, 2, 9, 2, 6, 3], "h")                         // top face catches the sun
    c.poly([9, 3, 12, 5, 13, 8, 11, 8], "D")                             // shadow on the right
    c.hline(2, 8, 10, "N")
  }, outline)

  // ================================================================ fence (32x12, tiles at 32px)
  sprite("fence", { w: 32, h: 12 }, (c) => {
    // posts every 16px so the pattern repeats on a 32px tile. Each post is sunlit on its left edge.
    for (const x of [2, 18]) { c.rect(x, 2, 3, 10, "t"); c.vline(x, 2, 10, "u"); c.vline(x + 2, 2, 10, "T"); c.px(x + 1, 1, "t"); c.px(x + 1, 0, "u") }
    c.rect(0, 4, 32, 2, "t"); c.hline(0, 4, 32, "u"); c.hline(0, 5, 32, "T")
    c.rect(0, 8, 32, 2, "t"); c.hline(0, 8, 32, "u"); c.hline(0, 9, 32, "T")
    c.hline(0, 11, 32, "S")
  }, outline)

  // ================================================================ signpost (14x24)
  sprite("signpost", { w: 14, h: 24 }, (c) => {
    c.rect(5, 8, 3, 15, "t"); c.vline(5, 8, 15, "u"); c.vline(7, 8, 15, "T")
    c.poly([0, 4, 10, 4, 13, 6, 10, 8, 0, 8], "u")                       // board pointing right
    c.hline(0, 4, 10, "y"); c.hline(0, 7, 10, "t")
    c.poly([14, 11, 4, 11, 1, 13, 4, 15, 14, 15], "t")                   // board pointing left
    c.hline(4, 11, 10, "u")
    c.hline(2, 6, 4, "T"); c.px(10, 6, "T")                              // a painted word
    c.hline(0, 23, 14, "S")
  }, outline)

  // ================================================================ woodpile (20x12)
  sprite("woodpile", { w: 20, h: 12 }, (c) => {
    for (let row = 0; row < 3; row++)
      for (let i = 0; i < 4 - (row === 2 ? 1 : 0); i++) {
        const x = 1 + i * 5 + (row % 2) * 2, y = 9 - row * 4
        c.rect(x, y - 1, 5, 4, "u"); c.hline(x, y - 1, 5, "y"); c.hline(x, y + 2, 5, "t")
        c.circ(x, y + 1, 1, "d")                                         // log ends
      }
    c.hline(0, 11, 20, "S")
  }, outline)

  // ================================================================ lamp post (10x40) and its lit overlay
  // Post centred on x=4..5. Lantern glass is the 4x4 block at x3..6, y3..6: centre (4.5, 4.5).
  sprite("lamp_post", { w: 10, h: 40 }, (c) => {
    c.rect(3, 1, 4, 1, "N")                                              // cap
    c.rect(2, 2, 6, 1, "N")
    c.rect(2, 3, 1, 5, "D"); c.rect(7, 3, 1, 5, "D")                     // lantern frame
    c.rect(3, 3, 4, 4, "V")                                              // dark glass until it is lit
    c.px(3, 3, "c")
    c.rect(2, 8, 6, 2, "N")                                              // collar
    c.rect(4, 10, 2, 29, "N"); c.vline(4, 10, 29, "D")                   // post, shade on the right
    c.rect(2, 39, 6, 1, "S")                                             // foot
  }, outline)
  // Overlay 26x48: the post's origin is at (8,8) inside this canvas, so the lantern glass (3..6, 3..6)
  // maps to (11..14, 11..14). Lit overlay = that glass plus halo only.
  sprite("lamp_post_lit", { w: 26, h: 48 }, (c) => {
    c.rect(11, 11, 4, 4, "y"); c.rect(12, 12, 2, 2, "w")
    c.px(11, 11, "l"); c.px(14, 14, "o")
    halo(c, 2, 5)
  })

  // ================================================================ nest post (16x36)
  // A post of weathered timber with the hornero's round mud nest on top. Nest centre = (8, 8).
  sprite("nest_post", { w: 16, h: 36 }, (c) => {
    c.rect(7, 14, 3, 22, "t"); c.vline(7, 14, 22, "u"); c.vline(9, 14, 22, "T")
    c.rect(5, 34, 7, 2, "t")                                             // foot
    // mud nest: a dome of ochre with a darker underside and the entrance tube
    c.circ(8, 8, 6, "t"); c.circ(7, 7, 5, "u"); c.circ(6, 6, 2, "y")
    c.hline(4, 13, 9, "T")                                               // the ledge line where it sits on the post
    c.rect(9, 8, 3, 3, "T"); c.px(9, 8, "D")                              // entrance hole, right side
    c.rect(6, 12, 4, 2, "t")                                             // sunken base
    c.hline(0, 35, 16, "S")
  }, outline)
}
