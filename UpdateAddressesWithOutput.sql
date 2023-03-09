USE Geocoding
UPDATE Geocoding.dbo.Addresses_fromGeocoder_Matched
SET AddressID = REPLACE(AddressID,'"','')
	, TigerLineSide = REPLACE(REPLACE(TigerLineSide,'"',''),CHAR(13),'')
UPDATE Geocoding.dbo.Addresses_fromGeocoder_NotMatched
SET AddressID = REPLACE(AddressID,'"','')
	, TigerAddressRangeMatchIndicator = REPLACE(REPLACE(TigerAddressRangeMatchIndicator,'"',''),CHAR(13),'')

UPDATE Geocoding.dbo.Addresses
SET
	Lat = RIGHT(interpolatedlonglat, len(interpolatedlonglat)-charindex(',',interpolatedlonglat)),
	Long = LEFT(interpolatedlonglat,charindex(',',interpolatedlonglat)-1),
	TigerAddressRangeMatchIndicator = m.TigerAddressRangeMatchIndicator,
	TigerMatchType = m.TigerMatchType,
	OutputAddress = m.OutputAddress,
	TigerLineID = m.TigerLineID,
	TigerLineSide = m.TigerLineSide,
	is_BeingProcessed = 0
FROM Geocoding.dbo.Addresses_fromGeocoder_Matched m
JOIN Geocoding.dbo.Addresses a
ON m.AddressID = a.AddressID

UPDATE Geocoding.dbo.Addresses
SET
	Lat = 999, -- 999 meaning "processed, but no match found"
	Long = 999,
	TigerAddressRangeMatchIndicator = nm.TigerAddressRangeMatchIndicator,
	TigerMatchType = 'NO MATCH',
	OutputAddress = 'NO MATCH',
	TigerLineID = '0',
	TigerLineSide = '0',
	is_BeingProcessed = 0
FROM Geocoding.dbo.Addresses_fromGeocoder_NotMatched nm
JOIN Geocoding.dbo.Addresses a
ON nm.AddressID = a.AddressID

DELETE FROM Geocoding.dbo.Addresses_fromGeocoder_Matched
WHERE AddressID IN (
	SELECT AddressID FROM Addresses
	WHERE is_BeingProcessed = 0
)

DELETE FROM Geocoding.dbo.Addresses_fromGeocoder_NotMatched
WHERE AddressID IN (
	SELECT AddressID FROM Addresses
	WHERE is_BeingProcessed = 0
)