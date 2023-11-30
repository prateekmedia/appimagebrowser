import 'dart:io';

import 'package:appimagepool/src/features/home/data/local_path_provider.dart';
import 'package:appimagepool/src/constants/constants.dart';
import 'package:appimagepool/src/utils/extensions/extensions.dart';
import 'package:appimagepool/src/utils/program_utils.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

final appimageToolsRepositoryProvider =
    Provider<AppimageToolsRepository>((ref) {
  return AppimageToolsRepository(ref.watch(localPathServiceProvider));
});

class AppimageToolsRepository {
  AppimageToolsRepository(this._localPathService);
  final LocalPathService _localPathService;

  Future<FileSystemEntity?> loadAppImage() async {
    // final file = await _localPathService.pickAppImage();
    // if (file != null) {
    //   return file;
    // }
    return 1 as dynamic;
  }

  Future<void> integrate(
    List<String> content,
    int index,
    FileSystemEntity file,
  ) async {
    String tempDir =
        "${(await getTemporaryDirectory()).path}/appimagepool_${p.basenameWithoutExtension(file.path)}";

    // Create Temporary Directory
    Directory dir = Directory(tempDir);
    await dir.create();

    // Create AppImage executable first
    ProgramUtils.makeProgramExecutable(
      location: p.dirname(file.path),
      program: p.basename(file.path),
    );

    //Extract AppImage's Content
    await Process.run(
      file.path,
      ["--appimage-extract"],
      workingDirectory: tempDir,
    );

    final checksum = (await Process.run(
      'md5sum',
      [file.path],
    ))
        .stdout
        .toString()
        .split(' ')[0]
        .trim();

    var newPath =
        '${p.withoutExtension(file.path)}_$checksum${p.extension(file.path)}';
    file.moveFile(newPath);

    String squashDir = "$tempDir/squashfs-root";

    String desktopfilename =
        'aip_${p.basenameWithoutExtension(newPath)}.desktop';

    String? iconName;

    // Copy desktop file
    try {
      var desktopFile = Directory(squashDir)
          .listSync()
          .firstWhere((element) => p.extension(element.path) == ".desktop");
      await desktopFile.moveResolvedFile(
          _localPathService.applicationsDir + desktopfilename);
      String execPath = (await Process.run(
        "grep",
        [
          "^Exec=",
          desktopfilename,
        ],
        runInShell: true,
        workingDirectory: _localPathService.applicationsDir,
      ))
          .stdout
          .split("=")[1]
          .split(' ')[0]
          .trim();

      iconName = (await Process.run(
        "grep",
        [
          "^Icon=",
          desktopfilename,
        ],
        runInShell: true,
        workingDirectory: _localPathService.applicationsDir,
      ))
          .stdout
          .split("=")[1]
          .trim();

      // Update desktop file
      await Process.run(
        "sed",
        [
          "s:Exec=$execPath:Exec=$newPath:g",
          desktopfilename,
          "-i",
        ],
        workingDirectory: _localPathService.applicationsDir,
      );

      await Process.run(
        "sed",
        [
          "s:Icon=$iconName:Icon=aip_${iconName}_$checksum:",
          "-i",
          desktopfilename,
        ],
        workingDirectory: _localPathService.applicationsDir,
      );
    } catch (e) {
      debugPrint("$e");
    }

    // Copy Icons
    var iconsDir = Directory("$squashDir/usr/share/icons");

    if (iconsDir.existsSync()) {
      for (FileSystemEntity icon in iconsDir.listSync(recursive: true)) {
        if (icon is File) {
          icon.moveFile(
              '${p.dirname(icon.path)}/aip_${p.basenameWithoutExtension(icon.path)}_$checksum${p.extension(icon.path)}');
        }
      }

      (await Process.run(
        "cp",
        ["-r", "./usr/share/icons", localShareDir],
        workingDirectory: squashDir,
      ));
    } else if (iconName != null) {
      // No icons in {squashDir}/usr/share/icons, search in top-level folder
      try {
        var icon = Directory(squashDir).listSync().firstWhere((element) =>
            p.basenameWithoutExtension(element.path) == iconName &&
            ['.png', '.svg'].contains(p.extension(element.path)));

        if (icon is File) {
          if (!icon.resolveSymbolicLinksSync().startsWith("$squashDir/")) {
            throw const FileSystemException(
                'Symlink for icon points out of the AppDir boundary');
          }

          String sizeName;
          String iconExt = p.extension(icon.path);
          if (iconExt == '.png') {
            var iconData = await decodeImageFromList(icon.readAsBytesSync());
            int iconSize = iconData.height;
            sizeName = "${iconSize}x$iconSize";
          } else {
            sizeName = "scalable";
          }

          var iconFilename = "aip_${iconName}_$checksum$iconExt";
          icon.moveResolvedFile(
              "$localShareDir/icons/hicolor/$sizeName/apps/$iconFilename");
        }
      } catch (e) {
        debugPrint("$e");
      }
    }

    Directory(tempDir).delete(recursive: true);
  }

  Future<void> remove(
    List<String> content,
    int index,
    FileSystemEntity file,
  ) async {
    // Delete Icons
    String? iconName;
    try {
      iconName = (await Process.run(
        "grep",
        [
          "^Icon=",
          "${_localPathService.applicationsDir}${content[index]}.desktop",
        ],
        runInShell: true,
        workingDirectory: _localPathService.applicationsDir,
      ))
          .stdout
          .split("=")[1]
          .trim();
    } on RangeError catch (_) {}

    for (var icon
        in Directory(_localPathService.iconsDir).listSync(recursive: true)) {
      if (p.basenameWithoutExtension(icon.path) == iconName) {
        await icon.delete();
      }
    }

    // Delete Desktop file
    await File("${_localPathService.applicationsDir}${content[index]}.desktop")
        .delete();

    // Remove checksum from app name
    final basenl = p.basenameWithoutExtension(file.path).split('_');
    file.moveFile(
      '${p.dirname(file.path)}/${basenl.sublist(0, basenl.length - 1).join('_')}${p.extension(
        file.path,
      )}',
    );
  }

  Future<void> integrateOrRemove({
    required List<String> content,
    required int index,
    required FileSystemEntity file,
    bool isIntegrated = true,
  }) async {
    if (isIntegrated) {
      await remove(content, index, file);
    } else {
      await integrate(content, index, file);
    }
  }

  Future<void> removeItem({
    required bool isIntegrated,
    required List<String> content,
    required int index,
    required FileSystemEntity file,
  }) async {
    if (isIntegrated) {
      return await remove(content, index, file);
    }
    await File(file.path).delete();
  }
}
