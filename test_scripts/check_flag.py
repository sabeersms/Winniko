import json
import urllib.request

url = "https://firestore.googleapis.com/v1/projects/winniko-real/databases/(default)/documents/app_metadata/t20_leaderboard_refresh"
req = urllib.request.Request(url)
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode('utf-8'))
        print(data)
except urllib.error.URLError as e:
    print(f"Error: {e}")
