// Trees 48x48 — canopy volume: dark base, mid, lit top-left, trunk shadow side, ground shadow.
include("palette.px.js")
function shadowTrunk(c,h=14){c.ellipse(24,44,13,3,"F");c.rect(22,32,5,h,"D");c.vline(26,32,h,"b");c.vline(22,32,h,"d");c.line(22,38,18,43,"D");c.line(27,38,31,43,"b")}
function canopy(c,cols,seed,blossom){const [dark,mid,lit]=cols;c.circ(24,20,15,dark);c.circ(14,26,9,dark);c.circ(34,26,9,dark);
  c.circ(20,17,11,mid);c.circ(31,22,8,mid);c.circ(13,24,6,mid);
  c.circ(17,13,7,lit);c.circ(11,20,4,lit);c.circ(24,10,5,lit);c.px(14,10,lit);c.px(20,7,lit);
  const r=c.rng(seed);for(let i=0;i<26;i++){const x=8+Math.floor(r()*32),y=6+Math.floor(r()*26);if((x-24)**2+(y-20)**2<210)c.px(x,y,r()<.5?dark:lit)}
  if(blossom){const r2=c.rng(seed+7);for(let i=0;i<22;i++){const x=9+Math.floor(r2()*30),y=7+Math.floor(r2()*24);if((x-24)**2+(y-20)**2<200)c.px(x,y,r2()<.6?"h":"H")}}}
function tree(name,cols,seed,blossom,extra){sprite(name,{w:48,h:48},(c)=>{shadowTrunk(c);canopy(c,cols,seed,blossom);if(extra)extra(c)})}
tree("tree-round",["F","G","g"],11,false)
tree("tree-blossom",["f","G","g"],12,true)
tree("tree-amber",["f","J","j"],13,false,c=>{c.px(16,18,"Y");c.px(30,14,"Y");c.px(24,24,"L")})
tree("tree-rune",["F","f","G"],14,false,c=>{c.px(23,36,"a");c.px(24,35,"a");c.px(24,37,"A");c.px(22,34,"A");c.circ(34,16,2,"F");c.px(34,15,"a")})
sprite("tree-pine",{w:48,h:48},(c)=>{c.ellipse(24,44,12,3,"F");c.rect(22,34,5,10,"D");c.vline(26,34,10,"b");
  c.poly([24,2,38,26,10,26],"F");c.poly([24,8,34,28,14,28],"f");c.poly([24,16,30,32,18,32],"G");
  c.line(24,4,16,20,"g");c.line(24,10,19,24,"g");c.px(18,14,"g");c.px(22,22,"g");c.hline(14,32,20,"k")})
sprite("tree-willow",{w:48,h:48},(c)=>{c.ellipse(24,44,13,3,"F");c.rect(22,28,5,16,"D");c.vline(26,28,16,"b");
  c.circ(24,16,13,"F");c.circ(18,12,8,"G");c.circ(15,10,5,"g");
  for(let x=10;x<=38;x+=4){const len=16+((x*7)%9);c.vline(x,18,len,"f");c.px(x,18+len,"g")}c.vline(14,16,20,"G");c.vline(30,16,18,"G")})
