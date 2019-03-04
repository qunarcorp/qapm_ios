//
//  Monitor.h
//  CommonFramework
//
//  Created by zhou on 16/1/14.
//  Copyright © 2016年 Qunar.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "QCacheStorage.h"

typedef enum : NSUInteger
{
    eNetworkTaskMonitor,
    eWebNetMonitor,
    eUIMonitor,
} eMonitorType;

NS_ASSUME_NONNULL_BEGIN

@interface QAPMonitor : NSObject
+ (instancetype)getInstance;
@property (nonatomic, strong, readonly) QCacheStorage   *gMonitorCache;
@property (nonatomic, copy) NSString   *uploadUrl;
// 装载性能监控
+ (void)setupMonitorWithPid:(nonnull NSString *)pid
                        cid:(nullable NSString *)cid
                        vid:(nullable NSString *)vid
                        uid:(nullable NSString *)uid;

// 添加监控数据
+ (void)addMonitor:(NSDictionary *)monitorData withType:(eMonitorType)type;
/// 添加UI监控数据
+ (void)addUIMonitor:(NSDictionary *)uiMonitorData;
/// 添加net监控数据
+ (void)addNetMonitor:(NSDictionary *)netMonitorData;
// 发送监控数据
+ (void)sendMonitor;
+ (void)addFPSMonitor:(NSDictionary *)fpsMonitorData;
// 最近成功的NetworkTask的URL
+ (NSString *)lastSearchURL;

// 获取vid
+ (NSString *)vid;

// 获取uid
+ (NSString *)uid;

+ (NSString *)netType;

+ (NSString *)carrierCode;
+ (BOOL)isForeground;

- (NSDictionary *)commonParam;
@property (nonatomic, strong) NSNumber *userModifyTime;
@end

NS_ASSUME_NONNULL_END

__BEGIN_DECLS
long long QAPMGetCurrentTime_millisecond(void);
__END_DECLS
