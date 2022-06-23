if (Get-Module -ListAvailable -Name Microsoft.PowerShell.ConsoleGuiTools) {
    Write-Host "Console Gui Is installed"
   } 
   else{
    Write-Host "Console Gui Is Not installed - Installing" -ForegroundColor Red
    Install-Module Microsoft.PowerShell.ConsoleGuiTools 
   }

   if (Get-Module -ListAvailable -Name Az) {
    Write-Host "Az Module Is Installed"
   } 
   else{
    Write-Host "Az Modules are Is Not installed - Installing" -ForegroundColor Red
    Install-Module -Name Az  -Repository PSGallery -Force
   }

#"Create / refresh assessments and download them for all machines",
#"Generate Tagging Sheet",
#"Generate Health State Infomation",
#"Populate Scope Groups",
#"Populate Production/Non Prodction Groups",
#"Create / refresh assessments and download them for Scope machines",
#"Create / refresh assessments and download them for Production/Non Production machines",
#"Create Assessments from Group"
#"Download Assessments from Group"

# force use of latest PS version, currently hardcoded
#Requires -Version 7.2.2
Add-Type -AssemblyName PresentationFramework
#Login Style - Change Line to login Directly
$Login_via_ADO = $true




$starttime = $(Get-Date -Format "yyyy-MM-ddHH_mm_ss")
$logname = "AzureMigrate_Downlaoder"+$starttime

#change directory to current script execution directory
if ((Get-Host).Name -eq 'Visual Studio Code Host') {
    Write-Host "Running on Visual Studio Code !" -f Red
    $folder_path = Read-Host "Provide script path"
    $path_to_Customers_folder = Read-Host "Provide path to Customers folder"
    $path_to_Customers_folder = $path_to_Customers_folder + '\'
    } 
elseif ((Get-Host).Name -eq 'ConsoleHost' -and  ($PSVersionTable).Platform -ceq "Unix") {
    Write-Host "Running on Cloud Shell!" -f Green
    $folder_path = Read-Host "Provide Path to Script"
    $path_to_Customers_folder =  new-item $folder_path\Customers -force
   
    $path_to_Customers_folder = $path_to_Customers_folder + '\'
    }  

    else {
        Write-Host "Running on Windows Terminal" -f Green
    $folder_path = Split-Path $MyInvocation.MyCommand.Path
    $path_to_Customers_folder = $path_to_AzureMigrateDownloader_dir + 'Customers\'
    }

Set-Location $folder_path

Import-module .\Module\AzMigrate.psm1 -Force -DisableNameChecking -Scope Global

start-Transcript -Path .\$logname.txt

#newline
$nl = [Environment]::NewLine

$dts_stamp = $(Get-Date -Format "yyyy-MM-dd_HH_mm_ss")



#Login via ADO

if ($Login_via_ADO -eq $true) {
Write-host "Loging in Via ADO" -ForegroundColor Green
    Set-location $folder_path
    $customers_available = Get-AM-Customers
    $customer_selected = $customers_available | Select-Object -Property Customer | Sort-Object Customer | Out-ConsoleGridView -Title "Customer" -OutputMode Single
    if ($customer_selected -eq $null) { exit }
    $customer = $customers_available | Where-Object {$_.Customer -eq $customer_selected.Customer}
    
    $global:customerName = $customer.Customer
    $global:containername = Generate-Container-Name -name $customername
    $AADID = $customer.'AAD tenant ID'
    
    Set-Location $path_to_Customers_folder
    Create-CustomerArea -CustomerName $containername
    Set-Location $path_to_Customers_folder\$containername
    Write-Host "Creating Assessment Folders" -ForegroundColor Green
    Create-Assessment-Folders -dts_stamp $dts_stamp
    #$root = Get-Location
    #Login
    Write-Host "You will now be prompted for Login with your account that has access to the Customer Tennant (USE YOUR V- ACCOUNT!)" -ForegroundColor Cyan
    Connect-AzAccount -Tenant $AADID | out-null
    $Subscriptions_availaible = Get-AzSubscription -TenantId $AADID
    $Subscriptions_selected = $Subscriptions_availaible | select-object name,state,id| Out-ConsoleGridView -Title "Pick the Azure Subscription to run the assessments against" -OutputMode Single
    if ($Subscriptions_selected -eq $null) { exit }
    $subscrption = $Subscriptions_availaible | where-object {$_.'Name' -eq $Subscriptions_selected.name}
    Set-AzContext -Tenant $AADID  -Subscription $subscrption.Id| out-null
    
    Write-Host "You are now sucsessfully Logged into the $($customerName) Tennant" -ForegroundColor Green
    
    # Retrieve a bearer token for use when interacting with the underlying REST API:
    $token = Get-AzCachedAccessToken
    
    $projects_available = Get-AzureMigrateProject -Token $token -TenantId $AADID
    $project_selected = $projects_available | Select-Object -Property "Azure Migrate project display name","RG" | Out-ConsoleGridView -Title "Pick the Azure Migrate project to run the assessments against" -OutputMode Single
    if ($project_selected -eq $null) { exit }
    $project = $projects_available | Where-Object {$_.'Azure Migrate project display name' -eq $project_selected.'Azure Migrate project display name' -and $_.SubscriptionID -eq $Subscriptions_selected.Id}
    
    
    $global:SubscriptionID = $project.SubscriptionID
    $global:rg = $project.RG
    $global:project_name = $project.'Azure Migrate project internal name'
    $global:project_friendly_name = $project.'Azure Migrate project display name'
    
    $masterSite = Get-AzureMigrateMasterSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg
    if ($mastersite.count -eq 1) {
        $mastersite_selected = $mastersite[0]
    }
    elseif ($mastersite.count -gt 1) {
        $all_mastersites = $mastersite | select-object name,@{N = "Project Name"; E = { $_.tags.'Migrate Project' } }| Out-ConsoleGridView -Title "Pick the Azure Migrate mastersite to run the assessments against" -OutputMode Single
        $mastersite_selected = $all_mastersites  | Where-Object {$_.name -eq $all_mastersites.name}
        
    }
    
    
    
    #GET SITE INFOMATION
    Write-Host "Storing Site infomation" -ForegroundColor Yellow
    $HypervSite = Get-AzureMigrateHyperSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg
    if ($HypervSite.count -eq 1) {
        $HypervSite_selected = $HypervSite
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -HyperVSiteName  $HypervSite_selected.name -ResourceGroup $rg
        #$health = Get-AzureMigrateHyperVHealthSiteSummary -Token $token -SubscriptionID $subscrption -ResourceGroup $rg -SiteName $HypervSite_selected.name
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $heartbeat = $HypervSite_selected.Properties.agentDetails.lastHeartBeatUtc
      
        
    }
    elseif ($HypervSite.count -gt 1) {
        $all_HypervSite = $HypervSite |Select-Object @{N = "Site Name"; E = { $_.name } },@{N = "Appliance Name"; E = { $_.properties.appliancename } }, @{N = "Project Name"; E = { $_.properties.discoverySolutionId } }| Out-ConsoleGridView -Title "Pick the Azure Migrate VMware to run the assessments against" -OutputMode Single
        $HypervSite_selected = $all_HypervSite  | Where-Object {$_.name -eq $all_HypervSite.name}
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -HyperVSiteName  $HypervSite_selected.name -ResourceGroup $rg
        #$health = Get-AzureMigrateHyperVHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -SiteName $HypervSite_selected.'Site Name'
        $HypervSite_selected = Get-AzureMigrateVMWareSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $HypervSite_selected.'Site Name'
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $heartbeat = $HypervSite_selected.Properties.agentDetails.lastHeartBeatUtc
        #$sqlsite = Get-AzureMigrate-SQLSite -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -MasterSiteName $mastersite_selected.name
        #$SQLInstances = Get-AzureMigrate-SQLDiscovervedInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_friendly_name -MasterSiteName $mastersite_selected.name -APIVersion 2020-11-11-preview -SQLSiteName $sqlsite.name
    
    }
    
    $VMwareSite = Get-AzureMigrateVMWareSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg 
    if ($VMwareSite.count -eq 1) {
        $VMwareSite_selected = $VMwareSite
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.name -ResourceGroup $rg
        $health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -SiteName $vmwaresite_selected.name
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
        $sqlsite = Get-AzureMigrate-SQLSite -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -MasterSiteName $mastersite_selected.name
        $SQLInstances = Get-AzureMigrate-SQLDiscovervedInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_friendly_name -MasterSiteName $mastersite_selected.name -APIVersion 2020-11-11-preview -SQLSiteName $sqlsite.name
    
    
    }
    elseif ($VMwareSite.count -gt 1) {
        $all_VMwareSites = $VMwareSite |Select-Object @{N = "Site Name"; E = { $_.name } },@{N = "Appliance Name"; E = { $_.properties.appliancename } }, @{N = "Project Name"; E = { $_.properties.discoverySolutionId } }| Out-ConsoleGridView -Title "Pick the Azure Migrate VMware to run the assessments against" -OutputMode Single
        $vmwaresite_selected = $all_VMwareSites  | Where-Object {$_.name -eq $all_VMwareSites.name}
    
        
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.'Site Name' -ResourceGroup $rg
        $health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $vmwaresite_selected.'Site Name'    
        $heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $sqlsite = Get-AzureMigrate-SQLSite -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -MasterSiteName $mastersite_selected.name
        $SQLInstances = Get-AzureMigrate-SQLDiscovervedInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_friendly_name -MasterSiteName $mastersite_selected.name -APIVersion 2020-11-11-preview -SQLSiteName $sqlsite.name
    
    
    }
    $PhysicalSite = Get-AzureMigratePhysicalSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -ProjectName $project_name
    if ($PhysicalSite.count -eq 1) {
        $PhysicalSite_selected = $PhysicalSite
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.name -ResourceGroup $rg
        #$health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -SiteName $vmwaresite_selected.name
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        #$heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
    
    }
    elseif ($PhysicalSite.count -gt 1) {
        $all_PhysicalSite = $PhysicalSite |Select-Object @{N = "Site Name"; E = { $_.name } },@{N = "Appliance Name"; E = { $_.properties.appliancename } }, @{N = "Project Name"; E = { $_.properties.discoverySolutionId } }| Out-ConsoleGridView -Title "Pick the Azure Migrate VMware to run the assessments against" -OutputMode Single
        $PhysicalSite_selected = $all_PhysicalSite  | Where-Object {$_.name -eq $all_PhysicalSite.name}
    
        
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.'Site Name' -ResourceGroup $rg
        #$health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $vmwaresite_selected.'Site Name'
    #$vmwaresite_selected = Get-AzureMigrateVMWareSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $vmwaresite_selected.'Site Name'
    
        #$heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
    
    }
    
    $ImportSite = Get-AzureMigrateImportSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -ProjectName $project_name
    
    
    
    
    #Get Machine Stats
    $discoveredmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
    $discoveredSQLmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -SQL
    $discoveredAVSmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -AVS
    $discoveredCSVmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Import
    if ($discoveredmachines.count -ge 1000) {
        Write-host "More then 1000 VM Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
    $timerangeVM = "Weekly"
    }
    elseif ($discoveredmachines.count -lt 1000) {
        $timerangeVM = "Monthly"
    }
    
    if ($discoveredCSVmachines.count -ge 1000) {
        Write-host "More then 1000 CSV Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
        $timerangeCSV = "Weekly"
        }
        elseif ($discoveredCSVmachines.count -lt 1000) {
            $timerangeCSV = "Monthly"
        }
    
     if ($discoveredSQLmachines.count -ge 1000) {
            Write-host "More then 1000 SQL Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
            $timerangeSQL = "Weekly"
            }
     elseif ($discoveredCSVmachines.count -lt 1000) {
                $timerangeSQL = "Monthly"
            }
    
    
    }
    #Loging in Non ADO
