import 'package:flutter/material.dart';

import '../src/models.dart';

class NewInstanceSheet extends StatefulWidget {
  const NewInstanceSheet({super.key, required this.existingNames});

  final Set<String> existingNames;

  @override
  State<NewInstanceSheet> createState() => _NewInstanceSheetState();
}

class _NewInstanceSheetState extends State<NewInstanceSheet> {
  final _name = TextEditingController();
  bool _privateBus = true;
  bool _isolateHome = true;

  String? get _error {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Name required';
    if (widget.existingNames.contains(name)) return 'Name already used';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New instance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Instance name',
              hintText: 'alt, account2, test…',
              errorText: _name.text.isEmpty ? null : _error,
            ),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            title: const Text('Isolated home'),
            subtitle: const Text('Separate config, data and saves'),
            value: _isolateHome,
            onChanged: (v) => setState(() => _isolateHome = v),
          ),
          SwitchListTile(
            title: const Text('Private D-Bus session'),
            subtitle: const Text('Bypasses single-instance detection'),
            value: _privateBus,
            onChanged: (v) => setState(() => _privateBus = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _error == null
              ? () => Navigator.pop(context, (
                    name: _name.text.trim(),
                    privateBus: _privateBus,
                    isolateHome: _isolateHome,
                  ))
              : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

Future<AppInstance?> showNewInstanceSheet(
  BuildContext context,
  String appId,
  Set<String> existingNames,
  String Function(String name) homeFor,
) async {
  final result = await showDialog<({String name, bool privateBus, bool isolateHome})>(
    context: context,
    builder: (_) => NewInstanceSheet(existingNames: existingNames),
  );
  if (result == null) return null;
  return AppInstance(
    appId: appId,
    name: result.name,
    home: homeFor(result.name),
    privateBus: result.privateBus,
    isolateHome: result.isolateHome,
  );
}
