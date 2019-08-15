//
//  NSObject+VHAnalyticsDelegateProxy.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/11/2.
//  Copyright © 2018 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WKWebView.h>

@class VHDelegateProxy;

@interface NSObject (VHAnalyticsDelegateProxy)

@property (nonatomic,strong) VHDelegateProxy *VHAnalyticsDelegateProxy;

@end

@interface UITableView (VHAnalyticsDelegateProxy)

@end

@interface UICollectionView (VHAnalyticsDelegateProxy)

@end
