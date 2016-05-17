//
//  MTMCCacheConfiguration.h
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MTMCCacheConfiguration : NSObject

+ (instancetype)configurationWithFileName:(NSString *)fileName;
- (void)save;

@property (nonatomic, strong) NSURLResponse *response;
- (NSArray<NSValue *> *)cacheFragments;
- (void)addCacheFragment:(NSRange)fragment;

@end
