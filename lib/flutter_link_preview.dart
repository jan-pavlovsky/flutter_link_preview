library flutter_link_preview;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gbk2utf8/gbk2utf8.dart';
import 'package:html/dom.dart' hide Text;
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart';
import 'package:collection/collection.dart' show IterableExtension;

part 'web_analyzer.dart';

/// Link Preview Widget
class FlutterLinkPreview extends StatefulWidget {
  const FlutterLinkPreview({
    Key? key,
    required this.url,
    this.cache = const Duration(hours: 24),
    required this.builder,
    this.titleStyle,
    this.bodyStyle,
  }) : super(key: key);

  /// Web address, HTTP and HTTPS support
  final String url;

  /// Cache result time, default cache 1 hour
  final Duration cache;

  /// Customized rendering methods
  final Widget Function(InfoBase? info) builder;

  /// Title style
  final TextStyle? titleStyle;

  /// Content style
  final TextStyle? bodyStyle;

  @override
  _FlutterLinkPreviewState createState() => _FlutterLinkPreviewState();
}

class _FlutterLinkPreviewState extends State<FlutterLinkPreview> {
  String? _url;
  InfoBase? _info;

  @override
  void initState() {
    _url = widget.url.trim();
    _info = WebAnalyzer.getInfoFromCache(_url!);
    if (_info == null) _getInfo();
    super.initState();
  }

  Future<void> _getInfo() async {
    if (_url!.startsWith("http")) {
      _info = await WebAnalyzer.getInfo(
        _url!,
        cache: widget.cache,
      );
      if (mounted) setState(() {});
    } else {
      print("Links don't start with http or https from : $_url");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null) {
      return SizedBox.shrink();
    }
    return widget.builder(_info!);
  }
}
