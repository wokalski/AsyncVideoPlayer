//
//  ViewController.m
//  ASVideoPlayer
//
//  Created by Wojciech Czekalski on 01.12.2016.
//  Copyright © 2016 wokalski. All rights reserved.
//

#import "ViewController.h"
#import "ASVideoPlayer.h"

@interface ViewController ()

@property (nonatomic, strong) ASVideoPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSURL *url = [[NSBundle bundleForClass:[ASVideoPlayer class]] URLForResource:@"hm" withExtension:@"mp4"];
    AVAsset *asset = [AVAsset assetWithURL:url];
    
    AVSampleBufferDisplayLayer *layer = [AVSampleBufferDisplayLayer new];
    layer.frame = self.view.bounds;
    layer.contentsGravity = AVLayerVideoGravityResizeAspectFill;
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    
    [self.view.layer addSublayer:layer];
    
    self.player = [ASVideoPlayer new];
    self.player.playerLayer = layer;
    [self.player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError) {
        if (success) {
            [self.player play];
        }
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
