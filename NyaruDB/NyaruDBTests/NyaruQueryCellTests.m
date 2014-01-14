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
    XCTAssertEqual(NyaruQueryUnequal, 0U, @"");
    XCTAssertEqual(NyaruQueryEqual, 1U, @"");
    
    XCTAssertEqual(NyaruQueryLess, 2U, @"");
    XCTAssertEqual(NyaruQueryLessEqual, 3U, @"");
    
    XCTAssertEqual(NyaruQueryGreater, 4U, @"");
    XCTAssertEqual(NyaruQueryGreaterEqual, 5U, @"");

    XCTAssertEqual(NyaruQueryLike, 0x30U, @"");
    
    XCTAssertEqual(NyaruQueryIntersection, 0x40U, @"");
    XCTAssertEqual(NyaruQueryUnion, 0x00U, @"");
    
    XCTAssertEqual(NyaruQueryAll, 0x80U, @"");
    
    XCTAssertEqual(NyaruQueryOrderASC, 0x100U, @"");
    XCTAssertEqual(NyaruQueryOrderDESC, 0x200U, @"");
}

@end
