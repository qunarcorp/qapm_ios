//
//  QAPFPSMonitor.m
//  QAPMApp
//
//  Created by mdd on 2019/1/7.
//  Copyright © 2019年 mdd. All rights reserved.
//

#import "QAPFPSMonitor.h"
#import <UIKit/UIKit.h>
#import "QAPManager.h"
#import "QAPMonitor.h"

/// 失去焦点上报，停止监听，获取焦点开始监听
@interface QAPFPSMonitor () {
    CADisplayLink *_link;
    BOOL _isMonitor;
    QAPFPSDroppedInfo _dropInfo;
    NSString *_lastTopVC;
}
@end

@implementation QAPFPSMonitor

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)appDidBecomeActive {
    if (_isMonitor == NO) {
        _isMonitor = YES;
        _lastTopVC = [QAPManager topVCClassName];
    }
}

- (void)appWillResignActive {
    if (_isMonitor) {
        [self recordFPSInfo];
        _isMonitor = NO;
    }
}

- (void)startFPSMonitor {
    @synchronized (self) {
        if (!_link) {
            [self clearDropedInfo];
            _isMonitor = YES;
            _lastTopVC = @"";
            _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
            [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
    }
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

/// 减少耗时操作
- (void)tick:(CADisplayLink *)link {
    if (!_isMonitor) {
        return;
    }
    if (_dropInfo.lastTime == 0) {
        _dropInfo.lastTime = link.timestamp;
        return;
    }
    NSString *curTopVC = [QAPManager topVCClassName];
    if (curTopVC.length == 0) {
        return;
    }
    if (_lastTopVC.length == 0) {
        _lastTopVC = curTopVC;
        return;
    }
    
    // 微妙
    static int refreshTime = 1;
    if (refreshTime == 1) {
        refreshTime = link.duration * 1000000;
    }
    int period = (link.timestamp - _dropInfo.lastTime) * 1000000;
    if ([curTopVC isEqualToString:_lastTopVC]) {
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
        _lastTopVC = curTopVC;
    }
    _dropInfo.lastTime = link.timestamp;
}

- (void)recordFPSInfo {
    if (_lastTopVC.length == 0 || _dropInfo.count == 0) {
        [self clearDropedInfo];
        return;
    }
    long long fps = (_dropInfo.count * 1000000) / _dropInfo.sumTime;
    long long timeIntervalNow = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSDictionary *dropDict = @{
               @"action":@"fps",
               // 页面名称
               @"page":_lastTopVC,
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
        [QAPMonitor addFPSMonitor:dropDict];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_link invalidate];
    _link = nil;
}

@end
