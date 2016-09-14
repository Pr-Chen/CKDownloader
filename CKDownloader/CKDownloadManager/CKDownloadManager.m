//
//  SFDownloadManager.m
//
//  Created by 陈凯 on 16/3/4.
//  Copyright © 2015年 陈凯. All rights reserved.
//

// 缓存主目录
#define SFDocumentDirectory [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"SFDownloadCaches"]

// 保存文件名
#define SFFileName(url) [url MD5String]
#define SFFileNameWithExtension(url) [[url MD5String] stringByAppendingPathExtension:url.pathExtension]

// 文件的存放路径（document）
#define SFFileFullpath(url) [SFDocumentDirectory stringByAppendingPathComponent:SFFileNameWithExtension(url)]

// 文件的已下载长度
#define SFDownloadLength(url) [[[NSFileManager defaultManager] attributesOfItemAtPath:SFFileFullpath(url) error:nil][NSFileSize] integerValue]

// 存储所有的下载任务（document）
#define SFDownloadTasksFileFullpath [SFDocumentDirectory stringByAppendingPathComponent:@"SFDownloadTasks.plist"]

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

//方式二: 通过url,创建下载任务,新建的全新任务
- (void)creatDownloadTaskWith:(NSString *)url name:(NSString *)name imgUrl:(NSString *)imgUrl progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize, float progress))progressBlock pause:(void(^)(BOOL pause))pauseBlock complete:(void(^)(BOOL success))completeBlock {
    if (!url) {
        return ;
    }
    
    CKDownloadTask *downloadTask = [self getDownloadTaskWithUrl:url];
    if (!downloadTask) {
        downloadTask = [[CKDownloadTask alloc] initWithUrl:url];
        self.allTasksDict[SFFileName(url)] = downloadTask;
        downloadTask.name = name;
        downloadTask.imgUrl = imgUrl;
        downloadTask.progressBlock = progressBlock;
        downloadTask.pauseBlock = pauseBlock;
        downloadTask.completeBlock = completeBlock;
        
        [self saveAllDownloadTasks];
    }
    
    [self startTask:downloadTask];
}


#pragma mark - 文件管理

// 创建缓存目录文件
- (void)createCacheDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:SFDocumentDirectory]) {
        [fileManager createDirectoryAtPath:SFDocumentDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

//保存所有的下载任务
- (void)saveAllDownloadTasks {
    NSMutableDictionary *saveDict = [NSMutableDictionary dictionary];
    for (CKDownloadTask *downloadTask in self.allTasksDict.allValues) {
        NSDictionary *dict = [downloadTask dictionaryForSave];
        saveDict[SFFileName(downloadTask.url)] = dict;
    }
    [saveDict writeToFile:SFDownloadTasksFileFullpath atomically:YES];
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

#pragma mark - 任务管理

- (void)startTask:(CKDownloadTask *)downloadTask {
    //1.任务是否有效
    if (!downloadTask.url.length) {
        return;
    }
    //2.任务正在运行
    if (downloadTask.state == SFDownloadTaskStateRunning) {
        return;
    }
    //3.任务已完成
    if ([self taskIsFinishedForUrl:downloadTask.url]) {
        return;
    }
    
    //已达最大下载数
    if ([self newTaskShouldWaiting]) {
        //4.任务切换至等待状态
        if (downloadTask.state == SFDownloadTaskStatePaused) {
            downloadTask.state = SFDownloadTaskStateWaiting;
            return;
        }
        //5.任务处于等待状态,则让任意一个运行着的任务变成等待状态
        else if (downloadTask.state == SFDownloadTaskStateWaiting) {
            [self makeAnyRuningTaskWaiting];
        }
    }
    
    //6.是否已有task对象,有则直接下载,没有则先创建
    if (!downloadTask.task) {
        [self creatRequestAndFileDataForTask:downloadTask];
    }
    //7.开始
    [downloadTask.task resume];
    downloadTask.state = SFDownloadTaskStateRunning;
    
    if (downloadTask.pauseBlock) {
        downloadTask.pauseBlock(NO);
    }
}

//创建新的数据请求与输入输出流
- (void)creatRequestAndFileDataForTask:(CKDownloadTask *)downloadTask {
    if (!downloadTask.url.length) {
        return;
    }
    [self createCacheDirectory];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    // 创建流
    NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:SFFileFullpath(downloadTask.url) append:YES];
    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:downloadTask.url]];
    // 设置请求头
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-", SFDownloadLength(downloadTask.url)];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    // 创建一个Data任务
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    NSUInteger taskIdentifier = arc4random() % ((arc4random() % 10000 + arc4random() % 10000));
    [task setValue:@(taskIdentifier) forKeyPath:@"taskIdentifier"];
    downloadTask.task = task;
    downloadTask.stream = stream;
    if (!downloadTask.startTime.length) {
        downloadTask.startTime = [NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970]];
    }

    CKDownloadTask *tempTask = [self.allTasksDict valueForKey:SFFileName(downloadTask.url)];
    if (!tempTask) {
        self.allTasksDict[SFFileName(downloadTask.url)] = downloadTask;
    }
    
}

//暂停某个任务
- (void)pauseTask:(CKDownloadTask *)downloadTask {
    if (!downloadTask.url || !downloadTask.task) {
        return;
    }
    //任务已完成
    if ([self taskIsFinishedForUrl:downloadTask.url]) {
        return;
    }
    //任务已暂停
    if (downloadTask.state == SFDownloadTaskStatePaused) {
        return;
    }
    //任务已失败
    if (downloadTask.state == SFDownloadTaskStateFailed) {
        return;
    }
    
    //暂停任务
    [downloadTask.task suspend];
    downloadTask.state = SFDownloadTaskStatePaused;
    // 关闭流
    downloadTask.task = nil;
    [downloadTask.stream close];
    downloadTask.stream = nil;
    
    //判断一下是否有等待的任务,如果有
    [self makeAnyWaitingTaskRunning];
    
    if (downloadTask.pauseBlock) {
        downloadTask.pauseBlock(YES);
    }
}

