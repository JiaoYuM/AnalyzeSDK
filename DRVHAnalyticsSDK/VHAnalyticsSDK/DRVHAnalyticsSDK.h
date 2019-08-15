//
//  DRVHAnalyticsSDK.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/8.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


/**
 * @abstract
 * Debug模式，用于检验数据导入是否正确。该模式下，事件会逐条实时发送到DRVHAnalytics，并根据返回值检查
 * 数据导入是否正确。
 *
 * @discussion
 * Debug模式的具体使用方式，请参考:
 *
 * Debug模式有三种选项:
 *   ViewHighAnalyticsDebugOff - 关闭DEBUG模式
 *   ViewHighAnalyticsDebugOnly - 打开DEBUG模式，但该模式下发送的数据仅用于调试，不进行数据导入
 *   ViewHighAnalyticsDebugAndTrack - 打开DEBUG模式，并将数据导入
 */
typedef NS_ENUM(NSInteger, ViewHighAnalyticsDebugMode) {
    ViewHighAnalyticsDebugOff,
    ViewHighAnalyticsDebugOnly,
    ViewHighAnalyticsDebugAndTrack,
};

/**
 * @abstract
 * AutoTrack 中的事件类型
 *
 * @discussion
 *   ViewHighAnalyticsEventTypeAppStart - $AppStart
 *   ViewHighAnalyticsEventTypeAppEnd - $AppEnd
 *   ViewHighAnalyticsEventTypeAppClick - $AppClick
 *   ViewHighAnalyticsEventTypeAppViewScreen - $AppViewScreen
 */
typedef NS_OPTIONS(NSInteger, ViewHighAnalyticsAutoTrackEventType) {
    ViewHighAnalyticsEventTypeNone      = 0,
    ViewHighAnalyticsEventTypeAppStart      = 1 << 0,
    ViewHighAnalyticsEventTypeAppEnd        = 1 << 1,
    ViewHighAnalyticsEventTypeAppClick      = 1 << 2,
    ViewHighAnalyticsEventTypeAppViewScreen = 1 << 3,
};

/**
 * @abstract
 * 网络类型
 *
 * @discussion
 *   ViewHighAnalyticsNetworkTypeNONE - NULL
 *   ViewHighAnalyticsNetworkType2G - 2G
 *   ViewHighAnalyticsNetworkType3G - 3G
 *   ViewHighAnalyticsNetworkType4G - 4G
 *   ViewHighAnalyticsNetworkTypeWIFI - WIFI
 *   ViewHighAnalyticsNetworkTypeALL - ALL
 */
typedef NS_OPTIONS(NSInteger, ViewHighAnalyticsNetworkType) {
    ViewHighAnalyticsNetworkTypeNONE      = 0,
    ViewHighAnalyticsNetworkType2G       = 1 << 0,
    ViewHighAnalyticsNetworkType3G       = 1 << 1,
    ViewHighAnalyticsNetworkType4G       = 1 << 2,
    ViewHighAnalyticsNetworkTypeWIFI     = 1 << 3,
    ViewHighAnalyticsNetworkTypeALL      = 0xFF,
};

@protocol VHUIViewAutoTrackDelegate

//UITableView
@optional
-(NSDictionary *) vhAnalytics_tableView:(UITableView *)tableView autoTrackPropertiesAtIndexPath:(NSIndexPath *)indexPath;

//UICollectionView
@optional
-(NSDictionary *) vhAnalytics_collectionView:(UICollectionView *)collectionView autoTrackPropertiesAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface UIImage (SensorsAnalytics)
@property (nonatomic,copy) NSString* vhAnalyticsImageName;
@end

@interface UIView (DRVHAnalytics)

- (nullable UIViewController *)viewController;
//viewID
@property (copy,nonatomic) NSString* VHAnalyticsViewID;

//AutoTrack 时，是否忽略该 View
@property (nonatomic,assign) BOOL VHAnalyticsIgnoreView;

//AutoTrack 发生在 SendAction 之前还是之后，默认是 SendAction 之前
@property (nonatomic,assign) BOOL VHAnalyticsAutoTrackAfterSendAction;

//AutoTrack 时，View 的扩展属性
@property (strong,nonatomic) NSDictionary* VHAnalyticsViewProperties;

@property (nonatomic, weak, nullable) id VHAnalyticsDelegate;
@end

@interface DRVHAnalyticsSDK : NSObject

/**
 * @proeprty
 *
 * @abstract
 * 当App进入后台时，是否执行upload将数据发送到
 *
 * @discussion
 * 默认值为 YES
 */
@property (atomic) BOOL uploadBeforeEnterBackground;


#pragma mark -- 初始化设置

/*  初始化的方法  必须先实现此方法
 ** 根据传入的配置 初始化返回一个单例
 *  @param  serverURL  服务端的URL
 *  @parma  launchOptions  初始化的launchOptions
 *  @prama  debugMode   DRVHAnalytics 的debug模式
 */
+ (DRVHAnalyticsSDK *)sharedInstanceWithServerURL:(nonnull NSString *)serverURL
                                    andLaunchOptions:(NSDictionary *)launchOptions
                                        andDebugMode:(ViewHighAnalyticsDebugMode)debugMode;

