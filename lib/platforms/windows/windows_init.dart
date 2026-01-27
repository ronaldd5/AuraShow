import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart';

void registerPlatformWebview() {
  WebViewPlatform.instance = WindowsWebViewPlatform();
}
