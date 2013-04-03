//
//  NyaruDBTests.m
//  NyaruDBTests
//
//  Created by Kelp on 12/7/14.
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
    [collection removeAll];
    STAssertEquals(collection.count, 0U, nil);
    
    // insert with key
    NSString *key = [[collection insert:@{@"data": @"value", @"key": @"aa" }] objectForKey:@"key"];
    STAssertEquals(collection.count, 1U, nil);
    STAssertEqualObjects([[[[collection where:@"key" equal:key] fetch] lastObject] objectForKey:@"data"], @"value", nil);
    
    // insert without key
    key = [[collection insert:@{@"name": @"Kelp"}] objectForKey:@"key"];
    STAssertEqualObjects([[[[collection where:@"key" equal:key] fetch] lastObject] objectForKey:@"name"], @"Kelp", nil);
    // then remove it
    [[collection where:@"key" equal:key] remove];
    STAssertEquals(collection.count, 1U, nil);
    
    // remove key == @"aa"
    [[collection where:@"key" equal:@"aa"] remove];
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
    STAssertEqualObjects([[collection where:@"updateTime" equal:time].fetch.lastObject objectForKey:@"name"], @"Kelp X", nil);
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
    STAssertEquals([co where:@"string" equal:@"B0"].count, 1U, nil);
    STAssertEquals([co where:@"string" equal:@"B5"].count, 2U, nil);
    STAssertEquals([co where:@"string" equal:@"B9"].count, 1U, nil);
    STAssertEquals([co where:@"string" equal:@"B10"].count, 0U, nil);
    STAssertEquals([co where:@"string" notEqual:@"B0"].count, 10U, nil);
    STAssertEquals([co where:@"string" notEqual:@"B5"].count, 9U, nil);
    STAssertEquals([co where:@"string" notEqual:@"B9"].count, 10U, nil);
    STAssertEquals([co where:@"string" notEqual:@"B10"].count, 11U, nil);
    
    STAssertEquals([co where:@"string" greater:@"B9"].count, 0U, nil);
    STAssertEquals([co where:@"string" greater:@"B8"].count, 1U, nil);
    STAssertEquals([co where:@"string" greater:@"B0"].count, 10U, nil);
    STAssertEquals([co where:@"string" greater:@"A0"].count, 11U, nil);
    STAssertEquals([co where:@"string" greaterEqual:@"C0"].count, 0U, nil);
    STAssertEquals([co where:@"string" greaterEqual:@"B9"].count, 1U, nil);
    STAssertEquals([co where:@"string" greaterEqual:@"B8"].count, 2U, nil);
    STAssertEquals([co where:@"string" greaterEqual:@"B0"].count, 11U, nil);
    STAssertEquals([co where:@"string" greaterEqual:@"A0"].count, 11U, nil);
    
    STAssertEquals([co where:@"string" less:@"A0"].count, 0U, nil);
    STAssertEquals([co where:@"string" less:@"B0"].count, 0U, nil);
    STAssertEquals([co where:@"string" less:@"B1"].count, 1U, nil);
    STAssertEquals([co where:@"string" less:@"B6"].count, 7U, nil);
    STAssertEquals([co where:@"string" less:@"B9"].count, 10U, nil);
    STAssertEquals([co where:@"string" less:@"C0"].count, 11U, nil);
    STAssertEquals([co where:@"string" lessEqual:@"A0"].count, 0U, nil);
    STAssertEquals([co where:@"string" lessEqual:@"B0"].count, 1U, nil);
    STAssertEquals([co where:@"string" lessEqual:@"B1"].count, 2U, nil);
    STAssertEquals([co where:@"string" lessEqual:@"B6"].count, 8U, nil);
    STAssertEquals([co where:@"string" lessEqual:@"B9"].count, 11U, nil);
    STAssertEquals([co where:@"string" lessEqual:@"C0"].count, 11U, nil);
    
    STAssertEquals([co where:@"string" like:@"b"].count, 11U, nil);
    STAssertEquals([co where:@"string" like:@"c"].count, 0U, nil);
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
    STAssertEquals([co where:@"number" equal:@0].count, 1U, nil);
    STAssertEquals([co where:@"number" equal:@5].count, 2U, nil);
    STAssertEquals([co where:@"number" equal:@9].count, 1U, nil);
    STAssertEquals([co where:@"number" equal:@10].count, 0U, nil);
    STAssertEquals([co where:@"number" notEqual:@0].count, 10U, nil);
    STAssertEquals([co where:@"number" notEqual:@5].count, 9U, nil);
    STAssertEquals([co where:@"number" notEqual:@9].count, 10U, nil);
    STAssertEquals([co where:@"number" notEqual:@10].count, 11U, nil);
    
    STAssertEquals([co where:@"number" greater:@9].count, 0U, nil);
    STAssertEquals([co where:@"number" greater:@8].count, 1U, nil);
    STAssertEquals([co where:@"number" greater:@0].count, 10U, nil);
    STAssertEquals([co where:@"number" greater:@-1].count, 11U, nil);
    STAssertEquals([co where:@"number" greaterEqual:@10].count, 0U, nil);
    STAssertEquals([co where:@"number" greaterEqual:@9].count, 1U, nil);
    STAssertEquals([co where:@"number" greaterEqual:@8].count, 2U, nil);
    STAssertEquals([co where:@"number" greaterEqual:@0].count, 11U, nil);
    STAssertEquals([co where:@"number" greaterEqual:@-1].count, 11U, nil);

    STAssertEquals([co where:@"number" less:@-1].count, 0U, nil);
    STAssertEquals([co where:@"number" less:@0].count, 0U, nil);
    STAssertEquals([co where:@"number" less:@1].count, 1U, nil);
    STAssertEquals([co where:@"number" less:@6].count, 7U, nil);
    STAssertEquals([co where:@"number" less:@9].count, 10U, nil);
    STAssertEquals([co where:@"number" less:@10].count, 11U, nil);
    STAssertEquals([co where:@"number" lessEqual:@-1].count, 0U, nil);
    STAssertEquals([co where:@"number" lessEqual:@0].count, 1U, nil);
    STAssertEquals([co where:@"number" lessEqual:@1].count, 2U, nil);
    STAssertEquals([co where:@"number" lessEqual:@6].count, 8U, nil);
    STAssertEquals([co where:@"number" lessEqual:@9].count, 11U, nil);
    STAssertEquals([co where:@"number" lessEqual:@10].count, 11U, nil);
}

