Insert into Geocoding..GeocodingReporting(TimeStarted, PreviousLoopStart)
Values (GETDATE(), (SELECT MAX(TimeStarted) FROM Geocoding..GeocodingReporting))

Insert into Geocoding..Addresses (Address, City, State, Zip)
select top(10000)
	Address
	,City
	,StateAbbreviation
	,ZIPCode 
from Geocoding..IndividualNCOA ncoa
where not exists (
	select * from Geocoding..Addresses a
	where a.zip = ncoa.ZIPCode
	and a.Address = ncoa.Address
)