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

@interface CKDownloadManager()<NSCopying, NSURLSessionDelegate>


/** 保存所有任务(注：用下载地址md5后作为key) */
@property (nonatomic, strong) NSMutableDictionary *allTasksDict;

@property (nonatomic, strong) NSMutableArray *tempRunningTasks;
@property (nonatomic, strong) NSMutableArray *tempWaitingTasks;

@end

@implementation CKDownloadManager

static CKDownloadManager *_defaultManager;

#pragma mark - 初始化相关
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultManager = [super allocWithZone:zone];
    });
    return _defaultManager;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return _defaultManager;
}

+ (instancetype)defaultManager {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultManager = [[self alloc] init];
        _defaultManager.maxBothDownloadTasks = 3;
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
        self.allTasksDict[CKFileName(url)] = task;
        task.progressBlock = progressBlock;
        task.stateChangeBlock = stateChangeBlock;
        
        [self updateAllTaskRecordFile];
    }
    
    //开始下载
    [self startTask:task];
    
    return task;
}

#pragma mark - 任务管理

#warning - 要改
- (void)startTask:(CKDownloadTask *)downloadTask {
    //1.任务是否有效
    if (!downloadTask.url.length) {
        return;
    }
    
    //判断是否要创建下载目录
    
    //2.是否已在任务列表中(url是否有一样的),没有则需要加入
    
    
    //3.任务正在运行
    if (downloadTask.state == CKDownloadTaskStateRunning) {
        return;
    }
    //3.任务已完成
    if ([self taskIsFinishedForUrl:downloadTask.url]) {
        return;
    }
    
    //已达最大下载数
    if (self.runningTasks.count > self.maxRunningTasksAmount) {
        //4.任务切换至等待状态
        if (downloadTask.state == CKDownloadTaskStatePaused) {
            downloadTask.state = CKDownloadTaskStateWaiting;
            return;
        }
        //5.任务处于等待状态,则让任意一个运行着的任务变成等待状态
        else if (downloadTask.state == CKDownloadTaskStateWaiting) {
            [self makeAnyRuningTaskWaiting];
        }
    }
    
    //6.是否已有task对象,有则直接下载,没有则先创建
    if (!downloadTask.task) {
        [self creatSessionForTask:downloadTask];
    }
    if (!downloadTask.stream) {
        [self creatStreamForTask:downloadTask];
    }
    //7.开始
    [downloadTask.task resume];
    downloadTask.state = CKDownloadTaskStateRunning;
    
    //设置任务创建时间
    
    if (downloadTask.stateChangeBlock) {
        downloadTask.stateChangeBlock(downloadTask.state);
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
    task.task = dataTask;
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

#warning - 要改
//暂停某个任务
- (void)pauseTask:(CKDownloadTask *)downloadTask waitingTaskShouldStart:(BOOL)shouldStart {
    
    //1.判断任务是否有效,并且在任务列表中
    
    
    if (!downloadTask.url || !downloadTask.task) {
        return;
    }
    //任务已完成
    if ([self taskIsFinishedForUrl:downloadTask.url]) {
        return;
    }
    //任务已暂停
    if (downloadTask.state == CKDownloadTaskStatePaused) {
        return;
    }
    //任务已失败
    if (downloadTask.state == CKDownloadTaskStateFailed) {
        return;
    }
    
    //暂停任务
    [downloadTask.task suspend];
    downloadTask.state = CKDownloadTaskStatePaused;
    // 关闭流
    [downloadTask.stream close];
    
    if (shouldStart) {
        //判断一下是否有等待的任务,如果有
        [self makeAnyWaitingTaskRunning];
    }
    
    if (downloadTask.stateChangeBlock) {
        downloadTask.stateChangeBlock(downloadTask.state);
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

#warning - 要改
//让任意一个正在运行的任务处于等待中
- (void)makeAnyRuningTaskWaiting {
    if (!self.runningTasks.count) {
        return;
    }
    CKDownloadTask *downloadTask = self.runningTasks.lastObject;
    if (downloadTask.task && (downloadTask.task.state != NSURLSessionTaskStateCompleted)) {
        [downloadTask.task suspend];
        
        // 关闭流
        downloadTask.task = nil;
        [downloadTask.stream close];
        downloadTask.stream = nil;
    }
    downloadTask.state = CKDownloadTaskStateWaiting;
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
    return [self.allTasksDict valueForKey:CKFileName(url)];
}

//判断该文件是否下载完成
- (BOOL)taskIsFinishedForUrl:(NSString *)url {
    if (!url.length) {
        return NO;
    }
    if ([self fileTotalLengthForUrl:url] && SFDownloadLength(url) == [self fileTotalLengthForUrl:url]) {
        return YES;
    }
    return NO;
}

//查询该资源的下载进度值
- (float)progressForUrl:(NSString *)url {
    return [self fileTotalLengthForUrl:url] == 0 ? 0.0 : 1.0 * SFDownloadLength(url) /  [self fileTotalLengthForUrl:url];
}

//获取该资源总大小
- (NSInteger)fileTotalLengthForUrl:(NSString *)url {
    NSDictionary *allTaskDict = [NSDictionary dictionaryWithContentsOfFile:SFDownloadTasksFileFullpath];
    NSDictionary *dict = allTaskDict[SFFileName(url)];
    return [dict[@"totalLength"] integerValue];
}

//删除下载任务
- (void)deleteTaskWithUrl:(NSString *)url {
    if (!url) {
        return ;
    }
    
    //取消下载
    CKDownloadTask *downloadTask = [self.allTasksDict valueForKey:SFFileName(url)];
    if (downloadTask.task) {
        [downloadTask.task cancel];
        [downloadTask.stream close];
        downloadTask.stream = nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:SFFileFullpath(url)]) {
        // 删除沙盒中的资源
        [fileManager removeItemAtPath:SFFileFullpath(url) error:nil];
        // 删除任务
        [self.allTasksDict removeObjectForKey:SFFileName(url)];
        // 删除plist中的任务记录
        if ([fileManager fileExistsAtPath:SFDownloadTasksFileFullpath]) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:SFDownloadTasksFileFullpath];
            [dict removeObjectForKey:SFFileName(url)];
            [dict writeToFile:SFDownloadTasksFileFullpath atomically:YES];
        }
    }
}

//清空所有下载资源
- (void)deleteAllTasks {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:SFDocumentDirectory]) {
        // 删除沙盒中所有资源
        [fileManager removeItemAtPath:SFDocumentDirectory error:nil];
        // 删除任务
        for (CKDownloadTask *downloadTask in self.allTasksDict.allValues) {
            [downloadTask.task cancel];
            [downloadTask.stream close];
            downloadTask.stream = nil;
        }
        [self.allTasksDict removeAllObjects];
        
        // 删除plist中的任务记录
        if ([fileManager fileExistsAtPath:SFDownloadTasksFileFullpath]) {
            [fileManager removeItemAtPath:SFDownloadTasksFileFullpath error:nil];
        }
    }
}

