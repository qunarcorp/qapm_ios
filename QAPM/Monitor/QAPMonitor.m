//
//  Monitor.m
//  CommonFramework
//
//  Created by zhou on 16/1/14.
//  Copyright © 2016年 Qunar.com. All rights reserved.
//

#import "QAPMonitor.h"
#import <objc/runtime.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <CoreLocation/CLLocationManager.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "NSURLConnection+QunarAPM.h"
#import "NSURLSession+QunarAPM.h"
#import "Reachability.h"
#import "QAPManager.h"
#import "QCacheStorage.h"
#import "QAPFPSMonitor.h"
#import "QAPMSystemInfo.h"

#define kMonitorStorageKey                  @"AppMonitorStorageKey"
#define kMinMonitorNumber                   10

@interface QAPMonitor ()
/// 新格式，d新格式稳定后  老格式暂时保留：arrayNetwork、arrayUI
@property (atomic, strong) NSMutableArray<NSDictionary *>          *arrayMonitor;
@property (nonatomic, strong) NSString                             *searchURL;        // 最近成功的URL

@property (nonatomic, strong) NSString                             *vid;              // 版本号
@property (nonatomic, strong) NSString                             *pid;              // 产品号
@property (nonatomic, strong) NSString                             *uid;              // 设备号
@property (nonatomic, strong) NSString                             *cid;              // 渠道标识
@property (nonatomic, assign) BOOL isForeground;
@property (nonatomic, strong) QAPFPSMonitor *fpsMonitor;
@property (nonatomic, strong) QCacheStorage *gMonitorCache;
@end

static QAPMonitor *globalMonitor = nil;
static NSLock *globalMonitorWriteLock = nil;

@implementation QAPMonitor

+ (instancetype)getInstance {
    @synchronized(self) {
        // 实例对象只分配一次
        if (globalMonitor == nil) {
            globalMonitor = [[QAPMonitor alloc] init];
            NSString *defaultDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
            NSString *rlt = [defaultDirectory stringByAppendingPathComponent:@"QAPMonitorLog"];
            globalMonitor.gMonitorCache = [QCacheStorage cacheStorageWithDir:rlt];
            globalMonitor.gMonitorCache.maxCacheSize = 5;
            [globalMonitor setSearchURL:nil];
            globalMonitorWriteLock = [[NSLock alloc] init];
            
            if ([globalMonitor arrayMonitor] == nil) {
                [globalMonitor setArrayMonitor:[[NSMutableArray alloc] initWithCapacity:0]];
            }
            [globalMonitor registerNotification];
        }
    }
    return globalMonitor;
}

+ (void)addUIMonitor:(NSDictionary *)uiMonitorData {
    [self addMonitorData:uiMonitorData];
}

+ (void)addNetMonitor:(NSDictionary *)netMonitorData {
    [self addMonitorData:netMonitorData];
}

+ (void)addFPSMonitor:(NSDictionary *)fpsMonitorData {
    [self addMonitorData:fpsMonitorData];
}

+ (void)addMonitorData:(NSDictionary *)monitorData {
    [[QAPMonitor getInstance] lock];
    if (monitorData.count > 0) {
        [[[QAPMonitor getInstance] arrayMonitor] addObject:monitorData];
        if ([[[QAPMonitor getInstance] arrayMonitor] count] >= 10) {
            NSDictionary *cparam = [[QAPMonitor getInstance] commonParam];
            NSDictionary *data = @{@"c":cparam,@"b":[[QAPMonitor getInstance] arrayMonitor]};
            [[QAPMonitor getInstance] setArrayMonitor:@[].mutableCopy];
            [[[self getInstance] gMonitorCache] saveData:data toFile:[QCacheStorage autoIncrementFileName]];
            [[QAPMonitor getInstance] sendMonitorToServer];
        }
    }
    [[QAPMonitor getInstance] unlock];
}

