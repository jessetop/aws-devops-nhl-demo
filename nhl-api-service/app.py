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
    
    # NHL API endpoints
    teams_url = "https://statsapi.web.nhl.com/api/v1/teams"
    
    try:
        logger.info(f"Fetching teams from: {teams_url}")
        # Get teams data
        teams_response = http.request('GET', teams_url)
        logger.info(f"Teams response status: {teams_response.status}")
        teams_data = json.loads(teams_response.data.decode('utf-8'))
        logger.info(f"Found {len(teams_data.get('teams', []))} teams")
        
        # Get current season stats for first few teams
        stats = []
        for team in teams_data['teams'][:5]:  # Limit for demo
            team_id = team['id']
            stats_url = f"https://statsapi.web.nhl.com/api/v1/teams/{team_id}/stats"
            
            stats_response = http.request('GET', stats_url)
            team_stats = json.loads(stats_response.data.decode('utf-8'))
            
            stats.append({
                'team': team['name'],
                'id': team_id,
                'stats': team_stats.get('stats', [])
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