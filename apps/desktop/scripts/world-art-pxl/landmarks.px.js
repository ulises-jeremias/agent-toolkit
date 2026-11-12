// Landmarks — each: distinct silhouette + one signature detail.
include("palette.px.js")
function shingle(c,ax,ay,by,half,dl,dr){for(let y=ay+4,i=0;y<by;y+=4,i++){const t=(y-ay)/(by-ay),hw=Math.max(2,Math.round(half*t)),lx=ax-hw,rx=ax+hw;c.hline(lx,y,ax-lx,dl);c.hline(ax,y,rx-ax,dr);const off=(i%2)*3;for(let x=lx+3+off;x<rx-2;x+=7)c.vline(x,y,2,x<ax?dl:dr)}}
function roofDark(col){return {T:"u",S:"n",v:"k",n:"k",A:"z",u:"b",r:"u",g:"G",G:"f"}[col]||"k"}
function hall(c,w,h,wall,roof){const cx=w/2;c.ellipse(cx,h-2,w/2-2,2,"q");c.rect(6,30,w-12,h-32,wall);c.poly([cx,14,w-2,32,2,32],roof);shingle(c,cx,14,32,w/2-2,roofDark(roof),roofDark(roof));c.hline(4,31,w-8,"k");c.rect(cx-5,h-18,10,16,"D");c.px(cx+3,h-10,"Y");c.rect(10,40,8,10,"n");c.rect(11,41,6,8,"L");c.rect(w-18,40,8,10,"n");c.rect(w-17,41,6,8,"A")}
function clock(c,x,y){c.circ(x,y,6,"w");c.ring(x,y,6,"k");c.line(x,y,x,y-4,"k");c.line(x,y,x+3,y+1,"k");c.px(x,y,"r")}
sprite("landmark-workspace",{w:48,h:72},(c)=>{hall(c,48,72,"c","T");c.rect(18,2,12,16,"c");c.poly([24,0,32,8,16,8],"u");shingle(c,24,0,8,8,"b","b");clock(c,24,12);c.rect(8,58,32,3,"r");c.px(10,59,"L");c.px(37,59,"L");c.rect(13,58,6,3,"w");c.vline(16,58,3,"r");c.hline(22,59,4,"c");c.px(27,59,"w");c.hline(30,59,4,"c");c.px(20,59,"Y")})
sprite("landmark-archive",{w:48,h:72},(c)=>{hall(c,48,72,"P","S");for(let i=0;i<3;i++){c.rect(9+i*12,34,8,4,"D");c.px(10+i*12,35,"m")}c.circ(24,45,5,"n");c.ring(24,45,5,"j");c.hline(20,45,9,"j");c.vline(24,41,9,"j");c.ring(24,45,2,"j");c.px(24,45,"Y")})
sprite("landmark-library",{w:48,h:64},(c)=>{
  // A little glasshouse reading room: timber-and-stone base, steep glazed
  // roof, one broad book window and a separate, readable entrance.
  c.ellipse(24,61,21,2,"q");
  c.rect(6,24,35,34,"c");
  c.poly([41,24,46,19,46,54,41,58],"e");
  c.rect(4,54,39,7,"P");
  c.hline(5,58,37,"q");
  c.vline(14,54,7,"p");c.vline(27,54,7,"p");c.vline(37,54,7,"p");

  // Tall glazed roof planes give the Library a silhouette no other landmark
  // uses. The inked ribs are structural mullions, not surface noise.
  c.poly([24,1,46,21,2,21],"A");
  c.poly([24,1,46,21,24,21],"z");
  c.line(24,2,3,20,"k");c.line(24,2,45,20,"k");
  c.line(24,3,8,18,"a");c.line(24,3,40,18,"A");
  c.line(24,3,15,16,"z");c.line(24,3,33,16,"z");
  c.hline(8,17,32,"z");c.hline(4,20,40,"k");
  c.poly([18,7,24,10,24,15,18,12],"w");
  c.poly([24,10,30,7,30,12,24,15],"C");
  c.vline(24,10,5,"u");

  // Broad reading window: deep frame, warm shelves and distinct book spines.
  c.rect(9,24,30,23,"n");
  c.rect(11,26,26,19,"Z");
  c.rect(13,28,10,15,"D");c.rect(25,28,10,15,"D");
  const spines=["r","Y","V","g","a","j"];
  for(let shelf=0;shelf<2;shelf++){
    const sy=29+shelf*7;
    for(let book=0;book<5;book++){
      const bx=14+book*4+(book>2?1:0);
      c.vline(bx,sy,5,spines[(book+shelf*2)%spines.length]);
    }
    c.hline(13,sy+5,22,"b");
  }
  c.vline(24,26,19,"M");
  c.hline(10,35,28,"M");
  c.vline(7,21,34,"D");c.vline(40,21,34,"D");
  c.hline(7,22,34,"d");

  // Separate timber door, brass handle, steps and two potted library plants.
  c.rect(19,45,10,14,"D");c.box(19,45,10,14,"k");
  c.vline(24,46,12,"b");c.px(27,52,"Y");
  c.rect(18,59,12,2,"M");
  c.rect(7,47,5,5,"T");c.rect(34,47,5,5,"T");
  c.px(7,45,"G");c.px(9,43,"g");c.px(11,45,"f");
  c.px(34,45,"G");c.px(36,43,"g");c.px(38,45,"f");
})
sprite("landmark-workshop",{w:48,h:72},(c)=>{hall(c,48,72,"e","S");c.rect(34,6,7,22,"M");c.hline(33,5,9,"k");c.px(36,2,"L");c.px(38,0,"l");c.px(35,4,"J");for(let x=8;x<28;x+=6){c.rect(x,44,3,5,"r");c.rect(x+3,44,3,5,"w")}c.px(12,58,"J");c.line(10,60,16,54,"M")})
sprite("landmark-operations",{w:48,h:72},(c)=>{hall(c,48,72,"c","n");clock(c,24,22);c.circ(13,54,4,"M");c.ring(13,54,4,"n");c.circ(35,54,4,"M");c.ring(35,54,4,"n");c.px(13,50,"Y");c.px(35,58,"Y");c.px(24,58,"A")})
sprite("landmark-terminal",{w:48,h:72},(c)=>{hall(c,48,72,"c","A");c.rect(9,39,10,12,"c");c.rect(29,39,10,12,"c");c.vline(23,0,18,"n");c.vline(24,0,18,"n");c.hline(15,6,18,"n");c.hline(15,7,18,"n");c.px(15,6,"r");c.px(16,6,"r");c.px(24,3,"Y");c.px(32,6,"g");c.px(33,6,"g");c.px(24,12,"a");c.rect(15,42,18,10,"n");c.box(15,42,18,10,"m");c.px(17,44,"g");c.px(21,44,"A");c.px(17,48,"Y")})
sprite("landmark-attention",{w:48,h:72},(c)=>{hall(c,48,72,"c","T");c.rect(14,34,20,16,"d");c.box(14,34,20,16,"b");c.rect(16,36,6,5,"w");c.rect(24,36,8,5,"l");c.rect(17,43,7,5,"V");c.px(28,45,"r");c.poly([24,8,32,20,16,20],"r");shingle(c,24,8,20,8,"u","u");c.px(24,11,"w")})
sprite("landmark-files",{w:64,h:64},(c)=>{c.ellipse(32,62,28,2,"q");c.rect(6,24,52,38,"P");c.poly([32,8,60,26,4,26],"S");shingle(c,32,8,26,28,"n","n");c.hline(6,25,52,"k");for(let i=0;i<4;i++){c.rect(10+i*12,32,9,12,"D");c.hline(11+i*12,35,7,"m");c.px(17+i*12,40,"Y")}c.rect(26,48,12,14,"n");c.px(34,55,"Y")})
sprite("landmark-settings",{w:64,h:64},(c)=>{c.ellipse(32,62,28,2,"q");c.rect(10,34,44,28,"c");c.poly([32,10,58,36,6,36],"g");c.poly([32,10,58,36,32,36],"G");shingle(c,32,10,36,26,"G","f");c.hline(8,35,48,"k");c.circ(32,26,5,"M");c.ring(32,26,5,"k");c.px(32,26,"Y");for(let x=16;x<52;x+=12){c.vline(x,38,20,"D");c.px(x,42,"L")}c.hline(12,52,40,"D");c.rect(28,50,8,12,"D");c.box(28,50,8,12,"k");c.px(34,56,"Y")})
