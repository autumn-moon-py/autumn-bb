import 'dart:io';

String _repoDir() {
  final scriptFile = File(Platform.script.toFilePath());
  return scriptFile.parent.path;
}

/// 执行 git 命令。返回 exitCode；非零时已打印错误。
int runGit(String cmd, List<String> args) {
  final result = Process.runSync(
    'git',
    [cmd, ...args],
    workingDirectory: _repoDir(),
  );
  final stdoutStr = result.stdout.toString();
  final stderrStr = result.stderr.toString();
  if (stdoutStr.isNotEmpty) {
    // ignore: avoid_print
    print(stdoutStr);
  }
  if (result.exitCode != 0) {
    // ignore: avoid_print
    print('[错误] git $cmd 失败 (exit ${result.exitCode})');
    if (stderrStr.isNotEmpty) {
      // ignore: avoid_print
      print(stderrStr);
    }
    return result.exitCode;
  }
  return 0;
}

String _formatNow() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)} '
         '${two(now.hour)}:${two(now.minute)}';
}

/// 在 stash 列表输出中查找包含 `auto-stash` 的最新一条，返回形如 `stash@{0}` 的引用。
/// 找不到返回 null。
String? _findAutoStashRef() {
  final result = Process.runSync(
    'git',
    ['stash', 'list'],
    workingDirectory: _repoDir(),
  );
  if (result.exitCode != 0) return null;
  final lines = result.stdout.toString().split('\n');
  for (final line in lines) {
    if (line.contains('auto-stash')) {
      // 解析 "stash@{0}: On master: auto-stash" -> "stash@{0}"
      final match = RegExp(r'stash@\{\d+\}').firstMatch(line);
      if (match != null) return match.group(0);
    }
  }
  return null;
}

void actionRebasePull() {
  // 1. 检查是否有本地修改（status --porcelain 非空）
  final statusResult = Process.runSync(
    'git',
    ['status', '--porcelain'],
    workingDirectory: _repoDir(),
  );
  if (statusResult.exitCode != 0) {
    // ignore: avoid_print
    print('[错误] git status 失败');
    if (statusResult.stderr.toString().isNotEmpty) {
      // ignore: avoid_print
      print(statusResult.stderr);
    }
    return;
  }
  final hasLocalChanges = statusResult.stdout.toString().isNotEmpty;

  // 2. 有修改则 stash
  String? stashedRef;
  if (hasLocalChanges) {
    if (runGit('stash', ['push', '-m', 'auto-stash']) != 0) return;
    stashedRef = _findAutoStashRef();
  }

  // 3. pull --rebase
  if (runGit('pull', ['--rebase']) != 0) {
    if (stashedRef != null) {
      // ignore: avoid_print
      print('注意：stash 已保留（$stashedRef），请手动处理冲突');
    }
    return;
  }

  // 4. 有 stash 则 pop
  if (stashedRef != null) {
    if (runGit('stash', ['pop', stashedRef]) != 0) {
      // ignore: avoid_print
      print('stash pop 失败，stash 已保留，请手动解决冲突');
      return;
    }
  }

  // 5. 清理残留的 auto-stash
  final leftover = _findAutoStashRef();
  if (leftover != null) {
    // ignore: avoid_print
    print('清理残留 stash: $leftover');
    runGit('stash', ['drop', leftover]);
  }

  // ignore: avoid_print
  print('完成');
}

void actionCommitAndPush() {
  // 先看当前状态（非仓库时这里就会报错走错误处理）
  if (runGit('status', ['--porcelain']) != 0) return;
  if (runGit('add', ['-A']) != 0) return;

  // 读暂存区文件名列表判断是否有变更（不打印 stdout）
  final listResult = Process.runSync(
    'git',
    ['diff', '--cached', '--name-only'],
    workingDirectory: _repoDir(),
  );
  final names = listResult.stdout.toString().trim();
  if (names.isEmpty) {
    // ignore: avoid_print
    print('无变更');
    return;
  }
  final fileCount = names.split('\n').length;
  final msg = 'chore: auto commit at ${_formatNow()} ($fileCount files)';

  if (runGit('commit', ['-m', msg]) != 0) return;
  if (runGit('push', []) != 0) return;

  // ignore: avoid_print
  print('完成');
}

void main() {
  _repoDir(); // 解析并丢弃，仅确保路径可访问

  while (true) {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('===== git_sync =====');
    // ignore: avoid_print
    print('1. 变基拉取');
    // ignore: avoid_print
    print('2. 提交并推送');
    // ignore: avoid_print
    print('3. 查看状态');
    // ignore: avoid_print
    print('4. 退出');
    // ignore: avoid_print
    stdout.write('请选择 [1-4]: ');

    final input = stdin.readLineSync();
    if (input == null) {
      // ignore: avoid_print
      print('再见');
      return;
    }

    final choice = input.trim();
    if (choice == '1') {
      actionRebasePull();
    } else if (choice == '2') {
      actionCommitAndPush();
    } else if (choice == '3') {
      runGit('status', []);
    } else if (choice == '4') {
      // ignore: avoid_print
      print('再见');
      return;
    } else if (choice.isNotEmpty) {
      // ignore: avoid_print
      print('无效输入');
    }
    // 空输入：直接重新显示菜单，不打"无效输入"
  }
}