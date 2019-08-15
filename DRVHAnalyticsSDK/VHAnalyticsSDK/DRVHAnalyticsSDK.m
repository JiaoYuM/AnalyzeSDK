//
//  DRVHAnalyticsSDK.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/8.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "DRVHAnalyticsSDK.h"

#import <objc/runtime.h>
#include <sys/sysctl.h>
#include <stdlib.h>

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIScreen.h>

#import "VHLogger.h"
#import "NSObject+VHSwizzle.h"
#import "DRVHHandleSqliteData.h"
#import "VHReachability.h"
#import "VHGzipUtility.h"
#import "NSString+HashCode.h"
#import "AutoTrackExtendsion.h"
#import "UIViewController+AutoTrack.h"
#import "UIApplication+AutoTrack.h"

#define VERSION @"1.0.0"
#define PROPERTY_LENGTH_LIMITATION 8191
#define BUSSINESS_TYPE @"1"     //业务相关
#define COMMON_TYPE @"2"        //公共事件

// 自动追踪相关事件及属性
// App 启动或激活
static NSString* const APP_START_EVENT = @"$AppStart";
// App 退出或进入后台
static NSString* const APP_END_EVENT = @"AppEnd";
// App 浏览页面
static NSString* const APP_VIEW_SCREEN_EVENT = @"$PageDuration";
// App 首次启动
static NSString* const APP_FIRST_START_PROPERTY = @"$is_first_time";
// App 是否从后台恢复
static NSString* const RESUME_FROM_BACKGROUND_PROPERTY = @"$resume_from_background";
// App 浏览页面名称
static NSString* const SCREEN_NAME_PROPERTY = @"$screen_name";
// App 浏览页面 Url
static NSString* const SCREEN_URL_PROPERTY = @"$url";
// App 浏览页面 Referrer Url
static NSString* const SCREEN_REFERRER_URL_PROPERTY = @"$referrer";
//中国运营商 mcc 标识
static NSString* const CARRIER_CHINA_MCC = @"460";

static DRVHAnalyticsSDK *sharedInstance = nil;

@interface DRVHAnalyticsSDK ()
@property (atomic,copy)NSString *serverURL;
@property (atomic,copy)NSString *userId;
@property (atomic,copy)NSString *hospitalId;
@property (atomic,copy)NSString *firstDay;
@property (nonatomic,strong) dispatch_queue_t serialQueue;
@property (atomic,strong)NSDictionary *automaticProperties;
@property (atomic,strong)NSDictionary *superProperties;
@property (nonatomic, strong) NSMutableDictionary *trackTimer;
@property (nonatomic, strong) NSPredicate *regexTestName;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSDictionary *requestHeaders;
@property (nonatomic, strong) DRVHHandleSqliteData *sqliteDataQueue;
//用户设置的不被AutoTrack的Controllers
@property (nonatomic, strong) NSMutableArray *ignoredViewControllers;
@property (nonatomic, strong) NSMutableArray *heatMapViewControllers;
@property (nonatomic, strong) NSMutableArray *ignoredViewTypeList;

@property (nonatomic, copy) void(^reqConfigBlock)(BOOL success , NSDictionary *configDict);
@property (nonatomic, assign) NSUInteger pullSDKConfigurationRetryMaxCount;
@property (nonatomic,copy) NSDictionary<NSString *,id> *(^dynamicSuperProperties)(void);
///是否为被动启动
@property(nonatomic, assign, getter=isLaunchedPassively) BOOL launchedPassively;


@end

@implementation UIImage (DRVHAnalytics)
- (NSString *)vhAnalyticsImageName {
    return objc_getAssociatedObject(self, @"vhAnalyticsImageName");
}

