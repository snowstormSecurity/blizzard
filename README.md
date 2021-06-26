# Blizzard

Blizzard is the code name given to the PowerShell module to define and test network ACL & micro-segmentation rules within an environment.

## Getting Started

To build an initial ACL testing file, update the ``.\config\serverList.list`` file (or create a new list), then run:

```powershell
Import-Module Blizzard
$listofServers = '.\Config\serverList.list'
$outputConfig = '.\Config\myTestACLs.csv'
new-initialACLScan -systemNames $listofServers -config $outputConfig -verbose
```

Once the configuration file has been setup, open the document with Excel and update the ``expectedResults`` property to match how the test should be expected to return.

To start testing, run:

```powershell

# Start Testing
Import-Module Blizzard
$Config = '.\Config\myTestACLs.csv'
$aclTests = get-aclTest -config $Config
aclTestResults = $aclTests | invoke-aclTest

# Export Results to XML
$aclTestResults | export-cliXML -path .\results\aclTestResults.xml -depth 2

# Run Pester Test Result
convert-aclTestReport -xmlFile (get-item .\results\aclTestResults.xml)
```
  