//
//  JSONSerializeModel.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/24.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "JSONSerializeModel.h"
#import "VHLogger.h"

@implementation JSONSerializeModel {
    NSDateFormatter *_dateFormatter;
}


-(id)init {
    self = [super init];
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    [_dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC+8"]];
    return self;
}

- (NSData *)JSONSerializeObject:(id)obj{
    id coercedObj = [self JSONSerializableObjectForObject:obj];
    NSError *error = nil;
    NSData *data = nil;
    @try {
        data = [NSJSONSerialization dataWithJSONObject:coercedObj options:0 error:&error];
    }
    @catch (NSException *exception) {
        VHError(@"%@ exception encoding api data: %@", self, exception);
    }
    if (error) {
        VHError(@"%@ error encoding api data: %@", self, error);
    }
    return data;
}

/**
*  @abstract
*  在Json序列化的过程中，对一些不同的类型做一些相应的转换
*
*  @param obj 要处理的对象Object
*
*  @return 处理后的对象Object
*/
- (id)JSONSerializableObjectForObject:(id)obj {
    // valid json types
    if ([obj isKindOfClass:[NSString class]]) {
        return obj;
    }
    //防止 float 精度丢失
    if ([obj isKindOfClass:[NSNumber class]]) {
        NSDecimalNumber *number = [NSDecimalNumber decimalNumberWithDecimal:((NSNumber *)obj).decimalValue];
        return number;
    }
    // recurse on containers
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self JSONSerializableObjectForObject:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id key in obj) {
            NSString *stringKey;
            if (![key isKindOfClass:[NSString class]]) {
                stringKey = [key description];
                VHError(@"%@ warning: property keys should be strings. got: %@. coercing to: %@", self, [key class], stringKey);
            } else {
                stringKey = [NSString stringWithString:key];
            }
            id v = [self JSONSerializableObjectForObject:obj[key]];
            d[stringKey] = v;
        }
        return [NSDictionary dictionaryWithDictionary:d];
    }
    if ([obj isKindOfClass:[NSSet class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id i in obj) {
            [a addObject:[self JSONSerializableObjectForObject:i]];
        }
        return [NSArray arrayWithArray:a];
    }
    // some common cases
    if ([obj isKindOfClass:[NSDate class]]) {
        return [_dateFormatter stringFromDate:obj];
    }
    // default to sending the object's description
    NSString *s = [obj description];
    VHError(@"%@ warning: property values should be valid json types. got: %@. coercing to: %@", self, [obj class], s);
    return s;
}

@end
