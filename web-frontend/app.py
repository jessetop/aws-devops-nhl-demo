import json
import urllib3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        logger.info("Web frontend Lambda started")
        # Get service endpoints from environment variables
        nhl_api_endpoint = os.environ.get('NHL_API_ENDPOINT', 'https://YOUR_NHL_API_GATEWAY_URL/prod/nhl-stats')
        stats_processing_endpoint = os.environ.get('STATS_PROCESSING_ENDPOINT', 'http://YOUR_EKS_LOADBALANCER_URL/process-stats')
        
        # Get current AWS region
        current_region = os.environ.get('AWS_REGION', 'unknown')
        
        # Extract regions from endpoints for comparison
        nhl_api_region = 'unknown'
        eks_region = 'unknown'
        
        if 'execute-api' in nhl_api_endpoint:
            try:
                nhl_api_region = nhl_api_endpoint.split('.')[2]
            except:
                pass
        
        if 'elb.amazonaws.com' in stats_processing_endpoint:
            try:
                eks_region = stats_processing_endpoint.split('.')[1]
            except:
                pass
        
        # Simple HTML page that displays NHL stats
        html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
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
            <h1>&#127954; NHL Stats Dashboard</h1>
            
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
                <h2>Service Status & Configuration</h2>
                <div id="service-status">
                    <p>&#9989; Web Frontend: Active (Lambda + CodePipeline) - Region: {current_region}</p>
                    <p>&#128260; NHL API Service: <span id="nhl-api-status">Check endpoint</span> - Region: {nhl_api_region}</p>
                    <p>&#128260; Stats Processing: <span id="stats-processing-status">Check endpoint</span> - Region: {eks_region}</p>
                    <div id="region-warning" style="color: orange; margin-top: 10px;"></div>
                    <p><small>Endpoints: NHL API: {nhl_api_endpoint}</small></p>
                    <p><small>EKS: {stats_processing_endpoint}</small></p>
                </div>
            </div>
        </div>
        
        <script>
            // API endpoints from Lambda environment variables
            const NHL_API_ENDPOINT = '{nhl_api_endpoint}';
            const STATS_PROCESSING_ENDPOINT = '{stats_processing_endpoint}';
            
            // Region information
            const CURRENT_REGION = '{current_region}';
            const NHL_API_REGION = '{nhl_api_region}';
            const EKS_REGION = '{eks_region}';
            
            // Check for region mismatches
            function checkRegionMismatch() {{
                const warnings = [];
                if (NHL_API_REGION !== 'unknown' && NHL_API_REGION !== CURRENT_REGION) {{
                    warnings.push('NHL API in ' + NHL_API_REGION + ', Web Frontend in ' + CURRENT_REGION);
                }}
                if (EKS_REGION !== 'unknown' && EKS_REGION !== CURRENT_REGION) {{
                    warnings.push('EKS in ' + EKS_REGION + ', Web Frontend in ' + CURRENT_REGION);
                }}
                if (warnings.length > 0) {{
                    document.getElementById('region-warning').innerHTML = '⚠️ Region Mismatch: ' + warnings.join(', ');
                }}
            }}
            
            // Run region check on page load
            window.onload = function() {{
                checkRegionMismatch();
            }};
            
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
                    html += `<p><small>&#128640; Data from NHL API Lambda (GitHub Actions)</small></p>`;
                    
                    document.getElementById('nhl-stats').innerHTML = html;
                    document.getElementById('nhl-api-status').innerHTML = '✅ Active';
                } catch (error) {
                    console.error('NHL API Error:', error);
                    document.getElementById('nhl-stats').innerHTML = '<div style="color: red;">Error loading NHL stats: ' + error.message + '<br><small>Check if NHL API Lambda is deployed in ' + NHL_API_REGION + '</small></div>';
                    document.getElementById('nhl-api-status').innerHTML = '❌ Failed';
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
                    html += `<p><small>&#128640; Data from EKS Stats Processing (CodePipeline)</small></p>`;
                    
                    document.getElementById('processed-stats').innerHTML = html;
                    document.getElementById('stats-processing-status').innerHTML = '✅ Active';
                } catch (error) {
                    console.error('Stats Processing Error:', error);
                    document.getElementById('processed-stats').innerHTML = '<div style="color: red;">Error loading processed stats: ' + error.message + '<br><small>Check if EKS service is deployed in ' + EKS_REGION + '</small></div>';
                    document.getElementById('stats-processing-status').innerHTML = '❌ Failed';
                }
            }
        </script>
    </body>
    </html>
    """
    
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'text/html; charset=utf-8',
            },
            'body': html_content
        }
    except Exception as e:
        logger.error(f"Error in web frontend Lambda: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'text/html; charset=utf-8',
            },
            'body': f'<html><body><h1>Error</h1><p>Internal server error: {str(e)}</p></body></html>'
        }