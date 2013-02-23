//
//  NyaruDBTests.m
//  NyaruDBTests
//
//  Created by Kelp on 12/7/14.
//

#import "NyaruDBTests.h"
#import "NyaruSchema.h"
#import "NyaruIndex.h"
#import "NyaruConfig.h"


@implementation NyaruDBTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
    @try {
        NyaruDB *db = [NyaruDB instance];
        STAssertNotNil(db, @"nil!!");
        [db removeAllCollections];
        NyaruCollection *collection = [db collectionForName:@"nya"];
        STAssertNotNil(collection, @"nil!!");
    }
    @catch (NSException *exception) {
        NSLog(@"error------------------------------");
        NSLog(@"%@", exception.description);
        STFail(@"execption");
    }
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)test01CreateCollection
{
    NyaruDB *db = [NyaruDB instance];
    
    NyaruCollection *collection = [db collectionForName:@"test01"];
    STAssertNotNil(collection, @"nil!!");
    [db removeCollection:@"test01"];
}

- (void)test02InsertAndRemoveDocument
{
    NyaruDB *db = [NyaruDB instance];
    NyaruCollection *collection = [db collectionForName:@"nya"];
    STAssertEquals(collection.count, 0U, nil);
    
    // insert with key
    NSString *key = [[collection insert:@{@"data": @"value", @"key": @"aa" }] objectForKey:@"key"];
    STAssertEquals(collection.count, 1U, nil);
    STAssertEqualObjects([[[[collection where:@"key" equalTo:key] fetch] lastObject] objectForKey:@"data"], @"value", nil);
    
    // insert without key
    key = [[collection insert:@{@"name": @"Kelp"}] objectForKey:@"key"];
    STAssertEqualObjects([[[[collection where:@"key" equalTo:key] fetch] lastObject] objectForKey:@"name"], @"Kelp", nil);
    // then remove it
    [[collection where:@"key" equalTo:key] remove];
    STAssertEquals(collection.count, 1U, nil);
    
    // remove key == @"aa"
    [[collection where:@"key" equalTo:@"aa"] remove];
    STAssertEquals(collection.count, 0U, nil);
}

- (void)test03CreateAndRemoveIndex
{
    NyaruDB *db = [NyaruDB instance];
    
    NyaruCollection *collection = [db collectionForName:@"nya"];
    [collection removeAllindexes];
    STAssertEquals(collection.allIndexes.count, 1U, nil);
    [collection createIndex:@"updateTime"];
    STAssertEquals([[NSSet setWithArray:collection.allIndexes] intersectsSet:[NSSet setWithObject:@"updateTime"]], YES, nil);
    
    [collection createIndex:@"updateTime"];
    [collection createIndex:@"indexA"];
    [collection createIndex:@"indexB"];
    STAssertEquals([[NSSet setWithArray:collection.allIndexes] intersectsSet:[NSSet setWithObject:@"indexA"]], YES, nil);
    STAssertEquals([[NSSet setWithArray:collection.allIndexes] intersectsSet:[NSSet setWithObject:@"indexB"]], YES, nil);
    STAssertEquals(collection.allIndexes.count, 4U, nil);
    [collection removeIndex:@"indexA"];
    [collection removeIndex:@"indexB"];
    STAssertEquals(collection.allIndexes.count, 2U, nil);
    
    // insert document into collection which has other indexes
    NSDate *time = [NSDate date];
    [collection insert:@{@"name": @"Kelp"}];
    [collection insert:@{@"name": @"Kelp X", @"updateTime": time}];
    [collection insert:@{@"name": @"Kelp"}];
    STAssertEqualObjects([[collection where:@"updateTime" equalTo:time].fetch.lastObject objectForKey:@"name"], @"Kelp X", nil);
}