- (void)setVhAnalyticsImageName:(NSString *)vhAnalyticsImageName {
    objc_setAssociatedObject(self, @"vhAnalyticsImageName", vhAnalyticsImageName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
@end
@implementation UIView (DRVHAnalytics)
- (UIViewController *)viewController {
    UIResponder *next = [self nextResponder];
    do {
        if ([next isKindOfClass:[UIViewController class]]) {
            UIViewController *v = (UIViewController *)next;
            if (v.parentViewController) {
                if ([v.parentViewController isKindOfClass:[UIViewController class]] &&
                    ![v.parentViewController isKindOfClass:[UITabBarController class]] &&
                    ![v.parentViewController isKindOfClass:[UINavigationController class]] ) {
                    next = v.parentViewController;
                } else {
                    return v;
                }
            } else {
                return (UIViewController *)next;
            }
        }
        next = [next nextResponder];
    } while (next != nil);
    return nil;
}

//viewID
- (NSString *)VHAnalyticsViewID {
    return objc_getAssociatedObject(self, @"VHAnalyticsViewID");
}

- (void)setVHAnalyticsViewID:(NSString *)VHAnalyticsViewID {
    objc_setAssociatedObject(self, @"VHAnalyticsViewID", VHAnalyticsViewID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

//ignoreView
- (BOOL)VHAnalyticsIgnoreView {
    return [objc_getAssociatedObject(self, @"VHAnalyticsIgnoreView") boolValue];
}

- (void)setVHAnalyticsIgnoreView:(BOOL)VHAnalyticsIgnoreView {
    objc_setAssociatedObject(self, @"VHAnalyticsIgnoreView", [NSNumber numberWithBool:VHAnalyticsIgnoreView], OBJC_ASSOCIATION_ASSIGN);
}

//afterSendAction
- (BOOL)VHAnalyticsAutoTrackAfterSendAction {
    return [objc_getAssociatedObject(self, @"VHAnalyticsAutoTrackAfterSendAction") boolValue];
}

- (void)setVHAnalyticsAutoTrackAfterSendAction:(BOOL)VHAnalyticsAutoTrackAfterSendAction {
    objc_setAssociatedObject(self, @"VHAnalyticsAutoTrackAfterSendAction", [NSNumber numberWithBool:VHAnalyticsAutoTrackAfterSendAction], OBJC_ASSOCIATION_ASSIGN);
}

//viewProperty
- (NSDictionary *)VHAnalyticsViewProperties {
    return objc_getAssociatedObject(self, @"VHAnalyticsViewProperties");
}

- (void)setVHAnalyticsViewProperties:(NSDictionary *)VHAnalyticsViewProperties {
    objc_setAssociatedObject(self, @"VHAnalyticsViewProperties", VHAnalyticsViewProperties, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)VHAnalyticsDelegate {
    return objc_getAssociatedObject(self, @"VHAnalyticsDelegate");
}

- (void)setVHAnalyticsDelegate:(id)VHAnalyticsDelegate {
    objc_setAssociatedObject(self, @"VHAnalyticsDelegate", VHAnalyticsDelegate, OBJC_ASSOCIATION_ASSIGN);
}
@end

@implementation DRVHAnalyticsSDK {
    BOOL _disableSDK;
    ViewHighAnalyticsDebugMode _debugMode;
    UInt64 _uploadMaxSize;
    UInt64 _uploadInterval;
    UInt64 _maxCacheSize;
    NSDateFormatter *_dateFormater;
    BOOL _autoTrack;                    // 自动采集事件
    BOOL _appRelaunched;                // App 从后台恢复
    BOOL _showDebugAlertView;
    BOOL _heatMap;
    UInt8 _debugAlertViewHasShownNumber;
    NSString *_referrerScreenUrl;
    NSDictionary *_lastScreenTrackProperties;
    BOOL _applicationWillResignActive;
    BOOL _clearReferrerWhenAppEnd;
    ViewHighAnalyticsAutoTrackEventType _autoTrackEventType;
    ViewHighAnalyticsNetworkType  _networkTypePolicy;
    NSString *_deviceModel;
    NSString *_osVersion;
    NSString *_userAgent;
    NSString *_originServerUrl;
    NSString *_cookie;
}

#pragma mark -- init

+ (UInt64)getCurrentTime {
    UInt64 time = [[NSDate date] timeIntervalSince1970] * 1000;
    return time;
}
//获取系统时间
+ (UInt64)getSystemUpTime {
    UInt64 time = NSProcessInfo.processInfo.systemUptime * 1000;
    return time;
}

+(DRVHAnalyticsSDK *)sharedInstanceWithServerURL:(NSString *)serverURL andLaunchOptions:(NSDictionary *)launchOptions andDebugMode:(ViewHighAnalyticsDebugMode)debugMode {

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super alloc] initWithServerUrl:serverURL andLaunchOptions:launchOptions andDebugMode:debugMode];
    });
    return sharedInstance;
}
+(DRVHAnalyticsSDK *)sharedInstance{
    return sharedInstance;
}

-(instancetype)initWithServerUrl:(NSString *)serverUrl andLaunchOptions:(NSDictionary *)launchOptions andDebugMode:(ViewHighAnalyticsDebugMode)debugMode{
    @try {
        if (self = [self init]) {
            //默认不追踪任何事件
            _autoTrackEventType = ViewHighAnalyticsEventTypeNone;
            _networkTypePolicy = ViewHighAnalyticsNetworkType3G | ViewHighAnalyticsNetworkType4G | ViewHighAnalyticsNetworkTypeWIFI;
            if ([[NSThread currentThread] isMainThread]) {
                [self configLaunchedPassivelyWithLaunchOptions:launchOptions];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self configLaunchedPassivelyWithLaunchOptions:launchOptions];
                });
            }

            _debugMode = debugMode;
            [self enableLog];
            [self setServerUrl:serverUrl];

    
            //一些默认的规则设置
            //每次上传数据的最小间隔时间
            _uploadInterval = 15 * 1000;
            //每次上传的最大数据条数
            _uploadMaxSize = 100;
            //本地最大缓存条数
            _maxCacheSize = 10000;
            _disableSDK = NO;
            //默认不打开自动追踪
            _autoTrack = NO;
//            _heatMap = NO;
            _appRelaunched = NO;
            _showDebugAlertView = YES;
            _debugAlertViewHasShownNumber = 0;

//            _referrerScreenUrl = nil;
//            _lastScreenTrackProperties = nil;
            _applicationWillResignActive = NO;
            _clearReferrerWhenAppEnd = NO;
//            _pullSDKConfigurationRetryMaxCount = 3;// SDK 开启关闭功能接口最大重试次数

            _ignoredViewControllers = [[NSMutableArray alloc] init];
            _ignoredViewTypeList = [[NSMutableArray alloc] init];
            _heatMapViewControllers = [[NSMutableArray alloc] init];
            _dateFormater = [[NSDateFormatter alloc] init];
            [_dateFormater setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            //退到后台时上传一次
            self.uploadBeforeEnterBackground = YES;
            NSString *filepath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"DRVHAnalyticsMessage-v2.db"];
            self.sqliteDataQueue = [[DRVHHandleSqliteData alloc] initWithFilePath:filepath];
            if (self.sqliteDataQueue == nil) {
                VHError(@"SqliteException: init Message Queue in Sqlite fail");
            }
            //取上一次进程退出时保存的信息
            [self unarchive];

            if (self.firstDay == nil) {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                self.firstDay = [dateFormatter stringFromDate:[NSDate date]];
                [self archiveFirstDay];
            }

            self.automaticProperties = [self collectAutomaticProperties];

            self.trackTimer = [NSMutableDictionary dictionary];

            NSString *label = [NSString stringWithFormat:@"com.drvhdata.%@.%p", @"test", self];
            self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);

            [self setUpListeners];

            //捕获APPViewScreen & APPClick
            [self hockAllControllerViewAndClick];

            NSString *logMessage = nil;
            logMessage = [NSString stringWithFormat:@"%@ initialized the instance of  DRVHAnalytics SDK with server url '%@', debugMode: '%@'",
                          self, serverUrl, [self debugModeToString:debugMode]];
            VHLog(@"%@", logMessage);
            //打开debug模式，弹出提示
#ifndef VIEWHIGH_ANALYTICS_DISABLE_DEBUG_WARNING
            if (_debugMode != ViewHighAnalyticsDebugOff) {
                NSString *alertMessage = nil;
                if (_debugMode == ViewHighAnalyticsDebugOnly) {
                    alertMessage = @"现在您打开了'DEBUG_ONLY'模式，此模式下只校验数据但不导入数据，数据出错时会以提示框的方式提示开发者，请上线前一定关闭。";
                } else if (_debugMode == ViewHighAnalyticsDebugAndTrack) {
                    alertMessage = @"现在您打开了'DEBUG_AND_TRACK'模式，此模式下会校验数据并且导入数据，数据出错时会以提示框的方式提示开发者，请上线前一定关闭。";
                }
//                [self showDebugModeWarning:alertMessage withNoMoreButton:NO];
            }
#endif
        }
    } @catch (NSException *exception) {
        VHError(@"%@ error: %@", self, exception);
    }
    return self;
}
-(void)configLaunchedPassivelyWithLaunchOptions:(NSDictionary *)launchOptions{
    UIApplicationState applicationState = UIApplication.sharedApplication.applicationState;
    //远程通知启动 位置变动启动
    if ([launchOptions.allKeys containsObject:UIApplicationLaunchOptionsRemoteNotificationKey] ||
        [launchOptions.allKeys containsObject:UIApplicationLaunchOptionsLocationKey]) {
        if (applicationState == UIApplicationStateBackground) {
            self.launchedPassively = YES;
        }
    }
}
//当前的debug模式
- (NSString *)debugModeToString:(ViewHighAnalyticsDebugMode)debugMode {
    NSString *modeStr = nil;
    switch (debugMode) {
        case ViewHighAnalyticsDebugOff:
            modeStr = @"DebugOff";
            break;
        case ViewHighAnalyticsDebugAndTrack:
            modeStr = @"DebugAndTrack";
            break;
        case ViewHighAnalyticsDebugOnly:
            modeStr = @"DebugOnly";
            break;
        default:
            modeStr = @"Unknown";
            break;
    }
    return modeStr;
}
//debug模式下弹出提示信息
- (void)showDebugModeWarning:(NSString *)message withNoMoreButton:(BOOL)showNoMore {
#ifndef VIEWHIGH_ANALYTICS_DISABLE_DEBUG_WARNING
    if (_debugMode == ViewHighAnalyticsDebugOff) {
        return;
    }

    if (!_showDebugAlertView) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self->_debugAlertViewHasShownNumber >= 3) {
                return;
            }
            self->_debugAlertViewHasShownNumber += 1;
            NSString *alertTitle = @"重要提示";
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
                UIAlertController *connectAlert = [UIAlertController
                                                   alertControllerWithTitle:alertTitle
                                                   message:message
                                                   preferredStyle:UIAlertControllerStyleAlert];

                UIWindow *alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                [connectAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    alertWindow.hidden = YES;
                    self->_debugAlertViewHasShownNumber -= 1;
                }]];
                if (showNoMore) {
                    [connectAlert addAction:[UIAlertAction actionWithTitle:@"不再显示" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        alertWindow.hidden = YES;
                        self->_showDebugAlertView = NO;
                    }]];
                }

                alertWindow.rootViewController = [[UIViewController alloc] init];
                alertWindow.windowLevel = UIWindowLevelAlert + 1;
                alertWindow.hidden = NO;
                [alertWindow.rootViewController presentViewController:connectAlert animated:YES completion:nil];
            } else {
                UIAlertView *connectAlert = nil;
                if (showNoMore) {
                    connectAlert = [[UIAlertView alloc] initWithTitle:alertTitle message:message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:@"不再显示",nil, nil];
                } else {
                    connectAlert = [[UIAlertView alloc] initWithTitle:alertTitle message:message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                }
                [connectAlert show];
            }
        } @catch (NSException *exception) {
        } @finally {
        }
    });
