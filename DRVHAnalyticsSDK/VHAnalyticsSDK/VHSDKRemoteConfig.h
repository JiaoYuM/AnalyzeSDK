//
//  VHSDKRemoteConfig.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/23.
//  Copyright © 2018年 viewhigh. All rights reserved.
//  远程控制 SDK的可使用性

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSInteger kVHAutoTrackModeDefault = -1;//-1，表示不修改现有的 autoTrack 方式 。0 代表禁用所有的 autoTrack 。其他 1～15 为合法数据
static NSInteger kVHAutoTrackModeDisabledAll = 0;
static NSInteger kVHAutoTrackModeEnabledAll = 15;

BOOL isAutoTrackModeValid(NSInteger autoTrackMode);

@interface VHSDKRemoteConfig : NSObject

@property(nonatomic,copy)NSString *v;
@property(nonatomic,assign)BOOL disableSDK;
@property(nonatomic,assign)BOOL disableDebugMode;
@property(nonatomic,assign)NSInteger autoTrackMode;

+ (instancetype)configWithDict:(NSDictionary *)dict;
- (instancetype)initWithDict:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
