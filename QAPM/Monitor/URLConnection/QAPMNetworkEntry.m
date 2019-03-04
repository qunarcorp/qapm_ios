//
//  NetworkMonitorEntry.m
//  CommonFramework
//
//  Created by Quanquan.zhang on 16/1/19.
//  Copyright © 2016年 Qunar.com. All rights reserved.
//

#import "QAPMNetworkEntry.h"
#import <UIKit/UIKit.h>
#import "QAPManager.h"
#import "QAPMonitor.h"
#import <CommonCrypto/CommonDigest.h>
#import <mach/mach_time.h>

static NSString *const pitcherURLKey = @"Pitcher-Url";

@implementation QAPMMetricsTimingData : NSObject
@end

@implementation QAPMNetworkEntry


- (instancetype)initWithRequest:(nullable NSURLRequest *)request
{
    self = [super init];
    if (self) {
        _httpStatusCode = @"Unknown";
        _netStatus = @"error";
        _httpMethod = @"GET";
        _isValid = YES;
        _startTime = _connectTime = _endTime = 0;
        if (request) {
            [self recordRequest:request];
        }
    }
    
    return self;
}

- (void)recordRequest:(nullable NSURLRequest *)request {
    self.url = request.URL;

/**
 @b 统一逻辑 url 表示原始 url, Pitcher 数据在 request header 中
    // Pitcher support
    NSString *pitcherURL = [request valueForHTTPHeaderField:pitcherURLKey];
    if (pitcherURL && pitcherURL.length > 0) {
        self.url = [NSURL URLWithString:pitcherURL]?:request.URL;
    }
*/
    self.httpMethod = request.HTTPMethod;
    // TODO: HTTPBodyStream
    self.requestSize = [request.HTTPBody length];
    self.networkType = [QAPMonitor netType];
    
    // HTTPRequestHeaders
    NSMutableDictionary *allHTTPHeaderFields = [request.allHTTPHeaderFields mutableCopy];
    // remove some keys
    [allHTTPHeaderFields removeObjectsForKeys:@[@"Content-Type", @"X-ClientEncoding", @"Host", @"Connection", @"Accept-Encoding", @"Content-Length", @"Cookie"]];
    self.requestHeaderFields = allHTTPHeaderFields;
}

- (void)recordResponse:(nullable NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        // HTTP response
        long code = [(NSHTTPURLResponse*)response statusCode];
        if (code >= 100 && code < 400) {
            _netStatus = @"success";
        }
        self.httpStatusCode = [NSString stringWithFormat:@"%ld", code];
    }
    
    [self recordConnectTime];
}

- (void)recordError:(nullable NSError *)error {
    _errorMsg = [error localizedDescription];
    _endTime = _endTime?:QAPMGetCurrentTime_millisecond();
    _connectTime = _connectTime?:_endTime;
    if (self.cpuEndTime == 0) {
        self.cpuEndTime = mach_absolute_time();
    }
    if (error) {
        _netStatus = @"error";
        // 用户取消请求不记录
        switch (error.code) {
            case NSURLErrorUnknown:
                _errorMsg = @"Unknown";
                break;
            case NSURLErrorCancelled:
                _isValid = NO;
                break;
            case NSURLErrorBadURL:
            case NSURLErrorUnsupportedURL:
                _errorMsg = @"badurl";
                break;
            case NSURLErrorTimedOut:
                _errorMsg = @"timeout";
                break;
            case NSURLErrorNotConnectedToInternet:
                _errorMsg = @"unconnect";
                _networkType = @"unconnect";
                break;
            case NSURLErrorCannotFindHost:
            case NSURLErrorCannotConnectToHost:
            case NSURLErrorNetworkConnectionLost:
            case NSURLErrorDNSLookupFailed:
            case NSURLErrorHTTPTooManyRedirects:
            case NSURLErrorRedirectToNonExistentLocation:
                _errorMsg = @"hostErr";
                break;
            default:
                break;
        }
    }
}

- (void)recordStartTime {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
            self.isValid = NO;
        }
    });
    self.startTime = QAPMGetCurrentTime_millisecond();
    self.cpuStartTime = mach_absolute_time();
}

- (void)recordConnectTime {
    self.connectTime = QAPMGetCurrentTime_millisecond();
}

- (void)recordEndTime {
    self.endTime = QAPMGetCurrentTime_millisecond();
    self.cpuEndTime = mach_absolute_time();
}

- (void)debugPrint
{
#ifdef DEBUG
    NSLog(@"%@", [self convertToDictionary]);
#endif
}

- (BOOL)isIgnoreReq {
    NSString *reqStr = [NSString stringWithFormat:@"%@%@",_requestHeaderFields[@"Pitcher-Url"],_url.absoluteString];
    NSArray *filterArr = [[QAPManager sharedInstance] domainFilterList];
    for (NSString *filter in filterArr) {
        if ([reqStr containsString:filter]) {
            return YES;
        }
    }
    return NO;
}

