//
//  AppDelegate.m
//  QAPMApp
//
//  Created by mdd on 2019/3/1.
//  Copyright © 2019年 mdd. All rights reserved.
//

#import "AppDelegate.h"

#import "QAPMViewController.h"
#import "QAPManager.h" // 1 包含头文件

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 2. 在程序启动`didFinishLaunchingWithOptions`调用初始化方法，参数均必传。
    [QAPManager startWithPid:@"QAPMApp" cid:@"AppStore" vid:@"1.0" uid:@"uuid"];
    // 3. 一些其它设置 将@"https://github.com/qunarcorp" 过滤
    [[QAPManager sharedInstance] setDomainFilterList:@[@"https://github.com/qunarcorp"]];
    
    UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [window setBackgroundColor:[UIColor clearColor]];
    QAPMViewController *vc = [[QAPMViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [window setRootViewController:nav];
    [window makeKeyAndVisible];
    [self setWindow:window];
    return YES;
}
@end
