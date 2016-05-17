//
//  MTMCResourceLoaderManager.h
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface MTMCResourceLoaderManager : NSObject <AVAssetResourceLoaderDelegate>

@end

@interface MTMCResourceLoaderManager (Convenient)

+ (NSURL *)assetURLWithURL:(NSURL *)url;
- (AVPlayerItem *)playerItemWithURL:(NSURL *)url;

@end