- (void)test06InsertAndQueryDate
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"06"];
    NyaruCollection *co = [db collectionForName:@"06"];
    [co createIndex:@"date"];
    
    for (NSInteger index = 1; index <= 10; index++) {
        [co insert:@{@"date": [NSDate dateWithTimeIntervalSince1970:index * 100]}];
    }
    for (NSUInteger index = 1; index <= 10; index++) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:index * 100];
        STAssertEquals([[co where:@"date" equal:date] count], 1U, nil);
        
        date = [NSDate dateWithTimeIntervalSince1970:(index + 1) * 100];
        STAssertEquals([[co where:@"date" less:date] count], index, nil);
    }
    
    STAssertEquals([[co where:@"date" greaterEqual:[NSDate dateWithTimeIntervalSince1970:0]] count], 10U, nil);
    STAssertEquals([[co where:@"date" greaterEqual:[NSDate date]] count], 0U, nil);
    STAssertEquals([[co where:@"date" less:[NSDate date]] count], 10U, nil);
}

- (void)test07ReadWrite
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"07"];
    NyaruCollection *co = [db collectionForName:@"07"];
    
    NSDictionary *subDict = @{@"sub": @"data", @"empty": @""};
    NSArray *array = @[@"A", @-1, [NSNull null], @""];
    NSDictionary *doc = @{@"key": @"a",
                          @"number": @100,
                          @"double": @1000.00002,
                          @"date": [NSDate dateWithTimeIntervalSince1970:100],
                          @"null": [NSNull null],
                          @"sub": subDict,
                          @"array": array};
    [co insert:doc];
    [co clearCache];
    NSDictionary *check = co.all.fetch.lastObject;
    STAssertEqualObjects([check objectForKey:@"key"], [doc objectForKey:@"key"], nil);
    STAssertEqualObjects([check objectForKey:@"number"], [doc objectForKey:@"number"], nil);
    STAssertEqualObjects([check objectForKey:@"double"], [doc objectForKey:@"double"], nil);
    STAssertEqualObjects([check objectForKey:@"date"], [doc objectForKey:@"date"], nil);
    STAssertEqualObjects([check objectForKey:@"null"], [doc objectForKey:@"null"], nil);
    STAssertEqualObjects([[check objectForKey:@"sub"] objectForKey:@"sub"], [subDict objectForKey:@"sub"], nil);
    STAssertEqualObjects([[check objectForKey:@"sub"] objectForKey:@"empty"], [subDict objectForKey:@"empty"], nil);
    STAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:0]], nil);
    STAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:1]], nil);
    STAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:2]], nil);
    STAssertTrue([[check objectForKey:@"array"] containsObject:[array objectAtIndex:3]], nil);
}

