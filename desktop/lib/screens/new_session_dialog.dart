import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/app_provider.dart';

class NewSessionDialog extends StatefulWidget {
  const NewSessionDialog({super.key});

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  final _dirController = TextEditingController();
  final _commandController = TextEditingController(text: 'claude');
  bool _openAfterCreate = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _dirController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建 Claude 会话'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Working directory
            const Text('工作目录'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dirController,
                    decoration: const InputDecoration(
                      hintText: '选择工作目录',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectDirectory,
                  child: const Text('浏览'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Command
            const Text('启动命令 (可选)'),
            const SizedBox(height: 8),
            TextField(
              controller: _commandController,
              decoration: const InputDecoration(
                hintText: 'claude',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // Open after create
            CheckboxListTile(
              value: _openAfterCreate,
              onChanged: (value) {
                setState(() {
                  _openAfterCreate = value ?? false;
                });
              },
              title: const Text('创建后自动在终端中打开'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createSession,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('创建'),
        ),
      ],
    );
  }

  Future<void> _selectDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _dirController.text = result;
      });
    }
  }

  Future<void> _createSession() async {
    if (_dirController.text.isEmpty) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final provider = context.read<AppProvider>();
    final sessionName = await provider.createSession(
      _dirController.text,
      command: _commandController.text.isNotEmpty
          ? _commandController.text
          : 'claude',
    );

    if (sessionName != null && _openAfterCreate) {
      await provider.attachSession(sessionName);
    }

    if (mounted) {
      Navigator.pop(context, sessionName != null);
    }
  }
}
