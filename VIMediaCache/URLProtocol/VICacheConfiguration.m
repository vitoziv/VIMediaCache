//
//  VICacheConfiguration.m
//  VIMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import "VICacheConfiguration.h"

static NSString *kFileNameKey = @"kFileNameKey";
static NSString *kCacheFragmentsKey = @"kCacheFragmentsKey";
static NSString *kResponseKey = @"kResponseKey";

@interface VICacheConfiguration () <NSCoding>
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSArray<NSValue *> *internalCacheFragments;

@end

@implementation VICacheConfiguration

+ (instancetype)configurationWithFilePath:(NSString *)filePath {
    filePath = [filePath stringByAppendingPathExtension:@"mt_cfg"];
    VICacheConfiguration *configuration = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
    
    if (!configuration) {
        configuration = [[VICacheConfiguration alloc] init];
        configuration.fileName = [filePath lastPathComponent];
        configuration.filePath = filePath;
    }
    
    return configuration;
}

- (NSArray<NSValue *> *)internalCacheFragments {
    if (!_internalCacheFragments) {
        _internalCacheFragments = [NSArray array];
    }
    return _internalCacheFragments;
}

- (void)save {
    @synchronized (self.internalCacheFragments) {
        BOOL success = [NSKeyedArchiver archiveRootObject:self toFile:self.filePath];
        if (!success) {
            NSLog(@"#warning save configuration %@ failed", self.filePath);
        }
    }
}

- (NSArray<NSValue *> *)cacheFragments {
    return [_internalCacheFragments copy];
}

- (void)addCacheFragment:(NSRange)fragment {
    if (fragment.location == NSNotFound || fragment.length == 0) {
        return;
    }
    
    @synchronized (self.internalCacheFragments) {
        NSMutableArray *internalCacheFragments = [self.internalCacheFragments mutableCopy];
        
        NSValue *fragmentValue = [NSValue valueWithRange:fragment];
        NSInteger count = self.internalCacheFragments.count;
        if (count == 0) {
            [internalCacheFragments addObject:fragmentValue];
        } else {
            NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
            [internalCacheFragments enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSRange range = obj.rangeValue;
                if ((fragment.location + fragment.length) <= range.location) {
                    if (indexSet.count == 0) {
                        [indexSet addIndex:idx];
                    }
                    *stop = YES;
                } else if (fragment.location <= (range.location + range.length) && (fragment.location + fragment.length) > range.location) {
                    [indexSet addIndex:idx];
                } else if (fragment.location >= range.location + range.length) {
                    if (idx == count - 1) { // Append to last index
                        [indexSet addIndex:idx];
                    }
                }
            }];
            
            if (indexSet.count > 1) {
                NSRange firstRange = self.internalCacheFragments[indexSet.firstIndex].rangeValue;
                NSRange lastRange = self.internalCacheFragments[indexSet.lastIndex].rangeValue;
                NSInteger location = MIN(firstRange.location, fragment.location);
                NSInteger endOffset = MAX(lastRange.location + lastRange.length, fragment.location + fragment.length);
                NSRange combineRange = NSMakeRange(location, endOffset - location);
                [internalCacheFragments removeObjectsAtIndexes:indexSet];
                [internalCacheFragments insertObject:[NSValue valueWithRange:combineRange] atIndex:indexSet.firstIndex];
            } else if (indexSet.count == 1) {
                NSRange firstRange = self.internalCacheFragments[indexSet.firstIndex].rangeValue;
                
                NSRange expandFirstRange = NSMakeRange(firstRange.location, firstRange.length + 1);
                NSRange expandFragmentRange = NSMakeRange(fragment.location, fragment.length + 1);
                NSRange intersectionRange = NSIntersectionRange(expandFirstRange, expandFragmentRange);
                if (intersectionRange.length > 0) { // Should combine
                    NSInteger location = MIN(firstRange.location, fragment.location);
                    NSInteger endOffset = MAX(firstRange.location + firstRange.length, fragment.location + fragment.length);
                    NSRange combineRange = NSMakeRange(location, endOffset - location);
                    [internalCacheFragments removeObjectAtIndex:indexSet.firstIndex];
                    [internalCacheFragments insertObject:[NSValue valueWithRange:combineRange] atIndex:indexSet.firstIndex];
                } else {
                    if (firstRange.location > fragment.location) {
                        [internalCacheFragments insertObject:fragmentValue atIndex:[indexSet lastIndex]];
                    } else {
                        [internalCacheFragments insertObject:fragmentValue atIndex:[indexSet lastIndex] + 1];
                    }
                }
            }
        }
        
        self.internalCacheFragments = [internalCacheFragments copy];
    }
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.fileName forKey:kFileNameKey];
    [aCoder encodeObject:self.internalCacheFragments forKey:kCacheFragmentsKey];
    [aCoder encodeObject:self.response forKey:kResponseKey];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _fileName = [aDecoder decodeObjectForKey:kFileNameKey];
        _internalCacheFragments = [[aDecoder decodeObjectForKey:kCacheFragmentsKey] mutableCopy];
        if (!_internalCacheFragments) {
            _internalCacheFragments = [NSArray array];
        }
        _response = [aDecoder decodeObjectForKey:kResponseKey];
    }
    return self;
}

@end
