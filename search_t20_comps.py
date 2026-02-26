import json
import os

# Filter for T20 competitions
cmd = 'curl.exe -X GET "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions" -o t20_comps.json'
# We can't really filter via curl easily without auth, but let's try to find if there's any other way.
# I'll just look at the latest_comps.json I already fetched if it's still there.

if os.path.exists('latest_comps.json'):
    with open('latest_comps.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
        if 'documents' in data:
            print("--- T20 Competitions ---")
            for doc in data['documents']:
                fields = doc.get('fields', {})
                name = fields.get('name', {}).get('stringValue', 'N/A')
                id_ = doc['name'].split('/')[-1]
                league_id = fields.get('leagueId', {}).get('stringValue', 'N/A')
                if 't20' in name.lower() or 't20' in league_id.lower():
                    print(f"ID: {id_} | Name: {name} | LeagueID: {league_id}")
        else:
            print("No competitions found in latest_comps.json")
else:
    print("latest_comps.json not found")
