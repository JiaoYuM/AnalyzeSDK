//
//  VHReachability.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/25.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

//判断网络
typedef enum : NSUInteger {
    VHNotReachable = 0,
    VHReachableWifi,
    VHReachableWWAN,
} VHNetworkStatus;

extern NSString *kVHReachabilityChangedNotification;

@interface VHReachability : NSObject


+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*!
 * Use to check the reachability of a given IP address.
 */
+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress;

/*!
 * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
 */
+ (instancetype)reachabilityForInternetConnection;


- (VHNetworkStatus)currentReachabilityStatus;


@end


