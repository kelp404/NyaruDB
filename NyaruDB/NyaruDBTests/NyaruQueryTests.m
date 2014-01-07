//
//  NyaruQueryTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/03.
//
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
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


#pragma mark - And
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


#pragma mark - Or
- (void)testOrEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryEqual | NyaruQueryUnion;
    cell.value = @"value";
    [_query or:cell.schemaName equal:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testOrNotEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryUnequal | NyaruQueryUnion;
    cell.value = @"value";
    [_query or:cell.schemaName notEqual:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testOrGreater
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryGreater | NyaruQueryUnion;
    cell.value = @"value";
    [_query or:cell.schemaName greater:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testOrGreaterEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryGreaterEqual | NyaruQueryUnion;
    cell.value = @"value";
    [_query or:cell.schemaName greaterEqual:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testOrLess
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryLess | NyaruQueryUnion;
    cell.value = @"value";
    [_query or:cell.schemaName less:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testOrLessEqual
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryLessEqual | NyaruQueryUnion;
    cell.value = @"value";
    [_query or:cell.schemaName lessEqual:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}

- (void)testOrLike
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryLike | NyaruQueryUnion;
    cell.value = @"value";
    [_query or:cell.schemaName like:cell.value];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertEqualObjects([_query.queries[0] value], cell.value, @"");
}


#pragma mark - Order By
- (void)testOrderBy
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryOrderASC;
    [_query orderBy:cell.schemaName];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertNil([_query.queries[0] value], @"");
}

- (void)testOrderByDESC
{
    NyaruQueryCell *cell = [NyaruQueryCell new];
    cell.schemaName = @"name";
    cell.operation = NyaruQueryOrderDESC;
    [_query orderByDESC:cell.schemaName];
    XCTAssertEqual(_query.queries.count, 1U, @"");
    XCTAssertEqualObjects([_query.queries[0] schemaName], cell.schemaName, @"");
    XCTAssertEqual([_query.queries[0] operation], cell.operation, @"");
    XCTAssertNil([_query.queries[0] value], @"");
}


#pragma mark - Count
- (void)testCount
{
    id collection = [OCMockObject mockForClass:[NyaruCollection class]];
    _query = [[NyaruQuery alloc] initWithCollection:collection];
    [[collection expect] countByQuery:_query.queries];
    [[_query and:@"name" equal:@"value"] count];
    XCTAssertNoThrow([collection verify], @"");
}


#pragma mark - Fetch
- (void)testFetch
{
    id collection = [OCMockObject mockForClass:[NyaruCollection class]];
    _query = [[NyaruQuery alloc] initWithCollection:collection];
    [[collection expect] fetchByQuery:_query.queries skip:0 limit:0];
    [_query and:@"name" equal:@"value"];
    [_query fetch];
    XCTAssertNoThrow([collection verify], @"");
}

- (void)testFetchLimit
{
    id collection = [OCMockObject mockForClass:[NyaruCollection class]];
    _query = [[NyaruQuery alloc] initWithCollection:collection];
    [[collection expect] fetchByQuery:_query.queries skip:0 limit:1];
    [_query and:@"name" equal:@"value"];
    [_query fetch:1];
    XCTAssertNoThrow([collection verify], @"");
}

- (void)testFetchLimitSkip
{
    id collection = [OCMockObject mockForClass:[NyaruCollection class]];
    _query = [[NyaruQuery alloc] initWithCollection:collection];
    [[collection expect] fetchByQuery:_query.queries skip:2 limit:1];
    [_query and:@"name" equal:@"value"];
    [_query fetch:1 skip:2];
    XCTAssertNoThrow([collection verify], @"");
}

- (void)testFetchFirst
{
    id collection = [OCMockObject mockForClass:[NyaruCollection class]];
    _query = [[NyaruQuery alloc] initWithCollection:collection];
    [[collection expect] fetchByQuery:_query.queries skip:0 limit:1];
    [_query and:@"name" equal:@"value"];
    [_query fetchFirst];
    XCTAssertNoThrow([collection verify], @"");
}


#pragma mark - Remove
- (void)testRemove
{
    id collection = [OCMockObject mockForClass:[NyaruCollection class]];
    _query = [[NyaruQuery alloc] initWithCollection:collection];
    [[collection expect] removeByQuery:_query.queries];
    [_query and:@"name" equal:@"value"];
    [_query remove];
    XCTAssertNoThrow([collection verify], @"");
}


@end
