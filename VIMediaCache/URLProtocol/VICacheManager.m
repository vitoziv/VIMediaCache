//
//  VICacheManager.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VICacheManager.h"

NSString *VICacheManagerDidUpdateCacheNotification = @"VICacheManagerDidUpdateCacheNotification";

NSString *VICacheURLKey = @"VICacheURLKey";
NSString *VICacheFragmentsKey = @"VICacheFragmentsKey";
NSString *VICacheContentLengthKey = @"VICacheContentLengthKey";

static NSString *kMCMediaCacheDirectory;

@implementation VICacheManager

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setCacheDirectory:[NSTemporaryDirectory() stringByAppendingPathComponent:@"vimedia"]];
    });
}

+ (void)setCacheDirectory:(NSString *)cacheDirectory {
    kMCMediaCacheDirectory = cacheDirectory;
}

+ (NSString *)cacheDirectory {
    return kMCMediaCacheDirectory;
}

+ (NSString *)cachedFilePathForURL:(NSURL *)url {
    return [[self cacheDirectory] stringByAppendingPathComponent:[url lastPathComponent]];
}

@end
