import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://fixturedownload.com/index';
  final response = await http.get(Uri.parse(url));

  final html = response.body;
  final regExp = RegExp(r'href="/results/([^"]+)"');
  final matches = regExp.allMatches(html);

  for (var m in matches) {
    if (m.group(1)!.toLowerCase().contains('world')) {
      print('Found: ${m.group(1)}');
    }
  }
}
