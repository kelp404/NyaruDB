//
//  NyaruCollectionTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/06.
//
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMArg.h>
#import "NyaruDB.h"
#import "NyaruQueryCell.h"


#define TEST_PATH @"/tmp/nyaruTests"


@interface NyaruCollectionTests : XCTestCase {
    NyaruDB *_db;
    NyaruCollection *_collection;
}

@end



@implementation NyaruCollectionTests

- (void)setUp
{
    [super setUp];
    
    _db = [NyaruDB instance];
    if (![[NSFileManager defaultManager] fileExistsAtPath:TEST_PATH]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:TEST_PATH withIntermediateDirectories:YES attributes:nil error:&error];
        XCTAssertNil(error, @"");
    }
}

- (void)tearDown
{
    [NyaruDB reset];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:TEST_PATH error:&error];
    XCTAssertNil(error, @"");
    
    [super tearDown];
}


#pragma mark - Init
- (void)testInit
{
    XCTAssertNotNil(_db, @"");
    XCTAssertEqualObjects(_db.collections, @[], @"");
}

- (void)testInitWithNewCollectionName
{
    _collection = [[NyaruCollection alloc] initWithNewCollectionName:@"newCollection" databasePath:TEST_PATH];
    XCTAssertEqualObjects(_collection.name, @"newCollection", @"");
}


#pragma mark - Index
- (void)testAllIndexes
{
    _collection = [_db collection:@"collection"];
    XCTAssertEqualObjects(_collection.allIndexes, @[@"key"], @"");
}

- (void)testCreateIndex
{
    _collection = [_db collection:@"collection"];
    [_collection createIndex:@"index"];
    NSArray *indexes = @[@"key", @"index"];
    XCTAssertEqualObjects(_collection.allIndexes, indexes, @"");
}

- (void)testRemoveIndex
{
    _collection = [_db collection:@"collection"];
    [_collection createIndex:@"index"];
    [_collection removeIndex:@"index"];
    XCTAssertEqualObjects(_collection.allIndexes, @[@"key"], @"");
    XCTAssertThrows([_collection removeIndex:@"key"], @"");
}

- (void)testRemoveAllIndexes
{
    _collection = [_db collection:@"collection"];
    [_collection createIndex:@"indexA"];
    [_collection createIndex:@"indexB"];
    XCTAssertNoThrow([_collection removeAllindexes], @"");
    XCTAssertEqualObjects(_collection.allIndexes, @[@"key"], @"");
}


#pragma mark - Document
- (void)testPutNilDocument
{
    _collection = [_db collection:@"collection"];
    XCTAssertThrows([_collection put:nil], @"");
}

- (void)testPutDocumentWithoutKey
{
    _collection = [_db collection:@"collection"];
    NSDictionary *doc = [_collection put:@{@"name": @"value"}];
    XCTAssertNotNil(doc[@"key"], @"");
    XCTAssertEqualObjects(doc[@"name"], @"value", @"");
}

- (void)testPutDocumentWithoutNullKey
{
    _collection = [_db collection:@"collection"];
    NSDictionary *doc = [_collection put:@{@"key": [NSNull null], @"name": @"value"}];
    XCTAssertNotNil(doc[@"key"], @"");
    XCTAssertEqualObjects(doc[@"name"], @"value", @"");
}

- (void)testTheKeyOfDocumentIsGUID
{
    _collection = [_db collection:@"collection"];
    NSDictionary *doc = [_collection put:@{@"name": @"value"}];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[A-F0-9]{8}(?:-[A-F0-9]{4}){3}-[A-F0-9]{12}$"
                                                                           options:0 error:nil];
    NSString *key = doc[@"key"];
    NSInteger matchs = [regex numberOfMatchesInString:key options:0 range:NSMakeRange(0, key.length)];
    XCTAssertEqual(matchs, 1, @"");
}


#pragma mark - Query
- (void)testFetchEmptyData
{
    _collection = [_db collection:@"collection"];
    XCTAssertNil([[_collection all] fetchFirst], @"");
}

- (void)testPutAndFetch
{
    _collection = [_db collection:@"collection"];
    NSDictionary *doc = [_collection put:@{@"name": @"value"}];
    NSArray *documents = [[_collection all] fetch];
    XCTAssertEqualObjects(documents, @[doc], @"");
}

- (void)testPutAndFetchFirst
{
    _collection = [_db collection:@"collection"];
    NSDictionary *doc = [_collection put:@{@"name": @"value"}];
    NSDictionary *document = [[_collection all] fetchFirst];
    XCTAssertEqualObjects(document, doc, @"");
}

