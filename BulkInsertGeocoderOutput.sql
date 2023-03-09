--REPLACERS
--	##MATCHPATH##
--	##NOMATCHPATH##

USE Geocoding

BULK INSERT Geocoding.dbo.Addresses_fromGeocoder_Matched
FROM '##MATCHPATH##'
WITH (
	DATAFILETYPE = 'char',
	FIELDTERMINATOR = '","',
	ROWTERMINATOR = '0x0A'
)

BULK INSERT Geocoding.dbo.Addresses_fromGeocoder_NotMatched
FROM '##NOMATCHPATH##'
WITH (
	DATAFILETYPE = 'char',
	FIELDTERMINATOR = '","',
	ROWTERMINATOR = '0x0A'
)