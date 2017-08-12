<cfset opType="LRT Schedule" />
<cfif isDefined('url.fromStop')><cfset opType="Bus Stop Schedule" />
<cfelseif isDefined('url.rid')><cfset opType="Bus Routes" />
</cfif>
<cfset PageTitle="Edmonton #opType#">
<cfset PageTitleHead="#opType#" />

<!--- Toggle Dark Mode --->
<cfif isDefined('url.dark')>
	<cfif url.dark IS 1>
		<cfcookie name="LRT_DARK" value="true" expires="never" />
	<cfelseif url.dark IS 0>
		<cfcookie name="LRT_DARK" value="false" expires="never" />
	</cfif>
</cfif>


<cfif cgi.SCRIPT_NAME contains "EXEC(" OR cgi.PATH_INFO contains "EXEC(" OR cgi.QUERY_STRING contains "EXEC("><cfabort></cfif>

<!--- Actual HTML Page Begins --->
<!DOCTYPE html>	
<html>
<head>
	<meta http-equiv="x-ua-compatible" content="IE=Edge" />
	<meta charset="UTF-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0" />
	<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
	<!--- Geo calculation stuff --->
	<script defer src="latlon-spherical.min.js"></script>
    <script defer src="dms.min.js"></script>

	<script src="/Javascript/selectize/dist/js/standalone/selectize.min.js"></script>

	<link rel="shortcut icon" type="image/x-icon" href="/favicon.ico" />
	<link rel="icon" type="image/png" href="/favicon.png" />
	<link rel="apple-touch-icon" sizes="180x180" href="touch-icon-iphone-retina.png" />
	<link rel="apple-touch-icon" sizes="167x167" href="touch-icon-ipad-retina.png" />

	<!--- Custom Stylesheet for www2.epl.ca --->
	<link rel="stylesheet" href="/w2.css" type="text/css"/>

	<title><cfoutput>#PageTitleHead#</cfoutput></title>

	<style>
		body {
			font-family: "Open Sans",sans-serif;
			background-color: #cccac8;
			margin:5px;
		}
	</style>


</head>
<body class="<cfif isDefined('cookie.lrt_dark') and cookie.lrt_dark IS true>darkMode</cfif>">
	<div class="container clearfix">
	<!--- If a sidebar is defined, it will be inserted here --->

	<div class="page w2Contents">
	<!-- Page contents go below here -->
    
	<link href="/Javascript/selectize/dist/css/selectize.css" type="text/css" rel="stylesheet" />
  
    <cfoutput><cfif len(PageTitle)><div class="pageTitle">#PageTitle#</div></cfif></cfoutput>



