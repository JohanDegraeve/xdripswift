//
//  SystemInfoHelper.h
//  CriolloApp
//
//  Created by Cătălin Stan on 05/04/16.
//  Copyright © 2016 Cătălin Stan. All rights reserved.
//

@import Foundation;

#define CRBundleIdentifier          @"io.criollo.Criollo"
#define CRCriolloVersionFallback    @"0.1.12"

NS_ASSUME_NONNULL_BEGIN

@interface SystemInfoHelper : NSObject

+ (NSString *)IPAddress;
+ (NSString *)systemInfo;
+ (NSString *)systemVersion;
+ (NSString *)processName;
+ (NSString *)processRunningTime;
+ (NSString *)memoryInfo:(NSError * _Nullable __autoreleasing *)error;
+ (NSString *)requestsServed;
+ (void)addRequest;
+ (NSString *)criolloVersion;
+ (NSString *)bundleVersion;

@end

NS_ASSUME_NONNULL_END