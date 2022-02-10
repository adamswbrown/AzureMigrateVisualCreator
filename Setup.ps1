Import-Module .\AzMigrate.psm1 -Force

$TennantID = Read-Host -Prompt "Enter the Azure Tennant ID for the Customer"
$SubscriptionID = Read-Host -Prompt "Enter the Azure Subscription ID for the Customer"
Write-Host "You will now be prompted for Login with your account that has access to the Customer Tennant"
Connect-AzAccount -Tenant $TennantID -Subscription $SubscriptionID

#Select Subscription
$sub= select-subscription
$subscriptionid = (Get-AzContext).Subscription.id

$subscriptionid = Get-AzSubscription -SubscriptionId $SubscriptionID
Set-AzContext -SubscriptionId $subscriptionid

Write-Host "Prompting for Resoruce Group" -ForegroundColor Yellow
$resourceGroup = select-resorucegroup
$rg = $resourceGroup.ResourceGroupName
Write-Host "Resoruce Group Selected " -ForegroundColor Green




# Retrieve a bearer token for use when interacting with the underlying REST API:
$token = Get-AzCachedAccessToken

#Get a list of all available Azure Migrate projects in the subscription
$projects = Get-AzureMigrateProject -Token $token -SubscriptionID $subscriptionid -Verbose

#Get a list of discovered machines from the first project returned above
$discoveredmachines = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name

#Get a list of discovered SQL machines from the first project returned above
$discoveredSQLmachines = Get-AzureMigrateDiscoveredSQLMachine -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name
# Review the output of the above command

#Get a list of discovered AVS machines from the first project returned above
$discoveredAVSmachines = Get-AzureMigrateDiscoveredAVSMachine -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name
# Review the output of the above command



Write-Host "Here are the  $($discoveredSQLmachines.Count) SQL Machines that have been discovered" -ForegroundColor Yellow
$discoveredSQLmachines | Select-Object {$_.properties.displayname}, {$_.properties.megabytesofmemory}, {$_.properties.numberofcores}, {$_.properties.operatingsystemname} |Out-GridView

# Review the output of the above command
Write-Host "Here are the  $($discoveredmachines.Count) VM Machines that have been discovered" -ForegroundColor Yellow
$discoveredmachines | Select-Object {$_.properties.displayname}, {$_.properties.megabytesofmemory}, {$_.properties.numberofcores}, {$_.properties.operatingsystemname} |Out-GridView

# Review the output of the above command
Write-Host "Here are the  $($discoveredmachines.Count) AVS Machines that have been discovered" -ForegroundColor Yellow
$discoveredAVSmachines | Select-Object {$_.properties.displayname}, {$_.properties.megabytesofmemory}, {$_.properties.numberofcores}, {$_.properties.operatingsystemname} |Out-GridView




# Get a list of groups associated with a project
$AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name
# Review the list of groups returned
$AzMigGroups | Select-Object name, {$_.properties.machinecount}





##

# Create a new, empty group
$newgroup = New-AzureMigrateGroup -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -GroupName "All_Machines_2" -Verbose
$newgroupSQL = New-AzureMigrateGroup -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -GroupName "All_Machines_SQL" -Verbose




# Add machines to the new group
If($discoveredmachines.count -gt 0){
Write-Host "Adding $($discoveredmachines.count) to Group $($newgroup.name)" -f Yellow
$updatedGroupVM = Set-AzureMigrateGroup -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -Group $newgroup.name -Machines $discoveredmachines -Add

}
else

{Write-host "No Machines to Add To Group" -f Red}


#Add SQL Machiens to new Group
If($discoveredSQLmachines.count -gt 0){
Write-Host "Adding $($discoveredSQLmachines.count) to Group $($newgroupSQL.name)" -f Yellow
$updatedGroupSQL = Set-AzureMigrateGroup -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -Group $newgroupSQL.name -Machines $discoveredSQLmachines -Add
}
else{

Write-host "No Machines to Add To Group" -f Red
}
# Re-run the Get-AzMigrateGroups command to get the updated list of groups and verify the new group was created and has machines added to it
$AzMigGroups = Get-AzureMigrateGroups -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name
$AzMigGroups | Select-Object name, {$_.properties.machinecount}



