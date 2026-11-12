// Characters: the valley agents (a cloaked figure with a lantern), the hornero bird in perch and
// flight poses, and two speech bubbles. Agents are drawn once in the ember colourway; river and
// moss are swaps that change only the cloak, so the face, hood interior and lantern stay put.
include("lib.px.js")

{
  const { outline, win } = VA

  // ---------------------------------------------------------------- agent body (16x24)
  // dy shifts the head and shoulders (breathing); the hem and feet stay on the ground line.
  const figure = (c, dy, lamp) => {
    // cloak: hood, shoulders, long hem. Sun on the upper left, folds on the right.
    c.circ(7, 6 + dy, 4, "r")
    c.poly([4, 9 + dy, 11, 9 + dy, 13, 22, 2, 22], "r")
    c.poly([9, 9 + dy, 11, 9 + dy, 13, 22, 10, 22], "R")                   // far side in shadow
    c.px(4, 4 + dy, "o"); c.px(5, 3 + dy, "o"); c.px(3, 6 + dy, "o")        // hood highlight
    c.circ(7, 7 + dy, 2, "V")                                              // hood opening
    c.px(6, 7 + dy, "c"); c.px(8, 7 + dy, "c")                             // pale face in the dark
    c.px(6, 8 + dy, "k"); c.px(8, 8 + dy, "k")                             // eyes
    c.hline(2, 22, 11, "P")                                                // hem band
    c.px(5, 23, "T"); c.px(9, 23, "T")                                     // boots
    // lantern: hanging from the left hand, or held by the arm passed in `lamp`
    lamp(c, dy)
  }
  // Hanging lantern: dark iron frame, straw-warm glass, a hook.
  const hanging = (c) => {
    c.px(1, 13, "T")
    c.rect(0, 14, 3, 4, "D"); c.px(1, 15, "l"); c.px(1, 16, "y"); c.px(2, 15, "w")
    c.hline(0, 18, 3, "T")
  }
  const sleeve = (c, x1, y1) => c.line(11, 10, x1, y1, "r", 2)            // raised arm

  // ---------------------------------------------------------------- idle (breathing, 4 frames)
  anim("agent_idle_ember", { w: 16, h: 24, frames: 4, fps: 4 }, (c) => {
    const breath = [0, 0, 1, 1][c.frame]
    figure(c, -breath, (cv) => hanging(cv))
    outline(c)
  })

  // ---------------------------------------------------------------- work (lantern raised, 6 frames)
  anim("agent_work_ember", { w: 16, h: 24, frames: 6, fps: 8 }, (c) => {
    const f = c.frame
    const bob = [0, 0, -1, -1, 0, 0][f]
    const glow = f % 2 === 0 ? "w" : "y"                                   // lantern flickers
    figure(c, bob, (cv) => {
      sleeve(cv, 13, 6 + bob)
      cv.rect(12, 2 + bob, 3, 4, "D")                                      // raised lantern, clear of the top edge
      cv.rect(13, 3 + bob, 1, 2, glow)
      cv.px(12, 3 + bob, "l"); cv.px(14, 5 + bob, "o")
      // glow spill onto the cloak and the air around the lantern
      cv.px(11, 4 + bob, "l"); cv.px(15, 3 + bob, "l"); cv.px(15, 5 + bob, "l")
      cv.px(12, 6 + bob, "y"); cv.px(14, 2 + bob, "y")
    })
    // second arm hangs with a small lantern glint in the hand
    outline(c)
  })

  // ---------------------------------------------------------------- ask (wave, 6 frames)
  anim("agent_ask_ember", { w: 16, h: 24, frames: 6, fps: 6 }, (c) => {
    const f = c.frame
    const hx = [13, 14, 15, 14, 13, 12][f]                                // hand sways side to side
    const hy = [4, 3, 3, 3, 4, 4][f]
    figure(c, 0, (cv) => {
      hanging(cv)
      sleeve(cv, hx, hy)
      cv.px(hx, hy - 1, "c"); cv.px(hx + 1, hy - 1, "c")                   // open hand, fingers up
      cv.px(hx, hy - 2, "c")
    })
    outline(c)
  })

  // Recoloured families: base + swap. Only the cloak keys change; face, hood interior, lantern stay.
  const RIVER = { r: "b", R: "B", o: "a", P: "N" }
  const MOSS = { r: "g", R: "F", o: "G", P: "S" }
  const TIMING = { idle: { frames: 4, fps: 4 }, work: { frames: 6, fps: 8 }, ask: { frames: 6, fps: 6 } }
  for (const pose of ["idle", "work", "ask"]) {
    anim("agent_" + pose + "_river", { base: "agent_" + pose + "_ember", swap: RIVER, ...TIMING[pose] })
    anim("agent_" + pose + "_moss", { base: "agent_" + pose + "_ember", swap: MOSS, ...TIMING[pose] })
  }

  // ---------------------------------------------------------------- hornero perched (14x12, 4 frames)
  // Facing right. Rusty back, pale breast, dark tail and beak. Head tilt on frame 1, tail flick on 3.
  anim("hornero_perch", { w: 14, h: 12, frames: 4, fps: 4 }, (c) => {
    const f = c.frame
    const tilt = f === 1 ? 1 : 0
    const flick = f === 3 ? -1 : 0
    // tail, back and belly
    c.poly([1, 7 + flick, 4, 6, 5, 9, 1, 10 + flick], "T")
    c.circ(7, 7, 4, "t")                                                  // back
    c.poly([4, 4, 9, 4, 10, 6, 6, 6], "u")                                 // back catches the sun
    c.poly([6, 7, 11, 6, 11, 10, 6, 10], "c")                              // pale breast
    c.poly([9, 8, 11, 8, 11, 10, 9, 10], "C")                              // belly shade
    c.rect(4, 10, 2, 1, "T"); c.rect(8, 10, 2, 1, "T")                     // legs
    // head with a rust cap and a dark beak
    c.circ(10, 3 + tilt, 2, "t")
    c.hline(8, 1 + tilt, 3, "u")                                           // rusty crown
    c.px(10, 3 + tilt, "k")                                                // eye
    c.px(10, 4 + tilt, "c")                                                // pale throat
    c.rect(12, 2 + tilt, 2, 2, "T")                                        // short dark beak
    outline(c)
  })

  // ---------------------------------------------------------------- hornero flying (18x12, 4 frames)
  anim("hornero_fly", { w: 18, h: 12, frames: 4, fps: 10 }, (c) => {
    const f = c.frame
    const wingTip = [0, 3, 6, 3][f]                                       // up, mid, down, mid
    c.poly([1, 7, 5, 6, 5, 9], "T")                                       // tail
    c.circ(9, 6, 4, "t")
    c.poly([5, 4, 10, 4, 11, 6, 6, 7], "u")
    c.poly([6, 7, 12, 7, 12, 9, 7, 9], "c")
    c.circ(13, 4, 2, "t")
    c.px(12, 3, "u"); c.px(12, 2, "u")
    c.px(15, 3, "T"); c.px(15, 4, "T")                                    // beak
    c.px(14, 3, "k")
    // wing: root on the back, tip moves through the stroke
    c.poly([6, 5, 11, 5, 9, wingTip], "u")                                // wing: sunlit upper half
    c.poly([6, 5, 9, wingTip, 7, 6], "t")                                 // underside in shade
    c.line(7, 5, 2, wingTip + 1, "T")                                      // trailing primaries
    outline(c)
  })

  // ---------------------------------------------------------------- bubbles (12x12)
  // Ask: a cream speech bubble with a terracotta question mark. Done: cream bubble, green check.
  const speech = (c) => {
    c.rect(0, 0, 12, 9, "w")
    c.poly([3, 8, 7, 8, 3, 11], "w")
    c.px(0, 0, "_"); c.px(11, 0, "_"); c.px(0, 8, "_"); c.px(11, 8, "_")   // rounded corners
    c.hline(1, 0, 10, "c")                                                 // top rim
  }
  sprite("bubble_ask", { w: 12, h: 12 }, (c) => {
    speech(c)
    // the question mark, 3x5 pixels, centred in the bubble
    for (const [x, y] of [[4, 2], [5, 2], [6, 2], [6, 3], [5, 4], [6, 4], [5, 6]]) c.px(x, y - 1, "r")
    outline(c)
  })
  sprite("bubble_done", { w: 12, h: 12 }, (c) => {
    speech(c)
    for (const [x, y] of [[3, 4], [4, 5], [5, 6], [6, 5], [7, 4], [8, 3]]) c.px(x, y - 1, "G")
    for (const [x, y] of [[4, 4], [5, 5], [6, 4], [7, 3]]) c.px(x, y - 1, "F")
    outline(c)
  })
}
