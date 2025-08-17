import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

const String app_url = "https://bafapet.com/";
const List<String> external_hosts = [
  "wa.me",
  "maps.google.com",
  "youtube.com",
  "youtu.be",
  "play.google.com",
  "apps.apple.com",
  "tel",
  "mailto",
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  runApp(const WebAppShell());
}

class WebAppShell extends StatelessWidget {
  const WebAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bafapet',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(
            0xFF5B8DEF,
          ), // accent (selected day, clock hand, headers)
          onPrimary: Colors.white, // text on accent
          secondary: Color(0xFF5B8DEF),
          onSecondary: Colors.white,
          surface: Color(0xFFF8FAFC), // dialog background (light)
          onSurface: Color(0xFF0F172A), // text on dialog
          background: Color(0xFFFFFFFF),
          onBackground: Color(0xFF0F172A),
          error: Color(0xFFEF4444),
          onError: Colors.white,
          primaryContainer: Color(0xFF9DBDFF),
          onPrimaryContainer: Color(0xFF0B2545),
          secondaryContainer: Color(0xFF9DBDFF),
          onSecondaryContainer: Color(0xFF0B2545),
          surfaceTint: Color(0xFF5B8DEF),
          outline: Color(0xFFE2E8F0),
          outlineVariant: Color(0xFFD1D5DB),
          tertiary: Color(0xFF5B8DEF),
          onTertiary: Colors.white,
          scrim: Colors.black54,
          inverseSurface: Color(0xFF111827),
          onInverseSurface: Color(0xFFE5E7EB),
          inversePrimary: Color(0xFF3B82F6),
          shadow: Colors.black,
        ),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          elevation: 8,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF5B8DEF), // OK/Cancel
          ),
        ),
        useMaterial3: true,
      ),

      // DARK THEME (matches your screenshot palette)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFA7C7FF), // light-blue accent
          onPrimary: Color(0xFF0B2545), // dark text on accent chip
          secondary: Color(0xFFA7C7FF),
          onSecondary: Color(0xFF0B2545),
          surface: Color(0xFF2F2F2F), // dialog panel background
          onSurface: Color(0xFFE5E7EB), // labels/text
          error: Color(0xFFEF4444),
          onError: Colors.white,
          primaryContainer: Color(0xFF9DBDFF),
          onPrimaryContainer: Color(0xFF0B2545),
          secondaryContainer: Color(0xFF9DBDFF),
          onSecondaryContainer: Color(0xFF0B2545),
          surfaceTint: Color(0xFFA7C7FF),
          outline: Color(0xFF4B5563), // borders/dividers
          outlineVariant: Color(0xFF374151),
          tertiary: Color(0xFFA7C7FF),
          onTertiary: Color(0xFF0B2545),
          scrim: Colors.black54,
          inverseSurface: Color(0xFFE5E7EB),
          onInverseSurface: Color(0xFF111827),
          inversePrimary: Color(0xFF5B8DEF),
          shadow: Colors.black,
        ),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          elevation: 8,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Color(0xFFA7C7FF), // OK/Cancel
          ),
        ),
        useMaterial3: true,
      ),

      home: const WebHomePage(),
    );
  }
}

