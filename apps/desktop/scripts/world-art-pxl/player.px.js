// Player — 4 appearances x 4 directions, each 64x24 = 4 frames of 16x24.
// Hood-shadow face, no skin tones (same language as characters.px.js).
include("palette.px.js")
const APPS={
 river:{hood:"A",cloak:"z",dark:"Z",accent:"a",lantern:false},
 grove:{hood:"G",cloak:"f",dark:"F",accent:"g",lantern:false},
 ember:{hood:"t",cloak:"T",dark:"u",accent:"Y",lantern:false},
 dusk:{hood:"S",cloak:"n",dark:"k",accent:"L",lantern:true},
}
function boots(c,ox,dy,f,dir){
  // f: 0 contact, 1 passing, 2 contact2, 3 mid
  if(dir==="east"||dir==="west"){
    const s=dir==="east"?1:-1, cx=ox+8
    if(f===0){c.rect(cx-5*s-1,21+dy,4,2,"b");c.rect(cx+2*s-1,20+dy,4,2,"b")}
    else if(f===2){c.rect(cx+2*s-1,21+dy,4,2,"b");c.rect(cx-5*s-1,20+dy,4,2,"b")}
    else{c.rect(cx-3,21+dy,3,2,"b");c.rect(cx+1,21+dy,3,2,"b")}
    return
  }
  if(f===0){c.rect(ox+4,20+dy,3,3,"b");c.rect(ox+9,21+dy,3,2,"b")}
  else if(f===2){c.rect(ox+9,20+dy,3,3,"b");c.rect(ox+4,21+dy,3,2,"b")}
  else{c.rect(ox+5,21+dy,2,2,"b");c.rect(ox+9,21+dy,2,2,"b")}
}
function lantern(c,x,y){c.vline(x,y-3,3,"n");c.rect(x-1,y,3,4,"n");c.px(x,y+1,"l");c.px(x,y+2,"L")}
function figureP(c,ox,f,dir,P){
  const dy=(f===1||f===3)?1:0
  boots(c,ox,dy,f,dir)
  if(dir==="south"){
    c.rect(ox+5,8+dy,6,3,P.cloak);c.rect(ox+4,11+dy,8,10,P.cloak);c.vline(ox+11,10+dy,10,P.dark);c.hline(ox+4,20+dy,8,P.accent)
    c.circ(ox+8,5+dy,4,P.hood);c.rect(ox+5,4+dy,6,4,"k");c.hline(ox+4,8+dy,8,P.hood)
    c.px(ox+6,6+dy,P.accent);c.px(ox+10,6+dy,P.accent);c.hline(ox+5,10+dy,6,P.accent);c.px(ox+5,12+dy,P.accent)
    if(P.lantern)lantern(c,ox+13,13+dy)
  }else if(dir==="north"){
    c.rect(ox+5,8+dy,6,3,P.cloak);c.rect(ox+4,11+dy,8,10,P.cloak);c.vline(ox+11,10+dy,10,P.dark);c.hline(ox+4,20+dy,8,P.dark)
    c.circ(ox+8,5+dy,4,P.hood);c.rect(ox+5,4+dy,6,5,P.hood);c.vline(ox+8,4+dy,5,P.dark);c.hline(ox+4,8+dy,8,P.dark)
    c.hline(ox+5,10+dy,6,P.accent);c.rect(ox+6,13+dy,4,5,P.dark);c.px(ox+7,14+dy,P.accent) // back satchel/scarf knot
    if(P.lantern)lantern(c,ox+2,13+dy)
  }else{ // east profile; west authored mirrored below by drawing with mx offset logic
    const s=dir==="east"?1:-1, cx=ox+8
    c.rect(cx-3,8+dy,6,3,P.cloak);c.rect(cx-3,11+dy,7,10,P.cloak);c.vline(s>0?cx+3:cx-4,10+dy,10,P.dark);c.hline(cx-3,20+dy,7,P.accent)
    c.circ(cx+1*s,5+dy,4,P.hood);c.rect(cx+1*s,4+dy,4,4,"k");c.hline(cx-3,8+dy,7,P.hood) // face shadow toward facing side
    if(s<0)c.rect(cx-4,4+dy,3,4,"k")
    c.px(cx+2*s,6+dy,P.accent);c.hline(cx-2,10+dy,5,P.accent)
    if(P.lantern)lantern(c,cx+5*s,13+dy); else c.px(cx+3*s,13+dy,P.accent)
  }
}
function player(name,P,dir){sprite(name,{w:64,h:24},(c)=>{for(let f=0;f<4;f++)figureP(c,f*16,f,dir,P)})}
for(const [app,P] of Object.entries(APPS))for(const dir of ["south","north","east","west"])player(`char-player-${app}-${dir}`,P,dir)