elseif ($login_via_ADO -eq $false) {
    Write-host "Loging in Via AZ Connect" -ForegroundColor Green
    $folder_path = Split-Path $MyInvocation.MyCommand.Path
    $path_to_Customers_folder = Read-Host "Provide path to Customers folder"
    $path_to_Customers_folder = $path_to_Customers_folder + '\'
    Set-location $folder_path
    $customer = Read-Host "Customer Name"
    
    $global:customerName = $customer
    $global:containername = Generate-Container-Name -name $customername
    $AADID = Read-Host "AAD tenant ID"
    
    Set-Location $path_to_Customers_folder
    Create-CustomerArea -CustomerName $containername
    Set-Location $path_to_Customers_folder\$containername
    Write-Host "Creating Assessment Folders" -ForegroundColor Green
    Create-Assessment-Folders -dts_stamp $dts_stamp
    #$root = Get-Location
    #Login
    Write-Host "You will now be prompted for Login with your account that has access to the Customer Tennant (USE YOUR V- ACCOUNT!)" -ForegroundColor Cyan
    Connect-AzAccount -Tenant $AADID | out-null
    $Subscriptions_availaible = Get-AzSubscription -TenantId $AADID
    $Subscriptions_selected = $Subscriptions_availaible | select-object name,state,id| Out-ConsoleGridView -Title "Pick the Azure Subscription to run the assessments against" -OutputMode Single
    if ($Subscriptions_selected -eq $null) { exit }
    $subscrption = $Subscriptions_availaible | where-object {$_.'Name' -eq $Subscriptions_selected.name}
    Set-AzContext -Tenant $AADID  -Subscription $subscrption.Id| out-null
    
    Write-Host "You are now sucsessfully Logged into the $($customerName) Tennant" -ForegroundColor Green
    
    # Retrieve a bearer token for use when interacting with the underlying REST API:
    $token = Get-AzCachedAccessToken
    
    $projects_available = Get-AzureMigrateProject -Token $token -TenantId $AADID
    $project_selected = $projects_available | Select-Object -Property "Azure Migrate project display name","RG" | Out-ConsoleGridView -Title "Pick the Azure Migrate project to run the assessments against" -OutputMode Single
    if ($project_selected -eq $null) { exit }
    $project = $projects_available | Where-Object {$_.'Azure Migrate project display name' -eq $project_selected.'Azure Migrate project display name' -and $_.SubscriptionID -eq $Subscriptions_selected.Id}
    
    
    $global:SubscriptionID = $project.SubscriptionID
    $global:rg = $project.RG
    $global:project_name = $project.'Azure Migrate project internal name'
    $global:project_friendly_name = $project.'Azure Migrate project display name'
    
    $masterSite = Get-AzureMigrateMasterSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg
    if ($mastersite.count -eq 1) {
        $mastersite_selected = $mastersite[0]
    }
    elseif ($mastersite.count -gt 1) {
        $all_mastersites = $mastersite | select-object name,@{N = "Project Name"; E = { $_.tags.'Migrate Project' } }| Out-ConsoleGridView -Title "Pick the Azure Migrate mastersite to run the assessments against" -OutputMode Single
        $mastersite_selected = $all_mastersites  | Where-Object {$_.name -eq $all_mastersites.name}
        
    }
    
    
    
    #GET SITE INFOMATION
    Write-Host "Storing Site infomation" -ForegroundColor Yellow
    $HypervSite = Get-AzureMigrateHyperSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg
    if ($HypervSite.count -eq 1) {
        $HypervSite_selected = $HypervSite
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -HyperVSiteName  $HypervSite_selected.name -ResourceGroup $rg
        #$health = Get-AzureMigrateHyperVHealthSiteSummary -Token $token -SubscriptionID $subscrption -ResourceGroup $rg -SiteName $HypervSite_selected.name
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $heartbeat = $HypervSite_selected.Properties.agentDetails.lastHeartBeatUtc
      
        
    }
    elseif ($HypervSite.count -gt 1) {
        $all_HypervSite = $HypervSite |Select-Object @{N = "Site Name"; E = { $_.name } },@{N = "Appliance Name"; E = { $_.properties.appliancename } }, @{N = "Project Name"; E = { $_.properties.discoverySolutionId } }| Out-ConsoleGridView -Title "Pick the Azure Migrate VMware to run the assessments against" -OutputMode Single
        $HypervSite_selected = $all_HypervSite  | Where-Object {$_.name -eq $all_HypervSite.name}
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -HyperVSiteName  $HypervSite_selected.name -ResourceGroup $rg
        #$health = Get-AzureMigrateHyperVHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -SiteName $HypervSite_selected.'Site Name'
        $HypervSite_selected = Get-AzureMigrateVMWareSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $HypervSite_selected.'Site Name'
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $heartbeat = $HypervSite_selected.Properties.agentDetails.lastHeartBeatUtc
        #$sqlsite = Get-AzureMigrate-SQLSite -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -MasterSiteName $mastersite_selected.name
        #$SQLInstances = Get-AzureMigrate-SQLDiscovervedInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_friendly_name -MasterSiteName $mastersite_selected.name -APIVersion 2020-11-11-preview -SQLSiteName $sqlsite.name
    
    }
    
    $VMwareSite = Get-AzureMigrateVMWareSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg 
    if ($VMwareSite.count -eq 1) {
        $VMwareSite_selected = $VMwareSite
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.name -ResourceGroup $rg
        $health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -SiteName $vmwaresite_selected.name
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
        $sqlsite = Get-AzureMigrate-SQLSite -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -MasterSiteName $mastersite_selected.name
        $SQLInstances = Get-AzureMigrate-SQLDiscovervedInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_friendly_name -MasterSiteName $mastersite_selected.name -APIVersion 2020-11-11-preview -SQLSiteName $sqlsite.name
    
    
    }
    elseif ($VMwareSite.count -gt 1) {
        $all_VMwareSites = $VMwareSite |Select-Object @{N = "Site Name"; E = { $_.name } },@{N = "Appliance Name"; E = { $_.properties.appliancename } }, @{N = "Project Name"; E = { $_.properties.discoverySolutionId } }| Out-ConsoleGridView -Title "Pick the Azure Migrate VMware to run the assessments against" -OutputMode Single
        $vmwaresite_selected = $all_VMwareSites  | Where-Object {$_.name -eq $all_VMwareSites.name}
    
        
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.'Site Name' -ResourceGroup $rg
        $health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $vmwaresite_selected.'Site Name'

    
        $heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        $sqlsite = Get-AzureMigrate-SQLSite -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -MasterSiteName $mastersite_selected.name
        $SQLInstances = Get-AzureMigrate-SQLDiscovervedInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_friendly_name -MasterSiteName $mastersite_selected.name -APIVersion 2020-11-11-preview -SQLSiteName $sqlsite.name
    
    
    }
    $PhysicalSite = Get-AzureMigratePhysicalSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -ProjectName $project_name
    if ($PhysicalSite.count -eq 1) {
        $PhysicalSite_selected = $PhysicalSite
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.name -ResourceGroup $rg
        #$health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -SiteName $vmwaresite_selected.name
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
        #$heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
    
    }
    elseif ($PhysicalSite.count -gt 1) {
        $all_PhysicalSite = $PhysicalSite |Select-Object @{N = "Site Name"; E = { $_.name } },@{N = "Appliance Name"; E = { $_.properties.appliancename } }, @{N = "Project Name"; E = { $_.properties.discoverySolutionId } }| Out-ConsoleGridView -Title "Pick the Azure Migrate VMware to run the assessments against" -OutputMode Single
        $PhysicalSite_selected = $all_PhysicalSite  | Where-Object {$_.name -eq $all_PhysicalSite.name}
    
        
        $machineList = Get-AzureMigrateMachineList  -Token $token -SubscriptionID $SubscriptionID -SiteName  $vmwaresite_selected.'Site Name' -ResourceGroup $rg
        #$health = Get-AzureMigrateVMwareHealthSiteSummary -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $vmwaresite_selected.'Site Name'
    #$vmwaresite_selected = Get-AzureMigrateVMWareSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Sitename $vmwaresite_selected.'Site Name'
    
        #$heartbeat = $vmwaresite_selected.Properties.agentDetails.lastHeartBeatUtc
        $powerstate = $machinelist.properties | Select-Object vmFqdn, powerStatus
    
    }
    
    $ImportSite = Get-AzureMigrateImportSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -ProjectName $project_name
    
    
    
    
    #Get Machine Stats
    $discoveredmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
    $discoveredSQLmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -SQL
    $discoveredAVSmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -AVS
    $discoveredCSVmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Import
    if ($discoveredmachines.count -ge 1000) {
        Write-host "More then 1000 VM Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
    $timerangeVM = "Weekly"
    }
    elseif ($discoveredmachines.count -lt 1000) {
        $timerangeVM = "Monthly"
    }
    
    if ($discoveredCSVmachines.count -ge 1000) {
        Write-host "More then 1000 CSV Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
        $timerangeCSV = "Weekly"
        }
        elseif ($discoveredCSVmachines.count -lt 1000) {
            $timerangeCSV = "Monthly"
        }
    
     if ($discoveredSQLmachines.count -ge 1000) {
            Write-host "More then 1000 SQL Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
            $timerangeSQL = "Weekly"
            }
     elseif ($discoveredCSVmachines.count -lt 1000) {
                $timerangeSQL = "Monthly"
            }
    
}
    
