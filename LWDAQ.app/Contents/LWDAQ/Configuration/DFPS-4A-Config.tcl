# DFPS-4A LWDAQ Configuration Script 
# (C) 2024 Kevan Hashemi, Open Source Instruments Inc.
#
# Place in the LWDAQ Configuration Directory.

# Open the DFPS_Manager
LWDAQ_run_tool DFPS_Manager.tcl Standalone

# Open, configure and start the System Server.
set LWDAQ_Info(server_address_filter) "127.0.0.1"
set LWDAQ_Info(server_listening_port) "1090"
set LWDAQ_Info(server_mode) "execute"
LWDAQ_server_start