<style>
	select {
		/*-webkit-appearance:none;*/
		padding:4px 6px; /* Needed for mobile safari to make the dropdowns not too tiny */
	}



	/* Style to handle selectize dropdowns */
	.w2Form .selectizeLabel * {
		float:none;
	}

	.selectizeLabel {
		min-height:30px;
	}

	.selectizeLabel .selectize-input {
		font-size:16px;
		font-weight:normal;
	}

	.selectize-dropdown, .selectize-input, .selectize-input input {
		font-size:14px;
		font-weight:normal;
	}

	.selectize-dropdown [data-selectable] .highlight {
    	background: rgba(255, 255, 50, 0.3);
    }

	.selectize-control.multi .selectize-input > div {
			border-radius:4px;
			border:1px solid #AAA;
		}

	.selectize-control.multi .selectize-input > div.active {
			background-color:#DDD;
			color:black;
			border-width:1px;
			border-color:#999;
		}


	.selectize-dropdown-content .selected {
		/*background-color:inherit;*/
		text-decoration:none;
		color:inherit;
		box-shadow:none;
		-webkit-box-shadow:none;
	}

	.w2Form input,
	.w2Form button,
	.w2Form textarea,
	.w2Form select {
    	font-size: 16px;
    	border:1px solid #555;
	}

	.w2Form>label+label,
	.w2Form>label+.formItem,
	.w2Form>.formItem+.formItem,
	.w2Form>.formItem+label,
	.sectionContents>label+label {
    	padding-top: 0px;
	}

	#swapButtonLabel {
		margin-top:20px;
	}

	input[type="button"], button {
		border: solid 1px black;
		border-radius:5px;
		background-image:linear-gradient(to bottom, rgba(255,255,255,1) 0%,rgba(220,220,220,1) 100%);
	}

	.pageTitle {
		font-size:24px;
	}

	.w2Form label, .w2Form .formItem {
    	/*line-height:2.5em;*/
	}

	.w2Form label {
		overflow:auto;
	}
	
	.w2Form label.selectizeLabel {
		overflow:visible;
		/*display:block;*/
	}

	.leg {
		margin-bottom:1px;
	}

	.leg .smaller {
		font-size:18px;
	}
	
	.trainsFromTo {
		margin:8px 0px 6px 0px;
		font-size:18px;
		text-align:center;
	}
	.tripTime {
		margin-top:2px;
		font-weight:normal;
		font-size:17px;
	}	

	div#timeLabel {
		padding-top:5px;
	}

	#timeLabelText, #departLabelText {
		text-align: left;
		margin-top:5px;
		color:black;
		text-decoration: none;
	}

	a {
		text-decoration: underline;
		color:#0A2D75;
	}

	#nowLink, #nearestLink {
		font-size:13px;
		text-decoration: underline;
		color:#0A2D75;
		font-weight:normal;
		<cfif (isDefined('url.time') AND len(url.time))
		OR (isDefined('url.dow') AND len(url.dow))>
		display:inline;
		<cfelse>
		display:none;
		</cfif>
	}
	
	#nearestLink {
		display:none;
	}


	.departures {
		margin-top:20px;
		max-width:400px;
	}


	.departures table {
		margin:0;
		font-size:17px;
		width:400px;
	}

	.altColors tr {
		background-color: #fff;
	}

	.altColors tr:nth-child(4n+3){
		background-color:rgb(236, 236, 236);
	}
	.altColors tr:nth-child(4n+2){
		background-color:rgb(255, 255, 255);
	}
	.altColors tr:nth-child(4n+4){
		background-color:rgb(236, 236, 236);
	}	

	.departures table thead th {
		padding:3px 3px;
		font-size:15px;
		/*color:#555;*/
		/*opacity:0.5;*/
		/*font-weight:normal;*/
		background-color: rgb(236, 236, 236);
	}

	.departures table td {
		font-size:17px;
	}

	.nowrap {
		white-space:nowrap;
	}



	#swapFromTo, #swapRouteFromTo {
		font-size:13px;
		padding:1px 2px 2px 2px;
	}

 	#swapRouteFromTo {
		text-align: center;
		float:none;
		margin:0 auto;
	}

	#nightModeLink {
		text-align:center;
		font-size:13px;
		margin:15px;
	}

	#nightModeLink a {
		color:#555;
		text-decoration: none;
	}

	@media (max-width: 450px) {
		#nearestLink {
			display:inline;
			margin-left:6px;
		}

		.pageTitle {
			text-align: center;
		}
		.departures table {
			width:100%;
		}

		#swapFromTo, #swapRouteFromTo {
			width:50%;
			padding:1px 10px 2px 10px;
		}

		#swapButtonLabel {
			display:flex;
			justify-content:center;
			margin-bottom:8px;
		}

		label#toLabel,
		div#timeLabel {
			padding-top:0;
		}

		div#timeLabel {
			display:flex;
			justify-content:space-between;
		}

		#timeGroup {
			width:auto;
		}


	}

	.arrivalTime, .aT,
	.countdown, .cD {
		min-width:80px;
		white-space:nowrap;
	}

	.arrivalTime, .aT {
		font-weight:bold;
	}

	.trainName, .tN {

	}

	.due {
		color:green;
		font-weight:bold;
	}

	.gone {
		color:#770000;
		font-weight:bold;
	}

	#geoIcon {
		width:13px;
		height:12px;
	}

	#geoIcon path {
		fill:#0A2D75;
	}

	tr.destRow, tr.dR {
		display:none;
	}

	table td.destArrival,
	table td.dA {
		opacity:0.75;
		font-size:15px;
		text-align: center;
		padding-bottom:8px;
		padding-top:2px;
	}

	.opMode {
		margin-top:5px;
		display:flex;
		justify-content:space-around;
		max-width:400px;
		flex-wrap:wrap;

	}

	.opMode a, .opMode span {
		white-space:nowrap;
		padding:4px 5px;
		text-decoration: none;
	}

	.selectedMode {
		text-decoration: none;
		color:black;
		background-color:rgba(0,0,0,.1);
		border-radius:4px;
	}

	/* Dark Mode styles for Night */
		body.darkMode {
			background-color:#222;
			color:#ccc;
		}
		
		.darkMode .selectedMode {
			color:rgb(193, 211, 250);
			background-color:rgba(255,255,255,.1);			
		}

		.darkMode .pageTitle,
		.darkMode #nowLink,
		.darkMode #nearestLink {
			color:rgb(126, 164, 241);
		}

		.darkMode a {
			color:rgb(126, 164, 241);
		}

		.darkMode .w2Contents {
			background-color:#111;
		}

		.darkMode #timeLabelText, 
		.darkMode #departLabelText {
			color:#ccc;
		}

		.darkMode .altRow {
			background-color: rgb(40, 40, 40);
		}
		.darkMode .departures table thead th {
			/*color:#888;*/
			background-color:rgb(40, 40, 40);
		}

		.darkMode .altColors tr {
			background-color: #000;
		}

		.darkMode .altColors tr:nth-child(4n+3){
			background-color:rgb(40, 40, 40);
		}

		.darkMode .altColors tr:nth-child(even){
			/*background-color:rgb(40, 40, 40);*/
		}

		.darkMode .altColors tr:nth-child(4n+2){
			background-color:rgb(0, 0, 0);
		}
		.darkMode .altColors tr:nth-child(4n+4){
			background-color:rgb(40, 40, 40);
		}		

		.darkMode .w2Form input,
		.darkMode .w2Form button,
		.darkMode .w2Form textarea,
		.darkMode .w2Form select {
	    	border:1px solid #888;
		}

		.darkMode select {
			/*-webkit-appearance:none;*/
			padding:4px 6px; /* Needed for mobile safari to make the dropdowns not too tiny */
			color:white;
			background-color:black;
			background-image:linear-gradient(to bottom, rgba(100,100,100,0.45) 0%,rgba(0,0,0,0) 100%);
		}

		.darkMode .selectize-input {
			background-color:black;
			background-image:linear-gradient(to bottom, rgba(100,100,100,0.45) 0%,rgba(0,0,0,0) 100%);
			border:1px solid #888;
		}

		.darkMode .selectize-control.single .selectize-input.input-active {
			background: black;
		}

		.darkMode .selectize-dropdown {
			color:white;
			background-color:black;
			border-color: #888;
		}

		.darkMode .selectize-dropdown, .darkMode .selectize-input, .darkMode .selectize-input input {
			color:white;
		}

		.darkMode .selectize-dropdown .active {
			background-color:#555;
			color: white;
		}

		.darkMode .selectize-control.multi .selectize-input > div {
			background-color:#111;
			color:white;
			border-color:#333;
		}

		.darkMode .selectize-control.multi .selectize-input > div.active {
			background-color:#555;
			color:white;
			border-color:#777;
		}

		.darkMode .selectize-control.multi .selectize-input > div.active.selected {
			color:white;
		}

		.darkMode .selectize-dropdown-content .selected {
			background-color:black;
		}

		.darkMode .selectize-dropdown-content .selected.active {
			background-color:#555;
		}

		.darkMode input, 
		.darkMode button {
			background-color:black;
			color:#ddd;
		}

		.darkMode input[type="button"],
		.darkMode button {
			background-image:linear-gradient(to bottom, rgba(100,100,100,0.45) 0%,rgba(0,0,0,0) 100%);
		}


		.darkMode .due {
			color:#00A000;
		}
		.darkMode .gone {
			color:#CC0000;
		}

		.darkMode #geoIcon path {
			fill:rgb(126, 164, 241);
		}

		.darkMode .debug {
			border:1px solid gray;
			border-collapse:collapse;
		}

		.darkMode .debug td {
			border:1px solid gray;	
		}

		.darkMode .dowCell {
			padding:0 2px!important;
			text-align: center;
		}
	/* End darkMode styles */