###
$quit = "no"
while ($quit -ne "yes") {
    

$assessment_output_choices =@(  
"Project Stats"
"Create / refresh assessments and download them for all machines"
"Generate Tagging Sheet"
"Generate Health State Infomation"
"Populate Scope Groups"
"Create / refresh assessments and download them for Scope machines"
#"Populate Production/Non Prodction Groups",
#"Create / refresh assessments and download them for Production/Non Production machines",
#"Create Assessments from Group"
#"Download Assessments from Group"
"Get Full API Data (EnumerateMachines)"
#"Create Assessments (14 VM, 6 SQL)"
"Upload Data to Customer Blob"
"Open Customer Folder"
"######Advanced Settings#####"
"Download Assessments from Group"
"Remove Assessments from Group"
#"Remove Outdated Assessments"
"Remove All VM Assessments"
"Remove All SQL Assessments"
"Quit"
)
Set-Location $folder_path
$assessment_output_choices  =  $assessment_output_choices | Out-ConsoleGridView -Title "Assessment output options" -OutputMode Single
if ($assessment_output_choices -eq $null) { exit }

#Set Elements to faluse
$Project_Stats= $false
$Create_refresh_assessments_download_all_machine = $false
$Generate_Tagging_Sheet = $false
$Generate_Health_State_Infomation = $false
$Populate_Scope_Groups = $false
$Create_refresh_assessments_download_Scope_machines = $false
$Enable_Depdedancy= $false
$Export_Full_API_Dump= $false
#Advanced Start##
$Create_Assessments_from_Group= $false
$Remove_Assessments_from_Group= $false
$Download_Assessments_from_Group= $false
$Remove_Outdated_Assessments = $false
$Remove_All_VM_Assessments = $false
$Remove_All_SQL_Assessments = $false
Clear-Host



switch ($assessment_output_choices)
{
    "Project Stats"{$project_Stats = $true ;Set-Location $folder_path}
    "Create / refresh assessments and download them for all machines"{$Create_refresh_assessments_download_all_machine = $true}
    "Generate Tagging Sheet"{$Generate_Tagging_Sheet =$true;Set-Location $folder_path}
    "Generate Health State Infomation"{$Generate_Health_State_Infomation = $true}
    "Populate Scope Groups"{$Populate_Scope_Groups =$true;Set-Location $folder_path}
    "Create / refresh assessments and download them for Scope machines"{$Create_refresh_assessments_download_Scope_machines = $true }
    #"Populate Production/Non Prodction Groups"{}
    #"Create / refresh assessments and download them for Production/Non Production machines"{}
    #"Create Assessments from Group"{}
    "Upload Data to Customer Blob"{$Uplaod_Data_to_Customer_Blob = $true}
    "Enable Application Depdedancy"{$Enable_Depdedancy=$true}
    "Get Full API Data (EnumerateMachines)"{$Export_Full_API_Dump = $true}

    "Download Assessments from Group"{$Download_Assessments_from_Group=$true}
    "Remove Assessments from Group"{$Remove_Assessments_from_Group= $true}
    #"Remove Outdated Assessments"{$Remove_Outdated_Assessments = $true}
    "Remove All VM Assessments"{$Remove_All_VM_Assessments  =$true}
    "Remove All SQL Assessments"{$Remove_All_SQL_Assessments  = $true}

    "Open Customer Folder"{Write-Host "The last Export date was $($dts_stamp)";Invoke-Item $path_to_Customers_folder\$containername}
    "Quit"{$quit = "y";exit}
    Default {Write-Host "Incorrect input. Closing script in 10 seconds" ; Start-Sleep -s 10 ; exit}
}




#ProjectStats
if ($Project_Stats -eq $true) {

    Write-host "Project Stats:"
    if ($discoveredmachines.count -ge 1) {
           Write-Host "There are the  $($discoveredmachines.Count) Virtual Machines that have been discovered" -ForegroundColor Yellow
    }
    
    if ($discoveredCSVmachines.count -ge 1) {
        Write-Host "There are the  $($discoveredCSVmachines.Count) CSV Import Machines that have been discovered" -ForegroundColor Yellow  
    }
    if ($discoveredSQLmachines.count -ge 1) {
        Write-Host "There are the  $($discoveredSQLmachines.Count) SQL Machines that have been discovered" -ForegroundColor Yellow
    $sqlsite = Get-AzureMigrate-SQLSite -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -MasterSiteName $mastersite_selected.name
    $SQLInstances = Get-AzureMigrate-SQLDiscovervedInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_friendly_name -MasterSiteName $mastersite_selected.name -APIVersion 2020-11-11-preview -SQLSiteName $sqlsite.name
    
    }
    if ($discoveredAVSmachines.count -ge 1) {
        Write-Host "There are the  $($discoveredAVSmachines.Count) AVS Machines that have been discovered" -ForegroundColor Yellow
    }
    
  
}

#Create / refresh assessments and download them for all machines
if ($Create_refresh_assessments_download_all_machine -eq $true) {


    $token = Get-AzCachedAccessToken
#"Create / refresh assessments and download them for all machines"
#Required Actions
$AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
    #Create Groups - All VM - All SQL
    #Populate Groups - All VM - All SQL
    Write-Host "Creating VM Groups" -ForegroundColor Cyan
    if ($discoveredmachines.count -ne 0) {
    $All_Machines_Group = New-AzureMigrateGroupAddMachines -token $token -subscriptionId $SubscriptionID -resourceGroupName $rg -assessmentProjectName $project_name -discoverySource "Appliance" -groupName "All_Machines"
    }
    else {
        Write-Host "There are no VM Servers - Skipping" -ForegroundColor Cyan
    }
    if ($discoveredSQLmachines.count -ne 0) {
        $All_Machines_SQL_Group = New-AzureMigrateGroupAddMachines -token $token -subscriptionId $SubscriptionID -resourceGroupName $rg -assessmentProjectName $project_name -discoverySource "SQL" -groupName "All_Machines_SQL"
    
    }
    else {
        Write-Host "There are no SQL Servers - Skipping" -ForegroundColor Cyan
    }
    if ($discoveredCSVmachines.count -ne 0) {
        $All_Machines_CSV_Group = New-AzureMigrateGroupAddMachines -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -assessmentProjectName $project_name -GroupName "All_Machines_CSV" -discoverySource "Import"
    
    }
    else {
        Write-Host "There are no CSV Servers - Skipping" -ForegroundColor Cyan
    }
    Write-host "Waiting for Groups to be Created"
    $groupStatus = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
    $stopwatch =  [system.diagnostics.stopwatch]::StartNew()
    while ($groupStatus -eq "Running" -or $groupStatus-eq "Updated" -or $groupStatus -eq "Created") {
        Start-Sleep -Seconds 60
        $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
        [math]::Round($stopwatch.Elapsed.TotalMinutes,1).ToString() + " minutes"
    }
    $stopwatch.Stop()

Write-Host "Refreshing Token" -ForegroundColor Green
$token = Get-AzCachedAccessToken
if ($discoveredmachines.count -ge 1000) {
    Write-host "More then 1000 VM Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
$timerangeVM = "Weekly"
}
elseif ($discoveredmachines.count -lt 1000) {
    $timerangeVM = "Monthly"
}

if ($discoveredCSVmachines.count -ge 1000) {
    Write-host "More then 1000 CSV Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
    $timerangeCSV = "Weekly"
    }
    elseif ($discoveredCSVmachines.count -lt 1000) {
        $timerangeCSV = "Monthly"
    }

 if ($discoveredSQLmachines.count -ge 1000) {
        Write-host "More then 1000 SQL Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
        $timerangeSQL = "Weekly"
        }
 elseif ($discoveredCSVmachines.count -lt 1000) {
            $timerangeSQL = "Monthly"
        }
    

    Set-location $folder_path
    #Create 14 Assessmsnets - VM
    $token = Get-AzCachedAccessToken
    if ($discoveredmachines.count -ne 0) {
        Write-host "Begin Creating VM Assessments" -ForegroundColor Cyan
        Create-Bulk-VM-Assessments -Token $token -SubscriptionID $SubscriptionID -ProjectName $project_name -groupname "All_Machines" -ResourceGroup $rg -discoverySource Appliance -timerange $timerangeVM
    
    }
    
    $token = Get-AzCachedAccessToken
    
    if ($discoveredCSVmachines.count -ne 0) {
        Write-host "Begin Creating CSV Assessments" -ForegroundColor Cyan
        Create-Bulk-VM-Assessments -Token $token -SubscriptionID $SubscriptionID -ProjectName $project_name -groupname "All_Machines_CSV" -ResourceGroup $rg -discoverySource Import timerangeCSV $timerangeCSV
        
    }

    Set-location $folder_path
    #Create 6 Assessments - SQL
    $token = Get-AzCachedAccessToken
    if ($discoveredSQLmachines.count -ne 0) {
        Write-host "Begin Creating SQL Assessments" -ForegroundColor Cyan
        Create-Bulk-SQL-Assessments -Token $token -SubscriptionID $SubscriptionID -ProjectName $project_name -groupname "All_Machines_SQL" -ResourceGroup $rg -discoverySource Appliance -timerange $timerangeSQL
        
    }
    elseif ($discoveredSQLmachines.count -eq 0) {
        Write-Host "There are no SQL Servers - not creating Assessments" -ForegroundColor Cyan
    }
    $token = Get-AzCachedAccessToken

$assessments = Get-AzureMigrateAssessments -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
$VMassessments = $assessments | where-object {$_.properties.AssessmentType -eq "MachineAssessment" -and $_.properties.groupType -ne "Import"}  | Select-Object @{N="Group"; E={"All Machines"}}, @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}
$SQLassessments = $assessments | where-object {$_.properties.AssessmentType -eq "SqlAssessment"}  | Select-Object @{N="Group"; E={"All SQL Machines"}}, @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}
$CSVassessments = $assessments | where-object {$_.properties.groupType -eq "Import"}  | Select-Object @{N="Group"; E={"All CSV Machines"}}, @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}

    
    #Export 14 Assessments - VM
    if ($VMassessments.count -ge 1) {
        $groupname = "All_Machines"
        $token = Get-AzCachedAccessToken
        $Output_VMAssessments_All_Machines =   "$path_to_Customers_folder\$($containername)\VM Assessments\$($dts_stamp)"
        If(Test-Path $Output_VMAssessments_All_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_VMAssessments_All_Machines }
        Set-location $Output_VMAssessments_All_Machines
        Export-Bulk-VM-Assessments -SubscriptionID $SubscriptionID -ProjectName $project_name -ResourceGroup $rg -groupname $groupname -Token $token
   Write-host "Exporting Assessment JSON Outputs" -Force Cyan
   $Output_VMAssessments_All_Machines =   "$path_to_Customers_folder\$($containername)\VM Assessments\$($dts_stamp)\JSON"
        If(Test-Path $Output_VMAssessments_All_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_VMAssessments_All_Machines }
        Set-location $Output_VMAssessments_All_Machines
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 1 Year RI AHUB" | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 1 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 1 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 1 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 3 Year RI"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 3 Year RI AHUB"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "As is 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is PAYG"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is PAYG_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is PAYG AHUB"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is PAYG AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 3 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "Perf 1 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 1 Year RI AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 3 Year RI_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 1 Year RI"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 1 Year RI_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG - Premium Disks"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\JSON\$dts_stamp\Perf PAYG - Premium Disks_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG - Standard Disks"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\JSON\$dts_stamp\Perf PAYG - Standard Disks_$($groupname).json"
 
    }
    
    $token = Get-AzCachedAccessToken
    #Export 14 Assessments - CSV
    if ($CSVassessments.count -ge 1) {
        Write-host "Exporting Assessment JSON Outputs" -Force Cyan
        $Output_VMAssessments_All_Machines =   "$path_to_Customers_folder\$($containername)\VM Assessments\$($dts_stamp)"
             If(Test-Path $Output_VMAssessments_All_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_VMAssessments_All_Machines }
             Set-location $Output_VMAssessments_All_Machines
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 1 Year RI AHUB_CSV" | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 1 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 1 Year RI AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 1 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 3 Year RI_CSV" | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 3 Year RI AHUB_CSV"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "As is 3 Year RI AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is PAYG_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is PAYG_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is PAYG AHUB_CSV"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is PAYG AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 3 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "Perf 1 Year RI AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 1 Year RI AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 3 Year RI_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 1 Year RI_CSV"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 1 Year RI_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG AHUB_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG - Premium Disks_CSV"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG - Premium Disks_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG - Standard Disks_CSV"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG - Standard Disks_$($groupname).json"
 

            Write-host "Exporting Assessment CSV Outputs" -Force Cyan
        $groupname = "All_Machines_CSV"
        $token = Get-AzCachedAccessToken
        $Output_VMAssessments_CSV_Machines =   "$path_to_Customers_folder\$($containername)\VM Assessments\+$($dts_stamp)\JSON"
        If(Test-Path $Output_VMAssessments_CSV_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_VMAssessments_CSV_Machines }
        Set-location $Output_VMAssessments_CSV_Machines
        Export-Bulk-VM-Assessments -SubscriptionID $SubscriptionID -ProjectName $project_name -ResourceGroup $rg -groupname $groupname -Token $token -CSV
    
    
    
    }
    $token = Get-AzCachedAccessToken

    #Export 6 Assessments - SQL
    if ($SQLassessments.count -ge 1) {

    
        $groupname= "All_Machines_SQL"
            $token = Get-AzCachedAccessToken
           $Output_All_Machines_SQL_Machines =   "$($path_to_Customers_folder)\$($containername)\SQL Assessments\$($dts_stamp)"
            If(Test-Path $Output_All_Machines_SQL_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_All_Machines_SQL_Machines }
            Set-location $Output_All_Machines_SQL_Machines
            Export-Bulk-SQL-Assessments -SubscriptionID $SubscriptionID -ProjectName $project_name -ResourceGroup $rg -groupname $groupname -Token $token
                  Write-host "Exporting Assessment JSON Outputs" -Force Cyan
                  $Output_All_Machines_SQL_Machines =   "$($path_to_Customers_folder)\$($containername)\SQL Assessments\+$($dts_stamp)\JSON" 
                  If(Test-Path $Output_All_Machines_SQL_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_All_Machines_SQL_Machines }
                  Set-location $Output_All_Machines_SQL_Machines
            Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $project_name -groupname $groupname -assessmentname "SQL_Perf 1 Year RI AHUB"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\SQL_Perf 1 Year RI AHUB_$($groupname).json"
            Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf 1 Year RI"  | ConvertTo-Json  -Depth 100 |Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\SQL_Perf 1 Year RI_$($groupname).json"
            Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf 3 Year RI"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\SQL_Perf 3 Year RI_$($groupname).json"
            Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\SQL_Perf 3 Year RI AHUB_$($groupname).json"
            Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf PAYG"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\SQL_Perf PAYG_$($groupname).json"
            Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf PAYG AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\SQL_Perf PAYG AHUB_$($groupname).json"
    
      

     

            # Action to perform if the condition is true #>

        }

    $token = Get-AzCachedAccessToken
