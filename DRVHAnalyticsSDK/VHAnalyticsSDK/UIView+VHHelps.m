//
//  UIView+VHHelps.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/29.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "UIView+VHHelps.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <CommonCrypto/CommonDigest.h>
#import "VHLogger.h"

#define MP_FINGERPRINT_VERSION 1

@implementation UIView (VHHelps)
- (int)mp_fingerprintVersion {
    return MP_FINGERPRINT_VERSION;
}

- (int)jjf_fingerprintVersion {
    return [self mp_fingerprintVersion];
}

- (UIImage *)sa_snapshotImage {
    CGFloat offsetHeight = 0.0f;

    //Avoid the status bar on phones running iOS < 7
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending &&
        ![UIApplication sharedApplication].statusBarHidden) {
        offsetHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    CGSize size = self.layer.bounds.size;
    size.height -= offsetHeight;
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0f, -offsetHeight);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ([self respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        [self drawViewHierarchyInRect:CGRectMake(0.0f, 0.0f, size.width, size.height) afterScreenUpdates:YES];
    } else {
        [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
#else
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
#endif

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (UIImage *)sa_snapshotForBlur {
    UIImage *image = [self sa_snapshotImage];
    // hack, helps with colors when blurring
    NSData *imageData = UIImageJPEGRepresentation(image, 1); // convert to jpeg
    return [UIImage imageWithData:imageData];
}

// sa_targetActions
- (NSArray *)sa_targetActions {
    NSMutableArray *targetActions = [NSMutableArray array];
    if ([self isKindOfClass:[UIControl class]]) {
        for (id target in [(UIControl *)(self) allTargets]) {
            UIControlEvents allEvents = UIControlEventAllTouchEvents | UIControlEventAllEditingEvents;
            for (NSUInteger e = 0; (allEvents >> e) > 0; e++) {
                UIControlEvents event = allEvents & (0x01 << e);
                if(event) {
                    NSArray *actions = [(UIControl *)(self) actionsForTarget:target forControlEvent:event];
                    NSArray *ignoreActions = @[@"caojiangPreVerify:forEvent:", @"caojiangExecute:forEvent:"];
                    for (NSString *action in actions) {
                        if ([ignoreActions indexOfObject:action] == NSNotFound) {
                            [targetActions addObject:[NSString stringWithFormat:@"%lu/%@", (unsigned long)event, action]];
                        }
                    }
                }
            }
        }
    }
    return [targetActions copy];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
// Set by a userDefinedRuntimeAttr in the SATagNibs.rb script
- (void)setSensorsAnalyticsViewId:(id)object {
    objc_setAssociatedObject(self, @selector(sensorsAnalyticsViewId), [object copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)sa_viewId {
    return objc_getAssociatedObject(self, @selector(mixpanelViewId));
}
#pragma clang diagnostic pop

- (NSString *)sa_controllerVariable {
    NSString *result = nil;
    if ([self isKindOfClass:[UIControl class]]) {
        UIResponder *responder = [self nextResponder];
        while (responder && ![responder isKindOfClass:[UIViewController class]]) {
            responder = [responder nextResponder];
        }
        if (responder) {
            uint count;
            Ivar *ivars = class_copyIvarList([responder class], &count);
            for (uint i = 0; i < count; i++) {
                Ivar ivar = ivars[i];
                if (ivar_getTypeEncoding(ivar)[0] == '@' && object_getIvar(responder, ivar) == self) {
                    result = [NSString stringWithCString:ivar_getName(ivar) encoding:NSUTF8StringEncoding];
                    break;
                }
            }
            free(ivars);
        }
    }
    return result;
}

/*
 Creates a short string which is a fingerprint of a UIButton's image property.
 It does this by downsampling the image to 8x8 and then downsampling the resulting
 32bit pixel data to 8 bit. This should allow us to select images that are identical or
 almost identical in appearance without having to compare the whole image.

 Returns a base64 encoded string representing an 8x8 bitmap of 8 bit rgba data
 (2 bits per component).
 */
- (NSString *)sa_imageFingerprint {
    NSString *result = nil;
    UIImage *originalImage = nil;
    if ([self isKindOfClass:[UIButton class]]) {
        originalImage = [((UIButton *)self) imageForState:UIControlStateNormal];
    } else if ([NSStringFromClass([self class]) isEqual:@"UITabBarButton"] && [self.subviews count] > 0 && [self.subviews[0] respondsToSelector:NSSelectorFromString(@"image")]) {
        originalImage = (UIImage *)[self.subviews[0] performSelector:@selector(image)];
    }

    if (originalImage) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        uint32_t data32[64];
        uint8_t data4[32];
        CGContextRef context = CGBitmapContextCreate(data32, 8, 8, 8, 8*4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
        CGContextSetAllowsAntialiasing(context, NO);
        CGContextClearRect(context, CGRectMake(0, 0, 8, 8));
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextDrawImage(context, CGRectMake(0,0,8,8), [originalImage CGImage]);
        CGColorSpaceRelease(space);
        CGContextRelease(context);
        for(int i = 0; i < 32; i++) {
            int j = 2*i;
            int k = 2*i + 1;
            data4[i] = (((data32[j] & 0x80000000) >> 24) | ((data32[j] & 0x800000) >> 17) | ((data32[j] & 0x8000) >> 10) | ((data32[j] & 0x80) >> 3) |
                        ((data32[k] & 0x80000000) >> 28) | ((data32[k] & 0x800000) >> 21) | ((data32[k] & 0x8000) >> 14) | ((data32[k] & 0x80) >> 7));
        }
        result = [[NSData dataWithBytes:data4 length:32] base64EncodedStringWithOptions:0];
    }
    return result;
}

- (NSString *)sa_text {
    NSString *text = nil;
    SEL titleSelector = NSSelectorFromString(@"title");
    if ([self isKindOfClass:[UILabel class]]) {
        text = ((UILabel *)self).text;
    } else if ([self isKindOfClass:[UIButton class]]) {
        text = [((UIButton *)self) titleForState:UIControlStateNormal];
    } else if ([self respondsToSelector:titleSelector]) {
        IMP titleImp = [self methodForSelector:titleSelector];
        void *(*func)(id, SEL) = (void *(*)(id, SEL))titleImp;
        id title = (__bridge id)func(self, titleSelector);
        if ([title isKindOfClass:[NSString class]]) {
            text = title;
        }
    }
    return text;
}

static NSString* sa_encryptHelper(id input) {
    NSString *SALT = @"dbba253e672cc94bee5da560040b47b1";
    NSMutableString *encryptedStuff = nil;
    if ([input isKindOfClass:[NSString class]]) {
        NSData *data = [[input stringByAppendingString:SALT]  dataUsingEncoding:NSUTF8StringEncoding];
        uint8_t digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
        encryptedStuff = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
        for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
            [encryptedStuff appendFormat:@"%02x", digest[i]];
        }
    }
    if ([input isKindOfClass:[NSString class]]) {

    }
    return encryptedStuff;
}

#pragma mark - Aliases for compatibility
- (NSString *)mp_varA {
    return sa_encryptHelper([self sa_viewId]);
}

- (NSString *)jjf_varA {
    return [self mp_varA];
}

- (NSString *)mp_varB {
    return sa_encryptHelper([self sa_controllerVariable]);
}

- (NSString *)jjf_varB {
    return [self mp_varB];
}

- (NSString *)mp_varC {
    return sa_encryptHelper([self sa_imageFingerprint]);
}

- (NSString *)jjf_varC {
    return [self mp_varC];
}

- (NSArray *)mp_varSetD {
    NSArray *targetActions = [self sa_targetActions];
    NSMutableArray *encryptedActions = [NSMutableArray array];
    for (NSUInteger i = 0 ; i < [targetActions count]; i++) {
        [encryptedActions addObject:sa_encryptHelper(targetActions[i])];
    }
    return encryptedActions;
}

- (NSArray *)jjf_varSetD {
    return [self mp_varSetD];
}

- (NSString *)mp_varE {
    return sa_encryptHelper([self sa_text]);
}

- (NSString *)jjf_varE {
    return [self mp_varE];
}
@end
