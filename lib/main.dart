import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const appName = 'PayLane';
const _accent = Color(0xFF00D4AA);
const _violet = Color(0xFF6C63FF);

void main() => runApp(const PayLaneApp());

class PayLaneApp extends StatelessWidget {
  const PayLaneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: _violet,
        ),
        home: const ScanPage(),
      );
}

// ---------------------------------------------------------------------------
// UPI QR parsing
// ---------------------------------------------------------------------------

const _mccNames = <String, String>{
  '5411': 'Grocery / supermarket',
  '5311': 'Department store',
  '5499': 'Convenience store',
  '5812': 'Restaurant',
  '5814': 'Fast food',
  '5541': 'Fuel station',
  '5542': 'Fuel dispenser',
  '5912': 'Pharmacy',
  '5651': 'Clothing store',
  '5732': 'Electronics store',
  '4121': 'Taxi / cab',
  '4814': 'Telecom',
  '4900': 'Utilities',
  '7011': 'Hotel',
  '8062': 'Hospital',
};

class UpiInfo {
  UpiInfo(this.raw) : params = _parse(raw);

  final String raw;
  final Map<String, String> params;

  static Map<String, String> _parse(String raw) {
    final i = raw.indexOf('?');
    if (i < 0) return {};
    final out = <String, String>{};
    for (final part in raw.substring(i + 1).split('&')) {
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      final key = eq < 0 ? part : part.substring(0, eq);
      var value = eq < 0 ? '' : part.substring(eq + 1);
      try {
        value = Uri.decodeComponent(value);
      } catch (_) {}
      out[key.toLowerCase()] = value;
    }
    return out;
  }

  bool get isUpi => raw.toLowerCase().startsWith('upi://');

  bool get isMerchant {
    final mc = params['mc'];
    return mc != null && mc.isNotEmpty && mc != '0000';
  }

  String get payee {
    final pn = params['pn'];
    return (pn != null && pn.isNotEmpty) ? pn : 'Unknown payee';
  }

  String get vpa => params['pa'] ?? '';
  String? get amount => params['am'];

  String? get category {
    if (!isMerchant) return null;
    final mc = params['mc']!;
    return _mccNames[mc] ?? 'Category code $mc';
  }
}

// ---------------------------------------------------------------------------
// Scan screen
// ---------------------------------------------------------------------------

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  final _controller =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  late final AnimationController _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  bool _busy = false;
  bool _torch = false;

  @override
  void dispose() {
    _line.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _showResult(value);
  }

  Future<void> _paste() async {
    if (_busy) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) _showResult(text);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _torch = !_torch);
    } catch (_) {}
  }

  Future<void> _openChooser(String raw) async {
    try {
      await AndroidIntent(action: 'action_view', data: raw)
          .launchChooser('Pay with');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the UPI app selector')),
      );
    }
  }

  Future<void> _showResult(String value) async {
    if (!mounted) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    final info = UpiInfo(value);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ResultSheet(info: info, onChoose: () => _openChooser(value)),
    );
    await Future.delayed(const Duration(milliseconds: 800));
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F1A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error, [child]) => Container(
                color: const Color(0xFF0B0F1A),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded,
                        size: 48, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text('Camera unavailable',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60)),
                  ],
                ),
              ),
              onDetect: _onDetect,
            ),
            LayoutBuilder(builder: (context, c) {
              final side = (c.maxWidth * 0.72).clamp(220.0, 320.0).toDouble();
              final window = Rect.fromCenter(
                center: Offset(c.maxWidth / 2, c.maxHeight * 0.42),
                width: side,
                height: side,
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ScanOverlay(window, _accent),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _line,
                    builder: (context, _) {
                      final t = Curves.easeInOut.transform(_line.value);
                      return Positioned(
                        left: window.left + 20,
                        width: window.width - 40,
                        top: window.top + 16 + (window.height - 32) * t,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(colors: [
                              Colors.transparent,
                              _accent,
                              Colors.transparent,
                            ]),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withAlpha(120),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(
                            colors: [_violet, _accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        appName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      _GlassButton(
                          icon: Icons.content_paste_rounded, onTap: _paste),
                      const SizedBox(width: 8),
                      _GlassButton(
                        icon: _torch
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom hint
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.center_focus_strong_rounded,
                              size: 18, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Point at a UPI QR code',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withAlpha(110),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      );
}

class ScanOverlay extends CustomPainter {
  ScanOverlay(this.window, this.color);

  final Rect window;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(window, const Radius.circular(28));
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rrect),
    );
    canvas.drawPath(dim, Paint()..color = Colors.black.withAlpha(150));

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 36.0;
    const r = 28.0;

    void corner(Offset o, double dx, double dy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + dy * len)
        ..lineTo(o.dx, o.dy + dy * r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + dx * r, o.dy)
        ..lineTo(o.dx + dx * len, o.dy);
      canvas.drawPath(path, p);
    }

    corner(window.topLeft, 1, 1);
    corner(window.topRight, -1, 1);
    corner(window.bottomLeft, 1, -1);
    corner(window.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(ScanOverlay old) =>
      old.window != window || old.color != color;
}

// ---------------------------------------------------------------------------
// Result pop-up
// ---------------------------------------------------------------------------

class ResultSheet extends StatelessWidget {
  const ResultSheet({super.key, required this.info, required this.onChoose});

  final UpiInfo info;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color accent;
    final IconData icon;
    final String title;
    final String subtitle;

    if (!info.isUpi) {
      accent = const Color(0xFFF87171);
      icon = Icons.qr_code_2_rounded;
      title = 'Not a UPI QR';
      subtitle = "This code isn't a UPI payment QR.";
    } else if (info.isMerchant) {
      accent = const Color(0xFF34D399);
      icon = Icons.storefront_rounded;
      title = 'Merchant';
      subtitle = 'Verified merchant code found in this QR.';
    } else {
      accent = const Color(0xFFFBBF24);
      icon = Icons.person_rounded;
      title = 'Personal account';
      subtitle = 'No merchant code found in this QR.';
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 20 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withAlpha(36),
            ),
            child: Icon(icon, size: 36, color: accent),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: accent)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          if (info.isUpi) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.payee,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  if (info.vpa.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(info.vpa,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                  if (info.category != null || info.amount != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (info.category != null)
                          _Pill(info.category!, accent),
                        if (info.amount != null)
                          _Pill('\u20B9${info.amount}', _violet),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('Choose UPI app'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Scan another'),
          ),
          const SizedBox(height: 4),
          Text(
            '$appName only routes the payment. It never stores your details.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(36),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color),
        ),
      );
}
