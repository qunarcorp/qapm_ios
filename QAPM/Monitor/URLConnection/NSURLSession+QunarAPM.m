//
//  NSURLSession+QunarAPM.m
//  QunarAPM
//
//  Created by Quanquan.zhang on 15/9/23.
//  Copyright © 2015年 Qunar. All rights reserved.
//

#include <objc/runtime.h>

#import "NSURLSession+QunarAPM.h"
#import "QAPMNSURLSessionDelegateAgent.h"
#import "QAPMNSURLSessionTaskAgent.h"
#import "QAPMNetworkEntry.h"


typedef void (^DataTaskCompletionBlock)(NSData*,NSURLResponse*,NSError*);

NSURLSessionDataTask* (*origin_DataTaskWithRequestAndCompletionHandler)(id, SEL, NSURLRequest*, DataTaskCompletionBlock) = NULL;
void (*origin_NSCFLocalDataTask_resume)(id,SEL) = NULL;
void (*origin_NSURLSessionTask_resume)(id,SEL) = NULL;


#pragma mark - NSURLSessionTask

static void QAPM_NSCFLocalDataTask_Resume(id self, SEL _cmd)
{
    QAPMNSURLSessionTaskAgent *agent = [QAPMNSURLSessionTaskAgent agentForTask:self];
    if (agent) {
        [agent.networkEntry recordStartTime];
    }
    
    origin_NSCFLocalDataTask_resume(self, _cmd);
}

static void QAPM_NSURLSessionTask_Resume(id self, SEL _cmd)
{
    QAPMNSURLSessionTaskAgent *agent = [QAPMNSURLSessionTaskAgent agentForTask:self];
    if (agent) {
        [agent.networkEntry recordStartTime];
    }
    
    origin_NSURLSessionTask_resume(self, _cmd);
}


#pragma mark - NSURLSession

static NSURLSessionTask *QAPMN_NSURLSession_DataTaskWithRequestAndCompletionHandler(id self, SEL _cmd, NSURLRequest *request, DataTaskCompletionBlock completionHandler)
{
    NSURLSessionDataTask *task = nil;
    NSString *aID = [[NSUUID UUID] UUIDString];
    
    request = [QAPMNetworkEntry addCustomHeaderFieldWithURLRequest:request];
    
    if (completionHandler) {
        task = origin_DataTaskWithRequestAndCompletionHandler(self, _cmd, request, ^(NSData *data,
                                                                                     NSURLResponse *response,
                                                                                     NSError *error) {
            QAPMNSURLSessionTaskAgent *agent = [QAPMNSURLSessionTaskAgent agentForID:aID];
            if (agent) {
                QAPMNetworkEntry *networkEntry = agent.networkEntry;
                
                if (response) {
                    [networkEntry recordResponse:response];
                }
                
                networkEntry.responseSize = data.length;
                
                if (error) {
                    [networkEntry recordError:error];
                }
                
                [agent.networkEntry recordEndTime];
                [agent finish];
                
                [QAPMNSURLSessionTaskAgent removeAgentForID:aID];
            }
            
            completionHandler(data, response, error);
        });
    } else {
        task = origin_DataTaskWithRequestAndCompletionHandler(self, _cmd, request, completionHandler);
    }
    
    QAPMNSURLSessionTaskAgent *agent = [[QAPMNSURLSessionTaskAgent alloc] init];
    [agent.networkEntry recordRequest:request];
    [QAPMNSURLSessionTaskAgent registerAgent:agent forID:aID];
    [QAPMNSURLSessionTaskAgent registerID:aID forTask:task];

    return task;
}

static void QAPMSwizzleClassMethod(Class target, SEL originalSelector, SEL swizzledSelector)
{
    Class meta = object_getClass((id)target);
    
    Method originMethod = class_getClassMethod(target, originalSelector);
    Method swizzledMethod = class_getClassMethod(target, swizzledSelector);
    
    if (class_addMethod(meta, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(meta, swizzledSelector, method_getImplementation(originMethod), method_getTypeEncoding(originMethod));
    } else {
        method_exchangeImplementations(originMethod, swizzledMethod);
    }
}

@implementation NSURLSession (QunarAPM)

//- sessionWithConfiguration:delegate:delegateQueue:

#pragma mark - Class methods

+ (NSURLSession *)QAPMSessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(nullable id <NSURLSessionDelegate>)delegate delegateQueue:(nullable NSOperationQueue *)queue {
    QAPMNSURLSessionDelegateAgent *agent = [QAPMNSURLSessionDelegateAgent agentWithTarget:delegate];
    return [self QAPMSessionWithConfiguration:configuration delegate:(id)agent delegateQueue:queue];
}


#pragma mark - Instance methods
/// urlsession 监控初始化
+ (void)QAPMSetupPerformanceMonitoring {
    // iOS 6 compatible
    if (![NSURLSession class]) {
        return;
    }

    // Class method
    QAPMSwizzleClassMethod(self,
                           @selector(sessionWithConfiguration:delegate:delegateQueue:),
                           @selector(QAPMSessionWithConfiguration:delegate:delegateQueue:));
    
    Class claObj;
    SEL selMethod;
    IMP impOverrideMethod;
    Method origMethod;
    
    // NSURLSession dataTaskWithRequest:completionHandler:
    claObj = NSClassFromString(@"__NSCFURLSession"); // iOS 7
    if (!claObj) {
        claObj = NSClassFromString(@"__NSURLSessionLocal"); // iOS 8+
    }
    selMethod = @selector(dataTaskWithRequest:completionHandler:);
    impOverrideMethod = (IMP)QAPMN_NSURLSession_DataTaskWithRequestAndCompletionHandler;
    origMethod = class_getInstanceMethod(claObj, selMethod);
    origin_DataTaskWithRequestAndCompletionHandler = (void *)method_getImplementation(origMethod);
    if (origin_DataTaskWithRequestAndCompletionHandler) {
        method_setImplementation(origMethod, impOverrideMethod);
    }
    
    // NSURLSessionTask resume
    claObj = NSClassFromString(@"NSURLSessionTask");
    selMethod = @selector(resume);
    impOverrideMethod = (IMP)QAPM_NSURLSessionTask_Resume;
    origMethod = class_getInstanceMethod(claObj, selMethod);
    origin_NSURLSessionTask_resume = (void *)method_getImplementation(origMethod);
    if (origin_NSURLSessionTask_resume) {
        method_setImplementation(origMethod, impOverrideMethod);
    }
    
    // __NSCFLocalDataTask resume
    claObj = NSClassFromString(@"__NSCFLocalDataTask");
    selMethod = @selector(resume);
    impOverrideMethod = (IMP)QAPM_NSCFLocalDataTask_Resume;
    origMethod = class_getInstanceMethod(claObj, selMethod);
    origin_NSCFLocalDataTask_resume = (void *)method_getImplementation(origMethod);
    if (origin_NSCFLocalDataTask_resume) {
        method_setImplementation(origMethod, impOverrideMethod);
    }
}

@end
