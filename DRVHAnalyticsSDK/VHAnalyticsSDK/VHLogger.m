//
//  VHLogger.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/23.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "VHLogger.h"
static BOOL __enableLog__ ;
static dispatch_queue_t __logQueue__ ;

@implementation VHLogger
+ (void)initialize {
    __enableLog__ = NO;
    __logQueue__ = dispatch_queue_create("com.DRVHAnalytics.log", DISPATCH_QUEUE_SERIAL);
}
+ (BOOL)isLoggerEnabled {
    __block BOOL enable = NO;
    dispatch_sync(__logQueue__, ^{
        enable = __enableLog__;
    });
    return enable;
}

+ (void)enableLog:(BOOL)enableLog {
    dispatch_sync(__logQueue__, ^{
        __enableLog__ = enableLog;
    });
}

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... {

    //iOS 10.x 有可能触发 [[NSString alloc] initWithFormat:format arguments:args]  crash ，不在启用 Log
    NSInteger systemName = UIDevice.currentDevice.systemName.integerValue;
    if (systemName == 10) {
        return;
    }
    @try{
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self.sharedInstance log:asynchronous message:message level:level file:file function:function line:line];
        va_end(args);
    } @catch(NSException *e){

    }
}

- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line {
    @try{
        NSString *logMessage = [[NSString alloc]initWithFormat:@"[VHLog][%@]  %s [line %lu]    %s %@",[self descriptionForLevel:level],function,(unsigned long)line,[@"" UTF8String],message];
        if ([VHLogger isLoggerEnabled]) {
            NSLog(@"%@",logMessage);
        }
    } @catch(NSException *e){

    }
}

-(NSString *)descriptionForLevel:(VHLoggerLevel)level {
    NSString *desc = nil;
    switch (level) {
        case VHLoggerLevelInfo:
            desc = @"INFO";
            break;
        case VHLoggerLevelWarning:
            desc = @"WARN";
            break;
        case VHLoggerLevelError:
            desc = @"ERROR";
            break;
        default:
            desc = @"UNKNOW";
            break;
    }
    return desc;
}

- (void)dealloc {

}
@end
