import 'package:get/get.dart';
import 'package:linqoraremote/data/enums/type_request_host.dart';
import 'package:linqoraremote/data/models/script_item.dart';
import 'package:linqoraremote/data/models/script_execute_response.dart';
import 'package:linqoraremote/data/models/server_response.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/controllers/device_home_controller.dart';
import '../../core/utils/app_logger.dart';

class ScriptController extends GetxController {
  final WebSocketProvider webSocketProvider;

  ScriptController({required this.webSocketProvider});

  final RxList<ScriptItem> scripts = <ScriptItem>[].obs;
  final RxList<ScriptItem> demoScripts = <ScriptItem>[].obs;
  final RxList<ScriptItem> filteredScripts = <ScriptItem>[].obs;
  final RxMap<String, bool> executingScripts = <String, bool>{}.obs;
  final RxMap<String, ScriptExecuteResponse> lastExecutionResults =
      <String, ScriptExecuteResponse>{}.obs;
  final RxMap<String, String> realTimeOutput = <String, String>{}.obs;
  final RxBool isLoadingScripts = false.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _setupWebSocketHandlers();

    // Auto-filter scripts when list or query changes
    everAll([scripts, demoScripts, searchQuery], (_) => _filterScripts());

    fetchScripts();
  }

  // ─── Terminal state ───────────────────────────────────────────────────────
  final terminalOutput = <String>[].obs;
  final terminalRunning = false.obs;

  void runShellCommand(String cmd) {
    if (cmd.trim().isEmpty || !webSocketProvider.isConnected) return;
    terminalRunning.value = true;
    terminalOutput.add('> $cmd');
    webSocketProvider.registerHandler('shell_exec', _onShellResult);
    webSocketProvider.sendMessage(
      WsMessage(type: 'shell_exec')..setField('data', {'command': cmd}),
    );
  }

  void _onShellResult(Map<String, dynamic> data) {
    terminalRunning.value = false;
    webSocketProvider.removeHandler('shell_exec');
    if (data['status'] == 'error') {
      terminalOutput.add('[error] ${data['message'] ?? 'unknown'}');
      return;
    }
    final out = (data['data']?['output'] as String? ?? '').trimRight();
    final code = data['data']?['exit_code'] as int? ?? 0;
    if (out.isNotEmpty) terminalOutput.addAll(out.split('\n'));
    terminalOutput.add('[exit $code]');
    if (terminalOutput.length > 500) {
      terminalOutput.removeRange(0, terminalOutput.length - 500);
    }
  }

  void clearTerminal() => terminalOutput.clear();

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.script_list.value);
    webSocketProvider.removeHandler(TypeMessageWs.script_execute.value);
    webSocketProvider.removeHandler(TypeMessageWs.script_add.value);
    webSocketProvider.removeHandler(TypeMessageWs.script_update.value);
    webSocketProvider.removeHandler(TypeMessageWs.script_delete.value);
    webSocketProvider.removeHandler(TypeMessageWs.script_stop.value);
    webSocketProvider.removeHandler(TypeMessageWs.script_output.value);
    webSocketProvider.removeHandler('shell_exec');
    super.onClose();
  }

  void _setupWebSocketHandlers() {
    webSocketProvider.registerHandler(
      TypeMessageWs.script_list.value,
      _handleScriptList,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.script_execute.value,
      _handleScriptExecute,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.script_add.value,
      _handleScriptCU,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.script_update.value,
      _handleScriptCU,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.script_delete.value,
      _handleScriptDelete,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.script_stop.value,
      (data) => AppLogger.debug("Script stopped: $data"),
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.script_output.value,
      _handleScriptOutput,
    );
  }

  void _filterScripts() {
    final allScripts = [...scripts, ...demoScripts];
    if (searchQuery.isEmpty) {
      filteredScripts.assignAll(allScripts);
    } else {
      final query = searchQuery.value.toLowerCase();
      filteredScripts.assignAll(
        allScripts.where(
          (s) =>
              s.name.toLowerCase().contains(query) ||
              s.description.toLowerCase().contains(query) ||
              s.id.toLowerCase().contains(query),
        ),
      );
    }
  }

  void fetchScripts() {
    if (!webSocketProvider.isConnected) return;
    isLoadingScripts.value = true;
    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.script_list.value),
      );
    } catch (e) {
      isLoadingScripts.value = false;
      AppLogger.release(
        'Error fetching scripts: $e',
        module: "ScriptController",
      );
    }
  }

  void addScript(ScriptItem script) {
    if (!webSocketProvider.isConnected) return;
    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.script_add.value)
          ..setField('data', script.toJson()),
      );
    } catch (e) {
      AppLogger.release('Error adding script: $e', module: "ScriptController");
    }
  }

  void updateScript(ScriptItem script) {
    if (!webSocketProvider.isConnected) return;
    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.script_update.value)
          ..setField('data', script.toJson()),
      );
    } catch (e) {
      AppLogger.release(
        'Error updating script: $e',
        module: "ScriptController",
      );
    }
  }

  void deleteScript(String scriptId) {
    if (!webSocketProvider.isConnected) return;
    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.script_delete.value)
          ..setField('data', {'id': scriptId}),
      );
    } catch (e) {
      AppLogger.release(
        'Error deleting script: $e',
        module: "ScriptController",
      );
    }
  }

  void executeScript(String scriptId) {
    if (!webSocketProvider.isConnected) return;
    executingScripts[scriptId] = true;
    realTimeOutput[scriptId] = ''; // Reset output for new run
    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.script_execute.value)
          ..setField('data', {'id': scriptId}),
      );
    } catch (e) {
      executingScripts[scriptId] = false;
      AppLogger.release(
        'Error executing script $scriptId: $e',
        module: "ScriptController",
      );
    }
  }

  void stopScript(String scriptId) {
    if (!webSocketProvider.isConnected) return;
    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.script_stop.value)
          ..setField('data', {'id': scriptId}),
      );
    } catch (e) {
      AppLogger.release(
        'Error stopping script $scriptId: $e',
        module: "ScriptController",
      );
    }
  }

  // Handlers

  void _handleScriptList(Map<String, dynamic> data) {
    isLoadingScripts.value = false;
    try {
      final response = ServerResponse<List<ScriptItem>>.fromJson(
        data,
        (json) => (json['scripts'] as List)
            .map((e) => ScriptItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

      if (!response.hasError && response.data != null) {
        scripts.assignAll(response.data!);
        _checkAndAddDemoScripts();
      }
    } catch (e) {
      AppLogger.release(
        'Error processing script list: $e',
        module: "ScriptController",
      );
    }
  }

  void _handleScriptCU(Map<String, dynamic> data) {
    // Re-fetch after add/update
    fetchScripts();
  }

  void _handleScriptDelete(Map<String, dynamic> data) {
    fetchScripts();
  }

  void _handleScriptOutput(Map<String, dynamic> data) {
    try {
      final output = data['data'];
      if (output != null) {
        final String id = output['id'];
        final String text = output['text'];
        final String current = realTimeOutput[id] ?? '';
        realTimeOutput[id] = current + text + '\n';
      }
    } catch (e) {
      AppLogger.debug("Error parsing script output: $e");
    }
  }

  void _handleScriptExecute(Map<String, dynamic> data) {
    try {
      final response = ServerResponse<ScriptExecuteResponse>.fromJson(
        data,
        (json) => ScriptExecuteResponse.fromJson(json),
      );

      if (!response.hasError && response.data != null) {
        final result = response.data!;
        executingScripts[result.id] = false;
        lastExecutionResults[result.id] = result;

        // Show notification if it failed in background (e.g. exit code != 0)
        if (result.exitCode != 0) {
          Get.snackbar(
            'Script Failed'.tr,
            'Script "${result.id}" exited with code ${result.exitCode}'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.errorContainer,
            colorText: Get.theme.colorScheme.onErrorContainer,
          );
        }
      } else {
        final scriptId = data['data']?['id'] as String?;
        if (scriptId != null) {
          executingScripts[scriptId] = false;
        } else {
          executingScripts.clear();
        }
      }
    } catch (e) {
      AppLogger.release(
        'Error processing script execution result: $e',
        module: "ScriptController",
      );
      executingScripts.clear();
    }
  }

  void _checkAndAddDemoScripts() {
    try {
      final deviceHome = Get.find<DeviceHomeController>();
      final os = deviceHome.hostInfo.value?.os.toLowerCase() ?? '';

      if (os.contains('windows')) {
        demoScripts.assignAll([
          ScriptItem(
            id: 'demo-win-sysinfo',
            name: 'Windows: System Info',
            description: 'Display detailed Windows system information',
            command: 'powershell.exe',
            args: ['-Command', 'Get-ComputerInfo | Select-Object CsName, OsArchitecture, WindowsVersion | Format-List'],
          ),
          ScriptItem(
            id: 'demo-win-procs',
            name: 'Windows: Top Processes',
            description: 'Show top 5 CPU consuming processes',
            command: 'powershell.exe',
            args: ['-Command', 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | Format-Table'],
          ),
        ]);
      } else if (os.contains('linux') || os.contains('darwin')) {
        demoScripts.assignAll([
          ScriptItem(
            id: 'demo-nix-sysinfo',
            name: 'Unix: System Health',
            description: 'Display system uptime and load average',
            command: 'uptime',
          ),
          ScriptItem(
            id: 'demo-nix-disk',
            name: 'Unix: Disk Space',
            description: 'Show formatted disk space usage',
            command: 'df',
            args: ['-h'],
          ),
        ]);
      }
    } catch (e) {
      AppLogger.debug("Error adding demo scripts: $e");
    }
  }
}
