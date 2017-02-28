//
//  SFDownloadManager.h
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//

#import "CKDownloadTask.h"

@interface CKDownloadManager : NSObject

@property (nonatomic, strong) NSMutableArray *allTasks;
@property (nonatomic, strong) NSMutableArray *finishedTasks;

@property (nonatomic, strong) NSMutableArray *waitingTasks;//所有等待中的任务
@property (nonatomic, strong) NSMutableArray *runningTasks;//所有正在下载的任务
@property (nonatomic, strong) NSMutableArray *pausedTasks;//所有已暂停的任务

@property (nonatomic, assign) NSUInteger maxRunningTasksAmount; //同时下载的最大任务数

+ (instancetype)defaultManager;

- (CKDownloadTask *)downloadUrl:(NSString *)url progress:(CKDownloadTaskProgressBlock)progressBlock stateChangeBlock:(CKDownloadTaskStateChangeBlock)stateChangeBlock;
- (CKDownloadTask *)downloadUrl:(NSString *)url class:(Class)taskClass progress:(CKDownloadTaskProgressBlock)progressBlock stateChangeBlock:(CKDownloadTaskStateChangeBlock)stateChangeBlock;

- (CKDownloadTask *)taskForUrl:(NSString *)url;

//删除任务
- (void)deleteTask:(CKDownloadTask *)task deleteFile:(BOOL)deleteFile;

//删除所有任务
- (void)deleteAllTasks;

//开始任务
- (void)startTask:(CKDownloadTask *)task;

//暂停任务
- (void)pauseTask:(CKDownloadTask *)task;

//暂停所有任务
- (void)pauseAllTasks;

//开始所有任务
- (void)startAllTasks;

//可用存储空间
- (float)freeDiskSpace;

@end



@interface NSString (MD5)

@property (nonatomic, copy, readonly) NSString *MD5String;

@end
