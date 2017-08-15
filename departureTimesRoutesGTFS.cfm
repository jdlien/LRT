
<!--- This version of departureTimesRoutesGTFS gets departure times for the stops for a specific route --->

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


<cffunction name="getRouteDepartures" returntype="void"
description="Accepts FROM and TO stop IDs, and a datetime and outputs a table with relevant stops at that stop to the destination">
	<cfargument name="rid" required="true" type="numeric" />
	<cfargument name="from" required="true" type="numeric" />
	<cfargument name="CurrentTime" required="true" type="date" />
	<cfargument name="to" required="false" type="numeric" />

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


	<cfquery name="fromStop" dbtype="ODBC" datasource="SecureSource">
		SELECT * FROM vsd.ETS_stops WHERE stop_id=#from#
	</cfquery>
	
	<cfif isDefined('to') AND isNumeric(to)>
		<cfquery name="toStop" dbtype="ODBC" datasource="SecureSource">
			SELECT * FROM vsd.ETS_stops WHERE stop_id=#to#
		</cfquery>
	</cfif>

	<!--- Query that should show the relevant schedule times. --->
	<cfif isDefined('to') AND isNumeric(to)>
		<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
			SELECT * FROM (
			SELECT
				(SELECT TOP 1 sdt2.ActualDateTime FROM vsd.ETS_trip_stop_datetimes sdt2
				WHERE stop_id=#to#
				AND trip_id=sdt.trip_id
				AND stop_sequence > sdt.stop_sequence
				AND ActualDateTime > #CurrentTime#
				ORDER BY sdt2.ActualDateTime
			) AS dest_arrival_datetime,
			* FROM vsd.ETS_trip_stop_datetimes sdt
			WHERE route_id=#rid#
			AND stop_id=#from#
			AND ActualDateTime > #CurrentTime# AND ActualDateTime < #MaxFutureTime#
			) AS stops WHERE dest_arrival_datetime IS NOT NULL
			ORDER BY ActualDateTime
		</cfquery>	
	<cfelse>
		<cfquery name="DepartureTimes" dbtype="ODBC" datasource="SecureSource">
			SELECT NULL AS dest_arrival_datetime, * FROM vsd.ETS_trip_stop_datetimes sdt
			WHERE route_id=#rid#
			AND stop_id=#from#
			AND ActualDateTime > #CurrentTime# AND ActualDateTime < #MaxFutureTime#
			ORDER BY ActualDateTime
		</cfquery>		
	</cfif>




	<cfoutput>
	
	<table class="altColors">
	<thead>
		<tr>
			<th colspan="4">Departures from #fromStop.stop_name#
			<cfif isDefined('to') and isNumeric(to)>
			<span class="nowrap">to #toStop.stop_name#</span><!-- after #TimeFormat(CurrentTime, "h:mm tt")#-->
			<div class="tripTime"><cfif DepartureTimes.recordCount>
			<cfif IsDate(DepartureTimes.dest_arrival_datetime)>Trip time is <b>#dateDiff("n", DepartureTimes.ActualDateTime, DepartureTimes.dest_arrival_datetime)# minutes</b></cfif>
			<cfelse>
				There are no departures during this time. 
			</cfif>
			</cfif>
			</div>
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
			<cfif isDefined('to') and isNumeric(to)>
			<td class="dA" colspan="3">Arrive at #toStop.stop_name# <cfif IsDate(DepartureTimes.dest_arrival_datetime)>at #TimeFormat(dest_arrival_datetime, "h:mm tt")#</cfif></td>
			</cfif>
		</tr>
	</cfloop>
	</tbody>
	</table>
	</cfoutput>


	
</cffunction><!---getDepartures--->


<cfif isDefined('url.rid') AND isNumeric(url.rid)
	AND isDefined('url.from') AND isNumeric(url.from)>

	<cfif isDefined('url.to') AND url.from IS url.to>
		<!--- Ugh, this flahes when clicking "swap" --->
		<p class="gone">You have selected the same stops for your source and destination.<br /><br />Please select a different stop.</p>
	
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


		<!--- Here's where the magic happens. Call the getRouteDepartures function --->
		<cfif isDefined('url.to') and isNumeric(url.to)>
			<cfoutput>#getRouteDepartures(url.rid, url.from, currentTime, url.to)#</cfoutput>
		<cfelse>
			<cfoutput>#getRouteDepartures(url.rid, url.from, currentTime)#</cfoutput>
		</cfif>


	</cfif><!---if from IS to / else --->

</cfif><!---isDefined('url.from') AND isDefined('url.to')--->