- (void)saveAllMonitorData {
    if ([[[QAPMonitor getInstance] arrayMonitor] count] > 0) {
        NSDictionary *cparam = [[QAPMonitor getInstance] commonParam];
        NSDictionary *data = @{@"c":cparam?:@{},@"b":[[QAPMonitor getInstance] arrayMonitor]};
        [[QAPMonitor getInstance] setArrayMonitor:@[].mutableCopy];
        [self.gMonitorCache saveData:data toFile:[QCacheStorage autoIncrementFileName]];
        [self.gMonitorCache saveCacheToFile:nil];
    }
}

+ (void)addMonitor:(NSDictionary *)monitorData withType:(eMonitorType)type {
    NSMutableDictionary *dictM = nil;
    [[QAPMonitor getInstance] lock];
    if ([monitorData count] > 0) {
        switch (type)
        {
            case eNetworkTaskMonitor:
            {
                NSString *reqUrl = [monitorData objectForKey:@"reqUrl"];
                NSString *code = [monitorData objectForKey:@"httpCode"];
                if (reqUrl != nil && [reqUrl length] > 0 && code != nil && [code length] > 0 && [code isEqualToString:@"200"])
                {
                    [[QAPMonitor getInstance] setSearchURL:reqUrl];
                }
                dictM = monitorData.mutableCopy;
                dictM[@"action"] = @"iosNet";
            }
                break;
                
            default:
                break;
        }
    }
    [[QAPMonitor getInstance] unlock];
    if (dictM) {
        [self addMonitorData:dictM];
#if (BETA_BUILD == 1) || DEBUG
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[QAPMSystemInfo sharedInstance] addArrayMonitor:dictM];
        });
#endif
    }
}

+ (void)setupMonitorWithPid:(nonnull NSString *)pid
                        cid:(nullable NSString *)cid
                        vid:(nullable NSString *)vid
                        uid:(nullable NSString *)uid {
    
    [[QAPMonitor getInstance] setPid:pid];
    [[QAPMonitor getInstance] setCid:cid];
    [[QAPMonitor getInstance] setVid:vid];
    [[QAPMonitor getInstance] setUid:uid];
    [[QAPMonitor getInstance] setIsForeground:YES];
    [QAPMonitor setupMonitor];
}

+ (void)setupMonitor {
    // 初始化对 NSURLConnection/UIViewController 的监控
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        [QAPMonitor getInstance];
        [NSURLConnection QAPMSetupPerformanceMonitoring];
        [NSURLSession QAPMSetupPerformanceMonitoring];
        Class classInstance = NSClassFromString(@"QAPMVCLoadingMonitor");
        SEL sel = NSSelectorFromString(@"startVCLoadingMonitor");
        if ([classInstance respondsToSelector:sel]) {
            [classInstance performSelector:sel withObject:nil];
        }
        globalMonitor.fpsMonitor = [[QAPFPSMonitor alloc] init];
        [globalMonitor.fpsMonitor startFPSMonitor];
#if (BETA_BUILD == 1) || DEBUG
        [[QAPMSystemInfo sharedInstance] startMonitor];
#endif
    });
}

+ (void)sendMonitor {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[QAPMonitor getInstance] sendMonitor];
    });
}

+ (NSString *)lastSearchURL {
    return [[QAPMonitor getInstance] searchURL];
}

+ (NSString *)vid {
    return [[QAPMonitor getInstance] vid];
}

+ (NSString *)uid {
    return [[QAPMonitor getInstance] uid];
}

+ (BOOL)isForeground {
    return [[self getInstance] isForeground];
}

+ (void)enterBackground {
    [[self getInstance] setIsForeground:NO];
    [[self getInstance] sendMonitor];
}

+ (void)enterForeground {
    [[self getInstance] setIsForeground:YES];
}

- (void)registerNotification {
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(sendMonitor)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(enterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[self class]
                                             selector:@selector(enterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[QAPMonitor getInstance]
                                             selector:@selector(delaySendMonitor)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
}
/// 启动延迟三秒发送，避免影响性能
- (void)delaySendMonitor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self sendMonitor];
    });
}

