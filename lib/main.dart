import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ObjectDetectionScreen(),
    );
  }
}

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({Key? key}) : super(key: key);

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  WebSocketChannel? channel; // Initially null until detection starts
  bool isDetecting = false;
  Uint8List? frameBytes;
  Timer? debounceTimer;

  void toggleDetection() {
    if (isDetecting) {
      // Stop detection
      channel?.sink.add('STOP');
      channel?.sink.close();
      channel = null;
      setState(() {
        isDetecting = false;
        frameBytes = null; // Clear the frame when stopping detection
      });
    } else {
      // Start detection
      channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8000/ws'));
      setState(() {
        isDetecting = true;
      });

      // Listen for WebSocket data
      channel?.stream.listen(
        (data) {
          if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();

          // Debounce to reduce UI flickering
          debounceTimer = Timer(const Duration(milliseconds: 0), () {
            setState(() {
              frameBytes = base64Decode(data);
            });
          });
        },
        onError: (error) {
          setState(() {
            isDetecting = false;
            frameBytes = null;
          });
          showErrorDialog("Connection Error", error.toString());
        },
        onDone: () {
          setState(() {
            isDetecting = false;
            frameBytes = null;
          });
        },
      );

      // Send START command to backend
      channel?.sink.add('START');
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    debounceTimer?.cancel();
    super.dispose();
  }

  void showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("YOLO Object Detection"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Show the camera feed or a placeholder
          Expanded(
            child: isDetecting && frameBytes != null
                ? Image.memory(
                    frameBytes!,
                    fit: BoxFit.cover,
                  )
                : Center(
                    child: Text(
                      isDetecting
                          ? "Waiting for camera feed..."
                          : "Press 'START DETECTION' to begin",
                      style: const TextStyle(fontSize: 18, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.blueGrey,
            child: Center(
              child: Text(
                isDetecting ? "Detection Active" : "Detection Stopped",
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: toggleDetection,
        backgroundColor: isDetecting ? Colors.red : Colors.green,
        label: Text(isDetecting ? "STOP DETECTION" : "START DETECTION"),
        icon: Icon(isDetecting ? Icons.stop : Icons.play_arrow),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