//暂停所有任务
- (void)pauseAllTasks {
    for (CKDownloadTask *downloadTask in self.allTasks) {
        if (downloadTask.state == SFDownloadTaskStateRunning || downloadTask.state == SFDownloadTaskStateWaiting) {
            [downloadTask.task suspend];
            downloadTask.state = SFDownloadTaskStatePaused;
            
            // 关闭流
            downloadTask.task = nil;
            [downloadTask.stream close];
            downloadTask.stream = nil;
        }
    }
}

//开始所有任务
- (void)startAllTasks {
    for (CKDownloadTask *downloadTask in self.allTasks) {
        if (downloadTask.state == SFDownloadTaskStatePaused || downloadTask.state == SFDownloadTaskStateWaiting) {
            [self startTask:downloadTask];
        }
    }
}

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
    downloadTask.state = SFDownloadTaskStateWaiting;
}

//让任意一个处于等待中的任务开始运行
- (void)makeAnyWaitingTaskRunning {
    if (!self.waitingTasks.count) {
        return;
    }
    CKDownloadTask *task = self.waitingTasks.firstObject;
    if (!task.task) {
        [self creatRequestAndFileDataForTask:task];
    }
    [task.task resume];
    task.state = SFDownloadTaskStateRunning;
    if (task.pauseBlock) {
        task.pauseBlock(YES);
    }
}

/*
//开始某个任务(通过url)
- (void)startTaskWithUrl:(NSString *)url {
    if (!url.length) {
        return;
    }
    SFDownloadTask *downloadTask = [self getTaskBy:url];
    [downloadTask start];
    if (downloadTask.pauseBlock) {
        downloadTask.pauseBlock(NO);
    }
}

//暂停某个任务(通过url)
- (void)pauseTaskWithUrl:(NSString *)url {
    if (!url.length) {
        return;
    }
    SFDownloadTask *downloadTask = [self getTaskBy:url];
    [downloadTask pause];
    if (downloadTask.pauseBlock) {
        downloadTask.pauseBlock(YES);
    }
}
*/

//根据url获得对应的下载任务
- (CKDownloadTask *)getDownloadTaskWithUrl:(NSString *)url {
    
    if (!url) {
        return nil;
    }
    return [self.allTasksDict valueForKey:SFFileName(url)];
}

//判断一个任务是否应该等待
- (BOOL)newTaskShouldWaiting {
    return self.runningTasks.count >= self.maxBothDownloadTasks;
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

#pragma mark - 删除
/**
 *  删除下载任务
 */
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

/**
 *  清空所有下载资源
 */
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
 * 请求完毕（成功|失败）
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

//未完成的任务
- (NSArray *)unfinishTasks {
    NSArray *allTasks = self.allTasks;
    if (!allTasks.count) {
        return nil;
    }
    NSMutableArray *unfinishTasks = [NSMutableArray array];
    for (CKDownloadTask *downloadTask in allTasks) {
        if (![self taskIsFinishedForUrl:downloadTask.url]) {
            [unfinishTasks addObject:downloadTask];
        }
    }
    return unfinishTasks;
}

//根据创建时间排好序的任务列表
- (NSArray *)allTasksSortedByCreatedTime {
    
    NSArray *ary = self.allTasks;
    NSArray *resultAry = [ary sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSInteger startTime1 = [((CKDownloadTask *)obj1).startTime integerValue];
        NSInteger startTime2 = [((CKDownloadTask *)obj2).startTime integerValue];
        if (startTime1 < startTime2) {
            return NSOrderedAscending;
        }
        return NSOrderedDescending;
    }];
    
    return resultAry;
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

//设置最大同时下载数
- (void)setMaxBothDownloadTasks:(NSUInteger)maxBothDownloadTasks {
    if (maxBothDownloadTasks<=1) {
        _maxBothDownloadTasks = 1;
    }
    else {
        _maxBothDownloadTasks = maxBothDownloadTasks;
    }
}


- (NSMutableArray *)tempRunningTasks {
    if (!_tempRunningTasks) {
        _tempRunningTasks = [NSMutableArray array];
    }
    return _tempRunningTasks;
}

- (NSMutableArray *)tempWaitingTasks {
    if (!_tempWaitingTasks) {
        _tempWaitingTasks = [NSMutableArray array];
    }
    return _tempWaitingTasks;
}

//临时暂停所有任务
- (void)tempPauseAllTasks {
    if (!self.runningTasks.count) {
        return ;
    }
    [self.tempRunningTasks setArray:self.runningTasks];
    [self.tempWaitingTasks setArray:self.waitingTasks];
    [self pauseAllTasks];
}

//恢复临时暂停之前的状态
- (void)resumeAllTasks {
    if (!self.tempRunningTasks.count && !self.tempWaitingTasks.count) {
        return ;
    }
    for (CKDownloadTask *task in self.tempRunningTasks) {
        [self startTask:task];
    }
    for (CKDownloadTask *task in self.tempWaitingTasks) {
        task.state = SFDownloadTaskStateWaiting;
    }
    [self.tempRunningTasks removeAllObjects];
    [self.tempWaitingTasks removeAllObjects];
}

@end