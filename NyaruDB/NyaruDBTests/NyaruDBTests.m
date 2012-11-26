//
//  NyaruDBTests.m
//  NyaruDBTests
//
//  Created by Kelp on 12/7/14.
//  Copyright (c) 2012 Accuvally Inc. All rights reserved.
//

#import "NyaruDBTests.h"

@implementation NyaruDBTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testInit
{
    @try {
        NyaruDB *db = [NyaruDB sharedInstance];
        NSLog(@"database path: %@", db.databasePath);
    }
    @catch (NSException *exception) {
        STFail(@"init failed");
    }
}

- (void)testCollection
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collectioin = [db createCollection:@"collection00"];
    if (collectioin == nil || [db.allCollections objectForKey:@"collection00"] == nil) {
        STFail(@"collection create failed");
    }
    [db removeCollection:@"collection00"];
}

- (void)testSchema
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collection = [db createCollection:@"collection01"];
    [collection createSchema:@"email"];
    [collection createSchema:@"number"];
    [collection insertDocument:@{@"email": @"kelp@phate.org", @"name": @"Kelp"}];
    if (collection.allSchemas.count != 3 ||
        [collection.allSchemas objectForKey:@"email"] == nil ||
        [collection.allSchemas objectForKey:@"number"] == nil ||
        [collection.allSchemas objectForKey:@"key"] == nil) {
        STFail(@"schema create failed");
    }
    [collection remove];
}

- (void)testDocumentForKey
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collection = [db createCollection:@"testDocumentForKey"];
    [collection insertDocument:@{@"key" : @"a00", @"data" : @"accuvally"}];
    NSMutableDictionary *document = [collection documentForKey:@"a00"];
    if ([document objectForKey:@"data"] == nil || ![[document objectForKey:@"data"] isEqualToString:@"accuvally"]) {
        STFail(@"data should be accuvally");
    }
    [collection remove];
}

- (void)testSort
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collection = [db createCollection:@"testSort"];
    [collection createSchema:@"number"];
    [collection insertDocument:@{@"number" : @100}];
    [collection insertDocument:@{@"number" : @200}];
    [collection insertDocument:@{@"number" : @10}];
    
    // desc
    NSArray *query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryOrderDESC]];
    NSArray *documents = [collection documentsForNyaruQueries:query];
    if (![@200 isEqualToNumber:[[documents objectAtIndex:0] objectForKey:@"number"]]) {
        STFail(@"number should be 200");
    }
    if (![@100 isEqualToNumber:[[documents objectAtIndex:1] objectForKey:@"number"]]) {
        STFail(@"number should be 100");
    }
    if (![@10 isEqualToNumber:[[documents objectAtIndex:2] objectForKey:@"number"]]) {
        STFail(@"number should be 10");
    }
    
    // asc
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryOrderASC]];
    documents = [collection documentsForNyaruQueries:query];
    if (![@10 isEqualToNumber:[[documents objectAtIndex:0] objectForKey:@"number"]]) {
        STFail(@"number should be 10");
    }
    if (![@100 isEqualToNumber:[[documents objectAtIndex:1] objectForKey:@"number"]]) {
        STFail(@"number should be 100");
    }
    if (![@200 isEqualToNumber:[[documents objectAtIndex:2] objectForKey:@"number"]]) {
        STFail(@"number should be 200");
    }
    
    [collection remove];
}
    
