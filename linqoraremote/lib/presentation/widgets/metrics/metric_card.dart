import 'package:flutter/material.dart';

class MetricsCard extends StatefulWidget {
  final String title;
  final String value;
  final Widget? widget;

  const MetricsCard({
    required this.title,
    required this.value,
    this.widget,
    super.key,
  });

  @override
  State<MetricsCard> createState() => _MetricsCardState();
}

class _MetricsCardState extends State<MetricsCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 16)),
                Row(
                  children: [
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.widget != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 24,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (widget.widget != null && _isExpanded)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: widget.widget!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
