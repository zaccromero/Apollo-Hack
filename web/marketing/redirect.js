"use strict";
const anchor=document.currentScript?.dataset.anchor||document.querySelector('script[data-anchor]')?.dataset.anchor||'main';
location.replace('index.html'+location.search+'#'+anchor);
