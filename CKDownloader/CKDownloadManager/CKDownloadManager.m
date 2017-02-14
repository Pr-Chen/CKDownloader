//
//  SFDownloadManager.m
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//

// 下载路径
#define CKDownloadFolder [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"CKDownloads"]

// 保存文件名
#define CKFileName(url) url.MD5String
#define CKFileNameWithExtension(url) [url.MD5String stringByAppendingPathExtension:url.pathExtension]

// 文件的存放路径
#define CKFilePath(url) [CKDownloadFolder stringByAppendingPathComponent:CKFileNameWithExtension(url)]

// 文件的已下载长度
#define CKFileExistSize(url) [[[NSFileManager defaultManager] attributesOfItemAtPath:CKFilePath(url) error:nil][NSFileSize] integerValue]

// 所有任务记录文件的路径
#define CKAllTaskRecordFilePath [CKDownloadFolder stringByAppendingPathComponent:@"CKDownloadTasks.plist"]

#import "CKDownloadManager.h"
#include <sys/param.h>
#include <sys/mount.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

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
        task.url = url;
        task.creatDate = [NSDate date];
        [self.allTasks insertObject:task atIndex:0];
        [self updateAllTaskRecordFile];
    }
    task.progressBlock = progressBlock;
    task.stateChangeBlock = stateChangeBlock;
    
    [self startTask:task];
    
    return task;
}

#pragma mark - 任务管理

- (void)startTask:(CKDownloadTask *)task {
    
    if (!task.url.length) {
        return;
    }
    
    if (![self.allTasks containsObject:task]) {
        
        if ([self hasSameUrlTaskFor:task]) {
            //直接返回,提示任务已存在
            NSLog(@"任务已经存在");
            return;
        }
        else {
            [self.allTasks insertObject:task atIndex:0];
        }
    }
    
    if (task.state == CKDownloadTaskStateRunning) {
        return;
    }
    if (task.state == CKDownloadTaskStateFinished) {
        return;
    }
    
    if (self.runningTasks.count > self.maxRunningTasksAmount) {
        if (task.state == CKDownloadTaskStatePaused) {
            task.state = CKDownloadTaskStateWaiting;
            return;
        }
        else if (task.state == CKDownloadTaskStateWaiting) {
            [self makeAnyRuningTaskWaiting];
        }
    }
    
    if (!task.dataTask) {
        [self creatSessionForTask:task];
    }
    if (!task.stream) {
        [self creatStreamForTask:task];
    }
    
    [task.dataTask resume];
    task.state = CKDownloadTaskStateRunning;
    
    if (task.stateChangeBlock) {
        task.stateChangeBlock(task.state, @"开始下载");
    }
}

//创建新的数据请求
- (void)creatSessionForTask:(CKDownloadTask *)task {
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue new]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:task.url]];
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-", task.existSize];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
    task.dataTask = dataTask;
}

//创建新的输出流
- (void)creatStreamForTask:(CKDownloadTask *)task {
    
    NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:CKFilePath(task.url) append:YES];
    task.stream = stream;
}

- (void)pauseTask:(CKDownloadTask *)task {
    
    [self pauseTask:task waitingTaskShouldStart:YES];
}

//暂停某个任务
- (void)pauseTask:(CKDownloadTask *)task waitingTaskShouldStart:(BOOL)shouldStart {
    
    if (!task.url.length || ![self.allTasks containsObject:task]) {
        return;
    }
    
    if (!(task.state == CKDownloadTaskStateRunning || task.state == CKDownloadTaskStateWaiting)) {
        return;
    }
    
    [task.dataTask suspend];
    [task.stream close];
    
    task.state = CKDownloadTaskStatePaused;
    
    if (shouldStart) {
        [self makeAnyWaitingTaskRunning];
    }
    
    if (task.stateChangeBlock) {
        task.stateChangeBlock(task.state, @"已暂停");
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
        task.stateChangeBlock(task.state, @"进入等待状态");
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
    
    if (task.dataTask) {
        [task.dataTask cancel];
        task.dataTask = nil;
    }
    
    if (task.stream) {
        [task.stream close];
        task.stream = nil;
    }
    
    [self.allTasks removeObject:task];
    
    [self updateAllTaskRecordFile];
    
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
    
    if (!self.allTasks.count) {
        return;
    }
    
    for (CKDownloadTask *task in self.allTasks) {
        
        if (task.dataTask) {
            [task.dataTask cancel];
            task.dataTask = nil;
        }
        
        if (task.stream) {
            [task.stream close];
            task.stream = nil;
        }
    }
    
    [self.allTasks removeAllObjects];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:CKDownloadFolder]) {
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
    
    NSInteger expectedSize = [response.allHeaderFields[@"Content-Length"] integerValue] + task.existSize;
    task.expectedSize = expectedSize;
    [self updateAllTaskRecordFile];
    
    completionHandler(NSURLSessionResponseAllow);
}

