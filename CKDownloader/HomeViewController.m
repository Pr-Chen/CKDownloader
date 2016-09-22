//
//  ViewController.m
//  CKDownloader
//
//  Created by 陈凯 on 16/9/14.
//  Copyright © 2016年 陈凯. All rights reserved.
//

#import "HomeViewController.h"
#import "CKDownloadManager.h"
#import "VideoCell.h"

@interface HomeViewController ()
{
    NSMutableArray *_taskAry;
}
@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"%@",NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES));
    CKDownloadManager *manager = [CKDownloadManager defaultManager];
    _taskAry = manager.allTasks;
    
    NSString *url1 = @"http://vod.butel.com/bc95f18b224345138bff7132fd0a8b96.mp4";
    VideoTask *task1 = [VideoTask taskWithUrl:url1 progress:^(NSInteger receivedSize, NSInteger expectedSize) {
        NSLog(@"%.4f",1.0*receivedSize/expectedSize);
    } stateChangeBlock:^(CKDownloadTaskState state, NSString *message) {
        NSLog(@"%@",message);
    }];
    
    [manager startTask:task1];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _taskAry.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    VideoCell *cell = [tableView dequeueReusableCellWithIdentifier:[VideoCell cellID]];
    
    //设置数据
    cell.videoTask = _taskAry[indexPath.row];
    
    return cell;
}

@end
