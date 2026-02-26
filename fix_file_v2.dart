import 'dart:io';

void main() {
  print('Starting fix_file_v2.dart...');
  try {
    final file = File(
      'd:\\projects\\antigravity\\Winniko\\lib\\services\\tournament_data_service.dart',
    );
    if (!file.existsSync()) {
      print('File not found!');
      return;
    }
    final lines = file.readAsLinesSync();
    print('Read ${lines.length} lines.');

    if (lines.length > 2213) {
      print('Line 2212 content: "${lines[2212]}"');

      if (lines[2212].trim() == '}') {
        print('Truncating...');
        final newLines = lines.sublist(0, 2213);
        file.writeAsStringSync(newLines.join('\n'));
        print('Truncated successfully.');
      } else {
        print('Line 2212 is NOT "}". It is: "${lines[2212]}".');
      }
    } else {
      print('File is short enough.');
    }
  } catch (e) {
    print('Create Error: $e');
  }
}
