//
//  NyaruDBTests.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2014/02/12.
//
//

#import <XCTest/XCTest.h>
#import "NyaruDB.h"

@interface NyaruDBTests : XCTestCase {
    NyaruDB *_db;
}

@end



@implementation NyaruDBTests

- (void)setUp
{
    [super setUp];
    
    _db = [[NyaruDB alloc] initWithPath:@"/tmp/NyaruDB"];
}

- (void)tearDown
{
    [_db removeAllCollections];
    [_db close];
    
    [super tearDown];
}

- (void)testDataBasePath
{
    XCTAssertEqualObjects(_db.databasePath, @"/tmp/NyaruDB", @"");
}

- (void)testCollections
{
    NyaruCollection *collection = [_db collection:@"collection"];
    XCTAssertEqual(_db.collections[0], collection, @"");
}

- (void)testRemoveCollection
{
    NyaruCollection *collection = [_db collection:@"collection"];
    XCTAssertEqual(_db.collections[0], collection, @"");
    [_db removeCollection:@"collection"];
    XCTAssertEqual(_db.collections.count, 0UL, @"");
}

- (void)testRevmoeAllCollections
{
    [_db collection:@"a"];
    [_db collection:@"b"];
    XCTAssertEqual(_db.collections.count, 2UL, @"");
    [_db removeAllCollections];
    XCTAssertEqual(_db.collections.count, 0UL, @"");
}

@end
