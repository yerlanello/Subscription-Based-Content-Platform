import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opened after launching Stripe Checkout in the browser.
/// Listens for the xabarlaapp://payment deep link that Stripe redirects to on success.
/// Returns the Stripe session_id string on success, or null if the user cancelled.
class PaymentWaitingPage extends StatefulWidget {
  const PaymentWaitingPage({
    super.key,
    required this.checkoutUrl,
    required this.title,
  });

  final String checkoutUrl;
  final String title;

  @override
  State<PaymentWaitingPage> createState() => _PaymentWaitingPageState();
}

class _PaymentWaitingPageState extends State<PaymentWaitingPage>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;
  bool _waitingForReturn = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
    _launchBrowser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  // Called when the app returns from background (e.g. after Chrome redirect).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLatestLink();
    }
  }

  // Fallback: if the stream event was missed, getLatestLink picks it up on resume.
  Future<void> _checkLatestLink() async {
    try {
      final uri = await AppLinks().getLatestLink();
      if (uri != null && mounted) _handleUri(uri);
    } catch (_) {}
  }

  void _handleUri(Uri uri) {
    if (_handled) return;
    if (uri.scheme != 'xabarlaapp' || uri.host != 'payment') return;
    _handled = true;
    final type = uri.queryParameters['type'];
    if (type == 'cancelled') {
      Navigator.of(context).pop(null);
      return;
    }
    final sessionId = uri.queryParameters['session_id'];
    if (sessionId != null && sessionId.isNotEmpty) {
      Navigator.of(context).pop(sessionId);
    }
  }

  void _startListening() {
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      if (!mounted) return;
      _handleUri(uri);
    });
  }

  Future<void> _launchBrowser() async {
    final uri = Uri.parse(widget.checkoutUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) setState(() => _waitingForReturn = true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
        Navigator.of(context).pop(null);
      }
    }
  }

  Future<bool> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text('Your payment will not be processed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmCancel() && context.mounted) {
          Navigator.of(context).pop(null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmCancel() && context.mounted) {
                Navigator.of(context).pop(null);
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_browser, size: 64, color: cs.primary),
                const SizedBox(height: 24),
                Text(
                  _waitingForReturn
                      ? 'Complete your payment in the browser.\nThe app will update automatically when done.'
                      : 'Opening browser…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                if (_waitingForReturn) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _launchBrowser,
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('Re-open browser'),
                  ),
                ] else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
