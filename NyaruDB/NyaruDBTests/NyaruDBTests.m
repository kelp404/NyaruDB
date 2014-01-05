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

- (void)testCollections
{
    [_db collection:@"collection"];
    XCTAssertEqual(_db.collections.count, 1U, @"");
}


@end
