//
//  UIViewController+AutoTrack.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/26.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface UIViewController (AutoTrack)

-(void)autoTrack_viewWillAppear:(BOOL)animated;
-(void)autoTrack_viewWillDisAppear:(BOOL)animated;

@end