/**
 * @abstract
 * 返回之前所初始化好的单例
 *
 * @return 返回的单例
 */
+ (DRVHAnalyticsSDK * _Nullable)sharedInstance;
/**
 * @abstract
 * log功能开关
 *
 * @discussion
 * 根据需要决定是否开启 SDK log , ViewHighAnalyticsDebugOff 模式默认关闭 log
 * ViewHighAnalyticsDebugOnly  ViewHighAnalyticsDebugAndTrack 模式默认开启log
 *
 *  正式发布应当关闭log
 */
- (void)enableLog:(BOOL)enableLog;

/*
    是否禁用SDK统计埋点功能
 */
-(void)disableSDK:(BOOL)disableSDK;

/*
    设置请求的header
    
 */

-(void)setRequestHeader:(NSDictionary *)header;

#pragma mark -- cache & regulations
/**
 * @abstract
 * 设置本地缓存最多事件条数
 *
 * @discussion
 * 默认为 10000 条事件
 *
 * @param maxCacheSize 本地缓存最多事件条数
 */
- (void)setMaxCacheSize:(UInt64)maxCacheSize;
//获取
- (UInt64)getMaxCacheSize;
/**
 * @abstract
 * 设置本地缓存发送的最小时间 默认15s
 */
- (void)setMinUploadTime:(UInt64)minUploadTime;
- (UInt64)getMinUploadTime;
/*
 **
 *设置单次上传的最大数据条数
 */

-(void)setUploadMaxSize:(UInt64)uploadMaxSize;
-(UInt64)getUploadMaxSize;
/**
 * @abstract
 * 设置 upload 时网络发送策略
 *
 * @discussion
 * 默认 4G、WI-FI 环境下都会尝试 upload
 *
 * @param networkType ViewHighAnalyticsNetworkType
 */
- (void)setUploadNetworkPolicy:(ViewHighAnalyticsNetworkType)networkType;

#pragma mark -- Event Track
/**
 * @abstract
 * 登录，设置当前用户的userId
 *
 * @param userId 当前用户的userId
 */
- (void)login:(NSString *)userId;

- (void)login:(NSString *)userId withProperties:(NSDictionary * _Nullable )properties;
/**
 * @abstract
 * 注销，清空当前用户的userId
 *
 */
- (void)logout;

/*
 **
 *设置医院的id
 *@param hospitalId 医院ID
 */
- (void)addHospitalId:(NSString *)hospitalId;

- (void)setHospitalId:(NSString *)hospitalId withProperties:(NSDictionary * _Nullable)properties;

/**
 * @abstract
 * 用来设置每个事件都带有的一些公共属性   (设备信息，系统版本号等)
 *
 * @discussion
 * 当track的Properties，superProperties和SDK自动生成的automaticProperties有相同的key时，遵循如下的优先级：
 *    track.properties > superProperties > automaticProperties
 * 另外，当这个接口被多次调用时，是用新传入的数据去merge先前的数据，并在必要时进行merger
 * 例如，在调用接口前，dict是@{@"a":1, @"b": "bbb"}，传入的dict是@{@"b": 123, @"c": @"asd"}，则merge后的结果是
 * @{"a":1, @"b": 123, @"c": @"asd"}，同时，SDK会自动将superProperties保存到文件中，下次启动时也会从中读取
 * @param propertyDict 传入merge到公共属性的dict
 */
- (void)registerSuperProperties:(NSDictionary *)propertyDict;

/**
 * @abstract
 * 用来设置事件的动态公共属性 （网络，APP版本号）
 *
 * @discussion
 * 当track的Properties，superProperties和SDK自动生成的automaticProperties有相同的key时，遵循如下的优先级：
 *    track.properties > dynamicSuperProperties > superProperties > automaticProperties
 *
 * 例如，track.properties 是 @{@"a":1, @"b": "bbb"}，返回的 eventCommonProperty 是 @{@"b": 123, @"c": @"asd"}，
 * superProperties 是  @{@"a":1, @"b": "bbb",@"c":@"ccc"}，automaticProperties是 @{@"a":1, @"b": "bbb",@"d":@"ddd"},
 * 则merge后的结果是 @{"a":1, @"b": "bbb", @"c": @"asd",@"d":@"ddd"}
 * 返回的 NSDictionary 需满足以下要求
 * 重要：1,key 必须是NSString
 *          2,key 的名称必须符合要求
 *          3,value 的类型必须是 NSString, NSNumber, NSSet,NSArray,NSDate
 *          4,value 类型为 NSSet、NSArray 时，NSSet、NSArray 中的所有元素必须为 NSString
 * @param dynamicSuperProperties block 用来返回事件的动态公共属性
 */
-(void)registerDynamicSuperProperties:(NSDictionary<NSString *,id> *(^)(void)) dynamicSuperProperties;

/**
 * @abstract
 * 调用track接口，追踪一个无私有属性的event
 *
 * @param event event的名称
 */