- (NSDictionary *)convertToDictionary {
    
    long long enterBackGroundTime = [QAPManager enterBackgroundTime];
    
    if (_isValid == NO) {
        return nil;
    }
    
    if (_url.absoluteString.length == 0) {
        return nil;
    }
    
    if (self.cpuStartTime <= enterBackGroundTime && enterBackGroundTime <= self.cpuEndTime) {
        return nil;
    }
    
    long long reqTime = _endTime - _startTime;
//    long long connTime = _connectTime - _startTime;

    NSString *extension = [[_url pathExtension] lowercaseString];
    if ([@[@"png", @"jpg", @"gif", @"webp",@"jpeg"] indexOfObject:extension] != NSNotFound) {
        if (([_errorMsg length] != 0) && ([_httpStatusCode hasPrefix:@"2"] && reqTime < 2000)) {
            // 对于图片请求，只记录错误的情况和请求时间大于2秒的情况
            return nil;
        }
    }
    
    // 排除非http请求
    if (![_url.absoluteString hasPrefix:@"http"]) {
        return nil;
    }
    if ([self isIgnoreReq]) {
        return nil;
    }
    static dispatch_once_t onceToken;
    static double hTime2nsFactor = 1;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t info;
        if (mach_timebase_info (&info) == KERN_SUCCESS) {
            hTime2nsFactor = (double)info.numer / info.denom;
        }
    });
    uint64_t cpuCost = (self.cpuEndTime - self.cpuStartTime) * hTime2nsFactor / 1000000;
    NSString *topVC = [QAPManager appearVC];
    long long endCpuST = _startTime + cpuCost;
    NSDictionary *dict = @{
                           @"reqUrl": _url.absoluteString?:@"Unknown",
                           @"startTime": [NSString stringWithFormat:@"%lld", _startTime],
                           @"endTime": [NSString stringWithFormat:@"%lld", endCpuST],
                           @"reqSize": [@(_requestSize) stringValue],
                           @"resSize": [@(_responseSize) stringValue],
                           @"httpCode": _httpStatusCode?:@"Unknown",
                           @"hf": _errorMsg?:@"",
                           @"netType": _networkType?:@"Unknown",
                           @"header": _requestHeaderFields?_requestHeaderFields:@{},
                           @"topPage":topVC?:@"Unknown",
                           @"netStatus":_netStatus?:@"error",
                           @"extra":[self appleMetricsTime:self.timingData],
                           };
    return dict;
}

- (NSString *)appleMetricsTime:(QAPMMetricsTimingData *)timimgDate {
    NSString *timStr = @"";
    if (timimgDate.fetchStartDate) {
        long long netDua = [timimgDate.responseEndDate timeIntervalSinceDate:timimgDate.fetchStartDate] * 1000;
        long long dnsDua = [timimgDate.domainLookupEndDate timeIntervalSinceDate:timimgDate.domainLookupStartDate] * 1000;
        long long conDua = [timimgDate.connectEndDate timeIntervalSinceDate:timimgDate.connectStartDate] * 1000;
        long long tlsDua = [timimgDate.secureConnectionEndDate timeIntervalSinceDate:timimgDate.secureConnectionStartDate] * 1000;
        timStr = [NSString stringWithFormat:@"%lld-%lld-%lld-%lld",netDua,dnsDua,conDua,tlsDua];
    }
    return timStr;
}

+ (NSURLRequest *)addCustomHeaderFieldWithURLRequest:(NSURLRequest *)urlRequest {
#ifdef DEBUG 
    // beta 环境去掉 无用字段“L-Uuid”，待稳定没有问题后，再发布到正式环境
    return urlRequest;
#endif
    // 给request的Header添加L-Uuid字段
    NSMutableURLRequest *mutableURLRequest = [urlRequest mutableCopy];
    NSString *host = urlRequest.URL.host;
    // 12306可能根据这个字段风控我们，造成访问不了12306
    if ([host containsString:@"12306.cn"]) {
        return urlRequest;
    }
    if (mutableURLRequest) {
        NSString *aID = [[NSUUID UUID] UUIDString];
        NSString *uID = [QAPMonitor uid];
        NSString *L_UuidString = [NSString stringWithFormat:@"%@%@", aID, uID];
        NSString *L_UuidMD5String = [QAPMNetworkEntry getStringMD5:L_UuidString];
        if (L_UuidMD5String) {
            [mutableURLRequest addValue:L_UuidMD5String forHTTPHeaderField:@"L-Uuid"];
            
            return [mutableURLRequest copy];
        }
    }
    
    return urlRequest;
}

+ (NSString *)getStringMD5:(NSString *)inputString {
    const char *ptr = [inputString UTF8String];
    unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(ptr, (unsigned int)strlen(ptr), md5Buffer);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", md5Buffer[i]];
    }
    
    return [output copy];
}

@end
