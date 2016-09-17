//
//  SFDownloadTask.m
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//

#import "CKDownloadTask.h"

@implementation CKDownloadTask

- (instancetype)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        self.url = url;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        self.url = dict[@"url"];
        self.fileUrl = dict[@"fileUrl"];
        self.existSize = [dict[@"existSize"] integerValue];
        self.expectedSize = [dict[@"expectedSize"] integerValue];
        self.startTime = [dict[@"startTime"] integerValue];
        self.finishTime = [dict[@"finishedTime"] integerValue];
        self.state = [dict[@"state"] integerValue];
    }
    return self;
}

- (NSDictionary *)dictionary {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"url"] = self.url;
    dict[@"fileUrl"] = self.fileUrl;
    dict[@"existSize"] = @(self.existSize);
    dict[@"expectedSize"] = @(self.expectedSize);
    dict[@"startTime"] = @(self.startTime);
    dict[@"finishTime"] = @(self.finishTime);
    dict[@"state"] = @(self.state);
    return dict;
}

@end
