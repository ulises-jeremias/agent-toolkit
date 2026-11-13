// Shared drawing helpers for the Hornero Valley set (no assets of its own).
// Every art file include()s this; the guard makes repeated includes harmless.
// Convention everywhere: sun is low in the UPPER LEFT. Left/top faces light, right/under faces dark.
include("palette.px.js")

if (!globalThis.VA) {
  const VA = (globalThis.VA = {})

  // Outline colour for an edge that faces the sun, by the material it borders.
  // Shadow-side edges always get ink, so forms stay readable on any backdrop.
  const SUN_EDGE = {
    p: "R", o: "R", r: "R", R: "P", P: "P",
    w: "t", c: "t", C: "t", e: "T",
    Y: "F", G: "F", g: "F", F: "S", S: "S",
    y: "t", d: "t", u: "T", t: "T", T: "T",
    h: "D", s: "D", D: "N", N: "N",
    a: "B", b: "B", B: "N", l: "t",
  }

  /**
   * Selective outline, drawn INSIDE the canvas (leave a 1px margin around the art).
   * Edges touching the form only from its upper-left get a dark tone of the material;
   * every other edge gets ink. `plain: true` inks everything (characters, tiny props).
   */
  VA.outline = (c, o = {}) => {
    const solid = (x, y) => x >= 0 && y >= 0 && x < c.w && y < c.h && !c.is(x, y, ".")
    const edge = []
    for (let y = 0; y < c.h; y++)
      for (let x = 0; x < c.w; x++) {
        if (solid(x, y)) continue
        const L = solid(x - 1, y), R = solid(x + 1, y), U = solid(x, y - 1), D = solid(x, y + 1)
        if (!(L || R || U || D)) continue
        let key = "k"
        if (!o.plain && !L && !U) key = SUN_EDGE[D ? c.key(x, y + 1) : c.key(x + 1, y)] || "k"
        edge.push([x, y, key])
      }
    for (const [x, y, key] of edge) c.px(x, y, key)
  }
  VA.ink = (c) => VA.outline(c, { plain: true })

  /**
   * Coursed rubble masonry. Joints are structure, not noise: one line under each course and
   * staggered uprights; the top-left of each stone catches the sun.
   */
  VA.stones = (c, x, y, w, h, o = {}) => {
    const rh = o.rh || 4, base = o.base || "s", joint = o.joint || "D", hi = o.hi || "h"
    const widths = o.widths || [6, 8, 5, 7, 9, 6]
    c.rect(x, y, w, h, base)
    for (let r = 0, yy = y; yy < y + h; r++, yy += rh) {
      const ch = Math.min(rh, y + h - yy)
      if (ch === rh) c.hline(x, yy + rh - 1, w, joint)
      let xx = x - ((r * 5 + (o.shift || 0)) % 7), start = x
      for (let i = r; xx < x + w; i++) {
        xx += widths[i % widths.length]
        const end = Math.min(xx, x + w)
        if (hi && end - start >= 4 && ch >= 3) c.hline(start + (start === x ? 0 : 1), yy, Math.ceil((end - start) * 0.5), hi)
        if (xx < x + w - 1) c.vline(xx, yy, Math.max(1, ch - 1), joint)
        start = xx
      }
    }
  }

  /**
   * Roof tile courses inside a clip region (eave-on roofs). Each course is `ch` px tall:
   * a shadow line where it overlaps the next, and notches between the rounded tile ends,
   * offset every other course.
   */
  VA.tiles = (c, region, box, o = {}) => {
    const [x, y, w, h] = box
    const ch = o.ch || 4, tw = o.tw || 4, base = o.base || "r", seam = o.seam || "R"
    c.clip(region, () => {
      c.rect(x, y, w, h, base)
      for (let r = 0, yy = y; yy < y + h; r++, yy += ch) {
        c.hline(x, yy + ch - 1, w, seam)
        for (let xx = x + (r % 2 ? tw / 2 : 0); xx < x + w; xx += tw) c.px(xx, yy + ch - 2, seam)
      }
    })
  }

  /** Vertical planks: seam every `pw` px, and a sunlit left edge on each board when `hi` is set. */
  VA.planks = (c, x, y, w, h, o = {}) => {
    const pw = o.pw || 4, base = o.base || "t", seam = o.seam || "T"
    c.rect(x, y, w, h, base)
    for (let xx = x + pw - 1; xx < x + w - 1; xx += pw) c.vline(xx, y, h, seam)
    if (o.hi) for (let xx = x; xx < x + w; xx += pw) c.vline(xx, y, h, o.hi)
  }

  // ---- windows. x, y, w, h is the OUTER frame; panes() is what the *_lit overlays repaint.
  VA.panes = (x, y, w, h, o = {}) => {
    const ix = x + 1, iy = y + 1, iw = w - 2, ih = h - 2, out = []
    const cols = o.cols || (iw >= 5 ? 2 : 1), rows = o.rows || (ih >= 8 ? 2 : 1)
    // bars are 1px; panes share the remaining space, the extra pixel goes to the first pane
    const split = (len, n) => {
      const free = len - (n - 1), each = Math.floor(free / n), a = []
      for (let i = 0, p = 0; i < n; i++) { const s = each + (i < free - each * n ? 1 : 0); a.push([p, s]); p += s + 1 }
      return a
    }
    for (const [py, ph] of split(ih, rows)) for (const [px_, pw] of split(iw, cols)) out.push([ix + px_, iy + py, pw, ph])
    return out
  }
  /** Daytime window: timber frame, dark glass with one diagonal sky reflection, a sunlit sill. */
  VA.win = (c, x, y, w, h, o = {}) => {
    const frame = o.frame || "T", bar = o.bar || "t"
    c.rect(x, y, w, h, frame)
    c.rect(x + 1, y + 1, w - 2, h - 2, bar)
    for (const [px_, py, pw, ph] of VA.panes(x, y, w, h, o)) {
      c.rect(px_, py, pw, ph, "N")
      c.px(px_ + pw - 1, py + ph - 1, "V")                       // glass deepens away from the sun
      if (ph >= 2) c.px(px_ + pw - 1, py + ph - 2, "V")
      if (pw >= 2) c.px(px_ + pw - 2, py + ph - 1, "V")
    }
    const [fx, fy, fw, fh] = VA.panes(x, y, w, h, o)[0]            // reflection only in the first pane
    c.px(fx, fy + Math.min(1, fh - 1), "D"); if (fw >= 2) c.px(fx + 1, fy, "D")
    if (o.arch) { c.px(x, y, o.arch); c.px(x + w - 1, y, o.arch) }      // arch: wall colour eats the top corners
    if (o.sill !== false) {
      c.hline(x - 1, y + h, w + 2, o.sillHi || "d")
      c.hline(x - 1, y + h + 1, w + 2, o.sillLo || "t")
    }
  }
  /** Lamplit panes for an overlay: hottest near the top, cooling to orange at the sill. */
  VA.litwin = (c, x, y, w, h, o = {}) => {
    const all = VA.panes(x, y, w, h, o), top = Math.min(...all.map((p) => p[1])), bot = Math.max(...all.map((p) => p[1] + p[3]))
    for (const [px_, py, pw, ph] of all)
      for (let yy = py; yy < py + ph; yy++) {
        const k = (yy - top) / Math.max(1, bot - top - 1)
        c.hline(px_, yy, pw, k < 0.34 ? "y" : k < 0.9 ? "l" : "o")
      }
    const [fx, fy] = all[0]
    c.px(fx, fy, "w")
  }
  /**
   * Soft lamplight spill around everything already drawn on an overlay: one ring at ~55% alpha,
   * a wider one at ~25%. Call last. Alpha spill only exists on *_lit overlays.
   */
  VA.halo = (c, r1 = 1.5, r2 = 3.3) => {
    const lit = []
    for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) if (!c.is(x, y, ".")) lit.push([x, y])
    const R = Math.ceil(r2), put = []
    for (let y = 0; y < c.h; y++)
      for (let x = 0; x < c.w; x++) {
        if (!c.is(x, y, ".")) continue
        let best = 99
        for (const [lx, ly] of lit) {
          if (Math.abs(lx - x) > R || Math.abs(ly - y) > R) continue
          best = Math.min(best, Math.hypot(lx - x, ly - y))
        }
        if (best <= r1) put.push([x, y, "1"]); else if (best <= r2) put.push([x, y, "2"])
      }
    for (const [x, y, k] of put) c.px(x, y, k)
  }
}
