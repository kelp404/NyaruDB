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
    NyaruCollection *co = [db collectionForName:@"init"];
    [co removeAll];
    
    [db close];
}

@end