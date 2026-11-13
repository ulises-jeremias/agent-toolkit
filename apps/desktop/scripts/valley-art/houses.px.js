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
  // Terracotta gable cottage: plaster over a stone footing, river-blue door, two flower boxes.
  const A = {
    wins: [[13, 45, 9, 11, {}], [42, 45, 9, 11, {}], [28, 24, 8, 9, { arch: "c", cols: 2, rows: 1 }]],
    doorPane: [30, 51, 4, 3],
    lamps: [[40, 50, 2, 3]],
  }
  // Gable roof band: column x is `i` steps from the ridge; the band is `thick` px measured vertically.
  const gable = (c, { ridge, top, span, thick }, paint) => {
    for (let i = 0; i <= span; i++)
      for (const side of [-1, 1]) {
        const x = side < 0 ? ridge - i : ridge + 1 + i
        for (let d = 0; d < thick; d++) c.px(x, top + i + d, paint(side, i, d))
      }
  }
  sprite("house-cottage", { w: W, h: H }, (c) => {
    // chimney first, so the roof overlaps its foot
    stones(c, 43, 6, 7, 20, { rh: 3, widths: [4, 3, 5] })
    c.vline(43, 6, 20, "h"); c.vline(48, 6, 20, "D"); c.vline(49, 6, 20, "N")
    c.rect(42, 3, 9, 3, "s"); c.hline(42, 3, 9, "h"); c.hline(43, 5, 8, "D"); c.px(50, 4, "D")
    c.rect(45, 1, 3, 2, "r"); c.px(45, 1, "o"); c.px(47, 2, "R")       // clay pot = smoke mouth

    // gable wall + lower wall
    c.poly([32, 14, 55, 37, 55, 65, 9, 65, 9, 37], "c")
    c.poly([32, 14, 9, 37, 9, 40, 32, 17], "C")                       // roof shadow rakes down the left gable
    c.poly([32, 14, 33, 14, 55, 36, 55, 37], "C")
    // tie beam
    c.rect(8, 38, 48, 3, "t"); c.hline(8, 38, 48, "u"); c.hline(8, 40, 48, "T")
    c.hline(9, 41, 46, "C"); c.hline(11, 42, 42, "C")                 // its shadow on the plaster
    // corner posts
    for (const x of [9, 53]) { c.rect(x, 41, 2, 24, "t"); c.vline(x, 41, 24, "u") }
    c.vline(52, 43, 22, "C")
    // footing
    stones(c, 8, 65, 48, 6, { rh: 3 })

    // roof
    gable(c, { ridge: 31, top: 7, span: 27, thick: 7 }, (side, i, d) => {
      if (d === 6) return side < 0 ? "R" : "P"                         // underside
      const seam = (2 * i + d) % 8 === 0 && d > 0
      if (side < 0) return d === 0 ? "p" : seam ? "R" : d === 1 ? "o" : "r"
      return d === 0 ? "o" : seam ? "P" : d === 1 ? "r" : "R"
    })

    for (const [x, y, w, h, o] of A.wins) win(c, x, y, w, h, o)
    door(c, 27, 47, 10, 24, ["N", "B", "b"], { arch: "c", pane: A.doorPane })
    c.rect(25, 69, 14, 2, "s"); c.hline(25, 69, 14, "h")              // doorstep
    c.stamp("_box_red", 12, 54); c.stamp("_box_white", 41, 54)
    c.hline(14, 60, 10, "C"); c.hline(43, 60, 10, "C")                // box shadows
    c.stamp("_lantern", 38, 46)
  }, outline)

  sprite("house-cottage_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of A.wins) litwin(c, x, y, w, h, o)
    const [px_, py, pw, ph] = A.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
    for (const [x, y, w, h] of A.lamps) { c.rect(x, y, w, h, "y"); c.px(x, y, "w") }
  })

  // ================================================================ house-studio
  // Thatched round-eave cottage: a domed roof of straw strands over a plaster wall.
  const dome = (c, cx, cy, rx, ry, paint) => {
    for (let y = cy - ry; y <= cy; y++) {
      const hw = Math.round(rx * Math.sqrt(1 - ((cy - y) / ry) ** 2))
      for (let x = cx - hw; x <= cx + hw; x++) c.px(x, y, paint(x, y))
    }
  }
  const B = {
    wins: [[10, 46, 9, 10, {}], [45, 46, 9, 10, {}]],
    doorPane: [30, 51, 4, 3],
  }
  sprite("house-studio", { w: W, h: H }, (c) => {
    c.stamp("_lantern", 4, 44)                                        // sign bracket lantern left
    stones(c, 44, 10, 7, 13, { rh: 3, widths: [3, 4, 5] })              // stone chimney
    c.vline(44, 10, 13, "h"); c.vline(50, 10, 13, "D"); c.rect(43, 9, 9, 2, "s"); c.hline(43, 9, 9, "h")
    // straw dome: strands run diagonally, lit toward the upper left
    dome(c, 32, 36, 30, 28, (x, y) => {
      if ((x + y) % 6 === 0) return "t"                               // strand shadow
      if ((x - y) % 9 === 0) return "u"                               // bundled ridge
      return x < 26 + (y - 8) * 0.3 ? "y" : "d"
    })
    // eave: the straw thickens into a dark band, then the wall
    c.rect(2, 36, 60, 3, "t"); c.hline(2, 36, 60, "u"); c.hline(2, 38, 60, "T")
    c.rect(8, 39, 48, 25, "c")
    c.rect(48, 39, 8, 25, "C")
    stones(c, 6, 63, 52, 7, { rh: 3 })
    for (const [x, y, w, h, o] of B.wins) {
      win(c, x, y, w, h, { ...o, sill: false })
      c.rect(x - 1, y + h, w + 2, 2, "d"); c.hline(x - 1, y + h + 1, w + 2, "t")
    }
    door(c, 27, 47, 10, 23, ["N", "t", "d"], { arch: "t", pane: B.doorPane })
    c.stamp("_box_red", 8, 56)
    c.hline(8, 62, 11, "C")
    // hanging sign on a bracket: a timber board with two ink pixels as text
    c.vline(52, 52, 6, "T"); c.hline(47, 52, 6, "T"); c.hline(47, 54, 5, "t")
    c.rect(48, 56, 6, 4, "u"); c.hline(48, 56, 6, "y"); c.hline(48, 59, 6, "T"); c.px(50, 57, "T"); c.px(52, 57, "T")
  }, outline)
  sprite("house-studio_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of B.wins) litwin(c, x, y, w, h, o)
    const [px_, py, pw, ph] = B.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
  })

  // ================================================================ house-workshop
  // Tall timber-frame house with a steep slate roof and a hanging sign.
  const C = {
    wins: [[20, 27, 8, 9, {}], [36, 27, 8, 9, {}], [19, 47, 8, 10, {}]],
    doorPane: [31, 51, 3, 3],
  }
  sprite("house-workshop", { w: W, h: H }, (c) => {
    // steep slate roof: cool blue-grey, rim light on the left slope
    c.poly([32, 3, 9, 26, 55, 26], "N")
    c.poly([32, 3, 9, 26, 15, 26, 32, 6], "D")
    c.clip([32, 3, 9, 26, 55, 26], () => {                           // courses stay inside the roof
      for (let y = 10; y < 26; y += 3) c.hline(0, y, 64, "V")
    })
    c.rect(43, 6, 4, 9, "e"); c.hline(43, 6, 4, "C")                  // brick chimney above roof
    // timber-frame body
    c.rect(14, 26, 36, 46, "c")
    c.rect(44, 26, 6, 46, "C")
    for (const x of [14, 31, 47]) { c.rect(x, 26, 3, 46, "t"); c.vline(x, 26, 46, "u") }
    for (const y of [26, 45, 62]) { c.rect(14, y, 36, 2, "t"); c.hline(14, y, 36, "u") }
    // footing
    stones(c, 12, 66, 40, 6, { rh: 3 })                                // footing sits on the ground line
    for (const [x, y, w, h, o] of C.wins) {
      win(c, x, y, w, h, o)
      c.rect(x - 1, y + h, w + 2, 2, "d"); c.hline(x - 1, y + h + 1, w + 2, "t")
    }
    door(c, 27, 47, 10, 22, ["N", "B", "b"], { arch: "t", pane: C.doorPane })
    // hanging sign: a bracket with a painted board
    c.hline(9, 41, 6, "T"); c.vline(9, 41, 6, "T")
    c.rect(8, 46, 8, 5, "u"); c.hline(8, 46, 8, "y"); c.hline(8, 50, 8, "T"); c.px(10, 48, "T"); c.px(13, 48, "T")
    c.stamp("_box_white", 36, 37)
  }, outline)
  sprite("house-workshop_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of C.wins) litwin(c, x, y, w, h, o)
    const [px_, py, pw, ph] = C.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
  })

  // ================================================================ house-tower
  // Stone cottage with a slate roof, a dormer window and a climbing ivy wall on the left.
  const D = {
    wins: [[11, 44, 9, 11, {}], [44, 44, 9, 11, {}], [27, 20, 9, 9, {}]],
    doorPane: [30, 50, 4, 4],
  }
  sprite("house-tower", { w: W, h: H }, (c) => {
    stones(c, 46, 10, 8, 16, { rh: 4, widths: [4, 5, 3] })              // stone chimney
    c.vline(46, 10, 16, "h"); c.vline(53, 10, 16, "D")
    c.rect(45, 8, 10, 2, "s"); c.hline(45, 8, 10, "h")
    // slate roof gable, ridge highlight on the sunward slope
    c.poly([32, 6, 2, 36, 62, 36], "N")
    c.poly([32, 6, 2, 36, 8, 36, 32, 8], "D")
    c.line(32, 6, 2, 36, "h")
    c.clip([32, 6, 2, 36, 62, 36], () => {                           // slate courses inside the gable
      for (let y = 14; y < 36; y += 4) c.hline(0, y, 64, "V")
    })
    // dormer: small plaster box with its own gable cap
    c.rect(24, 22, 17, 13, "c")
    c.rect(37, 22, 4, 13, "C")
    c.poly([22, 22, 32, 14, 43, 22], "N")
    c.hline(22, 22, 22, "D")
    win(c, 27, 20, 9, 9, { sill: false })                               // sits in the dormer
    // stone walls
    stones(c, 4, 36, 56, 30, { rh: 4 })
    // ivy up the left wall: clusters, lit upper-left and darker below
    const ivy = (x, y) => { c.circ(x, y, 2, "F"); c.px(x - 1, y - 1, "G"); c.px(x + 1, y + 1, "S") }
    for (const [x, y] of [[7, 46], [10, 42], [6, 52], [9, 58], [5, 37]]) ivy(x, y)
    c.vline(8, 37, 8, "S")
    for (const [x, y, w, h, o] of D.wins) {
      if (y === 20) continue
      win(c, x, y, w, h, o)
      c.rect(x - 1, y + h, w + 2, 2, "s"); c.hline(x - 1, y + h + 1, w + 2, "D")
    }
    // stone door surround and oak door
    c.rect(25, 46, 14, 24, "s")
    c.rect(26, 46, 12, 23, "e")
    door(c, 27, 47, 10, 22, ["N", "t", "u"], { arch: "s", pane: D.doorPane })
    c.hline(25, 69, 14, "h")
  }, outline)
  sprite("house-tower_lit", { w: W, h: H }, (c) => {
    for (const [x, y, w, h, o] of D.wins) litwin(c, x, y, w, h, o)   // includes the dormer pane
    const [px_, py, pw, ph] = D.doorPane
    c.rect(px_, py, pw, ph, "l"); c.px(px_, py, "y")
  })
}
