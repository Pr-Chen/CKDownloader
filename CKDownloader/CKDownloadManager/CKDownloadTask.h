//
//  CKDownloadTask.h
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CKDownloadTaskState) {
    
    CKDownloadTaskStatePaused,    //已暂停
    CKDownloadTaskStateRunning,   //正在下载
    CKDownloadTaskStateWaiting,   //等待中
    CKDownloadTaskStateFinished,  //已完成
    CKDownloadTaskStateFailed,    //已失败
};

typedef void(^CKDownloadTaskProgressBlock)(NSInteger receivedSize, NSInteger expectedSize);

typedef void(^CKDownloadTaskStateChangeBlock)(CKDownloadTaskState state, NSString *message);

@interface CKDownloadTask : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dict;
+ (instancetype)taskWithUrl:(NSString *)url progress:(CKDownloadTaskProgressBlock)progressBlock stateChangeBlock:(CKDownloadTaskStateChangeBlock)stateChangeBlock;

//只转换存储所需要的属性
- (NSDictionary *)dictionary;

//下载地址
@property (nonatomic, copy) NSString *url;

//任务名称
@property (nonatomic, copy) NSString *name;

//下载状态
@property (nonatomic, assign) CKDownloadTaskState state;

//下载进度
@property (nonatomic, assign) float progress;

// 下载速度
@property (nonatomic, assign) float velocity;

//已下载大小
@property (nonatomic, assign) NSInteger existSize;

//要下载的文件总大小
@property (nonatomic, assign) NSInteger expectedSize;

//对应的本地文件路径
@property (nonatomic, copy) NSString *fileUrl;

//数据流
@property (nonatomic, strong) NSOutputStream *stream;

//下载任务
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;

//任务创建的时间
@property (nonatomic, strong) NSDate *creatDate;

//任务完成的时间
@property (nonatomic, strong) NSDate *finishDate;

//进度变化的block
@property (nonatomic, copy) CKDownloadTaskProgressBlock progressBlock;

//状态改变的block
@property (nonatomic, copy) CKDownloadTaskStateChangeBlock stateChangeBlock;

@end
