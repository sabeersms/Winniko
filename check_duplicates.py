import json
import os

cmd = 'curl.exe -X GET "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions/f7b5c908-a118-44b0-b78a-b2d23627f2be/matches?pageSize=100" -o debug_matches.json'
os.system(cmd)

with open('debug_matches.json', 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        if 'documents' in data:
            matches = []
            for doc in data['documents']:
                fields = doc.get('fields', {})
                t1 = fields.get('team1Name', {}).get('stringValue', 'N/A')
                t2 = fields.get('team2Name', {}).get('stringValue', 'N/A')
                matches.append(f"{t1} vs {t2}")
            
            from collections import Counter
            counts = Counter(matches)
            print("--- Match Counts in Contest ---")
            for m, count in counts.items():
                if count > 1:
                    print(f"DUPLICATE: {m} (x{count})")
                else:
                    print(f"OK: {m}")
        else:
            print("No matches found in contest")
    except Exception as e:
        print(f"Error: {e}")
