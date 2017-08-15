@echo off
C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\stop_times.txt > C:\inetpub\temp\gtfs\stop_times_noheader.txt

C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\shapes.txt > C:\inetpub\temp\gtfs\shapes_noheader.txt

C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\trips.txt > C:\inetpub\temp\gtfs\trips_noheader.txt

C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\calendar_dates.txt > C:\inetpub\temp\gtfs\calendar_dates_noheader.txt

C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\stops.txt > C:\inetpub\temp\gtfs\stops_noheader.txt

C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\transfers.txt > C:\inetpub\temp\gtfs\transfers_noheader.txt

C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\routes.txt > C:\inetpub\temp\gtfs\routes_noheader.txt

C:\Windows\System32\findstr.exe /V /R "^[a-z].*[a-z]$" C:\inetpub\temp\gtfs\agency.txt > C:\inetpub\temp\gtfs\agency_noheader.txt