import 'dart:io';

void main() {
  final file = File(
    'd:\\projects\\antigravity\\Winniko\\lib\\services\\tournament_data_service.dart',
  );
  final lines = file.readAsLinesSync();

  // Find line 2213 (0-indexed 2212)
  if (lines.length > 2213) {
    print('File has ${lines.length} lines. Truncating to 2213.');

    // Verify line 2212 matches '}'
    print('Line 2213 content: "${lines[2212]}"');
    if (lines[2212].trim() == '}') {
      final newLines = lines.sublist(0, 2213);
      file.writeAsStringSync(newLines.join('\n'));
      print('Truncated successfully.');
    } else {
      print('Line 2213 is NOT "}". It is: "${lines[2212]}". Aborting.');
      // Print surrounding lines to debug
      for (int i = 2210; i < 2215 && i < lines.length; i++) {
        print('$i: ${lines[i]}');
      }
    }
  } else {
    print('File is already short enough (${lines.length}).');
  }
}
