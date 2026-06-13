 <#
//---------------------------------------------------------------------------
// CreateCP-KS.ps1
//---------------------------------------------------------------------------
// Copyright (c) 2024 Venafi, Inc. All rights reserved.
//
// This software is licensed by Venafi.
// Additional license terms may apply. The software and its contents are
// provided by Venafi to customers for the purposes of integrating with
// services and platforms. Modification of this script is only allowed to
// update any necessary configuration details. Any sharing of this 
// script or its contents without consent from Venafi is 
// prohibited.
//
// This script is provided "as is" without warranty of any kind.
//
//---------------------------------------------------------------------------
#>

<##################################################################################################
.DESCRIPTION
    Creates Cloud Providers and Cloud Keystores from data exported form a CSVfile.
    The script performs GraphQL mutationa by sending a request to a specified API endpoint.
        It utilizes a secure API key (TPPLApiKey) for authentication.
        The script is designed to create cloud providers and cloud keysores with specific configurations,
        such as cloud provider name, owning team, authorized teams, ACM Account ID and ACM IAM Role.
        The script reads the required data from a CSV file, where each row represents a set of parameters for the GraphQL mutations.
        For each row in the CSV file, the script extracts the necessary parameters, constructs a GraphQL mutation requests, and sends it to the GraphQL API endpoint.
        The response is then processed, and the script may print the result or handle errors accordingly.
.PARAMETER ApiUrl
    A variable representing the URL of the GraphQL API endpoint.
        For example https://api.venafi.cloud/graphql
.PARAMETER TPPLApiKey
    A variable that stores the API key required for authentication
.PARAMETER CsvPath
     A variable that stores the path to the .csv file that contains the Cloud Provider and Cloud Keysore data.
.NOTES
    Executin example
    ./CreateCP-KS.ps1 -ApiUrl "https://api.venafi.cloud/graphql" -TPPLApiKey "3c9e4ca1-7b6c-4c2c-8bec-f955b6fc5a9c" -CsvPath "./data.csv"
    Multivalue parameters in the CSV are separated by ';'
##################################################################################################>

param(
    [string]$ApiUrl,
    [string]$TPPLApiKey,
    [string]$CsvPath
)

# Check if required parameters are provided
if (-not $ApiUrl -or -not $TPPLApiKey -or -not $CsvPath) {
    Write-Host "Please provide: -ApiUrl <Api_Url> -TPPLApiKey <API_KEY> -CsvPath <CSV_Path>"
    exit 1
}

# Set headers
$headers = @{
    "Content-Type" = "application/json"
    "tppl-api-key" = $TPPLApiKey
}

function CheckIfCPExists([string] $cloudProviderName) {
    $query = @"
    query CloudProviders {
        cloudProviders {
          nodes {
            name
          }
        }
      }
"@

    # Create the GraphQL request body
    $body = @{
        query = $query
    } | ConvertTo-Json

    # Make the GraphQL API call
    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop
        $cloudProviders = $response.data.cloudProviders.nodes.name
    }
    catch {
        Write-Host "Get query Failed for Cloud Provider '$cloudProviderName'. Error: $_"
    }
    # Check if the Cloudprovider already exists
    if ($cloudProviders -contains $cloudProviderName) {
        Write-Host "A Cloudprovider with name '$cloudProviderName' already exists."
        return $true
    }
    return $false
}

function CreateCloudProviderMutation ([string] $cloudProviderName, [string] $teamId, [string] $authorizedTeamId, [string] $cloudProviderType, [string] $awsRole, [string] $awsAccountId) {

    # Validate UUID format for teamId
    $uuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    if ($teamId -notmatch $uuidPattern) {
        Write-Host "Invalid teamId format: '$teamId'. Must be a valid UUID."
        return
    }

    # Validate cloudProviderType against allowlist
    $validTypes = @('AWS', 'AZURE', 'GCP')
    if ($cloudProviderType -notin $validTypes) {
        Write-Host "Invalid cloudProviderType: '$cloudProviderType'. Must be one of: $($validTypes -join ', ')"
        return
    }

    # Build authorizedTeams array for variables
    $authTeamsArray = @()
    if (-not [string]::IsNullOrEmpty($authorizedTeamId)) {
        $authTeamsArray = @($authorizedTeamId)
    }

    # GraphQL mutation with variables (literal here-string)
    $mutation = @'
mutation Mutation($cloudProviderName: String!, $teamId: ID!, $authorizedTeams: [ID!], $cloudProviderType: CloudProviderType!, $awsRole: String!, $awsAccountId: String!) {
  createCloudProvider(
    input: {
      authorizedTeams: $authorizedTeams
      awsConfiguration: { role: $awsRole, accountId: $awsAccountId }
      name: $cloudProviderName
      teamId: $teamId
      type: $cloudProviderType
    }
  ) {
    name
    id
  }
}
'@

    # Create the GraphQL request body with variables
    $body = @{
        query = $mutation
        variables = @{
            cloudProviderName = $cloudProviderName
            teamId = $teamId
            authorizedTeams = $authTeamsArray
            cloudProviderType = $cloudProviderType
            awsRole = $awsRole
            awsAccountId = $awsAccountId
        }
    } | ConvertTo-Json -Depth 10

    # Make the GraphQL API call
    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "Creationg Cloud Provider: '$cloudProviderName'."
        Write-Host "Response:"
        Write-Host ($response | ConvertTo-Json -Depth 4)
        $cloudProviderId = $response.data.createCloudProvider.id
        return $cloudProviderId
    }
    catch {
        Write-Host "Mutation Failed for Cloud Provider '$cloudProviderName'. Error: $_"
    }
}