cls



}
#Generate Tagging Sheet
if ($Generate_Tagging_Sheet -eq $true) {
    Set-Location     $path_to_Customers_folder\$containername\'API Infomation'
    If(Test-Path $dts_stamp) { "Output Folder Present" } Else { new-item -ItemType Directory -path $dts_stamp }
    Set-location $dts_stamp
    #"Generate Tagging Sheet",
    
    Write-Host "Exporting VM Scope File" -ForegroundColor Yellow
    Create-VM-Scope-Output -Output "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp"

    if ($discoveredSQLmachines.count -ge 1) {
        Write-Host "Exporting SQL Scope File" -ForegroundColor Yellow
        Create-SQL-Scope-Output "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp"
    }
    else
    {
    Write-Host "No SQL Machines found - Not Generating Tagging"
    
    }
        $token = Get-AzCachedAccessToken
}
#Generate Health State Infomation
if ($Generate_Health_State_Infomation -eq $true) {
#"Gather Health State Infomation",

$token = Get-AzCachedAccessToken
    <# Action to perform if the condition is true #>
    $Output_API_Infomation =   "$($path_to_Customers_folder)\$($containername)\API Infomation\"
    If(Test-Path $Output_API_Infomation) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_API_Infomation }
    Set-location $Output_API_Infomation
         Write-Host "Exporting Health State Infomation" -ForegroundColor Green 
        $jsonmachine = $machineList | ConvertTo-Json -Depth 100 | out-file machinelist.json   
         $jsonhealth = $health | ConvertTo-Json -Depth 100 | out-file healthsitesummary.json
         $jsonsqlinstances = $SQLInstances  | ConvertTo-Json -Depth 100 | out-file Discovered_SQL_Instances.json
         $discoveredmachines | ConvertTo-Json -Depth 100 | out-file Discovered_VMs.json      
         $discoveredSQLmachines | ConvertTo-Json -Depth 100 | out-file Discovered_SQL_Machine.json
         $stats = Get-AzureMigrateProjectStats -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name 
         $stats | ConvertTo-Json -Depth 100 | out-file ProjectInfo.json  

}
#Populate Scope Groups
if ($Populate_Scope_Groups -eq $true) {
    $token = Get-AzCachedAccessToken
    $VMtagging = Import-Csv -Path "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\VMScope.csv"
    Read-host "Please Update the VM Scope File with In/Out of Scope deffintions"
    ii .\VMScope.csv
    $VMtagging = Import-Csv -Path "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\VMScope.csv"
    $inscopevm = $VMtagging | Where-Object 'In/Out of Scope' -Like "In Scope" 
    $inscopevm | export-csv "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\VMScope.csv"
    
    
    
    
    $SQLtagging = Import-Csv -Path "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\SQLScope.csv"
    Read-host "Please Update the SQL Scope File with In/Out of Scope deffintions"
    ii .\SQLScope.csv
    $SQLtagging = Import-Csv -Path "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\SQLScope.csv"
    $inscopeSQL = $SQLtagging | Where-Object 'In/Out of Scope' -Like "In Scope" 
    $inscopeSQL | export-csv "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\SQLScope.csv"
    
    
    
    
    $token = Get-AzCachedAccessToken
    
    #"Populate Scope Groups",
    
        $VM_in_Scope_Group = New-AzureMigrateGroup -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName "VM_in_Scope"
        if ($discoveredSQLmachines -eq 0) {
            Write-Host "There are no SQL Servers - Skipping" -ForegroundColor Cyan
        }
        else {
            $SQL_In_Scope_Group = New-AzureMigrateGroup -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName "SQL_In_Scope"
        }
        Write-Host $nl  
        #Offer Option to Select VM ScopeFile
        if ($inscopevm.count -ne 0) {
               $groupname = "VM_in_Scope"
               $inscopemachines = Import-Csv "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\VMScope.csv" 
            Write-Host "Adding Machines to VM Scope Group" -ForegroundColor Cyan
        Set-AzureMigrateGroup -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $groupname -Machines $inscopemachines.id -Add
        }
        else {
            Write-Host "Please select the VM Scope file that you wish to update the VMScope Group with"
            $vmscopefile = Get-File
            $inscopemachines = Import-Csv $vmscopefile 
            $groupname = "VM_in_Scope"
            Write-Host "Adding Machines to VM Scope Group" -ForegroundColor Cyan
            Set-AzureMigrateGroup -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $groupname -Machines $inscopemachines -Add
        }
    
    
        if ($inscopeSQL.count -ne 0) {
            $groupname = "SQL_in_Scope"
            $inscopemachines = Import-Csv "$path_to_Customers_folder\$containername\API Infomation\$dts_stamp\SQLScope.csv" 
         Write-Host "Adding Machines to SQL Scope Group" -ForegroundColor Cyan
     Set-AzureMigrateGroup -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $groupname -Machines $inscopemachines.id -Add
     }
     else {
         Write-Host "Please select the VM Scope file that you wish to update the VMScope Group with"
         $SQLscopefile = Get-File
         $inscopemachines = Import-Csv $SQLscopefile 
         $groupname = "SQL_in_Scope"
         Write-Host "Adding Machines to SQL Scope Group" -ForegroundColor Cyan
         Set-AzureMigrateGroup -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $groupname -Machines $inscopemachines -Add
     }
    
        #Check for Status
        $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
        while ($groupStatus.Contains('Running') -or $groupStatus.Contains('Updated') -or $groupStatus.Contains('Created')) {
            Start-Sleep -Seconds 60
            $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
            [math]::Round($stopwatch.Elapsed.TotalMinutes, 1).ToString() + ' minutes'
        }
        $stopwatch.Stop()
    
}
#Create / refresh assessments and download them for Scope machines
if ($Create_refresh_assessments_download_Scope_machines -eq $true) {
    New-Item -Path "$path_to_Customers_folder\$($containername)\VM Assessments\$($dts_stamp)" -Name "ScopedVMExport.txt" -Force
 $token = Get-AzCachedAccessToken
#"Create / refresh assessments and download them for all machines"
#Required Actions

Write-Host "Refreshing Token" -ForegroundColor Green
$token = Get-AzCachedAccessToken
if ($discoveredmachines.count -ge 1000) {
    Write-host "More then 1000 VM Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
$timerangeVM = "Weekly"
}
elseif ($discoveredmachines.count -lt 1000) {
    $timerangeVM = "Monthly"
}

 if ($discoveredSQLmachines.count -ge 1000) {
        Write-host "More then 1000 SQL Machines dectected, Setting Assessment Time Range to Weekly to impove peformance" -ForegroundColor Red
        $timerangeSQL = "Weekly"
        }
 elseif ($discoveredCSVmachines.count -lt 1000) {
            $timerangeSQL = "Monthly"
        }
    

    Set-location $folder_path
    #Create 14 Assessmsnets - VM
    $token = Get-AzCachedAccessToken
    if ($discoveredmachines.count -ne 0) {
        Write-host "Begin Creating VM Assessments" -ForegroundColor Cyan
        Create-Bulk-VM-Assessments -Token $token -SubscriptionID $SubscriptionID -ProjectName $project_name -groupname "VM_in_Scope" -ResourceGroup $rg -discoverySource Appliance -timerange $timerangeVM
    
    }
    
    $token = Get-AzCachedAccessToken
    
    Set-location $folder_path
    #Create 6 Assessments - SQL
    $token = Get-AzCachedAccessToken
    if ($discoveredSQLmachines.count -ne 0) {
        Write-host "Begin Creating SQL Assessments" -ForegroundColor Cyan
        Create-Bulk-SQL-Assessments -Token $token -SubscriptionID $SubscriptionID -ProjectName $project_name -groupname "SQL_In_Scope" -ResourceGroup $rg -discoverySource Appliance -timerange $timerangeSQL
        
    }
    elseif ($discoveredSQLmachines.count -eq 0) {
        Write-Host "There are no SQL Servers - not creating Assessments" -ForegroundColor Cyan
    }
    $token = Get-AzCachedAccessToken

$assessments = Get-AzureMigrateAssessments -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
$VMassessments = $assessments | where-object {$_.properties.AssessmentType -eq "MachineAssessment" -and $_.properties.groupType -ne "Import"}  | Select-Object @{N="Group"; E={"All Machines"}}, @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}
$SQLassessments = $assessments | where-object {$_.properties.AssessmentType -eq "SqlAssessment"}  | Select-Object @{N="Group"; E={"All SQL Machines"}}, @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}
$CSVassessments = $assessments | where-object {$_.properties.groupType -eq "Import"}  | Select-Object @{N="Group"; E={"All CSV Machines"}}, @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}

    
    #Export 14 Assessments - VM
    if ($VMassessments.count -ge 1) {
        #Downlaod JSON Files
        Write-host "Exporting Assessment JSON Outputs" -Force Cyan
        $Output_VMAssessments_All_Machines =   "$path_to_Customers_folder\$($containername)\VM Assessments\$($dts_stamp)\JSON"
        If(Test-Path $Output_VMAssessments_All_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_VMAssessments_All_Machines }
        Set-location $Output_VMAssessments_All_Machines
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 1 Year RI AHUB" | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 1 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 1 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 1 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 3 Year RI"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is 3 Year RI AHUB"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "As is 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is 3 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is PAYG"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is PAYG_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "As is PAYG AHUB"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\As is PAYG AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 3 Year RI AHUB_$($groupname).json"
        Get-AzureMigrateAssessedMachines-by-Assessment -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -GroupName $groupname -assessmentname "Perf 1 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 1 Year RI AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 3 Year RI"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 3 Year RI_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf 1 Year RI"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf 1 Year RI_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\$dts_stamp\JSON\Perf PAYG AHUB_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG - Premium Disks"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\JSON\$dts_stamp\Perf PAYG - Premium Disks_$($groupname).json"
            Get-AzureMigrateAssessedMachines-by-Assessment -subscriptionId $subscriptionid -ResourceGroup $rg -Project $project_name -groupName $groupname -token $token  -assessmentName "Perf PAYG - Standard Disks"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\VM Assessments\JSON\$dts_stamp\Perf PAYG - Standard Disks_$($groupname).json"
 #Download XLS Files
 Write-host "Exporting Assessment XLS Outputs" -Force Cyan
        $groupname = "VM_in_Scope"
        $token = Get-AzCachedAccessToken
        $Output_VMAssessments_All_Machines =   "$path_to_Customers_folder\$($containername)\VM Assessments\$($dts_stamp)"
        If(Test-Path $Output_VMAssessments_All_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_VMAssessments_All_Machines }
        Set-location $Output_VMAssessments_All_Machines
        Export-Bulk-VM-Assessments -SubscriptionID $SubscriptionID -ProjectName $project_name -ResourceGroup $rg -groupname $groupname -Token $token

   
    }
    
    $token = Get-AzCachedAccessToken

    #Export 6 Assessments - SQL
    if ($SQLassessments.count -ge 1) {
        $jsonsqlinstances = $SQLInstances  | ConvertTo-Json -Depth 100 | out-file Discovered_SQL_Instances.json
        Write-host "Exporting Assessment JSON Outputs" -Force Cyan
        $Output_All_Machines_SQL_Machines =   "$($path_to_Customers_folder)\$($containername)\SQL Assessments\+$($dts_stamp)\JSON" 
        If(Test-Path $Output_All_Machines_SQL_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_All_Machines_SQL_Machines }
        Set-location $Output_All_Machines_SQL_Machines
  Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName $project_name -groupname $groupname -assessmentname "SQL_Perf 1 Year RI AHUB"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\SQL Assessments\$dts_stamp\JSON\SQL_Perf 1 Year RI AHUB_$($groupname).json"
  Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf 1 Year RI"  | ConvertTo-Json  -Depth 100 |Out-File "$path_to_Customers_folder\$containername\SQL Assessments\$dts_stamp\JSON\SQL_Perf 1 Year RI_$($groupname).json"
  Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf 3 Year RI"  | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\SQL Assessments\$dts_stamp\JSON\SQL_Perf 3 Year RI_$($groupname).json"
  Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf 3 Year RI AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\SQL Assessments\$dts_stamp\JSON\SQL_Perf 3 Year RI AHUB_$($groupname).json"
  Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf PAYG"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\SQL Assessments\$dts_stamp\JSON\SQL_Perf PAYG_$($groupname).json"
  Get-AzureMigrate-SQLDiscovervedDatabases -Token $token -SubscriptionID $subscriptionid -ResoruceGroup $rg -ProjectName  $project_name -groupname $groupname -assessmentname "SQL_Perf PAYG AHUB"   | ConvertTo-Json  -Depth 100 | Out-File "$path_to_Customers_folder\$containername\SQL Assessments\$dts_stamp\JSON\SQL_Perf PAYG AHUB_$($groupname).json"

  Write-host "Exporting Assessment XLS Outputs" -Force Cyan
        $groupname= "SQL_in_Scope"
            $token = Get-AzCachedAccessToken
           $Output_All_Machines_SQL_Machines =   "$($path_to_Customers_folder)\$($containername)\SQL Assessments\"+$($dts_stamp) 
            If(Test-Path $Output_All_Machines_SQL_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_All_Machines_SQL_Machines }
            Set-location $Output_All_Machines_SQL_Machines
            Export-Bulk-SQL-Assessments -SubscriptionID $SubscriptionID -ProjectName $project_name -ResourceGroup $rg -groupname $groupname -Token $token
       
      

     

            # Action to perform if the condition is true #>

        }

    $token = Get-AzCachedAccessToken
