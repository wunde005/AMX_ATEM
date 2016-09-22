PROGRAM_NAME='ATEM Switcher'
(***********************************************************)
(***********************************************************)
(***********************************************************)
(*
	This is a port of the Blackmagic Design ATEM Client library for Arduino by
	Kasper Skårhøj, SKAARHOJ K/S, kasper@skaarhoj.com 
	https://github.com/kasperskaarhoj/SKAARHOJ-Open-Engineering/tree/master/ArduinoLibs
	
	
	Atem Switcher:
	Currently supports just the basic commands for the ATEM Television Studio switcher
	
	Connecting:
	Assign ATEM_IP to the IP address of the switch
	ATEM_Connect(): to initiate a connection to the switch
	ATEM_Disconnect(): closes the connection to the switch
	
	Commands:
	ATEM_setProgramInputVideoSource(input): switches the program to the input
	ATEM_setPreviewInputVideoSource(input): switches the preview to the input
	ATEM_PerformCut(): preforms a cut
	
	Variables:
	ATEM_PrgI: Program Input
	ATEM_PrvI: Preview Input

	ATEM_AutoConnect = true/false: specifies if it should auto connect to the switch when the preceding commands are called
	Atem_AutoReconnect = true/false: specifies if the watchdog timer should reconnect if the connection is lost

	Atem_VidM: video output mode
	Atem_Ver:  switcher firmware version
	Atem_pin:  switcher product id
	Atem_Input_Ports[Atem_InputCount]:  Structure containing input settings (id, name, short name, etc....)

	Functions: 
	OVERRIDE_ATEM_UPDATE needs to be defined to declare them in main source file
	define_function atem_update(char output): runs when status of the outputs change.  
		output = 1 for program
		output = 2 for preview
	define_function atem_online_status(): runs when atem online status changes

	*)
