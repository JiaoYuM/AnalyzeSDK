//
//  VHReachability.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/25.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>

#import <CoreFoundation/CoreFoundation.h>

#import "VHReachability.h"


NSString *kVHReachabilityChangedNotification = @"kVHNetworkReachabilityChangedNotification";

@implementation VHReachability {
    SCNetworkReachabilityRef _reachabilityRef;

}

+(instancetype)reachabilityWithHostName:(NSString *)hostName{
    VHReachability *returnValue = NULL;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);

    if (reachability != NULL) {
        returnValue = [[self alloc] init];
        if (returnValue != NULL) {
            returnValue->_reachabilityRef = reachability;
        }else {
            CFRelease(reachability);
        }
    }
    return returnValue;
}

+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress);

    VHReachability* returnValue = NULL;

    if (reachability != NULL)
    {
        returnValue = [[self alloc] init];
        if (returnValue != NULL)
        {
            returnValue->_reachabilityRef = reachability;
        }
        else {
            CFRelease(reachability);
        }
    }
    return returnValue;
}

+ (instancetype)reachabilityForInternetConnection
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;

    return [self reachabilityWithAddress: (const struct sockaddr *) &zeroAddress];
}


#pragma mark - Network Flag Handling
- (VHNetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // The target host is not reachable.
        return VHNotReachable;
    }

    VHNetworkStatus returnValue = VHNotReachable;

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0){
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        returnValue = VHReachableWifi;
    }

    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = VHReachableWifi;
        }
    }

    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        returnValue = VHReachableWWAN;
    }

    return returnValue;
}


- (VHNetworkStatus)currentReachabilityStatus
{
    NSAssert(_reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
    VHNetworkStatus returnValue = VHNotReachable;
    SCNetworkReachabilityFlags flags;

    if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
    {
        returnValue = [self networkStatusForFlags:flags];
    }

    return returnValue;
}

- (void)dealloc
{
    if (_reachabilityRef != NULL)
    {
        CFRelease(_reachabilityRef);
    }
}
@end
