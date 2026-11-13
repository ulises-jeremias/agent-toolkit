// Houses 48x64 — distinct silhouettes, shared _roof/_window/_door parts.
include('palette.px.js');
sprite('_window-lit', { w: 8, h: 10 }, (c) => {
  c.rect(0, 0, 8, 10, 'D');
  c.rect(1, 1, 6, 8, 'L');
  c.px(2, 2, 'w');
  c.vline(4, 1, 8, 'D');
  c.hline(1, 5, 6, 'D');
});
sprite('_window', { w: 8, h: 10 }, (c) => {
  c.rect(0, 0, 8, 10, 'D');
  c.rect(1, 1, 6, 8, 'S');
  c.px(2, 2, 's');
  c.vline(4, 1, 8, 'D');
  c.hline(1, 5, 6, 'D');
});
sprite('_door', { w: 10, h: 16 }, (c) => {
  c.rect(0, 0, 10, 16, 'D');
  c.rect(1, 1, 8, 14, 'd');
  c.px(7, 8, 'Y');
  c.vline(5, 1, 14, 'b');
  c.hline(1, 4, 8, 'b');
});
sprite('_roof', { w: 48, h: 18 }, (c) => {
  c.poly([24, 0, 48, 18, 0, 18], 'T');
  c.poly([24, 0, 48, 18, 24, 18], 'u');
  shingle(c, 24, 0, 18, 24, 'u', 'b');
  c.hline(2, 16, 44, 'k');
});
function shingle(c, ax, ay, by, half, dl, dr) {
  for (let y = ay + 4, i = 0; y < by; y += 4, i++) {
    const t = (y - ay) / (by - ay),
      hw = Math.max(2, Math.round(half * t)),
      lx = ax - hw,
      rx = ax + hw;
    c.hline(lx, y, ax - lx, dl);
    c.hline(ax, y, rx - ax, dr);
    const off = (i % 2) * 3;
    for (let x = lx + 3 + off; x < rx - 2; x += 7) c.vline(x, y, 2, x < ax ? dl : dr);
  }
}
function base(c, x, y, w, h, wall) {
  c.ellipse(24, 62, 20, 2, 'q');
  c.rect(x, y, w, h, wall);
  c.vline(x + w - 3, y, h, 'e');
  c.hline(x, 60, w, 'k');
  c.rect(x, 58, w, 3, 'M');
}
function timber(c, x, y, w) {
  c.vline(x + 2, y, 22, 'D');
  c.vline(x + w - 3, y, 22, 'D');
  c.hline(x, y + 1, w, 'D');
}
sprite('house-cottage', { w: 48, h: 64 }, (c) => {
  // A compact river-quarter homestead: masonry footing, a deep side wall,
  // broad offset roof, sheltered porch and deliberately asymmetric chimney.
  c.ellipse(25, 60, 22, 3, 'q');
  // Chimney and rear return sit behind the roof and front wall.
  c.poly([34, 5, 41, 3, 42, 21, 36, 23], 'u');
  c.vline(38, 6, 14, 'T');
  c.hline(32, 5, 12, 'k');
  c.poly([28, 25, 42, 28, 42, 55, 29, 58], 'C');
  c.poly([29, 29, 40, 31, 40, 54, 29, 56], 'e');
  c.vline(36, 31, 23, 'O');
  c.hline(30, 53, 10, 'D');
  // Lit side window, set into the shaded return.
  c.rect(33, 34, 6, 9, 'D');
  c.rect(34, 35, 4, 7, 'L');
  c.vline(36, 35, 7, 'D');
  c.hline(34, 38, 4, 'D');
  // Front wall is a shallow trapezoid rather than a flat rectangle.
  c.poly([5, 28, 29, 25, 29, 56, 5, 58], 'c');
  c.poly([5, 53, 29, 52, 29, 57, 5, 59], 'e');
  c.hline(5, 57, 25, 'D');
  c.hline(5, 59, 25, 'M');
  // Exposed corner posts and a carved lintel articulate the plaster bays.
  c.vline(7, 30, 25, 'D');
  c.vline(27, 28, 24, 'D');
  c.hline(7, 31, 20, 'D');
  c.hline(8, 33, 18, 'C');
  // Main roof: long ridge, two visible planes and staggered tile courses.
  c.poly([18, 7, 44, 23, 43, 28, 28, 32, 3, 28], 'T');
  c.poly([18, 7, 44, 23, 43, 27, 28, 31], 'u');
  c.poly([18, 7, 28, 31, 3, 28], 't');
  c.line(18, 7, 44, 23, 'k');
  c.line(3, 28, 28, 31, 'k');
  c.line(28, 31, 43, 27, 'k');
  c.line(15, 12, 39, 27, 'u');
  c.line(10, 17, 35, 30, 'u');
  c.line(5, 22, 29, 32, 'u');
  c.line(19, 13, 18, 17, 'b');
  c.line(26, 17, 24, 21, 'b');
  c.line(33, 21, 31, 25, 'b');
  c.line(40, 25, 38, 27, 'b');
  c.vline(12, 24, 4, 'b');
  c.vline(20, 26, 5, 'b');
  c.vline(28, 27, 5, 'b');
  c.hline(5, 29, 25, 'k');
  c.hline(29, 31, 14, 'k');
  // Deep-set window with working shutters and a stone sill.
  c.rect(9, 36, 10, 12, 'D');
  c.rect(10, 37, 8, 9, 'S');
  c.rect(11, 38, 6, 7, 'L');
  c.vline(14, 38, 7, 'D');
  c.hline(11, 41, 6, 'D');
  c.rect(7, 36, 2, 11, 'd');
  c.rect(19, 35, 2, 12, 'd');
  c.hline(7, 48, 14, 'M');
  c.hline(8, 49, 12, 'w');
  // Porch canopy, brackets and posts create foreground depth around the door.
  c.poly([19, 35, 28, 32, 36, 37, 27, 40], 'S');
  c.poly([19, 35, 28, 32, 27, 35, 19, 38], 'n');
  c.line(20, 35, 28, 32, 'k');
  c.line(28, 32, 36, 37, 'k');
  c.vline(21, 38, 17, 'D');
  c.vline(34, 39, 15, 'D');
  c.hline(20, 39, 14, 'b');
  c.hline(21, 40, 12, 'd');
  // Recessed door, brass latch, sill and two broad stone steps.
  c.rect(23, 42, 9, 15, 'D');
  c.box(23, 42, 9, 15, 'k');
  c.rect(24, 43, 7, 13, 'd');
  c.vline(28, 44, 11, 'b');
  c.hline(24, 46, 7, 'D');
  c.px(30, 50, 'Y');
  c.hline(22, 57, 12, 'b');
  c.poly([20, 58, 35, 58, 38, 61, 17, 61], 'P');
  c.poly([15, 61, 40, 61, 43, 63, 12, 63], 'q');
  c.hline(14, 61, 25, 'p');
  // Entrance lantern and a small planted trough anchor the threshold.
  c.vline(36, 40, 5, 'D');
  c.rect(35, 42, 4, 4, 'L');
  c.box(35, 42, 4, 4, 'D');
  c.px(36, 43, 'w');
  c.hline(34, 47, 6, 'b');
  c.rect(4, 51, 7, 4, 'd');
  c.hline(4, 50, 7, 'b');
  c.px(5, 49, 'g');
  c.px(7, 48, 'G');
  c.px(9, 49, 'g');
  // Grounded side shadow and a single warm flower beside the steps.
  c.poly([40, 55, 43, 54, 45, 59, 41, 60], 'q');
  c.px(41, 56, 'h');
  c.px(42, 55, 'w');
  c.px(43, 56, 'H');
});
sprite(
  'house-studio',
  { w: 48, h: 64 },
  (c) => {
    base(c, 5, 32, 38, 30, 'c');
    c.poly([24, 10, 45, 34, 3, 34], 'S');
    c.poly([24, 10, 45, 34, 24, 34], 'n');
    shingle(c, 24, 10, 34, 21, 'n', 'k');
    c.hline(5, 33, 38, 'k');
    c.rect(10, 38, 20, 16, 'n');
    c.rect(11, 39, 18, 14, 'A');
    c.rect(18, 43, 4, 3, 'a');
    c.px(13, 41, 'w');
    c.line(24, 44, 28, 40, 'a');
    c.vline(17, 39, 14, 'n');
    c.vline(23, 39, 14, 'n');
    c.hline(11, 46, 18, 'n');
    c.rect(38, 14, 4, 10, 'M');
  },
  stamp('_door', 34, 46),
  stamp('_window-lit', 38, 38),
);
sprite(
  'house-workshop',
  { w: 48, h: 64 },
  (c) => {
    base(c, 4, 34, 40, 28, 'e');
    timber(c, 4, 36, 40);
    c.poly([24, 14, 46, 36, 2, 36], 'S');
    shingle(c, 24, 14, 36, 22, 'n', 'n');
    c.hline(4, 35, 40, 'k');
    // striped awning
    for (let x = 6; x < 30; x += 6) {
      c.rect(x, 42, 3, 5, 'r');
      c.rect(x + 3, 42, 3, 5, 'w');
    }
    c.hline(6, 47, 24, 'k');
    c.rect(32, 38, 12, 6, 'd');
    c.hline(34, 41, 8, 'Y');
  },
  stamp('_door', 34, 48),
  stamp('_window', 8, 50),
);
// tools hint beside door (drawn after stamps via function order note: stamps above run before this? keep simple)
sprite(
  'house-tower',
  { w: 48, h: 64 },
  (c) => {
    base(c, 14, 28, 22, 34, 'c');
    c.rect(18, 8, 14, 8, 'S');
    c.poly([25, 0, 38, 30, 12, 30], 'u');
    c.poly([25, 0, 38, 30, 25, 30], 'T');
    shingle(c, 25, 0, 30, 13, 'b', 'u');
    c.hline(13, 29, 24, 'k');
    c.px(24, 4, 'Y');
  },
  stamp('_window-lit', 21, 20),
  stamp('_window', 21, 36),
  stamp('_door', 20, 46),
);
sprite(
  'house-cabin',
  { w: 48, h: 64 },
  (c) => {
    base(c, 4, 38, 40, 24, 'd');
    for (let y = 42; y < 60; y += 4) c.hline(4, y, 40, 'b');
    c.px(6, 40, 'e');
    c.px(40, 48, 'e');
    c.poly([24, 22, 47, 40, 1, 40], 'D');
    c.poly([24, 22, 47, 40, 24, 40], 'b');
    shingle(c, 24, 22, 40, 23, 'b', 'k');
    c.hline(3, 39, 42, 'k');
    c.rect(8, 26, 5, 8, 'M');
  },
  stamp('_door', 12, 46),
  stamp('_window-lit', 30, 44),
);
sprite(
  'house-brick',
  { w: 48, h: 64 },
  (c) => {
    base(c, 6, 32, 36, 30, 'T');
    for (let y = 36; y < 60; y += 4) {
      c.hline(6, y, 36, 'u');
      for (let x = 10 + ((y / 4) % 2) * 6; x < 42; x += 12) c.vline(x, y, 4, 'u');
    }
    c.poly([24, 12, 44, 34, 4, 34], 'n');
    c.poly([24, 12, 44, 34, 24, 34], 'S');
    shingle(c, 24, 12, 34, 20, 'k', 'n');
    c.hline(6, 33, 36, 'k');
    c.ellipse(24, 50, 7, 8, 'D');
    c.rect(18, 50, 12, 12, 'D');
  },
  stamp('_window-lit', 10, 38),
  stamp('_window', 32, 38),
  stamp('_door', 19, 48),
);
