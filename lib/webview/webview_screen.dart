import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/constants.dart';
import '../core/connectivity_service.dart';
import '../core/downloads.dart';
import '../core/navigation.dart';
import '../core/permissions.dart';
import 'webview_controller.dart';

class WebHomePage extends StatefulWidget {
  const WebHomePage({super.key});

  @override
  State<WebHomePage> createState() => _WebHomePageState();
}

class _WebHomePageState extends State<WebHomePage> {
  InAppWebViewController? _webViewController;
  late WebControllerHelpers _helpers;

  final GlobalKey _webViewKey = GlobalKey();
  late PullToRefreshController _ptrController;

  double _progress = 0;
  bool _isOnline = true;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();

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

    onlineStream().listen((online) {
      if (_isOnline != online) {
        setState(() => _isOnline = online);
        if (online) _webViewController?.reload();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialUrl = WebUri(appUrl);

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
                    _helpers = WebControllerHelpers(controller);

                    // JS -> Flutter handler to open native pickers
                    controller.addJavaScriptHandler(
                      handlerName: 'openNativeDateTime',
                      callback: (args) async {
                        await _helpers.openNativeAndWriteBack(context);
                        return null;
                      },
                    );

                    await requestCommonPermissions();
                  },
                  onLoadStart: (controller, url) {
                    setState(() => _canGoBack = false);
                  },
                  onLoadStop: (controller, url) async {
                    _ptrController.endRefreshing();
                    if (mounted) {
                      final canGoBack = await controller.canGoBack();
                      setState(() => _canGoBack = canGoBack);
                    }
                    await _helpers.injectHookDebounced();
                  },
                  onProgressChanged: (controller, progress) async {
                    if (progress == 100) {
                      _ptrController.endRefreshing();
                      await _helpers.injectHookDebounced();
                    }
                    setState(() => _progress = progress / 100);
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    final url = action.request.url;
                    if (url != null &&
                        shouldOpenExternally(url, externalHosts)) {
                      final opened = await tryOpenExternal(url);
                      return opened
                          ? NavigationActionPolicy.CANCEL
                          : NavigationActionPolicy.ALLOW;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  onReceivedError: (controller, request, error) async {
                    _ptrController.endRefreshing();
                    // Optional: show an offline HTML from assets
                    // final offlineHtml = await DefaultAssetBundle.of(context).loadString("assets/offline.html");
                    // controller.loadData(data: offlineHtml, baseUrl: WebUri("about:blank"));
                  },
                  onDownloadStartRequest: (controller, request) async {
                    await handleDownload(context, controller, request.url);
                  },
                  onPermissionRequest: (controller, request) async {
                    await requestCommonPermissions();
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onConsoleMessage: (controller, consoleMessage) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
