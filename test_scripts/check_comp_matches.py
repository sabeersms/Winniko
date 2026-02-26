import json
import urllib.request
import urllib.parse

compId = "f7b5c908-a118-44b0-b78a-b2d23627f2be"
matches_url = f"https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions/{compId}/matches?pageSize=100"
req2 = urllib.request.Request(matches_url)
with urllib.request.urlopen(req2) as res2:
    matches_data = json.loads(res2.read().decode('utf-8'))
    for match_doc in matches_data.get('documents', []):
        m_fields = match_doc.get('fields', {})
        status = m_fields.get('status', {}).get('stringValue')
        if status == 'finished':
            print(f"Match: {match_doc['name'].split('/')[-1]}")
            print(m_fields.get('actualScore'))
            break
