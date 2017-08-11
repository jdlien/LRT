<cfsetting enablecfoutputonly="true">
<cfsetting showdebugoutput="false">
<cfheader name="Content-Type" value="application/json">
<!--- If we're passed a route_id (url.rid), we return all the relevant stop info here as JSON to populate select lists. Runs very quickly --->

<cfif isDefined("url.rid") AND isNumeric(url.rid)>
<!--- This query returns all unique stops on a route, ordered by their sequence --->
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
</cfquery>
<cfoutput>#SerializeJSON(routeStops)#</cfoutput>
<cfelse>
<cfoutput>{}</cfoutput>
</cfif>