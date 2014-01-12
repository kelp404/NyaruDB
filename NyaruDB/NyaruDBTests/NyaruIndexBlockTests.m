//
//  NyaruIndexBlockTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/02.
//
//

#import <XCTest/XCTest.h>
#import "NyaruIndexBlock.h"

@interface NyaruIndexBlockTests : XCTestCase {
    NyaruIndexBlock *_nib;
}

@end



@implementation NyaruIndexBlockTests

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
    _nib = [[NyaruIndexBlock alloc] initWithOffset:1 andLength:2];
    XCTAssertEqual(_nib.indexOffset, 1U, @"");
    XCTAssertEqual(_nib.blockLength, 2U, @"");
}

@end
