part of flutter_link_preview;

abstract class InfoBase {
  late DateTime _timeout;
}

/// Web Information
class WebInfo extends InfoBase {
  final String? title;
  final String? icon;
  final String? description;
  final String? image;
  final String? redirectUrl;

  WebInfo({
    this.title,
    this.icon,
    this.description,
    this.image,
    this.redirectUrl,
  });
}

/// Image Information
class WebImageInfo extends InfoBase {
  final String? image;

  WebImageInfo({this.image});
}

/// Web analyzer
class WebAnalyzer {
  static final Map<String, InfoBase> _map = {};
  static final RegExp _bodyReg =
      RegExp(r"<body[^>]*>([\s\S]*?)<\/body>", caseSensitive: false);
  static final RegExp _htmlReg = RegExp(
      r"(<head[^>]*>([\s\S]*?)<\/head>)|(<script[^>]*>([\s\S]*?)<\/script>)|(<style[^>]*>([\s\S]*?)<\/style>)|(<[^>]+>)|(<link[^>]*>([\s\S]*?)<\/link>)|(<[^>]+>)",
      caseSensitive: false);
  static final RegExp _metaReg = RegExp(
      r"<(meta|link)(.*?)\/?>|<title(.*?)</title>",
      caseSensitive: false,
      dotAll: true);
  static final RegExp _titleReg =
      RegExp("(title|icon|description|image)", caseSensitive: false);
  static final RegExp _lineReg = RegExp(r"[\n\r]|&nbsp;|&gt;");
  static final RegExp _spaceReg = RegExp(r"\s+");

  /// Is it an empty string
  static bool isNotEmpty(String? str) {
    return str != null && str.isNotEmpty;
  }

  /// Get web information
  /// return [InfoBase]
  static InfoBase? getInfoFromCache(String url) {
    final InfoBase? info = _map[url];
    if (info != null) {
      if (!info._timeout.isAfter(DateTime.now())) {
        _map.remove(url);
        return null;
      }
    }
    return info;
  }

  /// Get web information
  /// return [InfoBase]
  static Future<InfoBase?> getInfo(String url,
      {Duration cache = const Duration(hours: 24)}) async {
    // final start = DateTime.now();

    InfoBase? info = getInfoFromCache(url);
    if (info != null) return info;
    try {
      info = await _getInfo(url);
      if (info != null) {
        info._timeout = DateTime.now().add(cache);
        _map[url] = info;
      }
    } catch (e) {
      print("Get web error:$url, Error:$e");
    }

    // print("$url cost ${DateTime.now().difference(start).inMilliseconds}");

    return info;
  }

  static Future<InfoBase?> _getInfo(String url) async {
    final response = await _requestUrl(url);

    if (response == null) return null;
    final String? contentType = response.headers["content-type"];
    if (contentType != null) {
      if (contentType.contains("image/")) {
        return WebImageInfo(image: url);
      }
    }

    return _getWebInfo(response, url);
  }

  static Future<Response?> _requestUrl(String url) async {
    Response res = await get(Uri.parse(url));

    if (res.statusCode != 200) print("Get web info not 200 ($url)");
    return res;
  }

  static Future<InfoBase?> _getWebInfo(Response response, String url) async {
    if (response.statusCode == HttpStatus.ok) {
      String? html;
      try {
        html = const Utf8Decoder().convert(response.bodyBytes);
      } catch (e) {
        try {
          html = gbk.decode(response.bodyBytes);
        } catch (e) {
          print("Web page resolution failure from:$url Error:$e");
        }
      }

      if (html == null) {
        print("Web page resolution failure from:$url");
        return null;
      }

      // Improved performance
      // final start = DateTime.now();
      final headHtml = _getHeadHtml(html);
      final document = parser.parse(headHtml);
      // print("dom cost ${DateTime.now().difference(start).inMilliseconds}");
      final uri = Uri.parse(url);

      String title = _analyzeTitle(document);
      String? description =
          _analyzeDescription(document, html)?.replaceAll(r"\x0a", " ");
      if (!isNotEmpty(title)) {
        title = description ?? "";
        description = null;
      }

      final info = WebInfo(
        title: title,
        icon: _analyzeIcon(document, uri),
        description: description,
        image: _analyzeImage(document, uri),
        redirectUrl: response.request!.url.toString(),
      );
      return info;
    }
    return null;
  }

  static String _getHeadHtml(String html) {
    html = html.replaceFirst(_bodyReg, "<body></body>");
    final matchs = _metaReg.allMatches(html);
    final StringBuffer head = StringBuffer("<html><head>");
    matchs.forEach((element) {
      final String str = element.group(0)!;
      if (str.contains(_titleReg)) head.writeln(str);
    });

    head.writeln("</head></html>");
    return head.toString();
  }

  static String? _getMetaContent(
      Document document, String property, String propertyValue) {
    final meta = document.head!.getElementsByTagName("meta");
    final ele =
        meta.firstWhereOrNull((e) => e.attributes[property] == propertyValue);
    if (ele != null) return ele.attributes["content"]?.trim();
    return null;
  }

  static String _analyzeTitle(Document document) {
    final title = _getMetaContent(document, "property", "og:title");
    if (title != null) return title;
    final list = document.head!.getElementsByTagName("title");
    if (list.isNotEmpty) {
      final tagTitle = list.first.text;
      return tagTitle.trim();
    }
    return "";
  }

  static String? _analyzeDescription(Document document, String html) {
    final desc = _getMetaContent(document, "property", "og:description");
    if (desc != null) return desc;

    final description = _getMetaContent(document, "name", "description") ??
        _getMetaContent(document, "name", "Description");

    if (!isNotEmpty(description)) {
      // final DateTime start = DateTime.now();
      String body = html.replaceAll(_htmlReg, "");
      body = body.trim().replaceAll(_lineReg, " ").replaceAll(_spaceReg, " ");
      if (body.length > 300) {
        body = body.substring(0, 300);
      }
      // print("html cost ${DateTime.now().difference(start).inMilliseconds}");
      return body;
    }
    return description!;
  }

  static String? _analyzeIcon(Document document, Uri uri) {
    final meta = document.head!.getElementsByTagName("link");
    String? icon = "";
    // get icon first
    var metaIcon = meta.firstWhereOrNull((e) {
      final rel = (e.attributes["rel"] ?? "").toLowerCase();
      if (rel == "icon") {
        icon = e.attributes["href"];
        if (icon != null && !icon!.toLowerCase().contains(".svg")) {
          return true;
        }
      }
      return false;
    });

    metaIcon ??= meta.firstWhereOrNull((e) {
      final rel = (e.attributes["rel"] ?? "").toLowerCase();
      if (rel == "shortcut icon") {
        icon = e.attributes["href"];
        if (icon != null && !icon!.toLowerCase().contains(".svg")) {
          return true;
        }
      }
      return false;
    });

    if (metaIcon != null) {
      icon = metaIcon.attributes["href"];
    } else {
      return "${uri.origin}/favicon.ico";
    }

    return _handleUrl(uri, icon);
  }

  static String? _analyzeImage(Document document, Uri uri) {
    final image = _getMetaContent(document, "property", "og:image");
    return _handleUrl(uri, image);
  }

  static String? _handleUrl(Uri uri, String? source) {
    if (isNotEmpty(source) && !source!.startsWith("http")) {
      if (source.startsWith("//")) {
        source = "${uri.scheme}:$source";
      } else {
        if (source.startsWith("/")) {
          source = "${uri.origin}$source";
        } else {
          source = "${uri.origin}/$source";
        }
      }
    }
    return source;
  }
}
