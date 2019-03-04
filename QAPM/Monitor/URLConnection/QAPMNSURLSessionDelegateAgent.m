//
//  QAPMNSURLSessionDelegateAgent.m
//  QunarAPM
//
//  Created by Quanquan.zhang on 15/9/23.
//  Copyright © 2015年 Qunar. All rights reserved.
//

#import "QAPMNSURLSessionDelegateAgent.h"
#import "QAPMNSURLSessionTaskAgent.h"
#import "QAPMNetworkEntry.h"
#import <objc/runtime.h>

@implementation QAPMNSURLSessionDelegateAgent

+ (nullable instancetype)agentWithTarget:(nullable id)target
{
    QAPMNSURLSessionDelegateAgent *agent = [[QAPMNSURLSessionDelegateAgent alloc] init];
    agent.target = target;
    return agent;
}


#define TARGET_RESPONDS_TO_CMD (_target && [_target respondsToSelector:_cmd])

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error;
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session didBecomeInvalidWithError:error];
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        // Default handling
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, NULL);
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session NS_AVAILABLE_IOS(7_0);
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSessionDidFinishEventsForBackgroundURLSession:session];
    }
}


#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler];
    } else {
        completionHandler(request);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session task:task needNewBodyStream:completionHandler];
    } else {
        NSInputStream* inputStream = nil;
        
        if (task.originalRequest.HTTPBodyStream &&
            [task.originalRequest.HTTPBodyStream conformsToProtocol:@protocol(NSCopying)])
        {
            inputStream = [task.originalRequest.HTTPBodyStream copy];
        }
        
        completionHandler(inputStream);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error
{
    QAPMNSURLSessionTaskAgent *agent = [QAPMNSURLSessionTaskAgent agentForTask:task];
    if (agent) {
        QAPMNetworkEntry *entry = agent.networkEntry;
        [entry recordError:error];
        [entry recordEndTime];
        
        [agent finish];
        [QAPMNSURLSessionTaskAgent removeAgentForTask:task];
    }

    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session task:task didCompleteWithError:error];
    }
}


#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    if (response) {
        QAPMNSURLSessionTaskAgent *agent = [QAPMNSURLSessionTaskAgent agentForTask:dataTask];
        if (agent) {
            [agent.networkEntry recordResponse:response];
        }
    }
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    [QAPMNSURLSessionTaskAgent removeAgentForTask:dataTask];
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session dataTask:dataTask didBecomeDownloadTask:downloadTask];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didBecomeStreamTask:(NSURLSessionStreamTask *)streamTask
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session dataTask:dataTask didBecomeStreamTask:streamTask];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    QAPMNSURLSessionTaskAgent *agent = [QAPMNSURLSessionTaskAgent agentForTask:dataTask];
    if (agent) {
        agent.networkEntry.responseSize = data.length;
    }
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
    } else {
        completionHandler(proposedResponse);
    }
}


#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session downloadTask:downloadTask didFinishDownloadingToURL:location];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session downloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session downloadTask:downloadTask didResumeAtOffset:fileOffset expectedTotalBytes:expectedTotalBytes];
    }
}


#pragma mark - NSURLSessionStreamDelegate

- (void)URLSession:(NSURLSession *)session readClosedForStreamTask:(NSURLSessionStreamTask *)streamTask
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session readClosedForStreamTask:streamTask];
    }
}

- (void)URLSession:(NSURLSession *)session writeClosedForStreamTask:(NSURLSessionStreamTask *)streamTask
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session writeClosedForStreamTask:streamTask];
    }
}

- (void)URLSession:(NSURLSession *)session betterRouteDiscoveredForStreamTask:(NSURLSessionStreamTask *)streamTask
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session betterRouteDiscoveredForStreamTask:streamTask];
    }
}

- (void)URLSession:(NSURLSession *)session streamTask:(NSURLSessionStreamTask *)streamTask
didBecomeInputStream:(NSInputStream *)inputStream
      outputStream:(NSOutputStream *)outputStream
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session streamTask:streamTask didBecomeInputStream:inputStream outputStream:outputStream];
    }
}
/// iOS10 以上才会被调用；另外这种会漏掉 [NSURLSession sharedSession] 的请求
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    QAPMNSURLSessionTaskAgent *agent = [QAPMNSURLSessionTaskAgent agentForTask:task];
    if (agent) {
        NSURLSessionTaskTransactionMetrics *transactionMetrics = nil;
        for (NSURLSessionTaskTransactionMetrics *transMetric in metrics.transactionMetrics) {
            
            // 只记录通过网络加载的
            if (transMetric.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad) {
                transactionMetrics = transMetric;
            }
        }
        if (transactionMetrics) {
            QAPMMetricsTimingData *timingData = [[QAPMMetricsTimingData alloc] init];
            unsigned int count ,i;
            objc_property_t *propertyArray = class_copyPropertyList([timingData class], &count);
            for (i = 0; i < count; i++) {
                objc_property_t property = propertyArray[i];
                NSString *proKey = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
                id proValue = [transactionMetrics valueForKey:proKey];
                if (proValue) {
                    [timingData setValue:proValue forKey:proKey];
                }
            }
            free(propertyArray);
            agent.networkEntry.timingData = timingData;
        }
    }
    if (TARGET_RESPONDS_TO_CMD) {
        [_target URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}
#undef TARGET_RESPONDS_TO_CMD

@end
