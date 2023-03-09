USE Geocoding
WHILE EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_CATALOG = 'Geocoding' AND TABLE_NAME = 'Addresses_toGeocode')
BEGIN
	WAITFOR DELAY '00:00:01'
END
GO
SELECT TOP(10000) 
	AddressID
	,Address
	,City
	,State
	,Zip
INTO Geocoding..Addresses_toGeocode
FROM Geocoding..Addresses
WHERE Lat IS NULL -- We don't have Latitude yet, so this address still needs processed
AND is_BeingProcessed IS NULL -- Don't pull records unless they aren't currently being processed

UPDATE Geocoding..Addresses
SET is_BeingProcessed = 1
WHERE AddressID IN (SELECT AddressID FROM Geocoding..Addresses_toGeocode)