// Two additional project homes. Match the 64px valley module, top-left sun,
// coursed roof materials and grounded stonework without palette-only copies.
include("lib.px.js")

{
  const { outline, stones, planks, win } = globalThis.VA
  const W = 64, H = 72

  // A timber courtyard house with a side wing and an open covered entry.
  const COURT = {
    windows: [[10, 43, 9, 10], [39, 43, 9, 10], [25, 25, 9, 10]],
    panes: [29, 51, 4, 3],
  }
  sprite("house-cabin", { w: W, h: H }, (c) => {
    // Rear wing: the offset roofline gives the house a second, lower volume.
    c.rect(4, 39, 27, 25, "c")
    c.rect(26, 41, 5, 23, "C")
    planks(c, 4, 39, 27, 25, { pw: 7, base: "c", seam: "C", hi: "w" })
    stones(c, 2, 62, 31, 8, { rh: 4, widths: [5, 7, 4, 8] })
    c.poly([2, 40, 16, 27, 33, 40, 31, 44, 4, 44], "r")
    c.poly([16, 27, 33, 40, 31, 44, 16, 33], "R")
    for (let y = 32; y < 41; y += 3) {
      c.hline(16 - (y - 27), y, y - 27, "o")
      c.hline(16, y, y - 27, "R")
    }
    c.hline(3, 40, 29, "T")
    win(c, 9, 48, 8, 9, { sill: false })
    c.rect(8, 57, 10, 2, "d")
    c.vline(22, 45, 17, "t")

    // Main gable is set forward, with a deep porch roof and two timber posts.
    c.rect(26, 35, 34, 31, "c")
    c.rect(53, 37, 7, 29, "C")
    planks(c, 26, 35, 34, 31, { pw: 7, base: "c", seam: "C", hi: "w" })
    stones(c, 24, 63, 38, 7, { rh: 4, widths: [7, 5, 8, 6] })
    stones(c, 46, 12, 7, 20, { rh: 4, widths: [3, 4, 5] })
    c.vline(46, 13, 18, "h"); c.vline(52, 13, 18, "D")
    c.rect(45, 10, 9, 3, "s"); c.hline(45, 10, 9, "h")
    c.poly([43, 34, 61, 34, 64, 39, 39, 39], "T")
    c.poly([43, 34, 61, 34, 64, 39, 60, 39], "u")
    c.hline(40, 39, 24, "T")
    c.rect(40, 39, 2, 25, "t"); c.vline(40, 39, 25, "w")
    c.rect(60, 39, 2, 25, "t"); c.vline(60, 39, 25, "w")
    c.poly([43, 35, 51, 21, 63, 35], "n")
    c.poly([51, 21, 63, 35, 60, 35, 51, 24], "D")
    c.clip([43, 35, 51, 21, 63, 35], () => {
      for (let y = 26; y < 35; y += 3) c.hline(0, y, 64, "V")
    })
    c.hline(42, 35, 21, "T")
    c.vline(47, 38, 27, "t"); c.vline(59, 38, 27, "t")
    COURT.windows.forEach(([x, y, w, h]) => win(c, x, y, w, h, { sill: false }))
    c.rect(27, 48, 11, 22, "T")
    c.rect(28, 49, 9, 20, "B")
    c.vline(30, 50, 18, "b"); c.vline(33, 50, 18, "N")
    c.rect(...COURT.panes, "N"); c.px(29, 51, "D")
    c.px(35, 59, "l"); c.px(35, 60, "u")
    c.rect(25, 69, 15, 2, "s"); c.hline(25, 69, 15, "h")
    c.stamp("_box_white", 8, 55)
    c.stamp("_box_red", 42, 55)
  }, outline)
  sprite("house-cabin_lit", { w: W, h: H }, (c) => {
    COURT.windows.forEach(([x, y, w, h]) => globalThis.VA.litwin(c, x, y, w, h, { sill: false }))
    const [x, y, w, h] = COURT.panes
    c.rect(x, y, w, h, "l"); c.px(x, y, "y")
  })

  // A broad stone-and-plaster farmhouse with a clipped roof, porch and loft.
  const FARM = {
    windows: [[10, 45, 9, 10], [45, 45, 9, 10], [27, 27, 9, 9]],
    panes: [29, 52, 4, 3],
  }
  sprite("house-brick", { w: W, h: H }, (c) => {
    // Offset chimney and ridge cap break the familiar centred-gable outline.
    stones(c, 9, 12, 8, 22, { rh: 4, widths: [4, 5, 3] })
    c.vline(9, 13, 19, "h"); c.vline(16, 13, 18, "D")
    c.rect(8, 10, 10, 3, "s"); c.hline(8, 10, 10, "h")
    c.rect(46, 15, 8, 17, "e")
    stones(c, 45, 14, 10, 3, { rh: 3, base: "s", widths: [4, 3, 5] })
    c.rect(6, 35, 53, 30, "c")
    c.rect(48, 37, 11, 28, "C")
    stones(c, 4, 62, 57, 9, { rh: 4, widths: [7, 5, 9, 6] })

    // Hipped slate roof with a short gabled porch: layered eaves give it depth.
    c.poly([5, 37, 12, 25, 31, 12, 56, 25, 62, 37], "N")
    c.poly([31, 12, 56, 25, 62, 37, 55, 37], "D")
    c.poly([5, 37, 12, 25, 31, 12, 28, 18, 12, 29, 8, 37], "V")
    c.clip([5, 37, 12, 25, 31, 12, 56, 25, 62, 37], () => {
      for (let y = 19; y < 37; y += 4) {
        c.hline(0, y, 64, "V")
        for (let x = 5 + (y % 8 ? 3 : 0); x < 60; x += 8) c.px(x, y - 1, "P")
      }
    })
    c.hline(5, 36, 57, "T"); c.hline(7, 38, 53, "R")
    c.poly([24, 42, 40, 42, 44, 47, 20, 47], "T")
    c.poly([24, 42, 40, 42, 44, 47, 40, 47], "u")
    c.rect(22, 46, 2, 18, "t"); c.vline(22, 46, 18, "w")
    c.rect(40, 46, 2, 18, "t"); c.vline(40, 46, 18, "w")

    // Weatherboard central gable and a framed loft vent.
    c.poly([32, 17, 46, 32, 18, 32], "e")
    c.poly([32, 17, 46, 32, 42, 32, 32, 21], "C")
    c.rect(28, 24, 8, 7, "T"); c.rect(29, 25, 6, 5, "D")
    c.vline(31, 25, 5, "b"); c.vline(33, 25, 5, "b")
    c.rect(9, 39, 3, 24, "t"); c.vline(9, 39, 24, "w")
    c.rect(56, 39, 2, 24, "t"); c.vline(56, 39, 24, "w")
    FARM.windows.forEach(([x, y, w, h]) => win(c, x, y, w, h, { sill: false }))
    c.rect(27, 49, 11, 22, "s"); c.rect(28, 50, 9, 19, "B")
    c.vline(30, 51, 17, "b"); c.vline(33, 51, 17, "N")
    c.rect(...FARM.panes, "N"); c.px(29, 52, "D")
    c.px(35, 60, "l"); c.px(35, 61, "u")
    c.rect(25, 69, 15, 2, "s"); c.hline(25, 69, 15, "h")
    // A rain chain, stacked firewood and a small herb bed explain the porch.
    c.vline(47, 38, 7, "D"); c.px(46, 45, "D"); c.px(48, 46, "D")
    c.rect(3, 56, 6, 3, "d"); c.hline(3, 56, 6, "u"); c.hline(3, 59, 6, "T")
    c.rect(52, 57, 8, 5, "T"); c.hline(52, 57, 8, "w"); c.vline(56, 57, 5, "u")
  }, outline)
  sprite("house-brick_lit", { w: W, h: H }, (c) => {
    FARM.windows.forEach(([x, y, w, h]) => globalThis.VA.litwin(c, x, y, w, h, { sill: false }))
    const [x, y, w, h] = FARM.panes
    c.rect(x, y, w, h, "l"); c.px(x, y, "y")
  })
}
