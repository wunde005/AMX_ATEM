# AMX_ATEM

Include file that contains the main ATEM switcher code
- ATEM Switcher.axi

It has only been tested with an ATEM Television Studio.
This code is a port of the Blackmagic Design ATEM Client library for Arduino by
Kasper Skårhøj, SKAARHOJ K/S, kasper@skaarhoj.com 
https://github.com/kasperskaarhoj/SKAARHOJ-Open-Engineering/tree/master/ArduinoLibs
	
Touch panel demo:
- ATEM Switcher Demo.axs
- ATEM Demo.TP4 (for an MST-701)

Panel looks simlar to the ATEM Software Control system and supports selecting inputs for program and preview along with cutting.  It will also display the the switchers model, version, ip address and output resolution along with the short names for the inputs.

DGX style switching of a ATEM Television Studio using M2M virtual device communication
- ATEM Switcher-dgx.axs

Supports some of the DGX switching commands:
- CI\<input\>O\<output\>
- ?MODEL
- ?OUTPUT-VIDEO
- ?VIDOUT_RES_REF
- ?ATEM:ONLINE
- ATEM:ONLINE
- ATEM:OFFLINE
- ?VIDIN_NAME


