// Two additional project homes. Match the 64px valley module, top-left sun,
// coursed roof materials and grounded stonework without palette-only copies.
include("lib.px.js")

{
  const { outline, stones, win } = globalThis.VA
  const W = 64, H = 72

  // A timber courtyard house with a low annex and a deep, angled porch.
  const COURT = {
    windows: [[9, 46, 8, 9], [27, 43, 8, 9], [48, 42, 8, 9], [35, 23, 8, 8]],
    panes: [34, 53, 3, 3],
  }
  sprite("house-cabin", { w: W, h: H }, (c) => {
    // The annex sits behind the main gable and opens onto a small courtyard.
    c.poly([4, 40, 22, 44, 22, 62, 4, 60], "c")
    c.poly([22, 44, 30, 39, 30, 60, 22, 62], "C")
    c.poly([4, 60, 22, 62, 22, 68, 4, 66], "s")
    c.poly([22, 62, 30, 60, 30, 65, 22, 68], "D")
    c.line(5, 45, 21, 49, "u"); c.line(23, 49, 29, 45, "T")
    c.line(5, 53, 21, 57, "t"); c.line(23, 57, 29, 53, "D")
    c.vline(5, 42, 18, "w"); c.vline(21, 46, 16, "T"); c.vline(29, 41, 17, "D")
    // Its low clay roof turns into a shaded return plane at the courtyard.
    c.poly([2, 41, 15, 27, 25, 44, 21, 47], "r")
    c.poly([15, 27, 32, 38, 25, 44], "R")
    c.line(3, 41, 15, 28, "o"); c.line(16, 28, 31, 39, "P")
    for (let i = 0; i < 4; i++) {
      const x = 6 + i * 4
      c.line(x, 36 - i * 3, x + 6, 43 - i, i < 2 ? "o" : "R")
    }

    // Main cabin has a bright timber front and a deep, shaded east wall.
    c.poly([24, 33, 44, 45, 44, 64, 24, 59], "c")
    c.poly([44, 45, 62, 31, 62, 57, 44, 64], "C")
    c.poly([24, 59, 44, 64, 44, 70, 24, 65], "s")
    c.poly([44, 64, 62, 57, 62, 63, 44, 70], "D")
    for (const y of [40, 47, 54]) {
      c.line(25, y, 43, y + 11, "u")
      c.line(45, y + 11, 61, y - 2, "T")
    }
    c.line(26, 36, 43, 46, "w"); c.line(45, 46, 60, 34, "D")
    c.line(25, 57, 43, 62, "t"); c.line(46, 62, 60, 55, "T")
    c.vline(25, 36, 23, "w"); c.vline(43, 46, 17, "T"); c.vline(61, 33, 23, "D")

    // A steep, two-plane cedar roof, high chimney and attic window.
    c.poly([43, 7, 22, 33, 44, 46], "r")
    c.poly([43, 7, 63, 28, 44, 46], "R")
    c.poly([43, 7, 22, 33, 28, 36, 43, 15], "o")
    c.poly([43, 7, 63, 28, 58, 32, 43, 15], "r")
    c.line(43, 8, 23, 34, "y"); c.line(44, 9, 62, 29, "o")
    for (let y = 17; y < 34; y += 4) {
      const reach = Math.floor((y - 7) * 1.12)
      const ridgeY = y + Math.floor((y - 7) * 0.55)
      c.line(43 - reach, y, 43, ridgeY, y < 25 ? "o" : "R")
      c.line(43, ridgeY, 43 + reach, y, y < 25 ? "r" : "P")
    }
    c.line(22, 33, 44, 47, "T"); c.line(44, 47, 63, 29, "T")
    c.line(24, 35, 44, 49, "u"); c.line(44, 49, 61, 32, "u")
    stones(c, 51, 12, 7, 17, { rh: 3, widths: [3, 4, 5] })
    c.vline(51, 13, 15, "h"); c.vline(56, 13, 14, "D")
    c.rect(50, 10, 9, 3, "s"); c.hline(50, 10, 9, "h")
    c.rect(36, 24, 9, 9, "T"); c.rect(37, 25, 7, 7, "N")
    c.px(38, 26, "D"); c.px(38, 27, "b")

    // Covered porch follows the angled front wall; its posts anchor the door.
    c.poly([25, 46, 34, 41, 47, 48, 36, 54], "T")
    c.poly([25, 46, 34, 41, 34, 44, 26, 49], "u")
    c.line(26, 49, 36, 55, "D"); c.line(36, 55, 46, 49, "T")
    c.rect(26, 48, 2, 13, "t"); c.vline(26, 48, 13, "w")
    c.rect(44, 49, 2, 13, "T"); c.vline(44, 49, 13, "u")
    // Separate openings make the front and side elevations readable.
    for (const [x, y, w, h] of COURT.windows) {
      if (y === 23) continue
      win(c, x, y, w, h, { sill: false })
    }
    c.rect(31, 50, 10, 20, "T"); c.rect(32, 51, 8, 19, "t")
    c.vline(34, 52, 17, "u"); c.vline(37, 52, 17, "T")
    c.rect(...COURT.panes, "N"); c.px(34, 53, "D")
    c.px(39, 60, "l"); c.px(39, 61, "u")
    c.line(30, 69, 42, 69, "s"); c.line(31, 70, 41, 70, "h")
    COURT.windows.forEach(([x, y, w, h]) => {
      if (y === 23) win(c, x, y, w, h, { sill: false })
    })
    // A stacked wood niche, herb box and lantern describe a lived-in courtyard.
    c.rect(48, 53, 9, 4, "T"); c.hline(48, 53, 9, "u"); c.hline(48, 56, 9, "t")
    c.stamp("_box_white", 7, 53)
    c.vline(45, 43, 5, "T"); c.px(45, 48, "l"); c.px(45, 49, "y")
  }, outline)
  sprite("house-cabin_lit", { w: W, h: H }, (c) => {
    COURT.windows.forEach(([x, y, w, h]) => globalThis.VA.litwin(c, x, y, w, h, { sill: false }))
    const [x, y, w, h] = COURT.panes
    c.rect(x, y, w, h, "l"); c.px(x, y, "y")
  })

  // A broad limestone farmhouse with a terracotta hip roof, porch and loft.
  const FARM = {
    windows: [[13, 45, 8, 9], [45, 40, 8, 9], [24, 25, 8, 8]],
    panes: [27, 50, 4, 3],
  }
  sprite("house-brick", { w: W, h: H }, (c) => {
    // Limestone volume: sunward front plane and narrower shaded return wall.
    c.poly([10, 29, 35, 43, 35, 64, 11, 58], "c")
    c.poly([35, 43, 59, 28, 59, 55, 35, 64], "C")
    c.poly([11, 58, 35, 64, 35, 70, 11, 64], "s")
    c.poly([35, 64, 59, 55, 59, 62, 35, 70], "s")
    // Offset joints follow the perspective of each masonry face.
    for (const y of [38, 45, 52]) {
      c.line(11, y, 34, y + 13, "h")
      c.line(36, y + 13, 58, y - 1, "D")
    }
    for (const x of [18, 27, 32]) c.line(x, 34 + Math.floor((x - 10) * 0.56), x, 38 + Math.floor((x - 10) * 0.56), "s")
    for (const x of [42, 51, 57]) c.line(x, 49 - Math.floor((x - 35) * 0.62), x, 53 - Math.floor((x - 35) * 0.62), "D")
    c.vline(11, 32, 25, "h"); c.vline(34, 44, 17, "T"); c.vline(58, 31, 22, "D")
    c.line(12, 61, 35, 67, "D"); c.line(36, 67, 58, 59, "D")

    // Terracotta hip roof; the dark east plane recedes behind the ridge.
    c.poly([35, 6, 8, 26, 35, 43], "r")
    c.poly([35, 6, 61, 22, 35, 43], "R")
    c.poly([35, 6, 8, 26, 14, 29, 35, 14], "o")
    c.poly([35, 6, 61, 22, 56, 26, 35, 14], "r")
    c.line(35, 7, 9, 27, "y"); c.line(36, 8, 60, 23, "o")
    for (let y = 15; y < 31; y += 4) {
      const reach = Math.floor((y - 6) * 1.25)
      const ridgeY = y + Math.floor((y - 6) * 0.55)
      c.line(35 - reach, y, 35, ridgeY, y < 23 ? "o" : "R")
      c.line(35, ridgeY, 35 + reach, y, y < 23 ? "r" : "P")
    }
    c.line(8, 26, 35, 43, "T"); c.line(35, 43, 61, 23, "T")
    c.line(10, 29, 35, 45, "u"); c.line(35, 45, 59, 26, "u")

    // Rear chimney emerges from the shaded side of the roof.
    stones(c, 47, 9, 8, 18, { rh: 3, widths: [4, 5, 3] })
    c.vline(47, 10, 16, "h"); c.vline(53, 10, 16, "D")
    c.rect(46, 7, 10, 3, "s"); c.hline(46, 7, 10, "h")

    // Small attic dormer, set into the front roof plane.
    c.poly([19, 27, 25, 20, 33, 27], "R")
    c.line(25, 20, 19, 27, "o"); c.line(26, 21, 32, 27, "P")
    c.rect(22, 27, 10, 9, "c"); c.rect(29, 27, 3, 9, "C")
    win(c, 24, 25, 8, 8, { sill: false })

    // Porch canopy projects from the limestone front with two stout posts.
    c.poly([18, 46, 27, 41, 38, 47, 28, 53], "T")
    c.poly([18, 46, 27, 41, 27, 44, 19, 49], "u")
    c.line(19, 49, 28, 54, "D"); c.line(28, 54, 37, 48, "T")
    c.rect(19, 48, 2, 14, "t"); c.vline(19, 48, 14, "w")
    c.rect(36, 49, 2, 13, "T"); c.vline(36, 49, 13, "u")
    // Farmhouse sash windows, deep oak door and warm transom.
    FARM.windows.forEach(([x, y, w, h]) => {
      if (y !== 25) win(c, x, y, w, h, { sill: false })
    })
    c.rect(24, 48, 13, 22, "s"); c.rect(25, 49, 11, 21, "t")
    c.rect(27, 50, 4, 4, "N"); c.rect(27, 50, 4, 3, "B")
    c.vline(27, 55, 13, "u"); c.vline(30, 55, 13, "T"); c.vline(33, 55, 13, "u")
    c.px(33, 61, "l"); c.px(33, 62, "y")
    c.line(23, 69, 38, 69, "s"); c.line(24, 70, 37, 70, "h")
    // Rain chain, firewood and herb box tell a quiet working-farm story.
    c.vline(55, 37, 8, "D"); c.px(54, 45, "D"); c.px(56, 46, "D")
    c.rect(43, 55, 8, 4, "T"); c.hline(43, 55, 8, "u"); c.hline(43, 58, 8, "t")
    c.rect(12, 54, 8, 3, "d"); c.hline(12, 54, 8, "u"); c.hline(12, 57, 8, "T")
    c.stamp("_box_white", 12, 52)
  }, outline)
  sprite("house-brick_lit", { w: W, h: H }, (c) => {
    FARM.windows.forEach(([x, y, w, h]) => globalThis.VA.litwin(c, x, y, w, h, { sill: false }))
    const [x, y, w, h] = FARM.panes
    c.rect(x, y, w, h, "l"); c.px(x, y, "y")
  })
}
