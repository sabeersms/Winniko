import json
import os
import urllib.request

url = "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions?pageSize=200"
req = urllib.request.Request(url)
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode('utf-8'))

comps = []
if 'documents' in data:
    for doc in data['documents']:
        doc_id = doc['name'].split('/')[-1]
        fields = doc.get('fields', {})
        name = fields.get('name', {}).get('stringValue', 'N/A')
        leagueId = fields.get('leagueId', {}).get('stringValue', '')
        sport = fields.get('sport', {}).get('stringValue', '')
        comps.append({'id': doc_id, 'name': name, 'leagueId': leagueId, 'sport': sport})

for c in comps:
    print(c)
