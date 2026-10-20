import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:daitom/services/payment_config.dart';

enum PaymentState { pending, paid, failed, cancelled }

class PaymentStatus {
  const PaymentStatus({
    required this.checkoutId,
    required this.state,
    required this.amount,
    this.receipt,
    this.paidAmount,
    this.message,
  });

  final String checkoutId;
  final PaymentState state;

  /// KES the prompt was for.
  final int amount;

  /// M-Pesa receipt code (can be null for a moment after a confirmed payment).
  final String? receipt;

  /// KES Safaricom says was actually paid.
  final int? paidAmount;
  final String? message;

  factory PaymentStatus.fromJson(Map<String, dynamic> j) => PaymentStatus(
        checkoutId: j['checkoutId'] as String,
        state: switch (j['status']) {
          'paid' => PaymentState.paid,
          'failed' => PaymentState.failed,
          'cancelled' => PaymentState.cancelled,
          _ => PaymentState.pending,
        },
        amount: (j['amount'] as num).toInt(),
        receipt: j['receipt'] as String?,
        paidAmount: (j['paidAmount'] as num?)?.toInt(),
        message: j['message'] as String?,
      );
}

class PaymentException implements Exception {
  PaymentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the daitom-pay Cloudflare Worker, which holds the M-Pesa keys and
/// sends the PIN prompt. The app only ever sends the amount and phone number;
/// the paid/not-paid answer always comes from the Worker's ledger.
class MpesaPaymentService {
  MpesaPaymentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);

  Uri _uri(String path) {
    final base = kPaymentApiBase.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw PaymentException('Payments are not set up yet. Please contact your administrator.');
    }
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw PaymentException('You are signed out. Please sign in again.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    try {
      final res = await request(await _headers()).timeout(_timeout);
      final body = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) {
        throw PaymentException(
          (body['error'] as String?) ?? 'Payment service error (${res.statusCode}).',
        );
      }
      return body;
    } on PaymentException {
      rethrow;
    } on TimeoutException {
      throw PaymentException('The payment service took too long to respond. Check your connection and try again.');
    } on SocketException {
      throw PaymentException('No internet connection. Connect and try again.');
    } on http.ClientException {
      throw PaymentException('No internet connection. Connect and try again.');
    } on FormatException {
      throw PaymentException('Unexpected response from the payment service.');
    }
  }

  /// Sends the M-Pesa PIN prompt to [phone] for [amount] KES. If this rider
  /// already has a matching prompt in flight (or one that was paid but never
  /// used), that one is returned instead, so nobody is charged twice.
  Future<PaymentStatus> start({required int amount, required String phone}) async {
    final body = await _send(
      (h) => _client.post(
        _uri('/pay'),
        headers: h,
        body: jsonEncode({'amount': amount, 'phone': phone}),
      ),
    );
    return PaymentStatus.fromJson(body);
  }

  Future<PaymentStatus> status(String checkoutId) async {
    final body = await _send((h) => _client.get(_uri('/pay/$checkoutId'), headers: h));
    return PaymentStatus.fromJson(body);
  }

  /// Marks a paid payment as used by a finished clock-out.
  Future<void> consume(String checkoutId) async {
    await _send((h) => _client.post(_uri('/pay/$checkoutId/consume'), headers: h));
  }
}