- (void)track:(NSString *)event;
/**
 * @abstract
 * 调用track接口，追踪一个带有属性的event
 *
 * @discussion。
 * 其中的key是Property的名称，必须是NSString
 * value则是Property的内容，只支持 NSString,NSNumber,NSSet,NSArray,NSDate这些类型
 * 特别的，NSSet或者NSArray类型的value中目前只支持其中的元素是NSString
 *
 * @param event             event的名称
 * @param propertyDict     event的属性
 */
- (void)track:(NSString *)event withProperties:(nullable NSDictionary *)propertyDict;

-(void)track:(NSString *)event withProperties:(nullable NSDictionary *)propertieDict withType:(NSString *)type;

/**
 * @abstract
 * 通过代码触发 UIView 的 $AppClick 事件
 *
 * @param view UIView
 */

- (void)trackViewAppClick:(nonnull UIView *)view;

/**
 * @abstract
 * 通过代码触发 UIView 的 $AppClick 事件
 *
 * @param view UIView
 * @param properties 自定义属性
 */
- (void)trackViewAppClick:(nonnull UIView *)view withProperties:(nullable NSDictionary *)properties;


- (void)trackViewScreenStart:(UIViewController *)viewController;

/**
 * @abstract
 * 通过代码触发 UIViewController 的 $AppViewScreen 事件
 *
 * @param viewController 当前的 UIViewController
 */
- (void)trackViewScreenEnd:(UIViewController *)viewController;

#pragma mark -- 自动埋点统计
/**
 * @property
 *
 * @abstract
 * 打开 SDK 自动追踪,默认只追踪App 启动 / 关闭、进入页面、元素点击
 *
 * @discussion
 * 该功能自动追踪 App 的一些行为，例如 SDK 初始化、App 启动 / 关闭、进入页面 等等:
 * 该功能默认关闭
 */
- (void)enableAutoTrack:(ViewHighAnalyticsAutoTrackEventType)eventType;
//是否启动自动追踪
-(BOOL)isAutoTrackEnabled;
/**
 * @abstract
 * 判断某个 View 类型是否被忽略
 *
 * @param aClass Class View 对应的 Class
 *
 * @return YES:被忽略; NO:没有被忽略
 */
- (BOOL)isViewTypeIgnored:(Class)aClass;

- (UIViewController *_Nullable)currentViewController;
/**
 * @abstract
 * 判断某个 ViewController 是否被忽略
 *
 * @param viewController UIViewController
 *
 * @return YES:被忽略; NO:没有被忽略
 */
- (BOOL)isViewControllerIgnored:(UIViewController *)viewController ;

- (NSString *)getUIViewControllerTitle:(UIViewController *)controller ;
///**
// * @abstract
// * 自动收集 App Crash 日志，该功能默认是关闭的
// */
//- (void)trackAppCrash;

/**
 * @abstract
 * 开启 HeatMap，$AppClick 事件将会采集控件的 viewPath
 */
- (void)enableHeatMap;
- (BOOL)isEnableHeatMap;

/**
 * @abstract
 * 在AutoTrack时，用户可以设置哪些controlls不被AutoTrack
 *
 * @param controllers   controller‘字符串’数组
 */
- (void)ignoreAutoTrackViewControllers:(NSArray *)controllers;

/**
 * @abstract
 * 判断某个 AutoTrack 事件类型是否被忽略
 *
 * @param eventType SensorsAnalyticsAutoTrackEventType 要判断的 AutoTrack 事件类型
 *
 * @return YES:被忽略; NO:没有被忽略
 */
- (BOOL)isAutoTrackEventTypeIgnored:(ViewHighAnalyticsAutoTrackEventType)eventType;
/**
 * @abstract
 * 位置信息采集功能开关
 *
 * @discussion
 * 根据需要决定是否开启位置采集
 * 默认关闭
 *
 * @param enable YES/NO
 */
- (void)enableTrackGPSLocation:(BOOL)enable;

#pragma mark -- User Profile
/**
 * @abstract
 * 直接设置用户的一个或者几个Profiles
 *
 * @discussion
 * 这些Profile的内容用一个NSDictionary来存储
 * 其中的key是Profile的名称，必须是NSString
 * Value则是Profile的内容，只支持 NSString,NSNumber,NSSet,NSArray
 *                              NSDate这些类型
 * 特别的，NSSet或者NSArray类型的value中目前只支持其中的元素是NSString
 * 如果某个Profile之前已经存在了，则这次会被覆盖掉；不存在，则会创建
 *
 * @param profileDict 要替换的那些Profile的内容
 */
- (void)setUserProfile:(NSDictionary *)profileDict;


/**
 * @abstract
 * 强制试图把数据传到对应的服务器上
 *
 * @discussion
 * 主动调用upload接口，则不论网络类型的限制条件是否满足，都尝试向服务器上传一次数据
 */
- (void)uploadData;

/**
 * @abstract
 * 删除本地缓存的全部事件
 *
 * @discussion
 * 一旦调用该接口，将会删除本地缓存的全部事件，请慎用！
 */
- (void)deleteAll;

@end

NS_ASSUME_NONNULL_END
