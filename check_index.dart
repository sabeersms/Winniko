import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(
    Uri.parse('https://fixturedownload.com/index'),
  );
  if (response.statusCode == 200) {
    var html = response.body;
    print('HTML Length: ${html.length}');
    // Print first 500 chars
    print(html.substring(0, 500));

    final regExp = RegExp(r'href="/results/([^"]+)"[^>]*>([^<]+)</a>');
    final matches = regExp.allMatches(html);
    print('Matches found: ${matches.length}');
    for (var i = 0; i < matches.length && i < 10; i++) {
      print(
        'Match $i: ID=${matches.elementAt(i).group(1)}, Name=${matches.elementAt(i).group(2)}',
      );
    }
  } else {
    print('Error: ${response.statusCode}');
  }
}
