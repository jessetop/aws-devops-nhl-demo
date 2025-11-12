import json
import urllib3
from datetime import datetime
import logging

# Configure logging for better debugging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Read version from file
    try:
        with open('version.txt', 'r') as f:
            version = f.read().strip()
    except:
        version = 'unknown'
    
    http = urllib3.PoolManager()
    
    # NHL API endpoints - using NHL's current API
    teams_url = "https://api-web.nhle.com/v1/standings/now"
    
    try:
        logger.info(f"Fetching teams from: {teams_url}")
        # Get standings data (simpler than old API)
        teams_response = http.request('GET', teams_url)
        logger.info(f"Teams response status: {teams_response.status}")
        standings_data = json.loads(teams_response.data.decode('utf-8'))
        
        # Extract team data from standings
        stats = []
        standings = standings_data.get('standings', [])
        for standing in standings[:5]:  # Limit for demo
            stats.append({
                'team': standing.get('teamName', {}).get('default', 'Unknown Team'),
                'id': standing.get('teamAbbrev', {}).get('default', 'UNK'),
                'stats': [{
                    'splits': [{
                        'stat': {
                            'wins': standing.get('wins', 0),
                            'losses': standing.get('losses', 0),
                            'pts': standing.get('points', 0)
                        }
                    }]
                }]
            })
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'timestamp': datetime.now().isoformat(),
                'version': version,
                'teams': stats
            })
        }
        
    except Exception as e:
        logger.error(f"Error in NHL API service: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }