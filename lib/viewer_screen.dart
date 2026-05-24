import 'package:flutter/material.dart';

class ViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const ViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.straighten_outlined),
            tooltip: 'Strumento misura',
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Qui apparirà il disegno',
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}