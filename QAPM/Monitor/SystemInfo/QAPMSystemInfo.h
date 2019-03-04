//
//  QAPMSystemInfo.h
//  QAPMApp
//
//  Created by mdd on 2019/1/28.
//  Copyright © 2019年 mdd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QCacheStorage.h"
NS_ASSUME_NONNULL_BEGIN

@interface QAPMSystemInfo : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, strong, readonly) QCacheStorage   *sysMonitorCache;
- (void)startMonitor;
- (void)addArrayMonitor:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
