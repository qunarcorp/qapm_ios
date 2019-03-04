//
//  URLConnectionDelegateAgent.m
//  CommonFramework
//
//  Created by Quanquan.zhang on 16/1/19.
//  Copyright © 2016年 Qunar.com. All rights reserved.
//

#import "QAPMURLConnectionDelegateAgent.h"
#import "QAPMNetworkEntry.h"
#import "QAPMonitor.h"


@interface QAPMURLConnectionDelegateAgent ()

@property (nonatomic, strong, nonnull) QAPMNetworkEntry *networkEntry;
@property (nonatomic, assign) NSUInteger dataSize;

@end


@implementation QAPMURLConnectionDelegateAgent

- (instancetype)initWithTarget:(nullable id)target request:(nullable NSURLRequest *)request
{
    self = [super init];
    if (self) {
        self.target = target;
        self.networkEntry = [[QAPMNetworkEntry alloc] initWithRequest:request];
        [_networkEntry recordStartTime];
    }
    
    return self;
}

+ (nullable instancetype)agentWithTarget:(nullable id)target request:(nullable NSURLRequest *)request
{
    return [[QAPMURLConnectionDelegateAgent alloc] initWithTarget:target request:request];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    /**
     * Some methods, such as connectionDidFinishDownloading:destinationURL: and connectionDidFinishLoading:, are conflicted.
     * If the agent responds all NSURLConnection delegate methods, the behavior of target may be affected.
     */
    
    NSString *selectorString = NSStringFromSelector(aSelector);
    if ([selectorString isEqualToString:@"connection:didFailWithError:"]
        || [selectorString isEqualToString:@"connectionDidFinishLoading:"]
        || [selectorString isEqualToString:@"connection:didReceiveResponse:"]) {
        return YES;
    }
    
    if ([selectorString hasPrefix:@"connection"]) {
        BOOL targetResponses = [_target respondsToSelector:aSelector];
        BOOL selfResponses = [[self class] instancesRespondToSelector:aSelector];
        
        if (targetResponses && !selfResponses) {
            NSLog(@"Wranning: unresponsed method: %@", selectorString);
        }
        
        return targetResponses && selfResponses;
    }
    
    return [[self class] instancesRespondToSelector:aSelector];
}

#define TARGET_RESPONDS_TO_CMD (_target && [_target respondsToSelector:_cmd])

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [_networkEntry recordError:error];
    
    // TODO: error code
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connection:connection didFailWithError:error];
    }
    
    [_networkEntry debugPrint];
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    if (TARGET_RESPONDS_TO_CMD) {
        return [_target connectionShouldUseCredentialStorage:connection];
    }
    
    return NO;
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [_networkEntry recordConnectTime];
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connection:connection willSendRequestForAuthenticationChallenge:challenge];
    }
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"

// TODO: Should these deprecated methods be supported?

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    if (TARGET_RESPONDS_TO_CMD) {
        return [_target connection:connection canAuthenticateAgainstProtectionSpace:protectionSpace];
    }
    
    return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connection:connection didReceiveAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connection:connection didCancelAuthenticationChallenge:challenge];
    }
}

#pragma GCC diagnostic pop

#pragma mark - NSURLConnectionDataDelegate

- (nullable NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(nullable NSURLResponse *)response
{
    if (TARGET_RESPONDS_TO_CMD) {
        return [_target connection:connection willSendRequest:request redirectResponse:response];
    }
    
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_networkEntry recordResponse:response];
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connection:connection didReceiveResponse:response];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    _dataSize += [data length];
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connection:connection didReceiveData:data];
    }
}

- (nullable NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request
{
    if (TARGET_RESPONDS_TO_CMD) {
        return [self.target connection:connection needNewBodyStream:request];
    }
    
    return nil;
}

- (void)connection:(NSURLConnection *)connection   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite

{
    if (TARGET_RESPONDS_TO_CMD) {
        [self.target connection:connection
                didSendBodyData:bytesWritten
              totalBytesWritten:totalBytesWritten
      totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    }
}

- (nullable NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    if (TARGET_RESPONDS_TO_CMD) {
        return [self.target connection:connection willCacheResponse:cachedResponse];
    }
    
    return cachedResponse;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [_networkEntry recordEndTime];
    _networkEntry.responseSize = _dataSize;
    
    [_networkEntry debugPrint];
    
    NSDictionary *dictEntry = [_networkEntry convertToDictionary];
    if (dictEntry) {
        [QAPMonitor addMonitor:dictEntry withType:eNetworkTaskMonitor];
    }
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connectionDidFinishLoading:connection];
    }
}

#pragma mark - NSURLConnectionDownloadDelegate

- (void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes
{
    _dataSize += bytesWritten;
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connection:connection didWriteData:bytesWritten totalBytesWritten:totalBytesWritten expectedTotalBytes:expectedTotalBytes];
    }
}

- (void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes
{
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connectionDidResumeDownloading:connection totalBytesWritten:totalBytesWritten expectedTotalBytes:expectedTotalBytes];
    }
}

- (void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *) destinationURL
{
    [_networkEntry recordEndTime];
    _networkEntry.responseSize = _dataSize;
    
    [_networkEntry debugPrint];
    
    if (TARGET_RESPONDS_TO_CMD) {
        [_target connectionDidFinishDownloading:connection destinationURL:destinationURL];
    }
}

#undef TARGET_RESPONDS_TO_CMD

@end
