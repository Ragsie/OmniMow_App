import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'ros_service.dart'; // Import to read the active robot IP

class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends State<LiveFeedScreen> {
  final RTCVideoRenderer _videoRenderer = RTCVideoRenderer();
  bool _isRendererInitialized = false;

  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _signalingChannel;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _videoRenderer.initialize();
    setState(() {
      _isRendererInitialized = true;
    });

    // Creates connection ONLY when this specific screen is opened
    _connectWebRTC();
  }

  Future<void> _connectWebRTC() async {
    try {
      // Gets the active robot IP directly from the central ROS Service!
      final robotIp = rosService.currentIp;

      if (robotIp.isEmpty) {
        debugPrint("Error: No active IP selected!");
        return;
      }

      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video') {
          setState(() {
            _videoRenderer.srcObject = event.streams[0];
          });
        }
      };

      // Connects the WebRTC signaling to port 8889 on the robot's FastAPI/MediaMTX service
      final signalingUrl = 'ws://$robotIp:8889/webrtc';
      _signalingChannel = WebSocketChannel.connect(Uri.parse(signalingUrl));

      _signalingChannel!.stream.listen((message) async {
        final data = jsonDecode(message);

        if (data['type'] == 'answer') {
          final answer = RTCSessionDescription(data['sdp'], data['type']);
          await _peerConnection!.setRemoteDescription(answer);
        } else if (data['type'] == 'offer') {
          final offer = RTCSessionDescription(data['sdp'], data['type']);
          await _peerConnection!.setRemoteDescription(offer);
          final answer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(answer);
          _signalingChannel!.sink.add(jsonEncode({'type': 'answer', 'sdp': answer.sdp}));
        } else if (data['candidate'] != null) {
          final candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
        }
      });

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _signalingChannel!.sink.add(jsonEncode({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }));
      };

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _signalingChannel!.sink.add(jsonEncode({
        'type': 'offer',
        'sdp': offer.sdp,
      }));

    } catch (e) {
      debugPrint("WebRTC Error: $e");
    }
  }

  @override
  void dispose() {
    // Closes and cuts the stream completely as soon as you go back to Dashboard!
    _signalingChannel?.sink.close();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _videoRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("YOLO Camera Feed")),
      backgroundColor: Colors.black, // Makes the video stream look better
      body: Center(
        child: _isRendererInitialized
            ? RTCVideoView(
                _videoRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}