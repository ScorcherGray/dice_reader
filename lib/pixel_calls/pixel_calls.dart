import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Sse {
  final StreamController<String> _streamController = StreamController<String>.broadcast();
  late http.Client _client;
  late http.StreamedResponse _response;

  Sse._(this._client, this._response) {
    _handleEvents();
  }

  static Future<Sse> connect({
    required Uri uri,
    Map<String, String>? headers,
  }) async {
    final client = http.Client();
    final request = http.Request('GET', uri);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.headers['Cache-Control'] = 'no-cache';
    request.headers['Accept'] = 'text/event-stream';
    final response = await client.send(request);
    return Sse._(client, response);
  }

  Stream<String> get stream => _streamController.stream;

  void close() {
    _streamController.close();
    _client.close();
  }

  void _handleEvents() {
    _response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((event) {
      // Process the event data as needed
      _streamController.add(event);
    }, onError: (error) {
      // Handle errors
      _streamController.addError(error);
    }, onDone: () {
      // Handle stream completion
      _streamController.close();
    });
  }
}