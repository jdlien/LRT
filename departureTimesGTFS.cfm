
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
<cfsetting requesttimeout="12" />
<!--- set to 12s as safeguard against runaway recursive function. This page gets really slow, though :(  --->


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

	<!--- This query checks to see if our to and from stations connect. If not, we have to find a connecting station --->
	<cfquery name="validTrips" dbtype="ODBC" datasource="SecureSource">
		SELECT trip_id FROM 
			(SELECT trip_id, min(stop_id) as minStop FROM vsd.ETS_stop_times
			WHERE stop_id IN (#fromStation.stop_id1#,#fromStation.stop_id2#)
			GROUP  BY trip_id
			UNION ALL
			SELECT trip_id, min(stop_id) as minStop FROM vsd.ETS_stop_times
			WHERE stop_id IN (#toStation.stop_id1#,#toStation.stop_id2#)
		GROUP BY trip_id) stt
		GROUP BY trip_id HAVING COUNT(*) > 1
	</cfquery>

	<cfset cost = fromStation.CostFromOrigin />
	<cfset relTravelTime = toStation.CostFromOrigin-cost />



	<cfif validTrips.RecordCount IS 0>
		<!--- Query for a station that has a line present at both the source and destination station --->
		<!--- I could honestly just hardcode this as Churchill... but what fun would that be? --->

		<cfquery name="CommonStops" dbtype="ODBC" datasource="SecureSource">
			SELECT stop_id FROM (
			--All stops on trips that include FROM station
			SELECT DISTINCT stop_id--, stop_sequence
			FROM vsd.ETS_stop_times WHERE trip_id IN (SELECT trip_ID from  vsd.ETS_stop_times WHERE stop_id IN (#fromStation.stop_id1#, #fromStation.stop_id2#) )
			UNION ALL
			--All stops on trips that include TO station
			SELECT DISTINCT stop_id--, stop_sequence
			FROM vsd.ETS_stop_times WHERE trip_id IN (SELECT trip_ID from  vsd.ETS_stop_times WHERE stop_id IN (#toStation.stop_id1#, #toStation.stop_id2#) )
			) AS bothRouteStops
			GROUP BY bothRouteStops.stop_id
			HAVING count(stop_id)=2
		</cfquery>


		<!--- Get a max sequence for the example trip to be sure we get a trip that has the full set of stops --->
		<cfquery name="MaxTrip" dbtype="ODBC" datasource="SecureSource">
			SELECT MAX(stop_sequence) AS max_stops FROM vsd.ETS_stop_times stimes WHERE trip_id IN (
				--list of trips with our from and connecting stations
				SELECT trip_id FROM
				(	(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times
					WHERE stop_id IN
						(<cfoutput query="CommonStops"><cfif currentRow GT 1>,</cfif>#stop_id#</cfoutput>)
					)
					UNION ALL
					(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times
					WHERE stop_id IN
					--From station (#fromStation.StationCode# in this case)
					(#fromStation.stop_id1#, #fromStation.stop_id2#)
					)
				) AS bothStopTrips
		
				GROUP BY trip_id HAVING count(*)=2
			)
		</cfquery>

		<cfquery name="ExampleTrip" dbtype="ODBC" datasource="SecureSource">
		-- This seems to work efficiently to get a trip ID
		SELECT MAX(trip_id) AS trip_id FROM vsd.ETS_stop_times WHERE trip_id IN (
			--list of trips with our from and connecting stations
			SELECT trip_id FROM
			(	(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times
				WHERE stop_id IN
					(<cfoutput query="CommonStops"><cfif currentRow GT 1>,</cfif>#stop_id#</cfoutput>)
				)
				UNION ALL
				(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times
				WHERE stop_id IN
				--From station (Clareview in this example)
				(#fromStation.stop_id1#, #fromStation.stop_id2#)
				)
			) AS bothStopTrips
			WHERE stop_sequence=#MaxTrip.max_stops#
			GROUP BY trip_id HAVING count(*)=2
		)
		</cfquery>


		<cfquery name="ConnectingStopID" dbtype="ODBC" datasource="SecureSource">
			SELECT TOP 1 stop_id FROM vsd.ETS_stop_times WHERE trip_id=#ExampleTrip.trip_id#
			AND stop_sequence > (SELECT MAX(stop_sequence) FROM vsd.ETS_stop_times WHERE trip_id=#ExampleTrip.trip_id# AND stop_id IN (#fromStation.stop_id1#,#fromStation.stop_id2#))
			AND stop_id in (<cfoutput query="CommonStops"><cfif currentRow GT 1>,</cfif>#stop_id#</cfoutput>)
			ORDER BY stop_sequence
		</cfquery>

		<cfquery name="ConnectingStation" dbtype="ODBC" datasource="SecureSource">
			SELECT * FROM vsd.EZLRTStations WHERE
			stop_id1=#ConnectingStopID.stop_id# OR stop_id2=#ConnectingStopID.stop_id#
		</cfquery>


		<!--- all-in-one ConnectingStation query... about 300ms slower this way
		<cfquery name="ConnectingStation" dbtype="ODBC" datasource="SecureSource">

		--CommonStops (Datasource=SecureSource, Time=47ms, Records=21) in C:\inetpub\apps.epl.ca\Dev\LRT\departureTimesGTFS.cfm @ 10:37:47.047
		DECLARE @commonStops TABLE (stop_id INT);
		INSERT INTO @commonStops (stop_id)
			SELECT stop_id FROM (
			--All stops on trips that include FROM station
			SELECT DISTINCT stop_id--, stop_sequence
			FROM vsd.ETS_stop_times WHERE trip_id IN (SELECT trip_ID from  vsd.ETS_stop_times WHERE stop_id IN (#fromStation.stop_id1#,#fromStation.stop_id2#) )
			UNION ALL
			--All stops on trips that include TO station
			SELECT DISTINCT stop_id--, stop_sequence
			FROM vsd.ETS_stop_times WHERE trip_id IN (SELECT trip_ID from  vsd.ETS_stop_times WHERE stop_id IN (#toStation.stop_id1#,#toStation.stop_id2#) )
			) AS bothRouteStops
			GROUP BY bothRouteStops.stop_id
			HAVING count(stop_id)=2

		--maxStops
		DECLARE @maxStops INT = (
		SELECT MAX(stop_sequence) AS max_stops FROM vsd.ETS_stop_times stimes WHERE trip_id IN (
			--list of trips with our from and connecting stations
			SELECT trip_id FROM
			(
				(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times WHERE stop_id IN (SELECT stop_id FROM @commonStops) )
				UNION ALL
				(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times
				WHERE stop_id IN --From station
				(#fromStation.stop_id1#,#fromStation.stop_id2#)
				) 
			) AS bothStopTrips
			GROUP BY trip_id HAVING count(*)=2
		)
		)
				
		--ExampleTrip trip_id
		DECLARE @exampleTrip INT = (
			SELECT MAX(trip_id) AS trip_id FROM vsd.ETS_stop_times WHERE trip_id IN (
				--list of trips with our from and connecting stations
				SELECT trip_id FROM
				(	(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times
					WHERE stop_id IN
						(SELECT stop_id FROM @commonStops)
					)
					UNION ALL
					(SELECT DISTINCT trip_id FROM vsd.ETS_stop_times
					WHERE stop_id IN --From station
					(#fromStation.stop_id1#,#fromStation.stop_id2#)
					)
				) AS bothStopTrips
				WHERE stop_sequence=@maxStops
				GROUP BY trip_id HAVING count(*)=2
			)
		)
		--ConnectingStopID (Datasource=SecureSource, Time=172ms, Records=1) in C:\inetpub\apps.epl.ca\Dev\LRT\departureTimesGTFS.cfm @ 10:37:48.048
		DECLARE @connectingStopID INT = (
			SELECT TOP 1 stop_id FROM vsd.ETS_stop_times WHERE trip_id=@exampleTrip
			AND stop_sequence > (SELECT MAX(stop_sequence) FROM vsd.ETS_stop_times WHERE trip_id=@exampleTrip AND stop_id IN (#fromStation.stop_id1#,#fromStation.stop_id2#))
			AND stop_id IN (SELECT stop_id FROM @commonStops)
			ORDER BY stop_sequence
		)
				
		--ConnectingStation (Datasource=SecureSource, Time=0ms, Records=1) in C:\inetpub\apps.epl.ca\Dev\LRT\departureTimesGTFS.cfm @ 10:37:48.048
		SELECT * FROM vsd.EZLRTStations WHERE
		stop_id1 = @connectingStopID OR stop_id2 = @connectingStopID 

		</cfquery> END giant connectingstation query --->





		<!--- If there's a connecting station, we now have to do TWO routes. Have fun. --->
		<cfif ConnectingStation.RecordCount>

			<cfset url.from2 = ConnectingStation.StationID />
			<cfset fromStation2 = ConnectingStation />
			<cfset url.to2 = url.to />
			<cfset url.to = ConnectingStation.StationID />
			<!--- And url.from stays the same, obviously --->

			<cfquery name="Route1" dbtype="ODBC" datasource="SecureSource">
				SELECT * FROM vsd.ETS_routes WHERE route_id=
				(
					SELECT MAX(t.route_id) AS Route_ID FROM vsd.ETS_stop_times stime
					JOIN vsd.ETS_trips t ON stime.trip_id=t.trip_id
					WHERE stop_id IN (#fromStation.stop_id1#,#fromStation.stop_id2#)
				)
			</cfquery>

			<cfquery name="toStation2" dbtype="ODBC" datasource="SecureSource">
				SELECT * FROM vsd.EZLRTStations WHERE StationID=#url.to2#
			</cfquery>

			<cfquery name="Route2" dbtype="ODBC" datasource="SecureSource">
				SELECT * FROM vsd.ETS_routes WHERE route_id=(
					SELECT MAX(t.route_id) AS Route_ID FROM vsd.ETS_stop_times stime
					JOIN vsd.ETS_trips t ON stime.trip_id=t.trip_id
					WHERE stop_id IN (#toStation2.stop_id1#,#toStation2.stop_id2#)
				)
			</cfquery>


			<!--- Recursively call getDepartures() from itself. --->
			<cfoutput>
			<h2 class="leg">Leg 1: <cfif Route1.route_type IS 3>#Route1.route_id# </cfif>#Route1.route_long_name#</h2> <!--- line/route of url.from --->
			#getDepartures(url.from, url.to, CurrentTime)#
			<h2 class="leg">Leg 2:  <cfif Route2.route_type IS 3>#Route2.route_id# </cfif>#Route2.route_long_name#</h2> <!--- line/route of url.to2 --->
			#getDepartures(url.from2, url.to2, variables.CurrentTime)#
			</cfoutput>
			<cfreturn>
		<cfelse>
			<p class="error">You have chosen two stations with no connection between them.</p>
			<cfreturn />
		</cfif>

	</cfif><!---validTrips.RecordCount IS 0--->



	<!--- Query that should show the relevant schedule times. --->
	<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
		SELECT
		<cfif isDefined('url.destTime')>( -- As cool as it is to get the destination arrival time, it makes queries 10x slower :(
			SELECT TOP 1 sdt2.ActualDateTime FROM vsd.ETS_trip_stop_datetimes sdt2
			WHERE (stop_id=#toStation.stop_id1# OR stop_id=#toStation.stop_id2#)
			AND trip_id=sdt.trip_id
			AND stop_sequence > sdt.stop_sequence
			AND ActualDateTime > #CurrentTime#
			ORDER BY sdt2.ActualDateTime
		) AS dest_arrival_datetime, </cfif>
		* FROM vsd.ETS_trip_stop_datetimes sdt
		WHERE pickup_type=0 AND (stop_id=#fromStation.stop_id1# OR stop_id=#fromStation.stop_id2#) --FROM station #fromStation.StationCode#, North OR South
		AND trip_id IN (SELECT DISTINCT trip_id from vsd.ETS_stop_times stime2	WHERE stime2.stop_id=#toStation.stop_id1# OR stime2.stop_id=#toStation.stop_id2#) --TO station #toStation.StationCode#, North OR South
		AND ActualDateTime > #CurrentTime# AND ActualDateTime < #MaxFutureTime#
		AND EXISTS --stop for destination station from same trip
		(SELECT stop_sequence FROM vsd.ETS_stop_times stime3
			WHERE (stop_id=#toStation.stop_id1# OR stop_id=#toStation.stop_id2#)
			AND trip_id=sdt.trip_id
			AND stop_sequence > sdt.stop_sequence
			-- This clause is necessary to determine ensure we only get trains going the right direction
			AND sdt.stop_sequence = (
				SELECT max(stop_sequence) FROM vsd.ETS_stop_times
				WHERE trip_id=sdt.trip_id AND (stop_id=#fromStation.stop_id1# OR stop_id=#fromStation.stop_id2#)
				AND stop_sequence < stime3.stop_sequence
			)
			AND drop_off_type=0 --this makes sure we can get off, won't show the pickup stop after train switches direction
		)
		ORDER BY ActualDateTime
	</cfquery>

	<!--- See, if I put it here, I can use the actual destination stop --->
	<cfif DepartureTimes.RecordCount>
		<!--- Query to calculate trip times. Should only add a few ms --->
		<cfquery name="TripDurationHelper" dbtype="ODBC" datasource="SecureSource">
			SELECT TOP 3 arrival_time, trip_id, stop_id, stop_sequence, stop_headsign,
			(SELECT TOP 1 arrival_time FROM vsd.ETS_stop_times
			WHERE trip_id=#validTrips.trip_id# --from validTrips
				AND stop_id IN (#toStation.stop_id1#,#toStation.stop_id2#)
				AND stop_sequence > sdt.stop_sequence
				ORDER BY stop_sequence
			) AS DestTime
			FROM vsd.ETS_stop_times sdt WHERE trip_id=#validTrips.trip_id#
			AND stop_id IN (#fromStation.stop_id1#,#fromStation.stop_id2#)
			AND (SELECT TOP 1 arrival_time FROM vsd.ETS_stop_times
			WHERE trip_id=#validTrips.trip_id# --from validTrips
				AND stop_id IN (#toStation.stop_id1#,#toStation.stop_id2#)
				AND stop_sequence > sdt.stop_sequence
			) IS NOT NULL
			ORDER BY arrival_time DESC
		</cfquery>

		<!--- If we got a valid --->
		<cfif TripDurationHelper.RecordCount AND len(TripDurationHelper.DestTime)>
			<!--- Deal with wacky 24+ hour times here if they crop up - just subtract ten hours, since only relative times matter --->
			<cfif left(TripDurationHelper.destTime,2) GT 23>
				<cfset TripDurationHelper.arrival_time = (left(TripDurationHelper.arrival_time,2)-10)&right(TripDurationHelper.arrival_time, 6)>
				<cfset TripDurationHelper.DestTime = (left(TripDurationHelper.DestTime,2)-10)&right(TripDurationHelper.DestTime, 6)>
			</cfif>
			<cfset relTravelTime=DateDiff("n", TripDurationHelper.arrival_time, TripDurationHelper.DestTime) />
		</cfif>

	</cfif>

	<!--- For Debugging/Testing --->
	<cfif isDefined("url.debug")>
	<span class="timeStamp">
		<cfoutput><b>CurrentTime: </b>#dateFormat(CurrentTime, "Ddd Mmm dd")# #timeFormat(CurrentTime, "HH:mm")#</cfoutput>
	</span>
	<table class="debug altColors">
		<tr>
			<th>ActualDateTime</th>
			<cfif isDefined('url.destTime')><th>dest_arrival</th></cfif>
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
				<cfif isDefined('url.destTime')><td><span class="nowrap">#DateFormat(dest_arrival_datetime,"YYYY-Mmm-dd")#</span> #TimeFormat(dest_arrival_datetime, "HH:mm")#</td></cfif>
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
			<cfif isDefined('url.destTime')>Trip time is <b>#dateDiff("n", DepartureTimes.ActualDateTime, DepartureTimes.dest_arrival_datetime)# minutes</b><cfelse>
			Trip time is <b>#abs(relTravelTime)#</b> minute<cfif abs(relTravelTime) GT 1>s</cfif></cfif>
			<cfelse>
				There are no departures during this time. 
			</cfif></div>
			</th>
		</tr>
	</thead>
	<tbody>
	<cfloop query="DepartureTimes">
		<!--- Only show if the time hasn't elapsed --->
		<tr>
			<td class="tN">#UCase(stop_headsign)#</td>
			<td class="aT" data-datetime="#ActualDateTime#">#TimeFormat(ActualDateTime, "h:mm tt")#</td>
			<td class="cD"></td>
		</tr>
		<tr class="dR">
			<td class="dA" colspan="3">Arrive at #toStation.StationCode# <cfif isDefined('url.destTime')>at #TimeFormat(dest_arrival_datetime, "h:mm tt")#<cfelse>at #TimeFormat(DateAdd("n", abs(relTravelTime), ActualDateTime), "h:mm tt")#</cfif></td>
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