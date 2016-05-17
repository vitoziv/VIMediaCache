//
//  ViewController.m
//  VIMediaCacheDemo
//
//  Created by Vito on 5/17/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "ViewController.h"
#import "VIMediaCache.h"
#import "PlayerView.h"

@interface ViewController ()

@property (nonatomic, strong) VIResourceLoaderManager *resourceLoaderManager;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic) CMTime duration;

@property (weak, nonatomic) IBOutlet PlayerView *playerView;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *totalTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupPlayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaCacheDidChanged:) name:VICacheManagerDidUpdateCacheNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.player play];
}

- (IBAction)touchSliderAction:(UISlider *)sender {
    sender.tag = -1;
}

- (IBAction)sliderAction:(UISlider *)sender {
    CMTime duration = self.player.currentItem.asset.duration;
    CMTime seekTo = CMTimeMake((NSInteger)(duration.value * sender.value), duration.timescale);
    NSLog(@"seetTo %ld", (NSInteger)(duration.value * sender.value) / duration.timescale);
    __weak typeof(self)weakSelf = self;
    [self.player pause];
    [self.player seekToTime:seekTo completionHandler:^(BOOL finished) {
        sender.tag = 0;
        [weakSelf.player play];
    }];
}

#pragma mark - Setup

- (void)setupPlayer {
    //    NSURL *url = [NSURL URLWithString:@"https://mvvideo5.meitudata.com/56ea0e90d6cb2653.mp4"];
    //    NSURL *url = [NSURL URLWithString:@"https://mvvideo5.meitudata.com/56a9e1389b9706520.mp4"];
    //    NSURL *url = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"];
    NSURL *url = [NSURL URLWithString:@"https://mvvideo5.meitudata.com/571090934cea5517.mp4"];
    //    NSURL *url = [NSURL URLWithString:@"http://data.5sing.kgimg.com/G061/M0A/03/13/HZQEAFb493iAOeg5AHMiAfzZU0E739.mp3"];
    
    VIResourceLoaderManager *resourceLoaderManager = [VIResourceLoaderManager new];
    self.resourceLoaderManager = resourceLoaderManager;
    
    AVPlayerItem *playerItem = [resourceLoaderManager playerItemWithURL:url];
    self.playerItem = playerItem;
    
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    //    AVPlayer *player = [AVPlayer playerWithURL:url];
    self.player = player;
    [self.playerView setPlayer:player];
    
    __weak typeof(self)weakSelf = self;
    self.timeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                              queue:dispatch_queue_create("player.time.queue", NULL)
                                         usingBlock:^(CMTime time) {
                                             dispatch_async(dispatch_get_main_queue(), ^(void) {
                                                 if (weakSelf.slider.tag == 0) {
                                                     CGFloat duration = CMTimeGetSeconds(weakSelf.player.currentItem.duration);
                                                     weakSelf.totalTimeLabel.text = [NSString stringWithFormat:@"%.f", duration];
                                                     CGFloat currentDuration = CMTimeGetSeconds(time);
                                                     weakSelf.currentTimeLabel.text = [NSString stringWithFormat:@"%.f", currentDuration];
                                                     weakSelf.slider.value = currentDuration / duration;
                                                 }
                                             });
                                         }];
    
    [self.player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapPlayerViewAction:)];
    [self.playerView addGestureRecognizer:tap];
}

- (void)tapPlayerViewAction:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        if (self.player.rate > 0.0) {
            [self.player pause];
        } else {
            [self.player play];
        }
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (object == self.player && [keyPath isEqualToString:@"status"]) {
        NSLog(@"player status %@, rate %@", @(self.player.status), @(self.player.rate));
        if (self.player.status == AVPlayerStatusReadyToPlay) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                CGFloat duration = CMTimeGetSeconds(self.playerItem.duration);
                self.totalTimeLabel.text = [NSString stringWithFormat:@"%.f", duration];
            });
        } else if (self.player.status == AVPlayerStatusFailed) {
            // something went wrong. player.error should contain some information
            NSLog(@"player error %@", self.player.error);
        }
    }
}

#pragma mark - notification

- (void)mediaCacheDidChanged:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSURL *url = userInfo[VICacheURLKey];
    
    NSArray<NSValue *> *cachedFragments = userInfo[VICacheFragmentsKey];
    long long contentLength = [userInfo[VICacheContentLengthKey] longLongValue];
    
    __block long long cachedLength = 0;
    [cachedFragments enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        cachedLength += obj.rangeValue.length;
    }];
    
    NSLog(@"url: %@, progress: %@", url.absoluteString, @((double)cachedLength / (double)contentLength));
}

@end
