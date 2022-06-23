import-module E:\repo\AzureMigrateFunction\Module\V2SQL.psm1 -force
import-module E:\repo\AzureMigrateFunction\Module\AzMigrate.psm1 -force -Prefix old

$token = Get-AzCachedAccessToken

$SubscriptionID = "cb9bc043-5d05-480b-96fd-30cfd19877b1"
$rg = "RG-UKHSA-UKS-AZ-MIGRATION"
$project_name = "AzureMigCOL017808project"
$project_friendly_name = "BigRock-Optimisation"
$groupname = "All_Machines_SQL"
$assessmentname = "SQL_Perf PAYG"

$assessedDBName = "Not Known"
$assessedInstanceName = "Test"
$assessedSqlMachineName = "PROWTESTPOR01"
$recommendedAssessedEntityName ="PROWTESTPOR01"

#Get All Databases that have been assessed 
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-assessedSqlDatabases -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -AssessmentName $assessmentname -V2API

#Get single assessed Database
#ISSUE - Fails - Needs Database Name, not given
Get-AzureMigrate-assessedSqlDatabase -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -AssessmentName $assessmentname -assessedSqlDatabaseName $assessedDBName -V2API

#Get All Instances that have been assessed 
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-assessedSqlInstances -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -AssessmentName $assessmentname -V2API


#Get Single assessed instance 
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-assessedSqlInstance -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -AssessmentName $assessmentname -assessedSqlInstanceName $assessedInstanceName -V2API

#Get All assessed SQL Machines 
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-assessedSqlMachines -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -AssessmentName $assessmentname -V2API

#Get Single assessed SQL Machine 
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-assessedSqlMachine -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -AssessmentName $assessmentname -assessedSqlMachineName $assessedSqlMachineName -V2API


#Get All Assessed Recomdnedations
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-AssessedSQLRecomendations -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -V2API

#Get A single Recomdnedation
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-AssessedSQLRecomendation -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -recommendedAssessedEntityName $recommendedAssessedEntityName -V2API


#Get All SQL Assessments
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-SQLAssessments -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -V2API

#Get Single SQL Assessment
# ISSUE - UK South is not supoorted - most likely not deployed.
Get-AzureMigrate-SQLAssessment -Token $token -SubscriptionID $SubscriptionID -ResoruceGroup $rg -ProjectName $project_name -Groupname $groupname -assessmentName $assessmentname -V2API


#Create SQL Assessment
# ISSUE - UK South is not supoorted - most likely not deployed.
#TODO