(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

dvATEM = 0:100:0

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

//ATEM Header Commands
ATEM_headerCmd_AckRequest = $01
ATEM_headerCmd_HelloPacket = $02
ATEM_headerCmd_Resend = $04
ATEM_headerCmd_RequestNextAfter = $08
ATEM_headerCmd_Ack = $10

ATEM_MAX_PORTS = 20 //Television Studio studio has 18 ports, defines the size of the port array "atem_input_ports"

ATEM_ME = 0 //not sure what this is for. would need to be set differently for different models

ATEM_maxInitPackageCount = 40		// The maximum number of initialization packages. By observation on a 2M/E 4K can be up to (not fixed!) 32. We allocate a f more then...
ATEM_PacketBufferLength = 96	

ATEM_TL_TIMER_1 = 1
ATEM_TL_WATCHDOG = 2

ATEM_NO_INPUT = $FFFF
(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

structure atem_input_port{
	integer ID
	char name[20]  
	char sName[4]     //short name
	char available_pt //available port types
	char external_pt  //external port type
	char input_pt     //input port type
}
(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

char ATEM_IP[16]

atem_input_port atem_input_ports[ATEM_MAX_PORTS]

char ATEM_TlIn_PrgI = 0  //tally for program input
char ATEM_TlIn_PrvI = 0  //tally for preview input

char ATEM_DEBUG = 0

// ATEM Connection Basics

integer ATEM_localPacketIdCounter // This is our counter for the command packages we might like to send to ATEM

char ATEM_initPayLoadSent // If true, the initial reception of the ATEMatem_memory has passed and we can begin to respond during the runLoop()
INTEGER ATEM_initPayLoadSentAtPacketId 	// The Remote Package ID at which point the initialization payload was completed.

char ATEM_hasInitialized  // If true, all initial payload packets has been received during requests for resent - and we are completely ready to rock!
char ATEM_isConnected // Set true if we have received a hello package from the switcher.

integer ATEM_sessionID   // Session id of session, given by ATEM switcher

integer ATEM_lastRemotePacketID  // The most recent Remote Packet Id from switcher
integer ATEM_WATCHDOG_PacketId //last packetid seen by watchdog

char ATEM_missedInitializationPackages[6]   // Used to track which initialization packages have been missed
													//ATEM_maxInitPackageCount replaced due to double to int error
													//(ATEM_maxInitPackageCount+7)/8 = 5.875
														
integer ATEM_returnPackageLength

// ATEM Buffer:
char Atem_PacketBuffer[ATEM_PacketBufferLength]  // Buffer for storing segments of the packets from ATEM and creating answer packets.

integer ATEM_cmdLength   // Used when parsing packets

//integer atem_cmdPointer  // Used when parsing packets
//	
//		bool _ATEM_cBundle;				// If set, we are building a set-command bundle.
char ATEM_cBundle

              // Bundle Buffer Offset; This is an offset if you want to add more commands.
integer ATEM_cBBO  //not implimented 

//initialize to non-existant source
integer ATEM_PrgI = atem_no_input //Program Input
integer ATEM_PrvI = atem_no_input //Preview Input

char Atem_VidM[20] //video output mode
char Atem_Ver[11]  //switcher version
char Atem_pin[44]  //switcher product id

char Atem_InitBuffer[8000] //Used to dump entire init into buffer and parse after complete

LONG lReallyLongTime[1] = 4294967295;
integer ATEM_InputCount = 0

char Atem_AutoConnect = 0
char Atem_AutoReconnect = 0

//keep alive packets round trip is about 517
LONG ATEM_WATCHTIME[] = {520}
CHAR ATEM_WATCHDOG_FAILURES = 0

long temp
char atem_drop_pkt = false  //used for testing packet loss
(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)

#IF_NOT_DEFINED OVERRIDE_ATEM_UPDATE

//OVERRIDE IF NEEDED IN APP
define_function atem_update(char output){
	//function is run when output status changes
	//output 1 = program
	//output 2 = preview
}

define_function atem_online_status(){
	//function is run when online status changes
}
#END_IF


define_function printHex(char temp[],LONG length,char desc[]){
	local_var char retString[200]
	local_var LONG l_length
	local_var integer i
   retString = ""
	
	//only print the first 100 hex codes
	l_length = 100
	if(length < l_length){
		l_length = length
	}
	for(i=1;i<=l_length;i++){
		if(temp[i]>15){
			retString = "retString,itohex(temp[i]),':'" 
		}
		else{
			retString= "retString,'0',itohex(temp[i]),':'"
		}
	}	
	send_string 0,"desc,retString"
}

define_function printbinary(char temp[],integer length,char desc[]){
	local_var char retString[200]
	local_var integer l_length
	local_var integer i
   retString = ""
	
	//only print the first 100 hex codes
	l_length = 100
	if(length < l_length){
		l_length = length
	}
	for(i=l_length;i>0;i--){
		retString = "retString,returnbinary(type_cast(temp[i] >> 4)),returnbinary(type_cast(temp[i] & $0F)),':'"
	}	
	send_string 0,"desc,retString"
}


define_function char[4] returnbinary(char temp){
		local_var char binary[4]
		switch (temp){
			case 0: return '0000'
			case 1: return '0001'
			case 2: return '0010'
			case 3: return '0011'
			case 4: return '0100'
			case 5: return '0101'
			case 6: return '0110'
			case 7: return '0111'
			case 8: return '1000'
			case 9: return '1001'
			case 10: return '1010'
			case 11: return '1011'
			case 12: return '1100'
			case 13: return '1101'
			case 14: return '1110'
			case 15: return '1111'
			default: return 'XXXX'
		}
	
}

DEFINE_FUNCTION ATEM_createCommandHeader(char headerCmd,integer lengthOfData)
{
	ATEM_createCommandHeaderID(headerCMD,lengthOfData,0)
}

DEFINE_FUNCTION ATEM_createCommandHeaderID(char headerCmd,integer lengthOfData,integer remotePacketID){
		Atem_PacketBuffer[1] = TYPE_CAST((headerCmd << 3) | ((lengthOfData >> 8) & $07)) //cmd mask
		Atem_PacketBuffer[2] = TYPE_CAST(lengthOfData & $FF) // length LSB
		Atem_PacketBuffer[3] = TYPE_CAST(ATEM_sessionID >> 8)  // Session ID
		Atem_PacketBuffer[4] = TYPE_CAST(ATEM_sessionID & $FF) // Session ID
		Atem_PacketBuffer[5] = TYPE_CAST(remotePacketID >> 8) // Remote Packet ID, MSB
		Atem_PacketBuffer[6] = TYPE_CAST(remotePacketID & $FF)  // Remote Packet ID, LSB

		if(!(headerCmd & (ATEM_headerCmd_HelloPacket | ATEM_headerCmd_Ack | ATEM_headerCmd_RequestNextAfter))) {
			Atem_localPacketIdCounter++
			Atem_PacketBuffer[11] = type_cast(Atem_localPacketIdCounter >> 8)  // Local Packet ID, MSB
			Atem_PacketBuffer[12] = type_cast(Atem_localPacketIdCounter & $FF) // Local Packet ID, LSB
		}
		
}

DEFINE_FUNCTION ATEM_wipeCleanAtem_PacketBuffer {
	clear_buffer Atem_PacketBuffer
}

DEFINE_FUNCTION ATEM_send_PacketBuffer(integer length)	{
	set_length_string(Atem_PacketBuffer,length)
	send_string dvATEM,"Atem_PacketBuffer"
}

DEFINE_FUNCTION ATEM_CONNECT(){
	integer i
	
	//fail if no ip address has been assigned
	if(length_string(atem_ip) < 1){
		send_string 0,"'NO IP Assigned to ATEM_IP'"
		return
	}
	
	//don't try to reconnect if connection is already active
	if(!Atem_isConnected){
		ATEM_InputCount = 0
		Atem_localPacketIdCounter = 0      // Init Atem_localPacketIdCounter to 0;
		ATEM_initPayLoadSent = false		// Will be true after initial payload of data is delivered (regular 12-byte ping packages are transmitted.)
		ATEM_hasInitialized = false;		// Will be true after initial payload of data is resent and received well
		ATEM_isConnected = false;			// Will be true after the initial hello-package handshakes.
		ATEM_sessionID = $53AB 	// Temporary session ID - a new will be given back from ATEM.	
		
		//initialize to all 1s
		for(i=1; i <= max_length_array(ATEM_missedInitializationPackages); i++){
			ATEM_missedInitializationPackages = "ATEM_missedInitializationPackages,$FF"
			}
	
		ATEM_initPayLoadSentAtPacketId = ATEM_maxInitPackageCount;	// The max value it can be
	
		ip_client_open(dvatem.port,atem_ip,9910,IP_UDP_2WAY)
	
		ATEM_wipeCleanAtem_PacketBuffer();
		ATEM_createCommandHeader(ATEM_headerCmd_HelloPacket, 12+8);
		Atem_PacketBuffer[13] = $01;	// This seems to be what the client should send upon first request. 
		//Atem_PacketBuffer[10] = $3a;	// This seems to be what the client should send upon first request. 
		Atem_PacketBuffer[10] = $03;	// This seems to be what the client should send upon first request. 
		ATEM_send_PacketBuffer(20);  
		
		//Start watchdog timeline
		ATEM_WATCHDOG_PacketId = 0
		TIMELINE_CREATE(ATEM_TL_WATCHDOG,ATEM_WATCHTIME,1,TIMELINE_RELATIVE,TIMELINE_REPEAT)
	}
	else{
		Send_string 0,"'Already conneced'"
	}
}


DEFINE_FUNCTION ATEM_resetCommandBundle()	{
	ATEM_cBundle = false;
	ATEM_cBBO = 0;
}

//Print switch info to diag screen
define_function atem_print_switch(){
	integer i

	send_string 0,"'Model:  ',atem_pin"
	send_string 0,"'Ver:    ',Atem_Ver"
	send_string 0,"'IP:     ',atem_ip"
	send_string 0,"'Output: ',Atem_VidM"
	for(i=1;i<=ATEM_InputCount;i++){
		send_string 0,"'id: ',itoa(atem_input_ports[i].id),' name: ',atem_input_ports[i].name,' Short: ',atem_input_ports[i].sname,' available: ',itohex(atem_input_ports[i].available_pt),' external: ',itohex(atem_input_ports[i].external_pt),' input: ',itohex(atem_input_ports[i].input_pt)"
	}
}



define_function ATEM_Disconnect(){
	ip_client_close(dvatem.port)
	ATEM_isConnected = FALSE
	ATEM_Prgi = ATEM_NO_INPUT
	ATEM_PrvI = ATEM_NO_INPUT
	clear_buffer Atem_InitBuffer
	atem_online_status()
	if(timeline_active(atem_tl_watchdog)) timeline_kill(atem_tl_watchdog)
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

TIMELINE_CREATE (ATEM_TL_TIMER_1, lReallyLongTime, 1, TIMELINE_ABSOLUTE, TIMELINE_ONCE);

set_length_string(Atem_PacketBuffer,ATEM_PacketBufferLength)

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)


DEFINE_EVENT TIMELINE_EVENT[ATEM_TL_WATCHDOG]
{
  	//check to see if packetid has updated since last WatchDog run
	if(ATEM_WATCHDOG_PacketId >= ATEM_lastRemotePacketID){
		ATEM_WATCHDOG_FAILURES++
		send_string 0,"'WD no updated id ',ITOA(ATEM_WATCHDOG_FAILURES),' ',itoa(ATEM_lastRemotePacketID)"
	}
	else{
		ATEM_WATCHDOG_PacketId = ATEM_lastRemotePacketID
		ATEM_WATCHDOG_FAILURES = 0
	}
		
	if(ATEM_WATCHDOG_FAILURES > 5){
		CANCEL_WAIT_UNTIL 'autoconnect'
		if(Atem_AutoReconnect){
			atem_watchdog_failures = 0
			wait 20{
				send_string 0,"'WD reconnect'"
				atem_connect()
			}
			
		}
		send_string 0,"'WD disconnect'"
		atem_watchdog_failures = 0
		ATEM_Disconnect()
	}
}



DEFINE_EVENT

DATA_EVENT[dvATEM]
{
	ONERROR:
	{
		send_string 0,"'ATEM udp error',ITOA(Data.Number)"
		switch(data.number){
			case 2: send_string 0,"'2: General Failure'"
			case 4: send_string 0,"'4: Unknown host'"
			case 6: send_string 0,"'6: Connection refused'"
			case 7: send_string 0,"'7: Connection timed out'"
			case 8: send_string 0,"'8: Unknown connection error'"
			case 9: send_string 0,"'9: Already closed'"
			case 10: send_string 0,"'10: Binding error'"
			case 11: send_string 0,"'11: Listening error'"
			case 14: send_string 0,"'14: Local port already used'"
			case 15: send_string 0,"'15: UDP socket already listening'"
			case 16: send_string 0,"'16: Too many open sockets'"
			case 17: {
				send_string 0,"'17: local port not open'"
				ATEM_Disconnect() //clean up status
			}
		}
	}
	online:
	{
		send_string 0,"'ATEM online'"
	}
	offline:
	{
		send_string 0,"'ATEM offline'"
	}
	string:
	{
		local_var char l_header
		local_var long l_PacketLength
		local_var long	l_packetsize
		local_var char waitingForIncoming
		local_var char i
		
		waitingForIncoming = false
		
		l_packetsize = length_string(data.text)
		
		l_PacketLength = ((data.text[1] & $07) << 8 | data.text[2]) //uint16_t packetLength = word(_Atem_PacketBuffer[0] & B00000111, _Atem_PacketBuffer[1]);
		ATEM_sessionID = TYPE_CAST(data.text[3] << 8 | data.text[4]) //RETURN (Lsb | NLsb << 8 
		
		l_header = TYPE_CAST(data.text[1] >> 3)
		
		ATEM_lastRemotePacketID = type_cast(data.text[11] << 8 | data.text[12])
			
		if (ATEM_lastRemotePacketID < ATEM_maxInitPackageCount)	{
			ATEM_missedInitializationPackages[(ATEM_lastRemotePacketID>>3)+1] = ATEM_missedInitializationPackages[(ATEM_lastRemotePacketID>>3)+1] & TYPE_CAST(~($01<<(ATEM_lastRemotePacketID&$07)));
		}
		
		if(l_header & ATEM_headerCmd_Resend){
			send_string 0,"'resent packet'"
		}
		
		if(atem_watchdog_failures > 1){
			PRINTHEX(DATA.TEXT,l_packetsize,'watchdog>1: ')
		}
		
		if (l_header & ATEM_headerCmd_HelloPacket)	{	// Respond to "Hello" packages:						
			ATEM_isConnected = true;
						
			// _Atem_PacketBuffer[12]	The ATEM will return a "2" in this return package of same length. If the ATEM returns "3" itatem_means "fully booked" (no more clients can connect) and a "4" seems to be a kind of reconnect (seen when you drop the connection and the ATEM desperately tries to figure out what happened...)
			// _Atem_PacketBuffer[15]	This number seems to increment with about 3 each time a new client tries to connect to ATEM. It may be used to judge how many client connections has been made during the up-time of the switcher?
			
			ATEM_wipeCleanAtem_PacketBuffer();

			//switch sent a disconnect reqest
			if(data.text[13] == 4){
				ATEM_Disconnect()				
			}
			else{
				ATEM_createCommandHeader(ATEM_headerCmd_Ack, 12);
				Atem_PacketBuffer[10] = $03;	// This seems to be what the client should send upon first request. 
				ATEM_send_PacketBuffer(12);  
			}
			
		}
	
		if(!ATEM_initPayLoadSent && l_packetsize == 12 && ATEM_lastRemotePacketID>1) {
			ATEM_initPayLoadSent = true
			ATEM_initPayLoadSentAtPacketId = ATEM_lastRemotePacketID
		}
		
		if(!ATEM_initPayLoadSent && !(l_header & ATEM_headerCmd_HelloPacket) && !(l_header & ATEM_headerCmd_Resend) && l_packetsize > 12){
			Atem_InitBuffer = "Atem_InitBuffer,right_string(data.text,l_packetsize - 12)"
		}
		
		if (ATEM_initPayLoadSent && (l_header & ATEM_headerCmd_AckRequest) && (ATEM_hasInitialized || !(l_header & ATEM_headerCmd_Resend))) { 	// Respond to request for acknowledge	(and to resends also, whatever...  
				if(!atem_drop_pkt){
						ATEM_wipeCleanAtem_PacketBuffer();
						ATEM_createCommandHeaderID(ATEM_headerCmd_Ack, 12, ATEM_lastRemotePacketID);
						Atem_PacketBuffer[10] = $47
						if(l_header & ATEM_headerCmd_Resend) printhex(Atem_PacketBuffer,12,'resend ack: ')
						ATEM_send_PacketBuffer(12); 
				}
		}
		
		//if (!(l_header & ATEM_headerCmd_HelloPacket) && l_packetLength>12 && ATEM_hasInitialized)	{
		if (!(l_header & ATEM_headerCmd_HelloPacket) && l_packetLength>12 && ATEM_hasInitialized && !(l_header & ATEM_headerCmd_Resend))	{
						ATEM_parsePacket(right_string(data.text,l_packetsize-12),l_packetsize-12,false)
					}
					
		if (!ATEM_hasInitialized && ATEM_initPayLoadSent && !waitingForIncoming)	{
			for(i=0; i<ATEM_initPayLoadSentAtPacketId; i++)	{
				if (ATEM_missedInitializationPackages[i>>3+1] & ($01<<(i & $07)))	{
					ATEM_wipeCleanAtem_PacketBuffer();
					ATEM_createCommandHeader(ATEM_headerCmd_RequestNextAfter, 12);
					Atem_PacketBuffer[6] = TYPE_CAST(i-1>>8);  // Resend Packet ID, MSB
				   Atem_PacketBuffer[7] = TYPE_CAST((i-1)&$FF);  // Resend Packet ID, LSB
				   Atem_PacketBuffer[8] = $01;
				
					ATEM_send_PacketBuffer(12);  
					waitingForIncoming = true;
					break;
				}
			}
			if (!waitingForIncoming)	{
			   //send_string 0,"'ATEM_hasInitialized'"
				ATEM_parsePacket(Atem_InitBuffer,length_string(Atem_InitBuffer),true)
				ATEM_hasInitialized = true;
				atem_online_status()
				clear_buffer Atem_InitBuffer
				//send_string 0,"'init timeline: ',itoa(TIMELINE_GET (ATEM_TL_TIMER_1))"
			}
		}
	}
}

define_function ATEM_setProgramInputVideoSource(integer videosource){
	if(!ATEM_isConnected && Atem_AutoConnect){
		ATEM_CONNECT()
	}
	else if (!ATEM_isConnected){
		return
	}
	wait_until (ATEM_hasInitialized) 'autoconnect' {
		ATEM_prepareCommandPacket('CPgI',4);
		Atem_PacketBuffer[13+ATEM_cBBO+4+4+0] = atem_me;
		Atem_PacketBuffer[13+ATEM_cBBO+4+4+2] = TYPE_CAST(videoSource >> 8)
		Atem_PacketBuffer[13+ATEM_cBBO+4+4+3] = type_cast(videoSource & $FF)
		ATEM_finishCommandPacket();
	} 
}

define_function ATEM_setPreviewInputVideoSource(integer videosource){
	if(!ATEM_isConnected && Atem_AutoConnect){
		ATEM_CONNECT()
	}
	else if (!ATEM_isConnected){
		return
	}
	wait_until (ATEM_hasInitialized) 'autoconnect' {
		ATEM_prepareCommandPacket('CPvI',4);
		Atem_PacketBuffer[13+ATEM_cBBO+4+4+0] = atem_me;
		Atem_PacketBuffer[13+ATEM_cBBO+4+4+2] = type_cast(videoSource >> 8)
		Atem_PacketBuffer[13+ATEM_cBBO+4+4+3] = type_cast(videoSource & $FF)
		ATEM_finishCommandPacket();
	}
}

define_function ATEM_PerformCut(){
	if(!ATEM_isConnected && Atem_AutoConnect){
		ATEM_CONNECT()
	}
	else if (!ATEM_isConnected){
		return
	}
	wait_until (ATEM_hasInitialized) 'autoconnect' {
		ATEM_prepareCommandPacket('DCut',4);
		Atem_PacketBuffer[13+ATEM_cBBO+4+4+0] = atem_me;
		ATEM_finishCommandPacket();
	}
}


define_function ATEM_finishCommandPacket()	{
	ATEM_createCommandHeader(ATEM_headerCmd_AckRequest, ATEM_returnPackageLength);
	ATEM_send_PacketBuffer(ATEM_returnPackageLength);
   ATEM_returnPackageLength = 0;
}


DEFINE_FUNCTION ATEM_prepareCommandPacket(char cmdstring[],char cmdbytes){
	ATEM_wipecleanAtem_PacketBuffer();
	ATEM_returnPackageLength = 12 + 4 + 4 + cmdbytes
	if (length_string(cmdString)==4)	{
			Atem_PacketBuffer[13+ATEM_cBBO+4] = cmdstring[1]
			Atem_PacketBuffer[13+ATEM_cBBO+4+1] = cmdstring[2]
			Atem_PacketBuffer[13+ATEM_cBBO+4+2] = cmdstring[3]
			Atem_PacketBuffer[13+ATEM_cBBO+4+3] = cmdstring[4]
		} 
	Atem_PacketBuffer[13+ATEM_cBBO] = 0;	// MSB - but it's always under 256, so....
	Atem_PacketBuffer[13+1+ATEM_cBBO] = 4+4+cmdBytes;	// LSB
	}

define_function char[4] ATEM_getInputShortName(integer input){
	integer i
	for(i=1;i<=ATEM_InputCount;i++){
		if(atem_input_ports[i].id == input){
			return atem_input_ports[i].sname
		}
	}
	return itoa(input)
}

define_function char[20] ATEM_getInputName(integer input){
	integer i
	for(i=1;i<=ATEM_InputCount;i++){
		if(atem_input_ports[i].id == input){
			return atem_input_ports[i].name
		}
	}
	return itoa(input)
}


define_function ATEM_parsePacket(char packet[],LONG packetLength,char delay)	{	
		integer indexPointer
		integer i
		integer InputPortId
		integer id
      char cmdStr[5]
		char InPr_LName[20]  //switcher input long name
		char InPr_SName[4]   //switcher input short name
		integer temp_inputcount
		char found
		
		indexPointer = 0	// 12 bytes has already been read from the packet...
		while (indexPointer < packetLength)  {

        // Read the length of segment (first word):
        
		  ATEM_cmdLength = type_cast(packet[1 + indexPointer] << 8 | packet[2 + indexPointer])
		  
			// Get the "command string", basically this is the 4 char variable name in the ATEMatem_memory holding the various state values of the system:
        cmdStr = "packet[5+indexPointer], packet[6+indexPointer], packet[7+indexPointer], packet[8+indexPointer]"
			//IF(PACKETLENGTH < 120) printhex(mid_string(packet,1+indexPointer,atem_cmdlength),ATEM_cmdLength,'PARSEPACKET: ')
			// If length of segment larger than 8 (should always be...!)
        if (ATEM_cmdLength>8)  {
			SELECT {
				ACTIVE (cmdStr == 'PrgI') :{
					//Program Input
					ATEM_Prgi = type_cast((packet[11+indexPointer] << 8)| packet[12+indexPointer])
					ATEM_UPDATE(1)
				}
				active (cmdStr == 'TlSr') :{
					//send_string 0,"'TlSr: ',itoa(packet[9+indexPointer] << 8 | packet[10+indexPointer])"
					//for(i=11+indexPointer;i<=ATEM_cmdLength+indexPointer;){
						//send_string 0,"itoa(packet[i] << 8 | packet [i+1]),' ',itoa(packet[i+2])"
						//i = i + 3
					//}
				}
				active (cmdStr == 'TlIn') :{
				   //tally in bit indicates active camera
					//prgram tally
					ATEM_TlIn_PrgI = TYPE_CAST(((packet[indexpointer + 11] & $01) == 1) | ((packet[indexpointer + 12] & $01) == 1) << 1 |
								   ((packet[indexpointer + 13] & $01) == 1) << 2 | ((packet[indexpointer + 14] & $01) == 1) << 3 |
									((packet[indexpointer + 15] & $01) == 1) << 4 | ((packet[indexpointer + 16] & $01) == 1) << 5)
					//preview tally
					ATEM_TlIn_PrvI = TYPE_CAST(((packet[indexpointer + 11] & $02) == 2) | ((packet[indexpointer + 12] & $02) == 2) << 1 |
								   ((packet[indexpointer + 13] & $02) == 2) << 2 | ((packet[indexpointer + 14] & $02) == 2) << 3 |
									((packet[indexpointer + 15] & $02) == 2) << 4 | ((packet[indexpointer + 16] & $02) == 2) << 5)
				}	
				active (cmdStr == 'Time') :{
					//send_string 0,"'Time: hour',itoa(packet[9+indexPointer]),' min: ',itoa(packet[10+indexPointer]),' sec: ',itoa(packet[11+indexPointer]),' frame: ',itoa(packet[12+indexPointer])"
				}
				ACTIVE (cmdStr == 'PrvI') :{
					//Preview input
					ATEM_PrvI = type_cast(packet[11+indexPointer] << 8| packet[12+indexPointer])
					ATEM_UPDATE(2)
				}
				active (cmdstr == '_ver') :{
				   //ATEM Switch firmware version
					atem_ver = "itoa(packet[9+indexPointer] << 8| packet[10+indexPointer]),'.',itoa(packet[11+indexPointer] << 8| packet[12+indexPointer])"
				}
				active (cmdstr == '_pin') :{
					//ATEM Product ID
					atem_pin = mid_string(packet,indexPointer+1+12+1,ATEM_cmdLength-12-1)
					//remove invalid string character
					i = find_string(atem_pin,"$00",1)
					if(i <> 0){
						atem_pin = left_string(atem_pin,i-1)
					}
				}
				active (cmdstr == 'VidM') :{
					//Video Output Mode
					switch(packet[indexPointer+9]){
						case 0:  atem_vidm = '525i59.94 NTSC'
						case 1:  atem_vidm = '625i 50 PAL'
						case 2:  atem_vidm = '525i59.94 NTSC 16:9'
						case 3:  atem_vidm = '625i 50 PAL 16:9'
						case 4:  atem_vidm = '720p50'
						case 5:  atem_vidm = '720p59.94'
						case 6:  atem_vidm = '1080i50'
						case 7:  atem_vidm = '1080i59.94'
						case 8:  atem_vidm = '1080p23.98'
						case 9:  atem_vidm = '1080p24'
						case 10: atem_vidm = '1080p25'
						case 11: atem_vidm = '1080p29.97'
						case 12: atem_vidm = '1080p50'
						case 13: atem_vidm = '1080p59.94'
						case 14: atem_vidm = '2160p23.98'
						case 15: atem_vidm = '2160p24'
						case 16: atem_vidm = '2160p25'
						case 17: atem_vidm = '2160p29.97'
					}
				}
			active (cmdStr == 'InPr'):{
				InputPortId = 0
				//Input properties
				InPr_LName = mid_string(packet,indexPointer+11,20)
				InPr_SName = mid_string(packet,indexPointer+31,4)
				//remove invalid character from string
				i = find_string(InPr_LName,"$00",1)
				if(i <> 0){
					InPr_LName = left_string(InPr_LName,i-1)
				}
				i = find_string(InPr_SName,"$00",1)
				if(i <> 0){
					InPr_SName = left_string(InPr_SName,i-1)
				}
				id = type_cast(packet[9+indexPointer] << 8| packet[10+indexPointer])
				if(ATEM_InputCount == 0) temp_inputcount = 1
				else temp_inputcount = ATEM_InputCount
				
				//send_string 0,"'aip.id: ',itoa(atem_input_ports[temp_inputcount].id),' ',itoa(id),' ',itoa((atem_input_ports[temp_inputcount].id <= id))"

				//inputs aren't in order
				//is current id larger then last id
				if(atem_input_ports[temp_inputcount].id <= id){
					ATEM_InputCount++
					InputPortId = ATEM_InputCount
				}
				//id is not larger check for existing id
				else{
					found = false
					for(i=1;i<=ATEM_InputCount;i++){
						if(atem_input_ports[i].id == id){
							found = true
							InputPortId = i
						}
					}
					//existing not found point to next location
					if(found == false){
						ATEM_InputCount++
						InputPortId = ATEM_InputCount
					}
				}
				if(InputPortId){
					atem_input_ports[InputPortId].id = id
					atem_input_ports[InputPortId].name = InPr_LName
					atem_input_ports[InputPortId].sname = InPr_SName
					atem_input_ports[InputPortId].available_pt = (packet[indexPointer+36])
					atem_input_ports[InputPortId].external_pt = (packet[indexPointer+38])
					atem_input_ports[InputPortId].input_pt = (packet[indexPointer+39])
				}
				else send_string 0,"'InPr index error'"
			}
			active (1):{
					if(!delay && atem_debug){
						//send_string 0,"'cmdStr: ',cmdStr,' ATEM_cmdLength: ',itoa(ATEM_cmdLength),' indexpointer: ',itoa(indexPointer),' packetLength: ',itoa(packetLength)"
						//printhex(mid_string(packet,indexPointer+1,ATEM_cmdLength),ATEM_cmdLength,"cmdstr,': '")
					}
				}
		}
	
   indexPointer= indexPointer + ATEM_cmdLength
	}
	if (delay) WAIT 20 {} //the wait is to stop the while loop to allow response to switcher
	}
}


(*****************************************************************)
(*                                                               *)
(*                      !!!! WARNING !!!!                        *)
(*                                                               *)
(* Due to differences in the underlying architecture of the      *)
(* X-Series masters, changing variables in the DEFINE_PROGRAM    *)
(* section of code can negatively impact program performance.    *)
(*                                                               *)
(* See “Differences in DEFINE_PROGRAM Program Execution” section *)
(* of the NX-Series Controllers WebConsole & Programming Guide   *)
(* for additional and alternate codingatem_methodologies.            *)
(*****************************************************************)

DEFINE_PROGRAM

(*****************************************************************)
(*                       END OF PROGRAM                          *)
(*                                                               *)
(*         !!!  DO NOT PUT ANY CODE BELOW THIS COMMENT  !!!      *)
(*                                                               *)
(*****************************************************************)
