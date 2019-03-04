//
//  QAPMNSURLSessionTaskAgent.m
//  QunarAPM
//
//  Created by Quanquan.zhang on 15/10/26.
//  Copyright © 2015年 Qunar. All rights reserved.
//

#import "QAPMNSURLSessionTaskAgent.h"
#import "QAPMNetworkEntry.h"
#import "QAPMonitor.h"

static NSMutableDictionary *agentTaskMap;
static NSMapTable *taskIDMap;

// Lock for agentTaskMap and taskIDMap operation

static NSRecursiveLock *globalLock()
{
    static NSRecursiveLock *gLock;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        gLock = [[NSRecursiveLock alloc] init];
    });
    
    return gLock;
}

#define LOCK [globalLock() lock];
#define UNLOCK [globalLock() unlock];


@implementation QAPMNSURLSessionTaskAgent

- (instancetype)init {
    self = [super init];
    if (self) {
        self.networkEntry = [[QAPMNetworkEntry alloc] initWithRequest:nil];
    }
    
    return self;
}

- (void)finish {
    NSDictionary *dictEntry = [_networkEntry convertToDictionary];
    if (dictEntry) {
        [QAPMonitor addMonitor:dictEntry withType:eNetworkTaskMonitor];
    }
    
    self.networkEntry = nil;
}

+ (void)registerAgent:(nullable QAPMNSURLSessionTaskAgent *)agent forID:(nullable NSString *)aID {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        agentTaskMap = [NSMutableDictionary dictionary];
    });
    
    if (!aID) {
        return;
    }

    LOCK
    
    [agentTaskMap setObject:agent forKey:aID];
    
    UNLOCK
}

+ (nullable instancetype)agentForID:(nullable NSString *)aID {
    if (!aID) {
        return nil;
    }

    QAPMNSURLSessionTaskAgent *agent;

    LOCK
    
    agent = [agentTaskMap objectForKey:aID];

    UNLOCK
    
    return agent;
}

+ (void)removeAgentForID:(nullable NSString *)aID {
    if (!aID) {
        return;
    }
    
    LOCK
    
    [agentTaskMap removeObjectForKey:aID];
    
    UNLOCK
}

+ (void)registerID:(nullable NSString *)aID forTask:(nullable NSURLSessionTask *)task {
    static dispatch_once_t token;
    
    dispatch_once(&token, ^{
        // weak key and strong value
        taskIDMap = [NSMapTable weakToStrongObjectsMapTable];
    });
    
    if (!aID || !task) {
        return;
    }
    
    LOCK
    
    [taskIDMap setObject:aID forKey:task];
    
    UNLOCK
}

+ (nullable NSString *)idForTask:(nullable NSURLSessionTask *)task {
    if (!task) {
        return nil;
    }
    
    NSString *aID;
    
    LOCK
    
    aID = [taskIDMap objectForKey:task];
    
    UNLOCK
    
    return aID;
}

+ (nullable instancetype)agentForTask:(nullable NSURLSessionTask *)task {
    if (!task) {
        return nil;
    }
    
    QAPMNSURLSessionTaskAgent *agent;
    
    LOCK
    
    NSString *aID = [taskIDMap objectForKey:task];
    if (aID) {
        agent = [self agentForID:aID];
    }
    
    UNLOCK

    return agent;
}

+ (void)removeAgentForTask:(nullable NSURLSessionTask *)task {
    if (!task) {
        return;
    }
    
    LOCK
    
    NSString *aID = [taskIDMap objectForKey:task];
    if (aID) {
        [self removeAgentForID:aID];
    }
    
    UNLOCK
}

@end
