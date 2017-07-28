<cfset PageTitle="Edmonton LRT Schedule">
<cfset PageTitleHead="LRT Schedule" />

<!--- Toggle Dark Mode --->
<cfif isDefined('url.dark')>
	<cfif url.dark IS 1>
		<cfset session.dark=true />
	<cfelseif url.dark IS 0>
		<cfset session.dark=false />
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
<body>
	<div class="container clearfix">
	<!--- If a sidebar is defined, it will be inserted here --->

	<div class="page w2Contents">
	<!-- Page contents go below here -->
    

  
    <cfoutput><cfif len(PageTitle)><div class="pageTitle">#PageTitle#</div></cfif></cfoutput>



<style>

	.w2Form input, .w2Form textarea, .w2Form select {
    	font-size: 16px;
	}

	.pageTitle {
		font-size:24px;
	}

	.w2Form label, .w2Form .formItem {
    	/*line-height:2.5em;*/
	}

	div#timeLabel {
		padding-top:5px;
	}

	#timeLabelText {
		text-align: left;
		margin-top:5px;
		color:black;
		text-decoration: none;
	}

	#nowLink {
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

	.departures {
		margin-top:20px;
	}

	.departures table {
		margin:0;
		font-size:17px;
	}

	.nowrap {
		white-space:nowrap;
	}

	#swapButtonLabel {
		padding-top:14px;
		margin-bottom:11px;
	}

	#swapFromTo {
		font-size:14px;
		padding:0px;
	}

	#nightModeLink {
		text-align:center;
		font-size:13px;
		margin:5px;
	}

	#nightModeLink a {
		color:#555;
		text-decoration: none;
	}

	@media (max-width: 450px) {
		.pageTitle {
			text-align: center;
		}
		.departures table {
			width:100%;
		}

		#swapFromTo {
			width:50%;
			padding:0 20px;
		}

	#swapButtonLabel {
		display:flex;
		justify-content:center;
		margin-bottom:8px;
	}

		label#forLabel,
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

	.arrivalTime,
	.countdown {
		min-width:80px;
	}

	.arrivalTime {
		font-weight:bold;
	}

	.due {
		color:green;
		font-weight:bold;
	}

	.gone {
		color:#770000;
		font-weight:bold;
	}


	<cfif isDefined('session.dark') and session.dark IS true>
	/* Dark Mode styles for Night */
		body {
			background-color:#222;
			color:#ccc;
		}
		
		.pageTitle, #nowLink {
			color:rgb(126, 164, 241);
		}

		.w2Contents {
			background-color:#111;
		}

		#timeLabelText {
			color:#ccc;
		}

		.altRow {
			background-color: rgb(40, 40, 40);
		}

		.altColors tr:nth-child(even){
			background-color:rgb(40, 40, 40);
		}

		.altColors tr:nth-child(odd){
			background-color:rgb(0, 0, 0);
		}

		select {
			/*-webkit-appearance:none;*/
			padding:3px; /* Needed for mobile safari to make the dropdowns not too tiny */
			color:white;
			background-color:black;
			background-image:linear-gradient(to bottom, rgba(100,100,100,0.45) 0%,rgba(0,0,0,0) 100%);
		}

		input {
			background-color:black;
			color:#ddd;
		}

		input[type="button"] {
			background-image:linear-gradient(to bottom, rgba(100,100,100,0.45) 0%,rgba(0,0,0,0) 100%);
		}

		.due {
			color:#00A000;
		}
		.gone {
			color:#CC0000;
		}
	</cfif>

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

<label for="from" style="margin-bottom:0;">Departing From
	<select name="from" id="from">
		<cfoutput query="Stations">
			<option value="#StationID#" <cfif isDefined('url.from') AND url.from IS StationID>selected</cfif>>#StationName#</option>
		</cfoutput>
	</select>
</label>

<label for="swap" id="swapButtonLabel">
	<input type="button" id="swapFromTo" value="&#8593; swap &#8595;" />
</label>

<label for="to" id="forLabel">Travelling To
	<select name="to" id="to">
		<cfoutput query="Stations">
			<option value="#StationID#" <cfif isDefined('url.to') AND url.to IS StationID>selected<cfelseif NOT isDefined('url.to') AND StationID IS 15>selected</cfif>>#StationName#</option>
		</cfoutput>
	</select>
</label>

<div class="formItem" id="timeLabel"><a href="javascript:void(0);" id="timeLabelText">Time <span id="nowLink">Reset</span></a>
	<span class="formGroup" id="timeGroup">
	<select name="time" id="time" style="width:calc(50% - 15px);margin-right:10px">
		<option value="">Now</option>
		<cfloop from="5" to="23" index="hour"><cfoutput>
			<option value="#hour#:00" <cfif isDefined('url.time') AND url.time IS "#hour#:00">selected</cfif>>#timeFormat(hour&":00", "h:mm tt")#</option>
		</cfoutput></cfloop>
		<option value="00:00" <cfif isDefined('url.time') AND url.time IS "00:00">selected</cfif>>11:59 PM</option>
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
<cfinclude template="departureTimes.cfm" />

</div><!--departures-->
<p style="font-size:13px;color:#555;"><b>Note:</b> Times may vary by 2 minutes.</p>
<script>

// loads new departure times via ajax
function refreshDepartureTimes() {
	var fromVal = $('#from').val();
	var toVal = $('#to').val();
	var timeVal = $('#time').val();
	var dowVal = $('#dow').val();
	if (dowVal.length > 0 || timeVal.length > 0) $('#nowLink').show();
	else $('#nowLink').hide();

	$.get('departureTimes.cfm', {from:fromVal, to:toVal, time:timeVal, dow:dowVal}).done(function(data) {
		$('#departures').html(data);
		// update page URL so that you get the same data if you hit refresh
		window.history.pushState("", "LRT Schedule", "?from="+fromVal+"&to="+toVal+"&time="+timeVal+"&dow="+dowVal);
		// Refresh the arrival times so they don't go blank for a couple seconds
		updateArrivalTimes();
	});

}

$('#fromToForm select').change(function(){
	refreshDepartureTimes();
})

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
	$('.arrivalTime').each(function() {
		var thisTime = $(this).html();
		//Here are a bunch of hacks to get Safari to create a valid date
		var thisDate = $(this).attr('data-datetime').replace('-', '/');
		thisDate = thisDate.replace('-', '/');
		thisDate = thisDate.replace('.0', '');

		var date1 = new Date(thisDate)
		var dateNow = new Date();
		var day = 1;
		if (dateNow.getHours() < 4) day++;
		var date2 = new Date("1900/01/"+day+" "+dateNow.getHours()+":"+dateNow.getMinutes()+":"+dateNow.getSeconds())

		var secondsToDeparture = (date1-date2)/1000;

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
		
		// $(this).next().html(secondsToDeparture);
		$(this).next().html(timeString);

	});
}

// Show some kind of countdown - minutes and seconds until arrival
updateArrivalTimes();
setInterval(function(){updateArrivalTimes();}, 2000);


</script>





<!-- Page contents go above here -->
</div><!--.page .w2Contents-->
</div><!--.container .clearfix-->
<p id="nightModeLink">
	<cfif isDefined('session.dark') AND session.dark IS true>
		<a href="?dark=0">&#x2600; Day Mode</a>
	<cfelse>
		<a href="?dark=1"><!--&#x1F31C; -->Night Mode</a>
	</cfif>
</p>

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