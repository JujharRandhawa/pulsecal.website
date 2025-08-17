#!/usr/bin/env python3
"""
Clear Google API client discovery cache
"""
import os
import shutil
import sys

def clear_google_api_cache():
    """Clear Google API discovery cache"""
    try:
        # Find the cache directory
        cache_dir = os.path.join(sys.prefix, 'Lib', 'site-packages', 'googleapiclient', 'discovery_cache', 'documents')
        
        if os.path.exists(cache_dir):
            print(f"Clearing cache directory: {cache_dir}")
            shutil.rmtree(cache_dir)
            os.makedirs(cache_dir)
            print("Google API cache cleared successfully")
        else:
            print("Cache directory not found")
            
    except Exception as e:
        print(f"Error clearing cache: {e}")

if __name__ == "__main__":
    clear_google_api_cache()