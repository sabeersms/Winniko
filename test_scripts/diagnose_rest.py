import json
import urllib.request

BASE_URL = "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents"

def post_query(path, query_body):
    url = f"{BASE_URL}/{path}:runQuery"
    try:
        data = json.dumps(query_body).encode('utf-8')
        req = urllib.request.Request(url, data=data, method='POST')
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        # print(f"Error querying {path}: {e}")
        return None

def get_docs(path, query=""):
    url = f"{BASE_URL}/{path}{query}"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return {}

def run_diagnostic():
    print("--- Fetching competitions ---")
    comps_data = get_docs("competitions", "?pageSize=100")
    
    t20_comp_id = "f7b5c908-a118-44b0-b78a-b2d23627f2be"
    print(f"Target Competition: T20 CONTEST ({t20_comp_id})")
    
    # Fetch current matches
    print(f"Fetching current matches...")
    matches_data = get_docs(f"competitions/{t20_comp_id}/matches", "?pageSize=100")
    match_ids = set()
    if 'documents' in matches_data:
        for m_doc in matches_data['documents']:
            m_id = m_doc['name'].split('/')[-1]
            match_ids.add(m_id)
            
    print(f"Found {len(match_ids)} current matches.")
    
    # Query predictions for this competition
    print(f"Querying predictions for {t20_comp_id}...")
    query = {
        "structuredQuery": {
            "from": [{"collectionId": "predictions"}],
            "where": {
                "fieldFilter": {
                    "field": {"fieldPath": "competitionId"},
                    "op": "EQUAL",
                    "value": {"stringValue": t20_comp_id}
                }
            }
        }
    }
    
    results = post_query("", query)
    if not results:
        print("--- Query failed (probably needs auth). Trying sample list instead ---")
        results = get_docs("predictions", "?pageSize=100")
        if 'documents' in results:
            results = [{"document": doc} for doc in results['documents']]
        else:
            results = []

    valid = 0
    orphaned = 0
    orphaned_match_ids = set()
    
    for res in results:
        if 'document' not in res: continue
        doc = res['document']
        fields = doc.get('fields', {})
        
        # Filter by competitionId if it's from a broad list
        p_comp_id = fields.get('competitionId', {}).get('stringValue', '')
        if p_comp_id != t20_comp_id: continue
        
        p_match_id = fields.get('matchId', {}).get('stringValue', '')
        if p_match_id in match_ids:
            valid += 1
        else:
            orphaned += 1
            orphaned_match_ids.add(p_match_id)
            
    print(f"Prediction Summary:")
    print(f"Valid: {valid}")
    print(f"Orphaned: {orphaned}")
    print(f"Unique orphaned matches: {len(orphaned_match_ids)}")
    if orphaned_match_ids:
        print(f"Sample orphaned IDs: {list(orphaned_match_ids)[:10]}")

if __name__ == "__main__":
    run_diagnostic()
