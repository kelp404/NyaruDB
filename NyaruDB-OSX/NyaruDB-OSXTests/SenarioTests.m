//
//  NyaruDB-OSXTest.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2013/03/27.
//
//

#import <XCTest/XCTest.h>
#import "NyaruDB.h"

#define PATH @"/tmp/NyaruDB_OSX"


@interface ScenarioTests : XCTestCase {
    NyaruDB *_db;
}

@end



@implementation ScenarioTests

- (void)setUp
{
    [super setUp];
    _db = [[NyaruDB alloc] initWithPath:PATH];
}

- (void)tearDown
{
    [_db removeAllCollections];
    [_db close];
    [super tearDown];
}

- (void)testInit
{
    NyaruCollection *co = [_db collection:@"init"];
    XCTAssertNotNil(_db, @"");
    XCTAssertNotNil(co, @"");
}

- (void)testReadWrite
{
    NyaruCollection *co = [_db collection:@"07"];
    
    NSDictionary *subDict = @{@"sub": @"data", @"empty": @""};
    NSArray *array = @[@"A", @-1, [NSNull null], @""];
    NSDictionary *doc = @{@"key": @"a",
                          @"number": @100,
                          @"double": @1000.00002,
                          @"date": [NSDate dateWithTimeIntervalSince1970:100],
                          @"null": [NSNull null],
                          @"sub": subDict,
                          @"array": array};
    [co put:doc];
    [co waitForWriting];
    [co clearCache];
    NSDictionary *check = [[co all] fetchFirst];
    XCTAssertEqualObjects(check[@"key"], doc[@"key"], @"");
    XCTAssertEqualObjects(check[@"number"], doc[@"number"], @"");
    XCTAssertEqualObjects(check[@"double"], doc[@"double"], @"");
    XCTAssertEqualObjects(check[@"date"], doc[@"date"], @"");
    XCTAssertEqualObjects(check[@"null"], doc[@"null"], @"");
    XCTAssertEqualObjects(check[@"sub"][@"sub"], subDict[@"sub"], @"");
    XCTAssertEqualObjects(check[@"sub"][@"empty"], subDict[@"empty"], @"");
    XCTAssertTrue([check[@"array"] containsObject:array[0]], @"");
    XCTAssertTrue([check[@"array"] containsObject:array[1]], @"");
    XCTAssertTrue([check[@"array"] containsObject:array[2]], @"");
    XCTAssertTrue([check[@"array"] containsObject:array[3]], @"");
}

@end