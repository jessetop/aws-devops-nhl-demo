import json
import pytest
from unittest.mock import patch, MagicMock
from app import lambda_handler


def test_options_request():
    """Test CORS preflight OPTIONS request"""
    event = {'httpMethod': 'OPTIONS'}
    context = {}
    
    response = lambda_handler(event, context)
    
    assert response['statusCode'] == 200
    assert 'Access-Control-Allow-Origin' in response['headers']
    assert response['headers']['Access-Control-Allow-Origin'] == '*'


@patch('app.urllib3.PoolManager')
@patch('builtins.open')
def test_successful_api_call(mock_open, mock_pool_manager):
    """Test successful NHL API call"""
    # Mock version file
    mock_file = MagicMock()
    mock_file.read.return_value = '1.0.0'
    mock_open.return_value.__enter__.return_value = mock_file
    
    # Mock HTTP response
    mock_response = MagicMock()
    mock_response.status = 200
    mock_response.data.decode.return_value = json.dumps({
        'standings': [{
            'teamName': {'default': 'Test Team'},
            'teamAbbrev': {'default': 'TST'},
            'wins': 10,
            'losses': 5,
            'points': 25
        }]
    })
    
    mock_http = MagicMock()
    mock_http.request.return_value = mock_response
    mock_pool_manager.return_value = mock_http
    
    event = {'httpMethod': 'GET'}
    context = {}
    
    response = lambda_handler(event, context)
    
    assert response['statusCode'] == 200
    body = json.loads(response['body'])
    assert 'teams' in body
    assert 'version' in body
    assert body['version'] == '1.0.0'


@patch('app.urllib3.PoolManager')
def test_api_error_handling(mock_pool_manager):
    """Test error handling when API fails"""
    mock_http = MagicMock()
    mock_http.request.side_effect = Exception('API Error')
    mock_pool_manager.return_value = mock_http
    
    event = {'httpMethod': 'GET'}
    context = {}
    
    response = lambda_handler(event, context)
    
    assert response['statusCode'] == 500
    body = json.loads(response['body'])
    assert 'error' in body