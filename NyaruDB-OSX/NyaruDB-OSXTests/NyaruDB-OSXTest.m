//
//  NyaruDB-OSXTest.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2013/03/27.
//
//

#import "NyaruDB-OSXTest.h"
#import "NyaruDB.h"

#define PATH @"/tmp/NyaruDB"


@implementation NyaruDB_OSXTest

- (void)testInit
{
    NyaruDB *db = [[NyaruDB alloc] initWithPath:PATH];
    NyaruCollection *co = [db collection:@"init"];
    [co removeAll];
    
    [db close];
}

- (void)test07ReadWrite
{
    NyaruDB *db = [[NyaruDB alloc] initWithPath:PATH];
    [db removeCollection:@"07"];
    NyaruCollection *co = [db collection:@"07"];
    
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
    [co waiteForWriting];
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
    
    [db close];
}

@end