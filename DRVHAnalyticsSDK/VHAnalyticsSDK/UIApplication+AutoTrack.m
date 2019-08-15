//
//  UIApplication+AutoTrack.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/29.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "UIApplication+AutoTrack.h"
#import "VHLogger.h"
#import "DRVHAnalyticsSDK.h"
#import "AutoTrackExtendsion.h"
#import "UIView+AutoTrack.h"
#import "UIView+VHHelps.h"
@implementation UIApplication (AutoTrack)
- (BOOL)vh_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {

    /*
     默认先执行 AutoTrack
     如果先执行原点击处理逻辑，可能已经发生页面 push 或者 pop，导致获取当前 ViewController 不正确
     可以通过 UIView 扩展属性 sensorsAnalyticsAutoTrackAfterSendAction，来配置 AutoTrack 是发生在原点击处理函数之前还是之后
     */

    BOOL ret = YES;
    BOOL vhAnalyticsAutoTrackAfterSendAction = NO;

    @try {
        if (from) {
            if ([from isKindOfClass:[UIView class]]) {
                UIView* view = (UIView *)from;
                if (view) {
                    if (view.VHAnalyticsAutoTrackAfterSendAction) {
                        vhAnalyticsAutoTrackAfterSendAction = YES;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        VHError(@"%@ error: %@", self, exception);
        vhAnalyticsAutoTrackAfterSendAction = NO;
    }

    if (vhAnalyticsAutoTrackAfterSendAction) {
        ret = [self vh_sendAction:action to:to from:from forEvent:event];
    }

    @try {
        [self vh_track:action to:to from:from forEvent:event];
    } @catch (NSException *exception) {
        VHError(@"%@ error: %@", self, exception);
    }

    if (!vhAnalyticsAutoTrackAfterSendAction) {
        ret = [self vh_sendAction:action to:to from:from forEvent:event];
    }

    return ret;
}

- (void)vh_track:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    @try {
        //关闭 AutoTrack
        if (![[DRVHAnalyticsSDK sharedInstance] isAutoTrackEnabled]) {
            return;
        }

        //忽略 $AppClick 事件
        if ([[DRVHAnalyticsSDK sharedInstance] isAutoTrackEventTypeIgnored:ViewHighAnalyticsEventTypeAppClick]) {
            return;
        }

        // ViewType 被忽略
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
        if ([from isKindOfClass:[NSClassFromString(@"UITabBarButton") class]]) {
            if ([[DRVHAnalyticsSDK sharedInstance] isViewTypeIgnored:[UITabBar class]]) {
                return;
            }
        } else if ([from isKindOfClass:[NSClassFromString(@"UINavigationButton") class]]) {
            if ([[DRVHAnalyticsSDK sharedInstance] isViewTypeIgnored:[UIBarButtonItem class]]) {
                return;
            }
        } else
#endif
            if ([to isKindOfClass:[UISearchBar class]]) {
                if ([[DRVHAnalyticsSDK sharedInstance] isViewTypeIgnored:[UISearchBar class]]) {
                    return;
                }
            } else {
                if ([[DRVHAnalyticsSDK sharedInstance] isViewTypeIgnored:[from class]]) {
                    return;
                }
            }

        /*
         此处不处理 UITabBar，放到 UITabBar+AutoTrack.h 中处理
         */
        if (from != nil) {
            if ([from isKindOfClass:[UIBarButtonItem class]]) {
                return;
            }
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
            if ([from isKindOfClass:[NSClassFromString(@"UITabBarButton") class]]) {
                return;
            }
#else
            if ([to isKindOfClass:[UITabBar class]]) {
                return;
            }
#endif
        }

        if (([event isKindOfClass:[UIEvent class]] && event.type==UIEventTypeTouches) ||
            [from isKindOfClass:[UISwitch class]] ||
            [from isKindOfClass:[UIStepper class]] ||
            [from isKindOfClass:[UISegmentedControl class]]) {//0
            if (![from isKindOfClass:[UIView class]]) {
                return;
            }

            UIView* view = (UIView *)from;
            if (!view) {
                return;
            }

            if (view.VHAnalyticsIgnoreView) {
                return;
            }

            NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];

            //ViewID
            if (view.VHAnalyticsViewID != nil) {
                [properties setValue:view.VHAnalyticsViewID forKey:@"$element_id"];
            }

            UIViewController *viewController = [view viewController];

            if (viewController == nil || [viewController isKindOfClass:UINavigationController.class]) {
                viewController = [[DRVHAnalyticsSDK sharedInstance] currentViewController];
            }

            if (viewController != nil) {
                if ([[DRVHAnalyticsSDK sharedInstance] isViewControllerIgnored:viewController]) {
                    return;
                }

                //获取 Controller 名称($screen_name)
                NSString *screenName = NSStringFromClass([viewController class]);
                [properties setValue:screenName forKey:@"$page_name"];

                NSString *controllerTitle = viewController.navigationItem.title;
                if (controllerTitle != nil) {
                    [properties setValue:viewController.navigationItem.title forKey:@"$title"];
                }
                //再获取 controller.navigationItem.titleView, 并且优先级比较高
                NSString *elementContent = [[DRVHAnalyticsSDK sharedInstance] getUIViewControllerTitle:viewController];
                if (elementContent != nil && [elementContent length] > 0) {
                    elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                    [properties setValue:elementContent forKey:@"$title"];
                }
            }

            //UISwitch
            if ([from isKindOfClass:[UISwitch class]]) {
                [properties setValue:@"UISwitch" forKey:@"$element_type"];
                UISwitch *uiSwitch = (UISwitch *)from;
                if (uiSwitch.on) {
                    [properties setValue:@"checked" forKey:@"$element_content"];
                } else {
                    [properties setValue:@"unchecked" forKey:@"$element_content"];
                }

                [AutoTrackExtendsion addViewPathProperties:properties withObject:uiSwitch withViewController:viewController];

                //View Properties
                NSDictionary* propDict = view.VHAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }
                [[DRVHAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties withType:@"2"];
                return;
            }

            //UIStepper
            if ([from isKindOfClass:[UIStepper class]]) {
                [properties setValue:@"UIStepper" forKey:@"$element_type"];
                UIStepper *stepper = (UIStepper *)from;
                if (stepper) {
                    [properties setValue:[NSString stringWithFormat:@"%g", stepper.value] forKey:@"$element_content"];
                }

                [AutoTrackExtendsion addViewPathProperties:properties withObject:stepper withViewController:viewController];

                //View Properties
                NSDictionary* propDict = view.VHAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }
                [[DRVHAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties withType:@"2"];
                return;
            }

            //UISearchBar
                    if ([to isKindOfClass:[UISearchBar class]] && [from isKindOfClass:[[NSClassFromString(@"UISearchBarTextField") class] class]]) {
                        UISearchBar *searchBar = (UISearchBar *)to;
                        if (searchBar != nil) {
                            [properties setValue:@"UISearchBar" forKey:@"$element_type"];
                            NSString *searchText = searchBar.text;
                            if (searchText == nil || [searchText length] == 0) {
                                [[DRVHAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties withType:@"2"];
                                return;
                            }
                        }
                    }

            //UISegmentedControl
            if ([from isKindOfClass:[UISegmentedControl class]]) {
                UISegmentedControl *segmented = (UISegmentedControl *)from;
                [properties setValue:@"UISegmentedControl" forKey:@"$element_type"];

                if ([segmented selectedSegmentIndex] == UISegmentedControlNoSegment) {
                    return;
                }
                [properties setValue:[NSString stringWithFormat: @"%ld", (long)[segmented selectedSegmentIndex]] forKey:@"$element_position"];
                [properties setValue:[segmented titleForSegmentAtIndex:[segmented selectedSegmentIndex]] forKey:@"$element_content"];

                [AutoTrackExtendsion addViewPathProperties:properties withObject:segmented withViewController:viewController];

                //View Properties
                NSDictionary* propDict = view.VHAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }
                [[DRVHAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties withType:@"2"];
                return;

            }

            //只统计触摸结束时
            if ([event isKindOfClass:[UIEvent class]] && [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
                if ([from isKindOfClass:[NSClassFromString(@"UINavigationButton") class]]) {
                    UIButton *button = (UIButton *)from;
                    [properties setValue:@"UIBarButtonItem" forKey:@"$element_type"];
                    if (button != nil) {
                        NSString *currentTitle = button.vh_elementContent;
                        if (currentTitle != nil) {
                            [properties setValue:currentTitle forKey:@"$element_content"];
                        } else {
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UIIMAGE_IMAGENAME
                            UIImage *image = button.currentImage;
                            if (image) {
                                NSString *imageName = image.sensorsAnalyticsImageName;
                                if (imageName != nil) {
                                    [properties setValue:[NSString stringWithFormat:@"$%@", imageName] forKey:@"$element_content"];
                                }
                            }
#endif
                        }
                    }
                } else
#endif
                    if ([from isKindOfClass:[UIButton class]]) {//UIButton
                        UIButton *button = (UIButton *)from;
                        [properties setValue:@"UIButton" forKey:@"$element_type"];
                        if (button != nil) {
                            NSString *currentTitle = button.vh_elementContent;
                            if (currentTitle != nil) {
                                [properties setValue:currentTitle forKey:@"$element_content"];
                            } else {
                                if (button.subviews.count > 0) {
                                    NSString *elementContent = [[NSString alloc] init];
                                    elementContent = [AutoTrackExtendsion contentFromView:button];
                                    if (elementContent != nil && [elementContent length] > 0) {
                                        elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                                        [properties setValue:elementContent forKey:@"$element_content"];
                                    } else {
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UIIMAGE_IMAGENAME
                                        UIImage *image = button.currentImage;
                                        if (image) {
                                            NSString *imageName = image.vhAnalyticsImageName;
                                            if (imageName != nil) {
                                                [properties setValue:[NSString stringWithFormat:@"$%@", imageName] forKey:@"$element_content"];
                                            }
                                        }
#endif
                                    }
                                }
                            }
                        }
                    }
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
                    else if ([from isKindOfClass:[NSClassFromString(@"UITabBarButton") class]]) {//UITabBarButton
                        if ([to isKindOfClass:[UITabBar class]]) {//UITabBar
                            UITabBar *tabBar = (UITabBar *)to;
                            if (tabBar != nil) {
                                UITabBarItem *item = [tabBar selectedItem];
                                [properties setValue:@"UITabbar" forKey:@"$element_type"];
                                [properties setValue:item.title forKey:@"$element_content"];
                            }
                        }
                    }
#endif
                    else if([from isKindOfClass:[UITabBarItem class]]){//For iOS7 TabBar
                        UITabBarItem *tabBarItem = (UITabBarItem *)from;
                        if (tabBarItem) {
                            [properties setValue:@"UITabbar" forKey:@"$element_type"];
                            [properties setValue:tabBarItem.title forKey:@"$element_content"];
                        }
                    } else if ([from isKindOfClass:[UISlider class]]) {//UISlider
                        UISlider *slide = (UISlider *)from;
                        if (slide != nil) {
                            [properties setValue:@"UISlider" forKey:@"$element_type"];
                            [properties setValue:[NSString stringWithFormat:@"%f",slide.value] forKey:@"$element_content"];
                        }
                    } else {
                        if ([from isKindOfClass:[UIControl class]]) {
                            [properties setValue:@"UIControl" forKey:@"$element_type"];
                            UIControl *fromView = (UIControl *)from;
                            if (fromView.subviews.count > 0) {
                                NSString *elementContent = [[NSString alloc] init];
                                elementContent = [AutoTrackExtendsion contentFromView:fromView];
                                if (elementContent != nil && [elementContent length] > 0) {
                                    elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                                    [properties setValue:elementContent forKey:@"$element_content"];
                                }
                            }
                        }
                    }

                [AutoTrackExtendsion addViewPathProperties:properties withObject:view withViewController:viewController];

                //View Properties
                NSDictionary* propDict = view.VHAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }

                [[DRVHAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties withType:@"2"];
            }
        }
    } @catch (NSException *exception) {
        VHError(@"%@ error: %@", self, exception);
    }
}

@end
