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
import 'package:share_plus/share_plus.dart';

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
  // Required for Android debugging features; safe to keep
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
      title: "Bafapet",
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.dark,
        ),
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
        if (online) {
          _webViewController?.reload();
        }
      }
    });

    _initAppInfo();
  }

  Future<void> _initAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = "${info.version}+${info.buildNumber}");
  }

  Future<void> _requestCommonPermissions() async {
    // Request storage for downloads (Android <13), notifications (Android 13+ prompts at runtime), camera/mic for uploads
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        await [
          Permission.camera,
          Permission.microphone,
          Permission.photos,
        ].request();
      } else if (Platform.isIOS) {
        // iOS will prompt when needed; explicit pre-requests are optional
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
            arguments: {},
          )
          .then((_) async {
            // run the JS function
            return await controller.callAsyncJavaScript(
              functionBody:
                  "return await downloadFile('${url.toString().replaceAll("'", "\\'")}');",
            );
          });

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
        ).showSnackBar(SnackBar(content: Text("Download failed")));
      }
    }
  }

  bool _shouldOpenExternally(Uri url) {
    final scheme = url.scheme;
    if (scheme == "tel" ||
        scheme == "mailto" ||
        scheme == "sms" ||
        scheme == "intent") {
      return true;
    }
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

  @override
  Widget build(BuildContext context) {
    final initialUrl = WebUri(app_url);

    return PopScope(
      canPop: !_canGoBack, // intercept system back when webview can go back
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
                  pullToRefreshController: kIsWeb && Platform.isIOS
                      ? null
                      : _ptrController,
                  onWebViewCreated: (controller) async {
                    _webViewController = controller;
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
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) _ptrController.endRefreshing();
                    setState(() => _progress = progress / 100);
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    final policy = await _navDelegate(action);
                    return policy;
                  },
                  onReceivedError: (controller, request, error) async {
                    _ptrController.endRefreshing();
                    // Load offline page
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
                    // Auto-grant camera/mic for in-page prompts after requesting OS permission
                    await _requestCommonPermissions();
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    // Useful for debugging web issues
                    // print(consoleMessage);
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
