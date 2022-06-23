Set-StrictMode -Version latest
$global:contentType = 'application/json' 
#Helper Start
function Generate-Container-Name
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string] $name
    )

	$name = $name.ToLower()
	$name = $name.Replace(" ","-")
    $pattern = '[^a-z0-9-]'
	$name = $name -replace $pattern, ''
	while ($name -match "--") { $name = $name.Replace("--","-") }
	if ($name[-1] -eq "-") { $name = $name.Substring(0, $name.Length - 1) }
    if ($name[0] -eq "-") { $name = $name.Substring(1) }
	if ($name.Length -gt 63) { $name = $name.Substring(0,63) }
	if ($name.Length -eq 2) { $name = $name + "-" }
	
	return $name
}
Function Get-File
{  
 [System.Reflection.Assembly]::LoadWithPartialName(“System.windows.forms”) |
 Out-Null

 $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
 $OpenFileDialog.filter = “All files (*.*)| *.*”
 $OpenFileDialog.ShowDialog() | Out-Null
 $OpenFileDialog.filename
} #end function Get-FileName
function Create-CustomerArea {
    param (
        [Parameter(Mandatory=$true)]
        [string] $customername
    )
    Set-location $folder_path
set-location ..
$Root = Get-Location 
If (!(test-path "Customers")) {
    Write-Host "Creating Customer Holding Area" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path "$Root\Customers" 
}
else {
    Write-Host "Customer Holding Area Exisits" -ForegroundColor Cyan
}
Set-location "Customers"
If (!(test-path $customerName)) {
    Write-Host "Creating Customer Folder for $($customerName)" -ForegroundColor Cyan
    $cus = New-Item -ItemType Directory -Force -Path $customerName
    $root = $cus.FullName
}
else {
    Write-Host "Customer Folder for $($customerName) Exisits" -ForegroundColor Cyan
}
Set-Location $customerName
$Root = Get-Location 
}
function Create-Assessment-Folders {
    param (
              [Parameter(Mandatory = $true)][string]$dts_stamp
              
       )
Write-Host "Setting up Download Diretories" -ForegroundColor Yellow
$vmassessmentsfolder = new-item -type directory -path ".\VM Assessments\$($dts_stamp)" -Force
$SQLassessmentsfolder = new-item -type directory -Path ".\SQL Assessments\$($dts_stamp)" -Force
#$DepdedancyDatafolder = new-item -type directory -path ".\Depdedancy Data\$($dts_stamp)" -Force
$APIInfomationfolder = new-item -type directory -path ".\API Infomation\$($dts_stamp)" -Force
$EnvironmentContext = new-item -type directory -path ".\Environment Context Information" -Force


$vmassessmentsfolder = $vmassessmentsfolder.name 
$SQLassessmentsfolder = $SQLassessmentsfolder.name
#$DepdedancyDatafolder = $DepdedancyDatafolde.Name
$APIInfomationfolder =$APIInfomationfolder.name 
$EnvironmentContextfolder= $EnvironmentContext.name 
}


Function Sleep-Progress($seconds) {
    $s = 0;
    Do {
        $p = [math]::Round(100 - (($seconds - $s) / $seconds * 100));
        Write-Progress -Activity "Waiting..." -Status "$p% Complete:" -SecondsRemaining ($seconds - $s) -PercentComplete $p;
        [System.Threading.Thread]::Sleep(1000)
        $s++;
    }
    While($s -lt $seconds);
    
}

function Get-AM-Customers {
    # Wiql - Query By Id - https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/wiql/query-by-id
    # Service: Work Item Tracking
    # API Version: 6.0

    $token = 'ck63h2qrd57hmjmgmaqqibjgfdkznwooznxt7kostw45l6jeqexq'
    $token = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($token)"))
    $header = @{authorization = "Basic $token"}

    $URL_values = @(
         $organization = 'kmuller0304'
         $project = 'eb63f261-d59b-429f-b144-957516ae97a0'
         $team = '15639759-aba1-4e74-aeac-d4f5e9fe7eea'
        $query = 'ab2ee9a9-b0a8-4c85-945f-c50ae3d9a242'
    )

    $Params = @{
         Uri = "https://dev.azure.com/${organization}/${project}/${team}/_apis/wit/wiql/${query}?api-version=6.0"
        Headers = $header
        Method = "Get"
    }

    $results = Invoke-RestMethod @Params
    $list_work_items_IDs = $results.workItems.Id -join ","

    # Work Items - List - https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/list
    # Service: Work Item Tracking
    # API Version: 6.0

    $URL_values = @(
         $organization = 'kmuller0304'
         $project = 'eb63f261-d59b-429f-b144-957516ae97a0'
        $ids = $list_work_items_IDs
        $field_to_show = 'System.Title,Custom.AADtenantID'
    )

    $Params = @{
         Uri = "https://dev.azure.com/${organization}/${project}/_apis/wit/workitems?ids=${ids}&fields=${field_to_show}&api-version=6.0"
        Headers = $header
        Method = "Get"
    }

    $results = Invoke-RestMethod @Params
    $return_value = $results.value.fields
    $return_value = $return_value | Select-Object -Property @{Label="Customer";Expression={$_.{System.Title}}}, @{label="AAD tenant ID";Expression={$_.{Custom.AADtenantID}}}
    return $return_value
}


Function CreateStorageContainer {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$CustomerName,
        [Parameter(Mandatory = $true)][string]$Toolset,
        [Parameter(Mandatory = $true)][string]$datestamp

    )  
    Write-Host -ForegroundColor Green "Creating storage container.."  
    ## Get the storage account in which container has to be created  
    $storageAcc = Get-AzStorageAccount -ResourceGroupName "AzureMigrateExports" -Name "customerexports"
    ## Get the storage account context  
    $ctx = $storageAcc.Context 
 
    ## Check if the storage container exists  
    if (Get-AzStorageContainer -Name $CustomerName -Context $ctx -ErrorAction SilentlyContinue) {  
        Write-Host -ForegroundColor Magenta $customerName "- container already exists."  
    }  
    else {  
        Write-Host -ForegroundColor Magenta $CustomerName "- container does not exist."   
        ## Create a new Azure Storage Account  
        New-AzStorageContainer -Name $CustomerName -Context $ctx  -Permission Off | out-null
        $getAzureContainer = Get-AzStorageContainer -Context $ctx
 
    }  
}     

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

<#
Upload-Files-To-ADLS-Customer-Container function
takes a local path and uploads all the file in dir to ADSL ignoring other sub-directories and files therein
names file just like local filename and mirrors local directories structure

