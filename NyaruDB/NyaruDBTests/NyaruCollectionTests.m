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
    _collection = [[NyaruCollection alloc] initWithNewCollectionName:@"collection" databasePath:TEST_PATH];
    XCTAssertEqualObjects(_collection.name, @"collection", @"");
}


@end
