import json
import os
from collections import defaultdict

league_id = 'mens-t20-world-cup-2026'
url = f"https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/official_leagues/{league_id}/matches?pageSize=200"
cmd = f'curl.exe -X GET "{url}" -o hard_copy_matches.json'
os.system(cmd)

with open('hard_copy_matches.json', 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        if 'documents' in data:
            matches = []
            print(f"--- Hard Copy Matches in {league_id} ---")
            for doc in data['documents']:
                doc_id = doc['name'].split('/')[-1]
                fields = doc.get('fields', {})
                t1 = fields.get('team1Name', {}).get('stringValue', 'N/A')
                t2 = fields.get('team2Name', {}).get('stringValue', 'N/A')
                time = fields.get('scheduledTime', {}).get('timestampValue', 'N/A')
                matches.append({
                    'id': doc_id,
                    't1': t1,
                    't2': t2,
                    'time': time
                })
            
            # Find duplicates
            seen = defaultdict(list)
            for m in matches:
                key = tuple(sorted([m['t1'], m['t2']])) + (m['time'],)
                seen[key].append(m['id'])
            
            duplicates_found = False
            for key, ids in seen.items():
                if len(ids) > 1:
                    duplicates_found = True
                    print(f"DUPLICATE FOUND: {key[0]} vs {key[1]} at {key[2]}")
                    for i in ids:
                        print(f"  - Doc ID: {i}")
            
            if not duplicates_found:
                print("No obvious duplicates found by Team Pair + Time.")
        else:
            print("No matches found in hard copy")
    except Exception as e:
        print(f"Error parsing JSON: {e}")