foreach ($Group in $AzMigGroups)

{

Write-Host "Exporting Group Membership for $($group.name)" -f Yellow 
$Output = Get-AzureMigrateDiscoveredMachine -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -GroupName $Group.name
$Output | Select-Object @{Name = "Group Name"; Expression = {$group.name}}, @{Name = "Device Name"; Expression = {$_.properties.displayname}}  | Export-CSV Group_Membership.csv -NoClobber -NoTypeInformation -Append



}







# Create VM assessments for the new group using our assessment templates
Write-Host "Creating VM Assessments" -ForegroundColor Yellow
Write-Host "As is 1 Year RI AHUB"
$VM_Asis1YearRIAHUB = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "As is 1 Year RI AHUB" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\As is 1 Year RI AHUB.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "As is 1 Year RI"
$VM_Asis1YearRI    = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "As is 1 Year RI" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\As is 1 Year RI.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20


 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "As is 3 Year RI"
$VM_Asis3YearRI     =New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "As is 3 Year RI" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\As is 3 Year RI.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20


Write-Host "As is 3 Year RI AHUB"
$VM_Asis3YearRI     =New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "As is 3 Year RI AHUB" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\As is 3 Year RI AHUB.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20


Write-Host "As is Pay Go AHUB"
$VM_AsisPAYGAHUB  =New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "As is PAYG AHUB" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\As is PAYG AHUB.json' 
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "As is Pay Go"
$VM_AsisPAYG     = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "As is PAYG" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\As is PAYG.json'     
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "Perf 1 Year RI AHUB"
$VM_Perf1YearRIAHUB  = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "Perf 1 Year RI AHUB" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\Perf 1 Year RI AHUB.json'   
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20


Write-Host "Perf 1 Year RI"
$VM_Perf1YearRI     = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "Perf 1 Year RI" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\Perf 1 Year RI.json'   
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20


Write-Host "Perf 3 Year RI AHUB"
$VM_Perf3YearRIAHUB = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "Perf 3 Year RI AHUB" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\Perf 3 Year RI AHUB.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20


Write-Host "Perf 3 Year RI"
$VM_Perf3YearRI =  New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "Perf 3 Year RI" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\Perf 3 Year RI.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20


Write-Host "Perf Pay Go"
$VM_PerfPAYG  = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "Perf PAYG" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\Perf PAYG.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "Perf Pay Go - Premium Disks"
$VM_PerfPAYG_PremiumDisk  = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "Perf PAYG - Premium Disks" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\Perf PAYG - Premium Disks.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "Perf Pay Go AHUB"
$VM_PerfPAYGAHUB  = New-AzureMigrateVMAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "Perf PAYG AHUB" -Group $updatedGroupVM.name -AssessmentProperties '.\Assessments\Perf PAYG AHUB.json'
  ###Pausing for 20s between every assessment creation request

        Start-Sleep -s 20
 Write-Host "Finished Creating VM Assessments" -ForegroundColor Yellow



     



# Get a summary of assessments for the project
$assessments = Get-AzureMigrateAssessments -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name
# Review summary of assessments returned
$assessments |Select-Object name, @{Name='Type';Expression={$_.properties.sizingcriterion}}, @{Name='Status';Expression={$_.properties.status}}








# Export VM Assessments
Write-Host "Start Downloading VM Assessments" -ForegroundColor Yellow
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token -assessmentName "As is 1 Year RI AHUB"
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "As is 3 Year RI"
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "As is 3 Year RI AHUB"
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "As is 1 Year RI" 
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "As is PAYG" 
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "As is PAYG AHUB"     
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "Perf 1 Year RI AHUB"
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "Perf PAYG"
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "Perf PAYG AHUB"
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "Perf PAYG - Premium Disks"
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "Perf 3 Year RI"  
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "Perf 1 Year RI"    
Export-VMAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupVM.name -token $token  -assessmentName "Perf 3 Year RI AHUB" 
Write-Host "Finished Downlaoding VM Assessments" -ForegroundColor Yellow




