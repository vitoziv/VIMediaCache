//
//  MTMCContentInfo.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCContentInfo.h"

@implementation MTMCContentInfo

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@\ncontentLength: %lld\ndownloadedContentLength: %lld\ncontentType: %@\nbyteRangeAccessSupported:%@", NSStringFromClass([self class]), self.contentLength, self.downloadedContentLength, self.contentType, @(self.byteRangeAccessSupported)];
}

@end
