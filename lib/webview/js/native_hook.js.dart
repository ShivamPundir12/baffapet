const String nativeHookJs = r"""
(function(){
  function hook(doc){
    if (!doc) return;
    var q = doc.querySelectorAll('input[type=date],input[type=time],input[type=datetime-local]');
    q.forEach(function(el){
      if (!el || el.dataset._nativeHooked === '1') return;
      el.dataset._nativeHooked = '1';

      var v = el.value;
      try { el.type = 'text'; } catch(e) { el.setAttribute('type','text'); }
      if (v) el.value = v;

      el.classList.add('force-js-picker');
      el.setAttribute('inputmode','text');
      el.setAttribute('autocomplete','off');

      el.addEventListener('focus', function(){
        try {
          if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('openNativeDateTime');
          }
        } catch(e){}
        try { el.blur(); } catch(e){}
      }, {passive:true});
    });
  }

  function patch(doc){
    hook(doc);
    if (!doc.__nativeHookObs){
      doc.__nativeHookObs = true;
      try{
        var mo = new MutationObserver(function(){
          if (doc.__nativeHookPend) return;
          doc.__nativeHookPend = true;
          (doc.defaultView || window).requestAnimationFrame(function(){
            doc.__nativeHookPend = false;
            hook(doc);
          });
        });
        mo.observe(doc.documentElement || doc.body, {childList:true, subtree:true});
      }catch(e){}
    }
  }

  try { patch(document); } catch(e){}
  try {
    var ifr = document.querySelectorAll('iframe');
    for (var i=0;i<ifr.length;i++){
      try {
        var idoc = ifr[i].contentDocument || (ifr[i].contentWindow && ifr[i].contentWindow.document);
        patch(idoc);
      } catch(e){}
    }
  } catch(e){}
})();
""";
