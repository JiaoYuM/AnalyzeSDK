//
//  VHLogger.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/23.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef __DRVHAnalyticsSDK__VHLogger__
#define __DRVHAnalyticsSDK__VHLogger__
#define VHLogLevel(lvl,fmt,...)\
[VHLogger log : YES                                      \
level : lvl                                                  \
file : __FILE__                                            \
function : __PRETTY_FUNCTION__                       \
line : __LINE__                                           \
format : (fmt), ## __VA_ARGS__]

#define VHLog(fmt,...)\
VHLogLevel(VHLoggerLevelInfo,(fmt), ## __VA_ARGS__)

#define VHError VHLog
#define VHDebug VHLog

#endif/* defined(__DRVHAnalyticsSDK__VHLogger__) */
typedef NS_ENUM(NSUInteger,VHLoggerLevel){
    VHLoggerLevelInfo = 1,
    VHLoggerLevelWarning ,
    VHLoggerLevelError ,
};
@interface VHLogger : NSObject
@property(class , readonly, strong) VHLogger *sharedInstance;
+ (BOOL)isLoggerEnabled;
+ (void)enableLog:(BOOL)enableLog;
+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... ;

@end

NS_ASSUME_NONNULL_END
