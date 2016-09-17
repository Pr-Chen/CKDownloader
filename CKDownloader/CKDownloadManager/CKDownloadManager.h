//
//  SFDownloadManager.h
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKDownloadTask.h"

@interface CKDownloadManager : NSObject

@property (nonatomic, strong, readonly) NSArray *allTasks;
@property (nonatomic, strong, readonly) NSArray *finishedTasks;

@property (nonatomic, strong) NSArray *waitingTasks;//所有等待中的任务
@property (nonatomic, strong) NSArray *runningTasks;//所有正在下载的任务
@property (nonatomic, strong) NSArray *pausedTasks;//所有已暂停的任务

@property (nonatomic, assign) NSUInteger maxRunningTasksAmount; //同时下载的最大任务数

+ (instancetype)defaultManager;

- (CKDownloadTask *)downloadUrl:(NSString *)url progress:(CKDownloadTaskProgressBlock)progressBlock stateChangeBlock:(CKDownloadTaskStateChangeBlock)stateChangeBlock;

- (CKDownloadTask *)taskForUrl:(NSString *)url;

- (void)deleteTask:(CKDownloadTask *)task;
- (void)deleteTaskForUrl:(NSString *)url;

- (void)deleteAllTasks;

//继续任务
- (void)startTask:(CKDownloadTask *)task;

//暂停任务
- (void)pauseTask:(CKDownloadTask *)task;

//暂停所有任务
- (void)pauseAllTasks;

//开始所有任务
- (void)startAllTasks;

//可用存储空间
+ (float)freeDiskSpace;

@end
