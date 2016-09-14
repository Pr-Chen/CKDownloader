//
//  CKDownloadTask.h
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, CKDownloadTaskState) {
    
    CKDownloadTaskStatePaused = 0,    //已暂停
    CKDownloadTaskStateRunning = 1,   //正在下载
    CKDownloadTaskStateWaiting = 2,   //等待中
    CKDownloadTaskStateFinished = 3,  //已完成
    CKDownloadTaskStateFailed = 4,    //已失败
    CKDownloadTaskStateNotJion = 5,  //还未加入任务列表
    CKDownloadTaskStateWriteToFileFailed = 6, //写入文件失败
};

typedef void(^CKDownloadTaskProgressBlock)(NSInteger receivedSize, NSInteger expectedSize);

typedef void(^CKDownloadTaskStateChangeBlock)(CKDownloadTaskState state);


@interface CKDownloadTask : NSObject

- (instancetype)initWithUrl:(NSString *)url;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryForSave;

//必要的属性


//下载地址
@property (nonatomic, copy) NSString *url;

//下载状态
@property (nonatomic, assign) CKDownloadTaskState state;

//下载进度
@property (nonatomic, assign) float progress;

// 下载速度
@property (nonatomic, assign) float velocity;

//已下载大小
@property (assign, nonatomic) NSInteger existSize;

//要下载的文件总大小
@property (assign, nonatomic) NSInteger expectedSize;

//对应的本地文件路径
@property (copy, nonatomic) NSString *fileUrl;

//数据流
@property (nonatomic, strong) NSOutputStream *stream;

//下载任务
@property (nonatomic, strong) NSURLSessionDataTask *task;

//任务创建的时间
@property (nonatomic, copy) NSString *startTime;

//任务完成的时间
@property (nonatomic, copy) NSString *finishedTime;

//进度变化的block, 状态改变的block
@property (copy, nonatomic) CKDownloadTaskProgressBlock progressBlock;
@property (copy, nonatomic) CKDownloadTaskStateChangeBlock stateChangeBlock;

@end
