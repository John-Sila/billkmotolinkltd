import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:daitom/services/mpesa_payment_service.dart';

class MpesaPaymentResult {
  const MpesaPaymentResult({
    required this.checkoutId,
    required this.receipt,
    required this.amount,
  });

  final String checkoutId;
  final String? receipt;

  /// KES actually paid, as confirmed by Safaricom.
  final int amount;
}

/// Asks the rider to pay [amount] KES with an M-Pesa PIN prompt.
/// Returns the confirmed payment, or null if they cancelled / it didn't go through.
Future<MpesaPaymentResult?> showMpesaPaymentDialog(
  BuildContext context, {
  required int amount,
  required String initialPhone,
}) {
  return showDialog<MpesaPaymentResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MpesaPaymentDialog(amount: amount, initialPhone: initialPhone),
  );
}

enum _Phase { entry, sending, waiting, failed }

class _MpesaPaymentDialog extends StatefulWidget {
  const _MpesaPaymentDialog({required this.amount, required this.initialPhone});

  final int amount;
  final String initialPhone;

  @override
  State<_MpesaPaymentDialog> createState() => _MpesaPaymentDialogState();
}

class _MpesaPaymentDialogState extends State<_MpesaPaymentDialog> {
  static const Duration _pollEvery = Duration(seconds: 3);
  static const Duration _giveUpAfter = Duration(seconds: 120);
  static final RegExp _phonePattern = RegExp(r'^(?:\+?254|0)?[17]\d{8}$');

  final MpesaPaymentService _service = MpesaPaymentService();
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone == 'No phone' ? '' : widget.initialPhone);

  _Phase _phase = _Phase.entry;
  String? _error;
  String? _checkoutId; // set once a prompt exists, so "Check again" can resume it
  int _elapsed = 0;
  bool _stopped = false;

  @override
  void dispose() {
    _stopped = true;
    _phone.dispose();
    super.dispose();
  }

  String get _amountText => NumberFormat('#,##0').format(widget.amount);

  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (!_phonePattern.hasMatch(phone.replaceAll(RegExp(r'[\s\-]'), ''))) {
      setState(() => _error = 'Enter a valid Safaricom number, e.g. 0712 345 678');
      return;
    }

    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });

    try {
      final status = await _service.start(amount: widget.amount, phone: phone);
      if (!mounted) return;
      _checkoutId = status.checkoutId;
      await _waitFor(status);
    } on PaymentException catch (e) {
      _fail(e.message);
    }
  }

  /// Re-checks a prompt we already sent (e.g. the rider paid but we timed out).
  Future<void> _checkAgain() async {
    final id = _checkoutId;
    if (id == null) return;
    setState(() {
      _phase = _Phase.sending;
      _error = null;
    });
    try {
      await _waitFor(await _service.status(id));
    } on PaymentException catch (e) {
      _fail(e.message);
    }
  }

  Future<void> _waitFor(PaymentStatus first) async {
    var status = first;
    final started = DateTime.now();
    if (mounted) {
      setState(() {
        _phase = _Phase.waiting;
        _elapsed = 0;
      });
    }

    while (mounted && !_stopped) {
      switch (status.state) {
        case PaymentState.paid:
          Navigator.of(context).pop(
            MpesaPaymentResult(
              checkoutId: status.checkoutId,
              receipt: status.receipt,
              amount: status.paidAmount ?? status.amount,
            ),
          );
          return;
        case PaymentState.failed:
        case PaymentState.cancelled:
          _fail(_friendly(status.message, cancelled: status.state == PaymentState.cancelled));
          return;
        case PaymentState.pending:
          break;
      }

      if (DateTime.now().difference(started) > _giveUpAfter) {
        _fail(
          'No answer from M-Pesa yet. If you already entered your PIN, wait a moment and press "Check again".',
        );
        return;
      }

      await Future<void>.delayed(_pollEvery);
      if (!mounted || _stopped) return;
      setState(() => _elapsed = DateTime.now().difference(started).inSeconds);

      try {
        status = await _service.status(status.checkoutId);
      } on PaymentException catch (e) {
        // A hiccup mid-wait (signal dip): keep waiting until the time-out.
        debugPrint('Payment status check failed: ${e.message}');
      }
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  String _friendly(String? desc, {required bool cancelled}) {
    final d = (desc ?? '').toLowerCase();
    if (cancelled || d.contains('cancel')) return 'The M-Pesa prompt was cancelled.';
    if (d.contains('insufficient') || d.contains('balance')) {
      return 'Your M-Pesa balance is too low for this payment.';
    }
    if (d.contains('timeout') || d.contains('cannot be reached')) {
      return "The prompt timed out or your phone couldn't be reached.";
    }
    if (d.contains('initiator') || d.contains('pin')) {
      return 'The M-Pesa PIN was entered incorrectly.';
    }
    return (desc == null || desc.isEmpty) ? 'The payment did not go through.' : desc;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.phone_android, color: cs.primary),
            const SizedBox(width: 10),
            const Expanded(child: Text('Pay via M-Pesa')),
          ],
        ),
        content: SingleChildScrollView(child: _content(theme)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: _actions(),
      ),
    );
  }

  Widget _content(ThemeData theme) {
    final cs = theme.colorScheme;

    final amountBlock = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('Amount to pay', style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            'KES $_amountText',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );

    switch (_phase) {
      case _Phase.entry:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            amountBlock,
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofocus: widget.initialPhone.isEmpty,
              decoration: InputDecoration(
                labelText: 'M-Pesa number',
                helperText: 'The prompt will be sent to this number',
                prefixIcon: const Icon(Icons.phone),
                errorText: _error,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        );

      case _Phase.sending:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            amountBlock,
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Contacting M-Pesa...', style: theme.textTheme.bodyMedium),
          ],
        );

      case _Phase.waiting:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            amountBlock,
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Check your phone and enter your M-Pesa PIN',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Waiting for confirmation... ${_elapsed}s',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );

      case _Phase.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            amountBlock,
            const SizedBox(height: 16),
            Icon(Icons.error_outline, color: cs.error, size: 36),
            const SizedBox(height: 8),
            Text(
              _error ?? 'The payment did not go through.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            ),
          ],
        );
    }
  }

  List<Widget> _actions() {
    switch (_phase) {
      case _Phase.entry:
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.send_to_mobile),
            label: const Text('Send prompt'),
          ),
        ];
      case _Phase.sending:
        return const [];
      case _Phase.waiting:
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ];
      case _Phase.failed:
        return [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          if (_checkoutId != null)
            OutlinedButton(onPressed: _checkAgain, child: const Text('Check again')),
          FilledButton(
            onPressed: () => setState(() {
              _phase = _Phase.entry;
              _error = null;
            }),
            child: const Text('Try again'),
          ),
        ];
    }
  }
}
