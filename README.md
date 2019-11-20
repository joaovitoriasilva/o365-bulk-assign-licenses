# o365-bulk-assign-licenses
Office 365 Bulk Assign licenses (PowerShell AzureAD V2)

DISCLAIMER: The cmdlets used in this script may change. Test this script before using it in a production environment.

Script changes:
 - 1.0 - Initial version;
 - 1.1 - Changed return to continue in foreach loop;
   - Changed user usage location validation from empty string to $null.

Based on the service plans provided by the user, the script will assign a new Office 365 license or change the service plans of the desired license. If the user already has service plans activated for that SKU, the script will add them to the flow in order to mantain that service plans activated.
 - Example: If user has Exchange role activated and the service plans provided are SharePoint Online, in the end, the user will have both the service plans activated.

This script uses an additional CSV file expected to be in the same location of the script file with the following nomenclature: LicenseUsers.csv. This CSV is expected to have a column named "UserPrincipalName" with the UserPrincipalName of the users that are aimed to be targeted.

Notes:
 - Change the $SKU and $enabledPlans variables to the desired values;
 - To view the available subscription SKUs: Get-AzureADSubscribedSku;
 - To view the available service plans for a specific SKU: (Get-AzureADSubscribedSku | Where-Object {$_.SkuPartNumber -eq 'EMSPREMIUM'}).ServicePlans;
 - Do "get-help .\AddLicenses.ps1 -full" to see the script help.
 
Requirements:
 - This script requires Azure AD V2 Module. Get AzureAD V2 Module from https://docs.microsoft.com/en-us/powershell/module/azuread/?view=azureadps-2.0;
 
 The sample scripts are provided AS IS without warranty of any kind.