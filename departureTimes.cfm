
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
<cfsetting showdebugoutput="false" />

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
		SELECT
		CASE -- This glorious CASE will create a proper date out of the schedule times
		WHEN DepartureTime > DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) THEN --Yesterday
				DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), CAST('#DateFormat(DateAdd("d", dateAdjust, CurrentTime), "YYYY-MM-DD")# '+LEFT(CONVERT(CHAR, DepartureTime),10) AS DATETIME))
		-- Must change this when changing NextDOW
		WHEN DATEPART(hh, DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime))+21 <= DATEPART(hh, #CurrentTime#)
			THEN --Tomorrow
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
		AND t.StationID IN (#ValueList(OriginStations.StationID)#)
		<!--- Show only relevant days of the week --->
		AND (
		(#PrevDOW# = CASE WHEN DepartureTime > DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) THEN 1 END
			-- This clause only matters if it's very late or early in the morning (before 4)
			AND (DATEPART(hh, #CurrentTime#) <= 3)
			AND DepartureTime >= '22:57'
		)
		-- If departure time is less than 21 hours before current time, we assume it's the next day since we don't ever count backwards
		-- Keep in mind that there's a parallel WHEN in the list of select fields that needs to be changed if this changes
		OR (#NextDOW# = CASE WHEN DATEPART(hh, DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime))+21 <= DATEPART(hh, #CurrentTime#) THEN 1 END
			AND (DepartureTime < '04:57' OR DepartureTime > '23:00')
		)
		-- Normal case - the date of departure is greater than or equal to currenttime.
		OR  (#CurDow# = 1
			AND DATEADD(minute, ABS(#Cost#-s.CostFromOrigin), DepartureTime) >= CAST(#CurrentTime# AS TIME)
			<!--- Only use this if the FutureTime didn't wrap to the next day. Otherwise show to end of day --->
			<cfif Hour(MaxFutureTime) GTE Hour(CurrentTime)>
				AND DepartureTime <= CAST(DATEADD(minute, -ABS(#Cost#-s.CostFromOrigin), #MaxFutureTime#) AS TIME)
			</cfif>
		)
	)
	ORDER BY DepartureFromCurrentStationDT
	</cfquery>

	<!--- For Debugging/Testing --->
	<cfif isDefined("url.debug")>
	<span class="timeStamp">
		<cfoutput><b>CurrentTime: </b>#dateFormat(CurrentTime, "Ddd Mmm dd")# #timeFormat(CurrentTime, "HH:mm")#</cfoutput>
	</span>
	<table class="debug altColors">
		<tr>
			<th>Cost</th>
			<th>CurStnDprtDT</th>
			<th>Dprt</th>
			<th colspan="7">Days</th>
			<th>Dest Stn</th>
			<th>Source Stn</th>
		</tr>
		<cfoutput query="DepartureTimes">
			<tr>
				<td>#CostFromOrigin#</td>
				<td>#DateFormat(DepartureFromCurrentStationDT, "Ddd mmm, dd")# #TimeFormat(DepartureFromCurrentStationDT, "HH:mm")#</td>
				<td>#TimeFormat(DepartureTime, "HH:mm")#</td>
				<td class="dowCell"><cfif Mon>M<cfelse>_</cfif></td>
				<td class="dowCell"><cfif Tue>Tu<cfelse>_</cfif></td>
				<td class="dowCell"><cfif Wed>W<cfelse>_</cfif></td>
				<td class="dowCell"><cfif Thu>Th<cfelse>_</cfif></td>
				<td class="dowCell"><cfif Fri>F<cfelse>_</cfif></td>
				<td class="dowCell"><cfif Sat>Sa<cfelse>_</cfif></td>
				<td class="dowCell"><cfif Sun>Su<cfelse>_</cfif></td>
				<td>#DestStationCode#</td>
				<td>#StationCode#</td>
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
			<th colspan="3">Departures from #fromStation.StationCode# <span class="nowrap">to #toStation.StationCode#</span><!-- after #TimeFormat(CurrentTime, "h:mm tt")#-->
			<div class="tripTime">Trip time is about <b>#abs(relTravelTime)# minutes</b></div>
			</th></tr>
		</tr>
	</thead>
	<tbody>
	<cfloop query="DepartureTimes">
		<!--- Only show if the time hasn't elapsed --->
		<cfif DateCompare(DepartureFromCurrentStationDT, CurrentTime) GTE 0>
			<tr>
				<td class="trainName">#UCase(DestStationCode)#</td>
				<td class="arrivalTime" data-datetime="#DepartureFromCurrentStationDT#">#TimeFormat(DepartureFromCurrentStationDT, "h:mm tt")#</td>
				<td class="countdown"></td>
			</tr>
		</cfif>
	</cfloop>
	</tbody>
	</table>
	</cfoutput>


	<!--- Set this for the next call to departureTimes - it will then start with the first time from the last query plus the travel time, minus a two minute fudge factor --->
	<cfif isDefined('DepartureTimes.DepartureFromCurrentStationDT') AND isDate(DepartureTimes.DepartureFromCurrentStationDT)>
		<cfset variables.CurrentTime = DateAdd("n", abs(relTravelTime)-2, DepartureTimes.DepartureFromCurrentStationDT) >
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