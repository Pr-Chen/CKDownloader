//
//  VideoCell.m
//  CKDownloader
//
//  Created by 陈凯 on 2016/9/22.
//  Copyright © 2016年 陈凯. All rights reserved.
//

#import "VideoCell.h"

@interface VideoCell ()

@property (weak, nonatomic) IBOutlet UIImageView *coverImageView;
@property (weak, nonatomic) IBOutlet UIImageView *stateImageView;
@property (weak, nonatomic) IBOutlet UILabel *stateLabel;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *fileSizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *velocityLabel;

@end

@implementation VideoCell

+ (NSString *)cellID {
    return @"VideoCellID";
}

- (void)setVideoTask:(VideoTask *)videoTask {
    _videoTask = videoTask;
    
    self.nameLabel.text = videoTask.name;
    self.coverImageView.image = [UIImage imageNamed:videoTask.imageName];
    self.progressView.progress = 1.0*videoTask.existSize/videoTask.expectedSize;
    self.fileSizeLabel.text = [NSString stringWithFormat:@"%.1f/%.1fM", videoTask.existSize/1024.0/1024, videoTask.expectedSize/1024.0/1024];
    
    NSString *stateImageName;
    NSString *stateName;
    switch (videoTask.state) {
            //暂停
        case CKDownloadTaskStatePaused:
            stateImageName = @"zanting";
            stateName = @"已暂停";
            
            self.velocityLabel.hidden = YES;
            self.progressView.hidden = NO;
            self.fileSizeLabel.hidden = NO;
            break;
            
            //正在运行
        case CKDownloadTaskStateRunning:
            stateImageName = @"huancun";
            stateName = @"正在下载";
            self.velocityLabel.hidden = NO;
            self.progressView.hidden = NO;
            self.fileSizeLabel.hidden = NO;
            break;
            
            //等待中
        case CKDownloadTaskStateWaiting:
            stateImageName = @"dengdai";
            stateName = @"等待下载";
            self.velocityLabel.hidden = YES;
            self.progressView.hidden = NO;
            self.fileSizeLabel.hidden = NO;
            break;
            
            //已完成
        case CKDownloadTaskStateFinished:
            stateImageName = @"yihuancun";
            stateName = @"下载完成";
            self.velocityLabel.hidden = YES;
            self.progressView.hidden = YES;
            self.fileSizeLabel.hidden = NO;
            self.fileSizeLabel.text = [NSString stringWithFormat:@"%.1fM", videoTask.expectedSize/1024.0/1024];
            break;
            
            //失败
        case CKDownloadTaskStateFailed:
            stateImageName = @"shibai";
            stateName = @"下载失败";
            self.velocityLabel.hidden = YES;
            self.fileSizeLabel.hidden = NO;
            break;
            
        default:
            break;
    }
    self.stateImageView.image = [UIImage imageNamed:stateImageName];
    self.stateLabel.text = stateName;
    
    
}

@end
