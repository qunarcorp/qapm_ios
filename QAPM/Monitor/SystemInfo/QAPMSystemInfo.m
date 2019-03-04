//
//  QAPMSystemInfo.m
//  QAPMApp
//
//  Created by mdd on 2019/1/28.
//  Copyright © 2019年 mdd. All rights reserved.
//

#import "QAPMSystemInfo.h"

#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <mach/mach.h>

#import "QAPFPSMonitor.h"
#import "QAPManager.h"
#import "QAPMonitor.h"
#import "QCacheStorage.h"

@interface QAPMSystemInfo ()
{
    CADisplayLink *_link;
    QAPFPSDroppedInfo _dropInfo;
}
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray    *arrayMonitor;
@end

@implementation QAPMSystemInfo

+ (instancetype)sharedInstance {
    static QAPMSystemInfo *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)startMonitor {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self.timer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:1 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:(NSString *)kCFRunLoopCommonModes];
        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        NSString *defaultDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *rlt = [defaultDirectory stringByAppendingPathComponent:@"QAPMSystemInfo"];
        _sysMonitorCache = [QCacheStorage cacheStorageWithDir:rlt];
        _sysMonitorCache.maxCacheSize = 50;
    });
}

- (void)tick:(CADisplayLink *)link {
    static NSTimeInterval lastSecond = 0;
    if (![QAPMonitor isForeground]) {
        [self clearDropedInfo];
        return;
    }
    if (_dropInfo.lastTime == 0 || lastSecond == 0) {
        _dropInfo.lastTime = link.timestamp;
        lastSecond = link.timestamp;
        return;
    }
    
    NSTimeInterval delta = link.timestamp - lastSecond;
    
    static int refreshTime = 1;
    if (refreshTime == 1) {
        refreshTime = link.duration * 1000000;
    }
    int period = (link.timestamp - _dropInfo.lastTime) * 1000000;
    if (delta < 1) {
        _dropInfo.count++;
        _dropInfo.sumTime += period;
        int temp = period / refreshTime - 1;
        if (temp >= QAPFPS_DROPPED_FROZEN) {
            _dropInfo.dropLevel.frozen++;
            _dropInfo.dropSum.frozen += temp;
        }
        else if (temp >= QAPFPS_DROPPED_HIGH) {
            _dropInfo.dropLevel.high++;
            _dropInfo.dropSum.high += temp;
        }
        else if (temp >= QAPFPS_DROPPED_MIDDLE) {
            _dropInfo.dropLevel.middle++;
            _dropInfo.dropSum.middle += temp;
        }
        else if (temp >= QAPFPS_DROPPED_NORMAL) {
            _dropInfo.dropLevel.nomal++;
            _dropInfo.dropSum.nomal += temp;
        }
        else {
            _dropInfo.dropLevel.best++;
            _dropInfo.dropSum.best += (temp < 0 ? 0 : temp);
        }
    }
    else {
        // 发送
        [self recordFPSInfo];
        lastSecond = link.timestamp;
    }
    _dropInfo.lastTime = link.timestamp;
}

- (void)recordFPSInfo {
    if (_dropInfo.sumTime == 0) {
        return;
    }
    long long fps = (_dropInfo.count * 1000000) / _dropInfo.sumTime;
    long long timeIntervalNow = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *lastTopVC = [QAPManager appearVC];
    NSDictionary *dropDict = @{
                               @"action":@"fps",
                               // 页面名称
                               @"page":lastTopVC?:@"-1",
                               // 页面丢帧占比分布
                               @"dropLevel":@{
                                       @"frozen":[@(_dropInfo.dropLevel.frozen) stringValue],
                                       @"high":[@(_dropInfo.dropLevel.high) stringValue],
                                       @"middle":[@(_dropInfo.dropLevel.middle) stringValue],
                                       @"normal":[@(_dropInfo.dropLevel.nomal) stringValue],
                                       @"best":[@(_dropInfo.dropLevel.best) stringValue]
                                       },
                               // 页面丢帧占比分布
                               @"dropSum":@{
                                       @"frozen":[@(_dropInfo.dropSum.frozen) stringValue],
                                       @"high":[@(_dropInfo.dropSum.high) stringValue],
                                       @"middle":[@(_dropInfo.dropSum.middle) stringValue],
                                       @"normal":[@(_dropInfo.dropSum.nomal) stringValue],
                                       @"best":[@(_dropInfo.dropSum.best) stringValue]
                                       },
                               @"fps":[@(fps) stringValue],
                               @"count":[@(_dropInfo.count) stringValue],
                               @"sumTime":[@(_dropInfo.sumTime / 1000) stringValue],
                               @"logTime":[@(timeIntervalNow) stringValue]
                               };
    [self clearDropedInfo];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self addArrayMonitor:dropDict];
    });
}

