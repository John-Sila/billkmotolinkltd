import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastService {
  static void success(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void warning(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void error(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  static void info(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.blueGrey,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}