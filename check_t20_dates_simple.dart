// Simple script to check T20 match dates
// Run with: dart run check_t20_dates_simple.dart

import 'dart:io';

void main() {
  print('''
╔════════════════════════════════════════════════════════════╗
║         T20 World Cup Date Correction Guide                ║
╚════════════════════════════════════════════════════════════╝

Since some matches in your T20 World Cup contest have incorrect dates,
here are your options to fix them:

📱 OPTION 1: Fix via Mobile App (Recommended)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Open the Winniko app
2. Go to your T20 World Cup competition
3. Tap on the match with wrong date/time
4. As organizer, you'll see "Edit Date & Time" option
5. Select the correct date and time
6. Save the changes

⚠️  Note: You can only edit dates for:
   - Matches that are NOT verified by super admin
   - Custom tournaments (non-official)

For official tournaments, dates are synced from the API.


🔄 OPTION 2: Re-import the Tournament
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
If many dates are wrong:

1. Create a NEW competition
2. Search for "T20 World Cup 2026" in official tournaments
3. Import it fresh (this will have correct dates)
4. Invite participants to the new competition

This ensures all dates are correct from the start.


🛠️  OPTION 3: Manual Database Update (Advanced)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
If you need to update dates programmatically:

1. I can create a Firebase Admin script
2. You'll need to provide:
   - Your competition ID
   - Which matches need updating
   - The correct dates for each match

Would you like me to create this script?


📋 CHECKING YOUR COMPETITION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
To help you better, please tell me:

1. What is your competition name?
2. How many matches have wrong dates?
3. Are the dates completely wrong, or just off by a few hours?
4. Is this a custom tournament or imported from official?

''');

  print('Would you like me to:');
  print('  A) Create a Firebase Admin script to fix dates');
  print('  B) Guide you through manual fixing in the app');
  print('  C) Help you re-import the tournament');
  print('');
  print('Please respond with your choice (A/B/C)');
}