#endif
}

- (NSDictionary *)collectAutomaticProperties {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    UIDevice *device = [UIDevice currentDevice];
    _deviceModel = [self deviceModel];
    _osVersion = [device systemVersion];
    struct CGSize size = [UIScreen mainScreen].bounds.size;
    CTCarrier *carrier = [[[CTTelephonyNetworkInfo alloc] init] subscriberCellularProvider];
    // Use setValue semantics to avoid adding keys where value can be nil.
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"$app_version"];
    if (carrier != nil) {
        NSString *networkCode = [carrier mobileNetworkCode];
        NSString *countryCode = [carrier mobileCountryCode];

        NSString *carrierName = nil;
        //中国运营商
        if (countryCode && [countryCode isEqualToString:CARRIER_CHINA_MCC]) {
            if (networkCode) {

                //中国移动
                if ([networkCode isEqualToString:@"00"] || [networkCode isEqualToString:@"02"] || [networkCode isEqualToString:@"07"] || [networkCode isEqualToString:@"08"]) {
                    carrierName= @"中国移动";
                }
                //中国联通
                if ([networkCode isEqualToString:@"01"] || [networkCode isEqualToString:@"06"] || [networkCode isEqualToString:@"09"]) {
                    carrierName= @"中国联通";
                }
                //中国电信
                if ([networkCode isEqualToString:@"03"] || [networkCode isEqualToString:@"05"] || [networkCode isEqualToString:@"11"]) {
                    carrierName= @"中国电信";
                }
                //中国卫通
                if ([networkCode isEqualToString:@"04"]) {
                    carrierName= @"中国卫通";
                }
                //中国铁通
                if ([networkCode isEqualToString:@"20"]) {
                    carrierName= @"中国铁通";
                }
            }
        } else { //国外运营商解析
            carrierName = @"其它运营商";
        }

        if (carrierName != nil) {
            [p setValue:carrierName forKey:@"$carrier"];
        } else {
            if (carrier.carrierName) {
                [p setValue:carrier.carrierName forKey:@"$carrier"];
            }
        }
    }

    BOOL isReal;

#if !SENSORS_ANALYTICS_DISABLE_AUTOTRACK_DEVICEID
    [p setValue:[[self class] getUniqueHardwareId:&isReal] forKey:@"$device_id"];
#endif
    [p addEntriesFromDictionary:@{
                                  @"$lib_version": [self libVersion],
                                  @"$manufacturer": @"Apple",
                                  @"$os": @"iOS",
                                  @"$screen_height": @((NSInteger)size.height),
                                  @"$screen_width": @((NSInteger)size.width),
                                  }];
    return [p copy];
}

- (void)registerSuperProperties:(NSDictionary *)propertyDict {
    propertyDict = [propertyDict copy];

    [self unregisterSameLetterSuperProperties:propertyDict];

    dispatch_async(self.serialQueue, ^{
        // 注意这里的顺序，发生冲突时是以propertyDict为准，所以它是后加入的
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self->_superProperties];
        [tmp addEntriesFromDictionary:propertyDict];
        self->_superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [self archiveSuperProperties];
    });
}

-(void)registerDynamicSuperProperties:(NSDictionary<NSString *,id> *(^)(void)) dynamicSuperProperties {
    dispatch_async(self.serialQueue, ^{
        self.dynamicSuperProperties = dynamicSuperProperties;
    });
}

//设置数据平台URL
-(void)setServerUrl:(NSString *)serverUrl{
    _originServerUrl = serverUrl;
    self.serverURL = serverUrl;
    if (serverUrl == nil || serverUrl.length == 0 || _debugMode == ViewHighAnalyticsDebugOff) {

    }else {   //debug模式下的地址

    }

}

//是否禁用SDK 请谨慎使用 默认是NO
-(void)disableSDK:(BOOL)disableSDK{
    _disableSDK = disableSDK;
    if (_disableSDK) {
        [self stopUploadTimer];
    }else{
        [self startUploadTimer];
    }
}
//是否打印LOG信息
-(void)enableLog:(BOOL)enableLog{
    [VHLogger enableLog:enableLog];
}
-(void)enableLog{
    BOOL isLog = NO;

    if (_debugMode != ViewHighAnalyticsDebugOff) {
        isLog = YES;
    }
    [VHLogger enableLog:isLog];
}
//设置请求的header
-(void)setRequestHeader:(NSDictionary *)header{
    _requestHeaders = header;
}

- (NSString *)filePathForData:(NSString *)data {
    NSString *filename = [NSString stringWithFormat:@"DRVHAnalytics-%@.plist", data];
    NSString *filepath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
                          stringByAppendingPathComponent:filename];
    VHDebug(@"filepath for %@ is %@", data, filepath);
    return filepath;
}

+ (NSString *)getUniqueHardwareId:(BOOL *)isReal {
    NSString *distinctId = NULL;

    // 宏 SENSORS_ANALYTICS_IDFA 定义时，优先使用IDFA
#if defined(SENSORS_ANALYTICS_IDFA)
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
        distinctId = [uuid UUIDString];
        // 在 iOS 10.0 以后，当用户开启限制广告跟踪，advertisingIdentifier 的值将是全零
        // 00000000-0000-0000-0000-000000000000
        if (distinctId && ![distinctId hasPrefix:@"00000000"]) {
            *isReal = YES;
        } else{
            distinctId = NULL;
        }
    }
#endif

    // 没有IDFA，则使用IDFV
    if (!distinctId && NSClassFromString(@"UIDevice")) {
        distinctId = [[UIDevice currentDevice].identifierForVendor UUIDString];
        *isReal = YES;
    }

    // 没有IDFV，则使用UUID
    if (!distinctId) {
        VHDebug(@"%@ error getting device identifier: falling back to uuid", self);
        distinctId = [[NSUUID UUID] UUIDString];
        *isReal = NO;
    }

    return distinctId;
}
- (NSString *)deviceModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char answer[size];
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    NSString *results = @(answer);
    return results;
}

- (NSString *)libVersion {
    return VERSION;
}

///注销仅大小写不同的 SuperProperties
- (void)unregisterSameLetterSuperProperties:(NSDictionary *)propertyDict {
    NSArray *allNewKeys = propertyDict.allKeys;
    for (NSString *newKey in allNewKeys) {
        //如果包含仅大小写不同的 key ,unregisterSuperProperty
        NSArray *superPropertyAllKeys = [self.superProperties.allKeys mutableCopy];
        [superPropertyAllKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *usedKey = (NSString *)obj;
            if ([usedKey caseInsensitiveCompare:newKey] == NSOrderedSame) { // 存在不区分大小写相同 key
                [self unregisterSuperProperty:usedKey];
            }
        }];
    }
}

- (void)unregisterSuperProperty:(NSString *)property {
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self->_superProperties];
        if (tmp[property] != nil) {
            [tmp removeObjectForKey:property];
        }
        self->_superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [self archiveSuperProperties];
    });

}

