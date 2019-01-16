The algorithms folder has protocols and classes which define the Calibration.

Only algorithms, no data storage.
Also no read of access to data defined in other classes, the necessary data is passed when calling the functions.

CalibratorProtocol.swift

<b>protocol CalibratorProtocol</b><br>

Defines variables en functions.<br>
The variables need to be adopted by class that conform to the protocol.<br>
The variables are typical sensor type depenent :<br>

* <font color="#AC3EA4">var</font> sParams:<font color="#516374">SlopeParameters</font>{<font color="#AC3EA4">get</font>}<br>  //this variable defines sParams for type of sensor<br>
* <font color="#AC3EA4">var</font> ageAdjustMentNeeded:<font color="purple">Bool</font>{<font color="#AC3EA4">get</font>}<br> //age adjustment needed or not, which is not the case for Libre
<br>


<b>extension CalibratorProtocol</b><br>
The functions in the protocol are implemented in the extension CalibratorProtocol:<br>

* initialCalibration<br>
* createNewBgReading<br>
* createNewCalibration<br>

For a new type of Sensor (only Libre and Dexcom at the moment), a new class needs to be created that conforms to the protocol CalibratorProtocol and then defines only the variables sParams and ageAdjustMentNeeded.<br>
For the moment only Libre1Calibrator.swift exists
