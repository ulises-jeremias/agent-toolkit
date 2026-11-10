// Terrain & props — 16px grid, golden-hour valley.
include("palette.px.js")
const R=(c,s)=>c.rng(s)
function blades(c,seed,n,col="f"){const r=R(c,seed);for(let i=0;i<n;i++){const x=1+Math.floor(r()*14),y=2+Math.floor(r()*13);c.px(x,y,col);c.px(x,y-1,col)}}
function dots(c,seed,n,cols){const r=R(c,seed);for(let i=0;i<n;i++){const x=Math.floor(r()*16),y=Math.floor(r()*16);c.px(x,y,cols[Math.floor(r()*cols.length)])}}
function grassBase(c,seed){c.rect(0,0,16,16,"G");dots(c,seed,10,["g","f"]);c.px(1,1,"g");c.px(14,3,"g")}
function grass(name,seed,fn){sprite(name,{w:16,h:16},(c)=>{grassBase(c,seed);fn&&fn(c)})}
grass("grass-a",1)
grass("grass-b",2,c=>blades(c,21,5))
grass("grass-c",3,c=>{blades(c,31,3);c.px(3,5,"r");c.px(11,10,"w");c.px(7,13,"Y")})
grass("grass-d",4,c=>blades(c,41,9))
grass("grass-e",5,c=>{dots(c,51,16,["g","g","f"]);c.px(4,4,"g");c.px(12,12,"g")})
grass("grass-f",6,c=>{blades(c,61,4,"g");c.px(9,4,"V");c.px(5,11,"w")})
grass("grass-g",7,c=>{blades(c,71,12,"f");blades(c,72,3,"g")})
grass("grass-h",8,c=>{c.px(2,8,"f");c.px(13,6,"f");blades(c,81,2);c.px(8,9,"Y")})
sprite("dirt",{w:16,h:16},(c)=>{c.rect(0,0,16,16,"o");dots(c,91,12,["O","d","O"]);c.hline(2,4,4,"O");c.hline(9,11,4,"O")})
// dirt with grass edge on named side
function dirtEdge(name,side){sprite(name,{w:16,h:16},(c)=>{c.rect(0,0,16,16,"o");dots(c,93,8,["O","d"]);
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
// water: 32x16, frame0/frame1 differ by wave offset
sprite("water",{w:32,h:16},(c)=>{c.rect(0,0,32,16,"A");c.rect(0,12,32,4,"z");
  for(let f=0;f<2;f++){const o=f*16;c.hline(o+2,4,6,"a");c.hline(o+9,9,5,"a");c.px(o+4,12,"z");c.px(o+12,3,"z");if(f){c.hline(o+5,6,4,"w")}else{c.hline(o+3,7,4,"w")}}})
function waterEdge(name,side){sprite(name,{w:16,h:16},(c)=>{c.rect(0,0,16,16,"A");c.hline(2,5,6,"a");c.hline(8,10,5,"a");
  if(side==="n"){c.rect(0,0,16,3,"G");c.hline(0,3,16,"a");c.hline(0,4,16,"z")}
  if(side==="s"){c.rect(0,13,16,3,"G");c.hline(0,12,16,"a");c.hline(0,11,16,"z")}
  if(side==="w"){c.rect(0,0,3,16,"G");c.vline(3,0,16,"a");c.vline(4,0,16,"z")}
  if(side==="e"){c.rect(13,0,3,16,"G");c.vline(12,0,16,"a");c.vline(11,0,16,"z")}})}
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
function flowers(name,col,seed){sprite(name,{w:16,h:16},(c)=>{grassBase(c,seed);const r=R(c,seed+9);for(let i=0;i<5;i++){const x=2+Math.floor(r()*12),y=3+Math.floor(r()*11);c.px(x,y,"f");c.px(x,y+1,"f");c.px(x,y-1,col);c.px(x-1,y,col);c.px(x+1,y,col);c.px(x,y,col==="w"?"Y":col==="Y"?"w":col)}if(col==="w"){c.px(8,6,"Y")}})}
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