- (void)testQuery00
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collection = [db createCollection:@"testQuery00"];
    [collection createSchema:@"number"];
    [collection insertDocument:@{@"number" : @10}];
    [collection insertDocument:@{@"number" : @100}];
    [collection insertDocument:@{@"number" : @200}];
    
    
    // NyaruQueryGreater
    NSArray *query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryGreater value:@0]];
    NSArray *documents = [collection documentsForNyaruQueries:query];
    if (documents.count != 3) { STFail(@"query failed"); }
    
    // NyaruQueryGreater
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryGreaterEqual value:@10]];
    documents = [collection documentsForNyaruQueries:query];
    if (documents.count != 3) { STFail(@"query failed"); }
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryGreater value:@101]];
    documents = [collection documentsForNyaruQueries:query];
    if (documents.count != 1) { STFail(@"query failed"); }
    
    // NyaruQueryLess
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryLessEqual value:@100]];
    documents = [collection documentsForNyaruQueries:query];
    if (documents.count != 2) { STFail(@"query failed"); }
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryLessEqual value:@1000]];
    documents = [collection documentsForNyaruQueries:query];
    if (documents.count != 3) { STFail(@"query failed"); }
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryLess value:@1]];
    documents = [collection documentsForNyaruQueries:query];
    if (documents.count != 0) { STFail(@"query failed"); }
    
    // NyaruQueryEqual
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryEqual value:@10]];
    documents = [collection documentsForNyaruQueries:query];
    STAssertEqualObjects([[documents lastObject] objectForKey:@"number"], @10, @"query failed");
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryEqual value:@200]];
    documents = [collection documentsForNyaruQueries:query];
    STAssertEqualObjects([[documents lastObject] objectForKey:@"number"], @200, @"query failed");
    query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryEqual value:@100]];
    documents = [collection documentsForNyaruQueries:query];
    STAssertEqualObjects([[documents lastObject] objectForKey:@"number"], @100, @"query failed");
    
    [collection remove];
}

- (void)testQuery01
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collection = [db createCollection:@"testQuery01"];
    [collection createSchema:@"number"];
    
    // NyaruQueryEqual
    NSArray *query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryLess value:@10]];
    NSArray *documents = [collection documentsForNyaruQueries:query];
    if (documents.count != 0) {
        STFail(@"query failed");
    }
    
    [collection remove];
}

- (void)testDocuments
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collection = [db createCollection:@"testSort"];
    [collection createSchema:@"number"];
    [collection insertDocument:@{@"number" : @100}];
    [collection insertDocument:@{@"number" : @200}];
    [collection insertDocument:@{@"number" : @10}];
    
    NSArray *documents = collection.documents;
    for (NSMutableDictionary *document in documents) {
        NSLog(@"%@", document);
    }
    
    [collection remove];
}

- (void)testRemove
{
    NyaruDB *db = [NyaruDB sharedInstance];
    
    NyaruCollection *collection = [db createCollection:@"testSort"];
    [collection createSchema:@"number"];
    [collection insertDocument:@{@"number" : @100}];
    [collection insertDocument:@{@"number" : @200}];
    [collection insertDocument:@{@"number" : @10}];
    
    [collection removeAllDocument];
    [collection insertDocument:@{@"number" : @100}];
    [collection insertDocument:@{@"number" : @200}];
    [collection insertDocument:@{@"number" : @10}];
    
    [collection remove];
}

- (void)testAccessData
{
    NyaruDB *db = [NyaruDB sharedInstance];
    NyaruCollection *collection = [db createCollection:@"accessTest"];
    
    // create schema
    [collection createSchema:@"number"];
    
    // insert
    NSDate *count = [NSDate new];
    NSDate *date = [NSDate date];
    for (NSInteger index = 0; index < 1000; index++) {
        NSInteger random = arc4random() % 200;
        
        NSDictionary *document = @{ @"email": [NSString stringWithFormat:@"%i@phate.org", random],
            @"name": [NSString stringWithFormat:@"User%i", random],
            @"phone": @"0123456789",
            @"date": date,
            @"text": @"(」・ω・)」うー！(／・ω・)／にゃー！",
            @"number": [NSNumber numberWithInteger:random] };
        [collection insertDocument:document];
    }
    NSLog(@"insert 1k documents cost : %f ms", [count timeIntervalSinceNow] * -1000.0);
    
    // search top 3 document
    NSArray *query = @[[NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryGreater value:@150],
                                [NyaruQuery queryWithSchemaName:@"number" operation:NyaruQueryOrderDESC]];
    NSArray *documents = [collection documentsForNyaruQueries:query skip:0 take:3];
    for (NSMutableDictionary *document in documents) {
        NSLog(@"%@", document);
    }
    
    // remove collection
    [collection remove];
}

@end
