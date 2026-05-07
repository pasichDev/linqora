import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:linqoraremote/data/models/script_item.dart';
import 'package:linqoraremote/presentation/controllers/script_controller.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/presentation/widgets/lx_header.dart';

class ScriptsView extends StatefulWidget {
  const ScriptsView({super.key});

  @override
  State<ScriptsView> createState() => _ScriptsViewState();
}

class _ScriptsViewState extends State<ScriptsView> {
  late final ScriptController _scriptController;

  @override
  void initState() {
    super.initState();
    _scriptController = Get.find<ScriptController>();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Obx(
          () => LxHeader(
            title: 'Scripts',
            eyebrow: '${_scriptController.scripts.length} saved',
            showBack: false,
            action: GestureDetector(
              onTap: () => _showScriptDialog(),
              child: LxGlass(
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: lxTextDim,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Script list + console
        Expanded(
          child: Obx(() {
            if (_scriptController.isLoadingScripts.value &&
                _scriptController.scripts.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: lxAccent,
                  strokeWidth: 2,
                ),
              );
            }

            if (_scriptController.filteredScripts.isEmpty) {
              return Center(
                child: Text(
                  'No scripts saved',
                  style: const TextStyle(color: lxTextFaint),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: lxHairline),
                      ),
                    ),
                    child: Column(
                      children: _scriptController.filteredScripts
                          .map((s) => _buildScriptRow(s))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildConsoleSection(),
                  const SizedBox(height: 100),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─── Script row ──────────────────────────────────────────────────────────

  Widget _buildScriptRow(ScriptItem script) {
    return Obx(() {
      final isRunning =
          _scriptController.executingScripts[script.id] ?? false;
      final result = _scriptController.lastExecutionResults[script.id];

      final Color dotColor;
      if (isRunning) {
        dotColor = lxAccent;
      } else if (result == null) {
        dotColor = lxTextFaint;
      } else {
        dotColor = result.exitCode == 0 ? lxGreen : lxRed;
      }

      final tag = _tagForScript(script.command);

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: lxHairline, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: [
                  BoxShadow(color: dotColor, blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Name + tag + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          script.name,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                            color: lxText,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: lxHairline),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            color: lxTextFaint,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isRunning
                        ? 'running…'
                        : (result != null
                            ? '${result.durationMs} ms'
                            : 'not run'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: lxTextFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Run / Stop button
            GestureDetector(
              onTap: isRunning
                  ? () => _scriptController.stopScript(script.id)
                  : () => _scriptController.executeScript(script.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isRunning
                      ? lxGlass2
                      : lxAccent.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isRunning
                        ? lxHairline
                        : lxAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isRunning ? 'STOP' : '▶ RUN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isRunning ? lxTextDim : lxAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── Console section ─────────────────────────────────────────────────────

  Widget _buildConsoleSection() {
    return Obx(() {
      final runningId = _scriptController.executingScripts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .firstOrNull;

      final activeId = runningId ??
          (_scriptController.lastExecutionResults.isNotEmpty
              ? _scriptController.lastExecutionResults.keys.last
              : null);

      final script = activeId != null
          ? _scriptController.scripts
              .firstWhereOrNull((s) => s.id == activeId)
          : null;

      final output =
          activeId != null ? (_scriptController.realTimeOutput[activeId] ?? '') : '';
      final isLive = runningId != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow row
          Row(
            children: [
              Text(
                'Console${script != null ? ' · ${script.name}' : ''}',
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: lxTextFaint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isLive)
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: lxAccent,
                        boxShadow: [
                          BoxShadow(color: lxAccent, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'live',
                      style: TextStyle(fontSize: 10, color: lxAccent),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Glass console surface
          LxGlass(
            child: SizedBox(
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Output
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: output.isEmpty
                            ? const Text(
                                r'$ ',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: lxAccent,
                                ),
                              )
                            : _renderConsoleOutput(output),
                      ),
                    ),

                    // Bottom gradient fade
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              lxSurface.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _renderConsoleOutput(String output) {
    final lines = output.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        Color c = lxTextDim;
        if (line.startsWith(r'$')) {
          c = lxAccent;
        } else if (line.contains('✓') || line.contains('ok')) {
          c = lxGreen;
        } else if (line.contains('⟳') || line.contains('...')) {
          c = lxAmber;
        } else if (line.contains('error') || line.contains('Error')) {
          c = lxRed;
        }
        return Text(
          line,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: c,
            height: 1.7,
          ),
        );
      }).toList(),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _tagForScript(String command) {
    final cmd = command.toLowerCase();
    if (cmd.contains('.py') || cmd.startsWith('python')) {
      return 'PY';
    }
    if (cmd.contains('.js') || cmd.startsWith('node')) {
      return 'JS';
    }
    if (cmd.contains('.sh') || cmd.startsWith('bash') || cmd.startsWith('./')) {
      return 'BASH';
    }
    return 'CMD';
  }

  // ─── Script dialog ────────────────────────────────────────────────────────

  void _showScriptDialog([ScriptItem? script]) {
    final idController = TextEditingController(text: script?.id ?? '');
    final nameController = TextEditingController(text: script?.name ?? '');
    final descController =
        TextEditingController(text: script?.description ?? '');
    final cmdController = TextEditingController(text: script?.command ?? '');
    final argsController = TextEditingController(
      text: script?.args.join(', ') ?? '',
    );

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: lxSurface,
            borderRadius: BorderRadius.circular(lxRadiusModal),
            border: Border.all(color: lxHairline),
            boxShadow: [
              BoxShadow(
                color: lxAccent.withValues(alpha: 0.08),
                blurRadius: 24,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  script == null ? 'add_script'.tr : 'edit_script'.tr,
                  style: const TextStyle(
                    color: lxText,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                      child: const Text(
                        'cancel',
                        style: TextStyle(color: lxTextDim),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        final newScript = ScriptItem(
                          id: idController.text,
                          name: nameController.text,
                          description: descController.text,
                          command: cmdController.text,
                          args: argsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                        );
                        if (script == null) {
                          _scriptController.addScript(newScript);
                        } else {
                          _scriptController.updateScript(newScript);
                        }
                        Get.back();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: lxAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(lxRadiusTile),
                          border: Border.all(
                            color: lxAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: lxAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
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

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(color: lxText, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: lxTextFaint),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: lxHairline),
          ),
          disabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: lxHairline),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: lxAccent),
          ),
        ),
      ),
    );
  }
}
