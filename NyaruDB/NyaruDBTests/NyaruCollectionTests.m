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



@end