- (void)clearDropedInfo {
    _dropInfo.count = 0;
    _dropInfo.sumTime = 0;
    _dropInfo.lastTime = 0;
    
    _dropInfo.dropSum.frozen = 0;
    _dropInfo.dropSum.high = 0;
    _dropInfo.dropSum.middle = 0;
    _dropInfo.dropSum.nomal = 0;
    _dropInfo.dropSum.best = 0;
    
    _dropInfo.dropLevel.frozen = 0;
    _dropInfo.dropLevel.high = 0;
    _dropInfo.dropLevel.middle = 0;
    _dropInfo.dropLevel.nomal = 0;
    _dropInfo.dropLevel.best = 0;
}

- (NSMutableArray *)arrayMonitor {
    if (!_arrayMonitor) {
        _arrayMonitor = @[].mutableCopy;
    }
    return _arrayMonitor;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_link invalidate];
    _link = nil;
}

- (void)timerTick {
    static int count = 0;
    if (![QAPMonitor isForeground]) {
        count = 0;
        return;
    }
    NSDictionary *memData = [QAPMSystemInfo memoryMonitorData];
    NSDictionary *cpuData = [QAPMSystemInfo cpuMonitorData];
    NSDictionary *batData = nil;
    if (count++ == 60) {
        count = 0;
        batData = [QAPMSystemInfo batteryMonitorData];
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (memData) {
            [self addArrayMonitor:memData];
        }
        if (cpuData) {
            [self addArrayMonitor:cpuData];
        }
        if (batData) {
            [self addArrayMonitor:batData];
        }
    });
}

static float cpu_usage(void)
{
    kern_return_t           kr;
    thread_array_t          thread_list;
    mach_msg_type_number_t  thread_count;
    thread_info_data_t      thinfo;
    mach_msg_type_number_t  thread_info_count;
    thread_basic_info_t     basic_info_th;
    
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    float cpu_usage = 0;
    
    for (int i = 0; i < thread_count; i++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[i], THREAD_BASIC_INFO,(thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE))
        {
            cpu_usage += basic_info_th->cpu_usage;
        }
    }
    
    cpu_usage = cpu_usage / (float)TH_USAGE_SCALE * 100.0;
    
    vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    
    return cpu_usage;
}

static bool VMStats(vm_statistics64_data_t* const vmStats, vm_size_t* const pageSize)
{
    kern_return_t kr;
    const mach_port_t hostPort = mach_host_self();
    
    if((kr = host_page_size(hostPort, pageSize)) != KERN_SUCCESS)
    {
        return false;
    }
    
    mach_msg_type_number_t hostSize = sizeof(*vmStats) / sizeof(natural_t);
    kr = host_statistics64(hostPort, HOST_VM_INFO64,(host_info64_t)vmStats, &hostSize);
    if(kr != KERN_SUCCESS)
    {
        return false;
    }
    
    return true;
}

static uint64_t getUsedMemory(void) {
    int64_t memoryUsageInByte = 0;
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if (kernReturn != KERN_SUCCESS) { return NSNotFound; }
    memoryUsageInByte = (int64_t) vmInfo.phys_footprint;
    return memoryUsageInByte;
}

