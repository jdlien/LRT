
<!--- Simple function that accepts a weekday (2 or more letters) and returns the coldfusion weekday integer --->
<cffunction name="weekdayToNum" returntype="numeric">
	<cfargument name="DayName" required="true" type="String">
	<!--- If passed an int, just return it --->
	<cfif isNumeric(DayName)><cfreturn DayName></cfif>
	<cfswitch expression="#Left(DayName, 2)#">
		<cfcase value="Su">  <cfreturn 1></cfcase>
		<cfcase value="Mo,M"><cfreturn 2></cfcase>
		<cfcase value="Tu">  <cfreturn 3></cfcase>
		<cfcase value="We,W"><cfreturn 4></cfcase>
		<cfcase value="Th">  <cfreturn 5></cfcase>
		<cfcase value="Fr,F"><cfreturn 6></cfcase>
		<cfcase value="Sa">  <cfreturn 7></cfcase>
	</cfswitch>
</cffunction>
<!--- Loaded via ajax or include to show departureTimes table --->
<cfsetting showdebugoutput="true" />


<cffunction name="getDepartures" returntype="void"
description="Accepts FROM and TO station IDs, and a datetime and outputs a table with relevant stops at that station to the destination">
	<cfargument name="from" required="true" type="numeric" />
	<cfargument name="to" required="true" type="numeric" />
	<cfargument name="CurrentTime" required="true" type="date" />

	<!--- Set the says of the week --->
	<cfset DOW = CurDOW = DayOfWeek(CurrentTime) />
	<cfset NextDOW = (CurDOW+1) />
	<cfif NextDow GT 7><cfset NextDow -= 7 /></cfif>
	<cfset NextDOW = Left(DayOfWeekAsString(NextDOW),3)>
	<cfset PrevDOW = CurDOW-1 />
	<cfif PrevDOW LTE 0><cfset PrevDOW = PrevDOW+7></cfif>
	<cfset PrevDOW = Left(DayOfWeekAsString(PrevDOW),3)>
	<cfset CurDOW = Left(DayOfWeekAsString(CurDow),3)>


	<cfset maxDepartureMins = 90 />
	<!--- Show two hours if we are looking late at night --->
	<cfif Hour(CurrentTime) GTE 23 OR Hour(CurrentTime) IS 0>
		<cfset maxDepartureMins = 120 />
	</cfif>

	<!--- Set the end of the range we are interested in --->
	<cfset MaxFutureTime = DateAdd('n', maxDepartureMins, CurrentTime)>

	<!--- Information about relevant stations --->
	<cfquery name="fromStation" dbtype="ODBC" datasource="SecureSource">
		SELECT * FROM vsd.EZLRTStations WHERE StationID=#from#
	</cfquery>

	<cfquery name="toStation" dbtype="ODBC" datasource="SecureSource">
		SELECT * FROM vsd.EZLRTStations WHERE StationID=#to#
	</cfquery>


	<cfquery name="validLines" dbtype="ODBC" datasource="SecureSource">
		SELECT sl.LineID, LineCode, LineName, AdditionalInfo FROM vsd.EZLRTStationsLines sl
		JOIN vsd.EZLRTLines l ON sl.LineID=l.LineID
		WHERE StationID IN (#from#,#to#)
		GROUP BY sl.LineID, LineCode, LineName, AdditionalInfo
		HAVING COUNT(*)=2
	</cfquery>

	<cfset cost = fromStation.CostFromOrigin />
	<cfset relTravelTime = toStation.CostFromOrigin-cost />



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
			<cfset url.to = ConnectingStation.StationID />
			<!--- And url.from stays the same, obviously --->

			<!--- Recursively call getDepartures() from itself. --->
			<h2 class="leg">Leg 1 of 2</h2>
			<cfoutput>#getDepartures(url.from, url.to, CurrentTime)#</cfoutput>
			<h2 class="leg">Leg 2 of 2</h2>
			<cfoutput>#getDepartures(url.from2, url.to2, variables.CurrentTime)#</cfoutput>
			<cfreturn>
		<cfelse>
			<p class="error">You have chosen two stations with no connection between them.</p>
			<cfreturn />
		</cfif>

	</cfif><!---validLines.RecordCount IS 0--->


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

	<!--- If the date is just before midnight, then we leave the "yesterday" section to the same date
		and let the travel time wrap it to the next day
		 If the date is after midnight, we set it back one day --->
	<cfif Hour(CurrentTime) GTE 21>
		<cfset dateAdjust = 0>
	<cfelse>
		<cfset dateAdjust = -1>
	</cfif>

	<!--- Query that should show the relevant schedule times. --->
	<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
		SELECT (
			SELECT TOP 1 sdt2.ActualDateTime FROM vsd.ETS_trip_stop_datetimes sdt2
			WHERE (stop_id=#toStation.stop_id1# OR stop_id=#toStation.stop_id2#)
			AND trip_id=sdt.trip_id
			AND stop_sequence > sdt.stop_sequence
			AND ActualDateTime > #CurrentTime#
			ORDER BY sdt2.ActualDateTime
		) AS dest_arrival_datetime,
		* FROM vsd.ETS_trip_stop_datetimes sdt
		WHERE pickup_type=0 AND (stop_id=#fromStation.stop_id1# OR stop_id=#fromStation.stop_id2#) --FROM station, North OR South
		AND trip_id IN (SELECT DISTINCT trip_id from vsd.ETS_stop_times stime2	WHERE stime2.stop_id=#toStation.stop_id1# OR stime2.stop_id=#toStation.stop_id2#) --TO station, North OR South
		AND ActualDateTime > #CurrentTime# AND ActualDateTime < #MaxFutureTime#
		AND EXISTS --stop for destination station from same trip
		(SELECT stop_sequence FROM vsd.ETS_stop_times stime3
			WHERE (stop_id=#toStation.stop_id1# OR stop_id=#toStation.stop_id2#)
			AND trip_id=sdt.trip_id
			AND stop_sequence > sdt.stop_sequence
			-- AND stop_sequence-sdt.stop_sequence < 
			-- --If there's more than one stop for our FROM location, 
			-- CASE WHEN (SELECT COUNT(*) FROM vsd.ETS_stop_times WHERE trip_id=sdt.trip_id AND (stop_id=#fromStation.stop_id1# OR stop_id=#fromStation.stop_id2#)) > 1 --If the from station shows up twice
			-- THEN (SELECT Max(stop_sequence)/2 FROM vsd.ETS_stop_times WHERE trip_id=sdt.trip_id) --We look for the one that is less than half a trip away
			-- ELSE (SELECT Max(stop_sequence) FROM vsd.ETS_stop_times WHERE trip_id=sdt.trip_id) --Otherwise, we look through the whole trip
			-- END --CASE
			AND sdt.stop_sequence = (
				SELECT TOP 1
				stop_sequence
				FROM vsd.ETS_stop_times
				WHERE trip_id=sdt.trip_id
				AND (stop_id=#fromStation.stop_id1# OR stop_id=#fromStation.stop_id2#)
				AND stop_sequence < stime3.stop_sequence
				ORDER BY stime3.stop_sequence-stop_sequence
			)
			--This should now work for a circular system because it'll only limit the stop-time difference to half of the trip if there's more than one stop for the current FROM...
			AND drop_off_type=0 --this makes sure we can get off, won't show the pickup stop after train switches direction
		)
		ORDER BY ActualDateTime
	</cfquery>

	<!--- For Debugging/Testing --->
	<cfif isDefined("url.debug")>
	<span class="timeStamp">
		<cfoutput><b>CurrentTime: </b>#dateFormat(CurrentTime, "Ddd Mmm dd")# #timeFormat(CurrentTime, "HH:mm")#</cfoutput>
	</span>
	<table class="debug altColors">
		<tr>
			<th>ActualDateTime</th>
			<th>dest_arrival</th>
			<th>trip_id</th>
			<th>block_id</th>
			<th>arrival</th>
			<th>stop_id</th>
			<th>seq</th>
			<th>headsign</th>
			<th>pu</th>
			<th>do</th>
			<th>dist</th>
			<th>rid</th>
		</tr>
		<cfoutput query="DepartureTimes">
			<tr>
				<td><span class="nowrap">#DateFormat(ActualDateTime,"YYYY-Mmm-dd")#</span> #TimeFormat(ActualDateTime, "HH:mm")#</td>
				<td><span class="nowrap">#DateFormat(dest_arrival_datetime,"YYYY-Mmm-dd")#</span> #TimeFormat(dest_arrival_datetime, "HH:mm")#</td>
				<td>#trip_id#</td>
				<td>#block_id#</td>
				<td>#arrival_time#</td>
				<td>#stop_id#</td>
				<td>#stop_sequence#</td>
				<td>#stop_headsign#</td>
				<td>#pickup_type#</td>
				<td>#drop_off_type#</td>
				<td>#shape_dist_traveled#</td>
				<td>#route_id#</td>
			</tr>
		</cfoutput>
	</table>
	</cfif>

	<cfoutput>
	<!---
	<div class="trainsFromTo">
		<div class="tripTime">Trip time is about <b>#abs(relTravelTime)# minutes</b></div>
	</div>
	--->
	
	<table class="altColors">
	<thead>
		<tr>
			<th colspan="4">Departures from #fromStation.StationCode# <span class="nowrap">to #toStation.StationCode#</span><!-- after #TimeFormat(CurrentTime, "h:mm tt")#-->
			<div class="tripTime"><cfif DepartureTimes.recordCount>
			Trip time is <b>#dateDiff("n", DepartureTimes.ActualDateTime, DepartureTimes.dest_arrival_datetime)# minutes</b>
			<cfelse>
				There are no departures during this time. 
			</cfif></div>
			</th></tr>
		</tr>
	</thead>
	<tbody>
	<cfloop query="DepartureTimes">
		<!--- Only show if the time hasn't elapsed --->
		<tr>
			<td class="trainName">#UCase(stop_headsign)#</td>
			<td class="arrivalTime" data-datetime="#ActualDateTime#">#TimeFormat(ActualDateTime, "h:mm tt")#</td>
			<td class="countdown"></td>
		<tr class="destRow"><td class="destArrival" colspan="3"><!--- Depart at #TimeFormat(ActualDateTime, "h:mm")# and  --->Arrive in #toStation.StationCode# at #TimeFormat(dest_arrival_datetime, "h:mm tt")#</td></tr>
		</tr>
	</cfloop>
	</tbody>
	</table>
	</cfoutput>


	<!--- Set this for the next call to departureTimes - it will then start with the first time from the last query plus the travel time, minus a two minute fudge factor --->
	<cfif isDefined('DepartureTimes.ActualDateTime') AND isDate(DepartureTimes.ActualDateTime)>
		<cfset variables.CurrentTime = DateAdd("n", abs(relTravelTime)-2, DepartureTimes.ActualDateTime) >
	</cfif>
	
</cffunction><!---getDepartures--->



<cfif isDefined('url.from') AND isDefined('url.to')>
	<cfif url.from IS url.to>
		<p class="gone">You have selected the same stations for your source and destination.<br /><br />Please select a different station.</p>
	
	<cfelse>
		<!--- Setting date variables for DepartureTimes query --->
		<!--- Set the Day of Week. Sunday is 1, Saturday is 7 --->
		<cfif isDefined('url.dow') AND len(url.dow) GTE 3>
			<cfset DOW = Left(url.dow, 3)>
		<cfelse>
	 		<cfset DOW = Left(DayOfWeekAsString(DayOfWeek(now())),3)>
		</cfif>

		<!--- If it's Monday, and we've specified Sunday, we'll get -1. Add 7 to get 6 days ahead --->
		<cfset dayDiff = weekdayToNum(DOW) - DayOfWeek(now())>
		<cfif dayDiff LT 0><cfset dayDiff+=7></cfif> 

		<!--- Our start datetime for purposes of the query will then be --->
		<cfset CurrentTime = DateAdd('d', dayDiff, now()) >

		<!--- If the user has specified a time, we set it here --->
		<cfif isDefined('url.time') and len(url.time) GTE 3>
			<!--- Create a new currentTime with the speified time url --->
			<cfset CurrentTime=CreateDateTime(Year(CurrentTime), Month(CurrentTime), Day(CurrentTime), Hour(url.time), Minute(url.time), 0)>
		</cfif>
		<!--- Subtract three minutes to account for trains being a little late --->
		<cfset CurrentTime = DateAdd("n", -3, CurrentTime)>


		<!--- Here's where the magic happens. Call the recursive getDepartures function --->
		<cfoutput>#getDepartures(url.from, url.to, currentTime)#</cfoutput>

	</cfif><!---if from IS to / else --->

</cfif><!---isDefined('url.from') AND isDefined('url.to')--->