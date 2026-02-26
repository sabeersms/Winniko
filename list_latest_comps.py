import json
import os

cmd = 'curl.exe -X GET "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions?pageSize=20" -o latest_comps.json'
os.system(cmd)

with open('latest_comps.json', 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
        if 'documents' in data:
            print("--- Latest Competitions ---")
            for doc in data['documents']:
                fields = doc.get('fields', {})
                name = fields.get('name', {}).get('stringValue', 'N/A')
                id_ = doc['name'].split('/')[-1]
                created = doc.get('createTime', 'N/A')
                print(f"ID: {id_} | Name: {name} | Created: {created}")
        else:
            print("No competitions found")
    except Exception as e:
        print(f"Error: {e}")