</style>

<!--- The most basic operation of this app will let you select a source and destination station
	and a Day and Time and it will show you the next times a train will stop there --->

<cfparam name="url.from" default="1">
<cfparam name="url.to" default="15">

<cfquery name="Stations" dbtype="ODBC" datasource="SecureSource">
	SELECT * FROM vsd.EZLRTStations
	ORDER BY CostFromOrigin
</cfquery>


<form class="w2Form" id="fromToForm">

<cfif isDefined('url.fromStop')>
<!--- 6500 stops! --->
<cfquery name="Stops" dbtype="ODBC" datasource="SecureSource">
	SELECT * FROM vsd.ETS_stops
</cfquery>
<!--- This makes for a massive 6500 item select --->
<label for="fromStop" id="fromStopLabel" class="selectizeLabel"><a href="javascript:void(0);" id="departLabelText" title="Click to sort stops based on your location">Bus Stops <svg id="geoIcon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 900"><path d="M500 258.6l-490 245 9.6 1.2c5.2.5 107 8.2 226 16.8 133 9.8 217.5 16.5 218.8 18 1.2 1.2 8.3 87 18 219.6 8.5 119.7 16.4 221.3 17 226 1.3 7.7 6.3-1.8 246-482 135-269.4 245-490 244.6-489.7l-490 245z" /></svg><span id="nearestLink">Set Nearest Four Stops</span></a>
	<select name="fromStop" id="fromStop" class="selectizeField" multiple="multiple">
		<cfoutput query="Stops">
			<option value="#stop_id#" <cfif listContains(url.fromStop, stop_id)>selected</cfif>>#stop_id# #stop_name#</option>
		</cfoutput>
	</select>