- (void)test04InsertAndQueryString
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"04"];
    NyaruCollection *co = [db collectionForName:@"04"];
    [co createIndex:@"string"];
    
    for (NSInteger index = 0; index < 10; index++) {
        [co insert:@{@"string": [NSString stringWithFormat:@"B%i", index], @"data": @"data00"}];
    }
    [co insert:@{@"string": @"B5", @"data": @"data00"}];
    // count
    STAssertEquals([co where:@"string" equalTo:@"B0"].count, 1U, nil);
    STAssertEquals([co where:@"string" equalTo:@"B5"].count, 2U, nil);
    STAssertEquals([co where:@"string" equalTo:@"B9"].count, 1U, nil);
    STAssertEquals([co where:@"string" equalTo:@"B10"].count, 0U, nil);
    STAssertEquals([co where:@"string" notEqualTo:@"B0"].count, 10U, nil);
    STAssertEquals([co where:@"string" notEqualTo:@"B5"].count, 9U, nil);
    STAssertEquals([co where:@"string" notEqualTo:@"B9"].count, 10U, nil);
    STAssertEquals([co where:@"string" notEqualTo:@"B10"].count, 11U, nil);
    
    STAssertEquals([co where:@"string" greaterThan:@"B9"].count, 0U, nil);
    STAssertEquals([co where:@"string" greaterThan:@"B8"].count, 1U, nil);
    STAssertEquals([co where:@"string" greaterThan:@"B0"].count, 10U, nil);
    STAssertEquals([co where:@"string" greaterThan:@"A0"].count, 11U, nil);
    STAssertEquals([co where:@"string" greaterEqualThan:@"C0"].count, 0U, nil);
    STAssertEquals([co where:@"string" greaterEqualThan:@"B9"].count, 1U, nil);
    STAssertEquals([co where:@"string" greaterEqualThan:@"B8"].count, 2U, nil);
    STAssertEquals([co where:@"string" greaterEqualThan:@"B0"].count, 11U, nil);
    STAssertEquals([co where:@"string" greaterEqualThan:@"A0"].count, 11U, nil);
    
    STAssertEquals([co where:@"string" lessThan:@"A0"].count, 0U, nil);
    STAssertEquals([co where:@"string" lessThan:@"B0"].count, 0U, nil);
    STAssertEquals([co where:@"string" lessThan:@"B1"].count, 1U, nil);
    STAssertEquals([co where:@"string" lessThan:@"B6"].count, 7U, nil);
    STAssertEquals([co where:@"string" lessThan:@"B9"].count, 10U, nil);
    STAssertEquals([co where:@"string" lessThan:@"C0"].count, 11U, nil);
    STAssertEquals([co where:@"string" lessEqualThan:@"A0"].count, 0U, nil);
    STAssertEquals([co where:@"string" lessEqualThan:@"B0"].count, 1U, nil);
    STAssertEquals([co where:@"string" lessEqualThan:@"B1"].count, 2U, nil);
    STAssertEquals([co where:@"string" lessEqualThan:@"B6"].count, 8U, nil);
    STAssertEquals([co where:@"string" lessEqualThan:@"B9"].count, 11U, nil);
    STAssertEquals([co where:@"string" lessEqualThan:@"C0"].count, 11U, nil);
    
    STAssertEquals([co where:@"string" likeTo:@"b"].count, 11U, nil);
    STAssertEquals([co where:@"string" likeTo:@"c"].count, 0U, nil);
}

- (void)test05InsertAndQueryNumber
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"05"];
    NyaruCollection *co = [db collectionForName:@"05"];
    [co createIndex:@"number"];
    
    for (NSInteger index = 0; index < 10; index++) {
        [co insert:@{@"number": [NSNumber numberWithInteger:index], @"data": @"data00"}];
    }
    [co insert:@{@"number": @5, @"data": @"data00"}];
    // count
    STAssertEquals([co where:@"number" equalTo:@0].count, 1U, nil);
    STAssertEquals([co where:@"number" equalTo:@5].count, 2U, nil);
    STAssertEquals([co where:@"number" equalTo:@9].count, 1U, nil);
    STAssertEquals([co where:@"number" equalTo:@10].count, 0U, nil);
    STAssertEquals([co where:@"number" notEqualTo:@0].count, 10U, nil);
    STAssertEquals([co where:@"number" notEqualTo:@5].count, 9U, nil);
    STAssertEquals([co where:@"number" notEqualTo:@9].count, 10U, nil);
    STAssertEquals([co where:@"number" notEqualTo:@10].count, 11U, nil);
    
    STAssertEquals([co where:@"number" greaterThan:@9].count, 0U, nil);
    STAssertEquals([co where:@"number" greaterThan:@8].count, 1U, nil);
    STAssertEquals([co where:@"number" greaterThan:@0].count, 10U, nil);
    STAssertEquals([co where:@"number" greaterThan:@-1].count, 11U, nil);
    STAssertEquals([co where:@"number" greaterEqualThan:@10].count, 0U, nil);
    STAssertEquals([co where:@"number" greaterEqualThan:@9].count, 1U, nil);
    STAssertEquals([co where:@"number" greaterEqualThan:@8].count, 2U, nil);
    STAssertEquals([co where:@"number" greaterEqualThan:@0].count, 11U, nil);
    STAssertEquals([co where:@"number" greaterEqualThan:@-1].count, 11U, nil);

    STAssertEquals([co where:@"number" lessThan:@-1].count, 0U, nil);
    STAssertEquals([co where:@"number" lessThan:@0].count, 0U, nil);
    STAssertEquals([co where:@"number" lessThan:@1].count, 1U, nil);
    STAssertEquals([co where:@"number" lessThan:@6].count, 7U, nil);
    STAssertEquals([co where:@"number" lessThan:@9].count, 10U, nil);
    STAssertEquals([co where:@"number" lessThan:@10].count, 11U, nil);
    STAssertEquals([co where:@"number" lessEqualThan:@-1].count, 0U, nil);
    STAssertEquals([co where:@"number" lessEqualThan:@0].count, 1U, nil);
    STAssertEquals([co where:@"number" lessEqualThan:@1].count, 2U, nil);
    STAssertEquals([co where:@"number" lessEqualThan:@6].count, 8U, nil);
    STAssertEquals([co where:@"number" lessEqualThan:@9].count, 11U, nil);
    STAssertEquals([co where:@"number" lessEqualThan:@10].count, 11U, nil);
}

