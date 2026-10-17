"use strict";
for(const article of document.querySelectorAll('.video-choice')){
 const video=article.querySelector('video'),button=article.querySelector('[data-video-fullscreen]'),status=article.querySelector('.playback-status');
 button.hidden=false;
 video.addEventListener('play',()=>{for(const other of document.querySelectorAll('.video-choice video'))if(other!==video)other.pause();});
 button.addEventListener('click',()=>{
  status.textContent='';
  // Both operations begin in the user's gesture; native controls remain available.
  const playing=video.play();
  try{if(typeof video.webkitEnterFullscreen==='function')video.webkitEnterFullscreen();else if(typeof video.requestFullscreen==='function')video.requestFullscreen().catch(()=>{status.textContent='Use the player’s full-screen control if the browser asks.';});else status.textContent='Use the player’s full-screen control on your device.';}catch{status.textContent='Use the player’s full-screen control on your device.';}
  playing.catch(()=>{status.textContent='Use the player’s play and full-screen controls to continue.';});
 });
}
