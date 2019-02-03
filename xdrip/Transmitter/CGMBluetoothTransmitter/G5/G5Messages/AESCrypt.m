//
//  AESCrypt.m
//  xDripG5
//
//  Created by Nate Racklyeft on 6/17/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

#import "AESCrypt.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation AESCrypt

+ (NSData *)encryptData:(NSData *)data usingKey:(NSData *)key error:(NSError * _Nullable __autoreleasing *)error
{
    NSMutableData *dataOut = [NSMutableData dataWithLength: data.length + kCCBlockSizeAES128];

    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES,
                                     kCCOptionECBMode,
                                     key.bytes,
                                     key.length,
                                     NULL,
                                     data.bytes,
                                     data.length,
                                     dataOut.mutableBytes,
                                     dataOut.length,
                                     NULL);

    return status == kCCSuccess ? dataOut : nil;
}

@end
