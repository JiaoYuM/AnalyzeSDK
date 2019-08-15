//
//  DRVHAnalyticsSDK+Private.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/11/2.
//  Copyright © 2018 viewhigh. All rights reserved.
//


#ifndef DRVHAnalyticsSDK_Private_h
#define DRVHAnalyticsSDK_Private_h

#import "DRVHAnalyticsSDK.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/Webkit.h>

@interface DRVHAnalyticsSDK (Private)

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;


@end

#endif

