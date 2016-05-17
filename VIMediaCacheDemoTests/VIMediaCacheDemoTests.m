//
//  VIMediaCacheDemoTests.m
//  VIMediaCacheDemoTests
//
//  Created by Vito on 5/17/16.
//  Copyright © 2016 Vito. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "VICacheConfiguration.h"
#import "VIMediaCacheWorker.h"
#import "VICacheAction.h"

@interface VIMediaCacheDemoTests : XCTestCase

@end

@implementation VIMediaCacheDemoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
- (void)testConfiguration1 {
    VICacheConfiguration *configuration = [[VICacheConfiguration alloc] init];
    NSRange range1 = NSMakeRange(10, 10);
    [configuration addCacheFragment:range1];
    NSArray *fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 1 && NSEqualRanges([fragments[0] rangeValue], range1) , @"add (10, 10) to [], should equal [(10, 10)]");
    
    [configuration addCacheFragment:range1];
    fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 1 && NSEqualRanges([fragments[0] rangeValue], range1) , @"add (10, 10) to [(10, 10)], should equal [(10, 10)]");
    
    NSRange range0 = NSMakeRange(5, 1);
    [configuration addCacheFragment:range0];
    fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 2 && NSEqualRanges([fragments[0] rangeValue], range0) && NSEqualRanges([fragments[1] rangeValue], range1), @"add (5, 1) to [(10, 10)], should equal [(5, 1), (10, 10)]");
    
    NSRange range3 = NSMakeRange(1, 1);
    [configuration addCacheFragment:range3];
    fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 3 &&
              NSEqualRanges([fragments[0] rangeValue], range3) &&
              NSEqualRanges([fragments[1] rangeValue], range0) &&
              NSEqualRanges([fragments[2] rangeValue], range1),
              @"add (1, 1) to [(5, 1), (10, 10)], should equal [(1, 1), (5, 1), (10, 10)]");
    
    NSRange range4 = NSMakeRange(0, 9);
    [configuration addCacheFragment:range4];
    fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 2 &&
              NSEqualRanges([fragments[0] rangeValue], NSMakeRange(0, 9)) &&
              NSEqualRanges([fragments[1] rangeValue], range1),
              @"add (0, 9) to [(1, 1), (5, 1), (10, 10)], should equal [(0, 9), (10, 10)]");
}

- (void)testConfiguration2 {
    VICacheConfiguration *configuration = [[VICacheConfiguration alloc] init];
    NSRange range1 = NSMakeRange(10, 10);
    [configuration addCacheFragment:range1];
    NSArray *fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 1 && NSEqualRanges([fragments[0] rangeValue], range1) , @"add (10, 10) to [], should equal [(10, 10)]");
    
    NSRange range2 = NSMakeRange(30, 10);
    [configuration addCacheFragment:range2];
    fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 2 && NSEqualRanges([fragments[0] rangeValue], range1) && NSEqualRanges([fragments[1] rangeValue], range2), @"add (30, 10) to [(10, 10)] should equal [(10, 10), (30, 10)]");
    
    NSRange range3 = NSMakeRange(50, 10);
    [configuration addCacheFragment:range3];
    fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 3 &&
              NSEqualRanges([fragments[0] rangeValue], range1) &&
              NSEqualRanges([fragments[1] rangeValue], range2) &&
              NSEqualRanges([fragments[2] rangeValue], range3),
              @"add (50, 10) to [(10, 10), (30, 10)] should equal [(10, 10), (30, 10), (50, 10)]");
    
    NSRange range4 = NSMakeRange(25, 26);
    [configuration addCacheFragment:range4];
    fragments = [configuration cacheFragments];
    XCTAssert(fragments.count == 2 &&
              NSEqualRanges([fragments[0] rangeValue], range1) &&
              NSEqualRanges([fragments[1] rangeValue], NSMakeRange(25, 35)),
              @"add (25, 26) to [(10, 10), (30, 10), (50, 10)] should equal [(10, 10), (25, 35)]");
}

- (void)testCacheWorker {
    VIMediaCacheWorker *cacheWorker = [[VIMediaCacheWorker alloc] initWithCacheName:@"test.mp4"];
    
    NSArray *startOffsets = @[@(50), @(80), @(200), @(708), @(1024), @(1500)];
    [cacheWorker setCacheResponse:nil];
    
    if (!cacheWorker.cachedResponse) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"testUrl"]
                                                                    MIMEType:@"mime"
                                                       expectedContentLength:2048
                                                            textEncodingName:nil];
        [cacheWorker setCacheResponse:response];
        
        
        for (NSNumber *offset in startOffsets) {
            NSString *str = @"ddddddddddddddddddddddddddddddddddddddddd"; // 42
            const char *utfStr = [str UTF8String];
            NSData *data = [NSData dataWithBytes:utfStr length:strlen(utfStr) + 1];
            [cacheWorker cacheData:data forRange:NSMakeRange(offset.integerValue, data.length)];
            [cacheWorker save];
        }
    }
    
    NSRange range = NSMakeRange(0, 50);
    NSArray *cacheDataActions1 = [cacheWorker cachedDataActionsForRange:range];
    NSArray *expectActions1 = @[
                                [[VICacheAction alloc] initWithActionType:VICacheAtionTypeRemote range:range]
                                ];
    XCTAssert([cacheDataActions1 isEqualToArray:expectActions1], @"cacheDataActions1 count should equal to %@", expectActions1);
    
    
    NSRange range2 = NSMakeRange(51, 204);
    NSArray *cacheDataActions2 = [cacheWorker cachedDataActionsForRange:range2];
    XCTAssert(cacheDataActions2.count == 4, @"actions count should equal startoffsets's count");
    
    NSRange range3 = NSMakeRange(1300, 300);
    NSArray *cacheDataActions3 = [cacheWorker cachedDataActionsForRange:range3];
    NSArray *expectActions3 = @[
                                [[VICacheAction alloc] initWithActionType:VICacheAtionTypeRemote range:NSMakeRange(1300, 200)],
                                [[VICacheAction alloc] initWithActionType:VICacheAtionTypeLocal range:NSMakeRange(1500, 42)],
                                [[VICacheAction alloc] initWithActionType:VICacheAtionTypeRemote range:NSMakeRange(1542, 58)]
                                ];
    XCTAssert([cacheDataActions3 isEqualToArray:expectActions3], @"actions count should equal");
}

@end
