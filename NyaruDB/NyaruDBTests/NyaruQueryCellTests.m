//
//  NyaruQueryCellTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/03.
//
//

#import <XCTest/XCTest.h>
#import "NyaruQueryCell.h"


@interface NyaruQueryCellTests : XCTestCase {
    NyaruQueryCell *_nqc;
}

@end



@implementation NyaruQueryCellTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    
    _nqc = [NyaruQueryCell new];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)testInit
{
    XCTAssertNotNil(_nqc, @"");
}

- (void)testNyaruQueryOperation
{
    XCTAssertEqual(NyaruQueryUnequal, 0, @"");
    XCTAssertEqual(NyaruQueryEqual, 1, @"");
    
    XCTAssertEqual(NyaruQueryLess, 2, @"");
    XCTAssertEqual(NyaruQueryLessEqual, 3, @"");
    
    XCTAssertEqual(NyaruQueryGreater, 4, @"");
    XCTAssertEqual(NyaruQueryGreaterEqual, 5, @"");

    XCTAssertEqual(NyaruQueryLike, 0x30, @"");
    
    XCTAssertEqual(NyaruQueryIntersection, 0x40, @"");
    XCTAssertEqual(NyaruQueryUnion, 0x00, @"");
    
    XCTAssertEqual(NyaruQueryAll, 0x80, @"");
    
    XCTAssertEqual(NyaruQueryOrderASC, 0x100, @"");
    XCTAssertEqual(NyaruQueryOrderDESC, 0x200, @"");
}

@end
