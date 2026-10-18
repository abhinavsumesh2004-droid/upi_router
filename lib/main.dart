import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const MyApp());

/// EDIT THIS LIST: your own curated offer info (no UPI app exposes this via API).
class UpiApp {
  final String name;
  final String package;
  final String offer;
  const UpiApp(this.name, this.package, this.offer);
}

const upiApps = <UpiApp>[
  UpiApp('Google Pay', 'com.google.android.apps.nbu.paisa.user', 'Scratch card offers'),
  UpiApp('PhonePe', 'com.phonepe.app', 'Check in-app offers'),
  UpiApp('Paytm', 'net.one97.paytm', 'Check in-app offers'),
  UpiApp('CRED', 'com.dreamplug.androidapp', 'Check CRED coins / cashback'),
  UpiApp('BHIM', 'in.org.npci.upiapp', 'Govt cashback schemes'),
];

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'UPI Router',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const ScanPage(),
      );
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? raw; // original, unmodified QR string

  Map<String, String>? get params => raw == null ? null : Uri.tryParse(raw!)?.queryParameters;

  bool get isUpi => raw != null && raw!.toLowerCase().startsWith('upi://');

  bool get isMerchant {
    final mc = params?['mc'];
    return mc != null && mc.isNotEmpty && mc != '0000';
  }

  Future<void> launchApp(String? package) async {
    final intent = AndroidIntent(action: 'action_view', data: raw, package: package);
    try {
      if (package == null) {
        await intent.launchChooser('Pay with');
      } else {
        await intent.launch();
      }
    } catch (_) {
      // App not installed or refused: fall back to system chooser
      await AndroidIntent(action: 'action_view', data: raw).launchChooser('Pay with');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UPI Router')),
      body: raw == null ? _scanner() : _result(),
    );
  }
  Widget _scanner() => MobileScanner(
        errorBuilder: (context, error, child) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Camera error: ${error.errorCode.name}\n${error.errorDetails?.message ?? ''}',
                            style: const TextStyle(color: Colors.red, fontSize: 18),,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        onDetect: (capture)  {
          final value = capture.barcodes.firstOrNull?.rawValue;
          if (value != null && raw == null) setState(() => raw = value);
        },
      );

  Widget _result() {
    if (!isUpi) {
      return _message('Not a UPI QR code.');
    }
    final p = params ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(p['pn'] ?? 'Unknown payee', style: Theme.of(context).textTheme.headlineSmall),
        Text(p['pa'] ?? ''),
        const SizedBox(height: 8),
        Chip(
          label: Text(isMerchant ? 'Merchant (MCC ${p['mc']})' : 'Personal / no merchant code'),
          backgroundColor: isMerchant ? Colors.green.shade100 : Colors.orange.shade100,
        ),
        const SizedBox(height: 16),
        if (isMerchant) ...[
          const Text('Choose an app to pay with:'),
          ...upiApps.map((a) => Card(
                child: ListTile(
                  title: Text(a.name),
                  subtitle: Text(a.offer),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => launchApp(a.package),
                ),
              )),
        ] else
          FilledButton(onPressed: () => launchApp(null), child: const Text('Open app chooser')),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () => setState(() => raw = null), child: const Text('Scan another')),
      ],
    );
  }

  Widget _message(String m) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(m),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => setState(() => raw = null), child: const Text('Scan again')),
        ]),
      );
}
