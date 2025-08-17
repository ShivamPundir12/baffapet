import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/format.dart';
import 'js/native_hook.js.dart';

class WebControllerHelpers {
  WebControllerHelpers(this.controller);

  final InAppWebViewController controller;
  int _lastInjectMs = 0;

  Future<void> injectHookDebounced() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastInjectMs < 600) return;
    _lastInjectMs = now;
    try {
      await controller.setSettings(
        settings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        ),
      );
    } catch (_) {}
    try {
      await controller.evaluateJavascript(source: nativeHookJs);
    } catch (_) {}
  }

  Future<void> openNativeAndWriteBack(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final formatted = formatForSite(dt);

    final writeBackJs =
        """
      (function(){
        function target(){
          var el = document.activeElement;
          if (el && el.tagName && el.tagName.toLowerCase() === 'input') return el;
          var list = document.querySelectorAll('input.force-js-picker');
          if (list && list.length) return list[list.length-1];
          return null;
        }
        var el = target();
        if (!el) return;

        var newVal = "$formatted";
        var proto = window.HTMLInputElement && window.HTMLInputElement.prototype;
        var setter = proto ? Object.getOwnPropertyDescriptor(proto, 'value') : null;
        if (setter && setter.set) { setter.set.call(el, newVal); } else { el.value = newVal; }
        try { el.setSelectionRange(newVal.length, newVal.length); } catch(e){}

        ['input','change','blur'].forEach(function(t){ el.dispatchEvent(new Event(t, {bubbles:true})); });

        try {
          ['keydown','keyup'].forEach(function(t){
            var evt = new KeyboardEvent(t, {bubbles:true, cancelable:true, key:'Tab'});
            el.dispatchEvent(evt);
          });
        } catch(e){}

        try {
          var hidden = el.parentElement && el.parentElement.querySelector('input[type="hidden"]');
          if (hidden) {
            var hp = window.HTMLInputElement && window.HTMLInputElement.prototype;
            var hs = hp ? Object.getOwnPropertyDescriptor(hp, 'value') : null;
            if (hs && hs.set) { hs.set.call(hidden, newVal); } else { hidden.value = newVal; }
            ['input','change'].forEach(function(t){ hidden.dispatchEvent(new Event(t, {bubbles:true})); });
          }
        } catch(e){}

        if (el.form) { try { el.form.dispatchEvent(new Event('input', {bubbles:true})); } catch(e){} }
      })();
    """;

    try {
      await controller.evaluateJavascript(source: writeBackJs);
    } catch (_) {}
  }
}
