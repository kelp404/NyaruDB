//
//  NyaruQueryTest.m
//  NyaruDB
//
//  Created by Kelp on 2013/03/25.
//
//

#import "NyaruQueryTest.h"
#import "NyaruQuery.h"
#import "NyaruQueryCell.h"


@implementation NyaruQueryTest

- (void)testQueryEqual
{
    NyaruQuery *query = [NyaruQuery new];
    query = [[query and:@"key" equal:@"a"] union:@"key" equal:@"b"];
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] schemaName], @"key", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:0] operation], NyaruQueryIntersection | NyaruQueryEqual, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] value], @"a", nil);
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] schemaName], @"key", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:1] operation], NyaruQueryUnion | NyaruQueryEqual, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] value], @"b", nil);
}

- (void)testQueryNotEqual
{
    NyaruQuery *query = [NyaruQuery new];
    query = [[query and:@"name" notEqual:@"a"] union:@"group" notEqual:@10];
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] schemaName], @"name", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:0] operation], NyaruQueryIntersection | NyaruQueryUnequal, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] value], @"a", nil);
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] schemaName], @"group", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:1] operation], NyaruQueryUnion | NyaruQueryUnequal, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] value], @10, nil);
}

- (void)testQueryGreater
{
    NyaruQuery *query = [NyaruQuery new];
    query = [[query and:@"number" greater:@10] union:@"group" greaterEqual:@12];
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] schemaName], @"number", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:0] operation], NyaruQueryIntersection | NyaruQueryGreater, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] value], @10, nil);
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] schemaName], @"group", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:1] operation], NyaruQueryUnion | NyaruQueryGreaterEqual, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] value], @12, nil);
}

- (void)testQueryLess
{
    NyaruQuery *query = [NyaruQuery new];
    query = [[query and:@"number" less:@10] union:@"group" lessEqual:@12];
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] schemaName], @"number", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:0] operation], NyaruQueryIntersection | NyaruQueryLess, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:0] value], @10, nil);
    
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] schemaName], @"group", nil);
    STAssertEquals([(NyaruQueryCell *)[query.queries objectAtIndex:1] operation], NyaruQueryUnion | NyaruQueryLessEqual, nil);
    STAssertEqualObjects([(NyaruQueryCell *)[query.queries objectAtIndex:1] value], @12, nil);
}

@end
