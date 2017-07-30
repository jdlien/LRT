<cffunction name="WeekdayToNum">
	<cfargument name="DayName" required="true" type="String">

	<cfswitch expression="#Left(DayName, 3)#">
		<cfcase value="Sun"><cfreturn 1></cfcase>
		<cfcase value="Mon"><cfreturn 2></cfcase>
		<cfcase value="Tue"><cfreturn 3></cfcase>
		<cfcase value="Wed"><cfreturn 4></cfcase>
		<cfcase value="Thu"><cfreturn 5></cfcase>
		<cfcase value="Fri"><cfreturn 6></cfcase>
		<cfcase value="Sat"><cfreturn 7></cfcase>
	</cfswitch>
</cffunction>
<!--- Loaded via ajax or include to show departureTimes table --->
<!--- <cfsetting showdebugoutput="false" /> --->

<cfset maxDepartureMins = 70 />

<cfif isDefined('url.from') AND isDefined('url.to')>

<cfif url.from IS url.to>
	<p class="error">You have selected the same station for your source and destination.<br />Please select a different station.</p>
	<cfset skipCalc = true />
</cfif>

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

</cfif>

<cfset cost = fromStation.CostFromOrigin />




<cfif NOT isDefined('skipCalc')>

<!--- Step 1. Figure out the direction we need to go and the difference between our stations and the root --->
<cfset relTravelTime = toStation.CostFromOrigin-cost />

<cfif relTravelTime IS 0>
	<p class="error">There isn't much point in selecting the same station for your departure and arrival, is there?</p>
