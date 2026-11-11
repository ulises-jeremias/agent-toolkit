// Semantic signpost set — one sign per valley destination.
// Colour band + tiny 3x5 label identify each place; HTML keeps real text nav.
include("palette.px.js")
function sign(name, band, label, arrowRight) {
  sprite(name, { w: 48, h: 40 }, (c) => {
    c.ellipse(24, 37, 14, 2, "F"); c.rect(22, 16, 4, 20, "b"); c.vline(25, 16, 20, "D"); c.rect(21, 34, 6, 3, "D")
    c.rect(4, 4, 40, 14, "d"); c.box(4, 4, 40, 14, "b"); c.hline(4, 4, 40, "e")
    c.rect(5, 13, 38, 3, band)
    if (arrowRight) { c.poly([36, 7, 42, 10, 36, 13], band) } else { c.poly([12, 7, 6, 10, 12, 13], band) }
    c.text(arrowRight ? 8 : 16, 6, label, "w")
    c.px(10, 21, "Y"); c.px(37, 21, "Y"); c.rect(16, 22, 16, 2, "D")
  })
}
sign("sign-trailhead", "g", "START", true)
sign("sign-projects", "t", "BUILDS", true)
sign("sign-library", "v", "BOOKS", false)
sign("sign-guild", "Y", "GUILD", true)
sign("sign-operations", "S", "OPS", false)
sign("sign-workshop", "J", "SHOP", true)
sign("sign-waystation", "A", "REST", false)
sign("sign-square", "r", "TOWN", true)
sign("sign-chronicles", "H", "LORE", false)
