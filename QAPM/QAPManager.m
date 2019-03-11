//
//  QAPManager.m
//  QAPM_a
//
//  Created by mdd on 2018/11/21.
//  Copyright © 2018年 mdd. All rights reserved.
//

#import "QAPManager.h"
#import "QAPMonitor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach_time.h>
#import "QAPMSystemInfo.h"

@interface QAPManager ()

@property (nonatomic, strong) Class<QAPMExtendDelegate> monitorExtend;
/// 进入Background的cpu时间
@property (nonatomic, assign) long long enterBackgroundTime;
@end

@implementation QAPManager

//+ (void)load {
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self startWithPid:@"123" cid:@"234" vid:@"345" uid:@"456"];
//    });
//}

+ (instancetype)sharedInstance {
    static QAPManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.enterBackgroundTime = 0;
        [[NSNotificationCenter defaultCenter] addObserver:instance selector:@selector(updateBackgroundTime:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    });
    
    return instance;
}

+ (QCacheStorage *)releaseLogInstance {
    return [[QAPMonitor getInstance] gMonitorCache];
}

+ (QCacheStorage *)betaLogInstance {
    return [[QAPMSystemInfo sharedInstance] sysMonitorCache];
}

+ (void)startWithPid:(NSString *)pid cid:(NSString *)cid vid:(NSString *)vid uid:(NSString *)uid {
    [QAPManager sharedInstance];
    [QAPMonitor setupMonitorWithPid:pid cid:cid vid:vid uid:uid];
}

+ (void)registExtend:(id<QAPMExtendDelegate>)extend {
    QAPManager *manager = [self sharedInstance];
    manager.monitorExtend = [extend class];
}

+ (long long)enterBackgroundTime {
    return [[self sharedInstance] enterBackgroundTime];
}

- (void)updateBackgroundTime:(NSNotification*)notification {
    self.enterBackgroundTime = mach_absolute_time();
}

+ (void)addUIMonitor:(NSDictionary *)uiMonitorData {
    [QAPMonitor addUIMonitor:uiMonitorData];
}

+ (void)addNetMonitor:(NSDictionary *)netMonitorData {
    [QAPMonitor addNetMonitor:netMonitorData];
}

#pragma mark - QAPMExtendDelegate协议

/// 获取当前定位信息
+ (nullable CLLocation *)location {
    Class extend = [[QAPManager sharedInstance] monitorExtend];
    if (extend != nil && class_getClassMethod(extend, @selector(location)) != nil) {
        return [extend location];
    }
    return nil;
}

/// 获取当前显示界面
+ (nullable NSString *)appearVC {
    Class extend = [[QAPManager sharedInstance] monitorExtend];
    if (extend != nil && class_getClassMethod(extend, @selector(appearVC)) != nil) {
        return [extend appearVC];
    }
//    return [self topVCName];
    return nil;
}

+ (nullable NSString *)topVCClassName {
    NSString *vcName = nil;
    Class cla = NSClassFromString(@"VCController");
    SEL sel = NSSelectorFromString(@"getTopVC");
    if ([cla respondsToSelector:sel]) {
        id vc = [cla performSelector:sel];
        if (vc) {
            vcName = NSStringFromClass([vc class]);
        }
    }
    return vcName;
}

//+ (NSString *)topVCName {
//    UIViewController *result = nil;
//
//    // 获取mainWindow
//    UIWindow * window = [[UIApplication sharedApplication] keyWindow];
//    if (window.windowLevel != UIWindowLevelNormal) {
//        NSArray *windows = [[UIApplication sharedApplication] windows];
//        for (UIWindow * tmpWin in windows) {
//            if (tmpWin.windowLevel == UIWindowLevelNormal) {
//                window = tmpWin;
//                break;
//            }
//        }
//    }
//
//    // 获取window.rootVC,如果不存在，取window的subviews的最上层VC
//    UIViewController *rootVC = window.rootViewController;
//    if (rootVC == nil) {
//        UIView *backView = [[window subviews] objectAtIndex:0];
//        for (UIView* next = backView; next; next = next.superview) {
//            UIResponder* nextResponder = [next nextResponder];
//            if ([nextResponder isKindOfClass:[UIViewController class]]) {
//                rootVC =  (UIViewController*)nextResponder;
//                break;
//            }
//        }
//    }
//    // 如果存在，则递归获取最上层VC
//    result = [self topVCFromViewController:rootVC];
//
//    return NSStringFromClass([result class]);
//}
//
///// 返回值为顶层VC，vcList为VC栈
//+ (UIViewController *)topVCFromViewController:(UIViewController *)vc {
//    if (vc == nil) {
//        return nil;
//    }
//
//    UIViewController *resultVC = vc;
//    if (vc.presentedViewController != nil) {
//        resultVC = [self topVCFromViewController:vc.presentedViewController];
//    }
//
//    if ([vc isKindOfClass:[UINavigationController class]]) {
//        UIViewController *topVC = ((UINavigationController *)vc).topViewController;
//
//        resultVC = [self topVCFromViewController:topVC];
//    }
//
//    if ([vc isKindOfClass:[UITabBarController class]]) {
//        UIViewController *selectedVC  = ((UITabBarController *)vc).selectedViewController;
//        resultVC = [self topVCFromViewController:selectedVC];
//    }
//
//    return resultVC;
//}

@end
