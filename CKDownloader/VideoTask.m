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
    if (self = [super initWithDictionary:dict]) {
        self.imageName = dict[@"imageName"];
    }
    return self;
}

- (NSDictionary *)dictionary {
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:[super dictionary]];
    dict[@"imageName"] = self.imageName;
    return dict;
}

@end
