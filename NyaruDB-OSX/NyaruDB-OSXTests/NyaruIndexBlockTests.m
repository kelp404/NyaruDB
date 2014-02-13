//
//  NyaruIndexBlockTests.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2014/02/13.
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
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInit
{
    _nib = [[NyaruIndexBlock alloc] initWithOffset:1 andLength:2];
    XCTAssertEqual(_nib.indexOffset, 1U, @"");
    XCTAssertEqual(_nib.blockLength, 2U, @"");
}

@end
