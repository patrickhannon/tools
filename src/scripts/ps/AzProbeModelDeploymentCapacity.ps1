<#
.\Test-AzureOpenAICapacity.ps1 `
    -SubscriptionId "135cfae9-54fd-43e2-bb1b-a4ebc884d023" `
    -ResourceGroupName "my-rg" `
    -CognitiveAccountName "my-foundry-resource" `
    -DeleteSuccessfulDeployments
#>

param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$CognitiveAccountName,

    [switch]$DeleteSuccessfulDeployments
)

$Models = @(
    "gpt-4o-mini",
    "gpt-4o",
    "gpt-4.1-mini",
    "gpt-4.1",
    "o3-mini",
    "o3"
)

$Regions = @(
    "eastus",
    "eastus2",
    "westus",
    "westus2",
    "westus3",
    "northcentralus",
    "southcentralus",
    "canadacentral"
)

$Results = New-Object System.Collections.Generic.List[object]

az account set --subscription $SubscriptionId

foreach ($Region in $Regions)
{
    Write-Host "`n===== Testing Region: $Region =====" -ForegroundColor Cyan

    foreach ($Model in $Models)
    {
        $DeploymentName = ("quota-test-" + $Model.Replace(".","-")).ToLower()

        Write-Host "Testing $Model" -ForegroundColor Yellow

        try
        {
            $Json = @{
                sku = @{
                    name     = "Standard"
                    capacity = 1
                }
                properties = @{
                    model = @{
                        format  = "OpenAI"
                        name    = $Model
                        version = "latest"
                    }
                }
            } | ConvertTo-Json -Depth 10

            $TempFile = Join-Path $env:TEMP "$DeploymentName.json"
            $Json | Set-Content $TempFile

            $Output = az cognitiveservices account deployment create `
                --resource-group $ResourceGroupName `
                --name $CognitiveAccountName `
                --deployment-name $DeploymentName `
                --model-name $Model `
                --model-format OpenAI `
                --sku-name Standard `
                --sku-capacity 1 `
                --only-show-errors 2>&1

            Write-Host "SUCCESS" -ForegroundColor Green

            $Results.Add([PSCustomObject]@{
                Region = $Region
                Model  = $Model
                Result = "Success"
                Error  = ""
            })

            if ($DeleteSuccessfulDeployments)
            {
                az cognitiveservices account deployment delete `
                    --resource-group $ResourceGroupName `
                    --name $CognitiveAccountName `
                    --deployment-name $DeploymentName `
                    --yes `
                    --only-show-errors | Out-Null
            }
        }
        catch
        {
            $Message = $_.Exception.Message

            $Status =
                if ($Message -match "InsufficientQuota")
                {
                    "InsufficientQuota"
                }
                elseif ($Message -match "not supported")
                {
                    "ModelNotSupported"
                }
                elseif ($Message -match "SpecialFeatureOrQuotaIdRequired")
                {
                    "RequiresApproval"
                }
                else
                {
                    "OtherError"
                }

            Write-Host $Status -ForegroundColor Red

            $Results.Add([PSCustomObject]@{
                Region = $Region
                Model  = $Model
                Result = $Status
                Error  = $Message
            })
        }
    }
}

$CsvPath = ".\AzureOpenAI-CapacityResults.csv"

$Results |
    Sort-Object Model,Region |
    Export-Csv $CsvPath -NoTypeInformation

Write-Host "`nResults written to $CsvPath" -ForegroundColor Green

$Results |
    Sort-Object Model,Region |
    Format-Table -AutoSize