</label>


<!--- If url.rid is specified, we show the interface for selecting a route --->
<cfelseif isDefined('url.rid')>

<cfquery name="Routes" dbtype="ODBC" datasource="SecureSource">
	SELECT * FROM vsd.ETS_routes ORDER BY route_id
</cfquery>
<!--- This makes for a massive 6500 item select --->
<label for="rid" id="ridLabel" class="selectizeLabel">Bus Route
	<select name="rid" id="rid" class="selectizeField">
		<option></option>
		<cfoutput query="Routes">
			<option value="#route_id#" <cfif url.rid IS route_id>selected</cfif>>#route_id# #route_long_name#</option>
		</cfoutput>
	</select>
</label>

<label for="routeFrom" id="routeFromLabel" class="selectizeLabel">Departing From
	<select name="routeFrom" id="routeFrom" class="selectizeField">
	</select>
</label>

<label for="swapRouteFromTo" id="swapButtonLabel">
	<button type="button" id="swapRouteFromTo">&#8593; swap &#8595;</button>
</label>

<label for="routeTo" id="routeToLabel" class="selectizeLabel">Travelling To
	<select name="routeTo" id="routeTo" class="selectizeField">
	</select>
</label>




<cfelse>


<label for="from" style="margin-bottom:0;"><a href="javascript:void(0);" id="departLabelText" title="Click to set based on your location">Departing From <svg id="geoIcon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 900"><path d="M500 258.6l-490 245 9.6 1.2c5.2.5 107 8.2 226 16.8 133 9.8 217.5 16.5 218.8 18 1.2 1.2 8.3 87 18 219.6 8.5 119.7 16.4 221.3 17 226 1.3 7.7 6.3-1.8 246-482 135-269.4 245-490 244.6-489.7l-490 245z" /></svg><span id="nearestLink">Set Nearest</span></a>
	<select name="from" id="from">
		<cfoutput query="Stations">
			<option value="#StationID#" <cfif isDefined('url.from') AND url.from IS StationID>selected</cfif>>#StationName#</option>
		</cfoutput>
	</select>
</label>

<label for="swap" id="swapButtonLabel">
	<button type="button" id="swapFromTo">&#8593; swap &#8595;</button>
</label>

<label for="to" id="toLabel">Travelling To
	<select name="to" id="to">
		<cfoutput query="Stations">
			<option value="#StationID#" <cfif isDefined('url.to') AND url.to IS StationID>selected<cfelseif NOT isDefined('url.to') AND StationID IS 15>selected</cfif>>#StationName#</option>
		</cfoutput>
	</select>
</label>

</cfif><!---if not in bus stop mode --->

