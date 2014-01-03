//
//  NyaruQueryTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/03.
//
//

#import <XCTest/XCTest.h>
#import "NyaruQuery.h"
#import "NyaruCollection.h"
#import "NyaruQueryCell.h"


@interface NyaruQueryTests : XCTestCase {
    NyaruQuery *_query;
}

@end



@implementation NyaruQueryTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    
    _query = [NyaruQuery new];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}


#pragma mark Init
- (void)testInit
{
    XCTAssertNotNil(_query, @"");
    XCTAssertEqualObjects(_query.queries, [NSMutableArray new], @"");
    XCTAssertNil(_query.collection, @"");
}

- (void)testInitWithCollection
{
    NyaruCollection *collection = [NyaruCollection new];
    NyaruQuery *nq = [[NyaruQuery alloc] initWithCollection:collection];
    XCTAssertEqual(nq.collection, collection, @"");
}


#pragma mark - and
- (void)testAndEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryEqual | NyaruQueryIntersection;
    cell.value = @"value";
    [_query and:cell.schemaName equal:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testAndNotEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryUnequal | NyaruQueryIntersection;
    cell.value = @"value";
    [_query and:cell.schemaName notEqual:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testAndGreater
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryGreater | NyaruQueryIntersection;
    cell.value = @"value";
    [_query and:cell.schemaName greater:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testAndGreaterEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryGreaterEqual | NyaruQueryIntersection;
    cell.value = @"value";
    [_query and:cell.schemaName greaterEqual:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testAndLess
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryLess | NyaruQueryIntersection;
    cell.value = @"value";
    [_query and:cell.schemaName less:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testAndLessEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryLessEqual | NyaruQueryIntersection;
    cell.value = @"value";
    [_query and:cell.schemaName lessEqual:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testAndLike
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryLike | NyaruQueryIntersection;
    cell.value = @"value";
    [_query and:cell.schemaName like:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

@end
