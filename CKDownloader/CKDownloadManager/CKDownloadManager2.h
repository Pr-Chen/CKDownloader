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
@property (nonatomic, strong, readonly) NSArray *unfinishTasks;

@property (nonatomic, strong) NSArray *waitingTasks;//所有等待中的任务
@property (nonatomic, strong) NSArray *runningTasks;//所有正在下载的任务
@property (nonatomic, strong) NSArray *pausedTasks;//所有已暂停的任务

//根据创建时间排好序的任务列表
@property (nonatomic, strong, readonly) NSArray *allTasksSortedByCreatedTime;

@property (nonatomic, assign) NSUInteger maxBothDownloadTasks; //同时下载的最大任务数

/**
 *  单例
 *
 *  @return 返回单例对象
 */
+ (instancetype)defaultManager;

/**
 *  开启任务下载资源
 *
 *  @param url           下载地址
 *  @param progressBlock 回调下载进度
 *  @param stateBlock    下载状态
 */
- (void)creatDownloadTaskWith:(NSString *)url name:(NSString *)name imgUrl:(NSString *)imgUrl progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize, float progress))progressBlock pause:(void(^)(BOOL pause))pauseBlock complete:(void(^)(BOOL success))completeBlock;

- (CKDownloadTask *)getDownloadTaskWithUrl:(NSString *)url;

/**
 *  查询该资源的下载进度值
 *
 *  @param url 下载地址
 *
 *  @return 返回下载进度值
 */
- (float)progressForUrl:(NSString *)url;

/**
 *  获取该资源总大小
 *
 *  @param url 下载地址
 *
 *  @return 资源总大小
 */
- (NSInteger)fileTotalLengthForUrl:(NSString *)url;

/**
 *  判断该资源是否下载完成
 *
 *  @param url 下载地址
 *
 *  @return YES: 完成
 */
- (BOOL)taskIsFinishedForUrl:(NSString *)url;

/**
 *  删除该资源
 *
 *  @param url 下载地址
 */
- (void)deleteTaskWithUrl:(NSString *)url;

/**
 *  清空所有下载资源
 */
- (void)deleteAllTasks;

/**
 *  获取下载在本地的文件的URL字符串
 */
- (NSString *)localFileUrlWithUrl:(NSString *)url;

//可用存储空间
+ (float)getFreeDiskSpace;

////暂停任务,通过url
//- (void)pauseTaskWithUrl:(NSString *)url;

//继续任务
- (void)startTask:(CKDownloadTask *)downloadTask;

//暂停任务
- (void)pauseTask:(CKDownloadTask *)downloadTask;

//暂停所有任务
- (void)pauseAllTasks;

//开始所有任务
- (void)startAllTasks;

//临时暂停所有任务
- (void)tempPauseAllTasks;
//恢复临时暂停之前的状态
- (void)resumeAllTasks;

@end
