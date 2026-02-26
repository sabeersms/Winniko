import json
import os

# Fetch official matches for T20 WC 2026
cmd = 'curl.exe -X GET "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/official_leagues/mens-t20-world-cup-2026/matches?pageSize=100" -o official_matches_t20.json'
os.system(cmd)

with open('official_matches_t20.json', 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        if 'documents' in data:
            print(f"--- Official Matches for T20 WC ---")
            for doc in data['documents']:
                fields = doc.get('fields', {})
                t1 = fields.get('team1Name', {}).get('stringValue', 'N/A')
                t2 = fields.get('team2Name', {}).get('stringValue', 'N/A')
                match_id = doc['name'].split('/')[-1]
                print(f"ID: {match_id} | {t1} vs {t2}")
        else:
            print("No matches found in official_leagues/mens-t20-world-cup-2026/matches")
            print(data)
    except Exception as e:
        print(f"Error parsing JSON: {e}")
