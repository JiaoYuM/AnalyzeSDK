//
//  ViewController.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/8.
//  Copyright © 2018年 viewhigh. All rights reserved.
//

#import "ViewController.h"
#import "NextViewController.h"
#import "VHAnalyticsSDK/DRVHAnalyticsSDK.h"
@interface ViewController ()



@end

@implementation ViewController {
    BOOL _disable;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"测试Track" forState:UIControlStateNormal];
    button.frame = CGRectMake(50, 100, 220, 200);
    [button setBackgroundColor:[UIColor redColor]];
    [button addTarget:self action:@selector(clickTrack:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];


    UIButton *button1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [button1 setTitle:@"禁用" forState:UIControlStateNormal];
    button1.frame = CGRectMake(50, 400, 220, 200);
    [button1 setBackgroundColor:[UIColor redColor]];
    [button1 addTarget:self action:@selector(stopClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button1];

    // Do any additional setup after loading the view, typically from a nib.
}

-(void)stopClick:(UIButton *)sender{
    _disable = !_disable;
    if (_disable) {
        [sender setTitle:@"启用" forState:UIControlStateNormal];
    }else{
        [sender setTitle:@"禁用" forState:UIControlStateNormal];
    }
    [[DRVHAnalyticsSDK sharedInstance] disableSDK:_disable];
}
-(void)clickTrack:(UIButton *)sender{

    [[DRVHAnalyticsSDK sharedInstance] login:@"jiaoy"];
    [[DRVHAnalyticsSDK sharedInstance] track:@"PPPP" withProperties:@{@"name":@"jiao",@"age":@"22"}];
//    [[DRVHAnalyticsSDK sharedInstance] uploadData];

    NextViewController *nextVC = [[NextViewController alloc] init];
    [self.navigationController pushViewController:nextVC animated:YES];
    
}



@end
