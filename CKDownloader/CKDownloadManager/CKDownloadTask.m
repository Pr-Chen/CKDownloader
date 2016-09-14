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
        self.imgUrl = dict[@"imgUrl"];
        self.name = dict[@"name"];
        self.url = dict[@"url"];
        self.totalLength = [dict[@"totalLength"] integerValue];
        self.startTime = dict[@"startTime"];
        self.finishedTime = dict[@"finishedTime"];
        self.direction = [dict[@"direction"] integerValue];
    }
    return self;
}

- (NSDictionary *)dictionaryForSave {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"imgUrl"] = self.imgUrl;
    dict[@"name"] = self.name;
    dict[@"url"] = self.url;
    dict[@"totalLength"] = @(self.totalLength);
    dict[@"startTime"] = self.startTime;
    dict[@"finishedTime"] = self.finishedTime;
    dict[@"direction"] = @(self.direction);
    return dict;
}

@end
