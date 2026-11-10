// Houses 48x64 — distinct silhouettes, shared _roof/_window/_door parts.
include("palette.px.js")
sprite("_window-lit",{w:8,h:10},(c)=>{c.rect(0,0,8,10,"D");c.rect(1,1,6,8,"L");c.px(2,2,"w");c.vline(4,1,8,"D");c.hline(1,5,6,"D")})
sprite("_window",{w:8,h:10},(c)=>{c.rect(0,0,8,10,"D");c.rect(1,1,6,8,"S");c.px(2,2,"s");c.vline(4,1,8,"D");c.hline(1,5,6,"D")})
sprite("_door",{w:10,h:16},(c)=>{c.rect(0,0,10,16,"D");c.rect(1,1,8,14,"d");c.px(7,8,"Y");c.vline(5,1,14,"b");c.hline(1,4,8,"b")})
sprite("_roof",{w:48,h:18},(c)=>{c.poly([24,0,48,18,0,18],"T");c.poly([24,0,48,18,24,18],"u");shingle(c,24,0,18,24,"u","b");c.hline(2,16,44,"k")})
function shingle(c,ax,ay,by,half,dl,dr){for(let y=ay+4,i=0;y<by;y+=4,i++){const t=(y-ay)/(by-ay),hw=Math.max(2,Math.round(half*t)),lx=ax-hw,rx=ax+hw;c.hline(lx,y,ax-lx,dl);c.hline(ax,y,rx-ax,dr);const off=(i%2)*3;for(let x=lx+3+off;x<rx-2;x+=7)c.vline(x,y,2,x<ax?dl:dr)}}
function base(c,x,y,w,h,wall){c.ellipse(24,62,20,2,"q");c.rect(x,y,w,h,wall);c.vline(x+w-3,y,h,"e");c.hline(x,60,w,"k");c.rect(x,58,w,3,"M")}
function timber(c,x,y,w){c.vline(x+2,y,22,"D");c.vline(x+w-3,y,22,"D");c.hline(x,y+1,w,"D")}
sprite("house-cottage",{w:48,h:64},(c)=>{base(c,6,30,36,32,"c");timber(c,6,32,36);
  c.rect(34,12,6,12,"M");c.hline(33,11,8,"k");c.poly([24,6,46,32,2,32],"T");c.poly([24,6,46,32,24,32],"u");shingle(c,24,6,32,22,"u","b");c.hline(4,31,40,"k");c.px(12,18,"t");c.px(20,12,"t");
  c.line(24,6,2,32,"k");c.line(24,6,46,32,"k");c.rect(9,47,10,3,"u");c.px(11,46,"r");c.px(14,45,"Y");c.px(17,46,"w")},
  stamp("_door",30,46),stamp("_window-lit",10,36))
sprite("house-studio",{w:48,h:64},(c)=>{base(c,5,32,38,30,"c");c.poly([24,10,45,34,3,34],"S");c.poly([24,10,45,34,24,34],"n");shingle(c,24,10,34,21,"n","k");c.hline(5,33,38,"k");
  c.rect(10,38,20,16,"n");c.rect(11,39,18,14,"A");c.rect(18,43,4,3,"a");c.px(13,41,"w");c.line(24,44,28,40,"a");c.vline(17,39,14,"n");c.vline(23,39,14,"n");c.hline(11,46,18,"n");c.rect(38,14,4,10,"M")},
  stamp("_door",34,46),stamp("_window-lit",38,38))
sprite("house-workshop",{w:48,h:64},(c)=>{base(c,4,34,40,28,"e");timber(c,4,36,40);
  c.poly([24,14,46,36,2,36],"S");shingle(c,24,14,36,22,"n","n");c.hline(4,35,40,"k");
  // striped awning
  for(let x=6;x<30;x+=6){c.rect(x,42,3,5,"r");c.rect(x+3,42,3,5,"w")}c.hline(6,47,24,"k");
  c.rect(32,38,12,6,"d");c.hline(34,41,8,"Y")},
  stamp("_door",34,48),stamp("_window",8,50),)
 // tools hint beside door (drawn after stamps via function order note: stamps above run before this? keep simple)
sprite("house-tower",{w:48,h:64},(c)=>{base(c,14,28,22,34,"c");c.rect(18,8,14,8,"S");c.poly([25,0,38,30,12,30],"u");c.poly([25,0,38,30,25,30],"T");shingle(c,25,0,30,13,"b","u");c.hline(13,29,24,"k");c.px(24,4,"Y")},
  stamp("_window-lit",21,20),stamp("_window",21,36),stamp("_door",20,46))
sprite("house-cabin",{w:48,h:64},(c)=>{base(c,4,38,40,24,"d");for(let y=42;y<60;y+=4)c.hline(4,y,40,"b");c.px(6,40,"e");c.px(40,48,"e");
  c.poly([24,22,47,40,1,40],"D");c.poly([24,22,47,40,24,40],"b");shingle(c,24,22,40,23,"b","k");c.hline(3,39,42,"k");c.rect(8,26,5,8,"M")},
  stamp("_door",12,46),stamp("_window-lit",30,44))
sprite("house-brick",{w:48,h:64},(c)=>{base(c,6,32,36,30,"T");for(let y=36;y<60;y+=4){c.hline(6,y,36,"u");for(let x=10+((y/4)%2)*6;x<42;x+=12)c.vline(x,y,4,"u")}
  c.poly([24,12,44,34,4,34],"n");c.poly([24,12,44,34,24,34],"S");shingle(c,24,12,34,20,"k","n");c.hline(6,33,36,"k");
  c.ellipse(24,50,7,8,"D");c.rect(18,50,12,12,"D")},
  stamp("_window-lit",10,38),stamp("_window",32,38),stamp("_door",19,48))
