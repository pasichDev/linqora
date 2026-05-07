import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

void launchUrlHandler(String url) async {
  final Uri uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not launch $url: $e');
  }
}
