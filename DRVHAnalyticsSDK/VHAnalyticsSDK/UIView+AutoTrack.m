//
//  UIView+AutoTrack.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/29.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "UIView+AutoTrack.h"

@implementation UIView (AutoTrack)
-(NSString *)vh_elementContent {
    return nil;
}
@end

@implementation UIButton (AutoTrack)
-(NSString *)vh_elementContent {
    NSString *elementContent = self.currentAttributedTitle.string;
    if (elementContent != nil && elementContent.length > 0) {
        return elementContent;
    }
    return self.currentTitle;
}
@end

@implementation UILabel (AutoTrack)
-(NSString *)vh_elementContent {
    NSString *attributedText = self.attributedText.string;
    if (attributedText != nil && attributedText.length > 0) {
        return attributedText;
    }
    return self.text;
}
@end

@implementation UITextView (AutoTrack)
-(NSString *)vh_elementContent {
    NSString *attributedText = self.attributedText.string;
    if (attributedText != nil && attributedText.length > 0) {
        return attributedText;
    }
    return  self.text;
}
@end