<div class="formItem" id="timeLabel"><a href="javascript:void(0);" id="timeLabelText">Time <span id="nowLink">Reset</span></a>
	<span class="formGroup" id="timeGroup">
	<select name="time" id="time" style="width:calc(50% - 15px);margin-right:10px">
		<option value="">Now</option>
		<!--- <option value="1:00" <cfif isDefined('url.time') AND url.time IS "1:00">selected</cfif>>1:00 AM</option> --->
		<cfloop from="5" to="23" index="hour"><cfoutput>
			<option value="#hour#:00" <cfif isDefined('url.time') AND url.time IS "#hour#:00">selected</cfif>>#timeFormat(hour&":00", "h:mm tt")#</option>
		</cfoutput></cfloop>
		<!--- This special option ensures we are using the same day to prevent ambiguity --->
		<option value="23:59" <cfif isDefined('url.time') AND url.time IS "23:59">selected</cfif>>11:59 PM</option>
	</select>

	<select name="dow" id="dow" style="width:50%">
		<option value="">Today</option>
		<cfloop from="1" to="7" index="day"><cfoutput>
			<option value="#Left(DayOfWeekAsString(day),3)#" <cfif isDefined('url.dow') AND url.dow IS Left(DayOfWeekAsString(day),3)>selected</cfif>>#DayOfWeekAsString(day)#</option>
		</cfoutput></cfloop>
	</select>
	</span><!--.formGroup-->

</div><!--timeLabel-->

<label class="formSubmit" style="display:none;">
	<input type="submit" value="Show Departure Times" />
</label>



</form>

<div class="departures" id="departures">
<!--- this is where the tables will go --->
<cfif isDefined('url.fromStop')>
	<cfinclude template="stopTimesGTFS.cfm" />	
<cfelseif isDefined('url.rid')>
	<cfinclude template="departureTimesRoutesGTFS.cfm" />
<cfelse>
	<cfinclude template="departureTimesGTFS.cfm" />
</cfif>

</div><!--departures-->
<p style="font-size:13px;color:#555;"><b>Note:</b> Times may vary by 2 minutes.</p>


<div class="opMode">
<cfoutput>

<cfif NOT isDefined('url.fromStop') AND NOT isDefined('url.rid')>
	<span class="selectedMode" href="?">LRT Schedule</span>
<cfelse>
	<a href="?">LRT Schedule</a>
</cfif>

<cfif isDefined('url.fromStop')>
	<span class="selectedMode">Bus Stop Times</span>	
<cfelse>
	<a href="?fromStop">Bus Stop Times</a>	
</cfif>

<cfif isDefined('url.rid')>
	<span class="selectedMode">Bus Routes</span>
<cfelse>
	<a href="?rid">Bus Routes</a>
</cfif>

</cfoutput>
</div>


<!-- Page contents go above here -->
</div><!--.page .w2Contents-->
</div><!--.container .clearfix-->


<p id="nightModeLink">
	<cfif isDefined('cookie.lrt_dark') AND cookie.lrt_dark IS true>
		<a href="javascript:void(0);">&#x2600; Day Mode</a>
	<cfelse>
		<a href="javascript:void(0);"><!--&#x1F31C; -->Night Mode</a>
	</cfif>
</p>


<script>


// loads new departure times via ajax
function refreshDepartureTimes() {
	var fromVal = $('#from').val();
	var toVal = $('#to').val();
	var timeVal = $('#time').val();
	var dowVal = $('#dow').val();
	if (dowVal.length > 0 || timeVal.length > 0) $('#nowLink').show();
	else $('#nowLink').hide();

	$.get('departureTimesGTFS.cfm', {from:fromVal, to:toVal, time:timeVal, dow:dowVal<cfif isDefined('url.destTime')>, destTime:true</cfif>}).done(function(data) {
		$('#departures').html(data);
		// update page URL so that you get the same data if you hit refresh
		window.history.pushState("", "LRT Schedule", "?from="+fromVal+"&to="+toVal+"&time="+timeVal+"&dow="+dowVal<cfif isDefined('url.destTime')>+"&destTime"</cfif>);
		// Refresh the arrival times so they don't go blank for a couple seconds
		updateArrivalTimes();
		bindShowArrival();
	});
}

