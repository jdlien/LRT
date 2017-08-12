<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfheader name="Content-Type" value="application/json">
<!--- If we're passed a route_id (url.rid), we return all the relevant stop info here as JSON to populate select lists. Runs very quickly --->

<cfif isDefined("url.rid") AND isNumeric(url.rid)>
<!--- This query returns all unique stops on a route, ordered by their sequence. Unfortunately I can't guarantee that I'm returning all stops
<cfquery name="routeStops" dbtype="ODBC" datasource="SecureSource">
	SELECT stime.stop_id, stop_name, stop_lat, stop_lon, min(stop_sequence) AS min_stop_sequence FROM vsd.ETS_stop_times stime
	JOIN vsd.ETS_stops s ON s.stop_id=stime.stop_id
	WHERE trip_id = (
		SELECT trip_id FROM (
		SELECT TOP 1 MAX(stop_sequence) AS max_stops, trip_id AS trip_id
		FROM vsd.ETS_stop_times stimes WHERE trip_id IN (
				SELECT trip_id FROM vsd.ETS_trips WHERE route_id=#url.rid#)
		GROUP BY trip_id
		) AS max_trip
	)
	GROUP BY stime.stop_id, stop_name, stop_lat, stop_lon
	ORDER BY min_stop_sequence
</cfquery> --->

<!--- If I have a url.routeFrom id, I will only return the stops that are a destination for a trip AFTER the specified route
Hopefully this will make it much easier to select the appropriate stop
--->
<cfif isDefined('url.routeFrom') AND isNumeric(url.routeFrom)>

<cfquery name="routeStops" dbtype="ODBC" datasource="SecureSource">
	SELECT DISTINCT sdt.stop_id, stop_name, stop_lat, stop_lon FROM vsd.ETS_trip_stop_datetimes sdt
	JOIN vsd.ETS_stops s ON s.stop_id=sdt.stop_id
	WHERE route_id=#url.rid#
	-- Does the current route have any instances
	-- where it is in the same trip as the routeFrom
	-- and has a stop_sequence that is higher?
	AND stop_sequence > (SELECT stop_sequence FROM vsd.ETS_stop_times WHERE trip_id = sdt.trip_id AND  stop_id=#url.routeFrom#)
</cfquery>
<cfelse>

<cfquery name="routeStops" dbtype="ODBC" datasource="SecureSource">
	SELECT DISTINCT sdt.stop_id, stop_name, stop_lat, stop_lon FROM vsd.ETS_trip_stop_datetimes sdt
	JOIN vsd.ETS_stops s ON s.stop_id=sdt.stop_id
	WHERE route_id=#url.rid#
</cfquery>

</cfif>
<!--- Create a simple data structure that I can use with selectize to populate dropdowns --->
<cfset stopOptions = ArrayNew(1) />
<cfloop query="routeStops">
	<cfset stop = structNew() />
	<cfset stop["value"]=stop_id />
	<cfset stop["text"]="#stop_id# #stop_name#" />
	<cfset ArrayAppend(stopOptions, stop) />
</cfloop>

<cfoutput>#SerializeJSON(stopOptions)#</cfoutput>
<cfelse>
<cfoutput>{}</cfoutput>
</cfif>