$path_to_files is to be provided relative to local Customers folder
$path_to_files = "customer-a\VM Assessments\2022-05-17_14_30_00\"
possible improvement wait depending on file size
#>
function Upload-Files-To-ADLS-Customer-Container {
    param (
        [Parameter(Mandatory = $true)][string]$path_to_files
        )

    Connect-AzAccount
    Select-AzSubscription -SubscriptionId 54ed6cd8-e3a1-45c6-bcb5-181141404b0a
    $ctx = New-AzStorageContext -StorageAccountName 'customerexports' -UseConnectedAccount

    $customer_name = $path_to_files.Substring(0,$path_to_files.IndexOf('\'))
    $path_without_container_name = $path_to_files.Substring($path_to_files.IndexOf('\') + 1).Replace('\','/')

    try {
        (Get-AzStorageContainer -Context $ctx -Name $customer_name -ErrorAction Stop).Name
        }
    catch {
        New-AzStorageContainer -Context $ctx -Name $customer_name
        }

    try {
        (Get-AzDataLakeGen2Item -Context $ctx -FileSystem $customer_name -Path $path_without_container_name -ErrorAction Stop).Path
        }
    catch {
        New-AzDataLakeGen2Item -Context $ctx -FileSystem $customer_name -Path $path_without_container_name -Directory
        }

    # get number of files in ADLS dir without dir objects itself (this is not recursive)
    $number_of_files_ADLS = Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem $customer_name -Path $path_without_container_name
    $number_of_files_ADLS = $number_of_files_ADLS | Where-Object {-not $_.IsDirectory}
    $number_of_files_ADLS = $number_of_files_ADLS.Path.Count

    # get number of files in local dir without dir objects itself (this is not recursive)
    $local_path = $path_to_Customers_folder + $path_to_files
    $array_filenames = (Get-ChildItem -Attributes !Directory $local_path).Name
    $number_of_files_local = $array_filenames.Count

    # assumes no files with same name already in blob before upload
    $number_of_files_ADLS_expected_after_upload = $number_of_files_ADLS + $number_of_files_local

    # upload a file to a directory; this will overwrite the file if one with same name already exists in dir
    $array_filenames | ForEach-Object {
        New-AzDataLakeGen2Item -Context $ctx -FileSystem $customer_name -Path ($path_without_container_name + $_)  -Source ($local_path + $_) -Force
        Start-Sleep -Seconds 15
        }

    $number_of_files_ADLS = Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem $customer_name -Path $path_without_container_name
    $number_of_files_ADLS = $number_of_files_ADLS | Where-Object {-not $_.IsDirectory}
    $number_of_files_ADLS_after_upload = $number_of_files_ADLS.Path.Count

    if ($number_of_files_ADLS_after_upload -eq  $number_of_files_ADLS_expected_after_upload) {$IS_Uploaded_successfully = $true}
    else {$IS_Uploaded_successfully = $false}

    return $IS_Uploaded_successfully
}


#HelperEnd

#GeneralAzureMigrateStart


  



#Azure Migrate Functions


function Get-AzureMigrateProject {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$TenantId)

    $return_value = @()

    $extract_AM_project_name = {
        $character_positions = ($args[0] | Select-String "/" -AllMatches).Matches.Index
        $start_index_substring = $character_positions[7] + 1
        $length = $character_positions[8] - $start_index_substring
        $args[0].Substring($start_index_substring ,$length)
        }
    
    $extract_rg = {
        $character_positions = ($args[0] | Select-String "/" -AllMatches).Matches.Index
        $start_index_substring = $character_positions[3] + 1
        $length = $character_positions[4] - $start_index_substring
        $args[0].Substring($start_index_substring ,$length)
        }
    
        
    $subscription_IDs = Get-AzSubscription -TenantId $TenantId | Select-Object -Property @{Label="Subscription ID";Expression={$_.Id}}

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    foreach ($n in $subscription_IDs) {
        $url = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Migrate/assessmentProjects?api-version=2019-10-01" -f $n.'Subscription ID'
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET"
        $response = $response.value
        $response = $response | Select-Object @{Label="Azure Migrate project internal name";Expression={$_.name}}, @{Label="Azure Migrate project display name";Expression={& $extract_AM_project_name $_.properties.assessmentSolutionId}}, @{Label="RG";Expression={& $extract_rg $_.properties.assessmentSolutionId}}, @{Label="SubscriptionID";Expression={$n.'Subscription ID'}}
        $return_value += $response}
    return $return_value
}


function Get-AzureMigrateMasterSite {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup
        
    )
#https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OffAzure/MasterSites?api-version=2020-07-07
    #$obj = @()


        $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/MasterSites?api-version=2020-07-07"

     
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    $response.value

}
function Get-AzureMigrateProjectStats {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project
        
    )
#https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OffAzure/MasterSites?api-version=2020-07-07
    #$obj = @()


        $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroup)/providers/Microsoft.Migrate/MigrateProjects/$($project_friendly_name)?api-version=2020-06-01-preview"

     
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    $response

}



function Get-AzureMigrateMachineList {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $false)][string]$SiteName,
        [Parameter(Mandatory = $false)][string]$HyperVSiteName
    )

    $obj = @()
    if ($SiteName) {
    $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/VMwareSites/$($SiteName)/machines?api-version=2020-01-01"
    }
    if ($HyperVSiteName) {
        $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/HyperVSites/$($HyperVSiteName)/machines?api-version=2020-01-01"
    }

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
Write-host "Getting All Machines In Selected Site" -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
  $obj = $obj + $response.value
    while ($response.nextlink) {
        $newresponse = Invoke-RestMethod -Uri $response.nextLink -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
        $response = $newresponse
        $obj = $obj + $response.value
        clear-variable newresponse
    }
    return $obj

}



function Get-AzureMigrateVMwareHealthSiteSummary {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$SiteName
        
    )
#https://management.azure.com/subscriptions/4bd2aa0f-2bd2-4d67-91a8-5a4533d58600/resourceGroups/rahasijaBugBash050919/providers/Microsoft.OffAzure/VMwareSites/rahasapp122119d37csite/healthSummary?api-version=2020-01-01

    #$obj = @()


        $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/VMwareSites/$($SiteName)/healthSummary?api-version=2020-01-01"

     
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    $response.value
}


function Get-AzureMigrateVMwareSiteSumary {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName
        
    )
#https://management.azure.com/subscriptions/4bd2aa0f-2bd2-4d67-91a8-5a4533d58600/resourceGroups/rahasijaBugBash050919/providers/Microsoft.OffAzure/VMwareSites/rahasapp122119d37csite/healthSummary?api-version=2020-01-01

    #$obj = @()

#https://management.azure.com/subscriptions/b15a0658-b37a-4128-b7e8-3a652f299da0/resourceGroups/RG-PHE-UKS-CORE-INFRA/providers/Microsoft.Migrate/MigrateProjects/BigRock-Optimisation?api-version=2020-06-01-preview
        $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.Migrate/MigrateProjects/$($ProjectName)?api-version=2020-06-01-preview"

     
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    $response
}



    function Get-AzureMigrateHyperVHealthSiteSummary {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)][string]$Token,
            [Parameter(Mandatory = $true)][string]$SubscriptionID,
            [Parameter(Mandatory = $true)][string]$ResourceGroup,
            [Parameter(Mandatory = $true)][string]$SiteName
            
        )
    #https://management.azure.com/subscriptions/4bd2aa0f-2bd2-4d67-91a8-5a4533d58600/resourceGroups/rahasijaBugBash050919/providers/Microsoft.OffAzure/VMwareSites/rahasapp122119d37csite/healthSummary?api-version=2020-01-01
    
        #$obj = @()
    
    
            $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/HyperV/$($SiteName)/healthSummary?api-version=2020-01-01"
    
         
        $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
        $headers.Add("Authorization", "Bearer $Token")
    
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
        #$obj += $response.Substring(1) | ConvertFrom-Json
        #return (_formatResult -obj $obj -type "AzureMigrateProject")
        $response.value
    
        }
       




function Get-AzureMigrateDiscoveredMachine {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $false)][string]$GroupName,
        [Parameter(Mandatory = $false)]$HyperVSiteName,
        [switch]$SQL,
        [switch]$SQL_new,
        [switch]$Import,
        [switch]$AVS,
        [switch]$IIS

    )

    $obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/machines?api-version=2019-05-01&pageSize=2000" -f $SubscriptionID, $ResourceGroup, $Project
    if ($GroupName) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentprojects/{2}/machines?api-version=2019-05-01&pageSize=2000&%24filter=Properties/GroupName%20eq%20'{3}'" -f $SubscriptionID, $ResourceGroup, $Project, $GroupName
    }
    if ($HyperVSiteName) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.OffAzure/HyperVSites/{3}/machines?api-version=2020-01-01&pageSize=2000" -f $SubscriptionID, $ResourceGroup, $Project, $HyperVSiteName
    }
    if ($SQL) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/machines?api-version=2019-05-01&pageSize=100&%24filter=(Properties/SqlInstancesCount%20gt%200)" -f $SubscriptionID, $ResourceGroup, $Project
    }
    if ($Import) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/machines?api-version=2019-05-01&pageSize=100&%24filter=contains(Properties/DiscoveryMachineArmId%2C'ImportSites')" -f $SubscriptionID, $ResourceGroup, $Project
    }
    if ($AVS) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/machines?api-version=2019-05-01&pageSize=100&%24filter=contains(Properties/DiscoveryMachineArmId,'VMwareSites/AzureMigCOL015179site')" -f $SubscriptionID, $ResourceGroup, $Project
    }
    if ($IIS) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/machines?api-version=2019-05-01&pageSize=100&%24filter=(Properties%2FIsDeleted%20eq%20false)%20and%20(Properties%2FWebAppDiscovery%2FTotalWebServerCount%20gt%200)%26totalRecordCount%3D266" -f $SubscriptionID, $ResourceGroup, $Project
    }
    if ($SQL_new) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/machines?api-version=2019-05-01&pageSize=100&%26%60%24filter%3D(Properties%2FIsDeleted%20eq%20false)%20and%20(Properties/SqlInstancesCount%20gt%200)" -f $SubscriptionID, $ResourceGroup, $Project
    }

    
    #

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET"#-Debug -Verbose
    $obj = $obj + $response.value
    while ($response.nextlink) {
        $newresponse = Invoke-RestMethod -Uri $response.nextLink -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
        $response = $newresponse
        $obj = $obj + $response.value
        clear-variable newresponse
    }
    return $obj
}




function Get-AzureMigrateEnumerateMachines {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project


    )

    $obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/migrateProjects/{2}/machines?api-version=2018-09-01-preview&pageSize=2000" -f $SubscriptionID, $ResourceGroup, $Project
    

    
    #

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET"#-Debug -Verbose
    $obj = $obj + $response.value
    while ($response.nextlink) {
        $newresponse = Invoke-RestMethod -Uri $response.nextLink -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
        $response = $newresponse
        $obj = $obj + $response.value
        clear-variable newresponse
    }
    return $obj
}






