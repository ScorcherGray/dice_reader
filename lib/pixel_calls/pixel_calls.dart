import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Sse {
  final StreamController<String> _streamController = StreamController<String>.broadcast();
  late http.Client _client;
  late http.StreamedResponse _response;
  late Uri _uri;
  bool _isConnected = false;

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
    print('handle events called');
    _response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (event) {
        print('Handling event $event');
        _streamController.add(event); // Forward the event to the stream controller
      },
      onError: (error) {
        print('Error encountered');
        _streamController.addError(error); // Forward errors to the stream controller
        _reconnect(); // Attempt reconnection on error
      },
      onDone: () {
        print('Stream done. onDone and reconnecting.');
        _streamController.close(); // Close the stream controller
        _reconnect(); // Attempt reconnection on stream closure
      },
    );
  }

void _reconnect() {
  if (!_isConnected) {
    _isConnected = true; // Set the connection state to indicate reconnection attempt
    _streamController.add('Reconnecting...'); // Notify the stream about reconnection attempt
    _response.stream.drain().then((_) {
      _client.send(http.Request('GET', _uri)).then((newResponse) {
        _response = newResponse;
        _handleEvents(); // Re-establish event handling on the new response stream
        _isConnected = false; // Reset the connection state after successful reconnection
      }).catchError((error) {
        _streamController.addError(error); // Forward reconnection errors to the stream controller
      });
    }).catchError((error) {
      _streamController.addError(error); // Forward drain errors to the stream controller
    });
  }
}

}