// loads new bus stop times via ajax
function refreshStopTimes() {
	var fromStop = $('#fromStop').val();
	var timeVal = $('#time').val();
	var dowVal = $('#dow').val();
	if (dowVal.length > 0 || timeVal.length > 0) $('#nowLink').show();
	else $('#nowLink').hide();

	$.ajax('stopTimesGTFS.cfm', { data:{fromStop:fromStop, time:timeVal, dow:dowVal}, traditional:true}).done(function(data) {
		$('#departures').html(data);
		// update page URL so that you get the same data if you hit refresh
		window.history.pushState("", "Bus Stop Schedule", "?fromStop="+fromStop+"&time="+timeVal+"&dow="+dowVal);
		// Refresh the arrival times so they don't go blank for a couple seconds
		updateArrivalTimes();
		// bindShowArrival();
	});

}

//signals brand new load... feels like a crappy hack
var newLoad = true;

// Updates the dropdowns for from/to stops for a route
function refreshRouteStops() {
	$.get('routeStops.cfm', {rid:$('#rid').val()}).done(function(data) {
		// remove existing options
		// $('#routeFrom, #routeTo').html('');
		routeFromSelectize.clearOptions();
		routeToSelectize.clearOptions();

		routeFromSelectize.addOption(data);
		routeToSelectize.addOption(data);
		// $('#routeFrom, #routeTo').append('<option></option>');
		//Loop through data field and add an option for each
		// $.each(data.DATA, function(i, value) {
		// 	$('#routeFrom, #routeTo').append('<option value="'+data.DATA[i][0]+'">'+data.DATA[i][0]+' '+data.DATA[i][1]+'</option>');
		// });



		// $('#routeFrom').selectize({highlight:false});
		if (newLoad) {
		<cfif isDefined('url.routeFrom') AND isNumeric(url.routeFrom)>
			routeFromSelectize.addItem(<cfoutput>#url.routeFrom#</cfoutput>,true);
		</cfif>
		<cfif isDefined('url.routeTo') AND isNumeric(url.routeTo)>
			routeToSelectize.addItem(<cfoutput>#url.routeTo#</cfoutput>,true);
			refreshRouteToStops(<cfoutput>#url.routeTo#</cfoutput>);
		<cfelse>
			refreshRouteToStops();
		</cfif>
			newLoad=false;

			// I think I just need to do this on page load...
			refreshRouteDepartureTimes();
		}

	});
}

function refreshRouteToStops(stopId) {
	var routeFrom = $('#routeFrom').val();
	$.get('routeStops.cfm', {rid:$('#rid').val(), routeFrom:routeFrom}).done(function(data) {
		routeToSelectize.clearOptions();
		routeToSelectize.addOption(data);

		if (stopId) {
			routeToSelectize.addItem(stopId);
		}

	});
}

// loads new route stops into routeFrom/routeTo dropdowns when route is changed
$('#rid').change(function() {
	refreshRouteStops();
});

$('#routeFrom').change(function(){
	refreshRouteToStops();
});

$('#routeFrom, #routeTo').change(function(){
	refreshRouteDepartureTimes();
});


// loads new departure times via ajax
function refreshRouteDepartureTimes() {
	var fromVal = $('#routeFrom').val();
	var toVal = $('#routeTo').val();
	var timeVal = $('#time').val();
	var dowVal = $('#dow').val();
	var rid = $('#rid').val();
	if (dowVal.length > 0 || timeVal.length > 0) $('#nowLink').show();
	else $('#nowLink').hide();

	$.get('departureTimesRoutesGTFS.cfm', {rid:rid, from:fromVal, to:toVal, time:timeVal, dow:dowVal<cfif isDefined('url.destTime')>, destTime:true</cfif>}).done(function(data) {
		$('#departures').html(data);
		// update page URL so that you get the same data if you hit refresh
		window.history.pushState("", "Bus Route Schedule", "?rid="+rid+"&routeFrom="+fromVal+"&routeTo="+toVal+"&time="+timeVal+"&dow="+dowVal<cfif isDefined('url.destTime')>+"&destTime"</cfif>);
		// Refresh the arrival times so they don't go blank for a couple seconds
		updateArrivalTimes();
		bindShowArrival();
	});
}






$('#from, #to').change(function(){
	refreshDepartureTimes();
});

$('#fromStop').change(function(){
	refreshStopTimes();
});

<cfif isDefined('url.fromStop')>
$('#time, #dow').change(function(){
	refreshStopTimes();
});
<cfelseif isDefined('url.rid')>
$('#time, #dow').change(function(){
	refreshRouteDepartureTimes();
});
<cfelse>
$('#time, #dow').change(function(){
	refreshDepartureTimes();
});

</cfif>




$('#swapFromTo').click(function(){
	var fromVal = $('#from').val();
	var toVal = $('#to').val();
	$('#to').val(fromVal);
	$('#from').val(toVal);

	refreshDepartureTimes();
});


$('#timeLabelText').click(function(){
	$('#time').val('');
	$('#dow').val('').trigger('change');
});


function updateArrivalTimes() {
	$('.aT').each(function() {
		var thisTime = $(this).html();
		//Here are a bunch of hacks to get Safari to create a valid date
		var thisDate = $(this).attr('data-datetime').replace('-', '/');
		thisDate = thisDate.replace('-', '/');
		thisDate = thisDate.replace('.0', '');

		var date1 = new Date(thisDate)
		var dateNow = new Date();
		var day = 1;


		var secondsToDeparture = (date1-dateNow)/1000;

		// Now insert the seconds into the other field
		var timeString = Math.floor(secondsToDeparture/60) + " min"
		// if (Math.floor(secondsToDeparture/60) != 1) timeString+="s";

		// Handle time over an hour
		if (secondsToDeparture/60 > 60) {
			var hoursToDeparture = Math.floor(secondsToDeparture/60/60)
			timeString = hoursToDeparture + "hr";
			// if (hoursToDeparture > 1) {
			// 	timeString += "s";
			// }
			timeString += " "+Math.floor((secondsToDeparture%3600)/60) + "min";
		}

		if (secondsToDeparture < 60) timeString = '<span class="due">Arriving</span>';

		if (secondsToDeparture < -60) timeString = '<span class="gone">Departed</span>';
		
		// Don't bother showing the timeString if we're not looking at the current day, since it's pretty irrelevant
		// and likely to just be wrong anyways.
		// if ($('#dow').val().length > 0) timeString = "";
		// $(this).next().html(secondsToDeparture);
		$(this).next().html(timeString);

	});
}

// Show some kind of countdown - minutes and seconds until arrival
updateArrivalTimes();
setInterval(function(){updateArrivalTimes();}, 2000);

// Create JS object of station coords with coldfusion query loop
var stationCoords = [
<cfset c=0><cfoutput query="Stations">
<cfif c>,</cfif>{id:#StationID#<cfloop list="#coordinates#" index="i">, <cfif c++ MOD 2 IS 0>lat<cfelse>lon</cfif>:#trim(i)#</cfloop>}
</cfoutput>];

<!--- Include a table of bus stop coordinates if relevant --->
<cfif isDefined('url.fromStop')>
	var $fromStopselect;
	var selectize;
	var stopCoords = [
	<cfoutput query="Stops">
	<cfif CurrentRow GT 1>,</cfif>{id:#stop_id#, lat:#trim(stop_lat)#, lon:#trim(stop_lon)#}
	</cfoutput>];
	$(document).ready(function() {
		// Turns out that there's a bad bug in highlighting that eats characters as you type, so we disable that
		$fromStopselect = $("#fromStop").selectize({highlight:false});
		selectize = $fromStopselect[0].selectize; // This stores the selectize object to a variable (with name 'selectize')
	});

<cfelseif isDefined('url.rid')>

$('#swapRouteFromTo').click(function(){
	var fromVal = $('#routeFrom').val();
	var toVal = $('#routeTo').val();
	if (toVal.length > 0) {
		routeFromSelectize.clear(true);
		routeToSelectize.clear(true);
		routeFromSelectize.addItem(toVal, true);
		refreshRouteToStops();
		routeToSelectize.addItem(fromVal, true);
		// Not sure what'll happen here, since the stop may not exist... likely will be blank
		refreshRouteDepartureTimes();
	}
});

var $ridselect;
var ridSelectize;
var $routeFromselect;
var routeFromSelectize;
var $routeToselect;
var routeToSelectize;
	$(document).ready(function() {
		// Turns out that there's a bad bug in highlighting that eats characters as you type, so we disable that
		$ridselect = $("#rid").selectize({highlight:false});
		ridSelectize = $ridselect[0].selectize;
		$routeFromselect = $('#routeFrom').selectize({highlight:false});
		routeFromSelectize = $routeFromselect[0].selectize;
		$routeToselect = $('#routeTo').selectize({highlight:false});
		routeToSelectize = $routeToselect[0].selectize;		
		refreshRouteStops();
		//selectize = $ridselect[0].selectize; // This stores the selectize object to a variable (with name 'selectize')
	});


</cfif>




// Experimental calculation of distance from stations
function geoDistance(lat1, lon1, lat2, lon2) {
    var p1 = new LatLon(Dms.parseDMS(lat1), Dms.parseDMS(lon1));
    var p2 = new LatLon(Dms.parseDMS(lat2), Dms.parseDMS(lon2));
    var dist = parseFloat(p1.distanceTo(p2).toPrecision(4));
    return dist;
}


function setNearestStation() {
    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(findClosestStation);
    }
}

function findClosestStation(position) {
    var userLat = position.coords.latitude;
    var userLon = position.coords.longitude;

    var closestStation="";
    var closestStop1, closestStop2, closestStop3, closestStop4 ="";

    // Default to about the furthest point on earth in meters 21,000 km
    var closestDistance="21000000";

    // Loop through all stops
    <cfif isDefined('url.fromStop')>
	stopCoords.forEach(function(stop){
		var dist=geoDistance(userLat, userLon, stop.lat, stop.lon);
		if (dist < closestDistance) {
			closestDistance=dist;
			closestStop4=closestStop3;
			closestStop3=closestStop2;
			closestStop2=closestStop1;
			closestStop1=stop.id;
		}
	});

var closeStops = new Array();
	closeStops[0] = closestStop1;
	closeStops[1] = closestStop2;
	closeStops[2] = closestStop3;
	closeStops[3] = closestStop4;


	selectize.setValue(closeStops);
	// $('#fromStop').val(closeStops);
	// $('#fromStop').trigger('change');
    <cfelse>

	// Loop through all stations 
	stationCoords.forEach(function(station){
		var dist=geoDistance(userLat, userLon, station.lat, station.lon);
		if (dist < closestDistance) {
			closestDistance=dist;
			closestStation=station.id;
		}
	});

	// If the user's closest station is the one they had set as their destination,
	// I'm going to assume they want to go back to where they came from.
	// This has to be more useful than having from and to be the same
	if ($('#to').val() == closestStation) {
		$('#to').val($('#from').val());
	}
	$('#from').val(closestStation).trigger('change');

	</cfif>
}

$('#departLabelText').click(function(){
	setNearestStation();
});


// Tapping on a row shows the hidden row beneath and hides all others
function bindShowArrival() {
	$('.departures tr').click(function(){
		if ($(this).next().is(":visible")) $(this).next().hide()
		else {
			$('.dR').hide();
			$(this).next().show();
		}
	});
}
bindShowArrival();

function setCookie(key, value) {
	var expires = new Date();
	expires.setTime(expires.getTime() + (10 * 365 * 24 * 60 * 60 * 1000));
	document.cookie = key + '=' + value + ';expires=' + expires.toUTCString();
}

function getCookie(key) {
    var keyValue = document.cookie.match('(^|;) ?' + key + '=([^;]*)(;|$)');
    return keyValue ? keyValue[2] : null;
}

function toggleDarkMode() {
	$('body').toggleClass('darkMode');
	if (getCookie('LRT_DARK') === "true") {
		setCookie('LRT_DARK', "false");
		$('#nightModeLink a').html('Night Mode');
	}
	else {
		setCookie('LRT_DARK', "true");
		$('#nightModeLink a').html('&#x2600; Day Mode');
	}
}

$('#nightModeLink a').click(function(){
	toggleDarkMode();
});

</script>







<!--- Only include Google Analytics for pages that exist. --->
<cfif NOT isDefined('error404')>

	<script>
	  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
	  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
	  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
	  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

	  ga('create', 'UA-20121585-1', 'auto', {'allowLinker': true});
	  ga('require', 'linker');
	  ga('linker:autoLink', ['epl.bibliocommons.com', 'www.epl.ca'] );
	  ga('send', 'pageview');

	</script>

</cfif>

</body>
</html>