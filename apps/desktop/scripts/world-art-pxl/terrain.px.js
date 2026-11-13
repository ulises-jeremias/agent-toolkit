// Terrain & props — 16px grid, golden-hour valley.
include("palette.px.js")
const R=(c,s)=>c.rng(s)
function blades(c,seed,n,col="f"){const r=R(c,seed);for(let i=0;i<n;i++){const x=1+Math.floor(r()*14),y=2+Math.floor(r()*13);c.px(x,y,col);c.px(x,y-1,col)}}
function dots(c,seed,n,cols){const r=R(c,seed);for(let i=0;i<n;i++){const x=Math.floor(r()*16),y=Math.floor(r()*16);c.px(x,y,cols[Math.floor(r()*cols.length)])}}
function grassBase(c,seed,base="G"){
  // Broad meadow surfaces stay quiet at map scale. One short, low-contrast
  // blade breaks tile seams without turning every square into pixel confetti.
  const r=R(c,seed);const x=2+Math.floor(r()*12),y=2+Math.floor(r()*12);
  c.rect(0,0,16,16,base);c.vline(x,y,2,"x")
}
function grass(name,seed){
  // Grass tiles carry only the broad palette field. Distinct plant marks are
  // placed as complete vegetation sprites so the ground does not dissolve
  // into one random pixel per tile at overview scale.
  sprite(name,{w:16,h:16},(c)=>grassBase(c,seed,"G"))
}
grass("grass-a",1)
grass("grass-b",2)
grass("grass-c",3)
grass("grass-d",4)
grass("grass-e",5)
grass("grass-f",6)
grass("grass-g",7)
grass("grass-h",8)
sprite("dirt",{w:16,h:16},(c)=>{c.rect(0,0,16,16,"o");dots(c,91,3,["O","d","O"]);c.hline(2,4,4,"O");c.hline(9,11,4,"O")})
// dirt with grass edge on named side
function dirtEdge(name,side){sprite(name,{w:16,h:16},(c)=>{c.rect(0,0,16,16,"o");dots(c,93,2,["O","d"]);
  if(side==="n"){c.rect(0,0,16,3,"G");c.hline(0,3,16,"f");blades(c,94,2)}
  if(side==="s"){c.rect(0,13,16,3,"G");c.hline(0,12,16,"f")}
  if(side==="w"){c.rect(0,0,3,16,"G");c.vline(3,0,16,"f")}
  if(side==="e"){c.rect(13,0,3,16,"G");c.vline(12,0,16,"f")}
  if(side==="nw"){c.rect(0,0,16,3,"G");c.rect(0,0,3,16,"G");c.hline(0,3,16,"f");c.vline(3,0,16,"f")}
  if(side==="ne"){c.rect(0,0,16,3,"G");c.rect(13,0,3,16,"G");c.hline(0,3,16,"f");c.vline(12,0,16,"f")}
  if(side==="sw"){c.rect(0,13,16,3,"G");c.rect(0,0,3,16,"G");c.hline(0,12,16,"f");c.vline(3,0,16,"f")}
  if(side==="se"){c.rect(0,13,16,3,"G");c.rect(13,0,3,16,"G");c.hline(0,12,16,"f");c.vline(12,0,16,"f")}}) }
