import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ros_service.dart'; // Read the active robot IP from the shared service.

/// Displays the active mower camera stream through a WebRTC connection.
class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

/// Owns the WebRTC renderer, peer connection, and signaling channel lifecycle.
class _LiveFeedScreenState extends State<LiveFeedScreen> {
  final RTCVideoRenderer _videoRenderer = RTCVideoRenderer();
  bool _isRendererInitialized = false;

  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _signalingChannel;
  StreamSubscription? _signalingSubscription;
  bool _disposed = false;

  /// Shown instead of the video when the stream cannot be started.
  String? _error;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  /// Initializes the video renderer before opening the signaling connection.
  Future<void> _initRenderer() async {
    await _videoRenderer.initialize();
    if (_disposed) return;
    setState(() {
      _isRendererInitialized = true;
    });

    // Creates connection ONLY when this specific screen is opened
    _connectWebRTC();
  }

  /// Negotiates a WebRTC session with the mower's camera service.
  Future<void> _connectWebRTC() async {
    try {
      // Fetches the active robot IP directly from the central ROS Service!
      final robotIp = rosService.currentIp;

      if (robotIp.isEmpty) {
        _showError("No mower selected.");
        return;
      }

      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

      final pc = await createPeerConnection(configuration);
      if (_disposed) {
        await pc.dispose(); // screen closed while the connection was created
        return;
      }
      _peerConnection = pc;

      // Ask to receive video: without a transceiver the offer has no video
      // section and the mower has nothing to answer with.
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        if (_disposed || event.track.kind != 'video') return;
        // The track may arrive without a stream (no msid in the SDP).
        MediaStream stream;
        if (event.streams.isNotEmpty) {
          stream = event.streams.first;
        } else {
          stream = await createLocalMediaStream('mower');
          await stream.addTrack(event.track);
        }
        if (_disposed) return;
        setState(() {
          _videoRenderer.srcObject = stream;
        });
      };

      // Connects WebRTC signaling to port 8889 on the robot's FastAPI/MediaMTX service
      final signalingUrl = 'ws://$robotIp:8889/webrtc';
      _signalingChannel = WebSocketChannel.connect(Uri.parse(signalingUrl));

      _signalingSubscription = _signalingChannel!.stream.listen(
        (message) => _handleSignalingMessage(message).catchError((Object e) {
          debugPrint("WebRTC signaling error: $e");
        }),
        onError: (Object e) {
          debugPrint("WebRTC signaling connection failed: $e");
          _showError("Could not reach the mower camera stream.");
        },
      );

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (_disposed || candidate.candidate == null) return;
        _signalingChannel?.sink.add(
          jsonEncode({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }),
        );
      };

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _signalingChannel?.sink.add(
        jsonEncode({'type': 'offer', 'sdp': offer.sdp}),
      );
    } catch (e) {
      debugPrint("WebRTC Error: $e");
      _showError("Could not start the live stream.");
    }
  }

  /// Applies one JSON signaling message from the mower.
  Future<void> _handleSignalingMessage(dynamic message) async {
    final pc = _peerConnection;
    if (_disposed || pc == null) return;
    final data = jsonDecode(message);
    if (data is! Map) return;

    if (data['type'] == 'answer') {
      final answer = RTCSessionDescription(data['sdp'], data['type']);
      await pc.setRemoteDescription(answer);
    } else if (data['type'] == 'offer') {
      final offer = RTCSessionDescription(data['sdp'], data['type']);
      await pc.setRemoteDescription(offer);
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _signalingChannel?.sink.add(
        jsonEncode({'type': 'answer', 'sdp': answer.sdp}),
      );
    } else if (data['candidate'] != null) {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await pc.addCandidate(candidate);
    }
  }

  void _showError(String message) {
    if (_disposed) return;
    setState(() => _error = message);
  }

  /// Releases all streaming resources when the screen is removed.
  @override
  void dispose() {
    // Close and fully stop the stream as soon as the user returns to the dashboard.
    _disposed = true;
    _signalingSubscription?.cancel();
    _signalingChannel?.sink.close();
    final pc = _peerConnection;
    _peerConnection = null;
    // Close before dispose; running both at once can race in the native plugin.
    if (pc != null) {
      pc.close().catchError((_) {}).whenComplete(pc.dispose);
    }
    _videoRenderer.srcObject = null;
    _videoRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("YOLO Camera Feed")),
      backgroundColor: Colors.black, // Makes the video stream look better
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            : _isRendererInitialized
            ? RTCVideoView(
                _videoRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
