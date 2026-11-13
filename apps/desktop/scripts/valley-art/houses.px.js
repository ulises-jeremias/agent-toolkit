// The four project cottages, front-on, 64x72, standing on the bottom row.
// Each house keeps its windows/door in a spec so the *_lit overlay repaints exactly the same panes.
include("lib.px.js")

{
  const VA = globalThis.VA
  const { outline, stones, win, litwin } = VA
  const W = 64, H = 72

  // ---------------------------------------------------------------- shared details
  // Flower boxes sit under a 9px window: 11 wide. Bottom two rows are the box.
  sprite("_box_red", `
    .r.g.o.r.g.
    grgGgrgogrg
    gGgggGgggGg
    ddddddddddd
    tuuuuuuuuuT
    .TTTTTTTTT.`)
  sprite("_box_white", { base: "_box_red", swap: { r: "w", o: "i" } })
  // Wall lantern: dark by day; its glass (the two N pixels) is relit by the overlay.
  sprite("_lantern", `
    TTT.
    ..T.
    .NNN
    .DNN
    .NNN
    ..N.`)

  /** Arched plank door. x,y,w,h = outer frame; `col` = [dark, mid, light] paint. */
  const door = (c, x, y, w, h, col, o = {}) => {
    const [dk, md, lt] = col
    c.rect(x, y, w, h, "T")
    c.rect(x + 1, y + 1, w - 2, h - 1, md)
    c.vline(x + 1, y + 1, h - 1, lt)                                   // sunlit edge board
    for (let xx = x + 3; xx < x + w - 2; xx += 3) c.vline(xx, y + 4, h - 4, dk)
    c.hline(x + 1, y + 1, w - 2, dk)                                   // shadow under the lintel
    if (o.arch) { c.px(x, y, o.arch); c.px(x + w - 1, y, o.arch); c.px(x + 1, y + 1, "T"); c.px(x + w - 2, y + 1, "T") }
    if (o.pane) { const [px_, py, pw, ph] = o.pane; c.rect(px_ - 1, py - 1, pw + 2, ph + 2, dk); c.rect(px_, py, pw, ph, "N"); c.px(px_, py, "D") }
    c.px(x + w - 3, y + Math.round(h * 0.55), "l"); c.px(x + w - 3, y + Math.round(h * 0.55) + 1, "u")   // brass knob
  }

  // ================================================================ house-cottage
  // A compact riverside inn in three-quarter view: two wall planes, a hipped
  // roof, deep porch and stepped footing establish volume at the map scale.
  const A = {
    wins: [[14, 43, 8, 10, {}], [43, 42, 8, 10, {}]],
    doorPane: [27, 52, 3, 3],
    lamps: [[38, 48, 2, 3]],
  }
  sprite("house-cottage", { w: W, h: H }, (c) => {
    // Rear chimney emerges behind the ridge; the capped stack has a lit edge.
    stones(c, 44, 5, 8, 20, { rh: 3, widths: [4, 5, 3] })
    c.vline(44, 6, 18, "h"); c.vline(50, 6, 18, "D"); c.vline(51, 6, 18, "N")
    c.rect(43, 3, 10, 3, "s"); c.hline(43, 3, 10, "h"); c.hline(44, 5, 8, "D")
    c.rect(46, 1, 4, 2, "r"); c.px(46, 1, "o"); c.px(49, 2, "R")

    // Stone plinth and two plaster planes meet at a strong projecting corner.
    c.poly([10, 29, 35, 42, 35, 65, 12, 59], "c")
    c.poly([35, 42, 61, 28, 61, 57, 35, 65], "C")
    c.poly([10, 59, 35, 65, 35, 70, 10, 64], "s")
    c.poly([35, 65, 61, 57, 61, 63, 35, 70], "s")
    c.line(11, 61, 35, 67, "D"); c.line(36, 67, 60, 60, "D")
    c.line(11, 63, 35, 69, "h"); c.line(36, 69, 60, 62, "h")
    for (let x = 15; x < 34; x += 8) c.line(x, 62 + Math.floor((x - 11) / 4), x, 64 + Math.floor((x - 11) / 4), "D")
    for (let x = 41; x < 60; x += 8) c.line(x, 65 - Math.floor((x - 35) / 4), x, 67 - Math.floor((x - 35) / 4), "D")

    // Recessed timber framing follows each wall plane and catches upper-left sun.
    c.line(12, 32, 34, 44, "t"); c.line(36, 44, 59, 31, "t")
    c.line(13, 55, 34, 61, "u"); c.line(37, 61, 59, 54, "D")
    c.vline(13, 35, 23, "u"); c.vline(34, 46, 15, "T")
    c.vline(58, 34, 20, "D")
    c.hline(17, 39, 12, "C"); c.hline(40, 43, 13, "D")

    // Four sloping roof planes make a low hip rather than a flat front gable.
    c.poly([35, 7, 8, 26, 35, 41], "r")
    c.poly([35, 7, 62, 24, 35, 41], "R")
    c.poly([35, 7, 8, 26, 13, 29, 35, 15], "o")
    c.poly([35, 7, 62, 24, 57, 28, 35, 15], "r")
    c.line(35, 8, 9, 27, "p"); c.line(35, 9, 60, 25, "o")
    c.line(11, 29, 35, 43, "R"); c.line(35, 43, 60, 29, "P")
    for (let y = 17; y < 30; y += 4) {
      const reach = Math.floor((y - 7) * 1.15)
      const ridgeY = y + Math.floor((y - 7) * 0.45)
      c.line(35 - reach, y, 35, ridgeY, y < 22 ? "o" : "R")
      c.line(35, ridgeY, 35 + reach, y, y < 22 ? "r" : "P")
    }
    // Deep eaves throw one continuous shadow over both plaster faces.
    c.line(8, 26, 35, 42, "T"); c.line(35, 42, 62, 24, "T")
    c.line(9, 28, 35, 44, "u"); c.line(35, 44, 61, 27, "u")

    // Asymmetric windows: one opens to the lane, one to the sheltered side.
    A.wins.forEach(([x, y, w, h, o]) => win(c, x, y, w, h, o))
    c.stamp("_box_red", 13, 52)
    c.rect(42, 52, 10, 2, "d"); c.hline(42, 53, 10, "t")

    // A small covered porch projects from the angled front wall.
    c.poly([20, 45, 29, 42, 38, 47, 28, 52], "T")
    c.poly([20, 45, 29, 42, 29, 45, 21, 48], "u")
    c.line(20, 45, 29, 42, "w"); c.line(29, 42, 38, 47, "D")
    c.rect(21, 47, 2, 16, "t"); c.vline(21, 47, 16, "w")
    c.rect(36, 48, 2, 15, "t"); c.vline(36, 48, 15, "u")
    door(c, 26, 49, 9, 20, ["N", "B", "b"], { arch: "c", pane: A.doorPane })
    c.line(22, 63, 36, 67, "s"); c.line(22, 65, 36, 69, "h")
    c.stamp("_lantern", 38, 45)
    // The shaded wall gets a drain and a stacked wood niche, not filler speckle.
    c.vline(55, 34, 17, "D"); c.px(54, 51, "D"); c.px(56, 53, "D")
    c.rect(45, 55, 7, 3, "d"); c.hline(45, 55, 7, "u"); c.hline(45, 58, 7, "T")
  }, outline)

  sprite("house-cottage_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of A.wins) litwin(c, x, y, w, h, o)
    const [px_, py, pw, ph] = A.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
    for (const [x, y, w, h] of A.lamps) { c.rect(x, y, w, h, "y"); c.px(x, y, "w") }
  })

  // ================================================================ house-studio
  // Thatched round-eave cottage: a domed roof of straw strands over a plaster wall.
  const B = {
    wins: [[14, 43, 8, 10, {}], [44, 42, 8, 10, {}]],
    doorPane: [27, 52, 3, 3],
  }
  sprite("house-studio", { w: W, h: H }, (c) => {
    // A rear stone flue, visible above the thatch rather than pasted on its face.
    stones(c, 46, 6, 7, 20, { rh: 3, widths: [3, 4, 5] })
    c.vline(46, 7, 17, "h"); c.vline(51, 7, 17, "D")
    c.rect(45, 3, 9, 3, "s"); c.hline(45, 3, 9, "h"); c.hline(46, 5, 7, "D")

    // Two plaster walls meet at a sunlit corner; the right wall recedes in shade.
    c.poly([10, 29, 35, 42, 35, 65, 12, 59], "c")
    c.poly([35, 42, 61, 28, 61, 57, 35, 65], "C")
    c.poly([10, 59, 35, 65, 35, 70, 10, 64], "s")
    c.poly([35, 65, 61, 57, 61, 63, 35, 70], "s")
    c.line(11, 61, 35, 67, "D"); c.line(36, 67, 60, 60, "D")
    c.line(11, 63, 35, 69, "h"); c.line(36, 69, 60, 62, "h")

    // A broad half-round reed roof is a distinct silhouette from the inn's
    // hipped roof. Concentric courses follow its curve; the right half turns
    // into shade as it recedes from the upper-left sun.
    const roofCenter = 31, roofTop = 6, roofBase = 38, roofRadius = 31
    const roofSpan = (y) => Math.sqrt(Math.max(0, 1 - (1 - (y - roofTop) / (roofBase - roofTop)) ** 2))
    for (let y = roofTop; y < roofBase; y++) {
      const reach = Math.round(roofRadius * roofSpan(y))
      const left = Math.max(0, roofCenter - reach)
      const right = Math.min(63, roofCenter + reach)
      for (let x = left; x <= right; x++) {
        const side = (x - roofCenter) / Math.max(1, reach)
        const warm = side < -0.48 ? "w" : side < 0.06 ? "y" : side < 0.62 ? "u" : "d"
        c.px(x, y, warm)
      }
    }
    for (let y = 13; y < roofBase - 2; y += 4) {
      const reach = Math.round(roofRadius * roofSpan(y))
      const left = Math.max(2, roofCenter - reach + 3)
      const right = Math.min(61, roofCenter + reach - 3)
      if (right > left) c.hline(left, y, right - left, y < 22 ? "d" : "t")
      if (left < roofCenter) c.px(left + 2, y - 1, "w")
      if (right > roofCenter) c.px(right - 2, y - 1, "u")
    }
    // Reed tips and a dark under-eave keep the large round roof grounded.
    c.hline(1, 36, 61, "u"); c.hline(2, 38, 59, "t"); c.hline(4, 39, 55, "T")
    for (let x = 4; x < 60; x += 5) c.vline(x, 36 + (x % 2), 3, x < roofCenter ? "y" : "d")

    // Timber braces, a pair of differently oriented windows and a recessed door.
    c.line(13, 34, 34, 46, "u"); c.line(37, 46, 59, 33, "D")
    c.vline(13, 36, 21, "u"); c.vline(34, 46, 15, "T"); c.vline(58, 35, 19, "D")
    c.line(13, 56, 34, 62, "t"); c.line(37, 62, 58, 55, "D")
    B.wins.forEach(([x, y, w, h, o]) => win(c, x, y, w, h, o))
    c.stamp("_box_white", 13, 52)
    c.rect(43, 52, 10, 2, "d"); c.hline(43, 53, 10, "t")
    c.poly([20, 45, 29, 42, 38, 47, 28, 52], "t")
    c.poly([20, 45, 29, 42, 29, 45, 21, 48], "u")
    c.line(20, 45, 29, 42, "w"); c.line(29, 42, 38, 47, "D")
    c.rect(21, 47, 2, 16, "T"); c.vline(21, 47, 16, "u")
    c.rect(36, 48, 2, 15, "T"); c.vline(36, 48, 15, "t")
    door(c, 26, 49, 9, 20, ["N", "t", "u"], { arch: "t", pane: B.doorPane })
    c.line(22, 63, 36, 67, "s"); c.line(22, 65, 36, 69, "h")
    c.stamp("_lantern", 38, 45)
    // A hanging sign names a working studio; timber stacks under its sheltered wall.
    c.vline(55, 42, 8, "T"); c.hline(49, 42, 7, "T")
    c.rect(49, 49, 7, 5, "u"); c.hline(49, 49, 7, "y"); c.hline(49, 53, 7, "T")
    c.px(51, 51, "T"); c.px(54, 51, "T")
    c.rect(43, 56, 9, 3, "d"); c.hline(43, 56, 9, "u"); c.hline(43, 59, 9, "T")
  }, outline)
  sprite("house-studio_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of B.wins) litwin(c, x, y, w, h, o)
    const [px_, py, pw, ph] = B.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
  })

  // ================================================================ house-workshop
  // Tall three-quarter timber shop. Its steep roof and narrow shaded wall
  // distinguish it from the low inn and round thatched studio.
  const C = {
    wins: [[14, 46, 7, 8, {}], [45, 38, 7, 8, {}]],
    doorPane: [27, 56, 3, 3],
  }
  sprite("house-workshop", { w: W, h: H }, (c) => {
    stones(c, 47, 11, 8, 18, { rh: 3, widths: [4, 5, 3] })
    c.vline(47, 12, 16, "h"); c.vline(53, 12, 16, "D")
    c.rect(46, 9, 10, 3, "s"); c.hline(46, 9, 10, "h")
    // Two steep slate planes meet at a high ridge and share the valley light.
    c.poly([36, 3, 8, 26, 36, 40], "N")
    c.poly([36, 3, 60, 20, 36, 40], "D")
    c.poly([36, 3, 8, 26, 14, 29, 36, 12], "V")
    c.poly([36, 3, 60, 20, 55, 24, 36, 12], "N")
    c.line(36, 4, 9, 27, "h"); c.line(37, 5, 59, 21, "C")
    for (let y = 13; y < 30; y += 4) {
      const reach = Math.floor((y - 3) * 1.16)
      const ridgeY = y + Math.floor((y - 3) * 0.43)
      c.line(36 - reach, y, 36, ridgeY, y < 21 ? "V" : "C")
      c.line(36, ridgeY, 36 + reach, y, y < 21 ? "N" : "D")
    }
    c.line(8, 26, 36, 41, "T"); c.line(36, 41, 60, 22, "T")
    c.line(10, 29, 36, 44, "u"); c.line(36, 44, 58, 25, "u")
    // Plaster front and shaded side share one strong projecting corner.
    c.poly([13, 31, 36, 43, 36, 66, 13, 58], "c")
    c.poly([36, 43, 56, 29, 56, 56, 36, 66], "C")
    c.poly([13, 58, 36, 66, 36, 71, 13, 64], "s")
    c.poly([36, 66, 56, 56, 56, 62, 36, 71], "s")
    c.line(14, 61, 36, 68, "D"); c.line(37, 68, 55, 60, "D")
    c.line(16, 34, 34, 44, "u"); c.line(38, 44, 54, 33, "D")
    c.vline(15, 36, 22, "u"); c.vline(35, 45, 18, "T"); c.vline(54, 34, 20, "D")
    c.line(16, 54, 34, 61, "t"); c.line(38, 61, 54, 52, "D")
    for (const [x, y, w, h, o] of C.wins) {
      win(c, x, y, w, h, o)
      c.rect(x - 1, y + h, w + 2, 2, "d"); c.hline(x - 1, y + h + 1, w + 2, "t")
    }
    // Deep shop canopy, stout posts and a door opening onto the public lane.
    c.poly([19, 45, 26, 41, 36, 46, 28, 51], "T")
    c.poly([19, 45, 26, 41, 26, 44, 20, 48], "u")
    c.line(20, 48, 28, 52, "D"); c.line(28, 52, 35, 47, "T")
    c.rect(20, 47, 2, 11, "t"); c.vline(20, 47, 11, "u")
    c.rect(34, 48, 2, 12, "T"); c.vline(34, 48, 12, "u")
    door(c, 23, 50, 10, 20, ["N", "B", "b"], { arch: "t", pane: C.doorPane })
    // A bracketed sign sits on the receding wall beneath its deep eave.
    c.vline(52, 49, 7, "T"); c.hline(46, 49, 7, "T")
    c.rect(46, 56, 8, 5, "u"); c.hline(46, 56, 8, "y"); c.hline(46, 60, 8, "T")
    c.px(48, 58, "T"); c.px(51, 58, "T")
    c.stamp("_box_white", 13, 55)
  }, outline)
  sprite("house-workshop_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of C.wins) litwin(c, x, y, w, h, o)
    const [px_, py, pw, ph] = C.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
  })

  // ================================================================ house-tower
  // Stone tower-house in three-quarter view: a steep split roof, dormer and
  // shaded return wall give this silhouette a different scale from the shop.
  const D = {
    wins: [[14, 44, 8, 9, {}], [45, 39, 8, 9, {}], [24, 25, 8, 8, { sill: false }]],
    doorPane: [28, 56, 3, 3],
  }
  sprite("house-tower", { w: W, h: H }, (c) => {
    stones(c, 47, 9, 8, 18, { rh: 3, widths: [4, 5, 3] })
    c.vline(47, 10, 16, "h"); c.vline(53, 10, 16, "D")
    c.rect(46, 7, 10, 3, "s"); c.hline(46, 7, 10, "h")
    // Two slate roof planes meet above the projecting corner.
    c.poly([35, 4, 7, 27, 35, 42], "N")
    c.poly([35, 4, 61, 22, 35, 42], "D")
    c.poly([35, 4, 7, 27, 13, 30, 35, 13], "V")
    c.poly([35, 4, 61, 22, 56, 26, 35, 13], "N")
    c.line(35, 5, 8, 28, "h"); c.line(36, 6, 60, 23, "C")
    for (let y = 14; y < 31; y += 4) {
      const reach = Math.floor((y - 4) * 1.1)
      const ridgeY = y + Math.floor((y - 4) * 0.48)
      c.line(35 - reach, y, 35, ridgeY, y < 22 ? "V" : "C")
      c.line(35, ridgeY, 35 + reach, y, y < 22 ? "N" : "D")
    }
    c.line(7, 27, 35, 43, "T"); c.line(35, 43, 61, 23, "T")
    c.line(9, 30, 35, 45, "u"); c.line(35, 45, 59, 26, "u")
    // Pale limestone front and a cooler side plane, both with coursed joints.
    c.poly([11, 30, 35, 43, 35, 65, 12, 58], "c")
    c.poly([35, 43, 60, 27, 60, 56, 35, 65], "C")
    c.poly([12, 58, 35, 65, 35, 70, 12, 64], "s")
    c.poly([35, 65, 60, 56, 60, 62, 35, 70], "s")
    for (const y of [39, 46, 53]) {
      c.line(12, y, 34, y + 12, "h")
      c.line(36, y + 13, 59, y - 2, "D")
    }
    for (const x of [18, 26, 32]) c.line(x, 35 + Math.floor((x - 11) * 0.54), x, 39 + Math.floor((x - 11) * 0.54), "s")
    for (const x of [41, 49, 56]) c.line(x, 49 - Math.floor((x - 35) * 0.64), x, 53 - Math.floor((x - 35) * 0.64), "D")
    c.vline(12, 33, 24, "h"); c.vline(34, 44, 18, "T"); c.vline(59, 30, 24, "D")
    c.line(12, 60, 35, 67, "D"); c.line(36, 67, 59, 59, "D")
    // Repaint the dormer in front of the limestone courses, as a real
    // projection from the roof rather than a window buried in the wall.
    c.poly([19, 27, 26, 20, 34, 27], "N")
    c.line(26, 20, 19, 27, "h"); c.line(27, 21, 33, 27, "D")
    c.rect(22, 27, 10, 10, "c"); c.rect(29, 27, 3, 10, "C")
    win(c, 24, 25, 8, 8, { sill: false })
    // Ivy follows the sunny outer corner rather than covering a window.
    const ivy = (x, y) => { c.circ(x, y, 2, "F"); c.px(x - 1, y - 1, "G"); c.px(x + 1, y + 1, "S") }
    for (const [x, y] of [[13, 43], [15, 48], [14, 54], [17, 58]]) ivy(x, y)
    for (const [x, y, w, h, o] of D.wins) {
      if (y === 24) continue
      win(c, x, y, w, h, o)
      c.rect(x - 1, y + h, w + 2, 2, "s"); c.hline(x - 1, y + h + 1, w + 2, "D")
    }
    c.rect(24, 47, 13, 23, "s"); c.rect(25, 48, 11, 22, "e")
    door(c, 26, 49, 10, 21, ["N", "t", "u"], { arch: "s", pane: D.doorPane })
    c.line(24, 69, 37, 69, "h")
  }, outline)
  sprite("house-tower_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of D.wins) litwin(c, x, y, w, h, o)   // includes the dormer pane
    const [px_, py, pw, ph] = D.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
  })
}
