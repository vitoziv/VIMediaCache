//
//  MTMCCacheAction.h
//  MTMediaCacheDemo
//
//  Created by Vito on 4/21/16.
//  Copyright © 2016 Meitu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MTMCCacheAtionType) {
    MTMCCacheAtionTypeLocal = 0,
    MTMCCacheAtionTypeRemote
};

@interface MTMCCacheAction : NSObject

- (instancetype)initWithActionType:(MTMCCacheAtionType)actionType range:(NSRange)range;

@property (nonatomic) MTMCCacheAtionType actionType;
@property (nonatomic) NSRange range;

@end
