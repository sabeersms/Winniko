import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(
    Uri.parse('https://fixturedownload.com/index'),
  );
  if (response.statusCode == 200) {
    var html = response.body;
    int idx = html.indexOf('nfl-2025');
    if (idx != -1) {
      print(html.substring(idx - 200, idx + 200));
    }
  }
}