cls



}
#Enable Depdedancy
if ($Enable_Depdedancy -eq $true) {

    $token = Get-AzCachedAccessToken
    #Get List of VMs
    Set-Location     $path_to_Customers_folder\$containername\'API Infomation'
    If(Test-Path $dts_stamp) { "Output Folder Present" } Else { new-item -ItemType Directory -path $dts_stamp }
    Set-location $dts_stamp
    $output = new-item -ItemType Directory -Path "Depdendancy Output" -Force
    Get-AzMigDiscoveredVMwareVMs -ResourceGroupName $rg -ProjectName $project_friendly_name -OutputCsvFile "$output/Application_Depednacy_Discovered_VMs.csv"
    $file = Get-Content "$output/Application_Depednacy_Discovered_VMs.csv"
    
    if($file.count -gt 1000)
    {Write-host "More then 1000 machines in file, splitting file in to chunks"
    
    $InputFilename = Get-Content 'Application_Depednacy_Discovered_VMs.csv'
    $OutputFilenamePattern = 'output_done_'
    $LineLimit = 1000
    $line = 0
    $i = 0
    $file = 0
    $start = 0
    while ($line -le $InputFilename.Length) {
    if ($i -eq $LineLimit -Or $line -eq $InputFilename.Length) {
    $file++
    $Filename = "$OutputFilenamePattern$file.csv"
    $InputFilename[$start..($line-1)] | Out-File "$output/$Filename" -Force
    $start = $line;
    $i = 0
    Write-Host "$Filename"
    }
    $i++;
    $line++
    }
    Set-Location $path_to_Customers_folder\$containername\'API Infomation'\$dts_stamp\'Depdendancy Output'
    $inputfiles = Get-ChildItem '.\' -Filter *.csv
    foreach ($file in $inputfiles) {
        $file.name
        Set-AzMigDependencyMappingAgentless -InputCsvFile $file -Enable
    }
    
    
    
    
    }
    else
    {
        Set-Location $path_to_Customers_folder\$containername\'API Infomation'\$dts_stamp\'Depdendancy Output'
        $inputfiles = Get-ChildItem '.\' -Filter *.csv
        foreach ($file in $inputfiles) {
            $file.name
            Set-AzMigDependencyMappingAgentless -InputCsvFile $file -Enable
        }
    
    }
}
#Uplaod to Blob
if ($Uplaod_Data_to_Customer_Blob -eq $true) {
    $folders_choice_options = Get-ChildItem $path_to_Customers_folder\$containername -Directory | select name
    $folders_choice_options  =  $folders_choice_options | Out-ConsoleGridView -Title "Choose Uplaod Options" -OutputMode Single
    $folders_choice_options = $folders_choice_options.Name
    if ($folders_choice_options -eq $null) { exit }
    
    if ($folders_choice_options -eq "API Infomation") {
        Write-host "Uplaoding API Assessment Files" -ForegroundColor Green
        Upload-Files-To-ADLS-Customer-Container -path_to_files "$($containername)\API Infomation\"
        
    }
    if ($folders_choice_options -eq "VM Assessments") {
        Write-host "Uplaoding VM Assessment Files" -ForegroundColor Green
        Upload-Files-To-ADLS-Customer-Container -path_to_files "$($containername)\VM Assessments\$dts_stamp\"
        
    }
    if ($folders_choice_options -eq "SQL Assessments") {
        Write-host "Uplaoding SQL Assessment Files" -ForegroundColor Green
        Upload-Files-To-ADLS-Customer-Container -path_to_files "$($containername)\SQL Assessments\$dts_stamp\"
        
    }  
    if ($folders_choice_options -eq "Environment Context Information") {
        Write-host "Uplaoding SQL Assessment Files" -ForegroundColor Green
        Upload-Files-To-ADLS-Customer-Container -path_to_files "$($containername)\Environment Context Information\"
        
    }  
}