dirtEdge("dirt-n","n");dirtEdge("dirt-s","s");dirtEdge("dirt-e","e");dirtEdge("dirt-w","w")
dirtEdge("dirt-nw","nw");dirtEdge("dirt-ne","ne");dirtEdge("dirt-sw","sw");dirtEdge("dirt-se","se")
function plaza(name,seed,alt){sprite(name,{w:16,h:16},(c)=>{c.rect(0,0,16,16,alt?"P":"p");c.box(0,0,16,16,"q");c.vline(8,0,16,"P");c.hline(0,8,16,alt?"p":"P");dots(c,seed,5,["q","w"])})}
plaza("plaza",101,false);plaza("plaza-b",102,true)
// water: an uneven current over a deep lower plane; reflected light drifts
// along short angled ripples instead of identical ruler-straight bars.
sprite("water",{w:32,h:16},(c)=>{
  for(let f=0;f<2;f++){
    const o=f*16
    c.rect(o,0,16,16,"A")
    c.poly([o,12,o+3,11,o+7,12,o+11,11,o+16,12,o+16,16,o,16],"z")
    c.line(o+1,14,o+5,13,"Z");c.line(o+10,15,o+14,14,"Z")
    if(f===0){
      c.line(o+2,4,o+7,3,"a");c.line(o+9,7,o+13,6,"a")
      c.line(o+3,5,o+6,5,"w");c.line(o+11,8,o+13,8,"w")
      c.px(o+6,10,"a");c.px(o+14,3,"z")
    }else{
      c.line(o+4,3,o+8,4,"a");c.line(o+10,6,o+14,5,"a")
      c.line(o+5,4,o+7,4,"w");c.line(o+12,7,o+14,7,"w")
      c.px(o+2,9,"a");c.px(o+9,11,"z")
    }
  }
})
function waterEdge(name,side){sprite(name,{w:16,h:16},(c)=>{
  // Shore cells remain meadow; only an uneven, shallow lip joins the channel.
  // Filling these tiles with water made a one-tile creek read as a wide canal.
  grassBase(c,side==="e"?311:312);
  if(side==="e"){
    c.poly([11,0,16,0,16,16,12,16,11,13,10,11,11,8,9,6,10,3],"A");
    c.poly([10,0,11,0,10,3,9,6,11,8,10,11,12,13,13,16,11,16,10,13,9,11,10,8,8,6,9,3],"a");
    c.vline(14,2,3,"z");c.px(12,10,"w");
  }
  if(side==="w"){
    c.poly([0,0,5,0,6,3,7,6,5,8,6,11,4,13,3,16,0,16],"A");
    c.poly([5,0,6,0,7,3,8,6,6,8,7,11,5,13,4,16,3,16,4,13,6,11,5,8,7,6,6,3],"a");
    c.vline(2,2,3,"z");c.px(4,10,"w");
  }
  if(side==="n"){
    c.poly([0,11,3,10,6,11,9,9,12,10,16,9,16,16,0,16],"A");
    c.poly([0,10,3,9,6,10,9,8,12,9,16,8,16,10,12,11,9,10,6,12,3,11,0,12],"a");
    c.hline(3,13,4,"z");c.px(12,11,"w");
  }
  if(side==="s"){
    c.poly([0,0,16,0,16,7,12,6,9,8,6,7,3,9,0,8],"A");
    c.poly([0,8,3,9,6,7,9,8,12,6,16,7,16,9,12,8,9,10,6,9,3,11,0,10],"a");
    c.hline(9,2,4,"z");c.px(3,7,"w");
  }
})}
waterEdge("water-edge-n","n");waterEdge("water-edge-s","s");waterEdge("water-edge-e","e");waterEdge("water-edge-w","w")
sprite("bridge",{w:48,h:48},(c)=>{c.rect(0,0,48,48,"A");c.rect(0,34,48,14,"z");c.rect(0,44,48,4,"Z");
  c.hline(3,4,7,"a");c.hline(30,7,6,"a");c.hline(12,11,5,"w");c.hline(36,2,5,"a");c.hline(5,40,6,"a");c.hline(28,42,7,"a");c.hline(40,37,5,"w");c.px(20,5,"z");c.px(8,44,"A");
  // hard shadow cast on the water under the deck (offset down-right)
  c.rect(3,27,44,11,"Z");c.hline(6,38,38,"z");
  // deck: middle band only, planks run across the crossing (vertical strips along the walk)
  c.rect(0,19,48,13,"d");c.hline(0,19,48,"e");c.hline(0,31,48,"D");
  for(let x=0;x<48;x+=6){c.vline(x+5,20,11,"b");c.px(x+2,23,"D");c.px(x+3,28,"b")}
  c.px(9,21,"k");c.px(33,29,"k");
  // railings: posts + a single top rail per side, creek stays visible between the posts
  for(let x=2;x<47;x+=11){c.rect(x,14,3,6,"D");c.px(x,14,"d");c.rect(x,28,3,7,"D");c.px(x,28,"d")}
  c.rect(0,13,48,3,"b");c.hline(0,13,48,"d");c.rect(0,33,48,3,"b");c.hline(0,35,48,"D");
  // worn entry stones at both deck ends
  c.rect(0,20,6,11,"P");c.rect(42,20,6,11,"P");c.hline(0,25,6,"q");c.hline(42,24,6,"q");c.vline(3,20,11,"q");c.vline(44,20,11,"q");c.px(1,21,"p");c.px(46,29,"p");c.px(4,28,"w");c.px(43,22,"w")})
