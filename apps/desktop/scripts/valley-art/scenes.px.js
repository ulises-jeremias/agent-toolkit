// Composition checks, not shipped: valley_day and valley_dusk (400x200).
// Every building's bottom row sits on the lane line (y=146 in the scene: ground.png row 10).
// Buildings at y = 146 - height. The dusk scene swaps the sky, adds every *_lit overlay,
// and shades the valley so the lamplight reads as the warm accent.
include("backdrop.px.js")
include("houses.px.js")
include("landmarks.px.js")
include("nature.px.js")
include("characters.px.js")
include("effects.px.js")

const LANE = 146

/** Everything a composition needs, in back-to-front order. `dusk` picks sky, lit overlays, shading. */
const valley = (dusk) => {
  const items = [
    tile(dusk ? "sky_dusk" : "sky_day", 0, 0, 25, 1),
    stamp("cloud_1", 40, 20), stamp("cloud_2", 220, 14), stamp("cloud_3", 330, 34),
    stamp("hills_far", 0, 96),
    stamp("hills_mid", 0, 104),
    stamp("ground", 0, LANE - 10),
    // back-row trees and bushes stand at the lane's far edge
    stamp("tree_oak", -16, LANE - 64 - 2),
    stamp("tree_birch", 386, LANE - 56 - 2),
    stamp("tree_pine", 360, LANE - 64 - 4),
    // the valley: library, workshop with its wheel, lodge with banner, two cottages
    stamp("library", 0, LANE - 104),
    stamp("workshop", 80, LANE - 80),
    stamp("wheel", 80, LANE - 80 + 24),
    stamp("lodge", 176, LANE - 76),
    stamp("banner", 260, LANE - 76 + 4 - 4),
    stamp("house_a", 272, LANE - 72),
    stamp("house_b", 336, LANE - 72),
    stamp("lamp_post", 268, LANE - 40),
    stamp("nest_post", 52, LANE - 36),
    stamp("hornero_perch", 53, LANE - 36 - 10),                         // perched on the nest rim
    stamp("smoke", 144, 41),                                            // workshop chimney mouth
    stamp("smoke", 310, 45),                                            // house_a chimney mouth
    stamp("bush_2", 118, LANE - 14), stamp("woodpile", 150, LANE - 12),
    stamp("signpost", 2, LANE - 24),
    tile("bush_1", 200, LANE - 12, 2, 1),
    stamp("grass_sway", 232, LANE - 8), stamp("grass_sway", 252, LANE - 8),
    stamp("agent_idle_ember", 120, LANE - 24),
    stamp("agent_work_river", 146, LANE - 24),
    stamp("agent_ask_moss", 196, LANE - 24),
    stamp("bubble_ask", 200, LANE - 40),
    stamp("bubble_done", 124, LANE - 42),
    stamp("rock_1", 36, 184), stamp("flowers_1", 304, 186), stamp("flowers_2", 22, 184),
    stamp("reeds", 382, 180),
    tile("fence", 0, 186, 12, 1),
  ]
  if (dusk) {
    // shade the valley (everything below the far hills) so the lit windows read as the accent
    items.push(layer("dusk", { shade: 1 }, rect(0, 96, 400, 104, "k")))
    items.push(stamp("library_lit", 0, LANE - 104), stamp("workshop_lit", 80, LANE - 80),
      stamp("lodge_lit", 176, LANE - 76), stamp("house_a_lit", 272, LANE - 72), stamp("house_b_lit", 336, LANE - 72),
      stamp("lamp_post_lit", 260, LANE - 48))
  }
  return items
}

scene("valley_day", { w: 400, h: 200, bg: "q" }, ...valley(false))
scene("valley_dusk", { w: 400, h: 200, bg: "V" }, ...valley(true))

// Contact sheet of every exported asset (not parts), for review at a glance.
sheet("contact", ["sky_day", "sky_dusk", "hills_far", "hills_mid", "ground", "river", "bridge",
  "cloud_1", "cloud_2", "cloud_3", "house_a", "house_a_lit", "house_b", "house_b_lit", "house_c", "house_c_lit",
  "house_d", "house_d_lit", "library", "library_lit", "workshop", "workshop_lit", "lodge", "lodge_lit",
  "tree_oak", "tree_pine", "tree_birch", "bush_1", "bush_2", "flowers_1", "flowers_2", "reeds", "rock_1",
  "fence", "signpost", "woodpile", "lamp_post", "lamp_post_lit", "nest_post", "agent_*", "hornero_*",
  "bubble_*", "wheel", "smoke", "banner", "grass_sway", "water_shine"], { cols: 8, pad: 2 })
