import Foundation

/// static functions for Blucon
class BluconUtilities {
    
    /*public static func decodeSerialNumber(input: Data) -> String{
     
    let uuidShort = Data(bytes: <#T##Sequence#>)//new byte[]{0, 0, 0, 0, 0, 0, 0, 0};
    int i;
    
    for (i = 2; i < 8; i++) uuidShort[i - 2] = input[(2 + 8) - i];
    uuidShort[6] = 0x00;
    uuidShort[7] = 0x00;
    
    String binary = "";
    String binS = "";
    for (i = 0; i < 8; i++) {
    binS = String.format("%8s", Integer.toBinaryString(uuidShort[i] & 0xFF)).replace(' ', '0');
    binary += binS;
    }
    
    String v = "0";
    char[] pozS = {0, 0, 0, 0, 0};
    for (i = 0; i < 10; i++) {
    for (int k = 0; k < 5; k++) pozS[k] = binary.charAt((5 * i) + k);
    int value = (pozS[0] - '0') * 16 + (pozS[1] - '0') * 8 + (pozS[2] - '0') * 4 + (pozS[3] - '0') * 2 + (pozS[4] - '0') * 1;
    v += lookupTable[value];
    }
    Log.e(TAG, "decodeSerialNumber=" + v);
    
    return v;
    }*/

}

fileprivate let lookupTable = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                                 "A", "C", "D", "E", "F", "G", "H", "J", "K", "L",
                                 "M", "N", "P", "Q", "R", "T", "U", "V", "W", "X",
                                 "Y", "Z"]