function flowers(name,col,seed){sprite(name,{w:16,h:16},(c)=>{grassBase(c,seed);const r=R(c,seed+9);for(const [cx,cy] of [[5,8],[11,5]]){const x=cx+Math.floor(r()*3)-1,y=cy+Math.floor(r()*3)-1;c.vline(x,y+1,2,"f");c.px(x,y,col);c.px(x-1,y+1,"g")}if(col==="w")c.px(5,8,"Y")})}
flowers("flowers-poppy","r",201);flowers("flowers-daisy","w",202);flowers("flowers-lavender","V",203);flowers("flowers-gold","Y",204)
sprite("bush",{w:16,h:12},(c)=>{c.ellipse(8,8,7,4,"F");c.circ(5,6,3,"G");c.circ(10,5,4,"G");c.circ(8,4,3,"g");c.px(4,4,"g");c.px(11,3,"g");c.px(6,7,"r");c.px(12,7,"r");c.hline(4,11,9,"k")})
sprite("rock",{w:16,h:12},(c)=>{c.poly([1,11,3,5,7,2,13,4,15,11],"M");c.poly([3,5,7,2,10,4,6,6],"m");c.hline(2,11,13,"k");c.px(5,4,"w")})
sprite("tall-grass",{w:16,h:8},(c)=>{for(let x=1;x<16;x+=3){c.vline(x,3,5,"f");c.px(x+1,2,"G");c.vline(x+1,4,4,"G")}c.hline(1,7,14,"F")})
sprite("mushroom",{w:16,h:12},(c)=>{c.rect(6,6,4,5,"c");c.hline(5,11,6,"e");c.ellipse(8,5,7,3,"r");c.px(4,4,"w");c.px(10,3,"w");c.px(8,6,"u");c.hline(1,11,14,"F")})
sprite("reeds",{w:16,h:16},(c)=>{c.rect(0,13,16,3,"A");c.hline(0,13,16,"a");for(let x=2;x<15;x+=4){c.vline(x,3,11,"f");c.vline(x+1,5,9,"G");c.ellipse(x,2,1,2,"O")}c.px(6,8,"g")})
sprite("lily",{w:16,h:16},(c)=>{c.rect(0,0,16,16,"A");c.hline(2,4,5,"a");c.ellipse(6,9,4,2,"f");c.ellipse(11,12,3,2,"G");c.px(8,7,"h");c.px(8,6,"w");c.px(5,12,"a")})
sprite("stump",{w:16,h:12},(c)=>{c.rect(3,4,10,7,"D");c.ellipse(8,4,5,2,"d");c.ring(8,4,2,"e");c.vline(5,6,4,"b");c.vline(11,6,4,"b");c.px(2,3,"G");c.px(13,2,"g");c.hline(2,11,12,"k")})
sprite("fence-h",{w:16,h:12},(c)=>{c.rect(1,3,3,8,"D");c.rect(12,3,3,8,"D");c.rect(0,5,16,2,"d");c.rect(0,9,16,2,"d");c.hline(0,5,16,"b");c.hline(0,10,16,"b");c.px(2,4,"k");c.px(13,4,"k")})
sprite("fence-v",{w:12,h:16},(c)=>{c.rect(4,0,3,16,"D");c.rect(1,4,10,2,"d");c.rect(1,11,10,2,"d");c.vline(4,0,16,"b");c.px(5,2,"k")})
sprite("sign",{w:16,h:16},(c)=>{c.rect(7,7,2,8,"b");c.rect(2,1,12,7,"d");c.box(2,1,12,7,"b");c.hline(4,4,8,"c");c.hline(4,6,5,"e");c.px(12,3,"Y")})
// --- Round 3 append: more grass, wildflower patches, worn trails ---
grass("grass-i",9)
grass("grass-j",10)
grass("grass-k",11)
grass("grass-l",12)
grass("grass-m",13)
grass("grass-n",14)
grass("grass-o",15)
grass("grass-p",16)
grass("grass-q",17)
grass("grass-r",18)
grass("grass-s",19)
grass("grass-t",20)
grass("grass-u",21)
grass("grass-v",22)
grass("grass-w",23)
grass("grass-x",24)
function wildPatch(name,main,light,seed){sprite(name,{w:40,h:28},(c)=>{c.rect(0,0,40,28,"G");const r=R(c,seed);for(const [cx,cy] of [[7,17],[15,10],[25,18],[33,12]]){const x=cx+Math.floor(r()*5)-2,y=cy+Math.floor(r()*3)-1;c.vline(x,y+2,3,"f");c.vline(x+1,y+3,2,"f");c.px(x,y,main);c.px(x-1,y+1,light);c.px(x+1,y,main)}for(const [x,y] of [[5,22],[19,20],[29,23]]){c.px(x,y,"w");c.vline(x,y+1,2,"f")}})}
wildPatch("wildflower-patch-rose","r","h",501)
wildPatch("wildflower-patch-lilac","V","v",502)
wildPatch("wildflower-patch-gold","Y","L",503)
// trail shapes: connections N/S/E/W; path ~8px wide, irregular worn edges
const TRAIL={dot:[], "end-n":["N"],"end-s":["S"],"end-w":["W"],"end-e":["E"],v:["N","S"],h:["W","E"],"turn-nw":["N","W"],"turn-ne":["N","E"],"turn-sw":["S","W"],"turn-se":["S","E"],"tee-e":["N","S","E"],"tee-w":["N","S","W"],"tee-n":["W","E","N"],"tee-s":["W","E","S"],cross:["N","S","E","W"]}
function trail(shape,v){sprite(`trail-${shape}-${v}`,{w:16,h:16},(c)=>{grassBase(c,600+v*7+shape.length);const cs=TRAIL[shape];
  if(shape==="dot"){c.ellipse(8,8,4,4,"o");c.ellipse(8,8,3,2,"o");c.px(7,7,"O");c.px(9,9,"d")}
  else{const arm=(d)=>{if(d==="N")c.rect(4,0,8,8,"o");if(d==="S")c.rect(4,8,8,8,"o");if(d==="W")c.rect(0,4,8,8,"o");if(d==="E")c.rect(8,4,8,8,"o")};cs.forEach(arm);c.rect(4,4,8,8,"o")}
  const r=R(c,700+v*31+shape.charCodeAt(0)*3+shape.length*17);
  for(let i=0;i<4;i++){const x=Math.floor(r()*16),y=Math.floor(r()*16);if(c.is(x,y,"o"))c.px(x,y,["O","d","P","o"][Math.floor(r()*4)])}
  // worn irregular edges: grass bites into path, dirt specks into grass
  for(let i=0;i<4;i++){const x=Math.floor(r()*16),y=Math.floor(r()*16);if(c.is(x,y,"o")&&(x<5||x>10||y<5||y>10))c.px(x,y,r()>.5?"G":"f")}
  for(let i=0;i<2;i++){const x=Math.floor(r()*16),y=Math.floor(r()*16);if(!c.is(x,y,"o"))c.px(x,y,"o")}
  c.px(7,7,"P");if(shape!=="dot")c.px(9,10,"O")})}
for(const shape of Object.keys(TRAIL))for(let v=0;v<4;v++)trail(shape,v)