/**
 * 接收到服务器返回的数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    CKDownloadTask *task = [self taskForDataTask:dataTask];
    NSInteger writedLength = [task.stream write:data.bytes maxLength:data.length];
    
    task.existSize += writedLength;
    if (writedLength <= data.length) {
        
        [task.dataTask cancel];
        task.dataTask = nil;
        
        [task.stream close];
        task.stream = nil;
        
        task.state = CKDownloadTaskStateFailed;
        if (task.stateChangeBlock) {
            task.stateChangeBlock(task.state, @"存储空间不足");
        }
    }
    
    if (task.progressBlock) {
        task.progressBlock(task.existSize, task.expectedSize);
    }
}

/**
 * 下载完毕
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)dataTask didCompleteWithError:(NSError *)error {
    
    CKDownloadTask *task = [self taskForDataTask:(NSURLSessionDataTask *)dataTask];
    if (task.existSize == task.expectedSize) {
        
        task.state = CKDownloadTaskStateFinished;
        task.finishDate = [NSDate date];
        [self updateAllTaskRecordFile];
    }
    else if (error){
        task.state = CKDownloadTaskStateFailed;
    }
    
    task.dataTask = nil;
    [task.stream close];
    task.stream = nil;
    
    [self makeAnyWaitingTaskRunning];
    
    if (task.stateChangeBlock) {
        task.stateChangeBlock(task.state, @"下载完成");
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
    
    for (CKDownloadTask *tempTask in self.allTasks) {
        if ([tempTask.url isEqualToString:task.url] && tempTask!=task) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - 文件管理
// 创建下载文件夹
- (void)createDownloadFolder {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:CKDownloadFolder]) {
        [fileManager createDirectoryAtPath:CKDownloadFolder withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

//更新保存所有的下载任务的文件
- (void)updateAllTaskRecordFile {
    
    NSMutableArray *resultAry = [NSMutableArray array];
    for (CKDownloadTask *task in self.allTasks) {
        NSDictionary *dict = [task dictionary];
        [resultAry addObject:dict];
    }
    [resultAry writeToFile:CKAllTaskRecordFilePath atomically:YES];
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
            for (NSDictionary *dict in recordAry) {
                NSLog(@"字典：%@",dict);
                Class class = dict[@"class"] ? NSClassFromString(dict[@"class"]) : CKDownloadTask.class;
                CKDownloadTask *task = [[class alloc] initWithDictionary:dict];
                task.existSize = CKFileExistSize(task.url);
                [_allTasks addObject:task];
            }
        }
    }
    return _allTasks;
}

//已完成的任务
- (NSArray *)finishedTasks {
    
    if (!_finishedTasks) {
        _finishedTasks = [NSMutableArray array];
    }
    [_finishedTasks setArray:[self tasksForState:CKDownloadTaskStateFinished]];
    return _finishedTasks;
}

//正在等待下载的任务
- (NSArray *)waitingTasks {
    
    if (!_waitingTasks) {
        _waitingTasks = [NSMutableArray array];
    }
    [_waitingTasks setArray:[self tasksForState:CKDownloadTaskStateWaiting]];
    return _waitingTasks;
}

//正在运行的任务
- (NSArray *)runningTasks {
    
    if (!_runningTasks) {
        _runningTasks = [NSMutableArray array];
    }
    [_runningTasks setArray:[self tasksForState:CKDownloadTaskStateRunning]];
    return _runningTasks;
}

//已暂停的任务
- (NSArray *)pausedTasks {
    
    if (!_pausedTasks) {
        _pausedTasks = [NSMutableArray array];
    }
    [_pausedTasks setArray:[self tasksForState:CKDownloadTaskStatePaused]];
    return _pausedTasks;
}

//获取某个状态的任务
- (NSArray *)tasksForState:(CKDownloadTaskState)state {
    
    NSMutableArray *ary = [NSMutableArray array];
    for (CKDownloadTask *task in self.allTasks) {
        if (task.state == state) {
            [ary addObject:task];
        }
    }
    return ary;
}

@end

@implementation NSString (MD5)

- (NSString *)MD5String {
    
    const char *string = self.UTF8String;
    int length = (int)strlen(string);
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(string, length, bytes);
    return [[NSString alloc] initWithBytes:bytes length:CC_MD5_DIGEST_LENGTH encoding:NSUTF8StringEncoding];
}

@end
