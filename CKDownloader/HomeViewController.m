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

@property (strong, nonatomic) NSArray *urls;
@property (strong, nonatomic) NSMutableArray *tasks;

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"%@",NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES));
    
    self.urls = @[
                  @"http://vod.butel.com/bc95f18b224345138bff7132fd0a8b96.mp4",
                  @"http://vod.butel.com/334f33021cff403aba860e80f601c29a.mp4",
                  @"http://vod.butel.com/a54a4b949f5541178ebaa66d7cd104a8.mp4"
                  ];
    
    CKDownloadManager *manager = [CKDownloadManager defaultManager];
    self.tasks = manager.allTasks;
    
    for (NSString *url in self.tasks) {
        [manager downloadUrl:url progress:^(NSInteger receivedSize, NSInteger expectedSize) {
            NSLog(@"%.4f",1.0*receivedSize/expectedSize);
        } stateChangeBlock:^(CKDownloadTaskState state, NSString *message) {
            NSLog(@"%@",message);
        }];
    }
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



@end
