function Write-WithDate ($string) {
    Write-Host "$(Get-Date -Format "MMMdd yyyy HH:mm") $string" -ForegroundColor Yellow
}

While (1 -eq 1) {
    Write-WithDate "Pulling from NCOA to Addresses"
    Invoke-Sqlcmd -InputFile .\NcoaToAddresses.sql    #Pull addresses from IndividualNCOA table to Addresses table

    do {
        $Addresses_toGeocode_exists = (Invoke-Sqlcmd -InputFile .\Check_AddressesToGeocodeExists.sql).result
        Write-WithDate "Addresses_toGeocode check: $Addresses_toGeocode_exists"
    } while ($Addresses_toGeocode_exists -eq 1)
    
    Write-WithDate "Selecting into Addresses_toGeocode"
    Invoke-Sqlcmd -InputFile .\SelectUnprocessed.sql  #Select unprocessed addresses into Addresses_toGeocode table

    $fileNumber = 1
    while ($null -ne (Get-Item ".\GeocodingData\*$fileNumber*")) {
        $fileNumber ++
    }
    $toGeocodeName = "ToGeocode_$($fileNumber)"
    $fromGeocodeName = "GeocoderOutput_$($fileNumber)"
    Write-WithDate "bcp out to $toGeocodeName"
    bcp Geocoding.dbo.Addresses_toGeocode out ".\GeocodingData\$($toGeocodeName).csv" -T -c -t','

    Invoke-Sqlcmd -Query "DROP TABLE IF EXISTS Geocoding..Addresses_toGeocode" #dropped after bcp out to avoid race conditions with parallel SELECT INTO statements

    $continue = $false
    do {
        $firstLine = Get-Content ".\GeocodingData\$($toGeocodeName).csv" -Head 1
        Write-WithDate "Attempting to geocode file with first address of $firstLine"
        $startTime = Get-Date -UFormat '%R'
        cmd.exe /c "curl --form addressFile=@.\GeocodingData\$($toGeocodeName).csv --form benchmark=Public_AR_Current  https://geocoding.geo.census.gov/geocoder/locations/addressbatch --output .\GeocodingData\$($fromGeocodeName).csv"
        $endTime = Get-Date -UFormat '%R'
        if (((Get-Item ".\GeocodingData\$($fromGeocodeName).csv").Length -gt 0) -and ((Get-Content ".\GeocodingData\$($fromGeocodeName).csv" -head 1).Substring(0,3) -ne '<p>')) {
            #There are two known errors:
            #One in which the geocoder returns a blank file
            #And another in which the geocoder returns a result that starts with <p> and says something to the effect of "We're too busy to handle your request"
            Write-WithDate "No errors found; continuing script"
            $continue = $true
            Remove-Item ".\GeocodingData\$($toGeocodeName).csv"
        }
        else {
            Write-WithDate "Error has occurred; attempting Geocoder request again"
            if (((New-TimeSpan -Start $startTime -End $endTime).Minutes -lt 2) -and ($continue -eq $false)){
                Write-WithDate "Rate limiting; pausing for 60 seconds."
                Start-Sleep 60
            }
        }
    } while ($continue -eq $false)

    $noMatchPath = ".\GeocodingData\$($fromGeocodeName)_noMatches.csv"
    $matchPath = ".\GeocodingData\$($fromGeocodeName)_matches.csv"
    $matchReplacer = '##MATCHPATH##'
    $noMatchReplacer = '##NOMATCHPATH##'

    Write-WithDate "Separating output into Matches and NoMatches files"
    $noMatchRows = (Get-Content ".\GeocodingData\$($fromGeocodeName).csv" | Select-String -Pattern '"[LR]"$' -notmatch) #this includes No_Match and Tie
    Set-Content $noMatchPath -value $noMatchRows
    $matchRows = (Get-Content ".\GeocodingData\$($fromGeocodeName).csv" | Select-String -Pattern '"[LR]"$') #the final column of the matched data is either an L or R
    Set-Content $matchPath -value $matchRows

    Write-WithDate "Inserting $($fromGeocodeName).csv into SQL server"
    $insertQuery = (Get-Content ".\BulkInsertGeocoderOutput.sql").Replace($matchReplacer, $matchPath).Replace($noMatchReplacer, $noMatchPath)
    $insertPath = ".\OutputInsert_$($fileNumber).sql"
    Set-Content $insertPath -value $insertQuery
    Invoke-Sqlcmd -InputFile $insertPath  #Insert output into SQL server

    Write-WithDate "Removing $($fromGeocodeName).csv"
    Remove-Item ".\GeocodingData\$($fromGeocodeName).csv"
    Write-WithDate "Removing $insertPath"
    Remove-Item $insertPath
    Write-WithDate "Removing $noMatchPath"
    Remove-Item $noMatchPath
    Write-WithDate "Removing $matchPath"
    Remove-Item $matchPath

    Write-WithDate "Updating addresses with output information"
    Invoke-Sqlcmd -InputFile .\UpdateAddressesWithOutput.sql #Update addresses with output information
}