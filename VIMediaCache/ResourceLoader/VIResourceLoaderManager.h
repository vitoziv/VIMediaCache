//
//  VIResourceLoaderManager.h
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface VIResourceLoaderManager : NSObject <AVAssetResourceLoaderDelegate>

@end

@interface VIResourceLoaderManager (Convenient)

+ (NSURL *)assetURLWithURL:(NSURL *)url;
- (AVPlayerItem *)playerItemWithURL:(NSURL *)url;

@end
