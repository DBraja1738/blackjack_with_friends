import 'dart:io';
import 'dart:convert';
import 'dart:async';

class TCPChannel {
  Socket? _socket;
  final StreamController<dynamic> _streamController = StreamController.broadcast();
  final StreamController<dynamic> _sinkController = StreamController();
  StringBuffer _buffer = StringBuffer();

  Stream<dynamic> get stream => _streamController.stream;
  TCPSink get sink => TCPSink(_sinkController);

  TCPChannel._();

  static Future<TCPChannel> connect(String host, int port) async {
    final channel = TCPChannel._();
    await channel._connect(host, port);
    return channel;
  }

  Future<void> _connect(String host, int port) async {
    _socket = await Socket.connect(host, port);

    _sinkController.stream.listen((data) {
      if (_socket != null) {
        _socket!.write('$data\n');
      }
    });


    _socket!.listen(
          (data) {
        _buffer.write(utf8.decode(data));

        // process complete messages
        String bufferContent = _buffer.toString();
        List<String> lines = bufferContent.split('\n');

        // keep incomplete line in buffer
        _buffer = StringBuffer(lines.removeLast());

        // send complete messages to stream
        for (String line in lines) {
          line = line.trim();
          if (line.isNotEmpty) {
            _streamController.add(line);
          }
        }
      },
      onError: (error) {
        _streamController.addError(error);
      },
      onDone: () {
        _streamController.close();
        _sinkController.close();
      },
    );
  }

  void close() {
    _socket?.close();
    _streamController.close();
    _sinkController.close();
  }
}

class TCPSink {
  final StreamController<dynamic> _controller;

  TCPSink(this._controller);

  void add(dynamic data) {
    _controller.add(data);
  }

  void close() {
    _controller.close();
  }
}