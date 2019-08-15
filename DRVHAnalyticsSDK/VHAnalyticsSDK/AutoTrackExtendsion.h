//
//  AutoTrackExtendsion.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/29.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AutoTrackExtendsion : NSObject

+ (void)trackAppClickWithUITableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

+ (void)trackAppClickWithUICollectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;

+ (NSString *)contentFromView:(UIView *)rootView;

+ (void)addViewPathProperties:(NSMutableDictionary *)properties withObject:(UIView *)view withViewController:(UIViewController *)viewController;

@end

