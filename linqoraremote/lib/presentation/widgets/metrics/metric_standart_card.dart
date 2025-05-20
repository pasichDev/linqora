import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MetricsStandartCard extends StatefulWidget {
  final String title;
  final String value;
  final Widget? widget;

  const MetricsStandartCard({
    required this.title,
    required this.value,
    this.widget,
    super.key,
  });

  @override
  State<MetricsStandartCard> createState() => _MetricsStandartCardState();
}

class _MetricsStandartCardState extends State<MetricsStandartCard> {
  bool _isExpanded = true;

  _expanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Get.theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,

          onTap: _expanded,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title, style: Get.theme.textTheme.titleMedium),
                  Row(
                    children: [
                      Text(
                        widget.value,
                        style: Get.theme.textTheme.titleMedium?.copyWith(
                          color: Get.theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (widget.widget != null) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _expanded,
                          child: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 24,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  child: widget.widget!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
