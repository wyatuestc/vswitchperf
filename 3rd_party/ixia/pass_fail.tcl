#!/usr/bin/env tclsh

# Copyright (c) 2014, Ixia
# Copyright (c) 2015-2016, Intel Corporation
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
# contributors may be used to endorse or promote products derived
# from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# This file is a modified version of a script generated by Ixia
# IxExplorer.

lappend auto_path [list $lib_path]

package req IxTclHal

###################################################################
########################## Configuration ##########################
###################################################################

# Verify that the IXIA chassis spec is given

set reqVars [list "host" "card" "port1" "port2"]

foreach var $reqVars {
    set var_ns [namespace which -variable "$var"]
    if { [string compare $var_ns ""] == 0 } {
        errorMsg "The '$var' variable is undefined. Did you set it?"
        return -1
    }
}

# constants

set fullHex                             "000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F505152535455565758595A5B5C5D5E5F606162636465666768696A6B6C6D6E6F707172737475767778797A7B7C7D7E7F808182838485868788898A8B8C8D8E8F909192939495969798999A9B9C9D9E9FA0A1A2A3A4A5A6A7A8A9AAABACADAEAFB0B1B2B3B4B5B6B7B8B9BABBBCBDBEBFC0C1C2C3C4C5C6C7C8C9CACBCCCDCECFD0D1D2D3D4D5D6D7D8D9DADBDCDDDEDFE0E1E2E3E4E5E6E7E8E9EAEBECEDEEEFF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF"
set hexToC5                             "000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F505152535455565758595A5B5C5D5E5F606162636465666768696A6B6C6D6E6F707172737475767778797A7B7C7D7E7F808182838485868788898A8B8C8D8E8F909192939495969798999A9B9C9D9E9FA0A1A2A3A4A5A6A7A8A9AAABACADAEAFB0B1B2B3B4B5B6B7B8B9BABBBCBDBEBFC0C1C2C3C4C5"

#set payloadLookup(64)                   [string range $fullHex 0 11]
set payloadLookup(64)                   "000102030405"
set payloadLookup(128)                  "000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F404142434445"
set payloadLookup(256)                  "$hexToC5"
set payloadLookup(512)                  "$fullHex$hexToC5"
set payloadLookup(1024)                 "$fullHex$fullHex$fullHex$hexToC5"

###################################################################
###################### Chassis Configuration ######################
###################################################################

if {[isUNIX]} {
    if {[ixConnectToTclServer $host]} {
        errorMsg "Error connecting to Tcl Server $host"
        return $::TCL_ERROR
    }
}

######### Chassis #########

# Now connect to the chassis
if [ixConnectToChassis $host] {
    ixPuts $::ixErrorInfo
    return 1
}

# Get the chassis ID to use in port lists
set chassis [ixGetChassisID $host]

#########  Ports #########

set portList [list [list $chassis $card $port1] \
                   [list $chassis $card $port2]]

# Clear ownership of the ports we’ll use
if [ixClearOwnership $portList force] {
    ixPuts $::ixErrorInfo
    return 1
}

# Take ownership of the ports we’ll use
if [ixTakeOwnership $portList] {
    ixPuts $::ixErrorInfo
    return 1
}