function Get-AzureMigrateVMWareSite {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.OffAzure/VMwareSites?api-version=2020-01-01-preview" -f $SubscriptionID, $ResourceGroup

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response.value 

}



function Get-AzureMigrateHyperSite {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.OffAzure/HyperVSites?api-version=2020-01-01" -f $SubscriptionID, $ResourceGroup

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response.value

}


function Get-AzureMigrateImportSite {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/importcollectors?api-version=2019-10-01" -f $SubscriptionID, $ResourceGroup, $ProjectName

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response.value

}

function Get-AzureMigratePhysicalSite {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/servercollectors?api-version=2019-10-01" -f $SubscriptionID, $ResourceGroup, $ProjectName

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response.value

}





function Get-AzureMigrateAssessments {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project
        
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentprojects/{2}/assessmentsSummary/default?api-version=2020-05-01-preview" -f $SubscriptionID, $ResourceGroup, $Project
            
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET"
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response.properties.assessments

}

function Get-AzureMigrateAssessments-by-Group {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Group,
        [switch]$SQL
        

    )

    #$obj = @()

if ($SQL) {
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups/{3}/sqlassessments?api-version=2020-05-01-preview" -f $SubscriptionID, $ResourceGroup, $Project, $group
    
}
else {
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups/{3}/assessments?api-version=2019-10-01" -f $SubscriptionID, $ResourceGroup, $Project, $group
    
}

    
 
    
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET"
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

    return $response.value


}




function New-AzureMigrateGroup {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$GroupName
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups/{3}?api-version=2019-05-01" -f $SubscriptionID, $ResourceGroup, $Project, $GroupName

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "PUT" -Body "{'groupType': 'Default'}" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response

}


function New-AzureMigrateGroupAddMachines {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$token,
        [Parameter(Mandatory = $true)][string]$subscriptionId,
        [Parameter(Mandatory = $true)][string]$resourceGroupName,
        [Parameter(Mandatory = $true)][string]$assessmentProjectName,
        [Parameter(Mandatory = $false)][string]$discoverySource,
        [Parameter(Mandatory = $true)][string]$groupName
    )
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $token")

    #Use appliance based discovery as default discovery source if user does not provide the parameter
    if ($discoverySource -eq "") {
        $discoverySource = "Appliance"
    }
    #Create group
    ##PUT https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}?api-version=2019-10-01
    $groupURI = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentProjects/" + $assessmentProjectName + "/groups/" + $groupName + "?api-version=2019-10-01"
    ##Define the body JSON to be passed with th request
    $body = @"
    {   
        "properties": {
            "groupType": "",
            "supportedAssessmentTypes": ""
           
        }
    }
"@

    $body = $body | ConvertFrom-Json

    ##Specify groupType as Import if the discovery source is import
    if ($discoverySource -ceq "Import") {
        $body.properties.groupType = "Import"
        #$body.properties.supportedAssessmentTypes = "MachineAssessment, AvsAssessment"
    }
    if ($discoverySource -ceq "Appliance") {
        $body.properties.groupType = "Default"
        #$body.properties.supportedAssessmentTypes = "MachineAssessment, AvsAssessment, WebAppAssessment, SqlAssessment}"
    }
    if ($discoverySource -ceq "SQL") {
        $body.properties.groupType = "Default"
        #$body.properties.supportedAssessmentTypes = "MachineAssessment, AvsAssessment, SqlAssessment}"
    }
    $body = $body | ConvertTo-Json

    ##Create group
    try {
        $group = Invoke-RestMethod -ContentType "$global:contentType" -Uri $groupURI -Method "PUT" -Headers $headers -Body $body
        if ($group.name) {
            Write-Host "Group created:"$group.name
        }
    } 
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    }

    ##Remove quotes from the eTag field
    [String] $eTag = $group.eTag
    $eTag = $eTag.Replace("`"", "")

    #Get list of machines in the assessment project to be added to the group
    ##GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/machines?api-version=2019-10-01 
   
    $machinesByDiscoverySource = @"
{
    "properties": {
        "machines": [
        ]
     }
}
"@
    
    $machinesByDiscoverySource = $machinesByDiscoverySource | ConvertFrom-Json
    $machineURL = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentProjects/" + $assessmentProjectName + "/machines?api-version=2019-10-01"
    $SQLURL = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentProjects/" + $assessmentProjectName + "/machines?api-version=2019-05-01&pageSize=100&%24filter=(Properties/SqlInstancesCount%20gt%200)"
    $ImportURL = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentProjects/" + $assessmentProjectName + "/machines?api-version=2019-05-01&pageSize=100&%24filter=contains(Properties/DiscoveryMachineArmId%2C%27ImportSites%27)"

    #
    Write-Host "Getting all machines discovered via"$discoverySource
    ##Get all machines in the project till the nextLink in the response is blank
    try {
        do {
            if ($discoverySource -ceq "Appliance") {
                $responseMachineList = Invoke-RestMethod -ContentType "$global:contentType" -Uri $machineURL -Method "GET" -Headers $headers
            }
            if ($discoverySource -ceq "SQL") {
                $responseMachineList = Invoke-RestMethod -ContentType "$global:contentType" -Uri $SQLURL -Method "GET" -Headers $headers
            }
            if ($discoverySource -ceq "Import") {
                $responseMachineList = Invoke-RestMethod -ContentType "$global:contentType" -Uri $ImportURL -Method "GET" -Headers $headers
            }
            if ($responseMachineList) {
                $responseMachineList.value | ForEach-Object {
                    if ($discoverySource -ceq "Import") {
                        if ($_.id.EndsWith('-import')) {
                            $machinesByDiscoverySource.properties.machines += $_.id
                        }
                    }
                    if ($discoverySource -ceq "Appliance") {
                        if (-Not $_.id.EndsWith('-import')) {
                            $machinesByDiscoverySource.properties.machines += $_.id
                             
                        }
                    }
                    if ($discoverySource -ceq "SQL") {
                        if (-Not $_.id.EndsWith('-import')) {
                            $machinesByDiscoverySource.properties.machines += $_.id
                        }
                    }
                    
                }
                if ($responseMachineList.nextLink) {
                    ###Assign the next link to machine URL to get the next set of machines
                    if ($discoverySource -ceq "Appliance") {
                        $machineURL = $responseMachineList.nextLink
                    }
                    if ($discoverySource -ceq "SQL") {
                        $SQLURL = $responseMachineList.nextLink
                    }
                    

                }
            }
        }while ($responseMachineList.nextLink)
    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    }

    #Add/Update machines in the group
    ##POST https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/updateMachines?api-version=2019-10-01
    $groupUpdateURI = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentProjects/" + $assessmentProjectName + "/groups/" + $groupName + "/updateMachines?api-version=2019-10-01"
    Write-Host "Adding machines to the group..."
    ## Adding machines to the group based on discovery source
    if ($machinesByDiscoverySource.properties.machines) {
        Write-Host "Number of machines to be added to the group:"$machinesByDiscoverySource.properties.machines.count
        if ($machinesByDiscoverySource.properties.machines.count -ge 10000) {
            ## POST calls to update machines in the group can only be sent for 10000 machines at a time
            $parts = [Math]::Ceiling($machinesByDiscoverySource.properties.machines.count / 10000)
            $numberOfMachines = 10000

        }
        else {
            $parts = 1
        }
    }
    else {
        Write-Host "No machines to add to the group. Please wait for some more time after the discovery has been initiated."
        break
    }    

    ## POST calls to update machines in the group can only be sent for 10000 machines at a time
    for ($i = 1; $i -le $parts; $i++) {
        ##Define the body JSON to be passed with the update group request
        $body = @"
        {
            "eTag" : "",
            "properties": {
                "machines": [
                ],
                "operationType": "Add"
            }
    }
"@
        $body = $body | ConvertFrom-Json
        Write-Host "Making update machines call #"$i 
        if ($machinesByDiscoverySource.properties.machines.count -le 10000) {
            $numberOfMachines = $machinesByDiscoverySource.properties.machines.count
        }
        $body.properties.machines = $machinesByDiscoverySource.properties.machines | Select-Object -First $numberOfMachines
        $body = $body | ConvertTo-Json
        try {
            Invoke-RestMethod -ContentType "$global:contentType" -Uri $groupUpdateURI -Method "POST" -Headers $headers -Body $body
        } 
        catch {
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        }
        #Check group status before creating assessment
        $group = Get-GroupStatus -token $token -subscriptionId $subscriptionId -resourceGroupName $resourceGroupName -assessmentProjectName $assessmentProjectName -groupName $groupName
        $machinesByDiscoverySource.properties.machines = $machinesByDiscoverySource.properties.machines | Select-Object -Skip $numberOfMachines
        $body = $body | ConvertFrom-Json
    }
    return $group
} 