#pragma mark -- local caches 
- (UInt64)getUploadMaxSize {
    @synchronized(self) {
        return _uploadMaxSize;
    }
}
-(void)setUploadMaxSize:(UInt64)uploadMaxSize{
    @synchronized(self) {
        _uploadMaxSize = uploadMaxSize;
    }
}
-(UInt64)getMaxCacheSize{
    return _maxCacheSize;
}

-(void)setMaxCacheSize:(UInt64)maxCacheSize{
    if (maxCacheSize > 0) {
        //防止值太小统计不全面
        if (maxCacheSize < 10000) {
            maxCacheSize = 10000;
        }
        _maxCacheSize = maxCacheSize;
    }
}

-(UInt64)getMinUploadTime{
    @synchronized (self) {
        return _uploadInterval;
    }
}
-(void)setMinUploadTime:(UInt64)minUploadTime{
    @synchronized (self) {
        if (minUploadTime < 5 * 1000) {
            minUploadTime = 5 * 1000;
        }
        _uploadInterval = minUploadTime;
    }
    [self uploadData];
    [self startUploadTimer];
}
//设置网络环境规则
- (void)setUploadNetworkPolicy:(ViewHighAnalyticsNetworkType)networkType {
    @synchronized (self) {
        _networkTypePolicy = networkType;
    }
}

-(void)enableTrackGPSLocation:(BOOL)enable{

}
//归档数据
-(void)unarchive{
    [self unarchiveUserId];
    [self unarchiveSuperProperties];
    [self unarchiveFirstDay];
}
- (id)unarchiveFromFile:(NSString *)filePath {
    id unarchivedData = nil;
    @try {
        unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
    } @catch (NSException *exception) {
        VHError(@"%@ unable to unarchive data in %@, starting fresh", self, filePath);
        unarchivedData = nil;
    }
    return unarchivedData;
}
-(void)unarchiveUserId{
    NSString *archivedUserId = (NSString *)[self unarchiveFromFile:[self filePathForData:@"user_id"]];
    self.userId = archivedUserId;
}
- (void)unarchiveHospitalId {
    NSString *archivedHospitalId = (NSString *)[self unarchiveFromFile:[self filePathForData:@"hospital_Id"]];
    self.hospitalId = archivedHospitalId;
}
-(void)unarchiveFirstDay{
    NSString *archivedFirstDay = (NSString *)[self unarchiveFromFile:[self filePathForData:@"first_day"]];
    self.firstDay = archivedFirstDay;
}

-(void)unarchiveSuperProperties{
    NSDictionary *archivedSuperProperties = (NSDictionary *)[self unarchiveFromFile:[self filePathForData:@"super_properties"]];
    if (archivedSuperProperties == nil) {
        self.superProperties = [NSDictionary dictionary];
    } else {
        self.superProperties = [archivedSuperProperties copy];
    }
}

- (void)archiveUserId {
    NSString *filePath = [self filePathForData:@"user_id"];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[self.userId copy] toFile:filePath]) {
        VHError(@"%@ unable to archive userId", self);
    }
        VHDebug(@"%@ archived userId", self);
}

- (void)archiveHospitalId{
    NSString *filePath = [self filePathForData:@"hospital_Id"];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[[self hospitalId] copy] toFile:filePath]) {
        VHError(@"%@ unable to archive hospitalId", self);
    }
    VHDebug(@"%@ archived hospitalId", self);
}

- (void)archiveFirstDay {
    NSString *filePath = [self filePathForData:@"first_day"];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[[self firstDay] copy] toFile:filePath]) {
        VHError(@"%@ unable to archive firstDay", self);
    }
    VHDebug(@"%@ archived firstDay", self);
}

- (void)archiveSuperProperties {
    NSString *filePath = [self filePathForData:@"super_properties"];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[self.superProperties copy] toFile:filePath]) {
        VHError(@"%@ unable to archive super properties", self);
    }
    VHDebug(@"%@ archive super properties data", self);
}


//删除
-(void)deleteAll{
    [self.sqliteDataQueue deleteAll];
}
#pragma mark -- UIApplication Events

- (UIViewController *)currentViewController {
    __block UIViewController *currentVC = nil;
    if ([NSThread isMainThread]) {
        @try {
            UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
            if (rootViewController != nil) {
                currentVC = [self getCurrentVCFrom:rootViewController isRoot:YES];
            }
        } @catch (NSException *exception) {
            VHError(@"%@ error: %@", self, exception);
        }
        return currentVC;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            @try {
                UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
                if (rootViewController != nil) {
                    currentVC = [self getCurrentVCFrom:rootViewController isRoot:YES];
                }
            } @catch (NSException *exception) {
                VHError(@"%@ error: %@", self, exception);
            }
        });
        return currentVC;
    }
}

- (UIViewController *)getCurrentVCFrom:(UIViewController *)rootVC isRoot:(BOOL)isRoot{
    @try {
        UIViewController *currentVC;
        if ([rootVC presentedViewController]) {
            // 视图是被presented出来的
            rootVC = [self getCurrentVCFrom:rootVC.presentedViewController isRoot:NO];
        }

        if ([rootVC isKindOfClass:[UITabBarController class]]) {
            // 根视图为UITabBarController
            currentVC = [self getCurrentVCFrom:[(UITabBarController *)rootVC selectedViewController] isRoot:NO];
        } else if ([rootVC isKindOfClass:[UINavigationController class]]){
            // 根视图为UINavigationController
            currentVC = [self getCurrentVCFrom:[(UINavigationController *)rootVC visibleViewController] isRoot:NO];
        } else {
            // 根视图为非导航类
            if ([rootVC respondsToSelector:NSSelectorFromString(@"contentViewController")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                UIViewController *tempViewController = [rootVC performSelector:NSSelectorFromString(@"contentViewController")];
#pragma clang diagnostic pop
                if (tempViewController) {
                    currentVC = [self getCurrentVCFrom:tempViewController isRoot:NO];
                }
            } else {
                if (rootVC.childViewControllers && rootVC.childViewControllers.count == 1 && isRoot) {
                    currentVC = [self getCurrentVCFrom:rootVC.childViewControllers[0] isRoot:NO];
                }
                else {
                    currentVC = rootVC;
                }
            }
        }

        return currentVC;
    } @catch (NSException *exception) {
        VHError(@"%@ error: %@", self, exception);
    }
}
- (void)setUpListeners {
    // 监听 App 启动或结束事件
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];

    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];

    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];

    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];

    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminateNotification:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];

}
// APP active
//程序即将进入前台  但是还未处于活动状态
- (void)applicationWillEnterForeground:(NSNotification *)notification {
    VHDebug(@"%@ application will enter foreground", self);

    _appRelaunched = YES;
    self.launchedPassively = NO;
}
// 程序进入前台并且处于活动状态
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    VHDebug(@"%@ application did become active", self);
//    if (_appRelaunched) {
        //下次启动 app 的时候重新初始化
//        NSDictionary *sdkConfig = [[NSUserDefaults standardUserDefaults] objectForKey:@"VHSDKConfig"];
//        [self setSDKWithRemoteConfigDict:sdkConfig];
//    }
    if (_disableSDK == YES) {
        //停止 SDK 的 flushtimer
        if (self.timer.isValid) {
            [self.timer invalidate];
        }
        self.timer = nil;

#ifndef VIEWHIGH_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
        //停止采集设备方向信息
//        [self.deviceOrientationManager stopDeviceMotionUpdates];
#endif

#ifndef VIEWHIGH_ANALYTICS_DISABLE_TRACK_GPS
//        [self.locationManager stopUpdatingLocation];
#endif

        [self uploadData];
        //停止采集数据之后 flush 本地数据
//        dispatch_sync(self.serialQueue, ^{
//        });
        return;
    }
