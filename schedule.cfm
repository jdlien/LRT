<cfset PageTitle = "EZLRTDepartureTimes" />
<cfinclude template="/Includes/IntraHeader.cfm">
<cfinclude template="/Includes/functions/weekdayToNum.cfm">

<cfset maxDepartureMins = 70 />

<cfoutput>
<h1>#Minute("04:30")#</h1>

<h2>Testing WeekdayToNum</h2>
Day: #WeekdayToNum("W")#
<br><br>
We need to start with a date - not just a time.

For instance, today is #now()#

Let's say we want all the trains for 15 hours. In 15 hours, time will be
#DateAdd('h', 15, now())#

For giggles, imagine we want to specify a day of week. We need to be able to wrap around to the previous day

<br />Current Weekday Number:
<cfset DOW = DayOfWeek(now())>
#DOW#

<cfset DOW = "Sun"> We specified Saturday (7)
So what is the date of the next saturday?



<br />Difference between specified and current:
#weekdayToNum(DOW) - DayOfWeek(now())#

<br />Difference between specified and a Saturday:
<!--- If it's Monday, and we've specified Sunday, we'll get -1. Add 7 to get 6 days ahead --->
<cfset dayDiff = weekdayToNum(DOW) - DayOfWeek(now())>
<cfif dayDiff LT 0><cfset dayDiff+=7></cfif> 
<!--- Our start datetime for purposes of the query will then be --->
<cfset CurrentTime = DateAdd('d', dayDiff, now()) >
#CurrentTime#


<!--- If I've specified a time on the clock, I can probably override CurrentTime with that
Note that this POS is for testing only. I need to handle this quite differently in production
 --->
<cfset CurrentTime=CreateDateTime(2017, 7, 22, 00, 00, 0) />


<cfset CurDOW = DayOfWeek(CurrentTime) />
<cfset NextDOW = Left(DayOfWeekAsString((CurDOW+1) MOD 7),3) />
<cfset PrevDOW = CurDOW-1 />
<cfif PrevDOW LTE 0><cfset PrevDOW = PrevDOW+7></cfif>
<cfset PrevDOW = Left(DayOfWeekAsString(PrevDOW),3)>
<cfset CurDOW = Left(DayOfWeekAsString(CurDow),3)>
<br><br>
CurDOW = #CurDow#<br>
NextDOW = #NextDow#<br>
PrevDOW = #PrevDow#<br>



<br><br>
The end of the range we are interested in will be
<cfset MaxFutureTime = DateAdd('n', maxDepartureMins, CurrentTime)>
#MaxFutureTime#


<!--- For our demonstration, let's set a route from CP to CV --->
<cfset url.from=14>
<cfset url.to=15>

<!--- This gets all the requisite intermediate variables --->
<!--- Information about relevant stations --->
<cfquery name="fromStation" dbtype="ODBC" datasource="SecureSource">
	SELECT * FROM vsd.EZLRTStations WHERE StationID=#url.from#
</cfquery>

<cfquery name="toStation" dbtype="ODBC" datasource="SecureSource">
	SELECT * FROM vsd.EZLRTStations WHERE StationID=#url.to#
</cfquery>


