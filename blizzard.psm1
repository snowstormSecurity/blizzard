function new-aclTest { 
<#
.EXTERNALHELP xxxxx.psm1-Help.xml
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1)][string]$testName,
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2)][string]$Source,
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 3)][Alias('Target')][string]$Destination,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 4)][string]$Port,
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 5)][ValidateSet('True', 'False')][String]$expectedResult,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 6)][string]$ticketID,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 7)][string]$comments,
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 8)][ValidateSet('ping', 'tcp','icmp')][string]$method,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 9)][int]$timeout=100,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 99)][Alias('csv')][string]$config
    )

    # Create empty Object
    $diagOutputProperties = [ordered]@{
        TestName = $testName
        Source = $Source
        Destination = $Destination
        Port = $Port
        expectedResult = $expectedResult
        sourceDescription = ""
        destinationDesc = ""
        Method = $method
        Timeout = $timeout
        ticketID = $ticketID
        comments = $comments
    }
    $diagOutput = New-Object psObject -Property $diagOutputProperties

    # Test for existance of $config
    if((Test-Path -path $config) -eq $false){
        Write-Verbose "Configuration File not found.  Creating empty file" -Verbose
        $diagOutput | Export-Csv -path $config -Force -NoTypeInformation

    }
    else{
        $csv = Import-CSV -path $config

        if($csv.testname -contains $testName){
            Write-Verbose "Test Name: $($testName) already exists and can not be added" -Verbose
            Write-Verbose " - Action: Create new 'Testname' -or- remove existing test with remove-aclTest" -Verbose
            break
        }
        ($diagOutput | convertTo-CSV -NoTypeInformation)[-1] | Out-File -FilePath $config -Append -Encoding utf8
    }
}

function get-aclTest { 
    <#
    .EXTERNALHELP xxxxx.psm1-Help.xml
#>
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 99)][Alias('csv')][string]$config
    )

    # Test for existance of $config
    if((Test-Path -path $config) -eq $false){
        Write-Verbose "Configuration File not found." -verbose
        break;    
    }

    $results = import-csv -path $config

    Return $results
}

function invoke-aclTest { 
<#
    .EXTERNALHELP xxxxx.psm1-Help.xml
#>
     [CmdletBinding()]
     param(
        [parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 1)][object]$testObject,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 9)][Alias('csv')][string]$config='.\config\matrix.csv'
     )
     begin{
        if((Test-Path -path $config) -eq $false){
            # If Not Found, Create Empty JSON
            Write-Verbose "Configuration File not found." -verbose
            break;    
        }
    }
     Process{
        $result = $null

        if($null -eq $testObject){
            Write-Verbose " - testObject not found."
            break;
        }

        switch ($testObject.method.toLower()) {
            "tcp" {  
                $result = $testObject | invoke-aclTestTCP
            }
            "ping"{
                $result = $testObject | invoke-aclTestICMP
            }
            "icmp"{
                $result = $testObject | invoke-aclTestICMP
            }
            "ssh"{
                # TODO:  Future: Build SSH method for use in Linux system
                # $result = $testObject | invoke-aclTestSSH
            }
            Default {
                Write-error "Method Provided is not supported"
                break;
            }
        }

        $result | Add-Member -name 'TestName' -MemberType NoteProperty -value $testObject.TestName -force

        # $configuration = [PesterConfiguration]::Default
        # $configuration.run.PassThru = $true
        # $configuration.output.Verbosity = 'Detailed'
        # $configuration.output.Verbosity
        # Describe "Pester Test"{
        #     it "it statement"{
        #         $result.testResult | should -be $result.expectedResult
        #     }
        # }
        
        $result
     }
     End{


        
     }
}