//    else{
//#ifndef VIEWHIGH_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
//        if (self.deviceOrientationConfig.enableTrackScreenOrientation) {
//            [self.deviceOrientationManager startDeviceMotionUpdates];
//        }
//#endif
//
//#ifndef VIEWHIGH_ANALYTICS_DISABLE_TRACK_GPS
//        if (self.locationConfig.enableGPSLocation) {
//            [self.locationManager startUpdatingLocation];
//        }
//#endif
//    }
//    [self requestFunctionalManagermentConfig];
    if (_applicationWillResignActive) {
        _applicationWillResignActive = NO;
        return;
    }
    _applicationWillResignActive = NO;

    // 是否首次启动
    BOOL isFirstStart = NO;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"]) {
        isFirstStart = YES;
    }

//     遍历 trackTimer ,修改 eventBegin 为当前 currentSystemUpTime
//    dispatch_async(self.serialQueue, ^{
//
//        NSNumber *currentSystemUpTime = @([[self class] getSystemUpTime]);
//        NSArray *keys = [self.trackTimer allKeys];
//        NSString *key = nil;
//        NSMutableDictionary *eventTimer = nil;
//        for (key in keys) {
//            eventTimer = [[NSMutableDictionary alloc] initWithDictionary:self.trackTimer[key]];
//            if (eventTimer) {
//                [eventTimer setValue:currentSystemUpTime forKey:@"eventBegin"];
//                self.trackTimer[key] = eventTimer;
//            }
//        }
//    });

    if ([self isAutoTrackEnabled] && _appRelaunched) {
        // 追踪 AppStart 事件
        if ([self isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppStart] == NO) {
            [self track:APP_START_EVENT withProperties:@{
                                                         RESUME_FROM_BACKGROUND_PROPERTY : @(_appRelaunched),
                                                         APP_FIRST_START_PROPERTY : @(isFirstStart),
                                                         } withType:COMMON_TYPE];
        }
        // 启动 AppEnd 事件计时器
//        if ([self isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppEnd] == NO) {
//            [self trackTimer:APP_END_EVENT withTimeUnit:SensorsAnalyticsTimeUnitSeconds];
//        }
    }

    [self startUploadTimer];
}
// app即将进入非活动状态
- (void)applicationWillResignActive:(NSNotification *)notification {
    VHDebug(@"%@ application will resign active", self);
    _applicationWillResignActive = YES;
    [self stopUploadTimer];
}
// app进入后台时
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    VHDebug(@"%@ application did enter background", self);
    _applicationWillResignActive = NO;
    self.launchedPassively = NO;
//    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(requestFunctionalManagermentConfigWithCompletion:) object:self.reqConfigBlock];

//#ifndef VIEWHIGH_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
//    [self.deviceOrientationManager stopDeviceMotionUpdates];
//#endif
//
//#ifndef VIEWHIGH_ANALYTICS_DISABLE_TRACK_GPS
//    [self.locationManager stopUpdatingLocation];
//#endif

    // 遍历 trackTimer
    // eventAccumulatedDuration = eventAccumulatedDuration + currentSystemUpTime - eventBegin
//    dispatch_async(self.serialQueue, ^{
//        NSNumber *currentSystemUpTime = @([[self class] getSystemUpTime]);
//        NSArray *keys = [self.trackTimer allKeys];
//        NSString *key = nil;
//        NSMutableDictionary *eventTimer = nil;
//        for (key in keys) {
//            if (key != nil) {
//                if ([key isEqualToString:@"$AppEnd"]) {
//                    continue;
//                }
//            }
//            eventTimer = [[NSMutableDictionary alloc] initWithDictionary:self.trackTimer[key]];
//            if (eventTimer) {
//                NSNumber *eventBegin = [eventTimer valueForKey:@"eventBegin"];
//                NSNumber *eventAccumulatedDuration = [eventTimer objectForKey:@"eventAccumulatedDuration"];
//                long eventDuration;
//                if (eventAccumulatedDuration) {
//                    eventDuration = [currentSystemUpTime longValue] - [eventBegin longValue] + [eventAccumulatedDuration longValue];
//                } else {
//                    eventDuration = [currentSystemUpTime longValue] - [eventBegin longValue];
//                }
//                [eventTimer setObject:[NSNumber numberWithLong:eventDuration] forKey:@"eventAccumulatedDuration"];
//                [eventTimer setObject:currentSystemUpTime forKey:@"eventBegin"];
//                self.trackTimer[key] = eventTimer;
//            }
//        }
//    });

    if ([self isAutoTrackEnabled]) {
        // 追踪 AppEnd 事件
        if ([self isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppEnd] == NO) {
            if (_clearReferrerWhenAppEnd) {
                _referrerScreenUrl = nil;
            }
            [self track:APP_END_EVENT withProperties:nil withType:COMMON_TYPE];
        }
    }

    if (self.uploadBeforeEnterBackground) {
        dispatch_async(self.serialQueue, ^{
            [self upload:YES];
        });
    }
}

-(void)applicationWillTerminateNotification:(NSNotification *)notification {
    VHLog(@"applicationWillTerminateNotification");
    dispatch_sync(self.serialQueue, ^{
    });
}




- (BOOL)isViewControllerStringIgnored:(NSString *)viewControllerString {
    if (viewControllerString == nil) {
        return false;
    }

    if (_ignoredViewControllers != nil && _ignoredViewControllers.count > 0) {
        if ([_ignoredViewControllers containsObject:viewControllerString]) {
            return true;
        }
    }
    return false;
}
- (BOOL)isViewControllerIgnored:(UIViewController *)viewController {
    if (viewController == nil) {
        return false;
    }
    NSString *screenName = NSStringFromClass([viewController class]);
    if (_ignoredViewControllers != nil && _ignoredViewControllers.count > 0) {
        if ([_ignoredViewControllers containsObject:screenName]) {
            return true;
        }
    }
    return false;
}
-(void)ignoreAutoTrackViewControllers:(NSArray *)controllers{
    if (controllers == nil || controllers.count == 0) {
        return;
    }
    [_ignoredViewControllers addObjectsFromArray:controllers];

    //去重
    NSSet *set = [NSSet setWithArray:_ignoredViewControllers];
    if (set != nil) {
        _ignoredViewControllers = [NSMutableArray arrayWithArray:[set allObjects]];
    } else{
        _ignoredViewControllers = [[NSMutableArray alloc] init];
    }
}
- (BOOL)isViewTypeIgnored:(Class)aClass {
    return [_ignoredViewTypeList containsObject:aClass];
}
#pragma mark -- TrackActive
//登录
-(void)login:(NSString *)userId{
    [self login:userId withProperties:nil];
}
-(void)login:(NSString *)userId withProperties:(NSDictionary *)properties{
    if (userId == nil || userId.length == 0) {
        return;
    }
    if (userId.length > 255) {
        return;
    }

    if (![userId isEqualToString:[self userId]]) {
        self.userId = userId;
        [self archiveUserId];
        [self track:@"$login" withProperties:properties withType:BUSSINESS_TYPE];
    }
}

-(void)logout{
    self.userId = NULL;
//    self.hospitalId = NULL;
    [self archiveUserId];
}

