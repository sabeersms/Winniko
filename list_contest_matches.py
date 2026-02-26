import json
import os

# Fetch matches for the specific contest
cmd = 'curl.exe -X GET "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions/f7b5c908-a118-44b0-b78a-b2d23627f2be/matches?pageSize=100" -o contest_matches.json'
os.system(cmd)

with open('contest_matches.json', 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        if 'documents' in data:
            print(f"--- Matches in Contest f7b5 ---")
            for doc in data['documents']:
                fields = doc.get('fields', {})
                t1 = fields.get('team1Name', {}).get('stringValue', 'N/A')
                t2 = fields.get('team2Name', {}).get('stringValue', 'N/A')
                status = fields.get('status', {}).get('stringValue', 'N/A')
                is_verified = fields.get('actualScore', {}).get('mapValue', {}).get('fields', {}).get('verified', {}).get('booleanValue', False)
                print(f"| {t1} vs {t2} | Status: {status} | Verified: {is_verified}")
        else:
            print("No matches found in contest")
    except Exception as e:
        print(f"Error parsing JSON: {e}")
