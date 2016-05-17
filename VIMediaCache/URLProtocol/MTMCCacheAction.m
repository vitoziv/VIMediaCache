//
//  MTMCCacheAction.m
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import "MTMCCacheAction.h"

@implementation MTMCCacheAction

- (instancetype)initWithActionType:(MTMCCacheAtionType)actionType range:(NSRange)range {
    self = [super init];
    if (self) {
        _actionType = actionType;
        _range = range;
    }
    return self;
}

- (BOOL)isEqual:(MTMCCacheAction *)object {
    if (!NSEqualRanges(object.range, self.range)) {
        return NO;
    }
    
    if (object.actionType != self.actionType) {
        return NO;
    }
    
    return YES;
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@%@", NSStringFromRange(self.range), @(self.actionType)] hash];
}

@end
