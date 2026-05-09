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

class _ScriptsViewState extends State<ScriptsView>
    with SingleTickerProviderStateMixin {
  late final ScriptController _scriptController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _scriptController = Get.find<ScriptController>();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with tab bar as action
        Obx(
          () => LxHeader(
            title: 'Scripts',
            eyebrow: '${_scriptController.scripts.length} saved',
            showBack: false,
            action: _tabController.index == 0
                ? GestureDetector(
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
                  )
                : GestureDetector(
                    onTap: _scriptController.clearTerminal,
                    child: LxGlass(
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Icon(
                            Icons.delete_sweep_rounded,
                            size: 14,
                            color: lxTextDim,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),

        // Tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TabBar(
            controller: _tabController,
            indicatorColor: lxAccent,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: lxAccent,
            unselectedLabelColor: lxTextDim,
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
            dividerColor: lxHairline,
            tabs: const [
              Tab(text: 'SCRIPTS'),
              Tab(text: 'TERMINAL'),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ScriptsTab(ctrl: _scriptController, onAdd: _showScriptDialog),
              _TerminalTab(ctrl: _scriptController),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Delete confirmation ──────────────────────────────────────────────────

  void _confirmDelete(ScriptItem script) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: lxSurface,
            borderRadius: BorderRadius.circular(lxRadiusModal),
            border: Border.all(color: lxHairline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delete script?',
                style: TextStyle(
                    color: lxText, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '"${script.name}" will be permanently removed from the host.',
                style: const TextStyle(
                    color: lxTextDim, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child:
                        const Text('Cancel', style: TextStyle(color: lxTextDim)),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      _scriptController.deleteScript(script.id);
                      Get.back();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: lxRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(lxRadiusTile),
                        border:
                            Border.all(color: lxRed.withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                            color: lxRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Script dialog ────────────────────────────────────────────────────────

  void _showScriptDialog([ScriptItem? script]) {
    final idController = TextEditingController(text: script?.id ?? '');
    final nameController = TextEditingController(text: script?.name ?? '');
    final descController =
        TextEditingController(text: script?.description ?? '');
    final cmdController = TextEditingController(text: script?.command ?? '');
    final argsController =
        TextEditingController(text: script?.args.join(', ') ?? '');
    final schedController =
        TextEditingController(text: script?.schedule ?? '');

    const quickSchedules = [
      '@daily',
      '@hourly',
      '@every 30m',
      '@every 1h',
      '09:00'
    ];

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
                  color: lxAccent.withValues(alpha: 0.08), blurRadius: 24),
            ],
          ),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (_, setState) => Column(
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
                  // ── Schedule ───────────────────────────────────────────
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: lxAmber),
                    const SizedBox(width: 6),
                    const Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 12,
                        color: lxAmber,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '(optional)',
                      style: TextStyle(fontSize: 11, color: lxTextFaint),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Quick-pick chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickSchedules.map((q) {
                      final active = schedController.text == q;
                      return GestureDetector(
                        onTap: () => setState(() {
                          schedController.text = active ? '' : q;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? lxAmber.withValues(alpha: 0.15)
                                : Colors.transparent,
                            border: Border.all(
                              color: active
                                  ? lxAmber.withValues(alpha: 0.5)
                                  : lxHairline,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            q,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: active ? lxAmber : lxTextFaint,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // Custom schedule text field
                  _buildField(
                    'or enter custom (@every 2h, 14:30…)',
                    schedController,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('cancel',
                            style: TextStyle(color: lxTextDim)),
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
                            schedule: schedController.text.trim().isEmpty
                                ? null
                                : schedController.text.trim(),
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
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: lxAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(lxRadiusTile),
                            border: Border.all(
                                color: lxAccent.withValues(alpha: 0.35)),
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

// ─── Scripts tab ─────────────────────────────────────────────────────────────

class _ScriptsTab extends StatelessWidget {
  final ScriptController ctrl;
  final VoidCallback onAdd;

  const _ScriptsTab({required this.ctrl, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoadingScripts.value && ctrl.scripts.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: lxAccent, strokeWidth: 2),
        );
      }

      if (ctrl.filteredScripts.isEmpty) {
        return const Center(
          child: Text(
            'No scripts saved',
            style: TextStyle(color: lxTextFaint),
          ),
        );
      }

      // Delegate row building back to parent state via the controller
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: lxHairline)),
              ),
              child: Column(
                children: ctrl.filteredScripts
                    .map((s) => _ScriptRow(ctrl: ctrl, script: s))
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            _ConsoleSection(ctrl: ctrl),
            const SizedBox(height: 100),
          ],
        ),
      );
    });
  }
}

// ─── Script row ──────────────────────────────────────────────────────────────

class _ScriptRow extends StatelessWidget {
  final ScriptController ctrl;
  final ScriptItem script;

  const _ScriptRow({required this.ctrl, required this.script});

  String _tagForScript(String command) {
    final cmd = command.toLowerCase();
    if (cmd.contains('.py') || cmd.startsWith('python')) return 'PY';
    if (cmd.contains('.js') || cmd.startsWith('node')) return 'JS';
    if (cmd.contains('.sh') || cmd.startsWith('bash') || cmd.startsWith('./')) {
      return 'BASH';
    }
    return 'CMD';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isRunning = ctrl.executingScripts[script.id] ?? false;
      final result = ctrl.lastExecutionResults[script.id];

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
          border: Border(bottom: BorderSide(color: lxHairline, width: 1)),
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
                boxShadow: [BoxShadow(color: dotColor, blurRadius: 4)],
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
                            horizontal: 5, vertical: 1),
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
                  Row(
                    children: [
                      Text(
                        isRunning
                            ? 'running…'
                            : (result != null
                                ? '${result.durationMs} ms'
                                : 'not run'),
                        style: const TextStyle(
                            fontSize: 10.5, color: lxTextFaint),
                      ),
                      if (script.schedule != null &&
                          script.schedule!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: lxAmber.withValues(alpha: 0.1),
                            border: Border.all(
                                color: lxAmber.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 8, color: lxAmber),
                              const SizedBox(width: 3),
                              Text(
                                script.schedule!,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: lxAmber,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Run / Stop button
            GestureDetector(
              onTap: isRunning
                  ? () => ctrl.stopScript(script.id)
                  : () => ctrl.executeScript(script.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(width: 4),
            if (!script.id.startsWith('demo-'))
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 14, color: lxTextFaint),
                color: lxSurface,
                padding: EdgeInsets.zero,
                onSelected: (action) {
                  if (action == 'edit') {
                    // Find the parent _ScriptsViewState to call dialog
                    final state = context
                        .findAncestorStateOfType<_ScriptsViewState>();
                    if (action == 'edit') state?._showScriptDialog(script);
                    if (action == 'delete') state?._confirmDelete(script);
                  }
                  if (action == 'delete') {
                    final state = context
                        .findAncestorStateOfType<_ScriptsViewState>();
                    state?._confirmDelete(script);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: const [
                      Icon(Icons.edit_outlined, size: 14, color: lxTextDim),
                      SizedBox(width: 8),
                      Text('Edit',
                          style: TextStyle(color: lxText, fontSize: 13)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: const [
                      Icon(Icons.delete_outline, size: 14, color: lxRed),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: lxRed, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
          ],
        ),
      );
    });
  }
}

// ─── Console section (scripts tab) ───────────────────────────────────────────

class _ConsoleSection extends StatelessWidget {
  final ScriptController ctrl;

  const _ConsoleSection({required this.ctrl});

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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final runningId = ctrl.executingScripts.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .firstOrNull;

      final activeId = runningId ??
          (ctrl.lastExecutionResults.isNotEmpty
              ? ctrl.lastExecutionResults.keys.last
              : null);

      final script = activeId != null
          ? ctrl.scripts.firstWhereOrNull((s) => s.id == activeId)
          : null;

      final output =
          activeId != null ? (ctrl.realTimeOutput[activeId] ?? '') : '';
      final isLive = runningId != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        boxShadow: [BoxShadow(color: lxAccent, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('live',
                        style: TextStyle(fontSize: 10, color: lxAccent)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          LxGlass(
            child: SizedBox(
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
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
}

// ─── Terminal tab ─────────────────────────────────────────────────────────────

class _TerminalTab extends StatefulWidget {
  final ScriptController ctrl;

  const _TerminalTab({required this.ctrl});

  @override
  State<_TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<_TerminalTab> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final cmd = _inputCtrl.text.trim();
    if (cmd.isEmpty) return;
    _inputCtrl.clear();
    widget.ctrl.runShellCommand(cmd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _lineColor(String line) {
    if (line.startsWith('>')) return lxAccent;
    if (line.startsWith('[error')) return lxRed;
    if (line.startsWith('[exit')) return lxTextDim;
    return lxText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Output area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: LxGlass(
              borderRadius: BorderRadius.circular(lxRadiusCard),
              padding: const EdgeInsets.all(12),
              child: Obx(
                () => widget.ctrl.terminalOutput.isEmpty
                    ? const Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          r'$ ready',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: lxAccent,
                            height: 1.5,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: widget.ctrl.terminalOutput.length,
                        itemBuilder: (_, i) {
                          final line = widget.ctrl.terminalOutput[i];
                          return Text(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: _lineColor(line),
                              height: 1.5,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),

        // Input bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          child: LxGlass(
            borderRadius: BorderRadius.circular(lxRadiusCard),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Text(
                  '\$',
                  style: TextStyle(
                    color: lxAccent,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(
                      color: lxText,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter command…',
                      hintStyle: TextStyle(color: lxTextGhost),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                Obx(() => widget.ctrl.terminalRunning.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: lxAccent,
                        ),
                      )
                    : GestureDetector(
                        onTap: _submit,
                        child: const Icon(
                          Icons.send_rounded,
                          size: 16,
                          color: lxAccent,
                        ),
                      )),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
