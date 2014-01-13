//
//  ScenarioLoadDataTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/13.
//
//

#import <XCTest/XCTest.h>
#import "NyaruDB.h"



@interface ScenarioLoadDataTests : XCTestCase {
    NyaruDB *_db;
}

@end



@implementation ScenarioLoadDataTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test0Reset
{
    [NyaruDB reset];
}


#pragma mark - Indexes
- (void)test1WriteDataIndexes
{
    _db = [[NyaruDB alloc] init];
    NyaruCollection *collection = [_db collection:@"indexes"];
    [collection createIndex:@"name"];
    [collection createIndex:@"group"];
}

- (void)test2ReadDataIndexes
{
    _db = [[NyaruDB alloc] init];
    NyaruCollection *collection = [_db collection:@"indexes"];
    
    NSArray *indexes = @[@"key", @"name", @"group"];
    XCTAssertEqualObjects(collection.allIndexes, indexes, @"");
}


#pragma mark - Document
- (void)test1WriteDataDocument
{
    _db = [[NyaruDB alloc] init];
    NyaruCollection *collection = [_db collection:@"document"];
    [collection put:@{@"name": @"value"}];
}

- (void)test2ReadDataDocument
{
    _db = [[NyaruDB alloc] init];
    NyaruCollection *collection = [_db collection:@"document"];
    
    NSDictionary *doc = [[collection all] fetchFirst];
    XCTAssertEqualObjects(doc[@"name"], @"value", @"");
}


#pragma mark - Documents
- (void)test1WriteDataDocuments
{
    _db = [[NyaruDB alloc] init];
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
    _db = [[NyaruDB alloc] init];
    NyaruCollection *collection = [_db collection:@"documents"];
    NSArray *docs = [[[collection all] orderBy:@"index"] fetch];
    NSInteger index = 0;
    for (NSDictionary *doc in docs) {
        XCTAssertEqualObjects(doc[@"index"], [NSNumber numberWithInteger:index++], @"");
    }
    XCTAssertEqual(index, 1000, @"");
}


@end