<cfelse>

	<cfquery name="TripTrack" dbtype="ODBC" datasource="SecureSource">
		SELECT * FROM vsd.EZLRTTracks WHERE LineID IN (#ValueList(validLines.LineID)#) AND CostDirection='#abs(relTravelTime)/relTravelTime#'
	</cfquery>


	<!--- Sunday is 1, Saturday is 7 --->
	<cfif isDefined('url.dow') AND len(url.dow) GTE 3>
		<cfset DOW = Left(url.dow, 3)>
	<cfelseif isDefined('url.time') and len(url.time) GTE 3>
		<!--- Create date object using current date --->
		<cfset specifiedDateTime = CreateDateTime(Year(Now()), Month(Now()), Day(Now()), TimeFormat(url.time, "HH"), TimeFormat(url.time, "mm"), 0 ) >
		<cfset DOW = Left(DayOfWeekAsString(DayOfWeek(DateAdd("n", -3, specifiedDateTime))),3)>
	<cfelse>
		<cfset DOW = Left(DayOfWeekAsString(DayOfWeek(DateAdd("n", -3, Now()))),3)>
	</cfif>

	<!--- I'm going to subtract two minutes to account for trains being a little late --->
	<cfif isDefined('url.time') and len(url.time) GTE 3>
		<!--- Reduce selected time by three minutes (gets around midnight bug) --->
		<cfset CurrentTime=TimeFormat(DateAdd("n", -3, url.time), "HH:mm")>

	<cfelse>
		<cfset CurrentTime = TimeFormat(DateAdd("n", -3, Now()), "HH:mm")>
	</cfif>
	<cfset MaxFutureTime = TimeFormat(DateAdd("n", maxDepartureMins, CurrentTime), "HH:mm") >

	<cfset  NextDOW = Left(DayOfWeekAsString(DayOfWeek(WeekdayToNum(DOW)+1 MOD 7)),3)>

	<!--- Determine the origin station. What station is also on this line with the smallest cost --->
	<!--- If we are going in an increasing direction, we want to find stations with a smaller cost on this line --->
	<!--- Else we find the station with the highest cost --->
	<cfquery name="OriginStations" dbtype="ODBC" datasource="SecureSource">
		--This gets us our list of origin stations, even if there are two lines
		SELECT * FROM vsd.EZLRTStations s
		WHERE CostFromOrigin <cfif relTravelTime GT 0><=<cfelse>>=</cfif> #cost#
		AND s.StationID IN
		(SELECT StationID FROM vsd.EZLRTStationsLines WHERE StationID=s.StationID AND LineID IN (#ValueList(validLines.LineID)#))

	</cfquery>
	<!--- <cfdump var="#OriginStations#"> --->

	<!--- Now we have a list of originStations, so we can query for all the DepartureTimes from those trains --->
	<!--- We query for departures for the track we will use, which originate at one of our origin stations
			at a time after now() minus the difference in minutes between the origin station and the departure station
	--->

	<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
		SELECT
		CAST(DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) AS TIME)
		AS DepartureFromCurrentStation,
		DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST(DepartureTime AS DATETIME))
		AS DepartureFromCurrentStationDT,
		TID, TrackID, t.StationID, DestStationID, Mon, Tue, Wed, Thu, Fri, Sat, Sun, DepartureTime, t.AdditionalInfo,
		s.StationCode, s.StationName, s.CostFromOrigin,
		ds.StationID AS DestStationID, ds.StationCode AS DestStationCode, ds.StationName as DestStationName
		FROM vsd.EZLRTDepartureTimes t
		JOIN vsd.EZLRTStations s ON t.StationID=s.StationID
		JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID
		WHERE  t.TrackID IN (#ValueList(TripTrack.TrackID)#)
		AND t.StationID IN (#ValueList(OriginStations.StationID)#)
		AND #DOW#=1
		AND DepartureTime >= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), '#CurrentTime#') AS TIME)
		<!--- Skip this AND if it's After 11. If DateCompare is LT 1, it's before 11 PM --->
		<cfif DateCompare(CurrentTime, '22:50') LT 0>
			AND DepartureTime <= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), '#MaxFutureTime#') AS TIME)
		</cfif>
		ORDER BY DepartureFromCurrentStationDT
	</cfquery>

	<!--- This whole thing is a pretty awful hack to get times after midnight --->
	<cfquery name="DepartureTimesLate" dbtype="ODBC" datasource="SecureSource">
		SELECT
		CAST(DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) AS TIME)
		AS DepartureFromCurrentStation,
		DATEADD(minute, ABS(#Cost#-s.CostFromOrigin)+1440, CAST(DepartureTime AS DATETIME))
		AS DepartureFromCurrentStationDT,
		TID, TrackID, t.StationID, DestStationID, Mon, Tue, Wed, Thu, Fri, Sat, Sun, DepartureTime, t.AdditionalInfo,
		s.StationCode, s.StationName, s.CostFromOrigin,
		ds.StationID AS DestStationID, ds.StationCode AS DestStationCode, ds.StationName as DestStationName			
		FROM vsd.EZLRTDepartureTimes t
		JOIN vsd.EZLRTStations s ON t.StationID=s.StationID
		JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID
		WHERE  t.TrackID IN (#ValueList(TripTrack.TrackID)#)
		AND t.StationID IN (#ValueList(OriginStations.StationID)#)
		AND (
			( DepartureTime >= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), '#CurrentTime#') AS TIME)
				AND #DOW#=1 AND DepartureTime <= '11:59:59')
		OR 
			( DepartureTime <= '4:30' AND #NextDOW#=1 )
		)
		ORDER BY DepartureFromCurrentStationDT
	</cfquery>


	<!--- <cfdump var="#DepartureTimes#"> --->
	<cfif isDefined('url.from2') AND isDefined('url.to2')>
	<h2>Leg 1 of 2</h2>
	</cfif>
	<p style="margin-bottom:4px;">Trains from <cfoutput>#fromStation.StationName# <span class="nowrap">to #toStation.StationName#</span></cfoutput>:</p>
	<table class="altColors">
	<cfoutput query="DepartureTimes">
		<tr>
			<td class="trainName">#UCase(DestStationCode)#</td>
			<td class="arrivalTime" data-datetime="#DepartureFromCurrentStationDT#">#TimeFormat(DepartureFromCurrentStation, "h:mm tt")#</td>
			<td class="countdown"></td>
		</tr>
	</cfoutput>
	<!--- If It's after 11 PM, show the departure times after midnight. I'm not sure if this works. --->
	<cfif DateCompare(CurrentTime, '22:57') GTE 0>
	<!--- <cfif DepartureTimesLate.RecordCount><tr><td colspan="3"><b>Midnight</b></td></tr></cfif> --->
	<cfoutput query="DepartureTimesLate">
		<tr>
			<td class="trainName">#UCase(DestStationCode)#</td>
			<td class="arrivalTime" data-datetime="#DepartureFromCurrentStationDT#">#TimeFormat(DepartureFromCurrentStation, "h:mm tt")#</td>
			<td class="countdown"></td>
		</tr>
	</cfoutput>
	</cfif>

	</table>

	<p>Travel time will be about <b><cfoutput>#abs(relTravelTime)# minutes</cfoutput></b>.</p>
</cfif><!--relTravelTime IS 0/else -->




<!--- If there's a second leg of the trip, we can go through that now --->
<cfif isDefined('url.from2') AND isDefined('url.to2')>
<h2>Leg 2 of 2</h2>





<!--- Hold on man, this is gonna be some butt-ugly coding... I should redo the above as a function and run it twice --->

	<!--- Add the previous leg's travel time minus a two minute fudge-factor --->
	<cfset CurrentTime = TimeFormat(DateAdd("n", abs(relTravelTime)-2, DepartureTimes.DepartureTime), "HH:mm") >
	<cfset MaxFutureTime = TimeFormat(DateAdd("n", MaxDepartureMins, CurrentTime), "HH:mm") >

	<cfset cost = fromStation2.CostFromOrigin />

	<!--- Check valid lines for our new stations --->
	<cfquery name="validLines" dbtype="ODBC" datasource="SecureSource">
		SELECT sl.LineID, LineCode, LineName, AdditionalInfo FROM vsd.EZLRTStationsLines sl
		JOIN vsd.EZLRTLines l ON sl.LineID=l.LineID
		WHERE StationID IN (#url.from2#,#url.to2#)
		GROUP BY sl.LineID, LineCode, LineName, AdditionalInfo
		HAVING COUNT(*)=2
	</cfquery>

	<cfset relTravelTime = toStation2.CostFromOrigin-cost />



	<cfquery name="TripTrack" dbtype="ODBC" datasource="SecureSource">
		SELECT * FROM vsd.EZLRTTracks WHERE LineID IN (#ValueList(validLines.LineID)#) AND CostDirection='#abs(relTravelTime)/relTravelTime#'
	</cfquery>



	<!--- Determine the origin station. What station is also on this line with the smallest cost --->
	<!--- If we are going in an increasing direction, we want to find stations with a smaller cost on this line --->
	<!--- Else we find the station with the highest cost --->
	<cfquery name="OriginStations" dbtype="ODBC" datasource="SecureSource">
		--This gets us our list of origin stations, even if there are two lines
		SELECT * FROM vsd.EZLRTStations s
		WHERE CostFromOrigin <cfif relTravelTime GT 0><=<cfelse>>=</cfif> #cost#
		AND s.StationID IN
		(SELECT StationID FROM vsd.EZLRTStationsLines WHERE StationID=s.StationID AND LineID IN (#ValueList(validLines.LineID)#))

	</cfquery>
	<!--- <cfdump var="#OriginStations#"> --->

	<!--- Now we have a list of originStations, so we can query for all the DepartureTimes from those trains --->
	<!--- We query for departures for the track we will use, which originate at one of our origin stations
			at a time after now() minus the difference in minutes between the origin station and the departure station
	--->

	<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
		SELECT
		CAST(DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) AS TIME)
		AS DepartureFromCurrentStation,
		DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST(DepartureTime AS DATETIME))
		AS DepartureFromCurrentStationDT,
		TID, TrackID, t.StationID, DestStationID, Mon, Tue, Wed, Thu, Fri, Sat, Sun, DepartureTime, t.AdditionalInfo,
		s.StationCode, s.StationName, s.CostFromOrigin,
		ds.StationID AS DestStationID, ds.StationCode AS DestStationCode, ds.StationName as DestStationName
		FROM vsd.EZLRTDepartureTimes t
		JOIN vsd.EZLRTStations s ON t.StationID=s.StationID
		JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID
		WHERE  t.TrackID IN (#ValueList(TripTrack.TrackID)#)
		AND t.StationID IN (#ValueList(OriginStations.StationID)#)
		AND #DOW#=1
		AND DepartureTime >= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), '#CurrentTime#') AS TIME)
		<!--- Skip this AND if it's After 11. If DateCompare is LT 1, it's before 11 PM --->
		<cfif DateCompare(CurrentTime, '22:50') LT 0>
			AND DepartureTime <= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), '#MaxFutureTime#') AS TIME)
		</cfif>
		ORDER BY DepartureFromCurrentStationDT
	</cfquery>

	<!--- This whole thing is a pretty awful hack to get times after midnight --->
	<cfquery name="DepartureTimesLate" dbtype="ODBC" datasource="SecureSource">
		SELECT
		CAST(DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) AS TIME)
		AS DepartureFromCurrentStation,
		DATEADD(minute, ABS(#Cost#-s.CostFromOrigin)+1440, CAST(DepartureTime AS DATETIME))
		AS DepartureFromCurrentStationDT,
		TID, TrackID, t.StationID, DestStationID, Mon, Tue, Wed, Thu, Fri, Sat, Sun, DepartureTime, t.AdditionalInfo,
		s.StationCode, s.StationName, s.CostFromOrigin,
		ds.StationID AS DestStationID, ds.StationCode AS DestStationCode, ds.StationName as DestStationName
		FROM vsd.EZLRTDepartureTimes t
		JOIN vsd.EZLRTStations s ON t.StationID=s.StationID
		JOIN vsd.EZLRTStations ds ON t.DestStationID=ds.StationID
		WHERE  t.TrackID IN (#ValueList(TripTrack.TrackID)#)
		AND t.StationID IN (#ValueList(OriginStations.StationID)#)
		AND (
			( DepartureTime >= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), '#CurrentTime#') AS TIME)
				AND #DOW#=1 AND DepartureTime <= '11:59:59')
		OR 
			( DepartureTime <= '4:30' AND #NextDOW#=1 )
		)
		ORDER BY DepartureFromCurrentStationDT
	</cfquery>


	<!--- <cfdump var="#DepartureTimes#"> --->
	<p>Departure times from <cfoutput>#fromStation2.StationName# to #toStation2.StationName#</cfoutput>:</p>
	<table class="altColors">
	<cfoutput query="DepartureTimes">
		<tr>
			<td class="trainName">#UCase(DestStationCode)#</td>
			<td class="arrivalTime" data-datetime="#DepartureFromCurrentStationDT#">#TimeFormat(DepartureFromCurrentStation, "h:mm tt")#</td>
			<td class="countdown"></td>
		</tr>
	</cfoutput>
	<!--- If It's after 11 PM, show the departure times after midnight. I'm not sure if this works. --->
	<cfif DateCompare(CurrentTime, '22:57') GTE 0>
	<cfif DepartureTimesLate.RecordCount><tr><td><b>Midnight</b></td></tr></cfif>
	<cfoutput query="DepartureTimesLate">
		<tr>
			<td class="trainName">#UCase(DestStationCode)#</td>
			<td class="arrivalTime" data-datetime="#DepartureFromCurrentStationDT#">#TimeFormat(DepartureFromCurrentStation, "h:mm tt")#</td>
			<td class="countdown"></td>
		</tr>
	</cfoutput>
	</cfif>

	</table>

	<p>The travel time for this trip will be about <b><cfoutput>#abs(relTravelTime)# minutes</cfoutput></b>.<br />


</cfif><!---isDefined('url.from2') AND isDefined('url.to2')--->


</cfif><!--- NOT isDefined('skipCalc')--->

</cfif><!---isDefined('url.from') AND isDefined('url.to')--->