function Get-GroupStatus {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$token,
        [Parameter(Mandatory = $true)][string]$subscriptionId,
        [Parameter(Mandatory = $true)][string]$resourceGroupName,
        [Parameter(Mandatory = $true)][string]$assessmentProjectName,
        [Parameter(Mandatory = $true)][string]$groupName
    )
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
    
    #Check group status or Get group
    ##GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}?api-version=2019-10-01
    ## Poll the group response till the status is completed

    do {
        Start-Sleep -s 5
        Write-Host "Getting Group Status" -ForegroundColor c
        try {
            $responseGroup = Invoke-RestMethod -ContentType "$global:contentType" -Uri $groupURI -Method "GET" -Headers $headers
        }
        catch {
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        }
        Write-Host $responseGroup.properties.groupStatus
    }while ($responseGroup.properties.groupStatus -ne "Completed")
    return $responseGroup

}    


function Get-AzureMigrateGroups {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $false)][string]$Groupname
    )

    #$obj = @()
   
if ($Groupname) {
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups/{3}?api-version=2019-05-01" -f $SubscriptionID, $ResourceGroup, $Project, $group
}
else {
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups?api-version=2019-05-01" -f $SubscriptionID, $ResourceGroup, $Project
}

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response.value

}



function Set-AzureMigrateGroup {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Group,
        [Parameter(Mandatory = $true)][string[]]$Machines,
        [Parameter(Mandatory = $true, ParameterSetName = "Add")][switch]$Add,
        [Parameter(Mandatory = $true, ParameterSetName = "Remove")][switch]$Remove
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups/{3}/updateMachines?api-version=2019-05-01" -f $SubscriptionID, $ResourceGroup, $Project, $Group

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $jsonPayload = @"
    {
        "properties": {
          "machines": [
          ],
          "operationType": "Undefined"
        }
      }
"@

    $jsonPayload = $jsonPayload | ConvertFrom-Json

    if ($Add) {
        $jsonPayload.properties.operationType = "Add"
    }
    if ($Remove) {
        $jsonPayload.properties.operationType = "Remove"
    }

    $Machines | ForEach-Object {
        $jsonPayload.properties.machines += $_
    }

    $jsonPayload = $jsonPayload | ConvertTo-Json

    Write-Debug $jsonPayload

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "POST" -Body $jsonPayload #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response

}



function New-AzureMigrateVMAssessment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Group,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [Parameter(Mandatory = $true)][string]$AssessmentProperties
    )



    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentprojects/{2}/groups/{3}/assessments/{4}?api-version=2019-05-01" -f $SubscriptionID, $ResourceGroup, $Project, $Group, $AssessmentName

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $jsonPayload = Get-Content $AssessmentProperties

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "PUT" -Body $jsonPayload #-Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response

}


function Get-AzureMigrateAssessedMachines-by-Assessment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$GroupName,
        [Parameter(Mandatory = $true)][string]$assessmentname
     
    )

    $obj = @()
    #GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/assessments/{assessmentName}/assessedMachines?api-version=2019-10-01

    
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups/{3}/assessments/{4}/assessedMachines?api-version=2019-10-01&pageSize=2000" -f $SubscriptionID, $ResourceGroup, $Project,$groupName,$assessmentname


    
    #

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET"#-Debug -Verbose

    $obj = $obj + $response.value
    while ($response.nextlink) {
        $newresponse = Invoke-RestMethod -Uri $response.nextLink -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
        $response = $newresponse
        $obj = $obj + $response.value
        clear-variable newresponse
    }
    return $obj
}

function Get-AzureMigrateAssessedSQLMachines-by-Assessment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$GroupName,
        [Parameter(Mandatory = $true)][string]$assessmentname
     
    )

    $obj = @()
    #GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/assessments/{assessmentName}/assessedMachines?api-version=2019-10-01

    #https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{assessmentprojectName}/groups/{groupName}/sqlAssessments/{assessmentName}?api-version=2020-05-01-preview
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentProjects/{2}/groups/{3}/sqlAssessments/{4}?api-version=2020-05-01-preview&pageSize=2000" -f $SubscriptionID, $ResourceGroup, $Project,$groupName,$assessmentname


    
    #

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "GET"#-Debug -Verbose

    $obj = $obj + $response
    
    return $obj
}






function Remove-AzureMigrateAssessment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Group,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [switch]$SQL
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentprojects/{2}/groups/{3}/assessments/{4}?api-version=2019-05-01" -f $SubscriptionID, $ResourceGroup, $Project, $Group, $AssessmentName
    if ($SQL) {
        $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentprojects/{2}/groups/{3}/SqlAssessments/{4}?api-version=2020-05-01-preview" -f $SubscriptionID, $ResourceGroup, $Project, $Group, $AssessmentName
    }


    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "DELETE" 
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response

}



function Remove-AzureMigrateGroup {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Group
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentprojects/{2}/groups/{3}?api-version=2019-05-01" -f $SubscriptionID, $ResourceGroup, $Project, $Group

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "DELETE"
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response

}



function Export-VMAssessment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$token,
        [Parameter(Mandatory = $true)][string]$subscriptionId,
        [Parameter(Mandatory = $true)][string]$resourceGroupName,
        [Parameter(Mandatory = $true)][string]$assessmentProjectName,
        [Parameter(Mandatory = $true)][string]$groupName,
        [Parameter(Mandatory = $true)][string[]]$assessmentName
    )
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    #Get Assessment download URL and export each of the assessment reports in .xlsx files
    if ($assessmentName) {
        [int]$i = 0
        $assessmentName | ForEach-Object {

            ##Get assessment URL to check assessment status before downloading the assessment report
            $AssessmentGetURL = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentprojects/" + $assessmentProjectName + "/groups/" + $groupName + "/assessments/" + $assessmentName[$i] + "?api-version=2019-05-01"
    
            #Check assessment status
            ##GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/assessments/{assessmentName}?api-version=2019-10-01
            do {
                 Write-Host "Checking status to download assessment:$assessmentName[$i]..." -f Yellow
                Sleep-Progress -s 20
                
                ##Get assessment to check status before downloading the assessment report
                $responseAssessmentList = Invoke-RestMethod -ContentType "$global:contentType" -Uri $AssessmentGetURL -Method "GET" -Headers $headers
                Write-host "Current Status of $($assessmentName) is $($responseAssessmentList.properties.status)" -f Gray
                ##Get assessment to check status before downloading the assessment report
                if ($responseAssessmentList.properties.status -eq "Completed") {
                    ###Download link for assessment
                    ###POST https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/assessments/{assessmentName}/downloadUrl?api-version=2019-10-01
                    $assessmentDownloadURL = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentprojects/" + $assessmentProjectName + "/groups/" + $groupName + "/assessments/" + $assessmentName[$i] + "/downloadUrl?api-version=2019-05-01"
                    try {
                        $assessmentDownload = Invoke-RestMethod -ContentType "$global:contentType" -Uri $assessmentDownloadURL -Method "POST" -Headers $headers
                       $fileName = ".\" + $assessmentName[$i]+".xlsx"
                    #### Download assessment report from the URL as a .xlsx file
                        Invoke-WebRequest -uri $assessmentDownload.assessmentReportUrl -OutFile $fileName
                        Write-Host "Download completed for assessment: "$assessmentName[$i] -f Green
                    }
                    catch {
                        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
                        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
                    }
                }
            }while ($responseAssessmentList.properties.status -ne "Completed")
            $i = $i + 1
        }
        return $null
    }
}
function Export-SQLAssessment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$token,
        [Parameter(Mandatory = $true)][string]$subscriptionId,
        [Parameter(Mandatory = $true)][string]$resourceGroupName,
        [Parameter(Mandatory = $true)][string]$assessmentProjectName,
        [Parameter(Mandatory = $true)][string]$groupName,
        [Parameter(Mandatory = $true)][string[]]$assessmentName
    )
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    #Get Assessment download URL and export each of the assessment reports in .xlsx files
    if ($assessmentName) {
        [int]$i = 0
        $assessmentName | ForEach-Object {

            ##Get assessment URL to check assessment status before downloading the assessment report
            $AssessmentGetURL = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentprojects/" + $assessmentProjectName + "/groups/" + $groupName + "/SqlAssessments/" + $assessmentName[$i] + "?api-version=2020-05-01-preview"
    
            #Check assessment status
            ##GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/assessments/{assessmentName}?api-version=2019-10-01
            do {
                Write-Host "Checking status to download assessment:$assessmentName[$i]..." -f Yellow
                Sleep-Progress -s 20
                
                ##Get assessment to check status before downloading the assessment report
                $responseAssessmentList = Invoke-RestMethod -ContentType "$global:contentType" -Uri $AssessmentGetURL -Method "GET" -Headers $headers

                ##Get assessment to check status before downloading the assessment report
                if ($responseAssessmentList.properties.status -eq "Completed") {
                    ###Download link for assessment
                    ###POST https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/assessments/{assessmentName}/downloadUrl?api-version=2019-10-01
                    $assessmentDownloadURL = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.Migrate/assessmentprojects/" + $assessmentProjectName + "/groups/" + $groupName + "/SqlAssessments/" + $assessmentName[$i] + "/downloadUrl?api-version=2020-05-01-preview"
                    try {
                        $assessmentDownload = Invoke-RestMethod -ContentType "$global:contentType" -Uri $assessmentDownloadURL -Method "POST" -Headers $headers
                        $fileName = ".\" + $assessmentName[$i]+"_"+$groupName+".xlsx"
                        #### Download assessment report from the URL as a .xlsx file
                        Invoke-WebRequest -uri $assessmentDownload.assessmentReportUrl -OutFile $fileName
                        Write-Host "Download completed for assessment: "$assessmentName[$i] -f Gray
                    }
                    catch {
                    
                    }
                }
            }while ($responseAssessmentList.properties.status -ne "Completed")
  
            $i = $i + 1
        }
        return $null
    }
}


