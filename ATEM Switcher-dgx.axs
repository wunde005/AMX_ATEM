PROGRAM_NAME='ATEM Switcher-dgx'
INCLUDE 'RoomConfig.axi'

include 'ntp.axi'
INCLUDE 'SYSLOG.AXI'

#DEFINE OVERRIDE_ATEM_UPDATE
include 'ATEM Switcher.axi'


#if_not_defined DGX_SYSTEM_ID
define_constant
DGX_SYSTEM_ID = 11
#END_IF
(***********************************************************)
(***********************************************************)
(*
Ths program makes an amx controller and an ATEM switcher behave similar to a DGX switcher.
Run this on an amx controller and connect to it from another contoller with a Master to Master connection.
Use the following virtual devices to send commands:
vdv_ATEM1 = 34999:1:DGX_SYSTEM_ID //main and input 1
vdv_ATEM2 = 34999:2:DGX_SYSTEM_ID //input 2
vdv_ATEM3 = 34999:3:DGX_SYSTEM_ID //input 3
vdv_ATEM4 = 34999:4:DGX_SYSTEM_ID //input 4
vdv_ATEM5 = 34999:5:DGX_SYSTEM_ID //input 5
vdv_ATEM6 = 34999:6:DGX_SYSTEM_ID //input 6

It supports some of the DGX type switching commands.
Use send_command to send commands, responses will come back on the same device as a string

COMMAND					RESPONSE(string)
CI<input>O<output>	SWITCH-LVIDEOI<input>O<output>  output 1 is program, output 2 is preview and output 0 will trigger a cut

?MODEL					MODEL-<name>
?OUTPUT-VIDEO			SWITCH-LVIDEOI<input>O<output>
?VIDOUT_RES_REF		VIDOUT_RES_REF-<resolution>
?ATEM:ONLINE			ATEM:ONLINE or ATEM:OFFLINE
ATEM:ONLINE				ATEM:ONLINE
ATEM:OFFLINE			ATEM:OFFLINE
?VIDIN_NAME				VIDIN_NAME-<inputname>(<short name>) //send this command to the port for that input vdv_ATEM<PORT>

inputmap function is used to remap which inputs to different numbers

*)
(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)

DEFINE_DEVICE
vdv_test = 35000:1:0

vdv_ATEM1 = 34999:1:DGX_SYSTEM_ID
vdv_ATEM2 = 34999:2:DGX_SYSTEM_ID
vdv_ATEM3 = 34999:3:DGX_SYSTEM_ID
vdv_ATEM4 = 34999:4:DGX_SYSTEM_ID
vdv_ATEM5 = 34999:5:DGX_SYSTEM_ID
vdv_ATEM6 = 34999:6:DGX_SYSTEM_ID

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

dev vdv_ATEM[] = {vdv_ATEM1,vdv_ATEM2,vdv_ATEM3,vdv_ATEM4,vdv_ATEM5,vdv_ATEM6,vdv_test}

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

define_function atem_update(char output){
	if(output == 2){
		send_string vdv_atem1,"'SWITCH-LVIDEOI',ITOA(input_map(ATEM_PrvI,false)),'O2'"	
	}
	else if(output == 1){
		send_string vdv_atem1,"'SWITCH-LVIDEOI',ITOA(input_map(ATEM_PrgI,false)),'O1'"
	}
}

define_function atem_online_status(){
	if(ATEM_isConnected && ATEM_hasInitialized){
		send_string vdv_atem1,"'ATEM:ONLINE'"
	}
	else{
		send_string vdv_atem1,"'ATEM:OFFLINE'"
	}
	
}

define_function integer input_map  (integer input_request,  char incoming){
	local_var integer input
	if(incoming){
		switch(input_request){
			case 1: input = 6  //tracking
			case 2: input = 1  //student 1
			case 3: input = 2  //student 2
			case 4: input = 3  //front
			case 5: input = 4  //sdi in
			case 6: input = 5  //tracking ref
			default: input = input_request
		}
	}
	else{ //outgoing
		switch(input_request){
			case 1: input = 2  //student 1
			case 2: input = 3  //student 2
			case 3: input = 4  //front
			case 4: input = 5  //sdi in
			case 5: input = 6  //tracking ref
			case 6: input = 1  //tracking
			default: input = input_request
		}
	}
	return input
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)

