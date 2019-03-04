//
//  NSURLConnection+QunarAPM.m
//  QunarAPM
//
//  Created by Quanquan.zhang on 15/9/22.
//  Copyright © 2015年 Qunar. All rights reserved.
//

#import "NSURLConnection+QunarAPM.h"
#import "QAPMURLConnectionDelegateAgent.h"
#import "QAPMNetworkEntry.h"
#import "QAPMonitor.h"
#import <objc/runtime.h>

@implementation NSURLConnection (QunarAPM)

#pragma mark - Class Methods

+ (void)QAPMSendAsynchronousRequest:(NSURLRequest *) request
                          queue:(NSOperationQueue *) queue
              completionHandler:(void (^)(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError)) handler
{
    request = [QAPMNetworkEntry addCustomHeaderFieldWithURLRequest:request];

    QAPMNetworkEntry *networkEntry = [[QAPMNetworkEntry alloc] initWithRequest:request];
    [networkEntry recordStartTime];
    
    [self QAPMSendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
        
        if (response) {
            [networkEntry recordResponse:response];
        }
        
        [networkEntry recordEndTime];
        
        if (data) {
            networkEntry.responseSize = data.length;
        }
        
        if (connectionError) {
            [networkEntry recordError:connectionError];
        }
        
        [networkEntry debugPrint];
        
        NSDictionary *dictEntry = [networkEntry convertToDictionary];
        if (dictEntry) {
            [QAPMonitor addMonitor:dictEntry withType:eNetworkTaskMonitor];
        }
        
        handler(response, data, connectionError);
    }];
}

+ (nullable NSData *)QAPMSendSynchronousRequest:(NSURLRequest *)request
                              returningResponse:(NSURLResponse * _Nullable * _Nullable)response
                                          error:(NSError **)error
{
    NSError *agentError = nil;
    NSData *data = nil;
    
    request = [QAPMNetworkEntry addCustomHeaderFieldWithURLRequest:request];

    QAPMNetworkEntry *networkEntry = [[QAPMNetworkEntry alloc] initWithRequest:request];
    [networkEntry recordStartTime];
    
    if (error) {
        data = [self QAPMSendSynchronousRequest:request returningResponse:response error:error];
    } else {
        data = [self QAPMSendSynchronousRequest:request returningResponse:response error:&agentError];
    }
    
    if (response && *response) {
        [networkEntry recordResponse:*response];
    }
    
    [networkEntry recordEndTime];
    
    if (data) {
        networkEntry.responseSize = data.length;
    }
    
    if (error && *error) {
        [networkEntry recordError:*error];
    }

    [networkEntry debugPrint];
    NSDictionary *dictEntry = [networkEntry convertToDictionary];
    if (dictEntry) {
        [QAPMonitor addMonitor:dictEntry withType:eNetworkTaskMonitor];
    }

    return data;
}

+ (nullable NSURLConnection*)QAPMConnectionWithRequest:(NSURLRequest *)request delegate:(nullable id)delegate
{
    request = [QAPMNetworkEntry addCustomHeaderFieldWithURLRequest:request];
    QAPMURLConnectionDelegateAgent *agent = [QAPMURLConnectionDelegateAgent agentWithTarget:delegate request:request];
    return [self QAPMConnectionWithRequest:request delegate:agent];
}

#pragma mark - Instance Methods

- (nullable instancetype)QAPMInitWithRequest:(NSURLRequest *)request delegate:(nullable id)delegate startImmediately:(BOOL)startImmediately
{
    request = [QAPMNetworkEntry addCustomHeaderFieldWithURLRequest:request];
    QAPMURLConnectionDelegateAgent *agent = [QAPMURLConnectionDelegateAgent agentWithTarget:delegate request:request];
    return [self QAPMInitWithRequest:request delegate:agent startImmediately:startImmediately];
}

- (nullable instancetype)QAPMInitWithRequest:(NSURLRequest *)request delegate:(nullable id)delegate
{
    request = [QAPMNetworkEntry addCustomHeaderFieldWithURLRequest:request];
    QAPMURLConnectionDelegateAgent *agent = [QAPMURLConnectionDelegateAgent agentWithTarget:delegate request:request];
    return [self QAPMInitWithRequest:request delegate:agent];
}

+ (void)QAPMSetupPerformanceMonitoring
{
    // Class methods
    [self QAPMSwizzleClassMethod:self original:@selector(sendAsynchronousRequest:queue:completionHandler:) swizzled:@selector(QAPMSendAsynchronousRequest:queue:completionHandler:)];
    [self QAPMSwizzleClassMethod:self original:@selector(sendSynchronousRequest:returningResponse:error:) swizzled:@selector(QAPMSendSynchronousRequest:returningResponse:error:)];
    [self QAPMSwizzleClassMethod:self original:@selector(connectionWithRequest:delegate:) swizzled:@selector(QAPMConnectionWithRequest:delegate:)];
    
    // Instance methods
    [self QAPMSwizzleInstanceMethod:[self class] original:@selector(initWithRequest:delegate:startImmediately:) swizzled:@selector(QAPMInitWithRequest:delegate:startImmediately:)];
    [self QAPMSwizzleInstanceMethod:[self class] original:@selector(initWithRequest:delegate:) swizzled:@selector(QAPMInitWithRequest:delegate:)];
}

//====================================================================================================
//
#pragma mark -
#pragma mark Method

+ (void)QAPMSwizzleClassMethod:(Class)target original:(SEL)originalSelector swizzled:(SEL)swizzledSelector
{
    Class meta = object_getClass((id)target);
    
    Method originMethod = class_getClassMethod(target, originalSelector);
    Method swizzledMethod = class_getClassMethod(target, swizzledSelector);
    
    if (class_addMethod(meta, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod)))
    {
        class_replaceMethod(meta, swizzledSelector, method_getImplementation(originMethod), method_getTypeEncoding(originMethod));
    }
    else
    {
        method_exchangeImplementations(originMethod, swizzledMethod);
    }
}

+ (void)QAPMSwizzleInstanceMethod:(Class)target original:(SEL)originalSelector swizzled:(SEL)swizzledSelector
{
    Method originMethod = class_getInstanceMethod(target, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(target, swizzledSelector);
    
    if (class_addMethod(target, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod)))
    {
        class_replaceMethod(target, swizzledSelector, method_getImplementation(originMethod), method_getTypeEncoding(originMethod));
    }
    else
    {
        method_exchangeImplementations(originMethod, swizzledMethod);
    }
}

@end









