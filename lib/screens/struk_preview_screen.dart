import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/receipt_data.dart';
import '../services/receipt_pdf.dart';
import '../widgets/receipt_widget.dart';
import 'printer_picker_screen.dart';

class StrukPreviewScreen extends StatefulWidget {
  final ReceiptData data;
  const StrukPreviewScreen({super.key, required this.data});

  @override
  State<StrukPreviewScreen> createState() => _StrukPreviewScreenState();
}

class _StrukPreviewScreenState extends State<StrukPreviewScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _busy = false;

  Future<void> _bagikanGambar() async {
    setState(() => _busy = true);
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 3);
      if (bytes == null) throw Exception('Gagal mengambil gambar struk');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/struk_${widget.data.noNota}.jpg');
      await file.writeAsBytes(bytes);

      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Struk ${widget.data.noNota}',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      _snack('Gagal membagikan gambar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bagikanPdf() async {
    setState(() => _busy = true);
    try {
      final doc = buildReceiptPdf(widget.data);
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: 'struk_${widget.data.noNota}.pdf');
    } catch (e) {
      _snack('Gagal membagikan PDF: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cetakPdf() async {
    setState(() => _busy = true);
    try {
      final doc = buildReceiptPdf(widget.data);
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      _snack('Gagal membuka dialog cetak: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cetakThermal() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PrinterPickerScreen(data: widget.data)));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Struk')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Screenshot(
                  controller: _screenshotController,
                  child: Card(
                    elevation: 2,
                    child: ReceiptWidget(data: widget.data),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _bagikanGambar,
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('Bagikan JPG'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _bagikanPdf,
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Bagikan PDF'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _cetakPdf,
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('Print (dialog sistem)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _cetakThermal,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Printer Thermal'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
