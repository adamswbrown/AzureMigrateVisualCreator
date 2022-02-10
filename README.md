# AzMigrateAssessmentDownloader
Tool to Download Azure Migrate Assessments

Azure Migrate Assessment Download

Function:
To download the required VM and SQL assessments needed to produce Azure Assessments from a customers Azure Migrate environment

Requirements
1.	Access to Customers Azure Migrate environment (Contributor preferred)
2.	Azure Active Directory Tennant ID
3.	Azure Subscription name/ID
4.	Name of the resource group where the Azure Migrate Project resides
5.	Azure Migrate Export Scripts/Assessment Templates

Outputs:
VM Assessments:
•	As is 1 Year RI AHUB
•	As is 1 Year RI     
•	As is 3 Year RI AHUB
•	As is 3 Year RI     
•	As is PAYG AHUB     
•	As is PAYG          
•	Perf 1 Year RI AHUB 
•	Perf 1 Year RI      
•	Perf 3 Year RI AHUB 
•	Perf 3 Year RI      
•	Perf PAYG AHUB      
•	Perf PAYG
•	Perf PAYG - Premium Disks         
SQL Assessments
•	Perf 1 Year RI AHUB 
•	Perf 1 Year RI      
•	Perf 3 Year RI AHUB 
•	Perf 3 Year RI      
•	Perf PAYG AHUB      
•	Perf PAYG   

Machine Group Membership
•    Group_Membership

Note: if you wish to change the values in the Assessment JSON's remember to make the changes within each of the assessments you wish to use.


**Known issues as of 09/02/2022**

- Does not manage multiple Azure Migrate Projects well (Workarround availabile)
- Can time out due to large assessment numbers (No Workarround Availaible)

**TO DO as of 09/02/2022**
- Add Function to download Applicaiton Catalouge
- Ad Function to Create AVS Assessments
- Investigate IIS Assessments

Method 

- Create customer export folder to hold the reports
- Copy Export Scripts and Assessment Templates from Devops Folder (AZ Assessment Downloader)

- Open Setup.PS1 in PowerShell ISE or similar  (as Admin preferred)
- Change your current path to your working directory
- Run Script (Green Play button)
- When prompted enter the Tennant ID, and Subscription ID of the customer you wish to export from
- You will now be prompted to select the resource group the Azure Migrate Project resides in (typically there are only a few options)
- Select the Resource Group and click OK

The next sections of the script will run automatically:
- Listing Current VMs
- The script will compile a list of machines that have been discovered, and return the number, provides you a Grid view to inspect the machines discovered. – Dismiss the grid view to continue the script

Listing Current SQL Servers
The script will compile a list of SQL machines that have been discovered, and return the number, provides you a Grid view to inspect the machines discovered. – Dismiss the grid view to continue the script

•	Creating Groups for both
The Script will create a Group for both SQL and VM assets, and will add the machines to that group.

•	Exporting Group Membership
The Script will Export Membership of All groups that exisit within the project. This file will be exported as Group_Membership.CSV in the root folder


•	Creating Assessments
The Script will create assessments for VM and SQL machines. This can take some time.

•	Downloading Assessments
The Script will then downlaod the assessments to the current working directory.

These exports will be downloaded to the current folder. This can take several minutes to complete.

The Script will return to the normal prompt once completed.
