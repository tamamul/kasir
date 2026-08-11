import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import '../models/receipt_data.dart';
import '../services/thermal_printer_service.dart';
import '../widgets/receipt_widget.dart';

class PrinterPickerScreen extends StatefulWidget {
  final ReceiptData data;
  const PrinterPickerScreen({super.key, required this.data});

  @override
  State<PrinterPickerScreen> createState() => _PrinterPickerScreenState();
}

class _PrinterPickerScreenState extends State<PrinterPickerScreen> {
  List<Printer> _printers = [];
  bool _scanning = true;
  Printer? _mencetak;

  @override
  void initState() {
    super.initState();
    _mulaiScan();
  }

  void _mulaiScan() {
    setState(() => _scanning = true);
    ThermalPrinterService.devicesStream.listen((list) {
      if (mounted) setState(() => _printers = list);
    });
    ThermalPrinterService.scanPrinters();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _cetak(Printer printer) async {
    setState(() => _mencetak = printer);
    try {
      await ThermalPrinterService.connect(printer);
      await ThermalPrinterService.printReceiptWidget(printer, ReceiptWidget(data: widget.data));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Struk terkirim ke printer')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal cetak: $e')));
      }
    } finally {
      if (mounted) setState(() => _mencetak = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Printer'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _mulaiScan),
        ],
      ),
      body: Column(
        children: [
          if (_scanning) const LinearProgressIndicator(),
          Expanded(
            child: _printers.isEmpty
                ? Center(
                    child: Text(
                      _scanning ? 'Mencari printer...' : 'Printer tidak ditemukan.\nPastikan sudah dipasangkan (paired) lewat Bluetooth HP dulu.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _printers.length,
                    itemBuilder: (_, i) {
                      final p = _printers[i];
                      final sedangCetak = _mencetak?.address == p.address;
                      return ListTile(
                        leading: const Icon(Icons.print),
                        title: Text(p.name ?? p.address ?? 'Printer'),
                        subtitle: Text(p.connectionType?.name ?? ''),
                        trailing: sedangCetak
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right),
                        onTap: sedangCetak ? null : () => _cetak(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
