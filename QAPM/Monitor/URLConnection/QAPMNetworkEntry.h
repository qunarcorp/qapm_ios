//
//  NetworkMonitorEntry.h
//  CommonFramework
//
//  Created by Quanquan.zhang on 16/1/19.
//  Copyright © 2016年 Qunar.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QAPMMetricsTimingData : NSObject

@property (nonatomic, strong) NSDate *fetchStartDate;
@property (nonatomic, strong) NSDate *domainLookupStartDate;
@property (nonatomic, strong) NSDate *domainLookupEndDate;
@property (nonatomic, strong) NSDate *connectStartDate;
@property (nonatomic, strong) NSDate *connectEndDate;
@property (nonatomic, strong) NSDate *secureConnectionStartDate;
@property (nonatomic, strong) NSDate *secureConnectionEndDate;

@property (nonatomic, strong) NSDate *requestStartDate;
@property (nonatomic, strong) NSDate *requestEndDate;
@property (nonatomic, strong) NSDate *responseStartDate;
@property (nonatomic, strong) NSDate *responseEndDate;

@end


@interface QAPMNetworkEntry : NSObject
@property (nonatomic, strong) QAPMMetricsTimingData *timingData;

/// The url that is connecting to.
@property (nonatomic, strong, nullable) NSURL *url;

/**
 *  HTTP method, GET/POST/HEAD, etc.
 *
 *  @discussion Better in capital letters, defaults to GET.
 */
@property (nonatomic, copy, nullable) NSString *httpMethod;

/**
 *  Connection start time.
 */
@property (nonatomic) long long startTime;

/**
 *  Response time.
 */
@property (nonatomic) long long connectTime;

/**
 *  Time of end or error.
 */
@property (nonatomic) long long endTime;

@property (nonatomic, assign) uint64_t cpuEndTime;

@property (nonatomic, assign) uint64_t cpuStartTime;
/**
 *  HTTP status code, such as 200, 404, etc.
 */
@property (nonatomic, copy, nullable) NSString *httpStatusCode;

/**
 *  success：HTTP status code(100~399)的情况
 *  error：其它情况
 */
@property (nonatomic, copy, nullable) NSString *netStatus;

/**
 *  Error message
 */
@property (nonatomic, copy, nullable) NSString *errorMsg;

/**
 *  Size of request data.
 */
@property (nonatomic, assign) NSUInteger requestSize;

/**
 *  Size of response data.
 */
@property (nonatomic, assign) NSUInteger responseSize;

/**
 *  Network type, 2G/3G/4G/Wifi/Cellular/Unknow
 */
@property (nonatomic, copy, nullable) NSString *networkType;

/**
 *  HTTP header fields, Pitcher-Url/qrid
 */
@property (nonatomic, strong, nullable) NSDictionary *requestHeaderFields;

/**
 *  Record is valid. Default: YES
 */
@property (nonatomic) BOOL isValid;
/**
 *  Init the instance with url request
 *
 *  @param request url request
 *
 *  @return QAPMNetworkEntry instance
 */
- (nullable instancetype)initWithRequest:(nullable NSURLRequest *)request;

/**
 *  Record url request.
 *
 *  @discussion This method will initialize url, httpMethod, startTime,
 *              requestSize, and networkType properties.
 *
 *  @param request url request
 */
- (void)recordRequest:(nullable NSURLRequest *)request;

/**
 *  Record network response.
 *
 *  @param response response
 */
- (void)recordResponse:(nullable NSURLResponse *)response;

/**
 *  Record network error.
 *
 *  @param error network error
 */
- (void)recordError:(nullable NSError *)error;

/**
 *  Record the connection start time.
 */
- (void)recordStartTime;

/**
 *  Record the connection ready time.
 */
- (void)recordConnectTime;

/**
 *  Record the connection end time.
 */
- (void)recordEndTime;

/**
 *  Show properties in debug console.
 */
- (void)debugPrint;

/**
 *  Convert metircs data to dictionary.
 *
 *  @return data in dictionary
 */
- (nullable NSDictionary *)convertToDictionary;

/**
 *  工具方法： 给请求添加自定义的header字段
 */
+ (nullable NSURLRequest *)addCustomHeaderFieldWithURLRequest:(nullable NSURLRequest *)urlRequest;

@end
