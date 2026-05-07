import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:linqoraremote/presentation/controllers/script_controller.dart';
import 'package:linqoraremote/presentation/widgets/loading_view.dart';
import '../../core/themes/theme.dart';
import '../controllers/device_home_controller.dart';

class ScriptsView extends StatefulWidget {
  const ScriptsView({super.key});

  @override
  State<ScriptsView> createState() => _ScriptsViewState();
}

class _ScriptsViewState extends State<ScriptsView> with SingleTickerProviderStateMixin {
  late final ScriptController _scriptController;
  late final DeviceHomeController _homeController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scriptController = Get.find<ScriptController>();
    _homeController = Get.find<DeviceHomeController>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showScriptDialog([ScriptItem? script]) {
    final idController = TextEditingController(text: script?.id ?? '');
    final nameController = TextEditingController(text: script?.name ?? '');
    final descController = TextEditingController(text: script?.description ?? '');
    final cmdController = TextEditingController(text: script?.command ?? '');
    final argsController = TextEditingController(text: script?.args.join(', ') ?? '');

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 20)],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  script == null ? 'add_script'.tr : 'edit_script'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildField('ID', idController, enabled: script == null),
                _buildField('script_name'.tr, nameController),
                _buildField('script_description'.tr, descController),
                _buildField('script_command'.tr, cmdController),
                _buildField('script_args'.tr, argsController),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('cancel'.tr, style: const TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final newScript = ScriptItem(
                          id: idController.text,
                          name: nameController.text,
                          description: descController.text,
                          command: cmdController.text,
                          args: argsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                        );
                        if (script == null) {
                          _scriptController.addScript(newScript);
                        } else {
                          _scriptController.updateScript(newScript);
                        }
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('save'.tr),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => _homeController.selectMenuItem(-1),
        ),
        title: Text(
          'scripts'.tr,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _scriptController.fetchScripts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScriptDialog(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ).animate().scale(delay: 500.ms),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => _scriptController.searchQuery.value = v,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'search_scripts'.tr,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_scriptController.isLoadingScripts.value && _scriptController.scripts.isEmpty) {
                return const LoadingView();
              }

              if (_scriptController.filteredScripts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'no_scripts_available'.tr,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                      ),
                    ],
                  ).animate().fadeIn(),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _scriptController.filteredScripts.length,
                itemBuilder: (context, index) {
                  final script = _scriptController.filteredScripts[index];
                  return _buildScriptCard(script, index);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptCard(ScriptItem script, int index) {
    return Obx(() {
      final isExecuting = _scriptController.executingScripts[script.id] ?? false;
      final lastResult = _scriptController.lastExecutionResults[script.id];
      final rtOutput = _scriptController.realTimeOutput[script.id] ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: ExpansionTile(
              leading: Icon(
                Icons.terminal,
                color: isExecuting ? Colors.orange : Colors.blueAccent,
              ).animate(target: isExecuting ? 1 : 0).shimmer(duration: 1.seconds),
              title: Text(
                script.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                script.description,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white38),
                    onPressed: () => _showScriptDialog(script),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    onPressed: () => Get.defaultDialog(
                      title: 'delete_script'.tr,
                      middleText: 'confirm_delete'.tr,
                      backgroundColor: Colors.grey[900],
                      titleStyle: const TextStyle(color: Colors.white),
                      middleTextStyle: const TextStyle(color: Colors.white70),
                      textCancel: 'cancel'.tr,
                      textConfirm: 'delete'.tr,
                      confirmTextColor: Colors.white,
                      onConfirm: () {
                        _scriptController.deleteScript(script.id);
                        Get.back();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  isExecuting
                      ? SizedBox(
                          width: 80,
                          child: ElevatedButton(
                            onPressed: () => _scriptController.stopScript(script.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              foregroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text('stop'.tr, style: const TextStyle(fontSize: 10)),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => _scriptController.executeScript(script.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text('execute'.tr, style: const TextStyle(fontSize: 10)),
                        ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(color: Colors.white10),
                      if (isExecuting || rtOutput.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('OUTPUT:', style: TextStyle(color: Colors.blueAccent.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                            if (isExecuting)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1, color: Colors.blueAccent),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          maxHeight: 200,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            reverse: true,
                            child: Text(
                              rtOutput.isEmpty ? 'Waiting for output...'.tr : rtOutput,
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ],
                      if (!isExecuting && lastResult != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${'exit_code'.tr}: ${lastResult.exitCode}',
                              style: TextStyle(
                                color: lastResult.exitCode == 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${lastResult.durationMs} ms',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1);
    });
  }
}
