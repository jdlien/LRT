<!doctype html>
<html lang="en">
<head>
    <title>Using the scripts in web pages</title>
    <meta charset="utf-8">
    <script defer src="latlon-spherical.min.js"></script>
    <script defer src="dms.min.js"></script>
</head>
<body>
    <form>
        Lat 1: <input type="text" name="lat1" id="lat1">
        Lon 1: <input type="text" name="lon1" id="lon1">
        Lat 2: <input type="text" name="lat2" id="lat2">
        Lon 2: <input type="text" name="lon2" id="lon2">
        <button type="button" id="calc-dist">Calculate distance</button>
        <output id="result-distance"></output> metres
    </form>

<script>
        document.addEventListener('DOMContentLoaded', function() {
            document.querySelector('#calc-dist').onclick = function() {
                const lat1 = document.querySelector('#lat1').value;
                const lon1 = document.querySelector('#lon1').value;
                const lat2 = document.querySelector('#lat2').value;
                const lon2 = document.querySelector('#lon2').value;
                const p1 = new LatLon(Dms.parseDMS(lat1), Dms.parseDMS(lon1));
                const p2 = new LatLon(Dms.parseDMS(lat2), Dms.parseDMS(lon2));
                const dist = parseFloat(p1.distanceTo(p2).toPrecision(4));
                document.querySelector('#result-distance').textContent = dist;
            }
        });

function getLocation() {
    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(showPosition);
    }
}

function showPosition(position) {
    var lat = position.coords.latitude
    var lon = position.coords.longitude;
    document.getElementById('lat1').value=lat;
    document.getElementById('lon1').value=lon;
    document.getElementById('lat2').value=lat+1;
    document.getElementById('lon2').value=lon+1;    
}
</script>
</body>


</html>