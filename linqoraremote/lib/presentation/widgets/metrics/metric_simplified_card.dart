import 'package:flutter/material.dart';

class MetricsSimplifieldCard extends StatefulWidget {
  final String title;
  final Widget widget;

  const MetricsSimplifieldCard({
    required this.title,
    required this.widget,
    super.key,
  });

  @override
  State<MetricsSimplifieldCard> createState() => _MetricsSimplifieldCardState();
}

class _MetricsSimplifieldCardState extends State<MetricsSimplifieldCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface,
              ),
            ),

            SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: widget.widget,
            ),
          ],
        ),
      ),
    );
  }
}
