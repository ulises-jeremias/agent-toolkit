// Hero valley — layered 240x135 composition for the web hero.
// Layers back->front: sky, far hills, river+bridge, meadow, structures, signs.
include("palette.px.js");
sprite("_mini-canopy", { w: 24, h: 18 }, (c) => {
  c.circ(12, 9, 8, "F");
  c.circ(8, 11, 5, "F");
  c.circ(13, 7, 6, "G");
  c.circ(9, 5, 4, "g");
  c.px(7, 4, "w");
});
sprite("_mini-house", { w: 28, h: 22 }, (c) => {
  c.rect(4, 10, 20, 10, "c");
  c.poly([14, 2, 25, 11, 3, 11], "T");
  c.hline(3, 10, 22, "k");
  c.rect(12, 14, 5, 6, "D");
  c.rect(6, 13, 4, 4, "n");
  c.px(7, 14, "L");
  c.rect(19, 13, 4, 4, "n");
  c.px(20, 14, "A");
});
scene(
  "hero-valley",
  { w: 240, h: 135, bg: "i" },
  layer("sky", (c) => {
    c.rect(0, 0, 240, 58, "i");
    c.rect(0, 34, 240, 24, "I");
    c.circ(204, 20, 11, "l");
    c.ring(204, 20, 11, "L");
    c.circ(204, 20, 7, "w");
    c.rect(18, 12, 26, 4, "w");
    c.rect(24, 8, 14, 4, "w");
    c.rect(120, 16, 22, 3, "w");
    c.rect(126, 13, 10, 3, "w");
  }),
  layer("hills", (c) => {
    c.poly([0, 62, 60, 34, 120, 62], "G");
    c.poly([90, 62, 160, 28, 240, 62], "f");
    c.poly([90, 62, 160, 28, 240, 62], "G");
    c.poly([0, 62, 60, 34, 78, 62], "g");
    c.px(160, 30, "w");
    c.px(158, 32, "w");
    c.px(162, 32, "w");
    c.px(58, 36, "w");
  }),
  layer("midground", (c) => {
    c.rect(0, 58, 240, 40, "G");
    c.rect(0, 58, 240, 6, "g");
    const r = c.rng(9);
    for (let i = 0; i < 40; i++)
      c.px(
        Math.floor(r() * 240),
        64 + Math.floor(r() * 32),
        r() < 0.5 ? "g" : "f",
      );
    c.ellipse(40, 90, 16, 3, "f");
    c.ellipse(190, 94, 18, 3, "f");
    c.ellipse(130, 72, 12, 2, "f");
  }),
  layer("river", (c) => {
    c.rect(0, 96, 240, 39, "G");
    c.poly([96, 135, 128, 96, 148, 96, 128, 135], "A");
    c.poly([104, 135, 128, 104, 140, 104, 126, 135], "z");
    c.hline(112, 112, 10, "a");
    c.hline(122, 122, 8, "w");
    c.hline(108, 128, 9, "a");
    c.rect(96, 100, 56, 6, "d");
    c.hline(96, 100, 56, "e");
    for (let x = 100; x < 152; x += 7) c.vline(x, 101, 4, "b");
  }),
  layer("meadow", (c) => {
    const r = c.rng(42);
    for (let i = 0; i < 90; i++)
      c.px(
        Math.floor(r() * 240),
        98 + Math.floor(r() * 35),
        r() < 0.5 ? "g" : "f",
      );
    for (let i = 0; i < 14; i++)
      c.px(
        Math.floor(r() * 240),
        100 + Math.floor(r() * 30),
        ["r", "w", "Y", "h"][i % 4],
      );
    // winding dirt path from bottom-left to the bridge
    for (let t = 0; t < 20; t++) {
      const x = 8 + t * 5,
        y = 130 - t * 1.6;
      c.ellipse(x, y, 7, 3, "o");
      c.px(x - 2, y, "O");
    }
    c.rect(0, 132, 240, 3, "F");
  }),
  layer(
    "structures",
    stamp("_mini-house", 26, 66),
    stamp("_mini-house", 176, 70),
    stamp("_mini-house", 196, 88),
    stamp("_mini-canopy", 10, 76),
    stamp("_mini-canopy", 66, 72),
    stamp("_mini-canopy", 158, 64),
    stamp("_mini-canopy", 214, 60),
    (c) => {
      c.rect(16, 92, 4, 12, "D");
      c.rect(78, 88, 4, 12, "D");
      c.rect(168, 80, 4, 12, "D");
      c.rect(222, 76, 4, 12, "D");
    },
  ),
  layer("signage", (c) => {
    c.rect(112, 76, 4, 18, "b");
    c.rect(96, 68, 38, 12, "d");
    c.box(96, 68, 38, 12, "b");
    c.rect(97, 76, 36, 3, "g");
    c.text(101, 70, "VALLEY", "w");
    c.px(128, 72, "Y");
    c.rect(30, 108, 3, 12, "b");
    c.rect(18, 102, 28, 9, "d");
    c.box(18, 102, 28, 9, "b");
    c.text(22, 104, "START", "l");
  }),
);
