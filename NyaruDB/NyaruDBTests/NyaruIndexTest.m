//
//  NyaruIndexTest.m
//  NyaruDB
//
//  Created by Kelp on 2013/03/22.
//
//

#import "NyaruIndexTest.h"
#import "NyaruIndex.h"


@implementation NyaruIndexTest

- (void)testNyaruIndex
{
    NyaruIndex *index = [[NyaruIndex alloc] initWithIndexValue:@"10" key:@"AAA"];
    [index.keySet addObject:@"AAB"];
    
    STAssertEqualObjects(index.value, @"10", nil);
    STAssertTrue([index.keySet intersectsSet:[NSSet setWithObject:@"AAA"]], nil);
    STAssertTrue([index.keySet intersectsSet:[NSSet setWithObject:@"AAB"]], nil);
    STAssertFalse([index.keySet intersectsSet:[NSSet setWithObject:@"AAC"]], nil);
}

@end
