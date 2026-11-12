// Landmarks: the Library (tallest), the Workshop (watermill + forge), the Lodge (People hall).
// Each *_lit overlay repaints only the glowing panes, registered at 0,0 to its base sprite.
include("lib.px.js")

{
  const { outline, stones, tiles, planks, win, litwin, halo } = VA
  const rng = (seed) => { let s = seed; return () => ((s = (s * 16807) % 2147483647) / 2147483647) }

  // ================================================================ library (80x104)
  // Stone tower with a slate pyramid, flanked by two timber-frame wings. Tall arched windows
  // show book spines. The nest sits on a stone ledge under the roof, so the hornero is home.
  const LIB = {
    tower: [26, 22, 28, 82],
    wins: [[33, 30, 14, 22], [33, 60, 14, 18]],  // tall arched windows (x,y,w,h)
    wingWins: [[8, 70, 8, 10], [60, 70, 8, 10], [8, 52, 8, 8], [60, 52, 8, 8]],
    door: [36, 88, 8, 16],
    nest: [23, 27, 4],                            // centre x,y and radius
  }
  const spines = (c, x, y, w, h, seed) => {
    const r = rng(seed), cols = ["r", "u", "F", "t", "P", "G", "i", "c"]
    for (let xx = x; xx < x + w; xx += 1 + Math.floor(r() * 2)) {
      const bh = 3 + Math.floor(r() * 3)
      c.vline(xx, y + h - bh, bh, cols[Math.floor(r() * cols.length)])
    }
    for (let yy = y + 6; yy < y + h - 1; yy += 6) c.hline(x, yy, w, "T")  // shelves
  }
  const arch = (c, x, y, w, h, seed) => {
    c.rect(x, y, w, h, "T")
    c.rect(x + 1, y + 1, w - 2, h - 1, "N")
    c.hline(x + 1, y, w - 2, "T")
    c.px(x, y, "s"); c.px(x + w - 1, y, "s")          // rounded top corners read as stone
    c.px(x + 1, y + 1, "T"); c.px(x + w - 2, y + 1, "T")
    spines(c, x + 2, y + 2, w - 4, h - 3, seed)
    c.vline(x + w - 2, y + 2, h - 3, "D")               // light falls from the left
    c.hline(x, y + h, w, "s")
  }
  sprite("library", { w: 80, h: 104 }, (c) => {
    // wings: timber frame over plaster, with brick roofs
    for (const wx of [2, 54]) {
      c.rect(wx, 60, 24, 44, "c")
      c.rect(wx + 20, 60, 4, 44, "C")                     // shade on the wing's inner-right face
      planks(c, wx, 60, 24, 44, { pw: 6, base: "c", seam: "C" })   // faint board lines, not noise
      for (const y of [60, 80]) { c.rect(wx, y, 24, 2, "t"); c.hline(wx, y, 24, "u") }
      c.vline(wx, 60, 44, "t"); c.vline(wx + 23, 60, 44, "t")
      stones(c, wx - 1, 96, 26, 8, { rh: 4 })
    }
    c.poly([0, 62, 14, 46, 28, 62], "P")
    c.poly([54, 62, 66, 46, 80, 62], "P")
    c.poly([0, 62, 14, 46, 14, 47, 1, 62], "R")          // wing roof shadow on the right slope
    c.poly([54, 62, 66, 46, 66, 47, 55, 62], "R")
    for (const [x, y, w, h] of LIB.wingWins) win(c, x, y, w, h, { sill: false })

    // central tower: stone blocks, pyramid roof, clay ridge
    const [tx, ty, tw, th] = LIB.tower
    stones(c, tx, ty, tw, th, { rh: 4, widths: [6, 8, 5, 7, 9] })
    c.vline(tx, ty, th, "h")                             // sun on the left edge of the stone
    c.vline(tx + tw - 1, ty, th, "D")
    c.poly([40, 2, 23, 24, 57, 24], "P")
    c.clip([40, 2, 23, 24, 57, 24], () => {
      for (let y = 6; y < 24; y += 4) c.hline(0, y, 80, "R")
      for (let y = 6; y < 24; y += 4) for (let x = 0; x < 80; x += 4) if ((x + (y % 8 ? 2 : 0)) % 8 === 0) c.px(x, y - 1, "P")
    })
    c.poly([40, 2, 23, 24, 26, 24, 40, 4], "R")          // shadow on the sunless side
    c.hline(23, 24, 34, "P")                             // eave line
    // ledge and nest on the top left of the tower
    c.rect(18, 31, 12, 2, "h"); c.hline(18, 33, 12, "D")
    const [nx, ny, nr] = LIB.nest
    c.circ(nx, ny, nr, "u"); c.circ(nx + 1, ny + 1, nr - 1, "t")   // dome of mud
    c.ring(nx, ny, nr, "T")
    c.rect(nx - 1, ny + 1, 2, 2, "T")                    // entrance tube at the bottom left
    c.px(nx - 2, ny - 2, "y"); c.px(nx - 1, ny - 3, "y") // sunlit crown of straw

    // tall arched windows and the door
    LIB.wins.forEach(([x, y, w, h], i) => arch(c, x, y, w, h, 40 + i))

    // door: arched, ink-dark plank leaves
    const [dx, dy, dw, dh] = LIB.door
    c.rect(dx - 1, dy - 1, dw + 2, dh + 1, "s"); c.hline(dx - 1, dy - 1, dw + 2, "h")
    planks(c, dx, dy, dw, dh, { pw: 2, base: "T", seam: "N", hi: "t" })
    c.rect(dx, dy - 2, dw, 2, "s"); c.px(dx + 3, dy + 6, "l")

    // hanging open-book sign on a bracket from the left stonework
    c.hline(22, 40, 4, "T"); c.vline(25, 40, 4, "T"); c.px(22, 40, "T")
    c.rect(12, 44, 12, 7, "r"); c.rect(13, 45, 4, 5, "c"); c.rect(18, 45, 4, 5, "c")
    c.vline(17, 45, 5, "R"); c.hline(13, 49, 4, "e"); c.hline(18, 49, 4, "e")
    c.hline(12, 51, 12, "R")

    // ground stones
    stones(c, 0, 96, 80, 8, { rh: 4, widths: [5, 8, 6, 7] })
    c.hline(0, 103, 80, "N")
  }, outline)

  sprite("library_lit", { w: 80, h: 104 }, (c) => {
    for (const [x, y, w, h] of LIB.wins) {
      c.rect(x + 1, y + 1, w - 2, h - 1, "o")
      c.hline(x + 1, y + 1, w - 2, "l")
      c.px(x + 2, y + 2, "y"); c.px(x + 3, y + 3, "y")
      for (let yy = y + 6; yy < y + h - 1; yy += 6) c.hline(x + 1, yy, w - 2, "l")
    }
    for (const [x, y, w, h] of LIB.wingWins) { c.rect(x + 1, y + 1, w - 2, h - 2, "l"); c.px(x + 1, y + 1, "y") }
    const [dx, dy, dw] = LIB.door
    c.px(dx + 3, dy + 6, "y"); c.px(dx + 4, dy + 6, "w")
    halo(c)
  })

  // ================================================================ workshop (96x80)
  // Watermill shed with a big door and a forge chimney. The wheel's hub sits at (20,44),
  // on the left edge, and the wheel itself is drawn in effects.px.js around that centre.
  const WS = {
    body: [32, 34, 60, 46],
    door: [52, 46, 22, 33],
    hub: [20, 44],
    forge: [72, 44],                           // forge glow centre (inside the door)
    wins: [[36, 40, 8, 8], [76, 40, 8, 8]],
  }
  sprite("workshop", { w: 96, h: 80 }, (c) => {
    const [hx, hy] = WS.hub
    // axle and hub: the wheel attaches here
    c.hline(hx, hy - 1, 14, "T"); c.hline(hx, hy, 14, "t")
    c.circ(hx, hy, 3, "T"); c.circ(hx - 1, hy - 1, 2, "t"); c.px(hx, hy, "u")

    // shed body: vertical planks, sun on the left board edges
    const [bx, by, bw, bh] = WS.body
    planks(c, bx, by, bw, bh, { pw: 5, base: "t", seam: "T", hi: "u" })
    c.vline(bx, by, bh, "u")
    c.rect(bx, by + bh - 4, bw, 4, "T")                 // plinth in shadow
    c.hline(bx, by + bh - 4, bw, "t")

    // roof: terracotta tile over the shed
    c.poly([28, 36, 62, 6, 96, 36], "r")
    c.clip([28, 36, 62, 6, 96, 36], () => {
      for (let y = 8; y < 36; y += 4) c.hline(0, y, 96, "R")
      for (let y = 9; y < 36; y += 4) for (let x = 0; x < 96; x += 4) c.px(x + ((y >> 2) % 2) * 2, y, "o")
    })
    c.hline(28, 36, 68, "R")                             // eave

    // stone forge chimney, rising past the roof
    stones(c, 70, 8, 7, 20, { rh: 3, widths: [4, 3, 5] })
    c.vline(70, 8, 20, "h"); c.vline(76, 8, 20, "D")
    c.rect(69, 6, 9, 2, "s"); c.hline(69, 6, 9, "h")

    // side windows
    for (const [x, y, w, h] of WS.wins) win(c, x, y, w, h, { sill: false })

    // big door: two leaves hung open, a dark forge inside
    const [dx, dy, dw, dh] = WS.door
    c.rect(dx - 1, dy - 1, dw + 2, dh + 1, "T")
    c.rect(dx, dy, dw, dh, "N")
    c.rect(dx, dy + dh - 9, dw, 9, "D")                  // forge floor catches the fire
    c.vline(dx + Math.floor(dw / 2), dy, dh, "T")
    planks(c, dx, dy, Math.floor(dw / 2) - 1, dh, { pw: 4, base: "t", seam: "T", hi: "u" })
    planks(c, dx + Math.floor(dw / 2) + 1, dy, dw - Math.floor(dw / 2) - 1, dh, { pw: 4, base: "t", seam: "T", hi: "u" })

    // anvil and crates outside on the right
    c.rect(84, 66, 9, 3, "N"); c.hline(84, 66, 9, "h"); c.rect(82, 69, 13, 5, "N")
    c.rect(81, 74, 14, 2, "T"); c.hline(81, 74, 14, "t")
    for (const [x, y] of [[80, 60], [86, 60]]) {
      c.rect(x, y, 6, 6, "t"); c.box(x, y, 6, 6, "T"); c.hline(x, y, 6, "u")
    }
    c.rect(77, 70, 4, 9, "u"); c.vline(77, 70, 9, "t")   // a tall sack or crate end
    c.hline(0, 79, 96, "T")                              // ground line: shadowed bottom edge
  }, outline)

  sprite("workshop_lit", { w: 96, h: 80 }, (c) => {
    const [dx, dy, dw, dh] = WS.door
    c.rect(dx + 2, dy + dh - 9, dw - 4, 6, "o")
    c.rect(dx + 4, dy + dh - 7, dw - 8, 4, "y")
    c.px(dx + 6, dy + dh - 8, "w")
    for (const [x, y, w, h] of WS.wins) litwin(c, x, y, w, h, { sill: false })
    c.px(72, 4, "w")
    halo(c)
  })

  // ================================================================ lodge (96x76)
  // The People hall: a long plaster hall, a porch with posts, two benches, and a bare
  // flagpole at x=84 whose top is (84,4). The banner (effects.px.js) hangs from that point.
  const LG = {
    wins: [[12, 42, 10, 12], [26, 42, 10, 12], [60, 42, 10, 12], [74, 42, 10, 12]],
    door: [43, 50, 10, 25],
    pole: [84, 4],
  }
  sprite("lodge", { w: 96, h: 76 }, (c) => {
    // long hall body with timber frame
    c.rect(4, 36, 88, 38, "c")
    c.rect(84, 36, 8, 38, "C")
    for (const x of [4, 45, 88]) { c.rect(x, 36, 3, 38, "t"); c.vline(x, 36, 38, "u") }
    c.rect(4, 56, 88, 2, "t"); c.hline(4, 56, 88, "u")
    c.line(8, 40, 14, 52, "t"); c.line(81, 40, 75, 52, "t")
    // roof: long gable in terracotta with clay courses
    c.poly([48, 8, 0, 38, 96, 38], "r")
    c.clip([48, 8, 0, 38, 96, 38], () => {
      for (let y = 12; y < 38; y += 4) c.hline(0, y, 96, "R")
      for (let y = 13; y < 38; y += 4) for (let x = 0; x < 96; x += 4) c.px(x + ((y >> 2) % 2) * 2, y, "o")
    })
    c.poly([48, 8, 46, 9, 0, 38, 4, 38], "P")            // underside of the left slope in shadow
    c.hline(0, 38, 96, "R")
    // porch: two posts and a small roof over the door
    c.poly([38, 46, 58, 46, 62, 49, 34, 49], "T")
    for (const x of [36, 58]) { c.rect(x, 49, 3, 27, "t"); c.vline(x, 49, 27, "u") }
    c.hline(34, 49, 28, "u")
    // windows with flower sills
    for (const [x, y, w, h] of LG.wins) {
      win(c, x, y, w, h, { sill: false })
      c.rect(x - 1, y + h, w + 2, 2, "d"); c.hline(x - 1, y + h + 1, w + 2, "t")
    }
    // door
    const [dx, dy, dw, dh] = LG.door
    c.rect(dx - 1, dy - 1, dw + 2, dh + 1, "T")
    c.rect(dx, dy, dw, dh, "B")
    c.vline(dx + 1, dy, dh, "b")
    c.vline(dx + Math.floor(dw / 2), dy, dh, "N")
    c.px(dx + dw - 3, dy + 12, "l")
    // benches on the ground either side of the porch
    for (const bx of [12, 66]) {
      c.rect(bx, 67, 16, 2, "u"); c.hline(bx, 67, 16, "y"); c.hline(bx, 69, 16, "T")
      c.vline(bx + 1, 69, 4, "T"); c.vline(bx + 14, 69, 4, "T")
    }
    // bare flagpole (no flag: the banner is its own sprite)
    const [px_, py] = LG.pole
    c.vline(px_, py, 66, "N"); c.vline(px_ + 1, py, 66, "D")
    c.px(px_, py - 1, "h"); c.px(px_, py, "h")
    stones(c, 0, 72, 96, 4, { rh: 4 })                  // the hall's footing
  }, outline)

  sprite("lodge_lit", { w: 96, h: 76 }, (c) => {
    for (const [x, y, w, h] of LG.wins) litwin(c, x, y, w, h, {})
    const [dx, dy, dw] = LG.door
    c.px(dx + dw - 3, dy + 12, "y"); c.px(dx + dw - 4, dy + 12, "w")
    halo(c)
  })
}
