// Grove trees — 64px silhouettes at a consistent three-quarter scale.
// Form comes from boughs and layered leaf masses; no random leaf speckle.
include("palette.px.js")

function groundShadow(c) {
  c.ellipse(34, 60, 23, 3, "F");
  c.ellipse(27, 59, 13, 2, "q");
}

function trunk(c, width = 7) {
  const left = 32 - Math.floor(width / 2);
  c.poly([left + 2, 32, left + width - 2, 32, left + width + 3, 59, left - 2, 59], "D");
  c.poly([left + width - 2, 32, left + width + 3, 59, 34, 59, 34, 34], "b");
  c.poly([left + 2, 51, left - 7, 59, left + 5, 57], "D");
  c.poly([left + width - 1, 50, left + width + 8, 59, left + width - 3, 58], "b");
  c.vline(left + 2, 36, 15, "d");
  c.line(31, 38, 19, 25, "D");
  c.line(33, 39, 45, 24, "b");
  c.line(20, 26, 17, 20, "d");
  c.line(44, 25, 48, 19, "b");
}

function leafClump(c, x, y, rx, ry, fill, shadow, light) {
  c.ellipse(x, y, rx, ry, shadow);
  c.ellipse(x - 1, y - 2, rx - 2, ry - 3, fill);
  c.poly([x - rx + 2, y - 2, x - rx + 5, y - ry + 3, x - 1, y - ry + 2, x + 1, y - 2, x - 3, y + 1], light);
  c.px(x - 2, y - ry + 4, light);
  c.px(x + rx - 3, y + 1, shadow);
}

function canopy(c, fill, shadow, light, clumps) {
  // Separate leaf masses let the forked limbs show through the crown.
  for (const [x, y, rx, ry] of clumps) leafClump(c, x, y, rx, ry, fill, shadow, light);
}

function tree(name, fill, shadow, light, clumps, extra) {
  sprite(name, { w: 64, h: 64 }, (c) => {
    groundShadow(c);
    trunk(c, name === "tree-willow" ? 9 : 7);
    canopy(c, fill, shadow, light, clumps);
    if (extra) extra(c);
    c.poly([22, 51, 42, 51, 46, 55, 19, 55], "D");
    c.vline(31, 44, 14, "d");
    c.vline(35, 43, 16, "b");
    c.poly([27, 59, 34, 59, 40, 62, 22, 62], "F");
  });
}

// Broad oak: a connected, wind-shaped crown with layered boughs and an open
// lower canopy. Planes follow the upper-left sun instead of reading as balls.
sprite("tree-round", { w: 64, h: 64 }, (c) => {
  groundShadow(c);
  trunk(c, 8);

  // Deep silhouette: left crown reaches farther forward, with a broken ridge
  // and a lifted east edge rather than a circle of separate leaf clumps.
  c.poly([
    29, 4, 37, 6, 42, 11, 51, 14, 57, 21, 55, 28, 59, 34,
    55, 41, 48, 46, 39, 44, 33, 50, 24, 47, 17, 48, 10, 43,
    8, 36, 4, 30, 7, 23, 12, 19, 15, 12, 22, 9,
  ], "f");

  // The middle canopy is one continuous mass. A darker lee plane gives the
  // boughs weight; upper-left breaks catch warm daylight.
  c.poly([
    29, 7, 36, 9, 41, 14, 49, 17, 54, 22, 52, 28, 56, 34,
    52, 39, 47, 43, 39, 41, 32, 47, 25, 44, 18, 45, 12, 41,
    11, 35, 7, 30, 10, 24, 15, 20, 17, 14, 23, 11,
  ], "G");
  c.poly([33, 22, 42, 18, 50, 22, 52, 29, 56, 34, 52, 39, 47, 43, 39, 41, 32, 47, 27, 43], "F");

  // Sunward bough planes; stepped, angular leaf edges keep the silhouette
  // readable at the small in-world scale.
  c.poly([20, 13, 25, 10, 31, 8, 36, 10, 39, 14, 36, 18, 30, 17, 27, 21, 20, 20, 16, 23, 13, 20], "g");
  c.poly([11, 24, 15, 19, 21, 18, 25, 22, 23, 27, 17, 29, 13, 33, 9, 30], "g");
  c.poly([25, 22, 31, 18, 38, 19, 42, 23, 39, 28, 34, 29, 30, 34, 24, 31], "G");
  c.poly([39, 15, 45, 17, 50, 20, 51, 25, 47, 28, 42, 25, 39, 21], "g");
  c.poly([14, 33, 19, 29, 26, 31, 28, 36, 24, 41, 17, 42, 12, 39, 10, 35], "G");
  c.poly([31, 31, 38, 27, 45, 29, 49, 33, 46, 38, 41, 40, 34, 38, 29, 41], "g");

  // Forks show through two deliberate gaps; roots and bark planes carry the
  // same left-lit direction as the canopy.
  c.line(31, 42, 24, 32, "D");
  c.line(33, 42, 41, 31, "b");
  c.line(25, 33, 20, 28, "D");
  c.line(40, 33, 46, 27, "b");
  c.vline(30, 45, 13, "d");
  c.vline(34, 44, 14, "b");
  c.poly([22, 55, 32, 53, 40, 57, 38, 60, 21, 60], "D");
  c.vline(25, 55, 4, "d");
  c.vline(33, 54, 5, "b");
  c.poly([27, 59, 37, 59, 42, 62, 22, 62], "F");
});

