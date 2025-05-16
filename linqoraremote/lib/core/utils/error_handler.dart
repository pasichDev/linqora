import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showErrorSnackbar(String title, String message) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.orange.shade800,
    colorText: Colors.white,
  );
}