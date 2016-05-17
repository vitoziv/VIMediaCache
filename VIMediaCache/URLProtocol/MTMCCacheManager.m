//
//  MTMCCacheManager.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCCacheManager.h"

NSString *MTMCCacheManagerDidUpdateCacheNotification = @"MTMCCacheManagerDidUpdateCacheNotification";

NSString *MTMCCacheURLKey = @"MTMCCacheURLKey";
NSString *MTMCCacheFragmentsKey = @"MTMCCacheFragmentsKey";
NSString *MTMCCacheContentLengthKey = @"MTMCCacheContentLengthKey";

static NSString *kMCMediaCacheDirectory;

@implementation MTMCCacheManager

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setCacheDirectory:[NSTemporaryDirectory() stringByAppendingPathComponent:@"mcmedia"]];
    });
}

+ (void)setCacheDirectory:(NSString *)cacheDirectory {
    kMCMediaCacheDirectory = cacheDirectory;
}

+ (NSString *)cacheDirectory {
    return kMCMediaCacheDirectory;
}

@end
