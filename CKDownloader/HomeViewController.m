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

@interface HomeViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSArray *urls;
@property (strong, nonatomic) NSMutableArray *tasks;

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"%@",NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES));
    
    self.urls = @[
                  @"http://vod.butel.com/bc95f18b224345138bff7132fd0a8b96.mp4",
//                  @"http://vod.butel.com/334f33021cff403aba860e80f601c29a.mp4",
//                  @"http://vod.butel.com/a54a4b949f5541178ebaa66d7cd104a8.mp4"
                  ];
    
    CKDownloadManager *manager = [CKDownloadManager defaultManager];
    for (NSString *url in self.urls) {
        [manager downloadUrl:url class:[VideoTask class] progress:^(NSInteger receivedSize, NSInteger expectedSize) {
            NSLog(@"%.4f",1.0*receivedSize/expectedSize);
            
        } stateChangeBlock:^(CKDownloadTaskState state, NSString *message) {
            NSLog(@"%@",message);
        }];
    }
    self.tasks = manager.allTasks;
    
    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    VideoCell *cell = [tableView dequeueReusableCellWithIdentifier:[VideoCell cellID]];
    
    //设置数据
    cell.videoTask = self.tasks[indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CKDownloadTask *task = self.tasks[indexPath.row];
    if (task.state == CKDownloadTaskStateRunning) {
        [[CKDownloadManager defaultManager] pauseTask:task];
    }
    else if (task.state == CKDownloadTaskStatePaused) {
        [[CKDownloadManager defaultManager] startTask:task];
    }
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}


@end
