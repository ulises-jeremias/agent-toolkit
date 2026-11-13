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

function blossomPockets(c) {
  // Flower clusters sit on sunward outer branches, not evenly over the crown.
  c.px(11, 16, "h"); c.px(12, 15, "w"); c.px(13, 16, "H");
  c.px(21, 8, "h"); c.px(22, 7, "w"); c.px(23, 8, "H");
  c.px(36, 11, "h"); c.px(37, 10, "w"); c.px(38, 11, "H");
  c.px(48, 22, "h"); c.px(49, 21, "w"); c.px(50, 22, "H");
  c.px(17, 29, "h"); c.px(18, 28, "w"); c.px(19, 29, "H");
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

// Broad oak: a slightly leaning crown with five overlapping masses and visible roots.
tree("tree-round", "G", "f", "g", [
  [28, 11, 9, 9], [13, 23, 8, 9], [46, 22, 9, 10], [18, 36, 8, 8], [39, 36, 9, 8],
], (c) => {
  c.poly([17, 17, 20, 13, 22, 20, 18, 25], "g");
  c.poly([31, 11, 35, 9, 38, 15, 34, 18], "g");
  c.poly([42, 23, 47, 22, 49, 27, 45, 30], "f");
});

// Flowering plum: an open crown, with blossom confined to a few lit sprays.
tree("tree-blossom", "G", "f", "g", [
  [22, 12, 9, 9], [40, 15, 8, 8], [13, 26, 8, 9], [31, 28, 9, 9], [47, 31, 7, 8],
], (c) => {
  blossomPockets(c);
  c.poly([8, 25, 12, 21, 16, 23, 14, 29], "h");
  c.poly([40, 13, 44, 11, 47, 16, 43, 20], "h");
});

// Amber pear: layered fruiting boughs and a stronger fork in the trunk.
tree("tree-amber", "J", "u", "j", [
  [30, 10, 8, 9], [18, 22, 8, 9], [43, 23, 9, 9], [23, 36, 8, 8], [41, 37, 8, 8],
], (c) => {
  c.poly([13, 20, 18, 14, 25, 17, 23, 24, 17, 27], "j");
  c.poly([30, 8, 37, 10, 39, 16, 33, 18], "j");
  c.poly([41, 25, 47, 22, 51, 28, 46, 33], "j");
  c.px(16, 33, "Y"); c.px(17, 34, "J");
  c.px(37, 22, "Y"); c.px(38, 23, "J");
  c.px(47, 34, "Y"); c.px(46, 35, "J");
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
