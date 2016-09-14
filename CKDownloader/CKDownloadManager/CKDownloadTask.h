//
//  SFDownloadTask.h
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SFDownloadTaskState) {
    
    SFDownloadTaskStatePaused = 0,    //已暂停
    SFDownloadTaskStateRunning = 1,   //正在下载
    SFDownloadTaskStateWaiting = 2,   //等待中
    SFDownloadTaskStateFinished = 3,  //已完成
    SFDownloadTaskStateFailed = 4,    //已失败
    SFDownloadTaskStateNotJion = 5,  //还未加入任务列表
    SFDownloadTaskStateWriteToFileFailed = 6, //写入文件失败
};


@interface CKDownloadTask : NSObject

//图片地址
@property (nonatomic, copy) NSString *imgUrl;
//名字
@property (nonatomic, copy) NSString *name;
//下载地址
@property (nonatomic, copy) NSString *url;

@property (nonatomic, assign) NSInteger direction; //视频方向

//数据的总长度
@property (nonatomic, assign) NSInteger totalLength;
//任务创建的时间
@property (nonatomic, copy) NSString *startTime;
//任务完成的时间
@property (nonatomic, copy) NSString *finishedTime;


//下载状态
@property (nonatomic, assign) SFDownloadTaskState state;

//下载进度
@property (nonatomic, assign) float progress;

//下载速度
@property (nonatomic, assign) float velocity;
@property (nonatomic, assign) float receiveDataBytesInOneSecond;
@property (nonatomic, strong) NSDate *lastUpdateVelocityTime;

//数据流
@property (nonatomic, strong) NSOutputStream *stream;

//下载任务
@property (nonatomic, strong) NSURLSessionDataTask *task;

//下载进度变化时要执行的block
@property (nonatomic, copy) void(^progressBlock)(NSInteger receivedSize, NSInteger expectedSize, float progress);

//暂停或则开始下载的时候要执行的block
@property (nonatomic, copy) void(^pauseBlock)(BOOL pause);

//下载完成时要执行的block
@property (nonatomic, copy) void(^completeBlock)(BOOL success);



- (instancetype)initWithUrl:(NSString *)url;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryForSave;



@end