- (void)unregisterNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:[QAPMonitor getInstance]];
}

- (void)lock {
    if ([QAPMonitor getInstance] != nil) {
        [globalMonitorWriteLock lock];
    }
}

- (void)unlock {
    if ([QAPMonitor getInstance] != nil) {
        [globalMonitorWriteLock unlock];
    }
}

- (void)sendMonitor {
    [[QAPMonitor getInstance] lock];
    // 退到后台或者退出程序先保存到本地，t然后启动发送
    [self saveAllMonitorData];
    [[QAPMonitor getInstance] sendMonitorToServer];
    [[QAPMonitor getInstance] unlock];
}

- (void)sendMonitorToServer {
    __weak typeof(self) weakSelf = self;
    [self.gMonitorCache earlyFile:^(NSDictionary *data) {
        if (data) {
            NSString *fileName = data.allKeys.firstObject;
            NSDictionary *fileData = data[fileName];
            if ([fileData isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = @{@"monitor":fileName};
                if (weakSelf.uploadUrl) {
                    [weakSelf uploadLoadData:fileData withFileName:(NSString *)fileName WithURLString:weakSelf.uploadUrl];
                }
                else {                
                    [weakSelf qunarSendData:fileData customInfo:dictionary];
                }
            }
        }
    }];
}

- (void)uploadLoadData:(NSDictionary *)fileData withFileName:(NSString *)fileName  WithURLString:(NSString *)urlString {
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (fileData != nil) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:fileData options:NSJSONWritingPrettyPrinted error:nil];
        request.HTTPBody = data;
    }
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && (error == nil)) {
            [[weakSelf gMonitorCache] deleteFile:fileName];
            [weakSelf sendMonitorToServer];
        } else {
            [[weakSelf gMonitorCache] sendFileErrorAddFile:fileName];
        }
    }];
    // 5.每一个任务默认都是挂起的，需要调用 resume 方法
    [dataTask resume];
}

#pragma mark - qunar inner

- (void)qunarSendData:(NSDictionary *)data customInfo:(NSDictionary *)info {
    Class classInstance = NSClassFromString(@"QAPMNetworkTask");
    SEL sel = NSSelectorFromString(@"sendData:forInfo:");
    if ([classInstance respondsToSelector:sel]) {
        [classInstance performSelector:sel withObject:data withObject:info];
    }
}

// 获取网络请求回调
+ (void)networkCallback:(NSNumber *)status forInfo:(NSDictionary *)customInfo {
    BOOL success = status.boolValue;
    NSString *fileName = [customInfo objectForKey:@"monitor"];
    if (fileName) {
        if (success) {
            [[[self getInstance] gMonitorCache] deleteFile:fileName];
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [[self getInstance] sendMonitorToServer];
            });
        }
        else {
            [[[self getInstance] gMonitorCache] sendFileErrorAddFile:fileName];
        }
    }
}

#pragma mark - qunar inner end


