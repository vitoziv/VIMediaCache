//
//  PlayerView.h
//  VIMediaCacheDemo
//
//  Created by Vito on 5/17/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <UIKit/UIKit.h>
@import AVFoundation;

@interface PlayerView : UIView

- (AVPlayerLayer *)playerLayer;

- (void)setPlayer:(AVPlayer *)player;

@end
