// Characters 32x24 — two 16x24 frames side by side; frame2 = frame1 bobbed 1px. Hood-shadow faces, no skin.
include("palette.px.js")
function figure(c,ox,dy,hood,cloak,accent,kind){
  const x=ox+8
  // legs / boots
  c.rect(ox+5,20+dy,3,3,"b");c.rect(ox+9,20+dy,3,3,"b")
  // cloak body (tapered block, hard shadow on right)
  c.rect(ox+5,8+dy,6,3,cloak);c.rect(ox+4,11+dy,8,10,cloak);c.vline(ox+11,10+dy,11,"k");c.hline(ox+4,20+dy,8,accent);c.px(ox+5,12+dy,accent)
  // hood / head covering with shadow face
  if(kind==="scholar"){c.rect(ox+5,0+dy,6,5,"v");c.hline(ox+3,5+dy,10,"v");c.rect(ox+5,5+dy,6,4,"k")}
  else if(kind==="scout"){c.hline(ox+4,3+dy,9,"J");c.rect(ox+5,1+dy,6,3,hood);c.rect(ox+5,4+dy,6,4,"k")}
  else{c.circ(x,5+dy,4,hood);c.rect(ox+5,4+dy,6,4,"k");c.hline(ox+4,8+dy,8,hood)}
  c.px(ox+6,6+dy,accent);c.px(ox+10,6+dy,accent) // scarf/eye glints under hood shadow
  c.hline(ox+5,10+dy,6,accent) // scarf
  if(kind==="scout"){c.rect(ox+11,13+dy,4,5,"O");c.hline(ox+11,13+dy,4,"b")} // satchel
  if(kind==="maker"){c.rect(ox+6,12+dy,5,7,"c");c.hline(ox+6,12+dy,5,"e");c.px(ox+10,16+dy,"M")} // apron+tool
  if(kind==="scholar"){c.rect(ox+11,12+dy,4,6,"r");c.px(ox+12,13+dy,"w")} // book
  if(kind==="keeper"){c.vline(ox+13,9+dy,3,"n");c.rect(ox+12,12+dy,3,4,"n");c.px(ox+13,13+dy,"l");c.px(ox+13,14+dy,"L")} // lantern
}
function character(name,hood,cloak,accent,kind){sprite(name,{w:32,h:24},(c)=>{figure(c,0,0,hood,cloak,accent,kind);figure(c,16,1,hood,cloak,accent,kind)})}
character("char-teal","A","z","a")
character("char-gold","L","J","Y")
character("char-brick","u","T","r")
character("char-scout","G","f","Y","scout")
character("char-maker","d","D","c","maker")
character("char-scholar","v","V","l","scholar")
character("char-keeper","S","n","L","keeper")
