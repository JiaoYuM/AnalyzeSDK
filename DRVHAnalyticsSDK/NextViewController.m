//
//  NextViewController.m
//  DRVHAnalyticsSDK
//
//  Created by jiaoyu on 2018/10/31.
//  Copyright © 2018 viewhigh. All rights reserved.
//

#import "NextViewController.h"
#import "VHAnalyticsSDK/DRVHAnalyticsSDK.h"

@interface NextViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (nonatomic,strong)UITableView *tableview;
@property (nonatomic,strong)NSMutableArray *dataArray;
@end

@implementation NextViewController

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];

}
-(NSMutableArray *)dataArray{
    if (_dataArray == nil) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}
- (void)viewDidLoad {
    [super viewDidLoad];

    NSArray *array = @[@"index1",@"index2",@"index3",@"index4"];
    self.dataArray = array.mutableCopy;
    self.view.backgroundColor = [UIColor yellowColor];
    self.title = @"测试Next";

    self.tableview = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height) style:UITableViewStylePlain];
    self.tableview.backgroundColor = [UIColor blueColor];
    self.tableview.delegate = self;
    self.tableview.dataSource = self;
    self.tableview.rowHeight = 44;
    self.tableview.tableFooterView = [[UIView alloc] init];
    self.tableview.VHAnalyticsViewID = @"tableview1";
    [self.view addSubview:self.tableview];


}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataArray.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
         cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = self.dataArray[indexPath.row];
    cell.textLabel.textColor = [UIColor redColor];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"seleted  ====   %ld",indexPath.row);
}

@end
