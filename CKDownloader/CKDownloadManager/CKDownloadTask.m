//
//  SFDownloadTask.m
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//

#import "CKDownloadTask.h"

@implementation CKDownloadTask

+ (instancetype)taskWithUrl:(NSString *)url progress:(CKDownloadTaskProgressBlock)progressBlock stateChangeBlock:(CKDownloadTaskStateChangeBlock)stateChangeBlock {
    
    CKDownloadTask *task = [self new];
    task.url = url;
    task.progressBlock = progressBlock;
    task.stateChangeBlock = stateChangeBlock;
    return task;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        self.url = dict[@"url"];
        self.fileUrl = dict[@"fileUrl"];
        self.expectedSize = [dict[@"expectedSize"] integerValue];
        self.creatDate = dict[@"creatDate"];
        self.finishDate = dict[@"finishDate"];
        self.state = [dict[@"state"] integerValue];
    }
    return self;
}

- (NSDictionary *)dictionary {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"url"] = self.url;
    dict[@"fileUrl"] = self.fileUrl;
    dict[@"expectedSize"] = @(self.expectedSize);
    dict[@"creatDate"] = self.creatDate;
    dict[@"finishDate"] = self.finishDate;
    
    if (self.state==CKDownloadTaskStateFinished || self.state==CKDownloadTaskStateFailed) {
        dict[@"state"] = @(self.state);
    }
    
    return dict;
}

@end
