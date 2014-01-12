//
//  NyaruIndexTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/02.
//
//

#import <XCTest/XCTest.h>
#import "NyaruIndex.h"

@interface NyaruIndexTests : XCTestCase {
    NyaruIndex *_ni;
}

@end



@implementation NyaruIndexTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testInit
{
    _ni = [NyaruIndex new];
    XCTAssertNotNil(_ni.keySet, @"");
}

- (void)testInitWith
{
    NSString *value = @"value";
    NSString *key = @"key";
    NSSet *set = [[NSSet alloc] initWithObjects:@"key", nil];
    _ni = [[NyaruIndex alloc] initWithIndexValue:value key:key];
    XCTAssertEqual(_ni.value, value, @"");
    XCTAssertEqualObjects(_ni.keySet, set, @"");
}

@end
