//
//  QAPMViewController.m
//  QAPMApp
//
//  Created by mdd on 2019/3/1.
//  Copyright © 2019年 mdd. All rights reserved.
//

#import "QAPMViewController.h"
#import "QAPMonitor.h"
@interface QAPMViewController ()

@end

@implementation QAPMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self helloQAPM];
    [QAPMonitor netType];
}

- (void)helloQAPM {
    self.title = @"APM";
    UILabel *lbl = [[UILabel alloc] initWithFrame:self.view.bounds];
    lbl.text = @"Hello QAPM";
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.font = [UIFont systemFontOfSize:20];
    [self.view addSubview:lbl];
}

@end
