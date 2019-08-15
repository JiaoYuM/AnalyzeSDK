//
//  NSObject+VHSwizzle.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/23.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (VHSwizzle)

+ (BOOL)vh_swizzleMethod:(SEL)origSel_ withMethod:(SEL)altSel_ error:(NSError **)error_;
+ (BOOL)vh_swizzleClassMethod:(SEL)origSel_ withClassMethod:(SEL)altSel_ error:(NSError **)error_;

@end

NS_ASSUME_NONNULL_END
