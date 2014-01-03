//
//  NyaruSchemaTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/02.
//
//

#import <XCTest/XCTest.h>
#import "NyaruSchema.h"
#import "NyaruKey.h"
#import "NyaruIndex.h"


@interface NyaruSchemaTests : XCTestCase {
    NyaruSchema *_ns;
}

@end



@implementation NyaruSchemaTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}


#pragma mark Schema.unique
- (void)testUniqueOfSchemaAsKey
{
    _ns = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0 nextOffset:0];
    XCTAssertTrue(_ns.unique, @"");
    
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertFalse(_ns.unique, @"");
}


#pragma mark CreateSchema
- (void)testCreateSchema
{
    NyaruSchema *schema1 = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0U nextOffset:0U];
    schema1.offsetInFile = 9U;
    
    NyaruSchema *schema2 = [[NyaruSchema alloc] initWithName:@"name" previousOffser:9U nextOffset:0U];
    schema2.offsetInFile = 10U;
    schema1.nextOffsetInFile = 10U;
    
    XCTAssertNotNil(schema1, @"");
    XCTAssertEqualObjects(schema1.name, @"key", @"");
    XCTAssertTrue(schema1.unique, @"");
    XCTAssertEqual(schema1.previousOffsetInFile, 0U, @"");
    XCTAssertEqual(schema1.offsetInFile, 9U, @"");
    XCTAssertEqual(schema1.nextOffsetInFile, 10U, @"");
    XCTAssertEqual(schema1.schemaType, NyaruSchemaTypeString, @"");
    
    XCTAssertNotNil(schema2, @"");
    XCTAssertEqualObjects(schema2.name, @"name", @"");
    XCTAssertFalse(schema2.unique, @"");
    XCTAssertEqual(schema2.previousOffsetInFile, 9U, @"");
    XCTAssertEqual(schema2.offsetInFile, 10U, @"");
    XCTAssertEqual(schema2.nextOffsetInFile, 0U, @"");
    XCTAssertEqual(schema2.schemaType, NyaruSchemaTypeUnknow, @"");
}


#pragma mark SchemaSerializer
- (void)testSerializer
{
    NyaruSchema *schema = [[NyaruSchema alloc] initWithName:@"key" previousOffser:10U nextOffset:30U];
    NSData *data = schema.dataFormate;
    schema = [[NyaruSchema alloc] initWithData:data andOffset:20U];
    
    XCTAssertEqualObjects(schema.name, @"key", @"");
    XCTAssertTrue(schema.unique, @"");
    XCTAssertEqual(schema.previousOffsetInFile, 10U, @"");
    XCTAssertEqual(schema.offsetInFile, 20U, @"");
    XCTAssertEqual(schema.nextOffsetInFile, 30U, @"");
    XCTAssertEqual(schema.schemaType, NyaruSchemaTypeString, @"");
}


#pragma mark Schema.allKeys
- (void)testAllKeys
{
    _ns = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0 nextOffset:0];
    NyaruKey *nkA = [[NyaruKey alloc] initWithIndexOffset:0 documentOffset:0 documentLength:0 blockLength:0];
    NyaruKey *nkB = [[NyaruKey alloc] initWithIndexOffset:0 documentOffset:0 documentLength:0 blockLength:0];
    [_ns pushNyaruKey:@"a" nyaruKey:nkA];
    [_ns pushNyaruKey:@"b" nyaruKey:nkB];
    NSDictionary *assert = @{@"a": nkA, @"b": nkB};
    XCTAssertEqualObjects(_ns.allKeys, assert, @"");
}


#pragma mark Indexes of the Schema
- (void)testAllNilIndexes
{
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqualObjects(_ns.allNilIndexes, @[], @"");
    [_ns pushNyaruIndex:@"000-000" value:nil];
    XCTAssertEqualObjects(_ns.allNilIndexes, @[@"000-000"], @"");
    [_ns pushNyaruIndex:@"000-001" value:[NSNull null]];
    NSArray *assert = @[@"000-000", @"000-001"];
    XCTAssertEqualObjects(_ns.allNilIndexes, assert, @"");
}

- (void)testAllNotNilIndexes
{
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqualObjects(_ns.allNilIndexes, @[], @"");
    
    [_ns pushNyaruIndex:@"000-000" value:@"0"];
    NyaruIndex *assert = [[NyaruIndex alloc] initWithIndexValue:@"0" key:@"000-000"];
    XCTAssertEqualObjects([_ns.allNotNilIndexes[0] value], assert.value, @"");
    XCTAssertEqualObjects([_ns.allNotNilIndexes[0] keySet], assert.keySet, @"");
}


#pragma mark Remove
- (void)testRemoveAllKey
{
    _ns = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0 nextOffset:0];
    NyaruKey *nkA = [[NyaruKey alloc] initWithIndexOffset:0 documentOffset:0 documentLength:0 blockLength:0];
    [_ns pushNyaruKey:@"a" nyaruKey:nkA];
    XCTAssertEqual(_ns.allKeys.count, 1U, @"");
    
    [_ns removeAll];
    XCTAssertEqual(_ns.allKeys.count, 0U, @"");
}

- (void)testRemoveAllIndex
{
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    [_ns pushNyaruIndex:@"000-000" value:@"0"];
    [_ns pushNyaruIndex:@"000-000" value:nil];
    XCTAssertEqual(_ns.allNotNilIndexes.count, 1U, @"");
    XCTAssertEqual(_ns.allNilIndexes.count, 1U, @"");
    
    [_ns removeAll];
    XCTAssertEqual(_ns.allNotNilIndexes.count, 0U, @"");
    XCTAssertEqual(_ns.allNilIndexes.count, 0U, @"");
}


#pragma mark Schema.schemaType
- (void)testSchemaTypeString
{
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqual(_ns.schemaType, NyaruSchemaTypeUnknow, @"");
    [_ns pushNyaruIndex:@"000-000" value:@"string"];
    XCTAssertEqual(_ns.schemaType, NyaruSchemaTypeString, @"");
}

- (void)testSchemaTypeNumber
{
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqual(_ns.schemaType, NyaruSchemaTypeUnknow, @"");
    [_ns pushNyaruIndex:@"000-000" value:@1];
    XCTAssertEqual(_ns.schemaType, NyaruSchemaTypeNumber, @"");
}

- (void)testSchemaTypeDate
{
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqual(_ns.schemaType, NyaruSchemaTypeUnknow, @"");
    [_ns pushNyaruIndex:@"000-000" value:[NSDate dateWithTimeIntervalSince1970:0]];
    XCTAssertEqual(_ns.schemaType, NyaruSchemaTypeDate, @"");
}

- (void)testSchemaTypeError
{
    _ns = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertThrows([_ns pushNyaruIndex:@"000-000" value:@{@"a": @1}], @"");
    XCTAssertThrows([_ns pushNyaruIndex:@"000-000" value:@[@1]], @"");
}

@end
