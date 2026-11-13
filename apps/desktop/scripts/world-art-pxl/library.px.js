// The Library is a compact civic landmark: a clock tower rising behind two
// reading wings, with stone courses, clay roofs and a sheltered book gallery.
include("palette.px.js")

sprite("landmark-library", { w: 64, h: 64 }, (c) => {
  const roof = (points, x0, x1, y0, y1, light, shadow) => {
    c.poly(points, light)
    c.clip(points, () => {
      for (let y = y0; y < y1; y += 4) {
        c.hline(x0, y, x1 - x0, shadow)
        for (let x = x0 + ((y >> 2) % 2) * 2; x < x1; x += 8) c.px(x, y + 2, light)
      }
    })
  }
  const masonry = (x, y, w, h, base, seam, highlight) => {
    c.rect(x, y, w, h, base)
    for (let row = 4; row < h; row += 6) {
      c.hline(x, y + row, w, seam)
      const offset = (Math.floor(row / 6) % 2) * 5
      for (let xx = x + 5 + offset; xx < x + w; xx += 10) c.vline(xx, y + row - 5, 5, seam)
      c.hline(x + 1, y + row - 5, 4, highlight)
    }
  }
  const bookWindow = (x, y, w, h, seed) => {
    c.rect(x - 2, y - 2, w + 4, h + 4, "D")
    c.rect(x, y, w, h, "n")
    c.hline(x, y + Math.floor(h / 2), w, "s")
    const books = ["r", "Y", "V", "g", "a", "o"]
    for (let shelf = 0; shelf < 2; shelf++) {
      for (let i = 0; i < 5; i++) {
        const xx = x + 2 + i * 3
        const top = y + 2 + shelf * Math.floor(h / 2)
        const bh = Math.min(4, Math.floor(h / 2) - 2)
        c.vline(xx, top + (i + seed + shelf) % 2, bh, books[(i + seed + shelf * 2) % books.length])
      }
    }
    c.vline(x + 1, y + 1, h - 2, "s")
    c.vline(x + w - 1, y + 1, h - 2, "D")
  }

  // Long foundation and shallow wings anchor the narrow tower into the village.
  c.ellipse(32, 61, 29, 2, "q")
  c.rect(3, 55, 58, 7, "s")
  c.hline(4, 56, 56, "s")
  c.hline(4, 59, 56, "D")
  for (let x = 10; x < 60; x += 12) c.vline(x, 56, 6, "D")

  // West reading wing: timber-framed plaster beneath a low clay roof.
  c.rect(5, 32, 22, 24, "c")
  c.rect(22, 32, 5, 24, "C")
  c.vline(6, 33, 21, "w")
  c.hline(7, 49, 18, "t")
  roof([16, 20, 3, 33, 28, 33], 4, 28, 22, 33, "r", "u")
  c.line(16, 20, 4, 33, "o")
  c.line(16, 20, 28, 33, "u")
  c.rect(9, 38, 8, 11, "D")
  c.rect(10, 39, 6, 8, "n")
  c.vline(11, 40, 6, "a")
  c.vline(14, 40, 6, "V")
  c.vline(18, 34, 21, "t")
  c.vline(25, 34, 21, "D")

  // East scriptorium has a broader canopy and a lit reading window.
  c.rect(37, 32, 22, 24, "c")
  c.rect(54, 32, 5, 24, "C")
  c.vline(38, 33, 21, "w")
  c.hline(39, 49, 16, "t")
  roof([48, 20, 35, 33, 61, 33], 36, 61, 22, 33, "P", "u")
  c.line(48, 20, 36, 33, "o")
  c.line(48, 20, 61, 33, "u")
  c.rect(45, 38, 8, 11, "D")
  c.rect(46, 39, 6, 8, "n")
  c.vline(47, 40, 6, "Y")
  c.vline(50, 40, 6, "a")
  c.vline(41, 34, 21, "t")
  c.vline(57, 34, 21, "D")

  // Stone clock tower rises above both wings; courses wrap around its corners.
  masonry(23, 14, 19, 42, "s", "D", "s")
  c.vline(23, 16, 38, "s")
  c.vline(40, 16, 38, "n")
  roof([32, 1, 19, 16, 45, 16], 19, 45, 4, 16, "n", "D")
  c.line(32, 1, 19, 16, "s")
  c.line(32, 1, 45, 16, "k")
  c.hline(18, 16, 28, "k")
  c.rect(29, 4, 6, 8, "D")
  c.circ(32, 8, 3, "w")
  c.ring(32, 8, 3, "k")
  c.line(32, 8, 32, 6, "k")
  c.line(32, 8, 34, 9, "k")
  c.px(32, 8, "r")
  bookWindow(27, 20, 11, 12, 1)
  bookWindow(27, 35, 11, 12, 3)

  // Recessed double doors, brass handle, book sign and the house martin's nest.
  c.rect(27, 49, 12, 14, "n")
  c.rect(29, 50, 8, 13, "t")
  c.vline(32, 50, 13, "T")
  c.vline(30, 51, 10, "u")
  c.px(35, 56, "Y")
  c.rect(13, 29, 8, 2, "T")
  c.rect(9, 27, 10, 7, "r")
  c.rect(10, 28, 4, 4, "c")
  c.rect(15, 28, 3, 4, "c")
  c.vline(14, 28, 4, "u")
  c.circ(22, 18, 3, "u")
  c.circ(23, 18, 2, "t")
  c.px(20, 16, "Y")
  c.px(21, 15, "Y")

  // Two worn steps and paired herb planters give the entrance a lived-in scale.
  c.poly([23, 60, 41, 60, 44, 62, 21, 62], "M")
  c.hline(23, 60, 17, "s")
  c.poly([19, 62, 45, 62, 48, 64, 16, 64], "P")
  for (const x of [5, 54]) {
    c.rect(x, 49, 6, 6, "T")
    c.hline(x + 1, 50, 4, "u")
    c.poly([x, 49, x + 3, 44, x + 6, 49], "G")
    c.px(x + 2, 46, "g")
    c.px(x + 4, 47, "Y")
  }
}, "k")
