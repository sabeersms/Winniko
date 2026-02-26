import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(
    Uri.parse('https://fixturedownload.com/index'),
  );
  if (response.statusCode == 200) {
    var html = response.body;
    if (html.toLowerCase().contains('cricket')) {
      print('Cricket found!');
      int idx = html.toLowerCase().indexOf('cricket');
      print(html.substring(idx, idx + 500));
    } else {
      print('Cricket NOT found on fixturedownload index.');
    }
  }
}
