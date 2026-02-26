import json
import os

cmd = 'curl.exe -X GET "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/official_leagues/mens-t20-world-cup-2026/matches?pageSize=100" -o official_matches_full.json'
os.system(cmd)

with open('official_matches_full.json', 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        if 'documents' in data:
            matches = []
            for doc in data['documents']:
                fields = doc.get('fields', {})
                t1 = fields.get('team1Name', {}).get('stringValue', 'N/A')
                t2 = fields.get('team2Name', {}).get('stringValue', 'N/A')
                matches.append(f"{t1} vs {t2}")
            
            print("--- Matches in Official League ---")
            for m in matches:
                print(m)
        else:
            print("No matches in official league")
    except Exception as e:
        print(f"Error: {e}")
