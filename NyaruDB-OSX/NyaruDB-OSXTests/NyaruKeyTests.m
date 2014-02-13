//
//  NyaruKeyTests.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2014/02/13.
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
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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
