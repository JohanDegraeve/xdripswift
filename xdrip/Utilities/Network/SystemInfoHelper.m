//
//  SystemInfoHelper.m
//  CriolloApp
//
//  Created by Cătălin Stan on 05/04/16.
//  Copyright © 2016 Cătălin Stan. All rights reserved.
//

#import "SystemInfoHelper.h"

#include <stdio.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <sys/utsname.h>
#include <mach/mach.h>


@implementation SystemInfoHelper {
}

static NSDate *processStartTime;
static NSUInteger requestsServed;
static dispatch_queue_t backgroundQueue;

+ (void)initialize {
    processStartTime = [NSDate date];
    requestsServed = 0;
    backgroundQueue = dispatch_queue_create([NSStringFromClass(self.class) stringByAppendingString:@"-SystemInfoHelperQueue"].UTF8String, DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(backgroundQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
}

+ (NSString *)IPAddress {
    static NSString* address = @"127.0.0.1";
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct ifaddrs *interfaces = NULL;
        struct ifaddrs *temp_addr = NULL;
        int success = 0;
        success = getifaddrs(&interfaces);
        if (success == 0) {
            temp_addr = interfaces;
            while(temp_addr != NULL) {
                if(temp_addr->ifa_addr->sa_family == AF_INET) {
                    if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                        address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    }
                }
                temp_addr = temp_addr->ifa_next;
            }
        }
        freeifaddrs(interfaces);
    });
    return address;
}

+ (NSString *)systemInfo {
    static NSString* systemInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname unameStruct;
        uname(&unameStruct);
        systemInfo = [NSString stringWithFormat:@"%s %s %s %s %s", unameStruct.sysname, unameStruct.nodename, unameStruct.release, unameStruct.version, unameStruct.machine];
    });
    return systemInfo;
}

+ (NSString *)systemVersion {
    static NSString* publicSystemInfo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname unameStruct;
        uname(&unameStruct);
        publicSystemInfo = [NSString stringWithFormat:@"%s %s/%s", unameStruct.sysname, unameStruct.release, unameStruct.machine];
    });
    return publicSystemInfo;
}

+ (NSString *)processName {
    static NSString* processName;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processName = [NSProcessInfo processInfo].processName;
    });
    return processName;
}

+ (NSString *)processRunningTime {
    NSTimeInterval processRunningTime = processStartTime.timeIntervalSinceNow;
    NSString* processRunningTimeString;

    static NSDateComponentsFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateComponentsFormatter alloc] init];
        formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
        formatter.includesApproximationPhrase = YES;
        formatter.includesTimeRemainingPhrase = NO;
        formatter.allowedUnits = NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond|NSCalendarUnitDay|NSCalendarUnitMonth|NSCalendarUnitYear;
    });

    processRunningTimeString = [formatter stringFromTimeInterval:fabs(processRunningTime)];
    return processRunningTimeString.lowercaseString;
}

+ (NSString *)memoryInfo:(NSError * _Nullable __autoreleasing *)error {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if( kerr == KERN_SUCCESS ) {
        return [NSByteCountFormatter stringFromByteCount:info.resident_size countStyle:NSByteCountFormatterCountStyleMemory];
    } else {
        if ( *error ) {
            *error = [NSError errorWithDomain:[NSProcessInfo processInfo].processName code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s",mach_error_string(kerr)]}];
        }
        return @"";
    }
}

+ (void)addRequest {
    dispatch_async(backgroundQueue, ^{
        requestsServed++;
    });
}

+ (NSString *)requestsServed {
    static NSNumberFormatter* formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.maximumFractionDigits = 1;
    });
    NSArray<NSString *> * units = @[@"", @"K", @"M", @"B", @"trillion", @"quadrillion", @"quintillion", @"quintillion", @"sextilion", @"septillion", @"octillion", @"nonillion", @"decillion", @"undecillion", @"duodecillion", @"tredecillion", @"quatttuor-decillion", @"quindecillion", @"sexdecillion", @"septen-decillion", @"octodecillion", @"novemdecillion", @"vigintillion"];

    __block double requestCount = requestsServed;
    //    __block double requestCount = INT64_MAX;
    __block NSString *unit = @"";

    if ( requestCount >= pow(1000, units.count) ) {
        requestCount = requestCount / pow(1000, units.count - 1);
        unit = units.lastObject;
    } else {
        [units enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            unit = obj;
            if ( requestCount < pow(1000, idx + 1) ) {
                requestCount = requestCount / pow(1000, idx);
                *stop = YES;
            }
        }];
    }

    return [NSString stringWithFormat:@"about %@%@%@", [formatter stringFromNumber:@(requestCount)], unit.length > 0 ? @" " : @"", unit];
}

+ (NSString *)criolloVersion {
    static NSString* criolloVersion;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *criolloBundle = [NSBundle bundleWithIdentifier:CRBundleIdentifier];
        criolloVersion = [criolloBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if ( criolloVersion == nil ) {
            criolloVersion = CRCriolloVersionFallback;
        }
    });
    return criolloVersion;
}

+ (NSString *)bundleVersion {
    static NSString* bundleVersion;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        bundleVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    });
    return bundleVersion;
}

@end
