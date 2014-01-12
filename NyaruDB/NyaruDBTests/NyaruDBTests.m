//
//  NyaruDBTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/05.
//
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NyaruDB.h"


@interface NyaruDBTests : XCTestCase {
    NyaruDB *_db;
}

@end




@implementation NyaruDBTests

- (void)setUp
{
    [super setUp];
    
    _db = [NyaruDB instance];
}

- (void)tearDown
{
    [NyaruDB reset];
    
    [super tearDown];
}

#pragma mark - Init
- (void)testInstance
{
    XCTAssertNotNil(_db, @"");
    NyaruDB *db = [NyaruDB instance];
    XCTAssertEqual(_db, db, @"");
}

- (void)testDataBasePath
{
    NSString *path = ((NSArray *)NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)).lastObject;
    NSString *databasePath = [path stringByAppendingPathComponent:@"NyaruDB"];
    XCTAssertEqualObjects(_db.databasePath, databasePath, @"");
}


#pragma mark - Collection
- (void)testCollections
{
    NyaruCollection *collection = [_db collection:@"collection"];
    XCTAssertEqual(_db.collections[0], collection, @"");
}

- (void)testCollection
{
    NyaruCollection *collection = [_db collection:@"collection"];
    XCTAssertEqual(_db.collections[0], collection, @"");
}

- (void)testRemoveCollection
{
    NyaruCollection *collection = [_db collection:@"collection"];
    XCTAssertEqual(_db.collections[0], collection, @"");
    [_db removeCollection:@"collection"];
    XCTAssertEqual(_db.collections.count, 0U, @"");
}

- (void)testRevmoeAllCollections
{
    [_db collection:@"a"];
    [_db collection:@"b"];
    XCTAssertEqual(_db.collections.count, 2U, @"");
    [_db removeAllCollections];
    XCTAssertEqual(_db.collections.count, 0U, @"");
}


@end
