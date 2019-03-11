//
//  QAPManager.h
//  QAPM_a
//
//  Created by mdd on 2018/11/21.
//  Copyright © 2018年 mdd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocationManager.h>
#import "QCacheStorage.h"

@protocol QAPMExtendDelegate <NSObject>

@optional

/// 获取当前定位信息，，如果没有实现则使用默认实现
+ (nullable CLLocation *)location;

/// 获取当前显示界面，如果用户没有实现则默认检索
+ (nullable NSString *)appearVC;

@end

@interface QAPManager : NSObject

+ (instancetype)sharedInstance;
/**
 域名过滤，当请求的url.absoluteString包含set的内容时，不上传监控数据。实时生效
 域名比如 苹果网站:www.apple.com , 或者更具体的 www.apple.com/watch ，但是前者已包含后者
 */
@property (nonatomic, strong) NSArray<NSString *> *domainFilterList;

/**
 *  Start QAPM with pid, cid and vid
 *
 *  @param pid 产品号
 *  @param cid 渠道标识
 *  @param vid 版本号
 *  @param uid 设备号
 */
+ (void)startWithPid:(nonnull NSString *)pid
                 cid:(nullable NSString *)cid
                 vid:(nullable NSString *)vid
                 uid:(nullable NSString *)uid;

+ (void)registExtend:(id<QAPMExtendDelegate>)extend;

/// 添加UI监控数据
+ (void)addUIMonitor:(NSDictionary *)uiMonitorData;
/// 添加net监控数据
+ (void)addNetMonitor:(NSDictionary *)netMonitorData;
/// 进入Background的cpu时间
+ (long long)enterBackgroundTime;
/// 获取当前定位信息
+ (nullable CLLocation *)location;
/// 获取当前显示界面
+ (nullable NSString *)appearVC;
/// 获取当前显示界面类名
+ (nullable NSString *)topVCClassName;

/****************************************
 获取当前的日志：
 1. 获取操作文件的实例
 2. 通过实例，调用实例方法获取到存在本地的日志文件名、文件内容。暴露的方法见QCacheStorage.h
 ****************************************/

/// release环境的日志的实例
+ (QCacheStorage *)releaseLogInstance;
/// 获取beta环境
+ (QCacheStorage *)betaLogInstance;

@end
