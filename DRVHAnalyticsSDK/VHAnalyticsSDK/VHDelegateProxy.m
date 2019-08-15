//
//  VHDelegateProxy.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/11/2.
//  Copyright © 2018 viewhigh. All rights reserved.
//

#import "VHDelegateProxy.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "DRVHAnalyticsSDK+Private.h"
#import "DRVHAnalyticsSDK.h"

@interface VHTableViewDelegateProxy :VHDelegateProxy<UITableViewDelegate>

@end
@implementation VHTableViewDelegateProxy
- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.target];
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.target respondsToSelector:_cmd]) {
        [DRVHAnalyticsSDK.sharedInstance tableView:tableView didSelectRowAtIndexPath:indexPath];
        [self.target tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

@end


@interface VHCollectionViewDelegateProxy:VHDelegateProxy<UICollectionViewDelegate>
@end

@implementation VHCollectionViewDelegateProxy

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.target];
}
-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if ([self.target respondsToSelector:_cmd]) {
        [DRVHAnalyticsSDK.sharedInstance collectionView:collectionView didSelectItemAtIndexPath:indexPath];
        [self.target collectionView:collectionView didSelectItemAtIndexPath:indexPath];
    }
}
@end


@implementation VHDelegateProxy
+(instancetype)proxyWithTableView:(id)target {
    VHTableViewDelegateProxy *delegateProxy = [[VHTableViewDelegateProxy alloc]initWithObject:target];
    return delegateProxy;
}

+(instancetype)proxyWithCollectionView:(id)target {
    VHCollectionViewDelegateProxy *delegateProxy = [[VHCollectionViewDelegateProxy alloc]initWithObject:target];
    return delegateProxy;
}

- (id)initWithObject:(id)object {
    self.target = object;
    return self;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.target methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {

}

-(BOOL)respondsToSelector:(SEL)aSelector{
    if (aSelector == @selector(tableView:didSelectRowAtIndexPath:)) {
        return YES;
    }
    if (aSelector == @selector(collectionView:didSelectItemAtIndexPath:)) {
        return YES;
    }
    return [self.target respondsToSelector:aSelector];
}

-(void)dealloc {
    self.target = nil;
}

@end
