import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

typedef RealtimeHandler = FutureOr<void> Function(Map<String, dynamic> payload);

class RealtimeGateway {
  RealtimeGateway({required this.baseUrl});

  final String baseUrl;

  RealtimeHandler? _onUserEvent;
  RealtimeHandler? _onDriverEvent;

  String? _token;
  bool _userEnabled = false;
  bool _driverEnabled = false;

  final Map<_RealtimeChannel, WebSocketChannel?> _channels = {
    _RealtimeChannel.user: null,
    _RealtimeChannel.driver: null,
  };

  final Map<_RealtimeChannel, StreamSubscription<dynamic>?> _subscriptions = {
    _RealtimeChannel.user: null,
    _RealtimeChannel.driver: null,
  };

  final Map<_RealtimeChannel, Timer?> _pingTimers = {
    _RealtimeChannel.user: null,
    _RealtimeChannel.driver: null,
  };

  final Map<_RealtimeChannel, Timer?> _reconnectTimers = {
    _RealtimeChannel.user: null,
    _RealtimeChannel.driver: null,
  };

  final Map<_RealtimeChannel, int> _reconnectAttempts = {
    _RealtimeChannel.user: 0,
    _RealtimeChannel.driver: 0,
  };

  void setHandlers({
    RealtimeHandler? onUserEvent,
    RealtimeHandler? onDriverEvent,
  }) {
    _onUserEvent = onUserEvent ?? _onUserEvent;
    _onDriverEvent = onDriverEvent ?? _onDriverEvent;
  }

  void updateSession({
    required String? token,
    required bool enableUserChannel,
    required bool enableDriverChannel,
  }) {
    final normalizedToken = (token == null || token.trim().isEmpty)
        ? null
        : token.trim();
    final tokenChanged = normalizedToken != _token;
    _token = normalizedToken;

    final shouldEnableUser = enableUserChannel && normalizedToken != null;
    final shouldEnableDriver = enableDriverChannel && normalizedToken != null;

    if (!shouldEnableUser) {
      _closeChannel(_RealtimeChannel.user);
    }
    if (!shouldEnableDriver) {
      _closeChannel(_RealtimeChannel.driver);
    }
    if (normalizedToken == null) {
      _userEnabled = false;
      _driverEnabled = false;
      return;
    }

    if (tokenChanged) {
      _closeChannel(_RealtimeChannel.user);
      _closeChannel(_RealtimeChannel.driver);
    }

    _userEnabled = shouldEnableUser;
    _driverEnabled = shouldEnableDriver;

    if (_userEnabled && _channels[_RealtimeChannel.user] == null) {
      _connectChannel(_RealtimeChannel.user);
    }

    if (_driverEnabled && _channels[_RealtimeChannel.driver] == null) {
      _connectChannel(_RealtimeChannel.driver);
    }
  }

  void dispose() {
    _closeChannel(_RealtimeChannel.user);
    _closeChannel(_RealtimeChannel.driver);
    _onUserEvent = null;
    _onDriverEvent = null;
  }

  void _connectChannel(_RealtimeChannel channel) {
    if (!_isChannelEnabled(channel)) return;
    final token = _token;
    if (token == null || token.isEmpty) return;

    _reconnectTimers[channel]?.cancel();
    _reconnectTimers[channel] = null;

    try {
      final uri = _buildUri(channel, token);
      final socket = WebSocketChannel.connect(uri);
      _channels[channel] = socket;
      _reconnectAttempts[channel] = 0;

      _subscriptions[channel]?.cancel();
      _subscriptions[channel] = socket.stream.listen(
        (data) => _handleMessage(channel, data),
        onDone: () => _scheduleReconnect(channel),
        onError: (_) => _scheduleReconnect(channel),
        cancelOnError: true,
      );

      _startPing(channel);
    } catch (_) {
      _scheduleReconnect(channel);
    }
  }

  void _handleMessage(_RealtimeChannel channel, dynamic data) {
    final handler = channel == _RealtimeChannel.user
        ? _onUserEvent
        : _onDriverEvent;
    if (handler == null) return;

    final payload = _normalizePayload(data);
    if (payload == null) return;

    Future.microtask(() async {
      try {
        await handler(payload);
      } catch (_) {
        // Swallow handler errors so they do not tear down the stream listener.
      }
    });
  }

  void _scheduleReconnect(_RealtimeChannel channel) {
    if (!_isChannelEnabled(channel)) return;
    _closeChannel(channel, resetAttempts: false);

    final attempt = (_reconnectAttempts[channel] ?? 0) + 1;
    _reconnectAttempts[channel] = attempt;
    final seconds = math.min(30, 1 << math.min(attempt, 4));

    _reconnectTimers[channel]?.cancel();
    _reconnectTimers[channel] = Timer(
      Duration(seconds: seconds),
      () => _connectChannel(channel),
    );
  }

  void _startPing(_RealtimeChannel channel) {
    _pingTimers[channel]?.cancel();
    _pingTimers[channel] = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _send(channel, const {"type": "ping"}),
    );
  }

  void _send(_RealtimeChannel channel, Map<String, Object?> payload) {
    final socket = _channels[channel];
    if (socket == null) return;
    try {
      socket.sink.add(jsonEncode(payload));
    } catch (_) {
      // Ignore sink errors; reconnect logic will handle stale sockets.
    }
  }

  void _closeChannel(_RealtimeChannel channel, {bool resetAttempts = true}) {
    _pingTimers[channel]?.cancel();
    _pingTimers[channel] = null;

    _reconnectTimers[channel]?.cancel();
    _reconnectTimers[channel] = null;

    _subscriptions[channel]?.cancel();
    _subscriptions[channel] = null;

    final socket = _channels[channel];
    _channels[channel] = null;
    socket?.sink.close();

    if (resetAttempts) {
      _reconnectAttempts[channel] = 0;
    }
  }

  bool _isChannelEnabled(_RealtimeChannel channel) {
    return channel == _RealtimeChannel.user ? _userEnabled : _driverEnabled;
  }

  Map<String, dynamic>? _normalizePayload(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    final encoded = switch (data) {
      String value => value,
      List<int> bytes => utf8.decode(bytes),
      _ => null,
    };
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  Uri _buildUri(_RealtimeChannel channel, String token) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'ws',
      channel == _RealtimeChannel.user ? 'user' : 'driver',
      token,
    ];
    return base.replace(scheme: scheme, pathSegments: segments);
  }
}

enum _RealtimeChannel { user, driver }
