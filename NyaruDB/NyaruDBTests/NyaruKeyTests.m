//
//  NyaruKeyTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/02.
//
//

#import <XCTest/XCTest.h>
#import "NyaruKey.h"

@interface NyaruKeyTests : XCTestCase {
    NyaruKey *_nk;
}

@end



@implementation NyaruKeyTests

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
    _nk = [[NyaruKey alloc] initWithIndexOffset:1 documentOffset:2 documentLength:3 blockLength:4];
    XCTAssertEqual(_nk.indexOffset, 1U, @"");
    XCTAssertEqual(_nk.documentOffset, 2U, @"");
    XCTAssertEqual(_nk.documentLength, 3U, @"");
    XCTAssertEqual(_nk.blockLength, 4U, @"");
}

@end
