import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anjing atau Kucing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashPage(),
    );
  }
}

/// Halaman pembuka
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.teal, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.shade100,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Center(
                        child: Icon(Icons.pets, size: 70, color: Colors.teal)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ANJING ATAU KUCING INI?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 600),
                      pageBuilder: (_, __, ___) =>
                          const CameraGalleryPage(),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                    ),
                  );
                },
                icon: const Icon(Icons.pets),
                label: const Text('MULAI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Dibuat oleh Kelomnpok C4',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halaman utama
class CameraGalleryPage extends StatefulWidget {
  const CameraGalleryPage({super.key});

  @override
  State<CameraGalleryPage> createState() => _CameraGalleryPageState();
}

class _CameraGalleryPageState extends State<CameraGalleryPage> {
  File? _imageFile;
  bool _isProcessing = false;
  String _resultText = '';

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
          _resultText = '';
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _sendImageForAnalysis() async {
    if (_imageFile == null) {
      _showSnack('Pilih gambar terlebih dahulu (Kamera / Galeri).');
      return;
    }

    setState(() {
      _isProcessing = true;
      _resultText = '';
    });

    try {
      final result = await analyzeImage(_imageFile!);
      setState(() => _resultText = result);
    } catch (e) {
      setState(() => _resultText = 'Terjadi kesalahan: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Analisis gambar menggunakan model TFLite
  Future<String> analyzeImage(File imageFile) async {
    try {
      final interpreter =
          await Interpreter.fromAsset('assets/dogs_cats_modelv2.tflite');

      final labelData = await rootBundle.loadString('assets/label.txt');
      final labels = labelData
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final rawBytes = await imageFile.readAsBytes();
      final oriImage = img.decodeImage(rawBytes);
      if (oriImage == null) throw Exception("Gagal decode gambar");
      final resized = img.copyResize(oriImage, width: 128, height: 128);

      final input = List.generate(
        1,
        (_) => List.generate(
          128,
          (y) => List.generate(
            128,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final output = List.generate(1, (_) => List.filled(1, 0.0));
      interpreter.run(input, output);

      final prob = output[0][0];
      final isDog = prob >= 0.5;
      final label = isDog ? labels[1] : labels[0];
      final confidence = (isDog ? prob : 1 - prob) * 100;

      final description = getDescription(label, confidence);

      return 'Hasil: ${label.toUpperCase()} (${confidence.toStringAsFixed(2)}%)\n\n$description';
    } catch (e) {
      return 'Terjadi kesalahan saat analisis: $e';
    }
  }

  /// Deskripsi hasil berdasarkan label & confidence
  String getDescription(String label, double confidence) {
  final lower = label.toLowerCase();

  if (lower.contains('dog')) {
    if (confidence > 90) return 'Anjing ini tampak sangat jelas! Detail wajah dan bulunya terdeteksi kuat.';
    if (confidence > 70) return 'Kemungkinan besar ini anjing, namun pencahayaan atau posisi mungkin mempengaruhi.';
    return 'Model tidak terlalu yakin, coba gunakan foto yang lebih terang.';
  }

  if (lower.contains('cat')) {
    if (confidence > 90) return 'Kucing yang lucu! Model mengenali wajah dan bulunya dengan jelas.';
    if (confidence > 70) return 'Kemungkinan besar ini kucing, meskipun ada sedikit keraguan.';
    return 'Model agak ragu, coba gunakan foto yang lebih terang.';
  }

  return 'Tidak dapat memberikan deskripsi.';
}


  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildPreviewBox() {
    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: _imageFile == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 8),
                const Text('Belum ada gambar'),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Kamera'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
       const SizedBox(width: 12),
       Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Galeri'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _sendImageForAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Kirim'),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBox() {
  if (_resultText.isEmpty) {
    return const Text('Hasil: -');
  }

  final firstLine = _resultText.split('\n').first.toLowerCase();
  final isDog = firstLine.contains('dogs');

  final color = isDog ? Colors.orange.shade100 : Colors.blue.shade100;
  final icon = isDog ? Icons.pets : Icons.favorite;

  return Card(
    color: color,
    elevation: 2,
    margin: const EdgeInsets.only(top: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: Colors.teal.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _resultText,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deteksi Hewan'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreviewBox(),
              _buildActionButtons(),
              _buildResultBox(),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