<cfquery name="validLines" dbtype="ODBC" datasource="SecureSource">
	SELECT sl.LineID, LineCode, LineName, AdditionalInfo FROM vsd.EZLRTStationsLines sl
	JOIN vsd.EZLRTLines l ON sl.LineID=l.LineID
	WHERE StationID IN (#url.from#,#url.to#)
	GROUP BY sl.LineID, LineCode, LineName, AdditionalInfo
	HAVING COUNT(*)=2
</cfquery>

<!--- If there are no valid lines, I need to find the closest station that has one, then create a two routes
where that station is the end of the first trip and the start of the second --->
<cfif validLines.RecordCount IS 0>
	<!--- Query for a station that has a line present at both the source and destination station --->
	<cfquery name="ConnectingStation" dbtype="ODBC" datasource="SecureSource">
		SELECT TOP 1 sl.StationID, StationCode, StationName, Coordinates, CostFromOrigin, ABS(CostFromOrigin-1035) AS RelativeCost, Type, AdditionalInfo FROM vsd.EZLRTStationsLines sl
		JOIN vsd.EZLRTStations s ON s.StationID=sl.StationID
		WHERE LineID IN
		(SELECT LineID FROM vsd.EZLRTStationsLines WHERE StationID=15
			UNION
		 SELECT LineID FROM vsd.EZLRTStationsLines WHERE StationID=18)
		GROUP BY sl.StationID, StationCode, StationName, Coordinates, CostFromOrigin, Type, AdditionalInfo
			HAVING COUNT(*)=2
		ORDER BY RelativeCost
	</cfquery>	

	<!--- If there's a connecting station, we now have to do TWO routes. Have fun. --->
	<cfif ConnectingStation.RecordCount>

		<cfset url.from2 = ConnectingStation.StationID />
		<cfset fromStation2 = ConnectingStation />
		<cfset url.to2 = url.to />
		<cfset toStation2 = toStation />
		<cfset url.to = ConnectingStation.StationID />
		<cfset toStation = ConnectingStation />
		<!--- And url.from stays the same, obviously --->

	<!--- Check valid lines for our new stations --->
	<cfquery name="validLines" dbtype="ODBC" datasource="SecureSource">
		SELECT sl.LineID, LineCode, LineName, AdditionalInfo FROM vsd.EZLRTStationsLines sl
		JOIN vsd.EZLRTLines l ON sl.LineID=l.LineID
		WHERE StationID IN (#url.from#,#url.to#)
		GROUP BY sl.LineID, LineCode, LineName, AdditionalInfo
		HAVING COUNT(*)=2
	</cfquery>


	<cfelse>
		<p class="error">You have chosen two stations with no connection between them.</p>
		<cfset skipCalc = true />
	</cfif>

</cfif><!---validLines.RecordCount IS 0--->

<cfset cost = fromStation.CostFromOrigin />


<cfset relTravelTime = toStation.CostFromOrigin-cost />

	<cfquery name="TripTrack" dbtype="ODBC" datasource="SecureSource">
		SELECT * FROM vsd.EZLRTTracks WHERE LineID IN (#ValueList(validLines.LineID)#) AND CostDirection='#abs(relTravelTime)/relTravelTime#'
	</cfquery>


	<cfquery name="OriginStations" dbtype="ODBC" datasource="SecureSource">
		--This gets us our list of origin stations, even if there are two lines
		SELECT * FROM vsd.EZLRTStations s
		WHERE CostFromOrigin <cfif relTravelTime GT 0><=<cfelse>>=</cfif> #cost#
		AND s.StationID IN
		(SELECT StationID FROM vsd.EZLRTStationsLines WHERE StationID=s.StationID AND LineID IN (#ValueList(validLines.LineID)#))

	</cfquery>





<!--- I'm going to refactor this query to use DateTimes.
If the end datetime is on the same day, then we just limit to times before that on the same day
Otherwise we have to look for times before that on the next day... right?
 --->

<cfquery name="TestTime" dbtype="ODBC" datasource="SecureSource">

SELECT CAST(DATEADD(minute, ABS(1004-s.CostFromOrigin), DepartureTime) AS TIME) AS DepartureFromCurrentStation, CASE 
WHEN DepartureTime > DATEADD(minute, ABS(1004-s.CostFromOrigin), DepartureTime) THEN 
DATEADD(minute, ABS(1004-s.CostFromOrigin), CAST('2017-07-30 '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME)) WHEN DATEPART(hh, DepartureTime)+22 < DATEPART(hh, {ts '2017-07-31 23:56:00'}) THEN 
DATEADD(minute, ABS(1004-s.CostFromOrigin), CAST('2017-08-01 '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME))	ELSE --TODAY
DATEADD(minute, ABS(1004-s.CostFromOrigin), CAST('2017-07-31 '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME)) END	AS DepartureFromCurrentStationDT, TID, TrackID, t.StationID, DestStationID, Mon, Tue, Wed, Thu, Fri, Sat, Sun, DepartureTime, t.AdditionalInfo, s.StationCode, s.StationName, s.CostFromOrigin, ds.StationID AS DestStationID, ds.StationCode AS DestStationCode, ds.StationName as DestStationName FROM vsd.EZLRTDepartureTimes t JOIN vsd.EZLRTStations s ON t.StationID=s.StationID JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID WHERE t.TrackID IN (1) AND t.StationID IN (1,2)

AND (
	(Sun = CASE WHEN DepartureTime > DATEADD(minute, ABS(1004-s.CostFromOrigin), DepartureTime) THEN 1 END
	-- This clause only matters if it's very late or early in the morning (before 4)
	AND (DATEPART(hh, {ts '2017-07-31 23:56:00'}) <= 3) AND DepartureTime >= '22:57' )
-- If departure time is less than 22 hours before current time, we assume it's the next day since we don't ever count backwards -- Nothing I do to this clause seems to want to show trains that left after 1 AM if we're looking at the previous day
	OR (
	Tue = CASE WHEN DATEPART(hh, DepartureTime)+22 <= DATEPART(hh, {ts '2017-07-31 23:56:00'}) THEN 1 END
	AND DepartureTime < '04:57'
	)
	-- Normal case - the date of departure is greater than or equal to currenttime.
	OR (Mon = 1 AND DATEADD(minute, ABS(1004-s.CostFromOrigin), DepartureTime) >= {ts '2017-07-31 23:56:00'} ) )
	ORDER BY DepartureFromCurrentStationDT


</cfquery>

<cfdump var="#TestTime#" />
<h1>#DateFormat(CurrentTime, "ddd, yyyy-mmm-dd")# #TimeFormat(CurrentTime, "HH:mm")#</h1>
	<p style="margin-bottom:4px;">Trains from <cfoutput>#fromStation.StationName# <span class="nowrap">to #toStation.StationName#</span></cfoutput>:</p>



<!--- Query that should show the relevant schedule times. --->
<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">

	SELECT
	CAST(DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) AS TIME)
		AS DepartureFromCurrentStation,
	CASE -- This glorious CASE will create a proper date out of the schedule times
	WHEN DepartureTime > DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) THEN --Yesterday
			DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST('#DateFormat(DateAdd("d", -1, CurrentTime), "YYYY-MM-DD")# '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME))
	WHEN DATEPART(hh, DepartureTime)+22 < DATEPART(hh, #CurrentTime#) THEN --Tomorrow
		DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST('#DateFormat(DateAdd("d", 1, CurrentTime), "YYYY-MM-DD")# '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME))	
	ELSE --TODAY
		DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST('#DateFormat(CurrentTime, "YYYY-MM-DD")# '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME))
	END	AS DepartureFromCurrentStationDT,
	TID, TrackID, t.StationID, DestStationID, Mon, Tue, Wed, Thu, Fri, Sat, Sun, DepartureTime, t.AdditionalInfo,
	s.StationCode, s.StationName, s.CostFromOrigin,
	ds.StationID AS DestStationID, ds.StationCode AS DestStationCode, ds.StationName as DestStationName
	FROM vsd.EZLRTDepartureTimes t
	JOIN vsd.EZLRTStations s ON t.StationID=s.StationID
	JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID
	WHERE t.TrackID IN (#ValueList(TripTrack.TrackID)#)
	<!--- Show only relevant days of the week --->
	AND (
	(#PrevDOW# = CASE WHEN DepartureTime > DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) THEN 1 END
		-- This clause only matters if it's very late or early in the morning (before 4)
		AND (DATEPART(hh, #CurrentTime#) <= 5)
		AND DepartureTime >= '22:57'
	)
	-- If departure time is less than 22 hours before current time, we assume it's the next day since we don't ever count backwards
	OR (#NextDOW# = CASE WHEN DATEPART(hh, DepartureTime)+22 < DATEPART(hh, #CurrentTime#) THEN 1 END
		AND DepartureTime < '4:57'
	)
	-- Normal case - the date of departure is greater than or equal to currenttime.
	OR  (#CurDow# = 1
		AND DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) >= #CurrentTime#
		<!--- Only use this if the FutureTime didn't wrap to the next day. Otherwise show to end of day --->
		<cfif Hour(MaxFutureTime) GTE Hour(CurrentTime)>
			AND DepartureTime <= #MaxFutureTime#
		</cfif>
	)
)
ORDER BY DepartureFromCurrentStationDT

</cfquery>

<!--- I'm condeming this shitshow of a query
	<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
		SELECT
		CAST(DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) AS TIME)
		AS DepartureFromCurrentStation,
		<!--- These times will be around 1900-01-01. Maybe it's better if I use today?
			This will be based on #CurrentTime#

			Those departurefromcurrentstationdt times must be *after* the currenttime,
			so therefore the date will be the same, even if the train first departed yesterday,
			it will definitely be today by the time it gets to the from station.

			So how to do this? Tack on the CurrentTime date in the cast(departureTime)?
		 --->

		DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST('#DateFormat(CurrentTime, "YYYY-MM-DD")# '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME))
		AS DepartureFromCurrentStationDT,
		TID, TrackID, t.StationID, DestStationID, Mon, Tue, Wed, Thu, Fri, Sat, Sun, DepartureTime, t.AdditionalInfo,
		s.StationCode, s.StationName, s.CostFromOrigin,
		ds.StationID AS DestStationID, ds.StationCode AS DestStationCode, ds.StationName as DestStationName
		FROM vsd.EZLRTDepartureTimes t
		JOIN vsd.EZLRTStations s ON t.StationID=s.StationID
		JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID
		WHERE  t.TrackID IN (#ValueList(TripTrack.TrackID)#)
		AND t.StationID IN (#ValueList(OriginStations.StationID)#)
		AND (( -- This crazy bit allows us to pull the day of week based on the current time wholly in SQL
			  -- This can allow us to do dateadds on that date, if necessary.
			CAST(LEFT(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #CurrentTime#),11)+' '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME) >= DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #CurrentTime#)
			AND(
				<!--- Oh boy, I really wish I could reference this as DepartureFromCurrentStationDT --->
				#PrevDOW# = CASE WHEN DATEPART(hh, DepartureTime) > DATEPART(hh, DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST('#DateFormat(CurrentTime, "YYYY-MM-DD")# '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME))) THEN 1 END
				-- If departure time is less than 21 hours before current time, we assume it's the next day since we don't even count backwards
				--OR #NextDOW# = CASE WHEN DATEPART(hh, DepartureTime)+21 < DATEPART(hh, #CurrentTime#) THEN 1 END
				-- Normal case - the date of departure is greater than or equal to currenttime. This is not the case for the first
				--OR  #CurDow# = CASE WHEN DATEPART(hh, DepartureTime)+21 >= DATEPART(hh, #CurrentTime#) THEN 1 END
			)
		)
		-- This will be AND or OR depending on whether we cross over midnight. I'll need CF to handle that.
		-- In this example case, we have to cross over midnight, so we'll need an OR
		-- OR ( -- This crazy bit allows us to pull the day of week based on the current time wholly in SQL
		-- 	  -- This can allow us to do dateadds on that date, if necessary.
		-- 	CAST(LEFT(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#),11)+' '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME) <= DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)
		-- 	AND(Mon = CASE WHEN LEFT(DATENAME(dw, DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)),3) = 'Mon' THEN 1 END
		-- 	OR  Tue = CASE WHEN LEFT(DATENAME(dw, DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)),3) = 'Tue' THEN 1 END
		-- 	OR  Wed = CASE WHEN LEFT(DATENAME(dw, DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)),3) = 'Wed' THEN 1 END
		-- 	OR  Thu = CASE WHEN LEFT(DATENAME(dw, DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)),3) = 'Thu' THEN 1 END
		-- 	OR  Fri = CASE WHEN LEFT(DATENAME(dw, DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)),3) = 'Fri' THEN 1 END
		-- 	OR  Sat = CASE WHEN LEFT(DATENAME(dw, DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)),3) = 'Sat' THEN 1 END
		-- 	OR  Sun = CASE WHEN LEFT(DATENAME(dw, DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#)),3) = 'Sun' THEN 1 END)
		-- )
		)
		<!--- We have to find departure times in the past the number of minutes it takes to get from origin --->
		--AND DepartureTime >= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #CurrentTime#) AS TIME)
		--AND DepartureTime >= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #CurrentTime#) AS TIME)
		<!--- we also need departuretimes that come before the end time.. --->

		<!--- Skip this AND if it's After 11. If DateCompare is LT 1, it's before 11 PM 
		<cfif DateCompare(CurrentTime, '22:50') LT 0>
			AND DepartureTime <= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), '#MaxFutureTime#') AS TIME)
		</cfif>
		--->
		ORDER BY DepartureFromCurrentStationDT
	</cfquery>
		--->
<!--- <cfdump var="#DepartureTimes#" /> --->
<table class="altColors padded">
	<tr class="heading">
<!--- 		<th style="text-align:left;">Line</th> --->
		<th>Track</th>
		<th>Time</th>
		<th>Destination</th>
		<th>Weekdays</th>
		<th>DepartureFromCurrentStation</th>
	</tr>
<cfloop query="DepartureTimes">
	<tr>
<!--- 		<td>#LineID# #LineName#</td> --->
		<td style="text-align:center;">#TrackID#</td>
		<td>#TimeFormat(DepartureTime, "HH:mm")#
		<td>#UCase(DestStationCode)#</td>
		<td>
			<cfif Mon>M<cfelse>_</cfif>
			<cfif Tue>T<cfelse>_</cfif>
			<cfif Wed>W<cfelse>_</cfif>
			<cfif Thu>T<cfelse>_</cfif>
			<cfif Fri>F<cfelse>_</cfif>
			<cfif Sat>Sa<cfelse>_</cfif>
			<cfif Sun>Su<cfelse>_</cfif>
		</td>
		<td>#DateFormat(DepartureFromCurrentStationDT, "YYYY-Mmm-DD")# #TimeFormat(DepartureFromCurrentStationDT, "HH:mm")#</td>
	</tr>
</cfloop>

</table>

<!--- So even if we specify a day of week, we have a specific datetime we are starting with.
Having that should allow for much easier date/time calculations.

It should be trivial to figure out the datetime for the end, where we just advance it by 65 minutes or so.

Now what would a query using this look like?
--->



</p>
</cfoutput>


<!--- 
<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
	SELECT ds.StationCode AS DestStationCode, *
	FROM vsd.EZLRTDepartureTimes t
	JOIN vsd.EZLRTStations s ON t.StationID=s.StationID
	JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID
	JOIN vsd.EZLRTTracks tr ON t.TrackID=tr.TrackID
	JOIN vsd.EZLRTLines l ON l.LineID=tr.LineID
</cfquery>

<!--- Simple list of the departure times as per the schedule --->
<table class="altColors padded">
	<tr class="heading">
		<th style="text-align:left;">Line</th>
		<th>Track</th>
		<th>Time</th>
		<th>Destination</th>
		<th>Weekdays</th>
	</tr>
<cfoutput query="DepartureTimes">
	<tr>
		<td>#LineID# #LineName#</td>
		<td style="text-align:center;">#TrackID#</td>
		<td>#TimeFormat(DepartureTime, "HH:mm")#
		<td>#UCase(DestStationCode)#</td>
		<td>
			<cfif Mon>M<cfelse>_</cfif>
			<cfif Tue>T<cfelse>_</cfif>
			<cfif Wed>W<cfelse>_</cfif>
			<cfif Thu>T<cfelse>_</cfif>
			<cfif Fri>F<cfelse>_</cfif>
			<cfif Sat>Sa<cfelse>_</cfif>
			<cfif Sun>Su<cfelse>_</cfif>
		</td>
	</tr>
</cfoutput>
</table>
 --->






<cfinclude template="/Includes/IntraFooter.cfm">