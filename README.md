# PowerTelemetry
Open source and minimal AHK v2 script. This script displays basic telemetry including power source, raw charge/discharge rates in milliwatts, voltage, time remaining and calculated battery health degradation. Designed to work on windows with AHK v2.

# Installation & Setup
(THIS SCRIPT CAN ONLY RUN ON WINDOWS AS IT RELIES ON WINDOWS' ARCHITECTURE)

*Using the compiled .exe file:

Download PowerTelemetry with the .exe extension and run it without AHK v2 installed.


*Using Autohotkey v2:

To run this script natively from source, you must have AutoHotkey v2 installed on your system.

Download and install AHK v2 from [the Official AutoHotkey Website](https://www.autohotkey.com/)
then you can download the .ahk file and run it directly.



# Troubleshooting
On certain hardware configurations (or specific virtualized environments), the battery controller driver may block raw WMI telemetry queries. If this happens, metrics like Battery Health or Net Flow Rate will fallback and read Driver Restricted or N/A. If this happens, please open an issue query and I'll look into it.
