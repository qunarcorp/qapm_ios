//
//  QAPMNSURLSessionTaskAgent.h
//  QunarAPM
//
//  Created by Quanquan.zhang on 15/10/26.
//  Copyright © 2015年 Qunar. All rights reserved.
//

#import <Foundation/Foundation.h>


@class QAPMNetworkEntry;


@interface QAPMNSURLSessionTaskAgent : NSObject

@property (nonatomic, strong, nullable) QAPMNetworkEntry *networkEntry;

/**
 *  Record the networkEntry to Queue and delete it.
 */
- (void)finish;

/**
 *  Register agent for ID
 *
 *  @param agent agent
 *  @param aID task ID
 */
+ (void)registerAgent:(nullable QAPMNSURLSessionTaskAgent *)agent forID:(nullable NSString *)aID;

/**
 *  Get agent with the given ID
 *
 *  @param aID task ID
 *
 *  @return agent
 */
+ (nullable instancetype)agentForID:(nullable NSString *)aID;

/**
 *  Remove agent
 *
 *  @param aID task ID
 */
+ (void)removeAgentForID:(nullable NSString *)aID;

/**
 *  Register ID for task
 *
 *  @param aID  task ID
 *  @param task session task
 */
+ (void)registerID:(nullable NSString *)aID forTask:(nullable NSURLSessionTask *)task;

/**
 *  Get the ID of task
 *
 *  @param task data task
 *
 *  @return task ID
 */
+ (nullable NSString *)idForTask:(nullable NSURLSessionTask *)task;

/**
 *  Get the agent by task
 *
 *  @param task session task
 *
 *  @return agent or nil
 */
+ (nullable instancetype)agentForTask:(nullable NSURLSessionTask *)task;

/**
 *  Remove agent
 *
 *  @param task session task
 */
+ (void)removeAgentForTask:(nullable NSURLSessionTask *)task;

@end
