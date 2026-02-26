import json
import os

cmd = 'curl.exe -X GET "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions/f7b5c908-a118-44b0-b78a-b2d23627f2be/matches?pageSize=100" -o debug_matches_detailed.json'
os.system(cmd)

with open('debug_matches_detailed.json', 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        if 'documents' in data:
            for doc in data['documents']:
                fields = doc.get('fields', {})
                t1 = fields.get('team1Name', {}).get('stringValue', 'N/A')
                t2 = fields.get('team2Name', {}).get('stringValue', 'N/A')
                time = fields.get('scheduledTime', {}).get('timestampValue', 'N/A')
                id_ = doc['name'].split('/')[-1]
                if "India" in t1 and "Pakistan" in t2:
                    print(f"MATCH: {t1} vs {t2} | Time: {time} | ID: {id_}")
                if "England" in t1 and "West Indies" in t2:
                     print(f"MATCH: {t1} vs {t2} | Time: {time} | ID: {id_}")
        else:
            print("No matches")
    except Exception as e:
        print(f"Error: {e}")
