//
//  NyaruQueryCellTests.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2014/02/13.
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
    XCTAssertEqual(NyaruQueryUnequal, 0UL, @"");
    XCTAssertEqual(NyaruQueryEqual, 1UL, @"");
    
    XCTAssertEqual(NyaruQueryLess, 2UL, @"");
    XCTAssertEqual(NyaruQueryLessEqual, 3UL, @"");
    
    XCTAssertEqual(NyaruQueryGreater, 4UL, @"");
    XCTAssertEqual(NyaruQueryGreaterEqual, 5UL, @"");
    
    XCTAssertEqual(NyaruQueryLike, 0x30UL, @"");
    
    XCTAssertEqual(NyaruQueryIntersection, 0x40UL, @"");
    XCTAssertEqual(NyaruQueryUnion, 0x00UL, @"");
    
    XCTAssertEqual(NyaruQueryAll, 0x80UL, @"");
    
    XCTAssertEqual(NyaruQueryOrderASC, 0x100UL, @"");
    XCTAssertEqual(NyaruQueryOrderDESC, 0x200UL, @"");
}

@end