- (void)test06InsertAndQueryDate
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"06"];
    NyaruCollection *co = [db collectionForName:@"06"];
    [co createIndex:@"date"];
}

- (void)test07InsertAndQueryNull
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"07"];
    NyaruCollection *co = [db collectionForName:@"07"];
    [co createIndex:@"null"];
}

- (void)test08Order
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"08"];
    NyaruCollection *co = [db collectionForName:@"08"];
    [co createIndex:@"number"];
    
    for (NSInteger index = 0; index < 32; index++) {
        [co insert:@{@"number": [NSNumber numberWithInt:arc4random() % 10]}];
        [co insert:@{@"number": [NSNull null]}];
    }
    NSNumber *previous = nil;
    for (NSMutableDictionary *doc in [[co.all orderBy:@"number"] fetch]) {
        if ([[doc objectForKey:@"number"] isKindOfClass:NSNull.class]) { continue; }
        
        if (previous) {
            if ([previous compare:[doc objectForKey:@"number"]] == NSOrderedDescending) {
                STFail([NSString stringWithFormat:@"%@ --> %@", previous, [doc objectForKey:@"number"]]);
            }
        }
        previous = [doc objectForKey:@"number"];
    }
    
    previous = nil;
    for (NSMutableDictionary *doc in [[co.all orderByDESC:@"number"] fetch]) {
        if ([[doc objectForKey:@"number"] isKindOfClass:NSNull.class]) { continue; }
        
        if (previous) {
            if ([previous compare:[doc objectForKey:@"number"]] == NSOrderedAscending) {
                STFail([NSString stringWithFormat:@"%@ --> %@", previous, [doc objectForKey:@"number"]]);
            }
        }
        previous = [doc objectForKey:@"number"];
    }
}

- (void)test20Speed
{
    NyaruDB *db = [NyaruDB instance];
    
    NyaruCollection *collection = [db collectionForName:@"speed"];
    [collection removeAll];
    [collection createIndex:@"group"];
    
    NSDate *timer = [NSDate date];
    for (NSInteger loop = 0; loop < 1000; loop++) {
        [collection insert:@{
         @"name": @"Test",
         @"url": @"https://github.com/Kelp404/NyaruDB",
         @"phone": @"0123456",
         @"address": @"1600 Amphitheatre Parkway Mountain View, CA 94043, USA",
         @"group": [NSNumber numberWithInt:arc4random() % 512],
         @"email": @"test@phate.org",
         @"level": @0,
         @"updateTime": @""
         }];
    }
    NSLog(@"------------------------------------------------");
    NSLog(@"insert 1k data cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
    [collection waiteForWriting];
    
    timer = [NSDate date];
    collection.all.fetch;
    NSLog(@"------------------------------------------------");
    NSLog(@"fetch 1k data cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
    
    timer = [NSDate date];
    for (NSInteger index = 0; index < 10; index++) {
        [collection where:@"group" greaterEqualThan:[NSNumber numberWithInt:arc4random() % 512]].fetch;
    }
    NSLog(@"------------------------------------------------");
    NSLog(@"search documents in 1k data for 10 times cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
}


@end