+ (NSDictionary *)memoryMonitorData {
    uint64_t usedMem = -1;
    uint64_t freeMem = -1;
    uint64_t totalMem = -1;
    vm_statistics64_data_t vmStats;
    vm_size_t pageSize;
    if(VMStats(&vmStats, &pageSize)) {
//        usedMem = ((uint64_t)pageSize) * (vmStats.active_count + vmStats.wire_count) / 1024;
        freeMem = ((uint64_t)pageSize) * (vmStats.free_count + vmStats.inactive_count) >> 10;
        totalMem = [NSProcessInfo processInfo].physicalMemory >> 10;
    }
    usedMem = getUsedMemory() >> 10;
    long long timeIntervalNow = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    float usedRate = usedMem * 100.0 / totalMem;
    NSDictionary *memInfo = @{
                              @"action":@"memory",
                              @"currentProcessName":@"-1",
                              @"system":@{
                                  @"used":[@(usedMem) stringValue],  //设备已使用内存 单位K
                                  @"free":[@(freeMem) stringValue],  //设备剩余内存 单位K
                                  @"total":[@(totalMem) stringValue]  //设备总内存 单位K
                              },
                              @"currentProcess":@{
                                  @"max":@"-1",  //当前应用分配最大的内存  单位K
                                  @"used":[@(usedMem) stringValue],  //当前应用占用内存  单位K
                                  @"usedRate":[NSString stringWithFormat:@"%.2f",usedRate]  //当前应用占用的内存比  单位%
                              },
                              @"logTime":[@(timeIntervalNow) stringValue],//1970年以来的毫秒值
                              };
    return memInfo;
}

+ (NSDictionary *)batteryMonitorData {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    });
    
    CGFloat battery = [[UIDevice currentDevice] batteryLevel];
    BOOL isCharging = ([UIDevice currentDevice].batteryState == UIDeviceBatteryStateCharging);
    long long timeIntervalNow = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSDictionary *batteryData = @{
                              @"action":@"battery",
                              @"currentBatteryRate":[NSString stringWithFormat:@"%.1f",battery],
                              @"isCharging":[@(isCharging) stringValue],
                              @"logTime":[@(timeIntervalNow) stringValue],
                              };
    return batteryData;
}

+ (NSDictionary *)cpuMonitorData {
    float usagRate = cpu_usage();
    long long timeIntervalNow = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSDictionary *cpuData = @{
                              @"action":@"cpu",
                              @"currentProcessName":@"-1",
                              @"usagRate":[NSString stringWithFormat:@"%.2f",usagRate],
                              @"logTime":[@(timeIntervalNow) stringValue],
                              };
    return cpuData;
}

- (void)addArrayMonitor:(NSDictionary *)dict {
    @synchronized (self) {
        if (!dict) {
            return;
        }
        [self.arrayMonitor addObject:dict];
        if (self.arrayMonitor.count >= 10) {
            NSDictionary *cparam = [[QAPMonitor getInstance] commonParam];
            NSDictionary *data = @{@"c":cparam,@"b":[self arrayMonitor]};
            self.arrayMonitor = @[].mutableCopy;
            [_sysMonitorCache saveData:data toFile:[QCacheStorage autoIncrementFileName]];
            [self sendMonitorToServer];
            
        }
    }
}

- (void)sendMonitorToServer {
    __weak typeof(self) weakSelf = self;
    [_sysMonitorCache earlyFile:^(NSDictionary *data) {
        if (data) {
            NSString *fileName = data.allKeys.firstObject;
            NSDictionary *fileData = data[fileName];
            if ([fileData isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dictionary = @{@"monitor":fileName,@"type":@"betaInner"};
                [weakSelf qunarSendData:fileData customInfo:dictionary];
            }
        }
    }];
}

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
            [[[self sharedInstance] sysMonitorCache] deleteFile:fileName];
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [[self sharedInstance] sendMonitorToServer];
            });
        }
        else {
            [[[self sharedInstance] sysMonitorCache] sendFileErrorAddFile:fileName];
        }
    }
}

@end
