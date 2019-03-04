//
//  QAPMNSURLSessionDelegateAgent.h
//  QunarAPM
//
//  Created by Quanquan.zhang on 15/9/23.
//  Copyright © 2015年 Qunar. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface QAPMNSURLSessionDelegateAgent <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate, NSURLSessionStreamDelegate> : NSObject

@property (nonatomic, strong, nullable) id target;

+ (nullable instancetype)agentWithTarget:(nullable id)target;

@end