if ($Export_Full_API_Dump -eq $true) {
    $Output_API_Infomation =   "$($path_to_Customers_folder)\$($containername)\API Infomation\"
    If(Test-Path $Output_API_Infomation) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_API_Infomation }
    Set-location $Output_API_Infomation
    Write-Host "Exporting API Dump Infomation" -ForegroundColor Green
    Get-AzureMigrateEnumerateMachines -Token $token -SubscriptionID $subscriptionID -ResourceGroup $rg -Project $project_friendly_name |ConvertTo-Json -Depth 100 | Out-File -FilePath .\API_Dump.json

}
##ADvanced Start##

if ($Create_Assessments_from_Group -eq $true) {
   #List Groups
   $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
   $Group_Select  =  $AzMigGroups | select name | Out-ConsoleGridView -Title "Choose Group" -OutputMode Single
        #List Assessments
        $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name
        $assessments_Select  =  $assessments | select name | Out-ConsoleGridView -Title "Choose Assessment" -OutputMode Single

        #Create Assessment

}


if ($Remove_Assessments_from_Group-eq $true) {
    #List Groups
      $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
      $Group_Select  =  $AzMigGroups | select name | Out-ConsoleGridView -Title "Choose Group" -OutputMode Single
      if ($Group_Select -eq $null) { exit }
           #List Assessments
           if ($Group_Select.name -match  "SQL*") {
               Write-host "true"
            $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name -SQL
            $assessments_Select  =  $assessments | select name | Out-ConsoleGridView -Title "Choose Assessment" -OutputMode Single
           }
           else {
               Write-Host "false"
            $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name 
            $assessments_Select  =  $assessments | select name | Out-ConsoleGridView -Title "Choose Assessment" -OutputMode Single
     
           }
           
         
           #Remove Assessment
    if ($assessments_Select.name -ceq "SQL") {
        $groupname= $Group_Select.name
        $token = Get-AzCachedAccessToken
Write-host "Removing Assessment $($assessments_Select.name)" -ForegroundColor red
        Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -AssessmentName $assessments_Select.name -Group $groupname -SQL
    cls
    }else {
        $groupname = $Group_Select.name

        $token = Get-AzCachedAccessToken
Write-host "Removing Assessment $($assessments_Select.name)" -ForegroundColor red
        Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -AssessmentName $assessments_Select.name -Group $groupname
    }
   
    }

