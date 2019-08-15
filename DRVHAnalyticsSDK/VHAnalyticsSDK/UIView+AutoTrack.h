//
//  UIView+AutoTrack.h
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/29.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@protocol VHUIViewAutoTrack

@optional
-(NSString *)vh_elementContent;
@end;


@interface UIView (AutoTrack)<VHUIViewAutoTrack>;

-(NSString *)vh_elementContent;

@end

@interface UIButton (AutoTrack)<VHUIViewAutoTrack>
-(NSString *)vh_elementContent;
@end

@interface UILabel (AutoTrack)<VHUIViewAutoTrack>
-(NSString *)vh_elementContent;
@end

@interface UITextView (AutoTrack)<VHUIViewAutoTrack>
-(NSString *)vh_elementContent;
@end