class WebHomePage extends StatefulWidget {
  const WebHomePage({super.key});

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> {
  InAppWebViewController? _webViewController;
  final GlobalKey _webViewKey = GlobalKey();

  late PullToRefreshController _ptrController;
  double _progress = 0;
  bool _isOnline = true;
  bool _canGoBack = false;
  String _appVersion = "";
  int _lastInjectMs = 0;

  // JS: convert native date/time inputs to text and invoke Flutter handler on focus
  static const String _nativeHookJs = r"""
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
                // Ask Flutter to open native pickers
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

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _ptrController = PullToRefreshController(
        settings: PullToRefreshSettings(color: Colors.blue),
        onRefresh: () async {
          if (Platform.isAndroid) {
            _webViewController?.reload();
          } else if (Platform.isIOS) {
            final url = await _webViewController?.getUrl();
            if (url != null) {
              _webViewController?.loadUrl(urlRequest: URLRequest(url: url));
            }
          }
        },
      );
    }

    Connectivity().onConnectivityChanged.listen((result) async {
      final online = result != ConnectivityResult.none;
      if (_isOnline != online) {
        setState(() => _isOnline = online);
        if (online) _webViewController?.reload();
      }
    });

    _initAppInfo();
  }

  Future<void> _initAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = "${info.version}+${info.buildNumber}");
  }

  Future<void> _requestCommonPermissions() async {
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        await [
          Permission.camera,
          Permission.microphone,
          Permission.photos,
        ].request();
      }
    }
  }

  Future<void> _handleDownload(
    InAppWebViewController controller,
    Uri url,
  ) async {
    try {
      final dir = Platform.isAndroid
          ? (await getExternalStorageDirectory())
          : await getApplicationDocumentsDirectory();
      if (dir == null) return;

      final filename = url.pathSegments.isNotEmpty
          ? url.pathSegments.last
          : "file_${DateTime.now().millisecondsSinceEpoch}";
      final savePath = "${dir.path}/$filename";

      final data = await controller
          .callAsyncJavaScript(
            functionBody: """
            async function downloadFile(u){
              const res = await fetch(u, {credentials: 'include'});
              const buf = await res.arrayBuffer();
              return Array.from(new Uint8Array(buf));
            }
          """,
          )
          .then(
            (_) => controller.callAsyncJavaScript(
              functionBody:
                  "return await downloadFile('${url.toString().replaceAll("'", "\\'")}');",
            ),
          );

      if (data?.value is List) {
        final bytes = List<int>.from(data!.value);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Saved: $filename")));
        }
        await OpenFilex.open(savePath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Download failed")));
      }
    }
  }

  bool _shouldOpenExternally(Uri url) {
    final scheme = url.scheme;
    if (scheme == "tel" ||
        scheme == "mailto" ||
        scheme == "sms" ||
        scheme == "intent")
      return true;
    final host = url.host.toLowerCase();
    return external_hosts.any((h) => host.contains(h));
  }

  Future<NavigationActionPolicy> _navDelegate(NavigationAction action) async {
    final url = action.request.url;
    if (url == null) return NavigationActionPolicy.ALLOW;

    if (_shouldOpenExternally(url)) {
      final launchUri = url.toString();
      if (await canLaunchUrl(Uri.parse(launchUri))) {
        await launchUrl(
          Uri.parse(launchUri),
          mode: LaunchMode.externalApplication,
        );
        return NavigationActionPolicy.CANCEL;
      }
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _injectHookDebounced() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastInjectMs < 600) return;
    _lastInjectMs = now;
    try {
      // Encourage desktop assets (if site looks at UA)
      await _webViewController?.setSettings(
        settings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        ),
      );
    } catch (_) {}
    try {
      await _webViewController?.evaluateJavascript(source: _nativeHookJs);
    } catch (_) {}
  }

  // Open native pickers and write back formatted value with full event dispatch
  Future<void> _openNativeAndWriteBack() async {
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

    final formatted = _formatForSite(dt); // "MM/DD/YYYY, h:mm AM/PM"

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
      await _webViewController?.evaluateJavascript(source: writeBackJs);
    } catch (_) {}
  }

  // Format: "MM/DD/YYYY, h:mm AM/PM"
  String _formatForSite(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "$mm/$dd/$yyyy, $hour12:$min $ampm";
  }

  @override
  Widget build(BuildContext context) {
    final initialUrl = WebUri(app_url);

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _webViewController != null) {
          if (await _webViewController!.canGoBack()) {
            await _webViewController!.goBack();
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (!_isOnline)
                MaterialBanner(
                  content: const Text("No internet connection"),
                  actions: [
                    TextButton(
                      onPressed: () => _webViewController?.reload(),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              Expanded(
                child: InAppWebView(
                  key: _webViewKey,
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    useOnDownloadStart: true,
                    allowsBackForwardNavigationGestures: true,
                    cacheEnabled: true,
                    clearCache: false,
                    transparentBackground: false,
                    useShouldOverrideUrlLoading: true,
                    allowFileAccessFromFileURLs: true,
                    allowUniversalAccessFromFileURLs: true,
                    thirdPartyCookiesEnabled: true,
                    verticalScrollBarEnabled: true,
                    horizontalScrollBarEnabled: false,
                    supportZoom: true,
                  ),
                  initialUrlRequest: URLRequest(url: initialUrl),
                  pullToRefreshController:
                      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
                      ? null
                      : _ptrController,
                  onWebViewCreated: (controller) async {
                    _webViewController = controller;

                    // Register a handler that JS can call: window.flutter_inappwebview.callHandler('openNativeDateTime')
                    controller.addJavaScriptHandler(
                      handlerName: 'openNativeDateTime',
                      callback: (args) async {
                        // Open pickers and write back
                        await _openNativeAndWriteBack();
                        return null;
                      },
                    );

                    await _requestCommonPermissions();
                  },
                  onLoadStart: (controller, url) {
                    setState(() => _canGoBack = false);
                  },
                  onLoadStop: (controller, url) async {
                    _ptrController.endRefreshing();
                    if (mounted) {
                      final canGoBack = await controller.canGoBack();
                      setState(() {
                        _canGoBack = canGoBack;
                      });
                    }
                    await _injectHookDebounced();
                  },
                  onProgressChanged: (controller, progress) async {
                    if (progress == 100) {
                      _ptrController.endRefreshing();
                      await _injectHookDebounced();
                    }
                    setState(() => _progress = progress / 100);
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    final policy = await _navDelegate(action);
                    return policy;
                  },
                  onReceivedError: (controller, request, error) async {
                    _ptrController.endRefreshing();
                    final offlineHtml = await DefaultAssetBundle.of(
                      context,
                    ).loadString("assets/offline.html");
                    controller.loadData(
                      data: offlineHtml,
                      baseUrl: WebUri("about:blank"),
                    );
                  },
                  onDownloadStartRequest: (controller, request) async {
                    await _handleDownload(controller, request.url);
                  },
                  onPermissionRequest: (controller, request) async {
                    await _requestCommonPermissions();
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    // Keep quiet to avoid verbosity; add logging if needed
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
