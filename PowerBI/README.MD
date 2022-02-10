# AzMigrate Power BI Deliverable
A Power BI Dashboard to display Azure Migrate Outputs



Function:
To Display and Deliver SMB Azure Migrate Assessments

Requirements
1.	Azure Migrate Outputs for VM and SQL Assessments (See AzMigrateAssessment Downloader)
2.  Azure Migrate File Combiner.xlsm
2.	A Completed P-Edit File (Customer Action)
3.  A Power BI Premium Subscription (For Publishing/Exporting)
4.  Power BI Desktop Installed
5.  Access to the Inviso HUB on Sharepoint
5.	A large Coffee (or Tea)

Outputs:
Power BI Dashboard with Customers data imported


**Known issues as of 09/02/2022**

- Can take a while to Import
- If files are miss imported into the Excel, the import may fail.

**TO DO as of 09/02/2022**
- Intergrate RDIA output
- Add tabs on Storage growth
- Investigate Web Sevice to replace File Combiner Macro

Method 

**Combine Azure Migrate Outputs**
- Download all requried assessment items 
- Open Azure Migrate File Combiner.xlsm
- Allow Macros to run
- Copy all Assessment files into central location
- Click Merge Files Button
- Select all files from central location
- Click Open
- Workbooks will open in turn, and sheets will be coppeid to new tabs in this workbook
- Save resulting file as <Customer>_AzureMigrate_Export.xlsx

**Import into Power BI**
- Open Power BI (Suggested as Admin)
- Open Contoso_SMB_Data and Infra.pbix
- Open the Transform Data menu > Edit Paramaters
- Update WorkbookLocation to point to your combined Excel Workbook from above
- **First Run Only** You will be prompted to confirm creditals to a number of external data sources
    -   https://app-omaha-prod.azurewebsites.net/ - Select Anonymous as the Authentication option
    -   https://inviso.sharepoint.com - Select Orgianzational Account, and Login with your Inviso Creditals
- Update P-Edit Location to point to your location of your P-Edit Workbook
- Click OK

The Workbook will now import your data, this can take some time. (30 -60min), once complete validate that the data/costs look correct.

You can now use the Data Verification tabs toward the end of the file, have views to help with troubleshooting the data.

**Exporting to Power BI Service **

TBD