function Export-SoftwareInventory {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $false)] [ValidateSet('VMwareSites','HyperVSites')][string]$ApplianceType,
        [Parameter(Mandatory = $true)][string]$Sitename

  
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/" + $subscriptionId + "/resourceGroups/" + $ResoruceGroup + "/providers/Microsoft.OffAzure/$($ApplianceType)/" + $Sitename + "/ExportApplications?api-version=2018-05-01-preview"
$url
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    
    do {
        # Write-Host "Checking status to download assessment:$assessmentName[$i]..."
        Start-Sleep -s 20
        
        ##Get assessment to check status before downloading the assessment report
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "POST" #-Verbose -Debug
        ##Get assessment to check status before downloading the assessment report
        if ($response.status -eq "Running") {
            ###Download link for assessment
            ###POST https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/groups/{groupName}/assessments/{assessmentName}/downloadUrl?api-version=2019-10-01
            try {
                $download = Invoke-RestMethod -ContentType "$global:contentType" -Uri $url -Method "POST" -Headers $headers
                $fileName = ".\" + $Software_Inv + ".xlsx"
                #### Download assessment report from the URL as a .xlsx file
                $download.status
                #Write-Host "Download completed for assessment: "$assessmentName[$i]
            }
            catch {
                Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
                Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            }
        }
    }while ($download.status -ne "Running")
    Write-host "Waiting for proccess to complete" -f red
    $download = Invoke-RestMethod -ContentType "$global:contentType" -Uri $url -Method "POST" -Headers $headers
    Write-host "Current Status:" $download.status
    $i = $i + 1
}






function Get-AzureMigrateVMwareHealthSiteSummary {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$SiteName
        
    )
#https://management.azure.com/subscriptions/4bd2aa0f-2bd2-4d67-91a8-5a4533d58600/resourceGroups/rahasijaBugBash050919/providers/Microsoft.OffAzure/VMwareSites/rahasapp122119d37csite/healthSummary?api-version=2020-01-01

    #$obj = @()


        $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/VMwareSites/$($SiteName)/healthSummary?api-version=2020-01-01"

     
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    $response.value

    }

    function Get-AzureMigrateHyperVHealthSiteSummary {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)][string]$Token,
            [Parameter(Mandatory = $true)][string]$SubscriptionID,
            [Parameter(Mandatory = $true)][string]$ResourceGroup,
            [Parameter(Mandatory = $true)][string]$SiteName
            
        )
    #https://management.azure.com/subscriptions/4bd2aa0f-2bd2-4d67-91a8-5a4533d58600/resourceGroups/rahasijaBugBash050919/providers/Microsoft.OffAzure/VMwareSites/rahasapp122119d37csite/healthSummary?api-version=2020-01-01
    
        #$obj = @()
    
    
            $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/HyperV/PhysicalSites/$($SiteName)/healthSummary?api-version=2020-01-01"
    
         
        $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
        $headers.Add("Authorization", "Bearer $Token")
    
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
        #$obj += $response.Substring(1) | ConvertFrom-Json
        #return (_formatResult -obj $obj -type "AzureMigrateProject")
        $response.value
    
        }

    function Get-AzureMigrateMasterSite {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)][string]$Token,
            [Parameter(Mandatory = $true)][string]$SubscriptionID,
            [Parameter(Mandatory = $true)][string]$ResourceGroup
            
        )
  #https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OffAzure/MasterSites?api-version=2020-07-07
        #$obj = @()
    
    
            $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.OffAzure/MasterSites?api-version=2020-07-07"
    
         
        $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
        $headers.Add("Authorization", "Bearer $Token")
    
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
        #$obj += $response.Substring(1) | ConvertFrom-Json
        #return (_formatResult -obj $obj -type "AzureMigrateProject")
        $response.value
    
        }
        
    function Get-AzureMigrateAppliances {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true)][string]$Token,
            [Parameter(Mandatory = $true)][string]$SubscriptionID,
            [Parameter(Mandatory = $true)][string]$ResourceGroup,
            [Parameter(Mandatory = $true)][string]$ProjectName,
            [Parameter(Mandatory = $true)] [ValidateSet('VMWare','HyperV')][string]$ApplianceType 
            
        )
#GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/assessmentProjects/{projectName}/vmwarecollectors?api-version=2019-10-01
        #$obj = @()
    
    if ($ApplianceType = "VMWare") {
        $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.Migrate/assessmentProjects/$($ProjectName)/vmwarecollectors?api-version=2019-10-01"
    }
    elseif ($ApplianceType = "HyperV") {
        $url = "https://management.azure.com/subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.Migrate/assessmentProjects/{3}/hypervcollectors?api-version=2019-10-01"  -f $SubscriptionID, $ResourceGroup, $ProjectName
    }
    
         
        $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
        $headers.Add("Authorization", "Bearer $Token")
    
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
        #$obj += $response.Substring(1) | ConvertFrom-Json
        #return (_formatResult -obj $obj -type "AzureMigrateProject")
        $name = $response.value.name

        if ($ApplianceType = "VMWare") {
            $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResourceGroup)/providers/Microsoft.Migrate/assessmentProjects/$($ProjectName)/vmwarecollectors/$($name)?api-version=2019-10-01"
        }
        elseif ($ApplianceType = "HyperV") {
            $url = "https://management.azure.com/subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.Migrate/assessmentProjects/{3}/hypervcollectors//$($name)?api-version=2019-10-01"  -f $SubscriptionID, $ResourceGroup, $ProjectName
        }
        
        $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
        #$obj += $response.Substring(1) | ConvertFrom-Json
        #return (_formatResult -obj $obj -type "AzureMigrateProject")
       $response
    
        }
        