foreach portElem $portList {
    set chasNum [lindex $portElem 0]
    set cardNum [lindex $portElem 1]
    set portNum [lindex $portElem 2]

    port setFactoryDefaults $chasNum $cardNum $portNum
    port config -speed                                10000
    port config -flowControl                          true
    port config -transmitMode                         portTxModeAdvancedScheduler
    port config -receiveMode                          [expr $::portCapture|$::portRxModeWidePacketGroup]
    port config -advertise100FullDuplex               false
    port config -advertise100HalfDuplex               false
    port config -advertise10FullDuplex                false
    port config -advertise10HalfDuplex                false
    port config -portMode                             port10GigLanMode
    port config -enableTxRxSyncStatsMode              true
    port config -txRxSyncInterval                     2000
    port config -enableTransparentDynamicRateChange   true
    port config -enableDynamicMPLSMode                true
    if {[port set $chasNum $cardNum $portNum]} {
        errorMsg "Error calling port set $chasNum $cardNum $portNum"
    }

    packetGroup setDefault
    packetGroup config -numTimeBins                   1
    if {[packetGroup setRx $chasNum $cardNum $portNum]} {
        errorMsg "Error calling packetGroup setRx $chasNum $cardNum $portNum"
    }

    sfpPlus setDefault
    sfpPlus config -enableAutomaticDetect             false
    sfpPlus config -txPreTapControlValue              1
    sfpPlus config -txMainTapControlValue             63
    sfpPlus config -txPostTapControlValue             2
    sfpPlus config -rxEqualizerControlValue           0
    if {[sfpPlus set $chasNum $cardNum $portNum]} {
        errorMsg "Error calling sfpPlus set $chasNum $cardNum $portNum"
    }

    filter setDefault
    filter config -captureTriggerFrameSizeFrom        48
    filter config -captureTriggerFrameSizeTo          48
    filter config -captureFilterFrameSizeFrom         48
    filter config -captureFilterFrameSizeTo           48
    filter config -userDefinedStat1FrameSizeFrom      48
    filter config -userDefinedStat1FrameSizeTo        48
    filter config -userDefinedStat2FrameSizeFrom      48
    filter config -userDefinedStat2FrameSizeTo        48
    filter config -asyncTrigger1FrameSizeFrom         48
    filter config -asyncTrigger1FrameSizeTo           48
    filter config -asyncTrigger2FrameSizeFrom         48
    filter config -asyncTrigger2FrameSizeTo           48
    filter config -userDefinedStat1Enable             true
    filter config -userDefinedStat2Enable             true
    filter config -asyncTrigger1Enable                true
    filter config -asyncTrigger2Enable                true
    if {[filter set $chasNum $cardNum $portNum]} {
        errorMsg "Error calling filter set $chasNum $cardNum $portNum"
    }

    filterPallette setDefault
    filterPallette config -pattern1                   00
    filterPallette config -patternMask1               00
    filterPallette config -patternOffset1             20
    filterPallette config -patternOffset2             20
    if {[filterPallette set $chasNum $cardNum $portNum]} {
        errorMsg "Error calling filterPallette set $chasNum $cardNum $portNum"
    }

    capture setDefault
    capture config -sliceSize                         65536
    if {[capture set $chasNum $cardNum $portNum]} {
        errorMsg "Error calling capture set $chasNum $cardNum $portNum"
    }

    if {[interfaceTable select $chasNum $cardNum $portNum]} {
        errorMsg "Error calling interfaceTable select $chasNum $cardNum $portNum"
    }

    interfaceTable setDefault
    if {[interfaceTable set]} {
        errorMsg "Error calling interfaceTable set"
    }

    interfaceTable clearAllInterfaces
    if {[interfaceTable write]} {
        errorMsg "Error calling interfaceTable write"
    }

    ixEnablePortIntrinsicLatencyAdjustment $chasNum $cardNum $portNum true
}

ixWritePortsToHardware portList

if {[ixCheckLinkState $portList] != 0} {
    errorMsg "One or more port links are down"
}

