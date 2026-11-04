// SVG port of lib/game/bean_painter.dart and widgets.dart Jar, for mockups.
(function(){
const COL={berry:'#E0305A',peach:'#F07F1A',lime:'#6CCB47',grape:'#6E4AD6',lemon:'#F2C230',cola:'#6B3E26'};
const TYPES=Object.keys(COL);
let uid=0;
function dark(h,f){const n=parseInt(h.slice(1),16);const r=Math.round((n>>16&255)*f),g=Math.round((n>>8&255)*f),b=Math.round((n&255)*f);return `rgb(${r},${g},${b})`;}
function path(x,y,w,h){const p=(a,b)=>`${(x+w*a).toFixed(2)},${(y+h*b).toFixed(2)}`;
 return `M${p(.10,.80)} C${p(-.02,.55)} ${p(.04,.04)} ${p(.50,.03)} C${p(.96,.04)} ${p(1.02,.55)} ${p(.90,.80)} C${p(.78,.95)} ${p(.22,.95)} ${p(.10,.80)}Z`;}
// bean centred at cx,cy with width w (aspect 52:40), rotation deg
function bean(type,cx,cy,w,rot=0){
 const h=w*40/52,k=h/40,x=-w/2,y=-h/2,bh=h-3*k,id='b'+(uid++),base=COL[type];
 const d=path(x,y,w,bh);let s=`<g transform="translate(${cx},${cy}) rotate(${rot})">`;
 s+=`<clipPath id="${id}"><path d="${d}"/></clipPath>`;
 s+=`<path d="${d}" transform="translate(0,${3*k})" fill="${dark(base,.62)}"/><path d="${d}" fill="${base}"/><g clip-path="url(#${id})">`;
 if(type==='peach'){let r=7;const rnd=()=>{r=(r*9301+49297)%233280;return r/233280};for(let i=0;i<14;i++)s+=`<circle cx="${x+w*(.08+rnd()*.84)}" cy="${y+bh*(.12+rnd()*.76)}" r="${(1.1+rnd()*.9)*k}" fill="#FFE1BF"/>`;}
 if(type==='lime'){for(let xx=x+5*k;xx<x+w;xx+=10*k)s+=`<rect x="${xx}" y="${y}" width="${3.5*k}" height="${bh}" fill="#B8EB98"/>`;}
 if(type==='grape')s+=`<path d="${d}" fill="none" stroke="#C9B8FF" stroke-width="${6*k}"/>`;
 if(type==='lemon'){let pts=[];const c=[0,y+bh/2+2*k];for(let t=0;t<3.4*Math.PI;t+=.15){const rad=(1.2+t*1.25)*k;pts.push(`${(c[0]+Math.cos(t)*rad*1.3).toFixed(2)},${(c[1]+Math.sin(t)*rad).toFixed(2)}`)}s+=`<polyline points="${pts.join(' ')}" fill="none" stroke="#fff" stroke-width="${2.4*k}" stroke-linecap="round"/>`;}
 if(type==='cola')s+=`<ellipse cx="0" cy="${y+bh/2+k}" rx="${w*.28}" ry="${bh*.25}" fill="none" stroke="#C48A5A" stroke-width="${1.4*k}"/>`;
 s+=`</g><ellipse cx="0" cy="0" rx="${7.5*k}" ry="${3.5*k}" fill="rgba(255,255,255,.85)" transform="translate(${x+w*.28},${y+bh*.26}) rotate(-25.8)"/>`;
 s+=`<circle cx="${x+w*.47}" cy="${y+bh*.17}" r="${1.8*k}" fill="rgba(255,255,255,.7)"/></g>`;return s;}
// jar: x,y top-left, w width (h = 1.15w). n beans rows; big = bean size factor
function jar(x,y,w,opt={}){const h=w*1.15,big=opt.big||.2;let s=`<g transform="translate(${x},${y})">`;const id='j'+(uid++);
 const bx=w*.06,by=h*.2,bw=w*.88,bhh=h*.78,r=w*.16;
 s+=`<rect x="${bx}" y="${by+h*.02}" width="${bw}" height="${bhh}" rx="${r}" fill="rgba(0,0,0,.09)"/>`;
 s+=`<rect x="${bx}" y="${by}" width="${bw}" height="${bhh}" rx="${r}" fill="${opt.glass||'rgba(255,255,255,.8)'}"/>`;
 s+=`<clipPath id="${id}"><rect x="${bx+w*.03}" y="${by+w*.03}" width="${bw-w*.06}" height="${bhh-w*.06}" rx="${r*.85}"/></clipPath><g clip-path="url(#${id})">`;
 let seed=opt.seed||4;const rnd=()=>{seed=(seed*9301+49297)%233280;return seed/233280};
 const bw2=w*big,bh2=bw2*40/52,inL=bx+w*.05,inR=bx+bw-w*.05,inB=by+bhh-w*.05,inT=by+w*.05+(opt.fillTop||h*.08);let i=0;
 const order=opt.types||TYPES;
 for(let yy=inB-bh2/2;yy>inT;yy-=bh2*.8){for(let xx=inL+(i%2?bw2*.45:0);xx<inR+bw2*.3;xx+=bw2*.92){s+=bean(order[Math.floor(rnd()*order.length)],xx,yy,bw2,(rnd()-.5)*63);}i++;}
 s+=`</g><rect x="${w*.13}" y="${h*.3}" width="${w*.06}" height="${h*.5}" rx="${w*.03}" fill="rgba(255,255,255,.6)"/>`;
 s+=`<rect x="${bx}" y="${by}" width="${bw}" height="${bhh}" rx="${r}" fill="none" stroke="${opt.stroke||'#D7E3EE'}" stroke-width="${Math.max(2,w*.02)}"/>`;
 s+=`<rect x="${w*.14}" y="${h*.08}" width="${w*.72}" height="${h*.14}" rx="${w*.05}" fill="${opt.lid||'#E0306E'}"/><rect x="${w*.14}" y="${h*.18}" width="${w*.72}" height="${h*.03}" fill="${opt.lidShadow||'#B21F54'}"/>`;
 return s+'</g>';}
// tube: x,y top-left, k scale (62x232 design), beans bottom->top, sealed flavour
function tube(x,y,k,beans,opt={}){let s=`<g transform="translate(${x},${y})">`;const W=62*k;const sealed=opt.sealed;const fl=sealed?COL[beans[0]]:null;
 s+=`<path d="M${W*.36},${212*k} L${W*.64},${212*k} L${W*.57},${232*k} L${W*.43},${232*k}Z" fill="#E0306E"/>`;
 s+=`<rect x="0" y="${14*k+3*k}" width="${W}" height="${200*k}" rx="${18*k}" fill="rgba(0,0,0,.08)"/>`;
 s+=`<rect x="0" y="${14*k}" width="${W}" height="${200*k}" rx="${18*k}" fill="rgba(255,255,255,.75)" ${sealed?`style="filter:drop-shadow(0 0 ${6*k}px ${fl}88)"`:''}/>`;
 if(sealed)s+=`<rect x="0" y="${14*k}" width="${W}" height="${200*k}" rx="${18*k}" fill="${fl}" fill-opacity=".18"/>`;
 s+=`<rect x="0" y="${14*k}" width="${W}" height="${200*k}" rx="${18*k}" fill="none" stroke="${sealed?fl:'#D7E3EE'}" stroke-width="${(sealed?3:2)*k}"/>`;
 const bh=40*k,bw=52*k;beans.forEach((t,i)=>{const lift=(opt.lift&&i>=beans.length-opt.lift)?opt.liftPx||18*k:0;s+=bean(t,W/2,206*k-(bh+4*k)*(i+1)+4*k+bh/2-lift,bw)});
 s+=`<rect x="${7*k}" y="${28*k}" width="${5*k}" height="${166*k}" rx="${3*k}" fill="rgba(255,255,255,.6)"/>`;
 const ang=sealed?0:-31.5;s+=`<g transform="rotate(${ang} ${2*k} ${18*k})"><defs><linearGradient id="cg${uid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F4F7FA"/><stop offset="1" stop-color="#B9C3CD"/></linearGradient></defs><rect x="${-2*k}" y="0" width="${W+4*k}" height="${18*k}" rx="${6*k}" fill="url(#cg${uid++})" stroke="#9AA6B2" stroke-width="${1.4*k}"/></g>`;
 if(sealed){const c=[W/2,7*k],r=11*k;s+=`<circle cx="${c[0]}" cy="${c[1]+2*k}" r="${r}" fill="rgba(0,0,0,.2)"/><circle cx="${c[0]}" cy="${c[1]}" r="${r}" fill="${fl}" stroke="#fff" stroke-width="${2*k}"/><path d="M${c[0]-r*.45},${c[1]} L${c[0]-r*.1},${c[1]+r*.35} L${c[0]+r*.5},${c[1]-r*.35}" fill="none" stroke="#fff" stroke-width="${2.6*k}" stroke-linecap="round" stroke-linejoin="round"/>`;}
 return s+'</g>';}
function dots(w,h,n=46,seed=5,alpha=.18){let s='';let r=seed;const rnd=()=>{r=(r*9301+49297)%233280;return r/233280};for(let i=0;i<n;i++){s+=`<circle cx="${rnd()*w}" cy="${rnd()*h}" r="${3+rnd()*5}" fill="${COL[TYPES[i%5]]}" fill-opacity="${alpha}"/>`}return s;}
window.JB={bean,jar,tube,dots,COL,TYPES};
// Auto-render <svg data-art="..."> elements: data-art is a JS expression returning inner SVG.
document.addEventListener('DOMContentLoaded',()=>{document.querySelectorAll('svg[data-art]').forEach(e=>{e.innerHTML=new Function('JB','with(JB){return '+e.dataset.art+'}')(JB);});});
})();
