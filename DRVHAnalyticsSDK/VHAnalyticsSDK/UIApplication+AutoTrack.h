//
//  UIApplication+AutoTrack.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/29.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface UIApplication (AutoTrack)


- (BOOL)vh_sendAction:(SEL)action
                   to:(nullable id)to
                 from:(nullable id)from
             forEvent:(nullable UIEvent *)event;

@end

