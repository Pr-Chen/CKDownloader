//
//  SFDownloadManager.m
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//

// 下载路径
#define CKDownloadFolder [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"CKDownloads"]

// 保存文件名
#define CKFileName(url) [url MD5String]
#define CKFileNameWithExtension(url) [[url MD5String] stringByAppendingPathExtension:url.pathExtension]

// 文件的存放路径
#define CKFilePath(url) [CKDownloadFolder stringByAppendingPathComponent:CKFileNameWithExtension(url)]

// 文件的已下载长度
#define CKFileExistSize(url) [[[NSFileManager defaultManager] attributesOfItemAtPath:CKFilePath(url) error:nil][NSFileSize] integerValue]

// 所有任务记录文件的路径
#define CKAllTaskRecordFilePath [CKDownloadFolder stringByAppendingPathComponent:@"CKDownloadTasks.plist"]

#import "CKDownloadManager.h"
#import "NSString+Security.h"
#include <sys/param.h>
#include <sys/mount.h>

@interface CKDownloadManager()<NSURLSessionDelegate>

@end

@implementation CKDownloadManager

static CKDownloadManager *_defaultManager;

#pragma mark - 初始化相关

+ (instancetype)defaultManager {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultManager = [[self alloc] init];
        _defaultManager.maxRunningTasksAmount = 3;
        [_defaultManager createDownloadFolder];
    });
    return _defaultManager;
}

#pragma mark - 创建任务

- (CKDownloadTask *)downloadUrl:(NSString *)url progress:(CKDownloadTaskProgressBlock)progressBlock stateChangeBlock:(CKDownloadTaskStateChangeBlock)stateChangeBlock {
    if (!url.length) {
        return nil;
    }
    
    CKDownloadTask *task = [self taskForUrl:url];
    if (!task) {
        //创建task
        task = [[CKDownloadTask alloc] initWithUrl:url];
        task.creatDate = [NSDate date];
        task.progressBlock = progressBlock;
        task.stateChangeBlock = stateChangeBlock;
        
        [self.allTasks insertObject:task atIndex:0];
        
        [self updateAllTaskRecordFile];
    }
    
    //开始下载
    [self startTask:task];
    
    return task;
}

#pragma mark - 任务管理

- (void)startTask:(CKDownloadTask *)task {
    //1.任务是否有效
    if (!task.url.length) {
        return;
    }
    
    //2.是否已在任务列表中(url是否有一样的),没有则需要加入
    //任务不在列表中
    if (![self.allTasks containsObject:task]) {
        //是否有相同url的任务
        //a.有,提示任务已创建
        if ([self hasSameUrlTaskFor:task]) {
            return;
            //直接返回,提示任务已存在
        }
        //b.没有,加入下载列表
        else {
            [self.allTasks insertObject:task atIndex:0];
        }
    }
    
    //3.任务正在运行
    if (task.state == CKDownloadTaskStateRunning) {
        return;
    }
    //4.任务已完成
    if (task.state == CKDownloadTaskStateFinished) {
        return;
    }
    
    //已达最大下载数
    if (self.runningTasks.count > self.maxRunningTasksAmount) {
        //5.任务切换至等待状态
        if (task.state == CKDownloadTaskStatePaused) {
            task.state = CKDownloadTaskStateWaiting;
            return;
        }
        //6.任务处于等待状态,则让任意一个运行着的任务变成等待状态
        else if (task.state == CKDownloadTaskStateWaiting) {
            [self makeAnyRuningTaskWaiting];
        }
    }
    
    //7.是否已有task对象,有则直接下载,没有则先创建
    if (!task.dataTask) {
        [self creatSessionForTask:task];
    }
    if (!task.stream) {
        [self creatStreamForTask:task];
    }
    //8.开始
    [task.dataTask resume];
    task.state = CKDownloadTaskStateRunning;
    
    if (task.stateChangeBlock) {
        task.stateChangeBlock(task.state);
    }
}

//创建新的数据请求
- (void)creatSessionForTask:(CKDownloadTask *)task {
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue new]];
    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:task.url]];
    // 设置请求头
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-", task.existSize];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    // 创建一个Data任务
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
    NSUInteger taskIdentifier = arc4random() % ((arc4random() % 10000 + arc4random() % 10000));
    [task setValue:@(taskIdentifier) forKeyPath:@"taskIdentifier"];
    task.dataTask = dataTask;
}

//创建新的输出流
- (void)creatStreamForTask:(CKDownloadTask *)task {
    // 创建流
    NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:CKFilePath(task.url) append:YES];
    task.stream = stream;
}

- (void)pauseTask:(CKDownloadTask *)task {
    [self pauseTask:task waitingTaskShouldStart:YES];
}