// Flowering plum: a low, wind-swept crown with open branch windows. The
// flowering boughs form connected horizontal sprays, unlike the oak's dome.
sprite("tree-blossom", { w: 64, h: 64 }, (c) => {
  groundShadow(c);
  trunk(c, 6);
  c.poly([27, 8, 34, 5, 40, 10, 48, 12, 55, 21, 53, 27, 59, 32, 54, 40, 46, 42, 39, 38, 31, 42, 24, 39, 16, 43, 9, 38, 6, 31, 11, 24, 10, 17, 18, 12], "f");
  c.poly([26, 11, 34, 8, 39, 13, 47, 15, 52, 22, 50, 28, 55, 32, 51, 37, 45, 39, 38, 35, 31, 39, 24, 36, 17, 40, 12, 36, 10, 31, 14, 25, 13, 19, 20, 15], "G");
  c.poly([17, 25, 24, 19, 30, 21, 34, 27, 31, 31, 24, 30, 19, 34, 13, 31], "g");
  c.poly([34, 15, 41, 14, 48, 19, 49, 24, 44, 28, 38, 25, 33, 29, 29, 24], "g");
  c.poly([23, 31, 30, 28, 37, 31, 40, 36, 35, 39, 29, 36, 24, 39, 19, 36], "G");
  c.line(31, 42, 23, 30, "D");
  c.line(33, 41, 43, 28, "b");
  // Blossom is grouped at branch tips, never sprinkled uniformly over leaves.
  c.poly([9, 22, 13, 17, 18, 18, 17, 24, 12, 26], "h");
  c.poly([36, 12, 41, 9, 46, 12, 45, 17, 39, 19], "h");
  c.poly([46, 28, 51, 25, 56, 29, 55, 34, 50, 36], "h");
  c.px(12, 20, "w"); c.px(15, 22, "H");
  c.px(40, 12, "w"); c.px(43, 14, "H");
  c.px(51, 29, "w"); c.px(53, 32, "H");
  c.poly([22, 51, 42, 51, 46, 55, 19, 55], "D");
  c.vline(31, 44, 14, "d"); c.vline(35, 43, 16, "b");
  c.poly([27, 59, 34, 59, 40, 62, 22, 62], "F");
});

