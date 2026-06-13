""" 
This python script demonstrates API paging using the Venafi outagedetection/v1/certificatesearch API.
This particular API allows you to return all certificates in your inventory in batches - set here at 250 at a time.
We also use search criteria to help reduce the amount of certificates you return, and in this example, we are only returning "ACTIVE" (not RETIRED) certificates.
Finally, we will output the results into a .csv file in the same directory as this script.
***NOTE*** You will need to retrieve your API key from your tenant and set it as an OS environmental varible called: VAAS_API_KEY
"""

# IMPORTS
import os
import datetime
import requests
import csv

# URL for North America. Change to "https://api.venafi.eu" for EMEA
VAAS_URL = "https://api.venafi.cloud"

# Your API key is found in your tenant under your user "preferences".
# Ensure to set this as an environmental variable 
VAAS_API_KEY = os.environ.get('VAAS_API_KEY')

# Check that the variable is set. 
VAAS_API_KEY or exit("Environmental variable not set. Please set VAAS_API_KEY environmental variable with your Venafi API Key!")

if __name__ == "__main__":

    headers = {
        "accept": "application/json",
        "content-type": "application/json",
        "tppl-api-key": VAAS_API_KEY
    }

    page_num = 0
    PAGE_SIZE = 250

    cert_ids = []

    while True:

        uri = f"{VAAS_URL}/outagedetection/v1/certificatesearch"
        body = {
            "expression": {
                "operands": [
                    {
                        "field": "certificateStatus",
                        "operator": "MATCH",
                        "value": "ACTIVE"       #not "RETIRED"
                    }
                ]
            },
            "ordering": {
                "orders": [
                    {
                        "direction": "DESC",
                        "field": "certificateName"
                    }
                ]
            },
            "paging": {
                "pageNumber": page_num,
                "pageSize": PAGE_SIZE
            }
        }
        r = requests.post(url=uri, headers=headers, json=body, verify=True, timeout=30)
        if r.status_code != 200:
            print(f"///// Search failed with HTTP {r.status_code} /////")
            break
              
        for cert in r.json()["certificates"]:
            cert_ids.append(cert)

        if r.json()["count"] < PAGE_SIZE:
            break

        page_num += 1


    # Get current date/time for csv filename
    current_datetime = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    csv_file = f'output_{current_datetime}.csv'
    

    # Write data to CSV file
    with open(csv_file, 'w', newline='', encoding='utf-8') as csv_file:
        # Create a CSV writer object
        csv_writer = csv.writer(csv_file)

        # SECURITY (CWE-1236): neutralise spreadsheet formula leaders so values
        # originating from certificate attributes cannot execute as formulas
        # when the CSV is opened in Excel/LibreOffice.
        def defuse(v):
            s = str(v)
            return "'" + s if s[:1] in ('=', '+', '-', '@', '\t', '\r') else s

        # Write header
        if cert_ids:
            header = cert_ids[0].keys()
            csv_writer.writerow([defuse(key) for key in header])

            # Write data rows
            for row in cert_ids:
                csv_writer.writerow([defuse(row.get(key, '')) for key in header])


    # Print some information
    print(f"Found {len(cert_ids)} active certificates.")    
    print(f"Total paging operations: {page_num}")