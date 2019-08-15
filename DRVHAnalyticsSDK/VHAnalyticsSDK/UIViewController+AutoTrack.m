//
//  UIViewController+AutoTrack.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/26.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "UIViewController+AutoTrack.h"
#import "DRVHAnalyticsSDK.h"
#import "VHLogger.h"

@implementation UIViewController (AutoTrack)

-(void)autoTrack_viewWillAppear:(BOOL)animated{
    @try {
        if ([[DRVHAnalyticsSDK sharedInstance] isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppViewScreen] == NO) {
            UIViewController *viewController = (UIViewController *)self;
            if (![viewController.parentViewController isKindOfClass:[UIViewController class]] ||
                [viewController.parentViewController isKindOfClass:[UITabBarController class]] ||
                [viewController.parentViewController isKindOfClass:[UINavigationController class]] ) {
                [[DRVHAnalyticsSDK sharedInstance] trackViewScreenStart: viewController];
            }
        }
    } @catch (NSException *exception) {
        VHError(@"%@ error: %@", self, exception);
    } @finally {

    }
}

-(void)autoTrack_viewWillDisAppear:(BOOL)animated{
    @try {
        if ([[DRVHAnalyticsSDK sharedInstance] isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppViewScreen] == NO) {
            UIViewController *viewController = (UIViewController *)self;
            if (![viewController.parentViewController isKindOfClass:[UIViewController class]] ||
                [viewController.parentViewController isKindOfClass:[UITabBarController class]] ||
                [viewController.parentViewController isKindOfClass:[UINavigationController class]] ) {
                [[DRVHAnalyticsSDK sharedInstance] trackViewScreenEnd: viewController];
            }
        }
    } @catch (NSException *exception) {
        VHError(@"%@ error: %@", self, exception);
    } @finally {

    }
}

@end
