//
//  QAPMURLConnectionDelegate.h
//  QunarAPM
//
//  Created by Quanquan.zhang on 15/9/22.
//  Copyright © 2015年 Qunar. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface QAPMURLConnectionDelegateAgent <NSURLConnectionDataDelegate> : NSObject

@property (nonatomic, strong, nullable) id target;

- (nullable instancetype)initWithTarget:(nullable id)target request:(nullable NSURLRequest *)request;
+ (nullable instancetype)agentWithTarget:(nullable id)target request:(nullable NSURLRequest *)request;

@end
