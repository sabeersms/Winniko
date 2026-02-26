import json
import urllib.request
import urllib.parse

comps_url = "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions"
req = urllib.request.Request(comps_url)
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read().decode('utf-8'))
    
    comps = []
    for doc in data.get('documents', []):
         if doc.get('fields', {}).get('leagueId', {}).get('stringValue') == 'mens-t20-world-cup-2026':
             comps.append(doc['name'].split('/')[-1])
             
    for compId in comps:
         matches_url = f"https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/competitions/{compId}/matches?pageSize=100"
         try:
             req2 = urllib.request.Request(matches_url)
             with urllib.request.urlopen(req2) as res2:
                 matches_data = json.loads(res2.read().decode('utf-8'))
                 count = 0
                 for match_doc in matches_data.get('documents', []):
                     m_fields = match_doc.get('fields', {})
                     status = m_fields.get('status', {}).get('stringValue')
                     actualScore = m_fields.get('actualScore')
                     
                     if status != 'upcoming' or actualScore is not None:
                         count += 1
                 print(f"Comp {compId}: {count} non-upcoming matches.")
         except:
             pass
