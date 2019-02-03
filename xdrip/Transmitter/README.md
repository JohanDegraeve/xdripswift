<style type="text/css">
  h2 { margin-left: 10px; }
  h3 { margin-left: 25px; }
  h4 { margin-left: 40px; }
</style>

- [Summary](#summary)
- [Steps for adding new transmitter types](#newtransmitters)
	- [conform to protocol BluetoothTransmitterDelegate](#protocolbluetoothtransmitterdelegate)
		- [centralManagerDidConnect](#centralManagerdidconnect)
		- [centralManagerDidFailToConnect](#centralmanagerdidfailtoconnect)
		- [centralManagerDidDisconnectPeripheral](#centralmanagerdiddisconnectperipheral)
		- [centralManagerDidUpdateState](#centralManagerDidUpdateState)
		- [peripheralDidUpdateNotificationStateFor](#peripheraldidupdatenotificationstatefor)
		- [peripheralDidUpdateValueFor](#peripheraldidupatevaluefor)
	- [conform to protocol CGMTransmitterProtocol](#protocolCGMTransmitterProtocol)
		- [canDetectNewSensor](#canDetectNewSensorprotocol)
	- [extend class BluetoothTransmitter](#extendclassbuetoothtransmitter)
		- [initialize the super class BluetoothTransmitter](#initializebluetoothtransmitter)
			- [BluetoothTransmitter.DeviceAddressAndName](#deviceaddressname)
			- [CBUUID\_Advertisement](#cbuuidadvertisement)
			- [CBUUID\_Service](#cbuuidservice)
			- [CBUUID\_ReceiveCharacteristic](#cbuuidreceivecharacteristic)
			- [CBUUID\_WriteCharacteristic](#cbuuidwritecharacteristic)
	- [add a property of type CGMTransmitterDelegate](#protocolcgmtransmitterdelegate)
		- [cgmTransmitterDidConnect](#cgmTransmitterDidConnect)
		- [cgmTransmitterDidDisconnect](#cgmTransmitterDidDisconnect)
		- [didUpdateBluetoothState](#didUpdateBluetoothState)
		- [newSensorDetected](#newSensorDetected)
		- [sensorNotDetected](#sensorNotDetected)
		- [newReadingsReceived](#newReadingsReceived)
		- [transmitterNeedsPairing](#transmitterNeedsPairing)
- [Functions and properties available in transmitter classes](#functionsandpropertiesavailableintransmitterclasses)
	- [Functions in BluetoothTransmitter classes](#functionsinbluetoothtransmitterclasses)
		- [disconnect](#disconnect)
		- [startScanning](#startScanning)
		- [writeDataToPeripheral(data:Data, type:CBCharacteristicWriteType) -> Bool](#writeDataToPeripheral)
		- [writeDataToPeripheral(data:Data, characteristicToWriteTo:CBCharacteristic, type:CBCharacteristicWriteType) -> Bool](#writeDataToPeripheral)
		- [setNotifyValue](#setNotifyValue)
	- [Properties in BluetoothTransmitter classes](#propertiesinbluetoothtransmitterclasses)
		- [address](#address)
		- [name](#name)
	- [Functions in CGM Transmitter classes](#functionsincgmtransmitterclasses)
		- [canDetectNewSensor](#canDetectNewSensor)
- [Available CGM transmitter classes](#availablecgmtransmitterclasses)
	- [MiaoMiao](#MiaoMiao)
	- [xDripG4](#xDripG4)
	

# <a name="summary"></a>Summary

BluetoothTransmitter.swift defines the class **BluetoothTransmitter**, which implements the bluetooth protocol applicable to any 
type of peripheral and that works with only a receive and a transmit characteristic. 
The class handles the scanning, connect, services discovery, characteristics discover, subscribing to characteristic,
connect and reconnect, connect after app launch 
(app needs to connect at least once, then it will remember the address and reconnect automatically at next launch)

If necessary, each of the functions in the protocols CBCentralManagerDelegate and CBPeripheralDelegatecan be overriden by the inheriting class.

The protocol **BluetoothTransmitterDelegate** defines functions that allow to pass bluetooth activity information from the 
BluetoothTransmitter class to a specific transmitter class. Example when a disconnect occurs, the BlueToothTransmitter class 
handles the reconnect but the delegate class can for instance show the connection status to the user. It will be informed about
the connection status via the function centralManagerDidConnect in the BluetoothTransmitterDelegate

**CGMTransmitterProtocol** defines functions that CGM transmitter classes need to implement.

The CGM transmitter communicates back to the caller via the **CGMTransmitterDelegate** protocol.<br> 
Needs to be conformed to, for instance by a view controller, or manager, .. whatever<br>
This protocol allows passing information like new readings, sensor detected, and also connect/disconnect, bluetooth status change<br>

Following specific transmitter classes exist:<br>
**CGMG4xDripTransmitter**<br>
**CGMG5Transmitter**<br>

#<a name="newtransmitters"></a>Steps for adding new (CGM) transmitter types

Every new type of bluetoothtransmitter needs to

* extend BluetoothTransmitter
* conform to the protocol BluetoothTransmitterDelegate.

If it's a CGM transmitter (it could also be a bloodglucose meter that transmits data over bluetooth)

* conform to the protocol CGMTransmitterProtocol

## <a name="protocolbluetoothtransmitterdelegate"></a>conform to protocol BluetoothTransmitterDelegate

The functions that not be implemented:

### <a name="centralManagerdidconnect"><font color="purple">func</font> centralManagerDidConnect()

Called when device disconnects. Can be used to pass information to the user. The new transmitter class can use the protocol CGMTransmitterDelegate 
to pass back this information to a controlling class

### <a name="centralmanagerdidfailtoconnect"></a><font color="purple">func</font> centralManagerDidFailToConnect(error: Error?)

Called when device fails to connect. Probably not useful, but it's there

### <a name="centralmanagerdiddisconnectperipheral"></a><font color="purple">func</font> centralManagerDidDisconnectPeripheral(error: Error?)

Called when device disconnects. Can be used to pass information to the user. The transmitter class can use the protocol CGMTransmitterDelegate 
to pass back this information to a controlling class

### <a name="centralManagerDidUpdateState"></a><font color="purple">func</font> centralManagerDidUpdateState(state: <font color="purple">CBManagerState</font>)

Called when bluetooth state changes, ie when user switches on or off bluetooth. This function also gets called immediately 
after startup of the application.<br>
The transmitter class can use the protocol CGMTransmitterDelegate to pass back this information to a controlling class<br>
It can be used by the controlling class to start scanning.

### <a name="peripheraldidupdatenotificationstatefor"></a><font color="purple">func</font> peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?)

is called when BluetoothTranmsitter class function 
 peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) is called<br>
For instance in the MiaoMiao transmitter class, the implementation will call start reading command.<br>
For other types of transmitters there may be nothing to do.<br>

### <a name="peripheraldidupatevaluefor"></a><font color="purple">func</font> peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?)

This will be the most important function, because it contains the data that needs to be processed by the specific transmitter class.

## <a name="protocolCGMTransmitterProtocol"></a>conform to protocol CGMTransmitterProtocol

### <a name="canDetectNewSensorprotocol"></a>canDetectNewSensor

can the cgm transmitter detect that a new sensor is placed ? Will return true only for Libre type of transmitters, eg MiaoMiao<br>
If it returns true the the transmitter should also use newSensorDetected

## <a name="extendclassbuetoothtransmitter"></a>extend class BluetoothTransmitter

A new transmitter class needs to extend BluetoothTransmitter and

### <a name="initializebluetoothtransmitter"></a>initialize the super class BluetoothTransmitter

the signature of the initializer of the super class BluetoothTransmitter is<br>

<font color="purple">init</font>(addressAndName:<font color="#516374">BluetoothTransmitter.DeviceAddressAndName</font>, 
CBUUID\_Advertisement:<font color="purple">String</font>, 
CBUUID\_Service:<font color="purple">String</font>, 
CBUUID\_ReceiveCharacteristic:<font color="purple">String</font>, 
CBUUID\_WriteCharacteristic:<font color="purple">String</font>) {
  
#### <a name="deviceaddressname"></a>BluetoothTransmitter.DeviceAddressAndName

If the app never connected to the device, then we don't know it's name and address as the device itself is going to send.<br> 
Possibly we have an expected device name. Not all devices have a predefined device name (example xdrip/xbridge have different names).<br>
Usually, if there's no expected device name, there will be a CBUUID\_Advertisement<br>

If the app connected before, then we have the address (should be stored in the settings or somewhere) which needs to be set during
initialization

DeviceAddressAndName is an enum with two cases :

* alreadyConnectedBefore in which case we add the address and name as stored in the settings or database.
The app will only connected to a device if it has the same address.

* notYetConnected if we have an expected name, then it's added, if we don't then we pass nil<br>
The app will connected to a device if the name starts with the expected name, or in case the expected name is nil, it will connect

#### <a name="cbuuidadvertisement"></a>CBUUID\_Advertisement
optional<br>
If not nil then the app will scan for devices that advertise with this specific UUID.
The advantage of scanning with advertisement UUID is that the app can also scan while in the background.

#### <a name="cbuuidservice"></a>CBUUID_Service

The service UUID

#### <a name="cbuuidreceivecharacteristic"></a>CBUUID\_ReceiveCharacteristic

receive characteristic UUID, the BlueToothTransmitter class will take care of subscribing to it

#### <a name="cbuuidwritecharacteristic"></a>CBUUID\_WriteCharacteristic

write characteristic UUID

## <a name="protocolcgmtransmitterdelegate"></a>add a property of type CGMTransmitterDelegate

The new transmitter class needs to store a property of type CGMTransmitterDelegate<br>
This is used to pass back information to the controller<br>

Functions in CGMTransmitterDelegate:

### <a name="cgmTransmitterDidConnect"></a>cgmTransmitterDidConnect

When the transmitter is connected<br>
This will typically be called in centralManagerDidConnect, however it could be that the class decides to call this at a
later stage, for example when subscribing to receive characteristic is done.

### <a name="cgmTransmitterDidDisconnect"></a>cgmTransmitterDidDisconnect

When the transmitter is disconnected<br>
This will typically be called in centralManagerDidDisConnect

### <a name="didUpdateBluetoothState"></a>didUpdateBluetoothState

When the bluetooth status changes<br>
This will typically be called in centralManagerDidUpdateState

### <a name="newSensorDetected"></a>newSensorDetected

When a new sensor is detected, only applicable to transmitters that have this functionality

### <a name="sensorNotDetected"></a>sensorNotDetected

When a sensor is not detected, only applicable to transmitters that have this functionality

### <a name="newReadingsReceived"></a>newReadingsReceived

This is the most important function, it passes new readings to the delegate

### <a name="transmitterNeedsPairing"></a>transmitterNeedsPairing

The transmitter needs pairing, app should give warning to user to keep the app in the foreground

# <a name="functionsandpropertiesavailableintransmitterclasses"></a>Functions and properties available in transmitter classes

## <a name="functionsinbluetoothtransmitterclasses"></a>Functions in BluetoothTransmitter classes

### <a name="disconnect"></a>disconnect

will call centralManager.cancelPeripheralConnection

### <a name="startScanning"></a>startScanning

Will scan for the device.<br>
This should only be used the first time the app connects to a specific device and should not be done for transmittertypes that 
start scanning at initialization<br>
//TODO: needs more clarification

### <a name="writeDataToPeripheral"></a>writeDataToPeripheral(data:Data, type:CBCharacteristicWriteType)  -> Bool

calls peripheral.writeValue for characteristic CBUUID\_WriteCharacteristic

### <a name="writeDataToPeripheral"></a>writeDataToPeripheral(data:Data, characteristicToWriteTo:CBCharacteristic, type:CBCharacteristicWriteType)  -> Bool

calls peripheral.writeValue for characteristic that is given as argment : characteristicToWriteTo

### <a name="setNotifyValuefunc"></a>setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)

calls setNotifyValue for characteristic with value enabled

## <a name="propertiesinbluetoothtransmitterclasses"></a>Properties in BluetoothTransmitter classes

### <a name="address"></a>address

the peripheral address, available after successfully connecting

### <a name="name"></a>name

the peripheral name, available after successfully connecting

## <a name="functionsincgmtransmitterclasses"></a>Functions in CGM Transmitter classes

### <a name="canDetectNewSensor"></a>canDetectNewSensor

can the cgm transmitter detect a new sensor ?

# <a name="availablecgmtransmitterclasses"></a>Available CGM transmitter classes

## <a name="MiaoMiao"></a>MiaoMiao 

MiaoMiao transmitter is fully implemented

## <a name="xDripG4"></a>xDripG4

xDripG4 transmitter is fully implemented

