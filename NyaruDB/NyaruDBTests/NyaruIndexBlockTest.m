//
//  NyaruIndexBlockTest.m
//  NyaruDB
//
//  Created by Kelp on 2013/03/22.
//
//

#import "NyaruIndexBlockTest.h"
#import "NyaruIndexBlock.h"


@implementation NyaruIndexBlockTest

- (void)testNyaruIndexBlockTest
{
    NyaruIndexBlock *indexBlock = [NyaruIndexBlock indexBlockWithOffset:101U andLength:30U];
    STAssertNotNil(indexBlock, nil);
    STAssertEquals(indexBlock.indexOffset, 101U, nil);
    STAssertEquals(indexBlock.blockLength, 30U, nil);
}

@end
