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
    NSDictionary *check = co.all.fetch.lastObject;
    XCTAssertEqualObjects([check objectForKey:@"key"], [doc objectForKey:@"key"], @"");
    XCTAssertEqualObjects([check objectForKey:@"number"], [doc objectForKey:@"number"], @"");
    XCTAssertEqualObjects([check objectForKey:@"double"], [doc objectForKey:@"double"], @"");
    XCTAssertEqualObjects([check objectForKey:@"date"], [doc objectForKey:@"date"], @"");
    XCTAssertEqualObjects([check objectForKey:@"null"], [doc objectForKey:@"null"], @"");
    XCTAssertEqualObjects([[check objectForKey:@"sub"] objectForKey:@"sub"], [subDict objectForKey:@"sub"], @"");
    XCTAssertEqualObjects([[check objectForKey:@"sub"] objectForKey:@"empty"], [subDict objectForKey:@"empty"], @"");
    XCTAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:0]], @"");
    XCTAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:1]], @"");
    XCTAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:2]], @"");
    XCTAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:3]], @"");
}

@end