"use strict";
(() => {
 const media=matchMedia('(prefers-reduced-motion: reduce)');
 let manual=false;
 try{manual=sessionStorage.getItem('apollo-reduce-motion')==='true';}catch{}
 function motion(){document.documentElement.dataset.reduceMotion=String(manual||media.matches);document.querySelectorAll('.motion-toggle').forEach(b=>{b.setAttribute('aria-pressed',String(manual||media.matches));b.textContent=media.matches?'Reduced motion · system':manual?'Motion reduced':'Reduce motion';});}
 document.querySelectorAll('.motion-toggle').forEach(b=>b.addEventListener('click',()=>{manual=!manual;try{sessionStorage.setItem('apollo-reduce-motion',String(manual));}catch{}motion();}));
 media.addEventListener('change',motion);motion();
 // HTML exposes all four steps before enhancement, including when scripts are unavailable.
 const scene=document.querySelector('.story-scene');if(!scene)return;
 const names=['Discover','Look closer','Preview','Reflect'];let step=0,topic=new URLSearchParams(location.search).get('topic')==='etf'?'etf':'stock';
 const text=(key,v)=>document.querySelector('[data-story-'+key+']').textContent=v;
 function setTopic(key){topic=key==='etf'?'etf':'stock';const basket=topic==='etf';
  document.querySelectorAll('[data-story-topic]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.storyTopic===topic)));
  text('name',basket?'Sample market basket':'Example company');text('question',basket?'Twenty names. How evenly is the risk spread?':'You like the company. What makes it worth the price?');
  text('evidence',basket?'Three of twenty holdings make up 45% of the basket. Diversification depends on the weights, not just the number of names.':'Sales are growing, but costs are growing faster. Revenue alone doesn’t tell the whole story.');
  text('formula',basket?'3 shares × $50':'3 shares × $100');text('cost',basket?'$150.00':'$300.00');text('cash',basket?'$9,850.00':'$9,700.00');
  text('bar-one-label',basket?'Top three holdings':'Revenue growth');text('bar-one-value',basket?'45%':'8%');text('bar-two-label',basket?'Other 17 holdings':'Cost growth');text('bar-two-value',basket?'55%':'12%');
  document.querySelector('.bar-one').style.transform='scaleX('+(basket?.45:.53)+')';document.querySelector('.bar-two').style.transform='scaleX('+(basket?.55:.8)+')';
  text('reflect',basket?'Would you still call this spread out if the top three moved together?':'Would the idea still hold if costs kept outpacing sales?');
  document.querySelector('[data-story-practice]').href='practice.html?topic='+topic+'&stage=0';
 }
 function setStep(n){step=Math.max(0,Math.min(3,n));
  document.querySelectorAll('.story-state').forEach((a,i)=>{a.classList.toggle('is-active',i===step);a.setAttribute('aria-hidden',String(i!==step));a.inert=i!==step;});
  document.querySelectorAll('[data-story-step]').forEach((a,i)=>{if(i===step)a.setAttribute('aria-current','step');else a.removeAttribute('aria-current');});
  document.querySelector('.story-track>span').style.transform='scaleX('+((step+1)/4)+')';
  document.getElementById('story-status').textContent='Step '+(step+1)+' of 4 · '+names[step];
  const next=document.getElementById('story-next');next.textContent=step===3?'Start again ↺':'Next: '+names[step+1].toLowerCase()+' →';
 }
 document.querySelectorAll('[data-story-step]').forEach(a=>a.addEventListener('click',e=>{e.preventDefault();setStep(Number(a.dataset.storyStep));}));
 document.querySelectorAll('[data-story-topic]').forEach(b=>b.addEventListener('click',()=>setTopic(b.dataset.storyTopic)));
 document.getElementById('story-next').addEventListener('click',()=>setStep((step+1)%4));
 document.querySelector('.journey-section').classList.add('story-enhanced');setTopic(topic);setStep(0);
})();
