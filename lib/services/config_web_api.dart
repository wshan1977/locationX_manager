import 'dart:io';
import 'dart:convert';

class ConfigWebApi {
  final int port;
  const ConfigWebApi({this.port = 8080});

  Uri _url(String ip, String path) =>
      Uri.parse('http://$ip:$port$path');

  HttpClient _client() {
    final c = HttpClient();
    c.connectionTimeout = const Duration(seconds: 15);
    c.idleTimeout = const Duration(seconds: 5);
    return c;
  }

  /// GET /
  Future<Map<String, String>> load(String ip) async {
    final client = _client();
    try {
      final req = await client.getUrl(_url(ip, '/'));
      req.headers.set(HttpHeaders.connectionHeader, 'close');
      req.headers.set(HttpHeaders.acceptHeader, 'text/html');

      final resp = await req.close();

      if (resp.statusCode != 200) {
        final body = await utf8.decodeStream(resp);
        throw Exception('GET / failed: ${resp.statusCode} $body');
      }

      final html = await utf8.decodeStream(resp);

      String extract(String name) {
        final open = '<textarea name="$name">';
        final i = html.indexOf(open);
        if (i < 0) throw Exception('textarea[$name] not found');
        final j = html.indexOf('</textarea>', i);
        if (j < 0) throw Exception('textarea[$name] close not found');
        return _htmlUnescape(
          html.substring(i + open.length, j),
        ).trim();
      }

      return {
        'mqtt': extract('mqtt'),
        'locator': extract('locator'),
        'positioning': extract('positioning'),
      };
    } finally {
      client.close(force: true);
    }
  }

  /// POST /save
  Future<void> save({
    required String ip,
    required String mqtt,
    required String locator,
    required String positioning,
  }) async {
    final client = _client();
    try {
      final req = await client.postUrl(_url(ip, '/save'));
      req.headers.set(HttpHeaders.connectionHeader, 'close');
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );

      req.write(Uri(queryParameters: {
        'mqtt': mqtt,
        'locator': locator,
        'positioning': positioning,
      }).query);

      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw Exception('POST /save failed: ${resp.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }

  /// POST /apply
  Future<void> apply(String ip) async {
    final client = _client();
    try {
      final req = await client.postUrl(_url(ip, '/apply'));
      req.headers.set(HttpHeaders.connectionHeader, 'close');
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw Exception('POST /apply failed: ${resp.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }

  static String _htmlUnescape(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
