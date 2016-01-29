# AMX_ATEM

Include file that contains the main ATEM switcher code:
- ATEM Switcher.axi

This is an include file that works with AMX Netlinx Studio to control ATEM switchers. It currrently has only been tested with a ATEM Television Studio.  I have tested the include file on both NI and NX series controllers.  It supports basic functionalitly like changing the program or preview input, doing a cut and getting some information for the switch(input long names, input short names, model and version).

The include file is a port of the Blackmagic Design ATEM Client library for Arduino by 
Kasper Skårhøj, SKAARHOJ K/S, kasper@skaarhoj.com 
It can be found here:  https://github.com/kasperskaarhoj/SKAARHOJ-Open-Engineering/tree/master/ArduinoLibs



This repo also includes the touch panel demo I created to test the fuctionality of "ATEM Switcher.axi" during development.  It also contains the master source file I used to make my DGX800 controller look similar to a DGX switcher on a virtual device using M2M communication.  This was done to minimize the changes I need to make on my main program running on an NX2200. It also maps the inputs to match my original setup, again to minimize changes.

Touch panel demo:
- ATEM Switcher Demo.axs
- ATEM Demo.TP4 (for an MST-701)

The panel looks simlar to the ATEM Software Control system and supports selecting inputs for program and preview along with cutting.  It will also display the the switchers model, version, ip address and output resolution along with the short names for the inputs.

DGX style switching of a ATEM Television Studio using M2M virtual device communication:
- ATEM Switcher-dgx.axs

Supports a few of the DGX switching commands:
- CI\<input\>O\<output\>  output 1 is program, output 2 is preview, output 0 will trigger a cut
- ?MODEL
- ?OUTPUT-VIDEO
- ?VIDOUT_RES_REF
- ?ATEM:ONLINE
- ATEM:ONLINE
- ATEM:OFFLINE
- ?VIDIN_NAME


NOTES:
- The ATEM protocol seems to be timing sensitive, so you may run into issues if the controller this is running on is to busy to responed in a timely manner to ACK requests.  
