<#
.\AzCheckRegionNorthAmericaForModelCapacity.ps1 -SubscriptionId "135cfae9-54fd-43e2-bb1b-a4ebc884d023"
#>
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId
)

$NorthAmericaRegions = @(
    "eastus",
    "eastus2",
    "northcentralus",
    "southcentralus",
    "westus",
    "westus2",
    "westus3",
    "canadacentral",
    "canadaeast"
)

# Cost classifications (maintain as needed)
$CostMap = @{
    "gpt-4o-mini"           = "Low"
    "gpt-4.1-mini"          = "Low"
    "gpt-4.1-nano"          = "Very Low"
    "gpt-4o"                = "Medium"
    "gpt-4.1"               = "Medium"
    "o3-mini"               = "Medium"
    "o1-mini"               = "Medium"
    "o3"                    = "High"
    "o1"                    = "High"
    "gpt-5"                 = "Premium"
}

$Token = az account get-access-token `
    --resource https://management.azure.com `
    --query accessToken `
    -o tsv

$Results = @()

foreach ($Region in $NorthAmericaRegions)
{
    Write-Host "Checking $Region..." -ForegroundColor Cyan

    try
    {
        $Uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CognitiveServices/locations/$Region/models?api-version=2024-10-01"

        $Response = Invoke-RestMethod `
            -Method Get `
            -Uri $Uri `
            -Headers @{
                Authorization = "Bearer $Token"
            }

        foreach ($ModelEntry in $Response.value)
        {
            if ($ModelEntry.kind -ne "OpenAI")
            {
                continue
            }

            $ModelName = $ModelEntry.model.name
            $Version = $ModelEntry.model.version

            # Skip image/audio models
            if (
                $ModelName -match "image" -or
                $ModelName -match "whisper" -or
                $ModelName -match "tts"
            )
            {
                continue
            }

            $CostTier = "Unknown"

            foreach ($Key in $CostMap.Keys)
            {
                if ($ModelName -like "*$Key*")
                {
                    $CostTier = $CostMap[$Key]
                    break
                }
            }

            $Results += [PSCustomObject]@{
                Region          = $Region
                Model           = $ModelName
                Version         = $Version
                LifecycleStatus = $ModelEntry.model.lifecycleStatus
                CostTier        = $CostTier
            }
        }
    }
    catch
    {
        Write-Warning "Failed querying $Region"
    }
}

$Results |
    Sort-Object Model,Region |
    Format-Table -AutoSize

$Results |
    Export-Csv `
        -Path ".\AzureOpenAI-NorthAmerica-Models.csv" `
        -NoTypeInformation

Write-Host "`nResults exported to AzureOpenAI-NorthAmerica-Models.csv" -ForegroundColor Green