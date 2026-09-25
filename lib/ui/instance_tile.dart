import 'package:flutter/material.dart';

import '../src/models.dart';
import 'theme.dart';

class InstanceTile extends StatelessWidget {
  const InstanceTile({
    super.key,
    required this.instance,
    required this.running,
    required this.onLaunch,
    required this.onStop,
    required this.onDelete,
  });

  final AppInstance instance;
  final bool running;
  final VoidCallback onLaunch;
  final VoidCallback onStop;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.circle,
            size: 12, color: running ? erAccent : const Color(0xFF4A5560)),
        title: Text(instance.name),
        subtitle: Text(
          [
            if (instance.temporary) 'temporary',
            if (instance.isolateHome) 'isolated home' else 'shared home',
            if (instance.privateBus) 'private bus' else 'shared bus',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: running ? 'Stop' : 'Launch',
              icon: Icon(running ? Icons.stop : Icons.play_arrow,
                  color: running ? Colors.redAccent : erAccent),
              onPressed: running ? onStop : onLaunch,
            ),
            IconButton(
              tooltip: 'Delete instance and its data',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
