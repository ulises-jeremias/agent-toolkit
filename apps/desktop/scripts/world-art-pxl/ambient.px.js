// Ambient critters & sparkles — 2-frame horizontal strips.
include("palette.px.js")
sprite("hornero",{w:32,h:12},(c)=>{for(let f=0;f<2;f++){const o=f*16;
  // rufous hornero: brown back, cream belly, long tail
  c.line(o+2,8,o+6,6,"O");c.line(o+2,9,o+6,7,"O"); // tail
  c.ellipse(o+9,7,5,3,"o");c.ellipse(o+9,8,4,2,"c");c.ellipse(o+11,5,3,3,"o"); // body+head
  c.px(o+12,4,"k");c.px(o+14,5,"Y"); // eye+beak (beak clear of frame edge)
  if(f===0){c.poly([o+6,6,o+10,1,o+12,6],"D");c.px(o+9,3,"O")}else{c.poly([o+6,7,o+11,9,o+12,6],"D");c.px(o+9,8,"O")} // wing up/down
  c.vline(o+8,10,2,"k");c.vline(o+11,10,2,"k")}})
sprite("butterfly",{w:16,h:8},(c)=>{for(let f=0;f<2;f++){const o=f*8;c.vline(o+4,2,5,"k");c.px(o+4,1,"k");
  if(f===0){c.ellipse(o+2,2,2,1,"V");c.ellipse(o+6,2,2,1,"h");c.ellipse(o+2,5,1,1,"v");c.ellipse(o+6,5,1,1,"H")}
  else{c.ellipse(o+2,1,2,2,"V");c.ellipse(o+6,1,2,2,"h");c.px(o+2,5,"v");c.px(o+6,5,"H")}c.px(o+4,4,"Y")}})
sprite("firefly",{w:24,h:12},(c)=>{for(let f=0;f<2;f++){const o=f*12;c.vline(o+6,4,4,"k");c.ellipse(o+6,6,2,2,"n");c.line(o+4,4,o+2,2,"S");c.line(o+8,4,o+10,2,"S");
  if(f===0){c.circ(o+6,9,2,"l");c.px(o+6,9,"w");c.px(o+3,6,"L");c.px(o+9,5,"L");c.px(o+6,3,"l")}
  else{c.px(o+6,9,"J");c.px(o+5,8,"n")}}})
sprite("mote",{w:20,h:10},(c)=>{for(let f=0;f<2;f++){const o=f*10;const s=f?1:0;c.px(o+2+s,3,"l");c.px(o+7,2+s,"w");c.px(o+5+s,6,"L");c.px(o+8,7-s,"l");c.px(o+3,8,"L");c.px(o+6-s,4,"w")}})
sprite("water-sparkle",{w:20,h:10},(c)=>{for(let f=0;f<2;f++){const o=f*10;const s=f?1:0;c.px(o+3,4,"a");c.px(o+3+s,3,"w");c.px(o+3,5,"a");c.px(o+2,4,"a");c.px(o+4,4,"a");c.px(o+7-s,7,"w");c.px(o+8,6,"a");c.px(o+6,7,"A");c.px(o+1,8,"A")}})
