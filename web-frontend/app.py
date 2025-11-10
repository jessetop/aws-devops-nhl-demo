import json
import urllib3
import os

def lambda_handler(event, context):
    # Simple HTML page that displays NHL stats
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>NHL Stats Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 1200px; margin: 0 auto; }
            .service-box { border: 1px solid #ddd; padding: 20px; margin: 20px 0; border-radius: 5px; }
            .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
            button { background: #007cba; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
            button:hover { background: #005a87; }
            .loading { color: #666; font-style: italic; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🏒 NHL Stats Dashboard</h1>
            
            <div class="service-box">
                <h2>NHL API Service (Lambda + GitHub Actions)</h2>
                <button onclick="loadNHLStats()">Load NHL Team Stats</button>
                <div id="nhl-stats" class="loading">Click to load stats...</div>
            </div>
            
            <div class="service-box">
                <h2>Stats Processing Service (EKS + CodePipeline)</h2>
                <button onclick="loadProcessedStats()">Load Processed Stats</button>
                <div id="processed-stats" class="loading">Click to load processed stats...</div>
            </div>
            
            <div class="service-box">
                <h2>Service Status</h2>
                <div id="service-status">
                    <p>✅ Web Frontend: Active (Lambda + CodePipeline)</p>
                    <p>🔄 NHL API Service: Ready</p>
                    <p>🔄 Stats Processing: Ready</p>
                </div>
            </div>
        </div>
        
        <script>
            async function loadNHLStats() {
                document.getElementById('nhl-stats').innerHTML = '<div class="loading">Loading NHL stats...</div>';
                try {
                    // In a real implementation, this would call your NHL API Lambda
                    const mockData = {
                        timestamp: new Date().toISOString(),
                        teams: [
                            { team: 'Toronto Maple Leafs', wins: 25, losses: 15 },
                            { team: 'Boston Bruins', wins: 30, losses: 10 },
                            { team: 'Tampa Bay Lightning', wins: 28, losses: 12 }
                        ]
                    };
                    
                    let html = '<div class="stats-grid">';
                    mockData.teams.forEach(team => {
                        html += `<div><strong>${team.team}</strong><br>Wins: ${team.wins}, Losses: ${team.losses}</div>`;
                    });
                    html += '</div>';
                    html += `<p><small>Last updated: ${mockData.timestamp}</small></p>`;
                    
                    document.getElementById('nhl-stats').innerHTML = html;
                } catch (error) {
                    document.getElementById('nhl-stats').innerHTML = '<div style="color: red;">Error loading stats</div>';
                }
            }
            
            async function loadProcessedStats() {
                document.getElementById('processed-stats').innerHTML = '<div class="loading">Loading processed stats...</div>';
                try {
                    // Mock processed stats data
                    const mockProcessed = {
                        processed_teams: 10,
                        data: [
                            { name: 'Atlantic Division Leaders', conference: 'Eastern' },
                            { name: 'Metropolitan Division Leaders', conference: 'Eastern' },
                            { name: 'Central Division Leaders', conference: 'Western' }
                        ]
                    };
                    
                    let html = '<div class="stats-grid">';
                    mockProcessed.data.forEach(item => {
                        html += `<div><strong>${item.name}</strong><br>Conference: ${item.conference}</div>`;
                    });
                    html += '</div>';
                    html += `<p><small>Processed ${mockProcessed.processed_teams} teams</small></p>`;
                    
                    document.getElementById('processed-stats').innerHTML = html;
                } catch (error) {
                    document.getElementById('processed-stats').innerHTML = '<div style="color: red;">Error loading processed stats</div>';
                }
            }
        </script>
    </body>
    </html>
    """
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/html',
        },
        'body': html_content
    }