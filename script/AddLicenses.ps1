# This script requires Azure AD V2 Module
# Get AzureAD V2 Module from https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0  

<#

.SYNOPSIS
This script will assign a new Office 365 license or change the service plans of the desired license.

.DESCRIPTION
Based on the service plans provided by the user, the script will assign a new Office 365 license or change the service plans of the desired license. If the user already has service plans activated for that SKU, the script will add them to the flow in order to mantain that service plans activated.
Example: If user has Exchange role activated and the service plans provided are SharePoint Online, in the end, the user will have both the service plans activated.

This script uses an additional CSV file expected to be in the same location of the script file with the following nomenclature: LicenseUsers.csv. This CSV is expected to have a column named "UserPrincipalName" with the UserPrincipalName of the users that are aimed to be targeted.

Change the $SKU and $enabledPlans variables to the desired values.
To view the available subscription SKUs: Get-AzureADSubscribedSku
To view the available service plans for a specific SKU: (Get-AzureADSubscribedSku | Where-Object {$_.SkuPartNumber -eq 'EMSPREMIUM'}).ServicePlans

.NOTES
Script created by João Vitória Silva: https://www.linkedin.com/in/joao-v-silva/
Version 1.1 - AddLicenses_v1.1-JVS-17-07-2018
Script changes:	1.0 - Initial version.
                1.1 - Changed return to continue in foreach loop;
                    - Changed user usage location validation from empty string to $null.

.EXAMPLE
.\AddLicenses.ps1

#>

$SKU = "EMSPREMIUM"
$enabledPlans = @("AAD_PREMIUM","MFA_PREMIUM")

# Setting script version variable
$scriptVersion="AddLicenses_v1.1-JVS-17-07-2018"

Write-Host "Starting script $scriptVersion" -ForegroundColor "White"

Import-Module AzureAD
$Credential = Get-Credential
Connect-AzureAD -Credential $Credential

# Setting PSScriptRoot variable if PowerShell version minor than 3
if ($PSVersionTable.PSVersion.Major -lt 3) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    write-host "$PSScriptRoot"
}

# Import CSV with users information
try{
    $users = Import-Csv "$PSScriptRoot\LicenseUsers.csv"
}catch{
    Write-Host "Unable to find the users CSV file. Aborting script!" -ForegroundColor "Red"
    Disconnect-AzureAD
    exit 1
}

try{
    $targetedLicenseSku = Get-AzureADSubscribedSku | Where-Object {$_.SkuPartNumber -eq $SKU}
}catch{
    Write-Host "Unable to get Subscribed Skus. Aborting script!" -ForegroundColor "Red"
    Disconnect-AzureAD
    exit 2
}

foreach ($user in $users) {
    # Querying AzureAD for user object
    $userObject = Get-azureaduser -ObjectId $user.UserPrincipalName
    # Will iterate current licenses to check if the provided SKU already has sublicenses applied
    foreach ($license in $userObject.AssignedLicenses){
        if($license.SkuId -eq $targetedLicenseSku.SkuId){
            foreach ($skuServicePlan in $targetedLicenseSku.ServicePlans){
                foreach ($userServicePlan in $userObject.AssignedPlans){
                    if($skuServicePlan.ServicePlanId -eq $userServicePlan.ServicePlanId){
                        $aux = $false
                        foreach ($plan in $enabledPlans){
                            if($skuServicePlan.ServicePlanName -eq $plan){
                                $aux = $true
                            }
                        }
                        if(!$aux){
                            # If sublicense is already applied to the user, will add it to the $enabledPlans variable to remain applied after the configuration
                            $enabledPlans += $skuServicePlan.ServicePlanName
                        }
                    }
                }
            }
        }
    }
    # All sublicenses that will not be applied based on the $enabledPlans variable
    $disabledPlans = $targetedLicenseSku.ServicePlans | ForEach-Object -Process { 
        $_ | Where-Object -FilterScript {$_.ServicePlanName -notin $enabledPlans }
    }
    # Create the objects we'll need to add and remove licenses
    try{
        $licenseToAssign = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    }catch{
        Write-Host "Unable to create object license for the user $($user.UserPrincipalName). License not assigned!" -ForegroundColor "Red"
        return
    }
    $licenseToAssign.SkuId = $targetedLicenseSku.SkuId
    $licenseToAssign.DisabledPlans = $disabledPlans.ServicePlanId

    # Create the AssignedLicenses Object
    try{
        $AssignedLicenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    }catch{
        Write-Host "Unable to create object license for the user $($user.UserPrincipalName). License not assigned!" -ForegroundColor "Red"
        return
    }
    $AssignedLicenses.AddLicenses = $licenseToAssign
    $AssignedLicenses.RemoveLicenses = @()

    # Assign usage location PT if field UsageLocation empty
    # Field UsageLocation needs to have a valid value to be possible to assign new licenses 
    if($userObject.UsageLocation -eq $null){
        try{
            Set-AzureADUser -ObjectId $user.UserPrincipalName -UsageLocation "PT"
            Write-Host "Usage Location for user $($user.UserPrincipalName) was not set. Added Usage Location PT to the user!" -ForegroundColor "Yellow"
        }catch{
            Write-Host "Unable to set usage location for the user $($user.UserPrincipalName). License not assigned!" -ForegroundColor "Red"
            continue
        }
    }
    # Assign license previously created
    try{
        Set-AzureADUserLicense -ObjectId $user.UserPrincipalName -AssignedLicenses $AssignedLicenses
        Write-Host "License added to user $($user.UserPrincipalName)" -ForegroundColor "Green"
    }catch{
        Write-Host "Unable to set license for the user $($user.UserPrincipalName). License not assigned!" -ForegroundColor "Red"
        continue
    }
}

try{
    Disconnect-AzureAD
}catch{
    Write-Host "Unable to disconnect from AzureAD!" -ForegroundColor "Red"
}

Write-Host "Ending script $scriptVersion" -ForegroundColor "White"