function Create-Bulk-VM-Assessments {
    param (
       [Parameter(Mandatory = $true)][string]$Token,
       [Parameter(Mandatory = $true)][string]$SubscriptionID,
       [Parameter(Mandatory = $true)][string]$ProjectName,
       [Parameter(Mandatory = $true)][string]$ResourceGroup,
       [Parameter(Mandatory = $true)][string]$groupname,
       [Parameter(Mandatory = $true)] [ValidateSet('Appliance','Import')][string]$DiscoverySource,
       [Parameter(Mandatory = $true)] [ValidateSet('Weekly','Monthly')][string]$timerange
    )
    $token = Get-AzCachedAccessToken
    if ($DiscoverySource -eq "Appliance") {
        $Source = ""
        }
        elseif ($DiscoverySource -eq "Import")
         {
            $Source = "_CSV"
        }
    
  # Create VM assessments for the new group using our assessment templates      
        Write-Host "Creating VM Assessments for $($groupname)"  -ForegroundColor Yellow 
        $Assessmentstobecreated = @(
            'As is 1 Year RI AHUB'
            'As is 1 Year RI'
            'As is 3 Year RI AHUB'
            #'As is 3 Year RI'
            #'As is PAYG AHUB'
            #'As is PAYG'
            #'Perf 1 Year RI AHUB'
            #'Perf 1 Year RI'
            #'Perf 3 Year RI AHUB'
            #'Perf 3 Year RI'
            #'Perf PAYG - Premium Disks'
            #'Perf PAYG - Standard Disks'
            #'Perf PAYG AHUB'
            #'Perf PAYG'
        )
$Assessmentstobecreated |  ForEach-Object {
    Write-host $_ -ForegroundColor Yellow ; 
    $Assessmnetname = $_ + $($source); 
    $filename = ".\Assessments\"+"$($timerange)\"+$_ + ".json"; 
   # Write-host $filename ;
   $Assessment =New-AzureMigrateVMAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName $($Assessmnetname) -Group $groupname -AssessmentProperties $($filename)
}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

Write-Host "Waiting 60 Secconds for Assessment Creation to complete" -f Yellow
Sleep-Progress 60

$status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
while ($status.Contains('Running') -or $status.Contains('Computing') -or $status.Contains('Updating')) {
    Start-Sleep -Seconds 60
    $status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
    [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + ' minutes'
}

$stopwatch.Stop()

$Assessmentstobecreated = @(
            
            'As is 3 Year RI'
            'As is PAYG AHUB'
            'As is PAYG'
            #'Perf 1 Year RI AHUB'
            #'Perf 1 Year RI'
            #'Perf 3 Year RI AHUB'
            #'Perf 3 Year RI'
            #'Perf PAYG - Premium Disks'
            #'Perf PAYG - Standard Disks'
            #'Perf PAYG AHUB'
            #'Perf PAYG'
        )
$Assessmentstobecreated |  ForEach-Object {
    Write-host $_ -ForegroundColor Yellow ; 
    $Assessmnetname = $_ + $($source); 
    $filename = ".\Assessments\"+"$($timerange)\"+$_ + ".json"; 
    #Write-host $filename ;
    $Assessment =New-AzureMigrateVMAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName $($Assessmnetname) -Group $groupname -AssessmentProperties $($filename)
}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

Write-Host "Waiting 60 Secconds for Assessment Creation to complete" -f Yellow
Sleep-Progress 60

$status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
while ($status.Contains('Running') -or $status.Contains('Computing') -or $status.Contains('Updating')) {
    Start-Sleep -Seconds 60
    $status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
    [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + ' minutes'
}

$stopwatch.Stop()

$Assessmentstobecreated = @(
            
         
            'Perf 1 Year RI AHUB'
            'Perf 1 Year RI'
            'Perf 3 Year RI AHUB'
            #'Perf 3 Year RI'
            #'Perf PAYG - Premium Disks'
            #'Perf PAYG - Standard Disks'
            #'Perf PAYG AHUB'
            #'Perf PAYG'
        )
$Assessmentstobecreated |  ForEach-Object {
    Write-host $_ -ForegroundColor Yellow ; 
    $Assessmnetname = $_ + $($source); 
    $filename = ".\Assessments\"+"$($timerange)\"+$_ + ".json"; 
    #Write-host $filename ;
    $Assessment =New-AzureMigrateVMAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName $($Assessmnetname) -Group $groupname -AssessmentProperties $($filename) | out-null;

}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

Write-Host "Waiting 90 Secconds for Assessment Creation to complete" -f Yellow
Sleep-Progress 90

$status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
while ($status.Contains('Running') -or $status.Contains('Computing') -or $status.Contains('Updating')) {
    Start-Sleep -Seconds 60
    $status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
    [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + ' minutes'
}

$stopwatch.Stop()

$Assessmentstobecreated = @(
            
         
         
            'Perf 3 Year RI'
            'Perf PAYG - Premium Disks'
            'Perf PAYG - Standard Disks'
            #'Perf PAYG AHUB'
            #'Perf PAYG'
        )
$Assessmentstobecreated |  ForEach-Object {
    Write-host $_ -ForegroundColor Yellow ; 
    $Assessmnetname = $_ + $($source); 
    $filename = ".\Assessments\"+"$($timerange)\"+$_ + ".json"; 
    #Write-host $filename ;
    $Assessment = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName $($Assessmnetname) -Group $groupname -AssessmentProperties $($filename) | out-null
}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

Write-Host "Waiting 90 Secconds for Assessment Creation to complete" -f Yellow
Sleep-Progress 90

$status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
while ($status.Contains('Running') -or $status.Contains('Computing') -or $status.Contains('Updating')) {
    Start-Sleep -Seconds 60
    $status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
    [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + ' minutes'
}

$stopwatch.Stop()

$Assessmentstobecreated = @(
            
         
         
   
            'Perf PAYG AHUB'
            'Perf PAYG'
        )
$Assessmentstobecreated |  ForEach-Object {
    Write-host $_ -ForegroundColor Yellow ; 
    $Assessmnetname = $_ + $($source); 
    $filename = ".\Assessments\"+"$($timerange)\"+$_ + ".json"; 
    #Write-host $filename ;
$Assessment =New-AzureMigrateVMAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName $($Assessmnetname) -Group $groupname -AssessmentProperties $($filename) | out-null
}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

$status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
while ($status.Contains('Running') -or $status.Contains('Computing') -or $status.Contains('Updating')) {
    Start-Sleep -Seconds 60
    $status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
    [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + ' minutes'
}

$stopwatch.Stop()



Write-Host "Assessments Creation Completed"
}
      





function Remove-Bulk-VM-Assessments {
    param (
       [Parameter(Mandatory = $true)][string]$Token,
       [Parameter(Mandatory = $true)][string]$SubscriptionID,
       [Parameter(Mandatory = $true)][string]$ProjectName,
       [Parameter(Mandatory = $true)][string]$ResourceGroup,
       [Parameter(Mandatory = $true)][string]$groupname
    )
    $token = Get-AzCachedAccessToken
  # Create VM assessments for the new group using our assessment templates      
        Write-Host "Removing VM Assessments for $($groupname)" -ForegroundColor red
        Write-Host "As is 1 Year RI AHUB"
        $Asis1YearRIAHUB_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "As is 1 Year RI AHUB" -Group $groupname 
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        Write-Host "As is 1 Year RI"
        $Asis1YearRI_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "As is 1 Year RI" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
      Write-Host "As is 3 Year RI"
      $Asis3YearRI_Assessment=  Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "As is 3 Year RI" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        
        Write-Host "As is 3 Year RI AHUB"
        $Asis3YearRIAHUB_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "As is 3 Year RI AHUB" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        
        Write-Host "As is Pay Go AHUB"
        $AsisPayGoAHUB_Assessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "As is PAYG AHUB" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        Write-Host "As is Pay Go"
        $AsisPayGo_Assessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "As is PAYG" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        Write-Host "Perf 1 Year RI AHUB"
        $Perf1YearRIAHUB_Assessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf 1 Year RI AHUB" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        
        Write-Host "Perf 1 Year RI"
        $Perf1YearRI_Assessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf 1 Year RI" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        
        Write-Host "Perf 3 Year RI AHUB"
        $Perf3YearRIAHUB_Asessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf 3 Year RI AHUB" -Group $groupname 
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        
        Write-Host "Perf 3 Year RI"
        $Perf3YearRI_Year= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf 3 Year RI" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        
        Write-Host "Perf Pay Go"
        $PerfPayGo_Assessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf PAYG" -Group $groupname 
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
        Write-Host "Perf Pay Go - Premium Disks"
        $PerfPayGoPremiumDisks_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf PAYG - Premium Disks" -Group $groupname
         ###Pausing for 30s between every assessment creation request
                Sleep-Progress -s 30
        
                Write-Host "Perf Pay Go - Standard Disks"
                $PerfPayGoStandardDisks_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf PAYG - Standard Disks" -Group $groupname
                 ###Pausing for 30s between every assessment creation request
                        Sleep-Progress -s 30
        
        Write-Host "Perf Pay Go AHUB"
        $PerfPayGoAHUB_Assessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName "Perf PAYG AHUB" -Group $groupname
          ###Pausing for 30s between every assessment creation request
           Sleep-Progress -s 30
         Write-Host "Finished Removing VM Assessments" -ForegroundColor Yellow
         


}


function Remove-Bulk-SQL-Assessments {
       param (
              [Parameter(Mandatory = $true)][string]$Token,
              [Parameter(Mandatory = $true)][string]$SubscriptionID,
              [Parameter(Mandatory = $true)][string]$ProjectName,
              [Parameter(Mandatory = $true)][string]$ResourceGroup,
              [Parameter(Mandatory = $true)][string]$groupname
       )
       
       $token = Get-AzCachedAccessToken
       #Create SQL Assessments
           # Create SQL assessments for the new group using our assessment templates
           Write-Host "Removing SQL Assessments for $($groupname)" -ForegroundColor Yellow
           Write-Host "Perf 1 Year RI AHUB"
           $Perf1YearRIAHUBSQL_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $ProjectName -AssessmentName "SQL_Perf 1 Year RI AHUB" -Group $groupname -SQL
            ###Pausing for 30s between every assessment creation request
                   Sleep-Progress -s 30
           Write-Host "Perf 1 Year RI"
           $Perf1YearRISQL_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $ProjectName -AssessmentName "SQL_Perf 1 Year RI" -Group $groupname -SQL
            ###Pausing for 30s between every assessment creation request
                   Sleep-Progress -s 30
           Write-Host "Perf 3 Year RI AHUB"
           $Perf3YearRIAHUBSQL_Assessment =Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $ProjectName -AssessmentName "SQL_Perf 3 Year RI AHUB" -Group $groupname -SQL
            ###Pausing for 30s between every assessment creation request
            Write-Host "Perf 1 Year RI"
                   Sleep-Progress -s 30
           $Perf1YearRISQL_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $ProjectName -AssessmentName "SQL_Perf 3 Year RI" -Group $groupname -SQL
            ###Pausing for 30s between every assessment creation request
                   Sleep-Progress -s 30
           
           Write-Host "Perf Pay Go"
           $PerfPayGoSQL_Asessment= Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $ProjectName -AssessmentName "SQL_Perf PAYG" -Group $groupname -SQL
            ###Pausing for 30s between every assessment creation request
                   Sleep-Progress -s 30
           
           Write-Host "Perf Pay Go AHUB"
           $PerfPayGoAHUBSQL_Assessment = Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $ProjectName -AssessmentName "SQL_Perf PAYG AHUB" -Group $groupname -SQL
            ###Pausing for 30s between every assessment creation request
                   Sleep-Progress -s 30
    
}



function Create-Bulk-SQL-Assessments {
    param (
       [Parameter(Mandatory = $true)][string]$Token,
       [Parameter(Mandatory = $true)][string]$SubscriptionID,
       [Parameter(Mandatory = $true)][string]$ProjectName,
       [Parameter(Mandatory = $true)][string]$ResourceGroup,
       [Parameter(Mandatory = $true)][string]$groupname,
       [Parameter(Mandatory = $true)] [ValidateSet('Appliance','Import')][string]$DiscoverySource,
       [Parameter(Mandatory = $true)] [ValidateSet('Weekly','Monthly')][string]$timerange
    )
    $token = Get-AzCachedAccessToken
    if ($DiscoverySource -eq "Appliance") {
        $Source = ""
        }
        elseif ($DiscoverySource -eq "Import")
         {
            $Source = "_CSV"
        }
        $DiscoverySource -eq "Appliance"
    
  # Create VM assessments for the new group using our assessment templates      
        Write-Host "Creating SQL Assessments for $($groupname)"  -ForegroundColor Yellow 
        $Assessmentstobecreated = @(
            'SQL_Perf 1 Year RI AHUB'
            'SQL_Perf 1 Year RI'
            'SQL_Perf 3 Year RI AHUB'
            #'SQL_Perf 3 Year RI'
            #'SQL_Perf PAYG AHUB'
            #'SQL_Perf PAYG'
        
        )
$Assessmentstobecreated |  ForEach-Object {
    Write-host $_ -ForegroundColor Yellow ; 
    $Assessmnetname = $_ + $($source); 
    $filename = ".\Assessments\"+"$($timerange)\"+$_ + ".json"; 
    #Write-host $filename ;
New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName $($Assessmnetname) -Group $groupname -AssessmentProperties $($filename)
}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

Write-Host "Waiting 60 Secconds for Assessment Creation to complete" -f Yellow
Sleep-Progress 60

$status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
while ($status.Contains('Running') -or $status.Contains('Computing') -or $status.Contains('Updating')) {
    Start-Sleep -Seconds 60
    $status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
    [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + ' minutes'
}

$stopwatch.Stop()

$Assessmentstobecreated = @(
            
    #'SQL_Perf 1 Year RI AHUB'
    #'SQL_Perf 1 Year RI'
    #'SQL_Perf 3 Year RI AHUB'
    'SQL_Perf 3 Year RI'
    'SQL_Perf PAYG AHUB'
    'SQL_Perf PAYG'
        )
$Assessmentstobecreated |  ForEach-Object {
    Write-host $_ -ForegroundColor Yellow ; 
    $Assessmnetname = $_ + $($source); 
    $filename = ".\Assessments\"+"$($timerange)\"+$_ +".json"; 
    Write-host $filename ;
New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -AssessmentName $($Assessmnetname) -Group $groupname -AssessmentProperties $($filename)
}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

Write-Host "Waiting 60 Secconds for Assessment Creation to complete" -f Yellow
Sleep-Progress 60

$status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
while ($status.Contains('Running') -or $status.Contains('Computing') -or $status.Contains('Updating')) {
    Start-Sleep -Seconds 60
    $status = Get-Assessment-Status -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -list_of_unique_assessment_statuses_only
    [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + ' minutes'
}

$stopwatch.Stop()

Write-Host "Assessments Creation Completed"
}


function Create-VM-Scope-Output {
    param (
              [Parameter(Mandatory = $true)][string]$Output


       )

       Write-Host "Exporting VM Discovery list - Remove out of Scope Server and Save" -ForegroundColor red
#$discoveredmachines | export-csv  Discoveredmachines.csv
$machinescope = $discoveredmachines| ForEach-Object {
    [PSCustomObject]@{
        "In/Out of Scope"	=	" "
        "In/Out Scope Reason"	=	" "
        "Enviroment"	=	" "
        "Device Name"               = $_.properties.displayName
        "Id"        =           $_.id
        "name" =                $_.name
        "type" =                $_.type
        "properties" =          $_.properties
        }
}
$machinescope | Export-Csv $output/VMScope.csv
}


function Create-SQL-Scope-Output  {
    param (
              [Parameter(Mandatory = $true)][string]$Output


       )

       Write-Host "Exporting SQL Discovery list - Remove out of Scope Server and Save" -ForegroundColor red
#$discoveredSQLmachines | export-csv discoveredSQLmachines.csv
$SQLmachinescope = $discoveredSQLmachines| ForEach-Object {
    [PSCustomObject]@{
        "In/Out of Scope"	=	" "
        "In/Out Scope Reason"	=	" "
        "Enviroment"	=	" "
        "Device Name"               = $_.properties.displayName
        "Id"        =           $_.id
        "name" =                $_.name
        "type" =                $_.type
        "properties" =          $_.properties


    }
}

$SQlmachinescope | Export-Csv $output/SQLScope.csv

}

function Add-Scope-To-Group {
       param (
              [Parameter(Mandatory = $true)][string]$Token,
              [Parameter(Mandatory = $true)][string]$SubscriptionID,
              [Parameter(Mandatory = $true)][string]$ProjectName,
              [Parameter(Mandatory = $true)][string]$groupname,
              [Parameter(Mandatory = $true)][string]$Scopefile

       )
       Write-Host "Adding In Scope VM Machines to In Scope Group" -ForegroundColor Green
$inscopemachines = import-csv $Scopefile
$inscopemachines = $inscopemachines | Select-Object id,name
    #Add Scope Machiens to new Group
    If($inscopemachines.count -gt 0){
        Write-Host "Adding $($inscopemachines.count) to Group $($groupname)" -f Yellow
        $updatedGroupVMScope = Set-AzureMigrateGroup -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $ProjectName -Group $groupname -Machines $inscopemachines -Add
        }
        else{
        
        Write-host "No In scope Machines to Add To Group" -f Red
        }
    
}






function Get-AzureMigrate-Operations {
       
   
       #$obj = @()
       $url = "https://management.azure.com/providers/Microsoft.Migrate/operations?api-version=2019-10-01"
   
   
       $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
       $headers.Add("Authorization", "Bearer $Token")
   
       $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Debug -Verbose
       #$obj += $response.Substring(1) | ConvertFrom-Json
       #return (_formatResult -obj $obj -type "AzureMigrateProject")
   $response.value | Select-Object name, @{Name = 'Provider'; Expression = {$_.display.provider}},@{Name = 'Resource'; Expression = {$_.display.resoruce}},@{Name = 'Allowed Options'; Expression = {$_.display.Options}},@{Name = 'Description'; Expression = {$_.display.description}} | Format-Table
   
   }


function Get-Assessment-Status {
    param (
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $false)][string]$Project,
        [Parameter(Mandatory = $false)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Token,
        [switch]$list_of_unique_assessment_statuses_only
        )

    # Get a summary of assessments for the project
    $assessments = Get-AzureMigrateAssessments -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $Project
    $assessment_statuses = $assessments | Select-Object -Property @{Label="Assessment";Expression={$_.name}}, @{Label="Status";Expression={$_.properties.status}}
    $unique_assessment_statuses = $assessment_statuses | Select-Object -Property Status | Sort-Object -Property Status -Unique
    $unique_assessment_statuses = $unique_assessment_statuses.Status

    if ($list_of_unique_assessment_statuses_only) {return $unique_assessment_statuses} else {return $assessment_statuses}
}



function Export-Bulk-VM-Assessments  {
    param (
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $false)][string]$ProjectName,
        [Parameter(Mandatory = $false)][string]$ResourceGroup,
        [Parameter(Mandatory = $false)][string]$groupname,
        [Parameter(Mandatory = $true)][string]$Token,
        [switch]$CSV,
        [switch]$JSON


    )
    if ($csv) {
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token -assessmentName "As is 1 Year RI AHUB_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 3 Year RI_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 3 Year RI AHUB_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 1 Year RI_CSV"  
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is PAYG_CSV"  
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is PAYG AHUB_CSV"     
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 1 Year RI AHUB_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG AHUB_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Premium Disks_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Standard Disks_CSV" 
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname  -token $token  -assessmentName "Perf 3 Year RI_CSV"  
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname  -token $token  -assessmentName "Perf 1 Year RI_CSV"    
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI AHUB_CSV"  
        
    }
    else {
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token -assessmentName "As is 1 Year RI AHUB" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 3 Year RI" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 3 Year RI AHUB" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 1 Year RI"  
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is PAYG"  
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is PAYG AHUB"     
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 1 Year RI AHUB" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG AHUB" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Premium Disks" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Standard Disks" 
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname  -token $token  -assessmentName "Perf 3 Year RI"  
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname  -token $token  -assessmentName "Perf 1 Year RI"    
        
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI AHUB"  
        
    }
if ($json) {
    
    Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is 1 Year RI AHUB" | ConvertTo-Json  -Depth 100 | Out-File 'As is 1 Year RI AHUB_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is 1 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File 'As is 1 Year RI AHUB_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is 3 Year RI"  | ConvertTo-Json  -Depth 100 | Out-File 'As is 3 Year RI_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is 3 Year RI AHUB"  | ConvertTo-Json  -Depth 100 | Out-File 'As is 3 Year RI AHUB_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File 'As is 3 Year RI AHUB_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is PAYG"   | ConvertTo-Json  -Depth 100 | Out-File 'As is PAYG_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is PAYG AHUB"  | ConvertTo-Json  -Depth 100 | Out-File 'As is PAYG AHUB_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf 3 Year RI AHUB_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "Perf 1 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf 1 Year RI AHUB_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf 3 Year RI_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 1 Year RI"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf 1 Year RI_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG AHUB"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG AHUB_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Premium Disks"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG - Premium Disks_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Standard Disk"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG - Standard Disk_$($groupname).json'
       


}
elseif ($json -and $csv) {
    Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 1 Year RI AHUB_CSV" | ConvertTo-Json  -Depth 100 | Out-File 'As is 1 Year RI AHUB_CSV_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is 3 Year RI_CSV"  | ConvertTo-Json  -Depth 100 | Out-File 'As is 3 Year RI_CSV_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is 3 Year RI AHUB_CSV"  | ConvertTo-Json  -Depth 100 | Out-File 'As is 3 Year RI AHUB_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "As is 3 Year RI AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'As is 3 Year RI AHUB_CSV_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is PAYG_CSV"  | ConvertTo-Json  -Depth 100 | Out-File 'As is PAYG_CSV_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "As is PAYG AHUB_CSV"  | ConvertTo-Json  -Depth 100 | Out-File 'As is PAYG AHUB_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf 3 Year RI AHUB_CSV_$($groupname).json'
Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $ResourceGroup -Project $ProjectName -GroupName $groupname -assessmentname "Perf 1 Year RI AHUB_CSV"  | ConvertTo-Json  -Depth 100 | Out-File 'Perf 1 Year RI AHUB_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf 3 Year RI_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf 1 Year RI_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf 1 Year RI_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG AHUB_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Premium Disks_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG - Premium Disks_CSV_$($groupname).json'
    Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "Perf PAYG - Standard Disk_CSV"   | ConvertTo-Json  -Depth 100 | Out-File 'Perf PAYG - Standard Disk_CSV_$($groupname).json'

}
    
}

function Export-Bulk-SQL-Assessments  {
    param (
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $false)][string]$ProjectName,
        [Parameter(Mandatory = $false)][string]$ResourceGroup,
        [Parameter(Mandatory = $false)][string]$groupname,
        [Parameter(Mandatory = $true)][string]$Token,
        [switch]$json

    )
    Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "SQL_Perf 1 Year RI AHUB"
    
    Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "SQL_Perf 1 Year RI"
    
    Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "SQL_Perf 3 Year RI AHUB"
    
    Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "SQL_Perf 3 Year RI"
    
    Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "SQL_Perf PAYG"
    
    Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $ProjectName -groupName $groupname -token $token  -assessmentName "SQL_Perf PAYG AHUB"

    if ($json) {

        Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $ProjectName -groupname $groupname -assessmentname "SQL_Perf 1 Year RI AHUB"  | ConvertTo-Json  -Depth 100 | Out-File "SQL_Perf 1 Year RI AHUB_$($groupname).json"
        Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $ProjectName -groupname $groupname -assessmentname "SQL_Perf 1 Year RI"  | ConvertTo-Json  -Depth 100 | Out-File "SQL_Perf 1 Year RI_$($groupname).json"
        Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $ProjectName -groupname $groupname -assessmentname "SQL_Perf 3 Year RI"  | ConvertTo-Json  -Depth 100 | Out-File "SQL_Perf 3 Year RI_$($groupname).json"
        Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $ProjectName -groupname $groupname -assessmentname "SQL_Perf 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "SQL_Perf 3 Year RI AHUB_$($groupname).json"
        Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $ProjectName -groupname $groupname -assessmentname "SQL_Perf PAYG"   | ConvertTo-Json  -Depth 100 | Out-File "SQL_Perf PAYG_$($groupname).json"
        Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $ProjectName -groupname $groupname -assessmentname "SQL_Perf PAYG AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "SQL_Perf PAYG AHUB_$($groupname).json"

        # Action to perform if the condition is true #>
    }
    
}

#SQLV2 Start
function Get-AzureMigrate-SQLDiscovervedInstances {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$MasterSiteName,
        [Parameter(Mandatory = $true)][string]$SQLSiteName,
        [Parameter(Mandatory = $true)][string]$APIVersion


  
    )

    $obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.OffAzure/MasterSites/$($MasterSiteName)/SqlSites/$($SQLSiteName)/sqlServers?api-version=$($APIVersion)"
    #$url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/migrateProjects/$($ProjectName)/databaseInstances?api-version=2020-11-11-preview"
    
#GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/migrateProjects/{migrateProjectName}/databaseInstances?api-version=2018-09-01-preview
 
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $obj = $obj + $response.value
    while ($response.nextlink) {
        $newresponse = Invoke-RestMethod -Uri $response.nextLink -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
        $response = $newresponse
        $obj = $obj + $response.value
        clear-variable newresponse
    }
    return $obj


}

function Get-AzureMigrate-SQLDiscovervedDatabases {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$groupname,
        [Parameter(Mandatory = $true)][string]$assessmentname


  
    )

    $obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/assessmentProjects/$($ProjectName)/groups/$($groupname)/sqlAssessments/$assessmentName/assessedSqlDatabases?api-version=2020-05-01-preview"
    #$url = "https://management.azure.com/subscriptions/$($SubscriptionID)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.Migrate/migrateProjects/$($ProjectName)/databaseInstances?api-version=2020-11-11-preview"
    
#GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/migrateProjects/{migrateProjectName}/databaseInstances?api-version=2018-09-01-preview
 
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $obj = $obj + $response.value
    while ($response.nextlink) {
        $newresponse = Invoke-RestMethod -Uri $response.nextLink -Headers $headers -ContentType "application/json" -Method "GET" #-Debug -Verbose
        $response = $newresponse
        $obj = $obj + $response.value
        clear-variable newresponse
    }
    return $obj


}



