import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';

/// Wrapper tipis di atas package flutter_thermal_printer.
///
/// CATATAN: package printer thermal (paket manapun yang dipakai) API-nya
/// cukup sering berubah antar versi. Kalau setelah `flutter pub get` ada
/// error "method/getter tidak ditemukan" di sini, buka contoh resmi paket
/// ini di pub.dev (flutter_thermal_printer > Example) dan sesuaikan nama
/// method/stream-nya — strukturnya (scan -> pilih -> connect -> print)
/// tetap sama, cuma nama API persisnya yang mungkin geser.
class ThermalPrinterService {
  static final FlutterThermalPrinter _plugin = FlutterThermalPrinter.instance;

  static Stream<List<Printer>> get devicesStream => _plugin.devicesStream;

  static Future<void> scanPrinters({
    List<ConnectionType> connectionTypes = const [ConnectionType.BLE, ConnectionType.USB],
    Duration refreshDuration = const Duration(seconds: 4),
  }) {
    return _plugin.getPrinters(refreshDuration: refreshDuration, connectionTypes: connectionTypes);
  }

  static Future<void> connect(Printer printer) => _plugin.connect(printer);

  static Future<void> disconnect(Printer printer) => _plugin.disconnect(printer);

  static Future<void> printReceiptWidget(Printer printer, Widget widget) {
    return _plugin.printWidget(printer, widget);
  }
}