- (void)setUserProfile:(NSDictionary *)profileDict{
    [self track:@"$login" withProperties:profileDict withType:BUSSINESS_TYPE];
}
-(void)addHospitalId:(NSString *)hospitalId{
    [self setHospitalId:hospitalId withProperties:nil];
}
-(void)setHospitalId:(NSString *)hospitalId withProperties:(NSDictionary *)properties{
    if (hospitalId == nil || hospitalId.length == 0) {
        return;
    }
    if (hospitalId.length > 255) {
        return;
    }

    if (![hospitalId isEqualToString:self.hospitalId]) {
        self.hospitalId = hospitalId;
        [self archiveHospitalId];
        [self track:@"&setHospital" withProperties:properties withType:BUSSINESS_TYPE];
    }
}
- (void)track:(NSString *)event{
    [self track:event withProperties:nil];
}
-(void)track:(NSString *)event withProperties:(NSDictionary *)propertyDict{
    [self track:event withProperties:propertyDict withType:BUSSINESS_TYPE];
}
-(void)track:(NSString *)event withProperties:(NSDictionary *)propertieDict withType:(NSString *)type{
    //如果禁用sdk
    if (_disableSDK) {
        return;
    }
    //获取用户自定义的动态公共属性
    NSDictionary *dynamicSuperPropertiesDict = self.dynamicSuperProperties?self.dynamicSuperProperties():nil;

    //去掉重复的属性
    [self unregisterSameLetterSuperProperties:dynamicSuperPropertiesDict];

    dispatch_async(self.serialQueue, ^{

//        NSNumber *currentSystemUpTime = @([[self class] getSystemUpTime]);

        NSNumber *timeStamp = @([[self class] getCurrentTime]);

        NSMutableDictionary *p = [NSMutableDictionary dictionary];

        NSMutableDictionary *singleTrackDict = [NSMutableDictionary dictionary];

        // COMMON_TYPE 类型的请求，还是要加上自动获取的property
        [p addEntriesFromDictionary:self->_automaticProperties];
        //每次track时的网络状态
        NSString *networkType = [DRVHAnalyticsSDK getNetWorkStates];

        [p setValue:networkType forKey:@"$network_type"];
//        if ([type isEqualToString:COMMON_TYPE]) {
//
//        }
        // 这里注意下顺序，按照优先级从低到高，依次是automaticProperties, superProperties,dynamicSuperPropertiesDict,propertieDict
        [p addEntriesFromDictionary:self->_superProperties];
        [p addEntriesFromDictionary:dynamicSuperPropertiesDict];

        if (propertieDict) {
            NSArray  *keys = propertieDict.allKeys;
            for (id key in keys) {
                NSObject *obj = propertieDict[key];
                if ([obj isKindOfClass:[NSDate class]]) {
                    NSString  *dateStr = [self->_dateFormater  stringFromDate:(NSDate *)obj];
                    [p setObject:dateStr forKey:key];
                }else{
                    [p setObject:obj forKey:key];
                }
            }
        }

        BOOL isReal;
        [singleTrackDict setValue:[[self class] getUniqueHardwareId:&isReal] forKey:@"distinct_id"];
        [singleTrackDict setValue:event forKey:@"event"];
        [singleTrackDict setValue:self.userId == nil ? @"" : self.userId forKey:@"userid"];
        [singleTrackDict setValue:self.hospitalId == nil ? @"" : self.hospitalId forKey:@"hospitalid"];
        [singleTrackDict setValue:type forKey:@"type"];
        [singleTrackDict setValue:timeStamp forKey:@"time"];
        [singleTrackDict setValue:self->_osVersion forKey:@"version"];
        [singleTrackDict setValue:self->_deviceModel forKey:@"model"];
        [singleTrackDict setValue:[NSDictionary dictionaryWithDictionary:p] forKey:@"properties"];

        //存入缓存数据库
        [self enqueueWithType:type andEvent:singleTrackDict];

        //否则 在满足设置的规则后再发送
        if (self->_debugMode != ViewHighAnalyticsDebugOff) {
            //DEBUG模式下直接upload信息 用作调试
            [self uploadData];
        }else{
            if ([self.sqliteDataQueue count] >= self.getUploadMaxSize) {
                [self uploadData];
            }
        }
    });
}

- (void)enqueueWithType:(NSString *)type andEvent:(NSDictionary *)singleTrackDict {
    NSMutableDictionary *event = [[NSMutableDictionary alloc] initWithDictionary:singleTrackDict];
    [self.sqliteDataQueue addObejct:event withType:@"Post"];
}

-(void)trackViewScreenStart:(UIViewController *)viewController{
    if (!viewController) {
        return;
    }

    Class vClass = [viewController class];
    if (!vClass) {
        return;
    }

    NSString *screenName = NSStringFromClass(vClass);
    if ([viewController isKindOfClass:NSClassFromString(@"UINavigationController")] ||
        [viewController isKindOfClass:NSClassFromString(@"UITabBarController")]) {
        return;
    }

    //过滤用户设置的不被AutoTrack的Controllers
    if (_ignoredViewControllers != nil && _ignoredViewControllers.count > 0) {
        if ([_ignoredViewControllers containsObject:screenName]) {
            return;
        }
    }

    NSNumber *viewStartTime = @([[self class] getCurrentTime]);
    dispatch_async(self.serialQueue, ^{
        [self.trackTimer setValue:viewStartTime forKey:screenName];
    });

}
-(void)trackViewScreenEnd:(UIViewController *)viewController{
    if ([self isLaunchedPassively]) {
        return;
    }

    if (!viewController) {
        return;
    }

    Class klass = [viewController class];
    if (!klass) {
        return;
    }

    NSString *screenName = NSStringFromClass(klass);

    if ([viewController isKindOfClass:NSClassFromString(@"UINavigationController")] ||
        [viewController isKindOfClass:NSClassFromString(@"UITabBarController")]) {
        return;
    }

    //过滤用户设置的不被AutoTrack的Controllers
    if (_ignoredViewControllers != nil && _ignoredViewControllers.count > 0) {
        if ([_ignoredViewControllers containsObject:screenName]) {
            return;
        }
    }

    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    [properties setValue:NSStringFromClass(klass) forKey:@"$page_name"];

    @try {

        NSNumber *currentTime = @([[self class] getCurrentTime]);
        NSNumber *vStartTime = self.trackTimer[screenName];
        if (vStartTime) {
            float vDuration = [currentTime longValue] - [vStartTime longValue];
            [properties setValue:@(vDuration) forKey:@"$event_duration"];
            [properties setValue:vStartTime forKey:@"$startTime"];
            [properties setValue:currentTime forKey:@"$endTime"];
        }
        //先获取 controller.navigationItem.title
        NSString *controllerTitle = viewController.navigationItem.title;
        if (controllerTitle != nil) {
            [properties setValue:controllerTitle forKey:@"$title"];
        }

        //再获取 controller.navigationItem.titleView, 并且优先级比较高
        NSString *elementContent = [self getUIViewControllerTitle:viewController];
        if (elementContent != nil && [elementContent length] > 0) {
            elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
            [properties setValue:elementContent forKey:@"$title"];
        }
    } @catch (NSException *exception) {
        VHError(@"%@ failed to get UIViewController's title error: %@", self, exception);
    }
//
//    if ([controller conformsToProtocol:@protocol(SAAutoTracker)] && [controller respondsToSelector:@selector(getTrackProperties)]) {
//        UIViewController<SAAutoTracker> *autoTrackerController = (UIViewController<SAAutoTracker> *)controller;
//        [properties addEntriesFromDictionary:[autoTrackerController getTrackProperties]];
//        _lastScreenTrackProperties = [autoTrackerController getTrackProperties];
//    }

//#ifdef SENSORS_ANALYTICS_AUTOTRACT_APPVIEWSCREEN_URL
//    [properties setValue:screenName forKey:SCREEN_URL_PROPERTY];
//    @synchronized(_referrerScreenUrl) {
//        if (_referrerScreenUrl) {
//            [properties setValue:_referrerScreenUrl forKey:SCREEN_REFERRER_URL_PROPERTY];
//        }
//        _referrerScreenUrl = screenName;
//    }
//#endif

//    if ([controller conformsToProtocol:@protocol(SAScreenAutoTracker)] && [controller respondsToSelector:@selector(getScreenUrl)]) {
//        UIViewController<SAScreenAutoTracker> *screenAutoTrackerController = (UIViewController<SAScreenAutoTracker> *)controller;
//        NSString *currentScreenUrl = [screenAutoTrackerController getScreenUrl];
//
//        [properties setValue:currentScreenUrl forKey:SCREEN_URL_PROPERTY];
//        @synchronized(_referrerScreenUrl) {
//            if (_referrerScreenUrl) {
//                [properties setValue:_referrerScreenUrl forKey:SCREEN_REFERRER_URL_PROPERTY];
//            }
//            _referrerScreenUrl = currentScreenUrl;
//        }
//    }

    [self track:APP_VIEW_SCREEN_EVENT withProperties:properties withType:COMMON_TYPE];
}

