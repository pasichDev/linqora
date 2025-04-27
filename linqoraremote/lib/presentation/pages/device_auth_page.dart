import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/routes/app_routes.dart';

import '../widgets/app_bar.dart';

class DeviceAuthPage extends StatefulWidget {
  const DeviceAuthPage({super.key});

  @override
  State<DeviceAuthPage> createState() => _DeviceAuthPageState();
}


/**
 * Якщо повернутися з помилкою ssnackBarто вилітає назад клавіатура
 */
class _DeviceAuthPageState extends State<DeviceAuthPage> {
  final TextEditingController _codeController = TextEditingController();
  final int _codeLength = 6;
  final List<FocusNode> _focusNodes = [];
  final List<TextEditingController> _controllers = [];
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _codeLength; i++) {
     _focusNodes.add(FocusNode());
      _controllers.add(TextEditingController());
    }

  }

  @override
  void dispose() {
    _codeController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPinChanged() {
    String pin = '';
    for (var controller in _controllers) {
      pin += controller.text;
    }

    setState(() {
      _isCompleted = pin.length == _codeLength;
    });

    if (_isCompleted) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarCustom(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Будь ласка, введіть 6-значний код, який відображається в додатку LinqoraHost',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Як це процює?',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_codeLength, (index) {
                    return _buildPinDigit(index);
                  }),
                ),
                const SizedBox(height: 40),
                _isCompleted
                    ? ElevatedButton(
                      onPressed: () {
                        String deviceCode = '';
                        for (var controller in _controllers) {
                          deviceCode += controller.text;
                        }
                        Get.toNamed(
                          AppRoutes.DEVICE_HOME,
                          arguments: {'deviceCode': deviceCode},
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Підключитися',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinDigit(int index) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < _codeLength - 1) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            }
          }
          _onPinChanged();
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