if ($Download_Assessments_from_Group-eq $true) {
    #List Groups
      $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
      $Group_Select  =  $AzMigGroups | select name | Out-ConsoleGridView -Title "Choose Group" -OutputMode Single
      if ($Group_Select -eq $null) { exit }
           #List Assessments
           if ($Group_Select -ceq "SQL") {
            $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name -SQL
            $assessments_Select  =  $assessments | select name | Out-ConsoleGridView -Title "Choose Assessment" -OutputMode Single
           }
           else {
            $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name 
            $assessments_Select  =  $assessments | select name | Out-ConsoleGridView -Title "Choose Assessment" -OutputMode Single
     
           }
           
         
           #Download Assessment
    if ($assessments_Select.name -ceq "SQL") {
        $groupname= $Group_Select.name
        $token = Get-AzCachedAccessToken
       $Output_All_Machines_SQL_Machines =   "$($path_to_Customers_folder)\$($containername)\SQL Assessments\$($dts_stamp)"
        If(Test-Path $Output_All_Machines_SQL_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_All_Machines_SQL_Machines }
        Set-location $Output_All_Machines_SQL_Machines  
        Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $project_name -groupName $Group_Select.name -token $token  -assessmentName $assessments_Select.name
    cls
    }else {
        $groupname = $Group_Select.name
        $token = Get-AzCachedAccessToken
        $Output_VMAssessments_All_Machines =   "$path_to_Customers_folder\$($containername)\VM Assessments\$($dts_stamp)"
        If(Test-Path $Output_VMAssessments_All_Machines) { "Output Folder Present" } Else { new-item -ItemType Directory -path $Output_VMAssessments_All_Machines }
        Set-location $Output_VMAssessments_All_Machines
        Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $project_name -groupName $Group_Select.name -token $token -assessmentName $assessments_Select.name 

    }
   
    }

