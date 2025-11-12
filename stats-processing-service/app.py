from flask import Flask, jsonify
from flask_cors import CORS
import requests
import json
from datetime import datetime
import os

app = Flask(__name__)
CORS(app)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

@app.route('/process-stats')
def process_stats():
    try:
        # Get NHL API endpoint from environment
        nhl_api_url = os.getenv('NHL_API_URL', 'https://statsapi.web.nhl.com/api/v1/teams')
        
        # Fetch and process team standings
        response = requests.get(f"{nhl_api_url}")
        teams_data = response.json()
        
        processed_stats = []
        for team in teams_data.get('teams', [])[:10]:  # Process top 10 teams
            # Calculate some basic metrics
            team_info = {
                'name': team.get('name'),
                'division': team.get('division', {}).get('name'),
                'conference': team.get('conference', {}).get('name'),
                'processed_at': datetime.now().isoformat()
            }
            processed_stats.append(team_info)
        
        return jsonify({
            'processed_teams': len(processed_stats),
            'data': processed_stats,
            'service': 'stats-processing'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)