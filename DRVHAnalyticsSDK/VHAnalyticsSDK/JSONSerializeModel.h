//
//  JSONSerializeModel.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/24.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface JSONSerializeModel : NSObject

/**
 *  @abstract
 *  把一个Object转成Json字符串
 *
 *  @param obj 要转化的对象Object
 *
 *  @return 转化后得到的字符串
 */
- (NSData *)JSONSerializeObject:(id)obj;

/**
 *  初始化
 *
 *  @return 初始化后的对象
 */
- (id) init;


@end

