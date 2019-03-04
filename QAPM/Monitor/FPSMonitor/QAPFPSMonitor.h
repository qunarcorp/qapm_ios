//
//  QAPFPSMonitor.h
//  QAPMApp
//
//  Created by mdd on 2019/1/7.
//  Copyright © 2019年 mdd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define QAPFPS_DROPPED_FROZEN   42
#define QAPFPS_DROPPED_HIGH     24
#define QAPFPS_DROPPED_MIDDLE   9
#define QAPFPS_DROPPED_NORMAL   3

typedef struct QAPFPSDroppedInfo {
    long long count;
    long long sumTime;
    NSTimeInterval lastTime;
    struct {
        long long frozen;
        long long high;
        long long middle;
        long long nomal;
        long long best;
    } dropSum;
    struct {
        long long frozen;
        long long high;
        long long middle;
        long long nomal;
        long long best;
    } dropLevel;
    
}QAPFPSDroppedInfo;

@interface QAPFPSMonitor : NSObject
- (void)startFPSMonitor;
@end

NS_ASSUME_NONNULL_END
