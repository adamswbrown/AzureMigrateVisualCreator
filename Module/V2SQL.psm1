#V2SQL
Set-StrictMode -Version latest
$global:contentType = 'application/json' 

#Helper
function Get-AzCachedAccessToken() {
    $ErrorActionPreference = 'Stop'

    if (-not (Get-Module Az.Accounts)) {
        Import-Module Az.Accounts
    }
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile

    $currentAzureContext = Get-AzContext

    if (!$currentAzureContext) {
        Write-Error "Ensure you have logged in before calling this function."
    }

    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}
#helperend


function Get-AzureMigrate-assessedSqlDatabases {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [switch]$V2API

  
    )
#GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/migrateProjects/{migrateProjectName}/databaseInstances?api-version=2018-09-01-preview

if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#"/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/assessedSqlDatabases"
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/assessedSqlDatabases?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}

function Get-AzureMigrate-assessedSqlDatabase {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [Parameter(Mandatory = $true)][string]$assessedSqlDatabaseName,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
        #"/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/assessedSqlDatabases/{assessedSqlDatabaseName}"
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/assessedSqlDatabases/$($assessedSqlDatabaseName)?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}


function Get-AzureMigrate-assessedSqlInstances {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
                [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
        #        "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/assessedSqlInstances"
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/assessedSqlInstances/?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}

function Get-AzureMigrate-assessedSqlinstance{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [Parameter(Mandatory = $true)][string]$assessedSqlInstanceName,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#        "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/assessedSqlInstances/{assessedSqlInstanceName}": 
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/assessedSqlInstances/$($assessedSqlInstanceName)?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}


function Get-AzureMigrate-assessedSqlMachines{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#   "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/assessedSqlMachines":: 
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/$($assessedSqlMachines)?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}
function Get-AzureMigrate-assessedSqlMachine{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [Parameter(Mandatory = $true)][string]$assessedSqlMachineName,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#        },
#"/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/assessedSqlMachines/{assessedSqlMachineName}":
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/assessedSqlMachines/($assessedSqlMachineName)?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}





function Get-AzureMigrate-AssessedSQLRecomendations{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$assessmentName,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#        },
#        "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/recommendedAssessedEntities": 
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/recommendedAssessedEntities?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}


function Get-AzureMigrate-AssessedSQLRecomendation{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$recommendedAssessedEntityName,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#        },
#       "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments/{assessmentName}/recommendedAssessedEntities/{recommendedAssessedEntityName}": {
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$assessmentName/recommendedAssessedEntities/$($recommendedAssessedEntityName)?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}


function Get-AzureMigrate-SQLAssessments{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#        },
#       #/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments"
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}


function Get-AzureMigrate-SQLAssessment{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$Groupname,
        [Parameter(Mandatory = $true)][string]$assessmentName,
        [switch]$V2API

  
    )
#
if($V2API){
$APIVersion = "2022-02-02-preview"
}

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
#        },
#       #/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentprojects/{projectName}/groups/{groupName}/sqlAssessments"
$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentprojects/$projectName/groups/$Groupname/sqlAssessments/$($assessmentName)?api-version=$($APIVersion)"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}