- (NSDictionary *)commonParam {
    NSMutableDictionary *cParam = [[NSMutableDictionary alloc] init];
    
    // 版本号
    NSString *vid = [[QAPMonitor getInstance] vid];
    if (vid.length > 0) {
        [cParam setObject:vid forKey:@"vid"];
    }
    
    // 程序号
    NSString *pid = [[QAPMonitor getInstance] pid];
    if (pid.length > 0) {
        [cParam setObject:pid forKey:@"pid"];
    }
    
    // 渠道号
    NSString *cid = [[QAPMonitor getInstance] cid];
    if (cid.length > 0) {
        [cParam setObject:cid forKey:@"cid"];
    }
    
    // 设备标识符
    NSString *uid = [[QAPMonitor getInstance] uid];
    if (uid.length > 0) {
        [cParam setObject:uid forKey:@"uid"];
    }
    CLLocation *location = [QAPManager location];
    NSString *loc = location? [NSString stringWithFormat:@"%f,%f", location.coordinate.longitude, location.coordinate.latitude]:@"Unknown";
    [cParam setObject:loc forKey:@"loc"];
    
    NSString *mno = [QAPMonitor carrierCode];
    if (mno) {
        [cParam setObject:mno forKey:@"mno"];
    }
    else {
        [cParam setObject:@"Unknown" forKey:@"mno"];
    }
    
    // 系统版本
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    if(systemVersion != nil) {
        [cParam setObject:systemVersion forKey:@"osVersion"];
    }
    
    // 获取Key
    NSDate *curDate = [NSDate date];
    long long timeIntervalNow = (long long)([curDate timeIntervalSince1970] * 1000);
    
    NSString *curDateText = [NSString stringWithFormat:@"%lld", timeIntervalNow];
    
    [cParam setObject:curDateText forKey:@"key"];
    
    static NSString *platform = nil;
    if (platform == nil) {
        // 获取model
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        platform = [NSString stringWithUTF8String:machine];
        free(machine);
    }
    if (platform) {
        [cParam setObject:platform forKey:@"model"];
    }
    else {
        [cParam setObject:@"Unknown" forKey:@"model"];
    }
    return cParam;
}

/// 4g/wifi...Unknown(未知网络)，无网：(unconnect)
+ (NSString *)netType {
    Reachability *curReach = [Reachability reachabilityForInternetConnection];
    
    // 获得网络状态
    NetworkStatus netStatus = [curReach currentReachabilityStatus];
    switch (netStatus)
    {
            case NotReachable:
        {
            return @"unconnect";
        }
            break;
            
            case ReachableViaWWAN:
        {
            // 判断是否能够取得运营商
            Class telephoneNetWorkClass = (NSClassFromString(@"CTTelephonyNetworkInfo"));
            if (telephoneNetWorkClass != nil) {
                static CTTelephonyNetworkInfo * telephonyNetworkInfo = nil;
                if (telephonyNetworkInfo == nil) {
                    telephonyNetworkInfo = [[CTTelephonyNetworkInfo alloc] init];
                }
                
                if ([telephonyNetworkInfo respondsToSelector:@selector(currentRadioAccessTechnology)]) {
                    // 7.0 系统的适配处理。
                    return [NSString stringWithFormat:@"%@",telephonyNetworkInfo.currentRadioAccessTechnology];
                }
            }
            
            return @"2g/3g";
        }
            break;
            
            case ReachableViaWiFi:
        {
            return @"wifi";
        }
            break;
            
        default:
            break;
    }
    
    return nil;
}

/// 运营商信息
+ (NSString *)carrierCode {
    // 判断是否能够取得运营商
    Class telephoneNetWorkClass = (NSClassFromString(@"CTTelephonyNetworkInfo"));
    if (telephoneNetWorkClass != nil) {
        static CTTelephonyNetworkInfo * telephonyNetworkInfo = nil;
        if (telephonyNetworkInfo == nil) {
            telephonyNetworkInfo = [[CTTelephonyNetworkInfo alloc] init];
        }
        
        // 获得运营商的信息
        Class carrierClass = (NSClassFromString(@"CTCarrier"));
        if (carrierClass != nil) {
            CTCarrier *carrier = telephonyNetworkInfo.subscriberCellularProvider;
            
            // 移动运营商的mcc 和 mnc
            NSString * mobileCountryCode = [carrier mobileCountryCode];
            NSString * mobileNetworkCode = [carrier mobileNetworkCode];
            
            // 统计能够取到信息的运营商
            if ((mobileCountryCode != nil) && (mobileNetworkCode != nil)) {
                NSString *mobileCode = [[NSString alloc] initWithFormat:@"%@%@", mobileCountryCode, mobileNetworkCode];
                return mobileCode;
            }
        }
    }
    
    return nil;
}

@end

long long QAPMGetCurrentTime_millisecond(void) {
    long long time = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    return time;
}

