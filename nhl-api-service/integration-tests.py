#!/usr/bin/env python3
import requests
import json
import sys
import time
from datetime import datetime

def test_endpoint(url, test_name, expected_status=200):
    """Test an endpoint and return results"""
    print(f"Testing {test_name}...")
    try:
        start_time = time.time()
        response = requests.get(url, timeout=30)
        response_time = time.time() - start_time
        
        print(f"  Status: {response.status_code}")
        print(f"  Response Time: {response_time:.2f}s")
        
        if response.status_code == expected_status:
            print(f"  ✓ {test_name} PASSED")
            return True
        else:
            print(f"  ✗ {test_name} FAILED - Expected {expected_status}, got {response.status_code}")
            return False
            
    except Exception as e:
        print(f"  ✗ {test_name} FAILED - {str(e)}")
        return False

def test_api_response_structure(url):
    """Test API response has expected structure"""
    print("Testing API response structure...")
    try:
        response = requests.get(url, timeout=30)
        if response.status_code == 200:
            data = response.json()
            required_fields = ['timestamp', 'version', 'teams']
            
            for field in required_fields:
                if field not in data:
                    print(f"  ✗ Missing required field: {field}")
                    return False
            
            print("  ✓ API response structure PASSED")
            return True
        else:
            print(f"  ✗ API response structure FAILED - Status {response.status_code}")
            return False
    except Exception as e:
        print(f"  ✗ API response structure FAILED - {str(e)}")
        return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python integration-tests.py <API_ENDPOINT_URL>")
        sys.exit(1)
    
    api_url = sys.argv[1]
    print(f"Running integration tests against: {api_url}")
    print(f"Test started at: {datetime.now().isoformat()}")
    print("-" * 50)
    
    tests_passed = 0
    total_tests = 3
    
    # Test 1: Basic connectivity
    if test_endpoint(api_url, "Basic Connectivity"):
        tests_passed += 1
    
    # Test 2: Response structure
    if test_api_response_structure(api_url):
        tests_passed += 1
    
    # Test 3: CORS preflight (OPTIONS)
    try:
        print("Testing CORS preflight...")
        response = requests.options(api_url, timeout=30)
        if response.status_code == 200 and 'access-control-allow-origin' in response.headers:
            print("  ✓ CORS preflight PASSED")
            tests_passed += 1
        else:
            print("  ✗ CORS preflight FAILED")
    except Exception as e:
        print(f"  ✗ CORS preflight FAILED - {str(e)}")
    
    print("-" * 50)
    print(f"Tests completed: {tests_passed}/{total_tests} passed")
    
    if tests_passed == total_tests:
        print("🎉 All integration tests PASSED!")
        sys.exit(0)
    else:
        print("❌ Some integration tests FAILED!")
        sys.exit(1)

if __name__ == "__main__":
    main()