-(void)trackViewAppClick:(UIView *)view{
    [self trackViewAppClick:view withProperties:nil];
}
-(void)trackViewAppClick:(UIView *)view withProperties:(NSDictionary *)properties{
    @try {
        if (view == nil) {
            return;
        }

        //关闭 AutoTrack
        if (![self isAutoTrackEnabled]) {
            return;
        }

        //忽略 $AppClick 事件
        if ([self isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppClick]) {
            return;
        }

        if ([self isViewTypeIgnored:[view class]]) {
            return;
        }

        if (view.VHAnalyticsIgnoreView) {
            return;
        }

        NSMutableDictionary *propertyDict = [[NSMutableDictionary alloc] init];

        UIViewController *viewController = [self currentViewController];
        if (viewController != nil) {
            if ([[DRVHAnalyticsSDK sharedInstance] isViewControllerIgnored:viewController]) {
                return;
            }

            //获取 Controller 名称($screen_name)
            NSString *screenName = NSStringFromClass([viewController class]);
            [propertyDict setValue:screenName forKey:@"$page_name"];

            NSString *controllerTitle = viewController.navigationItem.title;
            if (controllerTitle != nil) {
                [propertyDict setValue:viewController.navigationItem.title forKey:@"$title"];
            }

            //再获取 controller.navigationItem.titleView, 并且优先级比较高
            NSString *elementContent = [self getUIViewControllerTitle:viewController];
            if (elementContent != nil && [elementContent length] > 0) {
                elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                [propertyDict setValue:elementContent forKey:@"$title"];
            }
        }

        //ViewID
        if (view.VHAnalyticsViewID != nil) {
            [propertyDict setValue:view.VHAnalyticsViewID forKey:@"$element_id"];
        }

        [propertyDict setValue:NSStringFromClass([view class]) forKey:@"$element_type"];

        NSString *elementContent = [[NSString alloc] init];
        elementContent = [AutoTrackExtendsion contentFromView:view];
        if (elementContent != nil && [elementContent length] > 0) {
            elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
            [propertyDict setValue:elementContent forKey:@"$element_content"];
        }

        if (properties != nil) {
            [propertyDict addEntriesFromDictionary:properties];
        }

        //View Properties
        NSDictionary* propDict = view.VHAnalyticsViewProperties;
        if (propDict != nil) {
            [propertyDict addEntriesFromDictionary:propDict];
        }

        [[DRVHAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:propertyDict withType:COMMON_TYPE];
    } @catch (NSException *exception) {
        VHError(@"%@: %@", self, exception);
    }
}

- (NSString *)getUIViewControllerTitle:(UIViewController *)controller {
    @try {
        if (controller == nil) {
            return nil;
        }

        UIView *titleView = controller.navigationItem.titleView;
        if (titleView != nil) {
            return [AutoTrackExtendsion contentFromView:titleView];
        }
    } @catch (NSException *exception) {
        VHError(@"%@: %@", self, exception);
    }
    return nil;
}


#pragma mark -- delegate
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [AutoTrackExtendsion trackAppClickWithUITableView:tableView didSelectRowAtIndexPath:indexPath];
}
-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [AutoTrackExtendsion trackAppClickWithUICollectionView:collectionView didSelectItemAtIndexPath:indexPath];
}

#pragma mark -- AutoTrack
//是否启用自动追踪
-(BOOL)isAutoTrackEnabled{
    if (_disableSDK) {
        return NO;
    }
    return _autoTrack;
}

-(void)enableAutoTrack:(ViewHighAnalyticsAutoTrackEventType)eventType{
    if (_autoTrackEventType != eventType) {
        _autoTrackEventType = eventType;
        _autoTrack = (_autoTrackEventType != ViewHighAnalyticsEventTypeNone);
//        [self hockAllControllerViewAndClick];
    }
    // 是否首次启动
    BOOL isFirstStart = NO;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"]) {
        isFirstStart = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasLaunchedOnce"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([self isLaunchedPassively]) {
            // 追踪 AppStart 事件
            if ([self isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppStart] == NO) {
                [self track:@"$AppStartPassively" withProperties:@{
                                                                   RESUME_FROM_BACKGROUND_PROPERTY : @(self->_appRelaunched),
                                                                   APP_FIRST_START_PROPERTY : @(isFirstStart),
                                                                   } withType:COMMON_TYPE];
            }
        } else {
            // 追踪 AppStart 事件
            if ([self isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppStart] == NO) {
                [self track:APP_START_EVENT withProperties:@{
                                                             RESUME_FROM_BACKGROUND_PROPERTY : @(self->_appRelaunched),
                                                             APP_FIRST_START_PROPERTY : @(isFirstStart),
                                                             } withType:COMMON_TYPE];
            }
            // 启动 AppEnd 事件计时器
//            if ([self isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppEnd] == NO) {
//                [self trackTimer:APP_END_EVENT withTimeUnit:SensorsAnalyticsTimeUnitSeconds];
//            }
        }
    });
}


-(BOOL)isAutoTrackEventTypeIgnored:(ViewHighAnalyticsAutoTrackEventType)eventType{
    if (_disableSDK) {
        return YES;
    }
    return !(_autoTrackEventType & eventType);
}

