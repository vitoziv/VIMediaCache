//
//  PlayerView.m
//  VIMediaCacheDemo
//
//  Created by Vito on 5/17/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "PlayerView.h"

@implementation PlayerView

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayer*)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

- (AVPlayerLayer *)playerLayer
{
    return (AVPlayerLayer *)self.layer;
}

@end
