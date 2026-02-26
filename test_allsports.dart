import 'package:flutter/widgets.dart';
import 'lib/services/allsports_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = AllSportsApiService();
  final res = await api.searchTournaments('world cup');
  print('Results: \${res.length}');
  if (res.isNotEmpty) {
    print(res.first);
  }
}
