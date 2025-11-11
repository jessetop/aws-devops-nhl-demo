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
                    <p>🔄 NHL API Service: <span id="nhl-api-status">Check endpoint</span></p>
                    <p>🔄 Stats Processing: <span id="stats-processing-status">Check endpoint</span></p>
                    <p><small>Update API endpoints in code to connect to real services</small></p>
                </div>
            </div>
        </div>
        
        <script>
            // API endpoints - these will be dynamically populated
            const NHL_API_ENDPOINT = 'https://YOUR_NHL_API_GATEWAY_URL/prod/nhl-stats';
            const STATS_PROCESSING_ENDPOINT = 'http://YOUR_EKS_LOADBALANCER_URL/process-stats';
            
            async function loadNHLStats() {
                document.getElementById('nhl-stats').innerHTML = '<div class="loading">Loading NHL stats from Lambda...</div>';
                try {
                    const response = await fetch(NHL_API_ENDPOINT);
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}`);
                    }
                    const data = await response.json();
                    
                    let html = '<div class="stats-grid">';
                    data.teams.forEach(team => {
                        const teamStats = team.stats[0]?.splits[0]?.stat || {};
                        html += `<div><strong>${team.team}</strong><br>`;
                        html += `Wins: ${teamStats.wins || 'N/A'}, Losses: ${teamStats.losses || 'N/A'}<br>`;
                        html += `Points: ${teamStats.pts || 'N/A'}</div>`;
                    });
                    html += '</div>';
                    html += `<p><small>Last updated: ${data.timestamp}</small></p>`;
                    html += `<p><small>🚀 Data from NHL API Lambda (GitHub Actions)</small></p>`;
                    
                    document.getElementById('nhl-stats').innerHTML = html;
                } catch (error) {
                    console.error('NHL API Error:', error);
                    document.getElementById('nhl-stats').innerHTML = `<div style="color: red;">Error loading NHL stats: ${error.message}<br><small>Check if NHL API Lambda is deployed</small></div>`;
                }
            }
            
            async function loadProcessedStats() {
                document.getElementById('processed-stats').innerHTML = '<div class="loading">Loading processed stats from EKS...</div>';
                try {
                    const response = await fetch(STATS_PROCESSING_ENDPOINT);
                    if (!response.ok) {
                        throw new Error(`HTTP ${response.status}`);
                    }
                    const data = await response.json();
                    
                    let html = '<div class="stats-grid">';
                    data.data.forEach(team => {
                        html += `<div><strong>${team.name}</strong><br>`;
                        html += `Division: ${team.division}<br>`;
                        html += `Conference: ${team.conference}</div>`;
                    });
                    html += '</div>';
                    html += `<p><small>Processed ${data.processed_teams} teams</small></p>`;
                    html += `<p><small>🚀 Data from EKS Stats Processing (CodePipeline)</small></p>`;
                    
                    document.getElementById('processed-stats').innerHTML = html;
                } catch (error) {
                    console.error('Stats Processing Error:', error);
                    document.getElementById('processed-stats').innerHTML = `<div style="color: red;">Error loading processed stats: ${error.message}<br><small>Check if EKS service is deployed and accessible</small></div>`;
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