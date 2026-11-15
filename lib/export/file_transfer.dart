import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup.dart';
import 'csv.dart';

/// Backups are small; anything bigger is not one of ours.
const maxBackupBytes = 20 * 1024 * 1024;

/// Hands files to the system share sheet and reads a backup the person picks.
/// Behind an interface so the screens can be tested without a phone.
abstract class FileTransfer {
  Future<void> share(List<ExportFile> files);

  /// The text of the file the person picked, or null if they cancelled.
  /// Throws [BackupException] when the file cannot be a backup.
  Future<String?> pickBackup();
}

class SystemFileTransfer implements FileTransfer {
  const SystemFileTransfer();

  @override
  Future<void> share(List<ExportFile> files) async {
    final dir = await getTemporaryDirectory();
    final paths = <XFile>[];
    for (final f in files) {
      final file = File('${dir.path}${Platform.pathSeparator}${f.name}');
      await file.writeAsString(f.contents, encoding: utf8);
      paths.add(XFile(file.path));
    }
    await SharePlus.instance.share(ShareParams(files: paths));
  }

  @override
  Future<String?> pickBackup() async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return null;
    const tooBig = BackupException(
      'That file is too big to be a Garden backup.',
    );
    final size = await picked.length();
    if (size != null && size > maxBackupBytes) throw tooBig;
    final bytes = await picked.readAsBytes();
    if (bytes.length > maxBackupBytes) throw tooBig;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const BackupException('That file is not a Garden backup.');
    }
  }
}

final fileTransferProvider = Provider<FileTransfer>(
  (ref) => const SystemFileTransfer(),
);