proc sendTraffic { flowSpec trafficSpec } {
    # Send traffic from IXIA.
    #
    # Transmits traffic from Rx port (port1), and captures traffic at
    # Tx port (port2).
    #
    # Parameters:
    #   flowSpec - a dict detailing how the packet should be sent. Should be
    #     of format:
    #         {type, numpkts, duration, framerate}
    #   trafficSpec - a dict describing the packet to be sent. Should be
    #     of format:
    #         { l2, vlan, l3}
    #     where each item is in turn a dict detailing the configuration of each
    #     layer of the packet
    # Returns:
    #   Output from Rx end of Ixia if duration != 0, else 0

    ##################################################
    ################# Initialisation #################
    ##################################################

    # Configure global variables. See documentation on 'global' for more
    # information on why this is necessary
    #   https://www.tcl.tk/man/tcl8.5/tutorial/Tcl13.html
    global portList

    # Extract the provided dictionaries to local variables to simplify the
    # rest of the script

    # flow spec

    set streamType              [dict get $flowSpec type]
    set numPkts                 [dict get $flowSpec numpkts]
    set duration                [expr {[dict get $flowSpec duration] * 1000}]
    set frameRate               [dict get $flowSpec framerate]

    # traffic spec

    # extract nested dictionaries
    set trafficSpec_l2          [dict get $trafficSpec l2]
    set trafficSpec_l3          [dict get $trafficSpec l3]
    set trafficSpec_l4          [dict get $trafficSpec l4]
    set trafficSpec_vlan        [dict get $trafficSpec vlan]

    set frameSize               [dict get $trafficSpec_l2 framesize]
    set srcMac                  [dict get $trafficSpec_l2 srcmac]
    set dstMac                  [dict get $trafficSpec_l2 dstmac]
    set srcPort                 [dict get $trafficSpec_l4 srcport]
    set dstPort                 [dict get $trafficSpec_l4 dstport]

    set proto                   [dict get $trafficSpec_l3 proto]
    set srcIp                   [dict get $trafficSpec_l3 srcip]
    set dstIp                   [dict get $trafficSpec_l3 dstip]

    if {[dict exists $trafficSpec_l3 protocolpadbytes]} {
        set protocolPad             [dict get $trafficSpec_l4 protocolpad]
        set protocolPadBytes        [dict get $trafficSpec_l4 protocolpadbytes]
    }

    set vlanEnabled             [dict get $trafficSpec_vlan enabled]
    if {$vlanEnabled == 1 } {
        # these keys won't exist if vlan wasn't enabled
        set vlanId                  [dict get $trafficSpec_vlan id]
        set vlanUserPrio            [dict get $trafficSpec_vlan priority]
        set vlanCfi                 [dict get $trafficSpec_vlan cfi]
    }

    ##################################################
    ##################### Streams ####################
    ##################################################

    streamRegion get $::chassis $::card $::port1
    if {[streamRegion enableGenerateWarningList $::chassis $::card $::port1 false]} {
        errorMsg "Error calling streamRegion enableGenerateWarningList  $::chassis $::card $::port1 false"
    }

    set streamId 1

    stream setDefault
    stream config -ifg                                9.6
    stream config -ifgMIN                             19.2
    stream config -ifgMAX                             25.6
    stream config -ibg                                9.6
    stream config -isg                                9.6
    stream config -rateMode                           streamRateModePercentRate
    stream config -percentPacketRate                  $frameRate
    stream config -framesize                          $frameSize
    stream config -frameType                          "08 00"
    stream config -sa                                 $srcMac
    stream config -da                                 $dstMac
    stream config -numSA                              16
    stream config -numDA                              16
    stream config -asyncIntEnable                     true
    stream config -dma                                $streamType
    stream config -numBursts                          1
    stream config -numFrames                          $numPkts
    stream config -patternType                        incrByte
    stream config -dataPattern                        x00010203
    stream config -pattern                            "00 01 02 03"

    protocol setDefault
    protocol config -name                             ipV4
    protocol config -ethernetType                     ethernetII
    if {$vlanEnabled == 1} {
        protocol config -enable802dot1qTag            vlanSingle
    }

    if {[info exists protocolPad]} {
        protocol config -enableProtocolPad                $protocolPad
    }

    ip setDefault
    ip config -ipProtocol                             ipV4Protocol[string totitle $proto]
    ip config -checksum                               "f6 75"
    ip config -sourceIpAddr                           $srcIp
    ip config -sourceIpAddrRepeatCount                10
    ip config -sourceClass                            classA
    ip config -destIpAddr                             $dstIp
    ip config -destIpAddrRepeatCount                  10
    ip config -destClass                              classA
    ip config -destMacAddr                            $dstMac
    ip config -destDutIpAddr                          0.0.0.0
    ip config -ttl                                    64
    if {[ip set $::chassis $::card $::port1]} {
        errorMsg "Error calling ip set $::chassis $::card $::port1"
    }

    "$proto" setDefault
    "$proto" config -checksum                         "25 81"
    if {["$proto" set $::chassis $::card $::port1]} {
        errorMsg "Error calling $proto set $::chassis $::card $::port"
    }

    if {[info exists protocolPad]} {
        protocolPad setDefault
        # VxLAN header with VNI 99 (0x63)
        # Inner SRC 01:02:03:04:05:06
        # Inner DST 06:05:04:03:02:01
        # IP SRC 192.168.0.2
        # IP DST 192.168.240.9
        # SRC port 3000 (0x0BB8)
        # DST port 3001 (0x0BB9)
        # length 26
        # UDP Checksum 0x2E93

        # From encap case capture
        protocolPad config -dataBytes "$protocolPadBytes"
        if {[protocolPad set $::chassis $::card $::port1]} {
            errorMsg "Error calling protocolPad set $::chassis $::card $::port"
            set retCode $::TCL_ERROR
        }
    }

    if {$vlanEnabled == 1 } {
        vlan setDefault
        vlan config -vlanID                               $vlanId
        vlan config -userPriority                         $vlanUserPrio
        vlan config -cfi                                  $vlanCfi
        vlan config -mode                                 vIdle
        vlan config -repeat                               10
        vlan config -step                                 1
        vlan config -maskval                              "0000XXXXXXXXXXXX"
        vlan config -protocolTagId                        vlanProtocolTag8100
    }

    if {[vlan set $::chassis $::card $::port1]} {
        errorMsg "Error calling vlan set $::chassis $::card $::port1"
    }

    if {[port isValidFeature $::chassis $::card $::port1 $::portFeatureTableUdf]} {
        tableUdf setDefault
        tableUdf clearColumns
        if {[tableUdf set $::chassis $::card $::port1]} {
            errorMsg "Error calling tableUdf set $::chassis $::card $::port1"
        }
    }

    if {[port isValidFeature $::chassis $::card $::port1 $::portFeatureRandomFrameSizeWeightedPair]} {
        weightedRandomFramesize setDefault
        if {[weightedRandomFramesize set $::chassis $::card $::port1]} {
            errorMsg "Error calling weightedRandomFramesize set $::chassis $::card $::port1"
        }
    }

    if {$proto == "tcp"} {
        tcp setDefault
        tcp config -sourcePort                            $srcPort
        tcp config -destPort                              $dstPort
        if {[tcp set $::chassis $::card $::port1 ]} {
            errorMsg "Error setting tcp on port $::chassis.$::card.$::port1"
        }

        if {$vlanEnabled != 1} {
            udf setDefault
            udf config -repeat                                1
            udf config -continuousCount                       true
            udf config -initval                               {00 00 00 01}
            udf config -updown                                uuuu
            udf config -cascadeType                           udfCascadeNone
            udf config -step                                  1

            packetGroup setDefault
            packetGroup config -insertSequenceSignature       true
            packetGroup config -sequenceNumberOffset          38
            packetGroup config -signatureOffset               42
            packetGroup config -signature                     "08 71 18 05"
            packetGroup config -groupIdOffset                 52
            packetGroup config -groupId                       $streamId
            packetGroup config -allocateUdf                   true
            if {[packetGroup setTx $::chassis $::card $::port1 $streamId]} {
                errorMsg "Error calling packetGroup setTx $::chassis $::card $::port1 $streamId"
            }
        }
    } elseif {$proto == "udp"} {
        udp setDefault
        udp config -sourcePort                            $srcPort
        udp config -destPort                              $dstPort
        set packetSize               [dict get $trafficSpec_l3 packetsize]
        stream config -framesize                          $packetSize
        if {[udp set $::chassis $::card $::port1]} {
            errorMsg "Error setting udp on port $::chassis.$::card.$::port1"
        }
        errorMsg "frameSize: $frameSize, packetSize: $packetSize, srcMac: $srcMac, dstMac: $dstMac, srcPort: $srcPort, dstPort: $dstPort"
        if {[info exists protocolPad]} {
            errorMsg "protocolPad: $protocolPad, protocolPadBytes: $protocolPadBytes"
        }
    }

    if {[stream set $::chassis $::card $::port1 $streamId]} {
        errorMsg "Error calling stream set $::chassis $::card $::port1 $streamId"
    }

    incr streamId
    streamRegion generateWarningList $::chassis $::card $::port1
    ixWriteConfigToHardware portList -noProtocolServer

    if {[packetGroup getRx $::chassis $::card $::port2]} {
        errorMsg "Error calling packetGroup getRx $::chassis $::card $::port2"
    }

    ##################################################
    ######### Traffic Transmit and Results ###########
    ##################################################

    # Transmit traffic

    logMsg "Clearing stats for all ports"
    ixClearStats portList

    logMsg "Starting packet groups on port $::port2"
    ixStartPortPacketGroups $::chassis $::card $::port2

    logMsg "Starting Capture on port $::port2"
    ixStartPortCapture $::chassis $::card $::port2

    logMsg "Starting transmit on port $::port1"
    ixStartPortTransmit $::chassis $::card $::port1

    # If duration=0 is passed, exit after starting transmit

    if {$duration == 0} {
        logMsg "Sending traffic until interrupted"
        return
    }

    logMsg "Waiting for $duration ms"

    # Wait for duration - 1 second to get traffic rate

    after [expr "$duration - 1"]

    # Get result

    set result                                        [stopTraffic]

    if {$streamType == "contPacket"} {
        return $result
    } elseif {$streamType == "stopStream"} {
        set payError 0
        set seqError 0
        set captureLimit 3000

        # explode results from 'stopTraffic' for ease of use later
        set framesSent [lindex $result 0]
        set framesRecv [lindex $result 1]
        set bytesSent [lindex $result 2]
        set bytesRecv [lindex $result 3]

        if {$framesSent <= $captureLimit} {
            captureBuffer get $::chassis $::card $::port2 1 $framesSent
            set capturedFrames [captureBuffer cget -numFrames]

            set notCaptured [expr "$framesRecv - $capturedFrames"]
            if {$notCaptured != 0} {
                errorMsg "'$notCaptured' frames were not captured"
            }

            if {$proto == "tcp"} {
                for {set z 1} {$z <= $capturedFrames} {incr z} {
                    captureBuffer getframe $z
                    set capFrame [captureBuffer cget -frame]
                    regsub -all " " $capFrame "" frameNoSpaces
                    set frameNoSpaces

                    set startPayload 108
                    set endPayload [expr "[expr "$frameSize * 2"] - 9"]
                    set payload [string range $frameNoSpaces $startPayload $endPayload]

                    if {$vlanEnabled != 1} {
                        set startSequence 76
                        set endSequence 83
                        set sequence [string range $frameNoSpaces $startSequence $endSequence]
                        scan $sequence %x seqDecimal
                        set seqDecimal
                        if {"$payload" != $::payloadLookup($frameSize)} {
                            errorMsg "frame '$z' payload: invalid payload"
                            incr payError
                        }
                        # variable z increments from 1 to total number of packets
                        # captured TCP sequence numbers start at 0, not 1. When
                        # comparing sequence numbers for captured frames, reduce
                        # variable z by 1 i.e. frame 1 with sequence 0 is compared
                        # to expected sequence 0.
                        if {$seqDecimal != $z-1} {
                            errorMsg "frame '$z' sequence number: Found '$seqDecimal'. Expected '$z'"
                            incr seqError
                        }
                    }
                }
            }
            logMsg "Sequence Errors: $seqError"
            logMsg "Payload Errors:  $payError\n"
        } else {
            errorMsg "Too many packets for capture."
        }

        set result [list $framesSent $framesRecv $bytesSent $bytesRecv $payError $seqError]
        return $result
    } else {
        errorMsg "streamtype is not supported: '$streamType'"
    }
}

