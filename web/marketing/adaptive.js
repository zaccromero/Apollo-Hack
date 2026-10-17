"use strict";
(() => {
 const chooser=document.querySelector('.demo-chooser');if(!chooser)return;
 const query=matchMedia('(max-width:720px), (pointer:coarse) and (max-width:1024px)');
 const controls=document.querySelector('[data-demo-format-controls]');
 const buttons=[...document.querySelectorAll('[data-video-choice]')];
 const articles=[...chooser.querySelectorAll('.video-choice')];
 let manualSelection=false;
 function select(format,manual=false){
  if(!['desktop','phone'].includes(format))return;
  if(manual)manualSelection=true;
  chooser.dataset.selected=format;
  for(const article of articles){
   const selected=(article.classList.contains('portrait-choice')?'phone':'desktop')===format;
   if(!selected)article.querySelector('video').pause();
   article.hidden=!selected;
  }
  for(const button of buttons)button.setAttribute('aria-pressed',String(button.dataset.videoChoice===format));
  const status=document.getElementById('demo-format-status');
  if(status)status.textContent=(format==='phone'?'Phone walkthrough':'Laptop overview')+(format===chooser.dataset.preferred?' · recommended for this screen.':' · selected by you.')+' Tap Play, or choose Play full screen.';
 }
 function recommend(){
  const preferred=query.matches?'phone':'desktop';chooser.dataset.preferred=preferred;
  document.querySelectorAll('[data-device]').forEach(e=>e.hidden=e.dataset.device!==preferred);
  const playerFullscreen=document.fullscreenElement||articles.some(a=>a.querySelector('video').webkitDisplayingFullscreen);
  if(!manualSelection&&!playerFullscreen)select(preferred);
 }
 for(const button of buttons)button.addEventListener('click',()=>select(button.dataset.videoChoice,true));
 chooser.dataset.videoMode='single';if(controls)controls.hidden=false;
 query.addEventListener('change',recommend);document.addEventListener('fullscreenchange',recommend);recommend();
 // Preserve the existing topic handoff within this responsive interface.
 document.querySelectorAll('[data-story-practice]').forEach(a=>a.addEventListener('click',e=>{e.preventDefault();const topic=document.querySelector('[data-story-topic][aria-pressed=true]')?.dataset.storyTopic||'stock';document.querySelector('[data-topic="'+topic+'"]').click();document.querySelector('[data-step="0"]').click();location.hash='practice';}));
})();
