//
//  NSString+Tools.h
//  JEFENNewClient
//
//  Created by 陈凯 on 16/1/15.
//  Copyright © 2016年 shuangfeng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Security)

//得到当前时间的字符串
+ (NSString *)getCurrentTimeStamp;

@property (readonly) NSString *Base64String;
@property (readonly) NSString *MD5String;
@property (readonly) NSString *SHA1String;
@property (readonly) NSString *SHA256String;
@property (readonly) NSString *SHA512String;

- (NSString *)hmacSHA1StringWithKey:(NSString *)key;
- (NSString *)hmacSHA256StringWithKey:(NSString *)key;
- (NSString *)hmacSHA512StringWithKey:(NSString *)key;

@end
