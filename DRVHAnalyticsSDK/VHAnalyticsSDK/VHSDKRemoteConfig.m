//
//  VHSDKRemoteConfig.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/23.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "VHSDKRemoteConfig.h"
//判断autoTrackMode是否为有效数据
BOOL isAutoTrackModeValid(NSInteger autoTrackMode) {
    BOOL valid = NO;
    if (autoTrackMode >= kVHAutoTrackModeDefault && autoTrackMode <= kVHAutoTrackModeEnabledAll) {
        valid = YES;
    }
    return valid;
}

@interface VHSDKRemoteConfig ()

@end

@implementation VHSDKRemoteConfig
+ (instancetype)configWithDict:(NSDictionary *)dict{
    return [[self alloc]initWithDict:dict];
}
-(instancetype)initWithDict:(NSDictionary *)dict{
    if (self = [super init]) {
        self.autoTrackMode = kVHAutoTrackModeDefault;
        self.v = [dict valueForKey:@"v"];
        self.disableSDK = [[dict valueForKeyPath:@"configs.disableSDK"] boolValue];
        self.disableDebugMode = [[dict valueForKeyPath:@"configs.disableDebugMode"] boolValue];
        NSNumber *autoTrackMode = [dict valueForKeyPath:@"configs.autoTrackMode"];
        if (autoTrackMode != nil) {
            NSInteger iMode = autoTrackMode.integerValue;
            if (isAutoTrackModeValid(iMode)) {
                self.autoTrackMode = iMode;
            }
        }
    }
    return self;
}


@end