proc stopTraffic {} {
    # Stop sending traffic from IXIA.
    #
    # Stops Transmit of traffic from Rx port.
    #
    # Returns:
    #   Output from Rx end of Ixia.

    ##################################################
    ################# Initialisation #################
    ##################################################

    # Configure global variables. See documentation on 'global' for more
    # information on why this is necessary
    #   https://www.tcl.tk/man/tcl8.5/tutorial/Tcl13.html
    global portList

    ##################################################
    ####### Stop Traffic Transmit and Results ########
    ##################################################

     # Read frame rate of transmission

    if {[stat getRate statAllStats $::chassis $::card $::port1]} {
        errorMsg "Error reading stat rate on port $::chassis $::card $::port1"
        return $::TCL_ERROR
    }

    set sendRate [stat cget -framesSent]
    set sendRateBytes [stat cget -bytesSent]

    if {[stat getRate statAllStats $::chassis $::card $::port2]} {
        errorMsg "Error reading stat rate on port $::chassis $::card $::port2"
        return $::TCL_ERROR
    }

    set recvRate [stat cget -framesReceived]
    set recvRateBytes [stat cget -bytesReceived]

    # Wait for a second, else we get funny framerate statistics
    after 1

    # Stop transmission of traffic
    ixStopTransmit portList

    if {[ixCheckTransmitDone portList] == $::TCL_ERROR} {
        return -code error
    } else {
        logMsg "Transmission is complete.\n"
    }

    ixStopPacketGroups portList
    ixStopCapture portList

    # Get statistics

    if {[stat get statAllStats $::chassis $::card $::port1]} {
        errorMsg "Error reading stat on port $::chassis $::card $::port1"
        return $::TCL_ERROR
    }

    set bytesSent [stat cget -bytesSent]
    set framesSent [stat cget -framesSent]

    if {[stat get statAllStats $::chassis $::card $::port2]} {
        errorMsg "Error reading stat on port $::chassis $::card $::port2"
        return $::TCL_ERROR
    }

    set bytesRecv [stat cget -bytesReceived]
    set framesRecv [stat cget -framesReceived]

    set bytesDropped [expr "$bytesSent - $bytesRecv"]
    set framesDropped [expr "$framesSent - $framesRecv"]

    logMsg "Frames Sent:       $framesSent"
    logMsg "Frames Recv:       $framesRecv"
    logMsg "Frames Dropped:    $framesDropped\n"

    logMsg "Bytes Sent:        $bytesSent"
    logMsg "Bytes Recv:        $bytesRecv"
    logMsg "Bytes Dropped:     $bytesDropped\n"

    logMsg "Frame Rate Sent:   $sendRate"
    logMsg "Frame Rate Recv:   $recvRate\n"

    set result [list $framesSent $framesRecv $bytesSent $bytesRecv $sendRate $recvRate $sendRateBytes $recvRateBytes]

    return $result
}