#pragma mark - NSURLSession代理方法
/**
 * 接收到响应
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
//    SFDownloadTask *downloadTask = [self getTask:SFFileName(dataTask.response.URL.absoluteString)];

    CKDownloadTask *downloadTask = [self getTaskWithIdentifier:dataTask.taskIdentifier];
    
    // 打开流
    [downloadTask.stream open];
    // 获得服务器这次请求 返回数据的总长度
    NSInteger totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] + SFDownloadLength(downloadTask.url);
    //
    downloadTask.lastUpdateVelocityTime = [NSDate date];
    
    // 更新下载记录
    downloadTask.totalLength = totalLength;
    [self saveAllDownloadTasks];
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
    
}

/**
 * 接收到服务器返回的数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
//    SFDownloadTask *downloadTask = [self getTask:SFFileName(dataTask.response.URL.absoluteString)];
    CKDownloadTask *downloadTask = [self getTaskWithIdentifier:dataTask.taskIdentifier];
    // 写入数据
    if ([downloadTask.stream hasSpaceAvailable]) {
        [downloadTask.stream write:data.bytes maxLength:data.length];
    }
    else {
        [downloadTask.stream close];
        downloadTask.stream = nil;
        downloadTask.task = nil;
        downloadTask.state = SFDownloadTaskStateWriteToFileFailed;
        return;
    }
    
    // 下载进度
    NSUInteger receivedSize = SFDownloadLength(downloadTask.url);
    NSUInteger expectedSize = downloadTask.totalLength;
    float progress = 1.0 * receivedSize / expectedSize;
    downloadTask.progress = progress;
    
    if (downloadTask.progressBlock) {
        downloadTask.progressBlock(receivedSize, expectedSize, progress);
    }
    
    //更新下载速度
    downloadTask.receiveDataBytesInOneSecond += data.length;
    NSDate *currentDate = [NSDate date];
    float timeInterval = [currentDate timeIntervalSinceDate:downloadTask.lastUpdateVelocityTime];
    if (timeInterval >= 1) {
        downloadTask.velocity = downloadTask.receiveDataBytesInOneSecond/1024;
        downloadTask.receiveDataBytesInOneSecond = 0;
        downloadTask.lastUpdateVelocityTime = currentDate;
    }
    
    if ([self.delegate respondsToSelector:@selector(downloadManager:receivedDataForTask:)]) {
        [self.delegate downloadManager:self receivedDataForTask:downloadTask];
    }
}

/**
 * 下载完毕
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
//    SFDownloadTask *downloadTask = [self getTask:SFFileName(task.response.URL.absoluteString)];
    //目前不知道如何获取到downloadTask的url,所以采用这种方式(随机数可能会重复,则会出现bug)
    CKDownloadTask *downloadTask = [self getTaskWithIdentifier:task.taskIdentifier];
    
    if (!downloadTask) {
        return ;
    }
    if ([self taskIsFinishedForUrl:downloadTask.url]) {
        
        // 下载完成
        downloadTask.state = SFDownloadTaskStateFinished;
        if (!downloadTask.finishedTime.length) {
            downloadTask.finishedTime = [NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970]];
        }
        [self saveAllDownloadTasks];
        
        if (downloadTask.completeBlock) {
            downloadTask.completeBlock(YES);
        }
    } else if (error){
        // 下载失败
        downloadTask.state = SFDownloadTaskStateFailed;
        if (downloadTask.completeBlock) {
            downloadTask.completeBlock(NO);
        }
    }
    
    // 关闭流
    [downloadTask.stream close];
    downloadTask.stream = nil;
    
    //开始一个处于等待中的任务
    [self makeAnyWaitingTaskRunning];
}

#pragma mark - 其他方法
//通过标识来获取任务(暂时没有想到好的办法,identifier是随机的,可能重复)
- (CKDownloadTask *)getTaskWithIdentifier:(NSUInteger)identifier {
    for (CKDownloadTask *task in self.allTasksDict.allValues) {
        if (task.task.taskIdentifier == identifier) {
            return task;
        }
    }
    return nil;
}

//获取可用存储空间大小
+ (float)getFreeDiskSpace {
    struct statfs buf;
    unsigned long long freeSpace = -1;
    if (statfs("/var", &buf) >= 0) {
        freeSpace = (unsigned long long)(buf.f_bsize * buf.f_bavail);
    }
    return freeSpace/1024.0/1024;
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
    NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
    for (CKDownloadTask *downloadTask in self.allTasksDict.allValues) {
        NSDictionary *dict = [downloadTask dictionary];
        resultDict[CKFileName(downloadTask.url)] = dict;
    }
    [resultDict writeToFile:CKAllTaskRecordFilePath atomically:YES];
}

//获取下载在本地的文件的URL
- (NSString *)localFileUrlWithUrl:(NSString *)url {
    if (!url.length) {
        return nil;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *videoPath = SFFileFullpath(url);
    BOOL isExist = [fileManager fileExistsAtPath:videoPath];
    if (isExist) {
        return [NSString stringWithFormat:@"file://%@",videoPath];
    }
    else {
        return nil;
    }
}


#pragma mark - getter & setter
//所有任务,用字典存储,url的MD5为key值
- (NSMutableDictionary *)allTasksDict {
    
    if (!_allTasksDict) {
        _allTasksDict = [NSMutableDictionary dictionary];
        //从plist读取
        NSDictionary *tempDict = [NSDictionary dictionaryWithContentsOfFile:SFDownloadTasksFileFullpath];
        //没有,说明任务记录为空
        if (!tempDict.count) {
            return _allTasksDict;
        }
        for (NSDictionary *dict in tempDict.allValues) {
            NSLog(@"%@",dict);
            CKDownloadTask *downloadTask = [[CKDownloadTask alloc] initWithDictionary:dict];
            
            NSUInteger receivedSize = SFDownloadLength(downloadTask.url);
            NSUInteger expectedSize = downloadTask.totalLength;
            float progress = 1.0 * receivedSize / expectedSize;
            downloadTask.progress = progress;
            
            if ([self taskIsFinishedForUrl:downloadTask.url]) {
                downloadTask.state = SFDownloadTaskStateFinished;
            }
            else {
                downloadTask.state = SFDownloadTaskStatePaused;
            }
            
            _allTasksDict[SFFileName(downloadTask.url)] = downloadTask;
        }
    }
    return _allTasksDict;
}

//所有任务
- (NSArray *)allTasks {
    return self.allTasksDict.allValues;
}

//已完成的任务
- (NSArray *)finishedTasks {
    NSArray *allTasks = self.allTasks;
    if (!allTasks.count) {
        return nil;
    }
    NSMutableArray *finishedTasks = [NSMutableArray array];
    for (CKDownloadTask *downloadTask in allTasks) {
        if ([self taskIsFinishedForUrl:downloadTask.url]) {
            [finishedTasks addObject:downloadTask];
        }
    }
    return finishedTasks;
}

//正在等待下载的任务
- (NSArray *)waitingTasks {
    NSArray *unfinishTasks = self.unfinishTasks;
    if (!unfinishTasks.count) {
        return nil;
    }
    NSMutableArray *waitingTasks = [NSMutableArray array];
    for (CKDownloadTask *downloadTask in unfinishTasks) {
        if (downloadTask.state == SFDownloadTaskStateWaiting) {
            [waitingTasks addObject:downloadTask];
        }
    }
    return waitingTasks;
}

//正在运行的任务
- (NSArray *)runningTasks {
    NSArray *unfinishTasks = self.unfinishTasks;
    if (!unfinishTasks.count) {
        return nil;
    }
    NSMutableArray *runningTasks = [NSMutableArray array];
    for (CKDownloadTask *downloadTask in unfinishTasks) {
        if (downloadTask.state == SFDownloadTaskStateRunning) {
            [runningTasks addObject:downloadTask];
        }
    }
    return runningTasks;
}

//已暂停的任务
- (NSArray *)pausedTasks {
    NSArray *unfinishTasks = self.unfinishTasks;
    if (!unfinishTasks.count) {
        return nil;
    }
    NSMutableArray *pausedTasks = [NSMutableArray array];
    for (CKDownloadTask *downloadTask in unfinishTasks) {
        if (downloadTask.state == SFDownloadTaskStatePaused) {
            [pausedTasks addObject:downloadTask];
        }
    }
    return pausedTasks;
}

@end
