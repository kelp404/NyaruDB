//
//  NyaruQueryTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/03.
//
//

#import <XCTest/XCTest.h>
#import "NyaruQuery.h"
#import "NyaruCollection.h"


@interface NyaruQueryTests : XCTestCase {
    NyaruQuery *_nq;
}

@end



@implementation NyaruQueryTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
    
    _nq = [NyaruQuery new];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}


#pragma mark Init
- (void)testInit
{
    XCTAssertNotNil(_nq, @"");
}

- (void)testInitWithCollection
{
    NyaruCollection *collection = [NyaruCollection new];
    NyaruQuery *nq = [[NyaruQuery alloc] initWithCollection:collection];
    XCTAssertEqual(nq.collection, collection, @"");
}



@end