-(void)hockAllControllerViewAndClick{
    // 监听所有 UIViewController 显示事件
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        //$AppViewScreen
        [UIViewController vh_swizzleMethod:@selector(viewWillAppear:) withMethod:@selector(autoTrack_viewWillAppear:) error:NULL];
        [UIViewController vh_swizzleMethod:@selector(viewWillDisappear:) withMethod:@selector(autoTrack_viewWillDisAppear:) error:NULL];
        NSError *error = NULL;
        //$AppClick
        // Actions & Events
        [UIApplication vh_swizzleMethod:@selector(sendAction:to:from:forEvent:)
                             withMethod:@selector(vh_sendAction:to:from:forEvent:)
                                  error:&error];
        if (error) {
            VHError(@"Failed to swizzle sendAction:to:forEvent: on UIAppplication. Details: %@", error);
            error = NULL;
        }
    });

}
#pragma mark -- upload
- (NSString *)getCookieWithDecode:(BOOL)decode {
    if (decode) {
        return (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,(__bridge CFStringRef)_cookie, CFSTR(""),CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    } else {
        return _cookie;
    }
}
-(void)uploadData{
    dispatch_async(self.serialQueue, ^{
        [self upload:NO];
    });
}

-(void)upload:(BOOL)vacuumAfterUoploading{
    if (_serverURL == nil || [_serverURL isEqualToString:@""]) {
        return;
    }
    // 判断当前网络类型是否符合同步数据的网络策略
    NSString *networkType = [DRVHAnalyticsSDK getNetWorkStates];
    if (!([self toNetworkType:networkType] & _networkTypePolicy)) {
        return;
    }

    // 使用 Post 发送数据
    BOOL (^uploadByPost)(NSArray *, NSString *) = ^(NSArray *recordArray, NSString *type) {
        NSString *jsonString;
        NSData *zippedData;
        NSString *b64String;
        NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
//        NSString *jsonStr;
        NSData *jsonData;
        @try {
            // 1. 先完成这一系列Json字符串的拼接
            jsonString = [NSString stringWithFormat:@"[%@]",[recordArray componentsJoinedByString:@","]];
            // 2. 使用gzip进行压缩
            zippedData = [VHGzipUtility gzipData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
            // 3. base64
            b64String = [zippedData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];
            int hashCode = [b64String data_hashCode];
//            b64String = (id)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
//                                                                                      (CFStringRef)b64String,
//                                                                                      NULL,
//                                                                                      CFSTR("!*'();:@&=+$,/?%#[]"),
//                                                                                      kCFStringEncodingUTF8));

            [postBody setObject:[NSString stringWithFormat:@"%d",hashCode] forKey:@"hashCode"];
            [postBody setObject:b64String forKey:@"dataList"];
            jsonData = [NSJSONSerialization dataWithJSONObject:postBody options:NSJSONWritingPrettyPrinted error:nil];
//            jsonStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];

//            postBody = [NSString stringWithFormat:@"hashCode:%d,dataList:%@", hashCode, b64String];

        } @catch (NSException *exception) {
            VHError(@"%@ flushByPost format data error: %@", self, exception);
            return YES;
        }

        NSURL *URL = [NSURL URLWithString:self.serverURL];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:jsonData];
        // 普通事件请求，使用标准 UserAgent
        [request setValue:@"DRVHAnalyticsSDK iOS SDK" forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
//        if (self->_debugMode == ViewHighAnalyticsDebugOnly) {
//            [request setValue:@"true" forHTTPHeaderField:@"Dry-Run"];
//        }

        //Cookie
        [request setValue:[[DRVHAnalyticsSDK sharedInstance] getCookieWithDecode:NO] forHTTPHeaderField:@"Cookie"];
        // 外部设置的header
        if (self.requestHeaders) {
            for (NSString *key in self.requestHeaders.allKeys) {
                [request setValue:self.requestHeaders[key] forHTTPHeaderField:key];
            }
        }

        dispatch_semaphore_t flushSem = dispatch_semaphore_create(0);
        __block BOOL flushSucc = YES;

        void (^block)(NSData*, NSURLResponse*, NSError*) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
                VHError(@"%@", [NSString stringWithFormat:@"%@ network failure: %@", self, error ? error : @"Unknown error"]);
                flushSucc = NO;
                dispatch_semaphore_signal(flushSem);
                return;
            }

            NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse*)response;
            NSString *urlResponseContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *errMsg = [NSString stringWithFormat:@"%@ upload failure with response '%@'.", self, urlResponseContent];
            NSString *messageDesc = nil;
            NSInteger statusCode = urlResponse.statusCode;
            if(statusCode != 200) {
                messageDesc = @"\n【invalid message】\n";
                flushSucc = NO;

            } else {
                messageDesc = @"\n【valid message】\n";
                
            }
            VHError(@"==========================================================================");
            if ([VHLogger isLoggerEnabled]) {
                @try {
                    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
                    NSString *logString=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
                    VHError(@"%@ %@: %@", self,messageDesc,logString);
                } @catch (NSException *exception) {
                    VHError(@"%@: %@", self, exception);
                }
            }
            if (statusCode != 200) {
                VHError(@"%@ ret_code: %ld", self, statusCode);
                VHError(@"%@ ret_content: %@", self, urlResponseContent);
            }
            dispatch_semaphore_signal(flushSem);
        };

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:block];

        [task resume];
#else
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:
         ^(NSURLResponse *response, NSData* data, NSError *error) {
             return block(data, response, error);
         }];
#endif

        dispatch_semaphore_wait(flushSem, DISPATCH_TIME_FOREVER);

        return flushSucc;
    };

    [self flushByType:@"Post" withSize:(_debugMode == ViewHighAnalyticsDebugOff ? self->_uploadMaxSize : 1) andFlushMethod:uploadByPost];

    if (vacuumAfterUoploading) {
        if (![self.sqliteDataQueue vacuum]) {
            VHError(@"failed to VACUUM SQLite.");
        }
    }

    VHDebug(@"events flushed.");
}
- (void)flushByType:(NSString *)type withSize:(UInt64)flushSize andFlushMethod:(BOOL (^)(NSArray *, NSString *))flushMethod {

    NSArray *recordArray = [self.sqliteDataQueue getFirstRecords:flushSize withType:type];
    if (recordArray == nil) {
        VHError(@"Failed to get records from SQLite.");
        return;
    }
    if ([recordArray count] == 0 || !flushMethod(recordArray, type)) {
        return;
    }

    if (![self.sqliteDataQueue removeFirstRecords:flushSize withType:type]) {
        VHError(@"Failed to remove records from SQLite.");
        return;
    }
}
- (ViewHighAnalyticsNetworkType)toNetworkType:(NSString *)networkType {
    if ([@"NULL" isEqualToString:networkType]) {
        return ViewHighAnalyticsNetworkTypeALL;
    } else if ([@"WIFI" isEqualToString:networkType]) {
        return ViewHighAnalyticsNetworkTypeWIFI;
    } else if ([@"2G" isEqualToString:networkType]) {
        return ViewHighAnalyticsNetworkType2G;
    }   else if ([@"3G" isEqualToString:networkType]) {
        return ViewHighAnalyticsNetworkType3G;
    }   else if ([@"4G" isEqualToString:networkType]) {
        return ViewHighAnalyticsNetworkType4G;
    }
    return ViewHighAnalyticsNetworkTypeNONE;
}
//重新开启计时器
-(void)startUploadTimer{
    VHDebug(@"starting upload timer.");
    [self stopUploadTimer];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_uploadInterval > 0) {
            double interval = self->_uploadInterval > 100 ? (double)self->_uploadInterval / 1000.0 : 0.1f;
            self.timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                          target:self
                                                        selector:@selector(uploadData)
                                                        userInfo:nil
                                                         repeats:YES];
            [[NSRunLoop currentRunLoop]addTimer:self.timer forMode:NSRunLoopCommonModes];
        }
    });
}

//停止计时器
-(void)stopUploadTimer{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
        }
        self.timer = nil;
    });
}

//获取网络状态
+ (NSString *)getNetWorkStates {
#ifdef SA_UT
    VHDebug(@"In unit test, set NetWorkStates to wifi");
    return @"WIFI";
#endif
    NSString* network = @"NULL";
    @try {
        VHReachability *reachability = [VHReachability reachabilityForInternetConnection];
        VHNetworkStatus status = [reachability currentReachabilityStatus];

        if (status == VHReachableWifi) {
            network = @"WIFI";
        } else if (status == VHReachableWWAN) {
            CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
            if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS]) {
                network = @"2G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge]) {
                network = @"2G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyWCDMA]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSDPA]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSUPA]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyeHRPD]) {
                network = @"3G";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE]) {
                network = @"4G";
            }
        }
    } @catch(NSException *exception) {
        VHDebug(@"%@: %@", self, exception);
    }
    return network;
}

-(void)enableHeatMap{
    _heatMap = YES;
}

-(BOOL)isEnableHeatMap{
    return _heatMap;
}

//- (void)trackAppCrash{
//
//}

@end