function CreateCloudKeystoreForACM([string] $cloudKeystoreName, [string] $teamId, [string] $authorizedTeamId, [string] $cloudProviderId, [string[]] $acmRegions) {

    # Validate UUID format for teamId and cloudProviderId
    $uuidPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    if ($teamId -notmatch $uuidPattern) {
        Write-Host "Invalid teamId format: '$teamId'. Must be a valid UUID."
        return
    }
    if ($cloudProviderId -notmatch $uuidPattern) {
        Write-Host "Invalid cloudProviderId format: '$cloudProviderId'. Must be a valid UUID."
        return
    }

    # Build authorizedTeams array for variables
    $authTeamsArray = @()
    if (-not [string]::IsNullOrEmpty($authorizedTeamId)) {
        $authTeamsArray = @($authorizedTeamId)
    }

    foreach ($region in $acmRegions) {

        # GraphQL mutation with variables (literal here-string)
        $mutation = @'
    mutation CreateCloudKeystore($name: String!, $teamId: ID!, $cloudProviderId: ID!, $region: String!, $authorizedTeams: [ID!]) {
        createCloudKeystore(
          input: {
            name: $name
            teamId: $teamId
            cloudProviderId: $cloudProviderId
            acmConfiguration: { region: $region }
            authorizedTeams: $authorizedTeams
            type: ACM
          }
        ) {
          id
          name
        }
    }
'@
        # Create the GraphQL request body with variables
        $body = @{
            query = $mutation
            variables = @{
                name = "$cloudKeystoreName-$region"
                teamId = $teamId
                cloudProviderId = $cloudProviderId
                region = $region
                authorizedTeams = $authTeamsArray
            }
        } | ConvertTo-Json -Depth 10

        # Make the GraphQL API call
        try {
            $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop
            Write-Host "Creating Cloud Keysore: '$cloudKeystoreName-$region'."
            Write-Host "Response:"
            Write-Host ($response | ConvertTo-Json -Depth 4)
        }
        catch {
            Write-Host "Create Cloud Keystore Failed. Error: $_"
        }
    }
}

function ValidateCloudProvider([string] $cloudProvidedId, [string] $cloudProviderName) {

    $mutation = @"
mutation ValidateCloudProvider {
    validateCloudProvider(
          cloudProviderId: "$cloudProvidedId"
    ) {
     result
    }
}
"@

    # Create the GraphQL request body
    $body = @{
        query = $mutation
    } | ConvertTo-Json

    # Make the GraphQL API call
    try {
        $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "Validating Cloud Provider: '$cloudProviderName'"
        Write-Host "Response:"
        Write-Host ($response | ConvertTo-Json -Depth 4)
        return $response.data.validateCloudProvider.result
    }
    catch {
        Write-Host "Validate Cloud Provider Failed. Error: $_"
    }
}

function ReadCsvAndExecuteMutations ([string]$CsvPath) {
    
    # Check if CSV path is provided
    if (-not $CsvPath) {
        Write-Host "Path to CSV file missing!"
        return
    }

    # Read CSV file
    $csvData = Import-Csv -Path $CsvPath

    foreach ($row in $csvData) {
        # Extract data into variables for each row
        $cloudProviderName = $row.CloudProviderName
        $teamId = $row.TeamId
        $authorizedTeamId = $row.AuthorizedTeamId -split ';'
        $cloudProviderType = $row.CloudProviderType
        $awsRole = $row.AWSRole
        $awsAccountId = $row.AWSAccountId
        #Keystore data
        $ckName = $row.CkName
        $ckTeamId = $row.CkTeamId
        $ckAuthorizedTeamId = $row.CkAuthorizedTeamId -split ';'
        $acmRegions = $row.AcmRegions -split ';'

        #Check if the provided CloudProviderName exists
        if (CheckIfCPExists -cloudProviderName $cloudProviderName) {
            continue
        }
        #Use extracted data to Create Cloud Provider
        $cpID = CreateCloudProviderMutation -cloudProviderName $cloudProviderName -teamId $teamId  -authorizedTeamId $($authorizedTeamId -join '","') -cloudProviderType $cloudProviderType -awsRole $awsRole -awsAccountId  $awsAccountId
        #Validate(Test Access) the cloud provider
        if (-not [string]::IsNullOrEmpty($cpID)) {
            $validationResult =  ValidateCloudProvider -cloudProvidedId $cpID -cloudProviderName $cloudProviderName
        }
        #If no data for CloudKeystore is provided skip execution of createCloudKeystore mutation
        if (-not $ckName -or $validationResult -eq "NOT_VALIDATED") {
            Write-Host "Skipping 'Create CloudKeystore For ACM': No CloudKeystore Data found for '$cloudProviderName' or Cloud Provider was not validated successfully!"
        }
        else {
            CreateCloudKeystoreForACM -cloudKeystoreName $ckName -teamId $ckTeamId -authorizedTeamId $($ckAuthorizedTeamId -join '","') -cloudProviderId $cpID -acmRegion $acmRegions
        }

    }
}

ReadCsvAndExecuteMutations -CsvPath $CsvPath