# Create SQL assessments for the new group using our assessment templates
Write-Host "Creating SQL Assessments" -ForegroundColor Yellow
Write-Host "Perf 1 Year RI AHUB"
$SQL_Perf1YearRIAHUB  = New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "SQL_Perf 1 Year RI AHUB" -Group $updatedGroupSQL.name -AssessmentProperties '.\Assessments\SQL\SQL_Perf 1 Year RI AHUB.json'   
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20
Write-Host "Perf 1 Year RI"
$SQL_Perf1YearRI     = New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "SQL_Perf 1 Year RI" -Group $updatedGroupSQL.name -AssessmentProperties '.\Assessments\SQL_Perf 1 Year RI.json'   
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20
Write-Host "Perf 3 Year RI AHUB"
$SQL_Perf3YearRIAHUB = New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "SQL_Perf 3 Year RI AHUB" -Group $updatedGroupSQL.name -AssessmentProperties '.\Assessments\SQL_Perf 1 Year RI.json'
 ###Pausing for 20s between every assessment creation request
 Write-Host "Perf 1 Year RI "
        Start-Sleep -s 20
$SQL_Perf3YearRI =  New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "SQL_Perf 3 Year RI" -Group $updatedGroupSQL.name -AssessmentProperties '.\Assessments\SQL_Perf 3 Year RI AHUB.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "Perf Pay Go"
$SQL_PerfPAYG  = New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "SQL_Perf PAYG" -Group $updatedGroupSQL.name -AssessmentProperties '.\Assessments\SQL_Perf PAYG.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20

Write-Host "Perf Pay Go AHUB"
$SQL_PerfPAYGAHUB  = New-AzureMigrateSQLAssessment -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name -AssessmentName "SQL_Perf PAYG AHUB" -Group $updatedGroupSQL.name -AssessmentProperties '.\Assessments\SQL_Perf PAYG AHUB.json'
 ###Pausing for 20s between every assessment creation request
        Start-Sleep -s 20
Write-Host "Finished Creating SQL Assessments" -ForegroundColor Yellow


# Get a summary of assessments for the project
$assessments = Get-AzureMigrateAssessments -Token $token -SubscriptionID $subscriptionid -ResourceGroup $rg -Project $projects[0].name
# Review summary of assessments returned
$assessments |Select-Object name, @{Name='Type';Expression={$_.properties.sizingcriterion}}, @{Name='Status';Expression={$_.properties.status}}


        
#Export SQL Assessments
Write-Host "Exporting SQL Assessments" -ForegroundColor Yellow
Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupSQL.name -token $token  -assessmentName "SQL_Perf 1 Year RI AHUB"
Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupSQL.name -token $token  -assessmentName "SQL_Perf 1 Year RI"
Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupSQL.name -token $token  -assessmentName "SQL_Perf 3 Year RI AHUB"   
Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupSQL.name -token $token  -assessmentName "SQL_Perf 3 Year RI"  
Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupSQL.name -token $token  -assessmentName "SQL_Perf PAYG"    
Export-SQLAssessment -subscriptionId $subscriptionid -resourceGroupName $rg -assessmentProjectName $projects[0].name -groupName $updatedGroupSQL.name -token $token  -assessmentName "SQL_Perf PAYG AHUB" 
Write-Host "Finished Exporting SQL Assessments" -ForegroundColor Yellow


#Get Vmware Sites
$VmwareSites = Get-AzureMigrateVMWareSite -Token $token -SubscriptionID $SubscriptionID -ResourceGroup $rg
$VmwareSites |Select-Object name, tags, @{Name='Status';Expression={$_.properties.provisioningState}}

#Export-SoftwareInventory -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -VmwareSite $VmwareSites[0].name
