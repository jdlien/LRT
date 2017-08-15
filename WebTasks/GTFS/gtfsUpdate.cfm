<cfsetting requesttimeout="600" /><!--- 600 seconds = ten minutes--->
<!--- First, I'm going to see if I can get all this GTFS data to download --->


<!--- Link Provided by City of Edmonton--->
<cfset gtfsUrl = "https://data.edmonton.ca/download/gzhc-5ss6/application%2Fzip" />

<!--- Actual filename --->
<!--- <cfset gtfsActual = "https://data.edmonton.ca/api/views/gzhc-5ss6/files/d646faa2-b520-418a-95e8-8ba53a989daf?filename=gtfs.zip" /> --->
<!--- 💩 <cfhttp method="get" url="#gtfsUrl#" path="C:\inetpub\temp\gtfs" file="gtfs.zip" timeout="1000" getasbinary="auto"> --->

<!--- Download COE zip file --->


<cfx_http5 url="#gtfsUrl#" ssl="5" async="n" out="C:\inetpub\temp\gtfs\gtfs.zip" file="y">

<CFIF STATUS EQ "ER">
   <h2>Server returned error: <CFOUTPUT>#ERRN#</CFOUTPUT></h2>
   <p><b>Failure to update GTFS Data</b></p>
   <!--- Could email JD here --->
   <CFOUTPUT>#MSG#</CFOUTPUT>
   <CFABORT>
</CFIF>
<!--- Extract zip into gtfs directory --->
<cfzip action="unzip" file="C:\inetpub\temp\gtfs\gtfs.zip" overwrite="true" destination="C:\inetpub\temp\gtfs\" />

<!--- Delete the original zip as we do not need it anymore --->
<cffile action="delete" file="C:\inetpub\temp\gtfs\gtfs.zip" />



<!--- List of files. First in reverse order for deleting without violating constraints --->

<!--- Remove annoying headers from GTFS files so we can import them easily --->
<!--- They use the command findstr /V /R "^[a-z].*[a-z]$" stop_times.txt > stop_times_noheader.txt --->
<cfexecute name='C:\inetpub\www2.epl.ca\WebTasks\GTFS\stripheaders.bat' timeout="10" />



<cfset gtfsFilesRev="stop_times,transfers,trips,stops,shapes,routes,calendar_dates,agency" />
<!--- DO NOT include stop_times at the end of this list. We handle it separately --->
<cfset gtfsFiles="agency,calendar_dates,routes,shapes,stops,trips,transfers,stop_times" />

<cfquery name="BulkInsert" dbtype="ODBC" datasource="ReadWriteSource">

<cfloop list="#gtfsFilesRev#" index="fileBase">
DELETE FROM vsd.ETS_#fileBase#
</cfloop>
<cfloop list="#gtfsFiles#" index="fileBase">
	BULK INSERT vsd.ETS_#fileBase# FROM '\\web6\gtfs$\#fileBase#_noheader.txt'
	WITH (
	FIRSTROW=1,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n',
	FORMATFILE = '\\web6\gtfs$\#fileBase#.fmt'
	);
</cfloop>


</cfquery>

<!--- There are a few stray double-quotes that I want to get rid of --->
<cfquery name="CleanUp" dbtype="ODBC" datasource="ReadWriteSource">
	<!--- only LRT route short names have double quotes ("Capital", "Metro"). Remove them. --->
	UPDATE vsd.ETS_routes SET route_short_name=REPLACE(route_short_name, '"', '')
	--run this after the update process runs to set a bit indicating which stops are LRT stations
	UPDATE vsd.ETS_stops SET is_lrt=1
	WHERE stop_id IN (
		SELECT s.stop_id
		FROM vsd.ETS_stop_times stime
		JOIN vsd.ETS_trips t ON t.trip_id=stime.trip_id
		JOIN vsd.ETS_calendar_dates c ON c.service_id=t.service_id
		JOIN vsd.ETS_stops s ON stime.stop_id=s.stop_id
		JOIN vsd.ETS_routes r ON r.route_id=t.route_id
		WHERE r.route_type=0
		GROUP BY s.stop_id
	)	
</cfquery>


<p>GTFS Data has been updated.</p>