function invoke-aclTestTCP { 
<#
    .EXTERNALHELP xxxxx.psm1-Help.xml
#>
     [CmdletBinding()]
     param(
          [parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 1)][object]$aclTest
     )

    $scriptBlock = {
        param(
            $targetSystem,
            $targetPort,
            $timeout=1000
        )

        $tcpClient = New-Object System.Net.Sockets.TCPClient
        $connect = $tcpClient.BeginConnect($targetSystem, $targetPort ,$null,$null) 

        # Sets Timeout, else default is 20 seconds
        $wait = $connect.AsyncWaitHandle.WaitOne($timeout,$false) 

        If($wait -eq $false){
            Write-Verbose ' - Timeout'
        }
        Else {
            Write-Verbose ' - Port open!'
        }
        
        $tcpClient
    }

    Write-Verbose "Start Remote Connection"
    Write-Verbose " - Source: $($aclTest.Source)"
    Write-Verbose " - Destination: $($aclTest.Destination)"
    Write-Verbose " - Port    : $($aclTest.Port)"
    Write-Verbose " - timeout  : $($aclTest.timeout)"
    $actualResult = Invoke-Command -ComputerName $aclTest.Source -ScriptBlock $scriptBlock -ArgumentList $aclTest.Destination, $aclTest.Port, $aclTest.Timeout

    if($actualResult.Connected.toString() -eq $aclTest.expectedResult){$actualResultsText = $true}else{$actualResultsText = $false}

    $objProperty = @{
        DateAssessed = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss:ff')
        testname = $aclTest.testName
        Source = $aclTest.Source
        Destination = $aclTest.Destination
        Port = $aclTest.Port
        expectedResult = $aclTest.expectedResult
        ticketID = $aclTest.ticketID
        comments = $aclTest.comments
        method = $aclTest.method
        actualResult = $actualResult.Connected
        testResult = $actualResultsText
    }

    $diagOutput = New-Object psObject -Property $objProperty
    $diagOutput.psobject.TypeNames[0] = "aclTest.Result"
    Write-Output $diagOutput
}

function invoke-aclTestICMP { 
    <#
        .EXTERNALHELP xxxxx.psm1-Help.xml
    #>
         [CmdletBinding()]
         param(
              [parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 1)][object]$aclTest
         )
    
        $scriptBlock = {
            param(
                $targetSystem
            )
            $ping = New-Object System.Net.Networkinformation.ping
            $ping.send($targetSystem, 5)            
        }
    
        Write-Verbose "Start Remote Connection"
        Write-Verbose " - Source: $($aclTest.Source)"
        Write-Verbose " - Destination: $($aclTest.Destination)"
        $actualResult = Invoke-Command -ComputerName $aclTest.Source -ScriptBlock $scriptBlock -ArgumentList $aclTest.Destination
    
        if($actualResult.Status -eq $aclTest.expectedResult){$actualResultsText = $true}else{$actualResultsText = $false}
    
        $objProperty = @{
            DateAssessed = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss:ff')
            Source = $aclTest.Source
            Destination = $aclTest.Destination
            Port = $aclTest.Port
            expectedResult = $aclTest.expectedResult
            ticketID = $aclTest.ticketID
            comments = $aclTest.comments
            method = $aclTest.method
            actualResult = $actualResult.Status
            testResult = $actualResultsText
        }
    
        $diagOutput = New-Object psObject -Property $objProperty
        $diagOutput.psobject.TypeNames[0] = "aclTest.Result"
        Write-Output $diagOutput
}

 function new-initialACLScan{
    [CmdletBinding()]

    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 1)][string]$systemNames,
        [parameter(Mandatory = $true, ValueFromPipeline = $false, Position = 2)][Alias('csv')][string]$config,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 9)][Alias('ports')][array]$portList=@(22,80,443,445,1433,3389)
    )

    if((Test-Path -path $systemNames) -eq $false){
        Write-Error "Unable to find $systemNames";
        break
    }
    $sourceList = Get-Content -path $systemNames | Sort-Object
    $targetList = Get-Content -path $systemNames | sort-object

    ForEach($source in $sourceList){
        Write-Verbose "Source: $source"

        ForEach($target in $targetList){
            Write-Verbose " - Target: $target"

            if($source -ne $target){
                ForEach($port in $portList){
                    $expectedResult = $true
                    $method = 'TCP'
                    $testName = "$source - $target : $port"
                    new-aclTest -testName $testName -Source $source -Destination $target -Port $port -expectedResult $expectedResult -method $method -config $config
                }
            }
        }
    }