function Get-AzureMigrate-SQLSite {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$MasterSiteName

  
    )
#GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/migrateProjects/{migrateProjectName}/databaseInstances?api-version=2018-09-01-preview

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.OffAzure/MasterSites/$($MasterSiteName)/SqlSites?api-version=2020-11-11-preview"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response.value
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}


function Get-AzureMigrate-SQLSite {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResoruceGroup,
        [Parameter(Mandatory = $true)][string]$ProjectName,
        [Parameter(Mandatory = $true)][string]$MasterSiteName

  
    )
#GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Migrate/migrateProjects/{migrateProjectName}/databaseInstances?api-version=2018-09-01-preview

    #$obj = @()
    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

$url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($ResoruceGroup)/providers/Microsoft.OffAzure/MasterSites/$($MasterSiteName)/SqlSites?api-version=2020-11-11-preview"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "Get" #-Verbose -Debug
    $response.value
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")

}
function New-AzureMigrateSQLAssessment {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SubscriptionID,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Group,
        [Parameter(Mandatory = $true)][string]$AssessmentName,
        [Parameter(Mandatory = $true)][string]$AssessmentProperties
    )

    #$obj = @()
    $url = "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Migrate/assessmentprojects/{2}/groups/{3}/SqlAssessments/{4}?api-version=2020-05-01-preview" -f $SubscriptionID, $ResourceGroup, $Project, $Group, $AssessmentName

    $headers = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
    $headers.Add("Authorization", "Bearer $Token")

    $jsonPayload = Get-Content $AssessmentProperties

    $response = Invoke-RestMethod -Uri $url -Headers $headers -ContentType "application/json" -Method "PUT" -Body $jsonPayload  #-Verbose
    #$obj += $response.Substring(1) | ConvertFrom-Json
    #return (_formatResult -obj $obj -type "AzureMigrateProject")
    return $response

}