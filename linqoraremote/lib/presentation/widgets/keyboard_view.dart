import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/themes/lx_theme.dart';
import '../controllers/keyboard_controller.dart';
import 'lx_glass.dart';
import 'lx_header.dart';

class KeyboardView extends StatelessWidget {
  const KeyboardView({super.key});

  static const _rows = [
    ['ctrl', 'alt', 'shift', 'win'],
    ['tab', 'esc', 'enter', 'backspace'],
    ['up', 'down', 'left', 'right'],
    ['home', 'end', 'pageup', 'pagedown'],
    ['f1', 'f2', 'f3', 'f4', 'f5', 'f6'],
    ['f7', 'f8', 'f9', 'f10', 'f11', 'f12'],
    ['delete', 'insert', 'printscreen', 'space'],
  ];

  static const _labels = {
    'ctrl': 'Ctrl',
    'alt': 'Alt',
    'shift': 'Shift',
    'win': 'Win',
    'tab': 'Tab',
    'esc': 'Esc',
    'enter': '↵',
    'backspace': '⌫',
    'up': '↑',
    'down': '↓',
    'left': '←',
    'right': '→',
    'home': 'Home',
    'end': 'End',
    'pageup': 'PgUp',
    'pagedown': 'PgDn',
    'delete': 'Del',
    'insert': 'Ins',
    'printscreen': 'PrtSc',
    'space': 'Space',
  };

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<KeyboardController>();

    return Column(
      children: [
        const LxHeader(title: 'Keyboard'),
        _TextInputRow(ctrl: ctrl),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: sp18, vertical: sp12),
            child: Column(
              children: _rows.map((row) => _KeyRow(keys: row, ctrl: ctrl)).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<String> keys;
  final KeyboardController ctrl;

  const _KeyRow({required this.keys, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: sp8),
      child: Row(
        children: keys
            .map((k) => Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: sp4),
                  child: _KeyButton(keyName: k, ctrl: ctrl),
                )))
            .toList(),
      ),
    );
  }
}

// ─── Text input row ───────────────────────────────────────────────────────────

class _TextInputRow extends StatefulWidget {
  final KeyboardController ctrl;
  const _TextInputRow({required this.ctrl});
  @override
  State<_TextInputRow> createState() => _TextInputRowState();
}

class _TextInputRowState extends State<_TextInputRow> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text;
    if (text.isEmpty) return;
    widget.ctrl.typeText(text);
    _textCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(sp18, sp4, sp18, sp12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              style: const TextStyle(color: lxText, fontSize: 14),
              cursorColor: lxAccent,
              decoration: InputDecoration(
                hintText: 'Type text to send…',
                hintStyle: const TextStyle(color: lxTextDim),
                filled: true,
                fillColor: lxSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: sp12,
                  vertical: sp8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(lxRadiusCard),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: sp8),
          LxGlass(
            onTap: _send,
            child: const Padding(
              padding: EdgeInsets.all(sp10),
              child: Icon(Icons.send_rounded, color: lxAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Key button ───────────────────────────────────────────────────────────────

class _KeyButton extends StatelessWidget {
  final String keyName;
  final KeyboardController ctrl;

  const _KeyButton({required this.keyName, required this.ctrl});

  static const _modifiers = {'ctrl', 'alt', 'shift', 'win'};

  @override
  Widget build(BuildContext context) {
    final label = KeyboardView._labels[keyName] ?? keyName.toUpperCase();
    final isMod = _modifiers.contains(keyName);

    return Obx(() {
      final isActive = ctrl.activeModifiers.contains(keyName);
      return LxGlass(
        accent: isActive,
        padding: const EdgeInsets.symmetric(vertical: sp12),
        borderRadius: BorderRadius.circular(lxRadiusTile),
        onTap: () => ctrl.tapKey(keyName),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? lxAccent : (isMod ? lxTextDim : lxText),
              fontSize: 12,
              fontWeight: isMod ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    });
  }
}
