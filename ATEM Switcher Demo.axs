PROGRAM_NAME='ATEM Switcher Test'
include 'ATEM Switcher.axi'

(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 04/05/2006  AT: 09:00:25        *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
    $History: $
*)
(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

dvTP = 10001:1:0

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

LONG 				minute[] = {6000}
(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE
//char test = $03
CHAR LOCAL_INIT = 0

IP_ADDRESS_STRUCT MyIPAddress 

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
(* EXAMPLE: `<RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)


DEFINE_FUNCTION CONNECT(){
		local_var integer i
		local_var char sname[5]
		ATEM_connect()
		wait_until (ATEM_hasInitialized){
			SEND_COMMAND dvtp,"'^TXT-1,1&2,Model: ',atem_pin"
			SEND_COMMAND dvtp,"'^TXT-2,1&2,Ver: ',atem_ver"
			SEND_COMMAND dvtp,"'^TXT-3,1&2,IP: ',ATEM_IP"
			SEND_COMMAND dvtp,"'^TXT-4,1&2,Output: ',atem_vidm"
			
			for(i=1;i<=6;i++){
				sname = atem_getinputshortname(i)
				send_command dvtp,"'^TXT-',itoa(20+i),',1&2,',sname"
				send_command dvtp,"'^TXT-',itoa(120+i),',1&2,',sname"
			}
			LOCAL_INIT = TRUE
		}

}




DEFINE_START

atem_ip = '192.168.0.10'
GET_IP_ADDRESS(0:0:0,MyIPAddress)
send_string 0,"'startup'"

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)

DEFINE_EVENT

DATA_EVENT[dvTP]
{
    ONLINE:
    {
	SEND_COMMAND DATA.DEVICE, "'ABEEP'"
	}        
}

BUTTON_EVENT[dvtp,10]{
	PUSH:{
	CONNECT()
	}
}


BUTTON_EVENT[dvtp,11]{
	PUSH:{
		ATEM_Disconnect()
		}
}

BUTTON_EVENT[dvtp,15]{
	PUSH:{
		integer i
		
		atem_print_switch()
	}
}

BUTTON_EVENT[dvtp,16]{
	PUSH:{
		send_string 0,"'CSOM-AV TEST ',TIME,' ',DATE"
	}
}



button_event[dvtp,20]
button_event[dvtp,21]
button_event[dvtp,22]
button_event[dvtp,23]
button_event[dvtp,24]
button_event[dvtp,25]
button_event[dvtp,26]{
	push:{
		ATEM_setProgramInputVideoSource(button.input.channel - 20)
	}
}

button_event[dvtp,120]
button_event[dvtp,121]
button_event[dvtp,122]
button_event[dvtp,123]
button_event[dvtp,124]
button_event[dvtp,125]
button_event[dvtp,126]{
	push:{
		ATEM_setPreviewInputVideoSource(button.input.channel - 120)
		
	}
}

button_event[dvtp,19]{
	push:{
		ATEM_PerformCut()
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

[dvtp,10] = ATEM_isConnected
[dvtp,12] = true
[dvtp,20] = (ATEM_PrgI == 0)
[dvtp,21] = (ATEM_PrgI == 1)
[dvtp,22] = (ATEM_PrgI == 2)
[dvtp,23] = (ATEM_PrgI == 3)
[dvtp,24] = (ATEM_PrgI == 4)
[dvtp,25] = (ATEM_PrgI == 5)
[dvtp,26] = (ATEM_PrgI == 6)
                    
[dvtp,120] = (ATEM_PrvI == 0)
[dvtp,121] = (ATEM_PrvI == 1)
[dvtp,122] = (ATEM_PrvI == 2)
[dvtp,123] = (ATEM_PrvI == 3)
[dvtp,124] = (ATEM_PrvI == 4)
[dvtp,125] = (ATEM_PrvI == 5)
[dvtp,126] = (ATEM_PrvI == 6)
 
[dvtp,16] = atem_drop_pkt 