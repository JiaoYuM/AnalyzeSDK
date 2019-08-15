//
//  VHDelegateProxy.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/11/2.
//  Copyright © 2018 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface VHDelegateProxy : NSProxy

@property(nonatomic,weak)id target;
+(instancetype)proxyWithTableView:(id)target;
+(instancetype)proxyWithCollectionView:(id)target;

@end

