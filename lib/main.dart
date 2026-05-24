import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'viewer_screen.dart';

void main() {
  runApp(const CadViewApp());
}

class CadViewApp extends StatelessWidget {
  const CadViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAD View',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && context.mounted) {
      final path = result.files.single.path!;
      final name = result.files.single.name;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(filePath: path, fileName: name),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.architecture,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CAD View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Viewer & misure DWG',
                        style: TextStyle(
                          color: Color(0xFF7B8BB2),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFF1E3A5F),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.folder_open_outlined,
                        color: Color(0xFF1565C0),
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Nessun file aperto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Apri un file DWG o DXF\nper iniziare',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7B8BB2),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _openFile(context),
                  icon: const Icon(Icons.file_open_outlined, size: 22),
                  label: const Text(
                    'Apri file DWG',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Formati supportati: DWG · DXF',
                  style: TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}