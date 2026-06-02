# CreateCP-KS.ps1

## Purpose

This PowerShell script automates the creation of cloud providers and cloud keystores within a Venafi platform. It utilizes GraphQL mutations to interact with the Venafi platform and reads configuration data from a provided CSV file.

## Author

Venafi, Inc.

## Requirements

* PowerShell version 3.0 or later
* Venafi API credentials (TPPLApiKey)

## Dependencies

None

## Usage

1. Set the TPPL_API_KEY environment variable with your Venafi API key (do not pass it on the command line).
2. Prepare a CSV file with the required configuration data (see CSV format below).
3. Run the script with the following parameters:

   ```powershell
   $env:TPPL_API_KEY = "your_api_key"
   ./CreateCP-KS.ps1 -ApiUrl "https://api.venafi.cloud/graphql" -CsvPath "path/to/your/data.csv"
   ```
so there would not be mistakes with the API URL
   

## CSV Format

| Column Name        | Description                                                                          |
|---------------------|-----------------------------------------------------------------------------------------------|
| CloudProviderName  | Name of the cloud provider to create                                                     |
| TeamId              | ID of the team that owns the cloud provider                                                  |
| AuthorizedTeamId    | (Optional) semicolon-separated list of authorized teams                                 |
| CloudProviderType   | Type of cloud provider (e.g., AWS, Azure)                                                    |
| AWSRole             | (For AWS providers) IAM role for accessing AWS                                          |
| AWSAccountId        | (For AWS providers) AWS account ID                                                      |
| CkName              | (Optional) Name of the cloud keystore to create                                            |
| CkTeamId            | (Optional) ID of the team that owns the keystore                                            |
| CkAuthorizedTeamId  | (Optional) Comma-separated list of authorized teams for the keystore |
| AcmRegions          | (Optional) Comma-separated list of ACM regions                                         |

## Output

The script will print messages to the console indicating the progress of the operations:

* Successful creation of cloud providers and keystores will be displayed with their IDs and names.
* Any errors or failures will also be displayed.

## Error Handling

The script includes basic error handling for API calls and CSV parsing. Detailed error messages are displayed to the console.

## License

Copyright (c) 2024 Venafi, Inc. All rights reserved. Additional license terms may apply.

## Important Notes

* The script is provided "as is" without warranty of any kind.
* Modification of the script is only allowed to update configuration details.
* Sharing of this script or its contents without consent from Venafi is prohibited.

## Troubleshooting

* Double-check the API URL, API key, and CSV file path.
* Ensure the CSV file is formatted correctly.
* Refer to the Venafi documentation for more information on AWS integration
