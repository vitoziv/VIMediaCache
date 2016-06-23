//
//  VICacheConfiguration.h
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VICacheConfiguration : NSObject

+ (instancetype)configurationWithFilePath:(NSString *)filePath;
- (void)save;

@property (nonatomic, strong) NSURLResponse *response;
- (NSArray<NSValue *> *)cacheFragments;
- (void)addCacheFragment:(NSRange)fragment;

@end
