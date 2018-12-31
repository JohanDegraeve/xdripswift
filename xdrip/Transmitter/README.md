* <b>Generic/BluetoothTransmitter.swift</b>

Setting up a connection to a ble device is usually the same process : discover peripheral, connect, discover services, discover characteristics,
subscribe to notify characteristic. Only after that data is exchanged.

Those steps are all be done by the same class : BluetoothTransmitter which implements the protocols CBCentralManagerDelegate and CBPeripheralDelegate
 

For any new type of transmitter, create a new class that inherits from BluetoothTransmitter

Each of the functions in the protocols CBCentralManagerDelegate and CBPeripheralDelegatecan be overriden by the inheriting class.
It's better to first call the same function in the super class.

For example

<font color="purple">func</font> centralManager(_ central: <font color="purple">CBCentralManager</font>, didConnect peripheral: <font color="purple">CBPeripheral</font>) 
is implemented in BluetoothTransmitter, it will continue with the next step which is to discover services.

But an inheriting class might override this on order to inform the user that the connection is made (via delegate)
So an inheriting class can override the function, first call the function in the super class and then do what is needed.

* <b>Generic/CGMTransmitterDelegate</b>

A specific transmitter will send info to a delegate via the protocol CGMTransmitterDelegate

Example<br>
<font color="purple">func</font> cgmTransmitterdidConnect()

The specific class will decide when to call that function. For MiaoMiao this would be when didConnect is called. For an xdrip i prefer to do this only later.

It also has functions to pass received readings back to the delegate.

* <b>Specific</b>

Specific transmitters are defined in this folder. One for xdrip, MiaoMiao, G5, ...<br>

Any class or anybody who wants to create a specific transmitter needs to implement the protocol CGMTransmitterDelegate and instantiate the specific transmitter class





