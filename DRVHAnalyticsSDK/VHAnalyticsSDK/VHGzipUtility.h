//
//  VHGzipUtility.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/29.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface VHGzipUtility : NSObject

+(NSData*) gzipData: (NSData*)pUncompressedData;

@end

