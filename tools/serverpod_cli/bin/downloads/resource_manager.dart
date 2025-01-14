import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../generated/version.dart';
import '../shared/environment.dart';

final resourceManager = ResourceManager();

class ResourceManager {
  Directory get homeDirectory {
    var envVars = Platform.environment;

    if (Platform.isMacOS) {
      return Directory(envVars['HOME']!);
    } else if (Platform.isLinux) {
      return Directory(envVars['HOME']!);
    } else if (Platform.isWindows) {
      return Directory(envVars['UserProfile']!);
    }

    throw (Exception('Unsupported platform.'));
  }

  Directory get localCacheDirectory =>
      Directory(homeDirectory.path + '/.serverpod');
  Directory get versionedDir =>
      Directory(localCacheDirectory.path + '/$templateVersion');
  Directory get templateDirectory {
    if (productionMode) {
      return Directory(versionedDir.path + '/serverpod_template');
    } else {
      return Directory(serverpodHome + '/templates/serverpod_templates');
    }
  }

  String get uniqueUserId {
    const uuidFilePath = '/uuid';
    try {
      var userIdFile = File(localCacheDirectory.path + uuidFilePath);
      var userId = userIdFile.readAsStringSync();
      return userId;
    } catch (e) {
      // Failed to read userId from file, it's probably not created.
    }
    var userId = const Uuid().v4();
    try {
      var userIdFile = File(localCacheDirectory.path + uuidFilePath);
      userIdFile.writeAsStringSync(userId);
    } finally {}

    return userId;
  }

  String get packageDownloadUrl =>
      'https://storage.googleapis.com/pub-packages/packages/serverpod_templates-$templateVersion.tar.gz';

  bool get isTemplatesInstalled {
    if (!versionedDir.existsSync()) return false;

    return templateDirectory.existsSync();
  }

  Future<void> installTemplates() async {
    print('Downloading templates for version $templateVersion');
    if (!versionedDir.existsSync()) versionedDir.createSync(recursive: true);

    var response = await http.get(Uri.parse(packageDownloadUrl));
    var data = response.bodyBytes;

    // var outFile = File(versionedDir.path + '/serverpod_templates.tar.gz');
    // outFile.writeAsBytesSync(data);

    var unzipped = GZipDecoder().decodeBytes(data);
    var archive = TarDecoder().decodeBytes(unzipped);

    for (var file in archive) {
      var outFileName = '${templateDirectory.path}/${file.name}';
      if (file.isFile) {
        var outFile = File(outFileName);
        outFile = await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content);
      } else {
        await Directory(outFileName).create(recursive: true);
      }
    }
    print('Download complete.\n');
  }
}