if ($Remove_Outdated_Assessments -eq $true) {
#List Groups
$AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name
$Group_Select  =  $AzMigGroups | select name | Out-ConsoleGridView -Title "Choose Group" -OutputMode Single
if ($Group_Select -eq $null) { exit }
     #List Assessments
     if ($Group_Select.name -match  "SQL*") {
         Write-host "true"
      $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name -SQL
      $SQLassessments = $assessments | where-object {$_.properties.AssessmentType -eq "sqlAssessment" -and $_.properties.status -eq "Outdated"}  | Select-Object @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}
       Write-host "Found $($SQLassessments.count) Outdated Assessments" -ForegroundColor red 
       foreach ($SQLassessment in $SQLassessments) {
        $SQLassessment
        Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -AssessmentName $SQLassessment.name -Group $Group_Select.name -SQL
    }
 
     }
     else {
         Write-Host "false"
         $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name
         $VMassessments = $assessments | where-object {$_.properties.AssessmentType -eq "MachineAssessment" -and $_.properties.groupType -ne "Import" -and $_.properties.status -eq "Outdated"}  | Select-Object @{N="Assessment Name"; E={$_.name}},  @{N="Assessment Type"; E={$_.properties.assessmentType}},@{N="Status"; E={$_.properties.status}}
         Write-host "Found $($Vmassessments.count) Outdated Assessments" -ForegroundColor red 
         foreach ($Vmassessment in $VMassessments) {
            Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -AssessmentName $vmassessment.name -Group $Group_Select.name -SQL
           }

      $assessments = Get-AzureMigrateAssessments-by-Group -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name -Group $Group_Select.name 
      $assessments_Select  =  $assessments | select name | Out-ConsoleGridView -Title "Choose Assessment" -OutputMode Single

     }
     
   
     #Remove Assessment
if ($assessments_Select.name -ceq "SQL") {
  $groupname= $Group_Select.name
  $token = Get-AzCachedAccessToken
Write-host "Removing Assessment $($assessments_Select.name)" -ForegroundColor red
  Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -AssessmentName $assessments_Select.name -Group $groupname -SQL
cls
}else {
  $groupname = $Group_Select.name

  $token = Get-AzCachedAccessToken
Write-host "Removing Assessment $($assessments_Select.name)" -ForegroundColor red
  Remove-AzureMigrateAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $project_name -AssessmentName $assessments_Select.name -Group $groupname
}
}
if ($Remove_All_VM_Assessments-eq $true) {
    $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name |where-object {$_.name -NotMatch "SQL"}
    $Group_Select  =  $AzMigGroups | select name | Out-ConsoleGridView -Title "Choose Group" -OutputMode Single
    if ($Group_Select -eq $null) { exit }
    Remove-Bulk-VM-Assessments -Token $token -SubscriptionID $SubscriptionID -ProjectName $project_name -ResourceGroup $rg -groupname $Group_Select.name 

}
if ($Remove_All_SQL_Assessments-eq $true) {
    $AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg -Project $project_name |where-object {$_.name -Match "SQL"}
    $Group_Select  =  $AzMigGroups | select name | Out-ConsoleGridView -Title "Choose Group" -OutputMode Single
    if ($Group_Select -eq $null) { exit }
    Remove-Bulk-SQL-Assessments -Token $token -SubscriptionID $SubscriptionID -ProjectName $project_name -ResourceGroup $rg -groupname $Group_Select.name 

}

}
