"use strict";
(() => {
 const chooser=document.querySelector('.demo-chooser');if(!chooser)return;
 const query=matchMedia('(max-width:720px)');
 function recommend(){const phone=query.matches;chooser.dataset.preferred=phone?'phone':'desktop';document.querySelectorAll('[data-device]').forEach(e=>e.hidden=(e.dataset.device==='phone')!==phone);}
 query.addEventListener('change',recommend);recommend();
 // Legacy topic links and deep links stay within this one responsive interface.
 document.querySelectorAll('[data-story-practice]').forEach(a=>a.addEventListener('click',e=>{e.preventDefault();const topic=document.querySelector('[data-story-topic][aria-pressed=true]')?.dataset.storyTopic||'stock';document.querySelector('[data-topic="'+topic+'"]').click();document.querySelector('[data-step="0"]').click();location.hash='practice';}));
})();