// Amber pear: a taller, tapered crown with fruiting limbs and a visible
// central fork; its silhouette stays distinct when viewed at fit-to-world.
sprite("tree-amber", { w: 64, h: 64 }, (c) => {
  groundShadow(c);
  trunk(c, 8);
  c.poly([29, 3, 37, 6, 40, 13, 49, 18, 54, 26, 50, 32, 55, 37, 50, 44, 42, 46, 36, 42, 29, 48, 21, 44, 14, 46, 8, 40, 10, 33, 5, 28, 11, 21, 18, 18, 20, 10], "u");
  c.poly([29, 6, 36, 9, 38, 15, 46, 20, 50, 26, 47, 32, 51, 37, 47, 41, 41, 43, 35, 39, 29, 44, 23, 41, 16, 43, 12, 39, 14, 33, 9, 28, 14, 23, 20, 21, 22, 13], "J");
  c.poly([24, 12, 30, 8, 35, 11, 37, 17, 32, 22, 26, 19, 21, 23, 17, 19], "j");
  c.poly([17, 25, 23, 20, 29, 23, 31, 29, 27, 34, 21, 32, 16, 36, 12, 32], "j");
  c.poly([34, 21, 40, 17, 46, 21, 48, 26, 44, 31, 38, 29, 34, 34, 30, 29], "j");
  c.poly([25, 33, 31, 29, 37, 33, 39, 38, 34, 42, 28, 39, 23, 42, 19, 38], "J");
  c.line(31, 43, 25, 31, "D"); c.line(33, 41, 42, 29, "b");
  // Warm highlights describe upper-left leaf planes; fruit hangs below limbs.
  c.line(25, 14, 32, 11, "j"); c.line(17, 27, 23, 23, "j");
  c.px(17, 36, "Y"); c.px(18, 37, "J");
  c.px(43, 33, "Y"); c.px(44, 34, "J");
  c.px(34, 44, "Y"); c.px(35, 45, "J");
  c.poly([22, 51, 42, 51, 46, 55, 19, 55], "D");
  c.vline(31, 44, 14, "d"); c.vline(35, 43, 16, "b");
  c.poly([27, 59, 34, 59, 40, 62, 22, 62], "F");
});

// Old rune tree: exposed forked limbs and a single mineral-blue scar.
tree("tree-rune", "f", "F", "G", [
  [31, 10, 8, 9], [17, 22, 8, 8], [43, 22, 8, 10], [25, 34, 8, 8], [44, 37, 7, 8],
], (c) => {
  c.poly([13, 16, 18, 11, 22, 14, 19, 21], "G");
  c.poly([39, 12, 45, 14, 46, 20, 41, 22], "G");
  c.vline(34, 36, 5, "a");
  c.px(33, 39, "A"); c.px(35, 40, "a");
  c.px(25, 48, "a"); c.px(26, 48, "A");
});

// Mountain pine: tiered boughs are separate planes, not a green triangle.
sprite("tree-pine", { w: 64, h: 64 }, (c) => {
  groundShadow(c);
  c.poly([29, 4, 34, 1, 40, 9, 38, 19, 45, 26, 41, 37, 49, 44, 44, 49, 18, 49, 13, 44, 21, 35, 17, 27, 24, 18, 22, 11], "F");
  c.poly([30, 5, 35, 3, 39, 11, 34, 16, 42, 26, 35, 33, 42, 41, 38, 46, 22, 46, 19, 42, 27, 34, 22, 27, 30, 19, 26, 12], "f");
  c.poly([29, 6, 34, 4, 36, 11, 32, 16, 36, 25, 30, 31, 35, 39, 31, 43, 25, 41, 30, 34, 26, 27, 32, 19, 28, 12], "G");
  c.line(30, 7, 24, 20, "g");
  c.line(32, 20, 22, 31, "G");
  c.line(31, 33, 22, 43, "g");
  c.poly([28, 40, 35, 40, 39, 59, 25, 59], "D");
  c.vline(33, 42, 15, "b");
  c.poly([24, 57, 38, 57, 43, 61, 19, 61], "F");
});

// Willow: a crooked trunk supports long, separated curtain boughs.
sprite("tree-willow", { w: 64, h: 64 }, (c) => {
  groundShadow(c);
  c.poly([28, 28, 35, 22, 40, 29, 37, 58, 24, 59], "D");
  c.vline(34, 29, 26, "b");
  c.line(32, 35, 19, 17, "D");
  c.line(35, 34, 48, 16, "b");
  c.poly([13, 10, 24, 4, 36, 6, 51, 13, 47, 25, 39, 30, 28, 26, 17, 29, 8, 21], "F");
  c.poly([14, 11, 24, 6, 35, 8, 47, 14, 43, 23, 35, 26, 26, 22, 17, 26, 11, 20], "G");
  c.poly([17, 11, 26, 7, 35, 9, 39, 15, 32, 18, 24, 16], "g");
  for (const x of [12, 18, 24, 40, 46, 51]) {
    const length = x < 20 ? 26 : x < 40 ? 20 : 25;
    c.vline(x, 19, length, x < 23 ? "f" : "F");
    c.vline(x + 1, 20, length - 1, x < 23 ? "G" : "f");
    c.px(x, 19 + length, "g");
  }
  c.poly([22, 56, 38, 56, 44, 61, 17, 61], "F");
});
