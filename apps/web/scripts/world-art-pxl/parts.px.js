// Reusable valley parts (trees / water / structures) — web world-art.
// "_" sprites are stamp-only parts; named sprites are exported assets.
include("palette.px.js");
sprite("_canopy", { w: 32, h: 24 }, (c) => {
  c.circ(16, 12, 11, "F");
  c.circ(10, 15, 7, "F");
  c.circ(22, 15, 7, "F");
  c.circ(13, 10, 8, "G");
  c.circ(20, 13, 6, "G");
  c.circ(11, 8, 5, "g");
  c.circ(17, 6, 4, "g");
  c.px(9, 6, "w");
  c.px(15, 4, "g");
});
sprite("tree-round", { w: 32, h: 40 }, (c) => {
  c.ellipse(16, 37, 10, 2, "F");
  c.rect(14, 24, 4, 13, "D");
  c.vline(17, 24, 13, "b");
  c.stamp("_canopy", 0, 0);
});
sprite("tree-blossom", { w: 32, h: 40 }, (c) => {
  c.ellipse(16, 37, 10, 2, "F");
  c.rect(14, 24, 4, 13, "D");
  c.vline(17, 24, 13, "b");
  c.stamp("_canopy", 0, 0);
  const r = c.rng(7);
  for (let i = 0; i < 16; i++)
    c.px(
      5 + Math.floor(r() * 22),
      3 + Math.floor(r() * 18),
      r() < 0.6 ? "h" : "H",
    );
});
sprite("tree-pine", { w: 32, h: 40 }, (c) => {
  c.ellipse(16, 37, 10, 2, "F");
  c.rect(14, 30, 4, 8, "D");
  c.poly([16, 2, 26, 20, 6, 20], "F");
  c.poly([16, 10, 23, 27, 9, 27], "f");
  c.poly([16, 18, 21, 32, 11, 32], "G");
  c.line(16, 4, 11, 16, "g");
  c.line(16, 12, 13, 22, "g");
});
sprite("water-tile", { w: 32, h: 16 }, (c) => {
  c.rect(0, 0, 32, 16, "A");
  c.rect(0, 12, 32, 4, "z");
  c.hline(3, 4, 7, "a");
  c.hline(18, 9, 6, "a");
  c.hline(10, 7, 4, "w");
  c.px(26, 3, "a");
});
sprite("water-edge", { w: 32, h: 16 }, (c) => {
  c.rect(0, 0, 32, 16, "A");
  c.rect(0, 0, 32, 3, "G");
  c.hline(0, 3, 32, "a");
  c.hline(0, 4, 32, "z");
  c.hline(4, 8, 6, "a");
  c.hline(20, 11, 5, "w");
});
sprite("bridge-mini", { w: 48, h: 24 }, (c) => {
  c.rect(0, 0, 48, 24, "A");
  c.rect(0, 18, 48, 6, "Z");
  c.rect(2, 13, 44, 6, "Z");
  c.rect(0, 8, 48, 7, "d");
  c.hline(0, 8, 48, "e");
  c.hline(0, 14, 48, "D");
  for (let x = 5; x < 48; x += 6) c.vline(x, 9, 5, "b");
  for (let x = 2; x < 47; x += 11) {
    c.rect(x, 4, 3, 5, "D");
    c.rect(x, 13, 3, 4, "D");
  }
  c.rect(0, 3, 48, 2, "b");
  c.hline(3, 20, 6, "a");
  c.hline(30, 21, 7, "a");
});
sprite("cottage", { w: 48, h: 40 }, (c) => {
  c.ellipse(24, 37, 20, 2, "q");
  c.rect(8, 18, 32, 18, "c");
  c.rect(8, 18, 32, 3, "C");
  c.poly([24, 4, 42, 19, 6, 19], "T");
  c.poly([24, 4, 42, 19, 24, 19], "u");
  c.hline(7, 18, 34, "k");
  c.rect(21, 26, 7, 10, "D");
  c.px(26, 31, "Y");
  c.rect(11, 24, 7, 7, "n");
  c.rect(12, 25, 5, 5, "L");
  c.rect(31, 24, 7, 7, "n");
  c.rect(32, 25, 5, 5, "A");
  c.rect(34, 6, 5, 10, "M");
  c.px(36, 3, "l");
});
sprite("hall-mini", { w: 48, h: 40 }, (c) => {
  c.ellipse(24, 37, 20, 2, "q");
  c.rect(6, 16, 36, 20, "C");
  c.poly([24, 2, 44, 17, 4, 17], "S");
  c.poly([24, 2, 44, 17, 24, 17], "n");
  c.hline(5, 16, 38, "k");
  c.circ(24, 11, 4, "w");
  c.ring(24, 11, 4, "k");
  c.line(24, 11, 24, 8, "k");
  c.line(24, 11, 26, 12, "k");
  c.rect(20, 26, 8, 10, "D");
  c.px(26, 31, "Y");
  c.rect(10, 24, 6, 6, "n");
  c.rect(11, 25, 4, 4, "l");
  c.rect(32, 24, 6, 6, "n");
  c.rect(33, 25, 4, 4, "l");
});
sprite("flower-patch", { w: 32, h: 16 }, (c) => {
  c.rect(0, 0, 32, 16, "G");
  const r = c.rng(21);
  for (let i = 0; i < 22; i++)
    c.px(Math.floor(r() * 32), Math.floor(r() * 16), r() < 0.5 ? "g" : "f");
  for (let i = 0; i < 7; i++) {
    const x = 2 + Math.floor(r() * 28),
      y = 2 + Math.floor(r() * 12);
    c.px(x, y, ["r", "w", "Y", "V"][i % 4]);
    c.px(x, y + 1, "f");
  }
});