DEFINE_START

atem_ip = '198.18.65.1'

Atem_AutoConnect = 1
atem_debug = 1

atem_connect()

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)

DEFINE_EVENT

data_event[vdv_atem]{
	command:{
		char i
		char waiton
		char cmd_input[20]
		local_var integer input_request
		local_var integer input
		waiton = 0
		if(remove_string(data.text,'CI',1)){
			cmd_input = remove_string(data.text,'O',1)
			cmd_input = left_string(cmd_input,length_string(cmd_input)-1)
			
			input_request = atoi(cmd_input)
			
			input = input_map(input_request,true)
			
			if(data.text[length_string(data.text)] == 'T'){
				set_length_string(data.text,length_string(data.text)-1)
			}
			
			if(data.text == '1'){
				ATEM_setProgramInputVideoSource(input)
				}
			else if(data.text == '2'){
				ATEM_setPreviewInputVideoSource(input)
			}
			else if(data.text == '0'){
				ATEM_PerformCut()
			}
			else{
				for(i=1;i<=length_string(data.text);i++){
					if(data.text[i] == ',' || data.text[i] == ' '){
					}
					else if(data.text[i] == '1' && !waiton){
						ATEM_setProgramInputVideoSource(input)
					}
					else if(data.text[i] == '1' && waiton){
						wait 1{
							ATEM_setProgramInputVideoSource(input)
						}
					}
					else if(data.text[i] == '2' && !waiton){
						ATEM_setPreviewInputVideoSource(input)
					}
					else if(data.text[i] == '2' && waiton){
						wait 1{
							ATEM_setPreviewInputVideoSource(input)
						}
					}
					waiton = 1
				}
			}
		}
		else if(data.text[1] == '?'){
			if(data.text == '?MODEL'){
				send_string 0,"'MODEL-',Atem_pin"
				send_string vdv_atem1,"'MODEL-',Atem_pin"
			}
			else if(remove_string(data.text,'?OUTPUT-VIDEO,',1)){
				if(data.text == '1'){
					send_string 0,"'SWITCH-LVIDEOI',itoa(input_map(atem_prgi,false)),'O1'"
					send_string vdv_atem1,"'SWITCH-LVIDEOI',itoa(input_map(atem_prgi,false)),'O1'"
				}
				else if (data.text == '2'){
					send_string 0,"'SWITCH-LVIDEOI',itoa(input_map(ATEM_PrvI,false)),'O2'"
					send_string vdv_atem1,"'SWITCH-LVIDEOI',itoa(input_map(ATEM_PrvI,false)),'O2'"
				}
			}
			else if(remove_string(data.text,'?VIDOUT_RES_REF',1)){
				if(atem_vidm == '1080i59.94'){
					send_string 0,"'VIDOUT_RES_REF-1920x1080i,29.9'"
					send_string vdv_atem1,"'VIDOUT_RES_REF-1920x1080i,29.9'"
				}
				else send_string vdv_atem1,"'VIDOUT_RES_REF-',atem_vidm"
			}
			else if(remove_string(data.text,'?VIDIN_NAME',1)){
				send_string data.device,"'VIDIN_NAME-',ATEM_getInputName(input_map(data.device.port,true)),' (',ATEM_getInputShortName(input_map(data.device.port,true)),')'"
			}
			else if(remove_string(data.text,'?ATEM:ONLINE',1)){
				atem_online_status()
			}
		}
		else if(remove_string(data.text,'ATEM:ONLINE',1)){
			atem_connect()
		}
		else if(remove_string(data.text,'ATEM:OFFLINE',1)){
			ATEM_Disconnect()
		}
	}
	string:{
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

