//
//  Video.m
//  CKDownloader
//
//  Created by 陈凯 on 2016/9/22.
//  Copyright © 2016年 陈凯. All rights reserved.
//

#import "VideoTask.h"

@implementation VideoTask

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        self.name = dict[@"name"];
        self.imageName = dict[@"imageName"];
    }
    return self;
}

- (NSDictionary *)dictionary {
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:[super dictionary]];
    dict[@"name"] = self.name;
    dict[@"imageName"] = self.imageName;
    return dict;
}

@end