//暂停某个任务
- (void)pauseTask:(CKDownloadTask *)task waitingTaskShouldStart:(BOOL)shouldStart {
    
    //1.判断任务是否有效,并且在任务列表中
    if (!task.url.length || ![self.allTasks containsObject:task]) {
        return;
    }
    //任务不是运行或等待状态
    if (!(task.state == CKDownloadTaskStateRunning || task.state == CKDownloadTaskStateWaiting)) {
        return;
    }
    
    [task.dataTask suspend];
    [task.stream close];
    
    task.state = CKDownloadTaskStatePaused;
    
    if (shouldStart) {
        //判断一下是否有等待的任务,如果有
        [self makeAnyWaitingTaskRunning];
    }
    
    if (task.stateChangeBlock) {
        task.stateChangeBlock(task.state);
    }
}

//暂停所有任务
- (void)pauseAllTasks {
    for (CKDownloadTask *task in self.allTasks) {
        [self pauseTask:task waitingTaskShouldStart:NO];
    }
}

//开始所有任务
- (void)startAllTasks {
    for (CKDownloadTask *downloadTask in self.allTasks) {
        [self startTask:downloadTask];
    }
}

//让任意一个正在运行的任务处于等待中
- (void)makeAnyRuningTaskWaiting {
    
    if (!self.runningTasks.count) {
        return;
    }
    
    CKDownloadTask *task = self.runningTasks.lastObject;
    [task.dataTask suspend];
    [task.stream close];
    
    task.state = CKDownloadTaskStateWaiting;
    if (task.stateChangeBlock) {
        task.stateChangeBlock(task.state);
    }
}

//让任意一个处于等待中的任务开始运行
- (void)makeAnyWaitingTaskRunning {
    if (!self.waitingTasks.count) {
        return;
    }
    CKDownloadTask *task = self.waitingTasks.firstObject;
    [self startTask:task];
}

- (CKDownloadTask *)taskForUrl:(NSString *)url {
    if (!url.length) {
        return nil;
    }
    
    for (CKDownloadTask *task in self.allTasks) {
        if ([task.url isEqualToString:url]) {
            return task;
        }
    }
    return nil;
}

- (void)deleteTask:(CKDownloadTask *)task deleteFile:(BOOL)deleteFile {
    //判断此任务是否在任务列表中
    
    //取消下载任务
    if (task.dataTask) {
        [task.dataTask cancel];
        task.dataTask = nil;
    }
    
    //关闭输出流
    if (task.stream) {
        [task.stream close];
        task.stream = nil;
    }
    
    //移除任务对象
    [self.allTasks removeObject:task];
    
    //删除记录
#warning - 未完成
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:CKAllTaskRecordFilePath];
    [dict removeObjectForKey:CKFilePath(task.url)];
    [dict writeToFile:CKAllTaskRecordFilePath atomically:YES];
    
    //删除文件
    if (!deleteFile) {
        return;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:CKFilePath(task.url)]) {
        // 删除沙盒中的资源
        [fileManager removeItemAtPath:CKFilePath(task.url) error:nil];
    }
}

//清空所有下载资源
- (void)deleteAllTasks {
    
    //判断任务列表是否有任务
    if (!self.allTasks.count) {
        return;
    }
    
    //取消和关闭
    for (CKDownloadTask *task in self.allTasks) {
        //取消下载任务
        if (task.dataTask) {
            [task.dataTask cancel];
            task.dataTask = nil;
        }
        
        //关闭输出流
        if (task.stream) {
            [task.stream close];
            task.stream = nil;
        }
    }
    
    //清空所有集合里的任务
    [self.allTasks removeAllObjects];
    
    //删除记录和文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:CKDownloadFolder]) {
        // 删除沙盒中所有资源
        [fileManager removeItemAtPath:CKDownloadFolder error:nil];
    }
}

