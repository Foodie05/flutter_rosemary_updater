import 'package:flutter/material.dart';
import 'package:rosemary_updater/rosemary_updater.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final RosemaryUpdater updater;
  String status = 'Idle';
  int progress = 0;
  UpdateReceive? updateInfo;

  @override
  void initState() {
    super.initState();
    final config = UpdaterConfig(
      apiBaseUrl: 'https://your-rosemary-backend.com',
      appName: 'YourAppName',
      appPasswd: 'your_app_password',
      betaPasswd: '',
      appVersion: 1,
      resVersion: 1,
    );
    updater = RosemaryUpdater(config);
  }

  Future<void> _check() async {
    setState(() {
      status = 'Checking updates...';
      progress = 0;
    });
    final info = await updater.checkUpdate();
    setState(() {
      updateInfo = info;
      status = info == null
          ? 'No updates'
          : 'Update found: app=${info.appUpgrade}, res=${info.resUpgrade}';
    });
  }

  Future<void> _update() async {
    final info = updateInfo;
    if (info == null) {
      setState(() => status = 'No update info, please check first');
      return;
    }
    await updater.runUpdate(
      updateInfo: info,
      onStatusChanged: (s) {
        setState(() {
          progress = s.progress;
          if (s.error != null) {
            status = 'Error: ${s.error}';
          } else if (s.installing) {
            status = 'Installing... ${s.message}';
          } else if (s.downloading) {
            status = 'Downloading...';
          } else if (s.success) {
            status = 'Success';
          } else {
            status = s.message;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('rosemary_updater example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $status'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress / 100),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _check,
                    child: const Text('Check Update'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _update,
                    child: const Text('Run Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
