library aad_oauth;

import 'model/config.dart';
import 'package:flutter/material.dart';
import 'helper/auth_storage.dart';
import 'model/token.dart';
import 'request_code.dart';
import 'request_token.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Authenticates a user with Azure Active Directory using OAuth2.0.
class AadOAuth {
  final Config config;
  final AuthStorage authStorage;
  final RequestCode requestCode;
  final RequestToken requestToken;

  /// Instantiating AadOAuth authentication.
  /// [config] Parameters according to official Microsoft Documentation.
  AadOAuth(Config config)
      : config = config,
        authStorage = AuthStorage(tokenIdentifier: config.tokenIdentifier),
        requestCode = RequestCode(config),
        requestToken = RequestToken(config);

  void setContext(BuildContext context) {
    config.context = context;
    requestToken.setContext(context);
    requestCode.setContext(context);
  }

  /// Set [screenSize] of webview.
  void setWebViewScreenSize(Rect screenSize) {
    if (screenSize != config.screenSize) {
      config.screenSize = screenSize;
      // requestCode.sizeChanged();
    }
  }

  void setWebViewScreenSizeFromMedia(MediaQueryData media) {
    final rect = Rect.fromLTWH(
      media.padding.left,
      media.padding.top,
      media.size.width - media.padding.left - media.padding.right,
      media.size.height - media.padding.top - media.padding.bottom,
    );
    setWebViewScreenSize(rect);
  }

  /// Perform Azure AD login.
  ///
  /// Setting [refreshIfAvailable] to [true] will attempt to re-authenticate
  /// with the existing refresh token, if any, even though the access token may
  /// still be valid. If there's no refresh token the existing access token
  /// will be returned, as long as we deem it still valid. In the event that
  /// both access and refresh tokens are invalid, the web gui will be used.
  Future<void> login({bool refreshIfAvailable = false}) async {
    await _removeOldTokenOnFirstLogin();
    await _authorization(refreshIfAvailable: refreshIfAvailable);
  }

  /// Retrieve cached OAuth Access Token.
  Future<String?> getAccessToken() async =>
      (await authStorage.loadTokenFromCache()).accessToken;

  /// Retrieve cached OAuth Id Token.
  Future<String?> getIdToken() async =>
      (await authStorage.loadTokenFromCache()).idToken;

  /// Perform Azure AD logout.
  Future<void> logout() async {
    await authStorage.clear();
    // await requestCode.clearCookies();
  }

  /// Authorize user via refresh token or web gui if necessary.
  ///
  /// Setting [refreshIfAvailable] to [true] will attempt to re-authenticate
  /// with the existing refresh token, if any, even though the access token may
  /// still be valid. If there's no refresh token the existing access token
  /// will be returned, as long as we deem it still valid. In the event that
  /// both access and refresh tokens are invalid, the web gui will be used.
  Future<Token> _authorization({bool refreshIfAvailable = false}) async {
    var token = await authStorage.loadTokenFromCache();

    if (!refreshIfAvailable) {
      if (token.hasValidAccessToken()) {
        return token;
      }
    }

    if (token.hasRefreshToken()) {
      token = await requestToken.requestRefreshToken(token.refreshToken!);
    }

    if (!token.hasValidAccessToken()) {
      token = await _performFullAuthFlow();
    }

    await authStorage.saveTokenToCache(token);
    return token;
  }

  /// Authorize user via refresh token or web gui if necessary.
  Future<Token> _performFullAuthFlow() async {
    var code = await requestCode.requestCode();
    if (code == null) {
      throw Exception('Access denied or authentication canceled.');
    }
    return await requestToken.requestToken(code);
  }

  Future<void> _removeOldTokenOnFirstLogin() async {
    var prefs = await SharedPreferences.getInstance();
    final _keyFreshInstall = 'freshInstall';
    if (!prefs.getKeys().contains(_keyFreshInstall)) {
      await logout();
      await prefs.setBool(_keyFreshInstall, false);
    }
  }
}
