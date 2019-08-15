//
//  NSObject+VHAnalyticsDelegateProxy.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/11/2.
//  Copyright © 2018 viewhigh. All rights reserved.
//

#import "NSObject+VHAnalyticsDelegateProxy.h"
#import <objc/runtime.h>
#import <objc/objc.h>
#import <objc/message.h>
#import "VHDelegateProxy.h"

void vh_setDelegate(id obj ,SEL sel, id delegate){
    SEL swizzileSel = sel_getUid("vh_setDelegate:");
    if (delegate != nil) {
        VHDelegateProxy *delegateProxy = nil;
        if ([obj isKindOfClass:UITableView.class]) {
            delegateProxy = [VHDelegateProxy proxyWithTableView:delegate];
        }else if ([obj isKindOfClass:UICollectionView.class]){
            delegateProxy = [VHDelegateProxy proxyWithCollectionView:delegate];
        }
        delegate = delegateProxy;
    }
    [(NSObject *)obj setVHAnalyticsDelegateProxy:delegate];
    ((void (*)(id, SEL,id))objc_msgSend)(obj,swizzileSel,delegate);
}
@implementation NSObject (VHAnalyticsDelegateProxy)

-(void)setVHAnalyticsDelegateProxy:(VHDelegateProxy *)VHAnalyticsDelegateProxy{
    objc_setAssociatedObject(self, @selector(setVHAnalyticsDelegateProxy:), VHAnalyticsDelegateProxy, OBJC_ASSOCIATION_RETAIN);
}

-(VHDelegateProxy *)VHAnalyticsDelegateProxy{
    return objc_getAssociatedObject(self, @selector(setVHAnalyticsDelegateProxy:));
}

@end

@implementation UITableView (VHAnalyticsDelegateProxy)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL origSel_ = sel_getUid("setDelegate:");
        SEL swizzileSel = sel_getUid("vh_setDelegate:");
        Method origMethod = class_getInstanceMethod(self, origSel_);
        const char* type = method_getTypeEncoding(origMethod);
        class_addMethod(self, swizzileSel, (IMP)vh_setDelegate, type);
        Method swizzleMethod = class_getInstanceMethod(self, swizzileSel);
        IMP origIMP = method_getImplementation(origMethod);
        IMP swizzleIMP = method_getImplementation(swizzleMethod);
        method_setImplementation(origMethod, swizzleIMP);
        method_setImplementation(swizzleMethod, origIMP);
    });
}

@end

@implementation UICollectionView (VHAnalyticsDelegateProxy)

+(void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL origSel_ = sel_getUid("setDelegate:");
        SEL swizzileSel = sel_getUid("vh_setDelegate:");
        Method origMethod = class_getInstanceMethod(self, origSel_);
        const char* type = method_getTypeEncoding(origMethod);
        class_addMethod(self, swizzileSel, (IMP)vh_setDelegate, type);
        Method swizzleMethod = class_getInstanceMethod(self, swizzileSel);
        IMP origIMP = method_getImplementation(origMethod);
        IMP swizzleIMP = method_getImplementation(swizzleMethod);
        method_setImplementation(origMethod, swizzleIMP);
        method_setImplementation(swizzleMethod, origIMP);
    });
}

@end
