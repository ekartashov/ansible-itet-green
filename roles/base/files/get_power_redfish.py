#!/usr/bin/env python3
import requests
import sys
import json
import urllib3 # Import urllib3 directly for cleaner warning suppression
from requests.auth import HTTPBasicAuth

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_power(ip, user, password):
    base_url = f"https://{ip}/redfish/v1/Chassis/"
    
    try:
        # 1. List chassis
        r = requests.get(base_url, auth=HTTPBasicAuth(user, password), verify=False, timeout=10)
        r.raise_for_status() # Automatically raises error for 4xx/5xx codes
        
        data = r.json()
        chassis_list = data.get("Members", [])
        
        if not chassis_list:
            # Print error to stderr for Ansible to see it as a log issue
            print("No chassis found.", file=sys.stderr)
            sys.exit(1)

        for chassis in chassis_list:
            ch_url = chassis["@odata.id"]
            # Redfish IDs usually start with /, so no / needed after {ip}
            power_url = f"https://{ip}{ch_url}/Power"
            
            r = requests.get(power_url, auth=HTTPBasicAuth(user, password), verify=False, timeout=10)
            if r.status_code != 200:
                continue

            pdata = r.json()
            power_control = pdata.get("PowerControl", [])
            
            if power_control:
                for ctrl in power_control:
                    watts = ctrl.get("PowerConsumedWatts")
                    if watts is not None:
                        # SUCCESS: Return a dictionary
                        return {"ip": ip, "watts": watts}

    except requests.exceptions.RequestException as e:
        # Print actual connection errors to stderr
        print(f"Connection Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"General Error: {e}", file=sys.stderr)
        sys.exit(1)

    print("No power data found.", file=sys.stderr)
    sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <BMC_IP> <USERNAME> <PASSWORD>", file=sys.stderr)
        sys.exit(1)

    ip = sys.argv[1]
    user = sys.argv[2]
    password = sys.argv[3]

    # Get the data
    result = get_power(ip, user, password)
    
    # Print JSON. Ansible can parse this easily.
    print(json.dumps(result))