proc rfcThroughputTest { testSpec trafficSpec } {
    # Execute RFC tests from IXIA.
    #
    # Wraps the sendTraffic proc, repeatedly calling it, storing the result and
    # performing an iterative binary search to find the highest possible RFC
    # transmission rate. Abides by the specification of RFC2544 as given by the
    # IETF:
    #
    #   https://www.ietf.org/rfc/rfc2544.txt
    #
    # Parameters:
    #   testSpec - a dict detailing how the test should be run. Should be
    #     of format:
    #         {numtrials, duration, lossrate}
    #   trafficSpec - a dict describing the packet to be sent. Should be
    #     of format:
    #         { l2, l3}
    #     where each item is in turn a dict detailing the configuration of each
    #     layer of the packet
    # Returns:
    #   Highest rate with acceptable packet loss.

    ##################################################
    ################# Initialisation #################
    ##################################################

    # Configure global variables. See documentation on 'global' for more
    # information on why this is necessary
    #   https://www.tcl.tk/man/tcl8.5/tutorial/Tcl13.html
    global portList

    # Extract the provided dictionaries to local variables to simplify the
    # rest of the script

    # testSpec

    # RFC2544 to IXIA terminology mapping (it affects Ixia configuration below):
    # Test    => Trial
    # Trial   => Iteration
    set numTrials               [dict get $testSpec tests]  ;# we don't use this yet
    set duration                [dict get $testSpec duration]
    set lossRate                [dict get $testSpec lossrate]
    set multipleStream          [dict get $testSpec multipleStreams]  ;# we don't use this yet

    # variables used for binary search of results
    set min 1
    set max 100
    set diff [expr "$max - $min"]

    set result [list 0 0 0 0 0 0 0 0]  ;# best result found so far
    set percentRate 100  ;# starting throughput percentage rate

    ##################################################
    ######### Traffic Transmit and Results ###########
    ##################################################

    # iterate a maximum of 20 times, sending packets at a set  rate to
    # find fastest possible rate with acceptable packetloss
    #
    # As a reminder, the binary search works something like this:
    #
    #   percentRate < idealValue --> min = percentRate
    #   percentRate > idealValue --> max = percentRate
    #   percentRate = idealValue --> max = min = percentRate
    #
    for {set i 0} {$i < 20} {incr i} {
        dict set flowSpec type                        "contPacket"
        dict set flowSpec numpkts                     100 ;# this can be bypassed
        dict set flowSpec duration                    $duration
        dict set flowSpec framerate                   $percentRate

        set flowStats [sendTraffic $flowSpec $trafficSpec]

        # explode results from 'sendTraffic' for ease of use later
        set framesSent [lindex $flowStats 0]
        set framesRecv [lindex $flowStats 1]
        set sendRate [lindex $flowStats 4]

        set framesDropped [expr "$framesSent - $framesRecv"]
        if {$framesSent > 0} {
            set framesDroppedRate [expr "double($framesDropped) / $framesSent"]
        } else {
            set framesDroppedRate 100
        }

        # check if we've already found the rate before 10 iterations, i.e.
        # 'percentRate = idealValue'. This is as accurate as we can get with
        # integer values.
        if {[expr "$max - $min"] <= 0.5 } {
            break
        }

        # handle 'percentRate <= idealValue' case
        if {$framesDroppedRate <= $lossRate} {
            logMsg "Frame sendRate of '$sendRate' pps succeeded ('$framesDropped' frames dropped)"

            set result $flowStats
            set min $percentRate

            set percentRate [expr "$percentRate + ([expr "$max - $min"] * 0.5)"]
        # handle the 'percentRate > idealValue' case
        } else {
            if {$framesDropped == $framesSent} {
                errorMsg "Dropped all frames!"
            }

            errorMsg "Frame sendRate of '$sendRate' pps failed ('$framesDropped' frames dropped)"

            set max $percentRate
            set percentRate [expr "$percentRate - ([expr "$max - $min"] * 0.5)"]
        }
    }

    set bestRate [lindex $result 4]

    logMsg "$lossRate% packet loss rate: $bestRate"

    return $result
}