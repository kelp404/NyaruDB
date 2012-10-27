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
    [collection insertDocumentWithDictionary:@{@"email": @"kelp@phate.org", @"name": @"Kelp"}];
    if (collection.allSchemas.count != 3 ||
        [collection.allSchemas objectForKey:@"email"] == nil ||
        [collection.allSchemas objectForKey:@"number"] == nil ||
        [collection.allSchemas objectForKey:@"key"] == nil) {
        STFail(@"schema create failed");
    }
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
        [collection insertDocumentWithDictionary:document];
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