- (void)testQuery
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = _collection.query;
    XCTAssertEqual(query.collection, _collection, @"");
}

- (void)testQueryAll
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection all];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryAll, @"");
}

- (void)testQueryWhereEqual
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection where:@"name" equal:@"value"];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryEqual, @"");
    XCTAssertEqualObjects([query.queries[0] schemaName], @"name", @"");
    XCTAssertEqualObjects([query.queries[0] value], @"value", @"");
}

- (void)testQueryWhereNotEqual
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection where:@"name" notEqual:@"value"];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryUnequal, @"");
    XCTAssertEqualObjects([query.queries[0] schemaName], @"name", @"");
    XCTAssertEqualObjects([query.queries[0] value], @"value", @"");
}

- (void)testQueryWhereLess
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection where:@"name" less:@10];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryLess, @"");
    XCTAssertEqualObjects([query.queries[0] schemaName], @"name", @"");
    XCTAssertEqualObjects([query.queries[0] value], @10, @"");
}

- (void)testQueryWhereLessEqual
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection where:@"name" lessEqual:@10];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryLessEqual, @"");
    XCTAssertEqualObjects([query.queries[0] schemaName], @"name", @"");
    XCTAssertEqualObjects([query.queries[0] value], @10, @"");
}

- (void)testQueryWhereGreater
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection where:@"name" greater:@10];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryGreater, @"");
    XCTAssertEqualObjects([query.queries[0] schemaName], @"name", @"");
    XCTAssertEqualObjects([query.queries[0] value], @10, @"");
}

- (void)testQueryWhereGreaterEqual
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection where:@"name" greaterEqual:@10];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryGreaterEqual, @"");
    XCTAssertEqualObjects([query.queries[0] schemaName], @"name", @"");
    XCTAssertEqualObjects([query.queries[0] value], @10, @"");
}

- (void)testQueryWhereLike
{
    _collection = [_db collection:@"collection"];
    NyaruQuery *query = [_collection where:@"name" like:@"value"];
    XCTAssertEqual(query.collection, _collection, @"");
    XCTAssertEqual([query.queries[0] operation], NyaruQueryLike, @"");
    XCTAssertEqualObjects([query.queries[0] schemaName], @"name", @"");
    XCTAssertEqualObjects([query.queries[0] value], @"value", @"");
}


#pragma mark - Count
- (void)testCount
{
    _collection = [_db collection:@"collection"];
    XCTAssertEqual(_collection.count, 0U, @"");
    
    NSDictionary *doc = [_collection put:@{@"name": @"value"}];
    XCTAssertEqual(_collection.count, 1U, @"");
    
    [[_collection where:@"key" equal:doc[@"key"]] remove];
    XCTAssertEqual(_collection.count, 0U, @"");
    
    [_collection put:@{@"name": @1}];
    [_collection put:@{@"name": @2}];
    XCTAssertEqual(_collection.count, 2U, @"");
}

- (void)testCountWithQuery
{
    _collection = [_db collection:@"collection"];
    [_collection createIndex:@"name"];
    NSUInteger count = [[_collection where:@"name" equal:@1] count];
    XCTAssertEqual(count, 0U, @"");
    
    [_collection put:@{@"name": @1}];
    [_collection put:@{@"name": @1}];
    count = [[_collection where:@"name" equal:@1] count];
    XCTAssertEqual(count, 2U, @"");
}


#pragma mark - Fetch
- (void)testFetchByQuery
{
    _collection = [_db collection:@"collection"];
    [_collection createIndex:@"name"];
    NSDictionary *doc = [_collection put:@{@"name": @"value"}];
    NyaruQuery *query = [_collection where:@"name" equal:@"value"];
    NSArray *data = [_collection fetchByQuery:query.queries skip:0 limit:0];
    XCTAssertEqualObjects(data[0], doc, @"");
}

- (void)testFetchKeyByQuery
{
    _collection = [_db collection:@"collection"];
    [_collection createIndex:@"name"];
    NSDictionary *doc = [_collection put:@{@"name": @"value"}];
    NyaruQuery *query = [_collection where:@"name" equal:@"value"];
    NSArray *data = [_collection fetchKeyByQuery:query.queries skip:0 limit:0];
    XCTAssertEqualObjects(data[0], doc[@"key"], @"");
}



@end
