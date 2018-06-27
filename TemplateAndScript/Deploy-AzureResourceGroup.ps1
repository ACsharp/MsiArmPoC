#Requires -Version 3.0

Param(
    [string] $ResourceGroupLocation = 'West Europe',
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [switch] $ValidateOnly
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ','_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force

if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                                                                  -TemplateFile $TemplateFile `
                                                                                  -TemplateParameterFile $TemplateParametersFile `
                                                                                  @OptionalParameters)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {
    New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       @OptionalParameters `
                                       -Force `
                                       -ErrorVariable ErrorMessages
	
    Write-Host "Waiting for creation of MSI service principal to complete..."
    Start-Sleep -s 15	

    Write-Host "Setting permissions..."
	$params = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
	$msi = ((Get-AzureRMWebApp -Name $params.parameters.websitename.value) | select Name -Expand Identity).PrincipalId
	Write-Output "MSI service principal: $($msi)"
    $rg = Get-AzureRMResourceGroup -Name $ResourceGroupName
    $scope = "$($rg.ResourceId)/providers/Microsoft.ServiceBus/namespaces/$($params.parameters.serviceBusNamespaceName.value)/entities/$($params.parameters.serviceBusQueueName.value)"
	
    $existingAssigment = Get-AzureRmRoleAssignment -ObjectId $msi -RoleDefinitionName "Owner" -Scope $scope
    if ($existingAssigment) {
        Write-Host "Role already assigned."
    }
    else
    {
        New-AzureRmRoleAssignment -ObjectId $msi -RoleDefinitionName "Owner" -Scope $scope
    }
    
    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}