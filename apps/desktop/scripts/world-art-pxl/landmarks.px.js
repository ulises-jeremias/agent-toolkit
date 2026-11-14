// Landmarks — each: distinct silhouette + one signature detail.
include("palette.px.js")
function shingle(c,ax,ay,by,half,dl,dr){for(let y=ay+4,i=0;y<by;y+=4,i++){const t=(y-ay)/(by-ay),hw=Math.max(2,Math.round(half*t)),lx=ax-hw,rx=ax+hw;c.hline(lx,y,ax-lx,dl);c.hline(ax,y,rx-ax,dr);const off=(i%2)*3;for(let x=lx+3+off;x<rx-2;x+=7)c.vline(x,y,2,x<ax?dl:dr)}}
function roofDark(col){return {T:"u",S:"n",v:"k",n:"k",A:"z",u:"b",r:"u",g:"G",G:"f"}[col]||"k"}
function hall(c,w,h,wall,roof){const cx=w/2;c.ellipse(cx,h-2,w/2-2,2,"q");c.rect(6,30,w-12,h-32,wall);c.poly([cx,14,w-2,32,2,32],roof);shingle(c,cx,14,32,w/2-2,roofDark(roof),roofDark(roof));c.hline(4,31,w-8,"k");c.rect(cx-5,h-18,10,16,"D");c.px(cx+3,h-10,"Y");c.rect(10,40,8,10,"n");c.rect(11,41,6,8,"L");c.rect(w-18,40,8,10,"n");c.rect(w-17,41,6,8,"A")}
function clock(c,x,y){c.circ(x,y,6,"w");c.ring(x,y,6,"k");c.line(x,y,x,y-4,"k");c.line(x,y,x+3,y+1,"k");c.px(x,y,"r")}
sprite("landmark-workspace",{w:48,h:72},(c)=>{hall(c,48,72,"c","T");c.rect(18,2,12,16,"c");c.poly([24,0,32,8,16,8],"u");shingle(c,24,0,8,8,"b","b");clock(c,24,12);c.rect(8,58,32,3,"r");c.px(10,59,"L");c.px(37,59,"L");c.rect(13,58,6,3,"w");c.vline(16,58,3,"r");c.hline(22,59,4,"c");c.px(27,59,"w");c.hline(30,59,4,"c");c.px(20,59,"Y")})
sprite("landmark-archive",{w:48,h:72},(c)=>{
  // A stone record house with a narrow catalog tower and vault-like roofline.
  c.ellipse(24,69,23,2,"q");
  c.poly([5,33,43,33,45,65,4,65],"P");
  c.poly([39,34,44,33,45,64,39,65],"S");
  c.rect(6,36,35,28,"s");
  c.poly([4,35,4,30,8,26,40,26,45,31,45,36],"n");
  c.poly([6,32,10,28,38,28,42,32],"S");
  c.hline(5,35,39,"k");c.hline(7,37,35,"m");
  // Offset archive tower: three deep-set slots hold the valley's records.
  c.rect(7,8,14,24,"S");
  c.poly([5,11,10,3,18,3,23,11],"n");
  c.poly([8,10,11,5,17,5,20,10],"M");
  c.hline(7,12,15,"k");
  for(let i=0;i<3;i++){
    const y=15+i*5;
    c.rect(10,y,8,4,"Z");c.box(10,y,8,4,"k");
    c.vline(12,y+1,2,"Y");c.vline(15,y+1,2,i===1?"t":"g");
  }
  c.rect(12,31,5,6,"D");
  // Ledger niches along the reading wall; each shelf has distinct folios.
  for(let i=0;i<3;i++){
    const x=9+i*11;
    c.rect(x,42,8,12,"n");c.box(x,42,8,12,"k");
    c.rect(x+1,43,6,10,"D");
    c.vline(x+2,44,7,"r");c.vline(x+4,44,7,"Y");c.vline(x+6,44,7,"a");
    c.hline(x+1,51,6,"b");
  }
  // Arched vault entrance and a stone lintel stamped with the archive seal.
  c.poly([18,65,18,52,20,48,27,48,30,52,30,65],"D");
  c.rect(19,53,10,12,"D");c.box(19,53,10,12,"k");
  c.vline(24,54,10,"b");c.px(27,59,"Y");
  c.circ(24,31,3,"j");c.ring(24,31,3,"k");c.hline(21,31,7,"k");
  c.rect(15,65,19,3,"M");c.hline(16,65,17,"w");
  c.rect(4,68,41,2,"q");
})
sprite("landmark-library",{w:64,h:64},(c)=>{
  // The valley library is an old adobe reading room joined to a small kiln
  // tower. Its broad, low roof and tall book gallery distinguish it from the
  // civic hall silhouettes without adding surface-noise pixels.
  c.ellipse(33,61,29,2,"q");
  c.poly([5,32,45,28,57,34,57,56,8,59],"e");
  c.poly([45,32,57,34,57,56,45,58],"P");
  c.rect(8,35,39,21,"c");
  c.poly([47,35,57,34,57,56,47,57],"C");
  c.poly([5,34,26,18,49,34,47,38,8,38],"T");
  c.poly([26,18,49,34,47,38,26,25],"u");
  c.line(26,19,6,34,"k");c.line(26,19,48,34,"k");
  c.hline(7,35,41,"b");
  // A round kiln / archive tower is the library's distant landmark.
  c.rect(45,9,12,26,"T");
  c.poly([44,12,49,5,55,5,59,12],"u");
  c.poly([46,12,50,7,54,7,57,12],"t");
  c.hline(46,13,11,"b");
  c.rect(48,16,7,11,"Z");c.box(48,16,7,11,"D");
  c.vline(51,17,9,"M");
  c.rect(49,29,5,7,"D");c.box(49,29,5,7,"k");
  // Deep-set gallery, timber mullions and warm shelves with restrained books.
  c.rect(12,39,29,13,"D");c.box(12,39,29,13,"k");
  c.rect(15,41,23,9,"Z");
  c.hline(15,45,23,"M");
  const spines=["r","Y","V","g","a","j"];
  for(let row=0;row<2;row++)for(let book=0;book<6;book++){
    const x=17+book*3;
    c.vline(x,42+row*4,3,spines[(book+row*2)%spines.length]);
  }
  c.vline(26,40,12,"d");c.vline(14,40,12,"d");c.vline(39,40,12,"d");
  // Recessed entrance, stone sill, worn step, and a small pair of planters.
  c.rect(22,49,9,10,"D");c.box(22,49,9,10,"k");
  c.vline(26,50,8,"b");c.px(29,54,"Y");
  c.poly([18,57,35,57,38,60,15,60],"M");
  c.poly([11,60,43,60,47,63,7,63],"P");c.hline(9,62,35,"q");
  c.rect(8,50,5,6,"T");c.rect(38,50,5,6,"T");
  c.poly([8,49,11,45,14,49],"G");c.poly([38,49,41,44,44,49],"f");
  c.px(10,46,"g");c.px(12,47,"g");c.px(40,45,"g");c.px(42,47,"G");
})
sprite("landmark-workshop",{w:48,h:72},(c)=>{
  // A sawtooth-roof forge with a wheel at the stream-facing end.
  c.ellipse(23,69,23,2,"q");
  c.poly([5,35,44,35,45,66,5,66],"e");
  c.poly([39,37,45,35,45,65,39,66],"P");
  c.rect(7,37,33,28,"e");
  c.poly([3,37,3,22,14,22,14,31,29,15,45,30,45,38],"n");
  c.poly([4,35,4,24,12,24,12,34,28,18,42,31,42,35],"S");
  c.poly([5,24,12,24,12,30,5,30],"M");
  c.poly([15,31,28,19,33,24,21,35],"m");
  c.poly([32,25,42,32,42,35,36,35],"M");
  c.hline(4,36,41,"k");
  // Brick flue, with a hood that catches the warm light.
  c.rect(7,8,8,17,"u");c.vline(9,10,13,"T");
  c.hline(5,7,12,"b");c.rect(8,5,7,3,"D");c.px(10,4,"L");
  // Wide split forge doors beneath the sheltered loading bay.
  c.rect(11,43,22,21,"D");c.box(11,43,22,21,"k");
  c.rect(13,45,9,17,"d");c.rect(23,45,8,17,"D");
  c.vline(22,44,19,"b");c.vline(23,44,19,"b");
  for(let y=47;y<61;y+=4){c.hline(14,y,7,"b");c.hline(24,y,6,"b")}
  c.px(20,53,"Y");c.px(28,53,"Y");
  // Waterwheel, rim and eight spokes, partly seated in its stone race.
  c.ring(41,51,6,"D");c.ring(41,51,5,"b");
  c.line(41,46,41,56,"d");c.line(36,51,46,51,"d");
  c.line(37,47,45,55,"d");c.line(45,47,37,55,"d");
  c.circ(41,51,2,"Y");
  c.poly([31,59,48,59,47,64,33,64],"A");c.hline(33,60,13,"a");
  c.rect(5,65,42,3,"M");c.hline(7,65,38,"w");
})
sprite("landmark-operations",{w:48,h:72},(c)=>{
  // A public map room: hipped clay roof, offset clock cupola and open map porch.
  c.ellipse(24,69,23,2,"q");
  c.poly([5,34,43,34,45,65,4,65],"c");
  c.poly([39,35,44,34,45,64,39,65],"C");
  c.poly([2,36,10,29,25,26,43,31,47,37,4,39],"u");
  c.poly([4,35,12,30,25,28,40,32,44,36],"T");
  c.line(25,28,4,36,"k");c.line(25,28,44,36,"b");
  c.hline(4,37,40,"k");
  // Cupola and clock face mark a civic meeting place from across the valley.
  c.rect(29,15,13,17,"e");
  c.poly([27,17,31,11,40,11,44,17],"S");
  c.poly([30,16,33,12,39,12,42,16],"M");
  c.rect(31,19,9,9,"n");c.circ(35,23,4,"w");c.ring(35,23,4,"k");
  c.line(35,23,35,20,"k");c.line(35,23,38,24,"k");
  c.rect(33,29,5,4,"D");
  // Deep shaded porch holds three framed, inspectable-looking valley maps.
  c.rect(7,42,34,14,"n");c.box(7,42,34,14,"k");
  for(let i=0;i<3;i++){
    const x=10+i*10;
    c.rect(x,45,8,8,"Z");c.box(x,45,8,8,"M");
    c.line(x+1,51,x+4,47,"g");c.line(x+4,47,x+7,50,"Y");
    c.px(x+2,49,"t");c.px(x+6,46,"a");
  }
  c.vline(7,40,20,"D");c.vline(40,40,20,"D");
  c.rect(20,54,9,12,"D");c.box(20,54,9,12,"k");
  c.vline(24,55,10,"b");c.px(27,60,"Y");
  c.poly([17,65,32,65,35,68,14,68],"M");
  c.rect(5,67,39,2,"q");
})
sprite("landmark-terminal",{w:48,h:72},(c)=>{hall(c,48,72,"c","A");c.rect(9,39,10,12,"c");c.rect(29,39,10,12,"c");c.vline(23,0,18,"n");c.vline(24,0,18,"n");c.hline(15,6,18,"n");c.hline(15,7,18,"n");c.px(15,6,"r");c.px(16,6,"r");c.px(24,3,"Y");c.px(32,6,"g");c.px(33,6,"g");c.px(24,12,"a");c.rect(15,42,18,10,"n");c.box(15,42,18,10,"m");c.px(17,44,"g");c.px(21,44,"A");c.px(17,48,"Y")})
sprite("landmark-attention",{w:48,h:72},(c)=>{hall(c,48,72,"c","T");c.rect(14,34,20,16,"d");c.box(14,34,20,16,"b");c.rect(16,36,6,5,"w");c.rect(24,36,8,5,"l");c.rect(17,43,7,5,"V");c.px(28,45,"r");c.poly([24,8,32,20,16,20],"r");shingle(c,24,8,20,8,"u","u");c.px(24,11,"w")})
sprite("landmark-files",{w:64,h:64},(c)=>{c.ellipse(32,62,28,2,"q");c.rect(6,24,52,38,"P");c.poly([32,8,60,26,4,26],"S");shingle(c,32,8,26,28,"n","n");c.hline(6,25,52,"k");for(let i=0;i<4;i++){c.rect(10+i*12,32,9,12,"D");c.hline(11+i*12,35,7,"m");c.px(17+i*12,40,"Y")}c.rect(26,48,12,14,"n");c.px(34,55,"Y")})
sprite("landmark-settings",{w:64,h:64},(c)=>{c.ellipse(32,62,28,2,"q");c.rect(10,34,44,28,"c");c.poly([32,10,58,36,6,36],"g");c.poly([32,10,58,36,32,36],"G");shingle(c,32,10,36,26,"G","f");c.hline(8,35,48,"k");c.circ(32,26,5,"M");c.ring(32,26,5,"k");c.px(32,26,"Y");for(let x=16;x<52;x+=12){c.vline(x,38,20,"D");c.px(x,42,"L")}c.hline(12,52,40,"D");c.rect(28,50,8,12,"D");c.box(28,50,8,12,"k");c.px(34,56,"Y")})