#pragma mark - NSURLSession代理方法
/**
 * 接收到响应
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    CKDownloadTask *task = [self taskForDataTask:dataTask];
    [task.stream open];
    
    // 获得服务器这次请求 返回数据的总长度
    NSInteger expectedSize = [response.allHeaderFields[@"Content-Length"] integerValue] + task.existSize;
    task.expectedSize = expectedSize;
    [self updateAllTaskRecordFile];
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

/**
 * 接收到服务器返回的数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    CKDownloadTask *task = [self taskForDataTask:dataTask];
    // 写入数据
    if ([task.stream hasSpaceAvailable]) {
        [task.stream write:data.bytes maxLength:data.length];
    }
    else {
        [task.dataTask cancel];
        task.dataTask = nil;
        
        [task.stream close];
        task.stream = nil;
        
        task.state = CKDownloadTaskStateWriteToFileFailed;
        return;
    }
    
    //更新任务数据
    task.existSize += data.length;
    
    if (task.progressBlock) {
        task.progressBlock(task.existSize, task.expectedSize);
    }
}

/**
 * 下载完毕
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)dataTask didCompleteWithError:(NSError *)error {
    
    CKDownloadTask *task = [self taskForDataTask:(NSURLSessionDataTask *)dataTask];
    
    //下载完成
    if (task.existSize == task.expectedSize) {
        
        // 下载完成
        task.state = CKDownloadTaskStateFinished;
        task.creatDate = [NSDate date];
        
        [self updateAllTaskRecordFile];
        
    }
    //下载失败
    else if (error){
        task.state = CKDownloadTaskStateFailed;
    }
    
    task.dataTask = nil;
    
    // 关闭流
    [task.stream close];
    task.stream = nil;
    
    //开始一个处于等待中的任务
    [self makeAnyWaitingTaskRunning];
    
    if (task.stateChangeBlock) {
        task.stateChangeBlock(task.state);
    }
}

#pragma mark - 其他方法
/******************************************************************************/

- (CKDownloadTask *)taskForDataTask:(NSURLSessionDataTask *)dataTask {
    for (CKDownloadTask *task in self.allTasks) {
        if (task.dataTask == dataTask) {
            return task;
        }
    }
    return nil;
}

//获取可用存储空间大小
- (float)freeDiskSpace {
    struct statfs buf;
    unsigned long long freeSpace = -1;
    if (statfs("/var", &buf) >= 0) {
        freeSpace = (unsigned long long)(buf.f_bsize * buf.f_bavail);
    }
    return freeSpace/1024.0/1024;
}

- (BOOL)hasSameUrlTaskFor:(CKDownloadTask *)task {
//    for (CKDownloadTask *tempTask in self.allTasks) {
//        if ([tempTask.url isEqualToString:task.url]) {
//            return YES;
//        }
//    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"url = %@",task.url];
    NSArray *resultAry = [self.allTasks filteredArrayUsingPredicate:predicate];
    return resultAry.count;
}

#pragma mark - 文件管理
// 创建下载文件夹
- (void)createDownloadFolder {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:CKDownloadFolder]) {
        [fileManager createDirectoryAtPath:CKDownloadFolder withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

#warning - 未完成
//更新保存所有的下载任务的文件
- (void)updateAllTaskRecordFile {
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
    for (CKDownloadTask *downloadTask in self.allTasks) {
        NSDictionary *dict = [downloadTask dictionary];
        resultDict[CKFileName(downloadTask.url)] = dict;
    }
    [resultDict writeToFile:CKAllTaskRecordFilePath atomically:YES];
}

//获取下载在本地的文件的URL
- (NSString *)fileUrlForUrl:(NSString *)url {
    if (!url.length) {
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = CKFilePath(url);
    BOOL isExist = [fileManager fileExistsAtPath:filePath];
    if (isExist) {
        return [NSString stringWithFormat:@"file://%@",filePath];
    }
    else {
        return nil;
    }
}

/******************************************************************************/
#pragma mark - getter & setter
//所有任务
- (NSMutableArray *)allTasks {
    if (!_allTasks) {
        _allTasks = [NSMutableArray array];
        
        NSArray *recordAry = [NSArray arrayWithContentsOfFile:CKAllTaskRecordFilePath];
        if (recordAry.count) {
            for (NSDictionary *dict in _allTasks) {
                CKDownloadTask *task = [[CKDownloadTask alloc] initWithDictionary:dict];
                task.existSize = CKFileExistSize(task.url);
                [_allTasks addObject:task];
            }
        }
    }
    return _allTasks;
}

//已完成的任务
- (NSArray *)finishedTasks {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state = %ld",CKDownloadTaskStateFinished];
    _finishedTasks = [self.allTasks filteredArrayUsingPredicate:predicate];
    return _finishedTasks;
}

//正在等待下载的任务
- (NSArray *)waitingTasks {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state = %ld",CKDownloadTaskStateWaiting];
    _waitingTasks = [self.allTasks filteredArrayUsingPredicate:predicate];
    return _waitingTasks;
}

//正在运行的任务
- (NSArray *)runningTasks {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state = %ld",CKDownloadTaskStateRunning];
    _runningTasks = [self.allTasks filteredArrayUsingPredicate:predicate];
    return _runningTasks;
}

//已暂停的任务
- (NSArray *)pausedTasks {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state = %ld",CKDownloadTaskStatePaused];
    _pausedTasks = [self.allTasks filteredArrayUsingPredicate:predicate];
    return _pausedTasks;
}

@end
