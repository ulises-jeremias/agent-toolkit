// Animated effects: the mill wheel, chimney smoke, the lodge banner, grass sway and river shimmer.
// Every loop closes on itself (frame k+1 wraps to frame 0), so none of them jumps when it repeats.
include("lib.px.js")

{
  const TAU = Math.PI * 2

  // ---------------------------------------------------------------- mill wheel (40x40, 8 frames)
  // Hub centre is (20,20) inside this canvas. On `workshop` (hub at 20,44) place it at (0,24).
  // Eight spokes at 45 degrees: one frame advances 45 degrees, so the 8-frame loop is exact.
  anim("wheel", { w: 40, h: 40, frames: 8, fps: 8 }, (c) => {
    const a0 = (c.frame * Math.PI) / 4
    const cx = 20, cy = 20, R = 17
    // rim and buckets (paddles) at each spoke end
    c.ring(cx, cy, R, "T")
    c.ring(cx, cy, R - 1, "t")
    for (let k = 0; k < 8; k++) {
      const a = a0 + (k * Math.PI) / 4
      const x = Math.round(cx + Math.cos(a) * R), y = Math.round(cy + Math.sin(a) * R)
      c.line(cx, cy, x, y, "T")
      // paddle: a 3px block facing the tangent, lit on its upper-left face
      const px_ = Math.round(cx + Math.cos(a) * (R - 1)), py_ = Math.round(cy + Math.sin(a) * (R - 1))
      c.rect(px_ - 1, py_ - 1, 3, 3, "u")
      c.px(px_ - 1, py_ - 1, "y")
      c.px(px_ + 1, py_ + 1, "T")
    }
    c.circ(cx, cy, 3, "T"); c.circ(cx - 1, cy - 1, 2, "t"); c.px(cx, cy, "u")  // hub
    // water dripping off the lowest paddles: a drop falls one row per frame, looping
    const drop = c.frame % 4
    c.px(26, 33 + drop, "a"); c.px(26, 34 + drop, "b")
    c.px(14, 35 + ((c.frame + 2) % 4), "a")
    // spray on the wheel's foot in the water
    c.hline(10, 38, 20, "B")
    c.hline(12, 37, 3, "a"); c.hline(25, 37, 3, "a")
  }, VA.outline)

  // ---------------------------------------------------------------- chimney smoke (16x32, 8 frames)
  // Three puffs rise from the mouth at bottom centre (8,31) and swell as they fade. Phase advances
  // one eighth per frame, and each puff starts a third of a cycle after the last, so it loops.
  anim("smoke", { w: 16, h: 32, frames: 8, fps: 6 }, (c) => {
    const ph = c.frame / 8
    const puffs = []
    for (let i = 0; i < 3; i++) {
      const t = (ph + i / 3) % 1                                       // 0 at the mouth, 1 gone
      const y = 29 - t * 24
      const x = 8 + Math.sin((t + i * 0.3) * TAU) * 1.4
      const r = 2 + t * 3.2
      puffs.push([x, y, r, t])
    }
    for (const [x, y, r, t] of puffs) if (t < 0.92) c.circ(Math.round(x), Math.round(y), Math.round(r), t > 0.6 ? "Q" : "n")
    for (const [x, y, r, t] of puffs) if (t < 0.92) c.circ(Math.round(x), Math.round(y), Math.max(1, Math.round(r) - 1), t > 0.6 ? "n" : "Q")
    // sunlit upper-left edge of the nearest puff
    for (const [x, y, r] of puffs.slice(0, 1)) c.px(Math.round(x) - 1, Math.round(y) - Math.round(r) + 1, "w")
  })

  // ---------------------------------------------------------------- lodge banner (16x20, 6 frames)
  // A pennant attached at its left edge (x=0), which hangs from the flagpole top (84,4).
  // The fold travels along the cloth: each column moves a little more than the one before it.
  anim("banner", { w: 16, h: 20, frames: 6, fps: 6 }, (c) => {
    const ph = (c.frame / 6) * TAU
    for (let x = 0; x < 15; x++) {
      const k = x / 14                                                   // 0 at the pole, 1 at the tip
      const wave = Math.round(Math.sin(x * 0.55 - ph) * (0.6 + 1.6 * k))
      const top = 4 + wave
      const h = Math.round(10 - k * 3)                                   // the tail narrows
      for (let y = top; y < top + h; y++) c.px(x, y, y > top + h - 3 ? "R" : (x > 6 ? "r" : "o"))
    }
    c.vline(0, 3, 13, "T")                                               // the pole's sleeve, in shade
    c.px(14, 6, "y")                                                     // a gold tassel on the tip
  })

  // ---------------------------------------------------------------- grass sway (16x8, 4 frames)
  // Four tufts bend left, straight, right, straight: a closed cycle with the bend held at the ends.
  anim("grass_sway", { w: 16, h: 8, frames: 4, fps: 4 }, (c) => {
    const bend = [0, 1, 0, -1][c.frame]
    for (const [x, h] of [[2, 6], [6, 7], [10, 5], [13, 6]]) {
      for (let i = 0; i < h; i++) {
        const dx = Math.round((bend * i) / Math.max(1, h - 1) * 1.2)
        c.px(x + dx, 7 - i, i > h - 3 ? "g" : "G")
      }
      c.px(x + Math.round((bend * (h - 1)) / Math.max(1, h - 1) * 1.2), 7 - h + 1, "G")
    }
    c.hline(0, 7, 16, "F")
  })

  // ---------------------------------------------------------------- river shimmer (64x8, 6 frames)
  // Sparks drift right and wrap at the width. Positions advance 2px per frame across a 6-frame loop.
  anim("water_shine", { w: 64, h: 8, frames: 6, fps: 5 }, (c) => {
    const sparks = [[4, 1, 3, "w"], [19, 4, 4, "a"], [33, 2, 2, "w"], [48, 5, 3, "a"], [60, 1, 2, "w"], [11, 6, 2, "a"]]
    for (const [x0, y, len, col] of sparks) {
      const x = (x0 + c.frame * 2) % 64
      c.hline(x, y, Math.min(len, 64 - x), col)
      if (x + len > 64) c.hline(0, y, x + len - 64, col)
    }
  })
}
