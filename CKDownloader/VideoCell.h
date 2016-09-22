//
//  VideoCell.h
//  CKDownloader
//
//  Created by 陈凯 on 2016/9/22.
//  Copyright © 2016年 陈凯. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoTask.h"

@interface VideoCell : UITableViewCell

@property (strong, nonatomic) VideoTask *videoTask;
+ (NSString *)cellID;

@end
