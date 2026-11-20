<#
.\AzCheckRegionForModelCapacity.ps1 -SubscriptionId "135cfae9-54fd-43e2-bb1b-a4ebc884d023" -Region "eastus2" -ModelName "gpt-4o-mini"
#>

param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$Region,

    [Parameter(Mandatory)]
    [string]$ModelName
)

# Requires:
# az login
# az account set --subscription <subscription>

$accessToken = az account get-access-token `
    --resource https://management.azure.com `
    --query accessToken `
    -o tsv

$uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Region/models?api-version=2024-10-01"

$response = Invoke-RestMethod `
    -Method Get `
    -Uri $uri `
    -Headers @{
        Authorization = "Bearer $accessToken"
    }

$matches = $response.value |
    Where-Object {
        $_.model.name -like "*$ModelName*"
    }

if ($matches) {
    Write-Host "Model found in region $Region" -ForegroundColor Green

    $matches | Select-Object `
        @{Name="Model";Expression={$_.model.name}},
        @{Name="Version";Expression={$_.model.version}},
        @{Name="Lifecycle";Expression={$_.model.lifecycleStatus}}
}
else {
    Write-Host "Model '$ModelName' is not available in $Region" -ForegroundColor Red
}