import 'dart:async';

import 'package:flutter/material.dart'
    show BuildContext, MaterialPageRoute, Navigator, SafeArea, Scaffold;
import 'package:webview_flutter/webview_flutter.dart';

import 'model/config.dart';
import 'request/authorization_request.dart';

class RequestCode {
  final StreamController<String?> _onCodeListener = StreamController();
  final Config _config;
  final AuthorizationRequest _authorizationRequest;

  late Stream<String?> _onCodeStream;

  RequestCode(Config config)
      : _config = config,
        _authorizationRequest = AuthorizationRequest(config) {
    _onCodeStream = _onCodeListener.stream.asBroadcastStream();
  }

  Future<String?> requestCode() async {
    String? code;
    final urlParams = _constructUrlParams();
    if (_config.context != null) {
      final initialURL = ('${_authorizationRequest.url}?$urlParams');
      print(initialURL);
      await _mobileAuth(initialURL);
    } else {
      throw Exception('Context is null. Please call setContext(context).');
    }
    code = await _onCode.first;
    return code;
  }

  // void sizeChanged() {
  //   _webView.resize(_config.screenSize!);
  // }

  // Future<void> clearCookies() async {
  //   await _webView.launch('', hidden: true);
  //   await _webView.cleanCookies();
  //   await _webView.clearCache();
  //   await _webView.close();
  // }

  void setContext(BuildContext context) {
    _config.context = context;
  }

  Future<void> _mobileAuth(String initialURL) async {
    var webView = WebView(
      initialUrl: initialURL,
      javascriptMode: JavascriptMode.unrestricted,
      onPageFinished: (url) => _geturlData(url),
    );

    await Navigator.of(_config.context!).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(child: webView),
        ),
      ),
    );
  }

  void _geturlData(String _url) {
    var url = _url.replaceFirst('#', '?');
    var uri = Uri.parse(url);

    if (uri.queryParameters['error'] != null) {
      Navigator.of(_config.context!).pop();
      _onCodeListener.addError(
        Exception('Access denied or authentation canceled.'),
      );
    }

    var token = uri.queryParameters['code'];
    if (token != null) {
      _onCodeListener.add(token);
      Navigator.of(_config.context!).pop();
    }
  }

  Stream<String?> get _onCode => _onCodeStream;

  String _constructUrlParams() =>
      _mapToQueryParams(_authorizationRequest.parameters);

  String _mapToQueryParams(Map<String, String> params) {
    final queryParams = <String>[];
    params.forEach((String key, String value) =>
        queryParams.add('$key=${Uri.encodeQueryComponent(value)}'));
    return queryParams.join('&');
  }
}