<#     1. Create a JSON with a list of common TCP Ports to be tested.  Keep list short
2. Create a CSV File with a list of servers to be tested
3. ForEach($server in CSV)
   1. ForEach($server in CSV)
      1. ForEach($port in JSON)
         1. Execute new-ACLTest
            1. TestName (firstLoop -> secondLoop:Port)
            2. Source (first loop)
            3. Destination (second loop)
            4. Port (port)
            5. expected = $true
            6. method = tcp
            7. ticket = null
            8. description = "Initial Scan" #>
}

function convert-aclTestReport{
    <#
    .EXTERNALHELP xxxxx.psm1-Help.xml
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)] $xmlFile,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 2)][ValidateSet('Source', 'Destination','Port','method')][string]$describeProperty = 'Source',
        [parameter(Mandatory = $false, ValueFromPipeline = $false, Position = 3)][ValidateSet('Source', 'Destination','Port','method')][string]$contextProperty = 'Destination'
    )

    #region PreExecution Testing
    if($xmlFile.psObject.typeNames[0] -ne 'System.IO.FileInfo'){
        Write-Verbose "Please provide a valid file object (e.g., get-item -path xxxxx)" -Verbose
        break;
    }

    if($null -eq (Test-Path $xmlFile.fullname)){
        Write-Verbose "Unable to find file: $($xmlFile.FullName)" -Verbose
        break;
    }

    if($null -eq (get-module -name Pester -ListAvailable)){
        Write-Verbose "Pester Module is required for this functionality" -verbose 
        Write-Verbose "Please install the Pester module:  Install-Module -name Pester" -verbose
    }

    if((Test-Path -path .\Tmp) -eq $false){
        new-item -name 'tmp' -ItemType Directory -path .\ | Out-Null
    }
    #endRegion

    # Load Required modules
    Import-Module -name Pester

    # Open CLIXML
    Write-Verbose "Get XML File: $($xmlFile.fullname)"
    [array] $xml = import-cliXML -path $xmlFile.fullname

    $groupDescribe = $xml | group-object -property $describeProperty
    $outputPesterFile = (join-path -path .\Tmp -ChildPath ($xmlFile).name) + '.tests.ps1'
    $outputNUnitFile = (join-path -path .\Results -ChildPath ($xmlFile).basename) + '.nUnitReport.xml'

    # Build tmp Pester Script
    Write-Verbose "Build Pester Script"
    $pesterTest = ''

    ForEach($describe in $groupDescribe){
        $pesterTest += "Describe '$($describeProperty): $($describe.name)'{`n"

        $groupContext = $describe.group | Group-Object -Property $contextProperty
        ForEach($context in $groupContext){
            $pesterTest += "`tContext '$($contextProperty): $($context.name)'{`n"

            ForEach($item in $context.group){
                $actualResult = '$' + $item.actualResult
                $expectedResult = '$' + $item.expectedResult
                $pesterTest += "`t`tIT '$($item.Source) -> $($item.Destination):$($item.Port) should be $($item.expectedResult)'{`n"
                $pesterTest += "`t`t`t $actualResult | should -be $expectedResult`n"
                $pesterTest += "`t`t}`n"
            }
            $pesterTest += "`t}`n"

        }
        $pesterTest += "}`n"

    }

    Write-Verbose "Write Temp Pester Script"
    $pesterTest | out-file -filePath $outputPesterFile -Force

    # Run tmp Pester Script & Output to Results folder
    Write-Verbose "Invoke Pester Script"

    invoke-pester -path $outputPesterFile -Output Detailed -passThru | Export-NUnitReport -path $outputNUnitFile
    
    # Remove Tmp Files
    Remove-item -path $outputPesterFile


    $diagOutputProperties = [ordered]@{
         aclTestFile = $xmlFile.fullname
         nUnitFile = (Get-item -path $outputNUnitFile).FullName
         describeProperty = $describeProperty
         contextProperty = $contextProperty
    }
    
    $diagOutput = New-Object psObject -Property $diagOutputProperties
    Write-Output $diagOutput

}