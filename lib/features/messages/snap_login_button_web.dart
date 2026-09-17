// Web-only bridge for Snap Login Kit's official web button.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

@JS('teluguSnapMount')
external void _mountSnapKit(JSString targetId, JSString clientId,
    JSString redirectUri, JSFunction onAvatar, JSFunction onError);

class SnapLoginButtonPlatform extends StatefulWidget {
  const SnapLoginButtonPlatform(
      {super.key,
      required this.clientId,
      required this.redirectUri,
      required this.onAvatar,
      required this.onError});
  final String clientId;
  final String redirectUri;
  final ValueChanged<String> onAvatar;
  final ValueChanged<String> onError;

  @override
  State<SnapLoginButtonPlatform> createState() =>
      _SnapLoginButtonPlatformState();
}

class _SnapLoginButtonPlatformState extends State<SnapLoginButtonPlatform> {
  static const viewType = 'telugu-tunes-snap-login';
  static bool registered = false;

  @override
  void initState() {
    super.initState();
    if (!registered) {
      ui_web.platformViewRegistry.registerViewFactory(viewType,
          (int id) => html.DivElement()..id = 'telugu-snap-login-$id');
      registered = true;
    }
  }

  void _mount(int id) {
    _mountSnapKit('telugu-snap-login-$id'.toJS, widget.clientId.toJS,
        widget.redirectUri.toJS,
        ((JSString url) => widget.onAvatar(url.toDart)).toJS,
        ((JSString error) => widget.onError(error.toDart)).toJS);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 52,
      width: 280,
      child:
          HtmlElementView(viewType: viewType, onPlatformViewCreated: _mount));
}