- (void)test08Order
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"08"];
    NyaruCollection *co = [db collectionForName:@"08"];
    [co createIndex:@"number"];
    
    for (NSInteger index = 0; index < 32; index++) {
        [co insert:@{@"number": [NSNumber numberWithInt:arc4random() % 10]}];
        [co insert:@{}];
    }
    NSNumber *previous = nil;
    for (NSMutableDictionary *doc in [[co.all orderBy:@"number"] fetch]) {
        if ([doc objectForKey:@"number"] == nil || [[doc objectForKey:@"number"] isKindOfClass:NSNull.class]) { continue; }
        
        if (previous) {
            if ([previous compare:[doc objectForKey:@"number"]] == NSOrderedDescending) {
                STFail([NSString stringWithFormat:@"%@ --> %@", previous, [doc objectForKey:@"number"]]);
            }
        }
        previous = [doc objectForKey:@"number"];
    }
    
    previous = nil;
    for (NSMutableDictionary *doc in [[co.all orderByDESC:@"number"] fetch]) {
        if ([doc objectForKey:@"number"] == nil || [[doc objectForKey:@"number"] isKindOfClass:NSNull.class]) { continue; }
        
        if (previous) {
            if ([previous compare:[doc objectForKey:@"number"]] == NSOrderedAscending) {
                STFail([NSString stringWithFormat:@"%@ --> %@", previous, [doc objectForKey:@"number"]]);
            }
        }
        previous = [doc objectForKey:@"number"];
    }
}

- (void)test09MixedQuery
{
    NyaruDB *db = [NyaruDB instance];
    [db removeCollection:@"09"];
    NyaruCollection *co = [db collectionForName:@"09"];
    [co createIndex:@"number"];
    [co createIndex:@"name"];
    
    for (NSInteger index = 0; index < 100; index++) {
        [co insert:@{@"number": [NSNumber numberWithInt:arc4random() % 10],
         @"name": @"Kelp"}];
        [co insert:@{@"name": @"cc"}];
    }
    
    NSNumber *previous = nil;
    NSArray *documents = [[[[[co where:@"number" greaterEqual:@6] union:@"number" equal:@5] and:@"name" equal:@"kelp"] orderBy:@"number"] fetch];
    STAssertEquals(documents.count > 0, true, nil);
    for (NSMutableDictionary *doc in documents) {
        if ([doc objectForKey:@"number"] == nil || [[doc objectForKey:@"number"] isKindOfClass:NSNull.class]) { continue; }
        
        if (previous) {
            if ([@4 compare:[doc objectForKey:@"number"]] == NSOrderedDescending) {
                STFail([NSString stringWithFormat:@"4 --> %@", [doc objectForKey:@"number"]]);
            }
            if ([previous compare:[doc objectForKey:@"number"]] == NSOrderedDescending) {
                STFail([NSString stringWithFormat:@"%@ --> %@", previous, [doc objectForKey:@"number"]]);
            }
        }
        previous = [doc objectForKey:@"number"];
    }
}

- (void)test10Multithread
{
    NyaruDB *db = [NyaruDB instance];
    NyaruCollection *co = [db collectionForName:@"10"];
    [co removeAll];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSUInteger index = 0; index < 500; index++) {
            [co insert:@{@"number": [NSNumber numberWithInt:arc4random() % 100], @"update": [NSDate date]}];
        }
    });
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSUInteger index = 0; index < 500; index++) {
            [co insert:@{@"number": [NSNumber numberWithInt:arc4random() % 100], @"update": [NSDate date]}];
        }
    });
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSUInteger index = 0; index < 10; index++) {
            if (co.all.fetch) { }
        }
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#if IOS
    dispatch_release(group);
#endif
    STAssertEquals(co.all.count, 1000U, nil);
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
    if (collection.all.fetch) { };
    NSLog(@"------------------------------------------------");
    NSLog(@"fetch 1k data cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
    
    timer = [NSDate date];
    for (NSInteger index = 0; index < 10; index++) {
        if ([collection where:@"group" equal:[NSNumber numberWithInt:arc4random() % 512]].fetch) { }
    }
    NSLog(@"------------------------------------------------");
    NSLog(@"search documents in 1k data for 10 times cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
}


@end
