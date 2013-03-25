//
//  NyaruKeyTest.m
//  NyaruDB
//
//  Created by Kelp on 2013/03/22.
//
//

#import "NyaruKeyTest.h"
#import "NyaruKey.h"


@implementation NyaruKeyTest

- (void)testNyaruKey
{
    NyaruKey *key = [[NyaruKey alloc] initWithIndexOffset:10U documentOffset:11U documentLength:12U blockLength:13U];
    
    STAssertEquals(key.indexOffset, 10U, nil);
    STAssertEquals(key.documentOffset, 11U, nil);
    STAssertEquals(key.documentLength, 12U, nil);
    STAssertEquals(key.blockLength, 13U, nil);
}

@end
