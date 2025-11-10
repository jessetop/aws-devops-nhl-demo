import json
import urllib3
import boto3
from datetime import datetime

def lambda_handler(event, context):
    http = urllib3.PoolManager()
    
    # NHL API endpoints
    teams_url = "https://statsapi.web.nhl.com/api/v1/teams"
    
    try:
        # Get teams data
        teams_response = http.request('GET', teams_url)
        teams_data = json.loads(teams_response.data.decode('utf-8'))
        
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
                'teams': stats
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }