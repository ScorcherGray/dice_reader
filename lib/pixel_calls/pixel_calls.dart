import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Sse {
  final StreamController<String> _streamController = StreamController<String>.broadcast();
  late http.Client _client;
  late http.StreamedResponse _response;
  late Uri _uri;

  Sse._(this._client, this._response, this._uri) {
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
    final response = await client.send(request); // Breaks when the server is cut
    return Sse._(client, response, uri);
  }

  Stream<String> get stream => _streamController.stream;

  void close() {
    _streamController.close();
    _client.close();
  }

  void _handleEvents() {
    String buffer = '';
    
    _response.stream.transform(utf8.decoder).listen(
        (String data) {
          print('SSE raw chunk...\n $data \n END OF CHUNK');
          buffer += data.replaceAll('\r\n', '\n');
          if (buffer.contains('\n\n')) {
            final parts = buffer.split('\n\n');
            for (var i = 0; i < parts.length - 1; i++) {
              final block = parts[i];
              for (final rawLine in block.split('\n')) {
                final line = rawLine.trim();
                if (line.isEmpty) continue;
                if (line.startsWith('data:')) {
                  final eventData = line.substring(6);
                  if (eventData.contains('"heartbeat":true')) continue;
                  print('Adding SSE event: $eventData');
                  _streamController.add(eventData);
                }
              }
            }
            buffer = parts.last;
        }
      },
      onError: (error) {
        _streamController.addError(error);
      },
      onDone: () {
        _streamController.addError('Connection closed');
      },
    );
  }

  Uri get uri => _uri;
}