//
//  NyaruIndexTests.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2014/02/13.
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
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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
