//
//  ScenarioLoadDataTest.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2014/02/14.
//
//

#import <XCTest/XCTest.h>
#import "NyaruDB.h"

#define PATH @"/tmp/NyaruDB"

@interface ScenarioLoadDataTest : XCTestCase {
    NyaruDB *_db;
}

@end



@implementation ScenarioLoadDataTest

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

- (void)test0Cleanup
{
    _db = [[NyaruDB alloc] initWithPath:PATH];
    [_db removeAllCollections];
    [_db close];
}

#pragma mark - Indexes
- (void)test1WriteDataIndexes
{
    _db = [[NyaruDB alloc] initWithPath:PATH];
    NyaruCollection *collection = [_db collection:@"indexes"];
    [collection createIndex:@"name"];
    [collection createIndex:@"group"];
}

- (void)test2ReadDataIndexes
{
    _db = [[NyaruDB alloc] initWithPath:PATH];
    NyaruCollection *collection = [_db collection:@"indexes"];
    
    NSArray *indexes = @[@"key", @"name", @"group"];
    XCTAssertEqualObjects(collection.allIndexes, indexes, @"");
}


#pragma mark - Document
- (void)test1WriteDataDocument
{
    _db = [[NyaruDB alloc] initWithPath:PATH];
    NyaruCollection *collection = [_db collection:@"document"];
    [collection put:@{@"name": @"value"}];
}

- (void)test2ReadDataDocument
{
    _db = [[NyaruDB alloc] initWithPath:PATH];
    NyaruCollection *collection = [_db collection:@"document"];
    
    NSDictionary *doc = [[collection all] fetchFirst];
    XCTAssertEqualObjects(doc[@"name"], @"value", @"");
}


#pragma mark - Documents
- (void)test1WriteDataDocuments
{
    _db = [[NyaruDB alloc] initWithPath:PATH];
    NyaruCollection *collection = [_db collection:@"documents"];
    [collection createIndex:@"index"];
    NSMutableDictionary *doc = [NSMutableDictionary new];
    for (NSInteger index = 0; index < 1000; index++) {
        [doc setObject:[NSNumber numberWithInteger:index] forKey:@"index"];
        [collection put:doc];
    }
    [collection waitForWriting];
}

- (void)test2ReadDataDocuments
{
    _db = [[NyaruDB alloc] initWithPath:PATH];
    NyaruCollection *collection = [_db collection:@"documents"];
    NSArray *docs = [[[collection all] orderBy:@"index"] fetch];
    NSInteger index = 0;
    for (NSDictionary *doc in docs) {
        XCTAssertEqualObjects(doc[@"index"], [NSNumber numberWithInteger:index++], @"");
    }
    XCTAssertEqual(index, 1000L
                   , @"");
}

@end
