//
//  NyaruSchemaTests.m
//  NyaruDB-OSX
//
//  Created by Kelp on 2014/02/13.
//
//

#import <XCTest/XCTest.h>
#import "NyaruSchema.h"
#import "NyaruKey.h"
#import "NyaruIndex.h"


@interface NyaruSchemaTests : XCTestCase {
    NyaruSchema *_schema;
}

@end



@implementation NyaruSchemaTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark Schema.unique
- (void)testUniqueOfSchemaAsKey
{
    _schema = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0 nextOffset:0];
    XCTAssertTrue(_schema.unique, @"");
    
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertFalse(_schema.unique, @"");
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
    _schema = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0 nextOffset:0];
    NyaruKey *nkA = [[NyaruKey alloc] initWithIndexOffset:0 documentOffset:0 documentLength:0 blockLength:0];
    NyaruKey *nkB = [[NyaruKey alloc] initWithIndexOffset:0 documentOffset:0 documentLength:0 blockLength:0];
    [_schema pushNyaruKey:@"a" nyaruKey:nkA];
    [_schema pushNyaruKey:@"b" nyaruKey:nkB];
    NSDictionary *assert = @{@"a": nkA, @"b": nkB};
    XCTAssertEqualObjects(_schema.allKeys, assert, @"");
}


#pragma mark Indexes of the Schema
- (void)testAllNilIndexes
{
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqualObjects(_schema.allNilIndexes, @[], @"");
    [_schema pushNyaruIndex:@"000-000" value:nil];
    XCTAssertEqualObjects(_schema.allNilIndexes, @[@"000-000"], @"");
    [_schema pushNyaruIndex:@"000-001" value:[NSNull null]];
    NSArray *assert = @[@"000-000", @"000-001"];
    XCTAssertEqualObjects(_schema.allNilIndexes, assert, @"");
}

- (void)testAllNotNilIndexes
{
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqualObjects(_schema.allNilIndexes, @[], @"");
    
    [_schema pushNyaruIndex:@"000-000" value:@"0"];
    NyaruIndex *assert = [[NyaruIndex alloc] initWithIndexValue:@"0" key:@"000-000"];
    XCTAssertEqualObjects([_schema.allNotNilIndexes[0] value], assert.value, @"");
    XCTAssertEqualObjects([_schema.allNotNilIndexes[0] keySet], assert.keySet, @"");
}


#pragma mark Remove
- (void)testRemoveAllKey
{
    _schema = [[NyaruSchema alloc] initWithName:@"key" previousOffser:0 nextOffset:0];
    NyaruKey *nkA = [[NyaruKey alloc] initWithIndexOffset:0 documentOffset:0 documentLength:0 blockLength:0];
    [_schema pushNyaruKey:@"a" nyaruKey:nkA];
    XCTAssertEqual(_schema.allKeys.count, 1UL, @"");
    
    [_schema removeAll];
    XCTAssertEqual(_schema.allKeys.count, 0UL, @"");
}

- (void)testRemoveAllIndex
{
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    [_schema pushNyaruIndex:@"000-000" value:@"0"];
    [_schema pushNyaruIndex:@"000-000" value:nil];
    XCTAssertEqual(_schema.allNotNilIndexes.count, 1UL, @"");
    XCTAssertEqual(_schema.allNilIndexes.count, 1UL, @"");
    
    [_schema removeAll];
    XCTAssertEqual(_schema.allNotNilIndexes.count, 0UL, @"");
    XCTAssertEqual(_schema.allNilIndexes.count, 0UL, @"");
}


#pragma mark Schema.schemaType
- (void)testSchemaTypeString
{
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqual(_schema.schemaType, NyaruSchemaTypeUnknow, @"");
    [_schema pushNyaruIndex:@"000-000" value:@"string"];
    XCTAssertEqual(_schema.schemaType, NyaruSchemaTypeString, @"");
}

- (void)testSchemaTypeNumber
{
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqual(_schema.schemaType, NyaruSchemaTypeUnknow, @"");
    [_schema pushNyaruIndex:@"000-000" value:@1];
    XCTAssertEqual(_schema.schemaType, NyaruSchemaTypeNumber, @"");
}

- (void)testSchemaTypeDate
{
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertEqual(_schema.schemaType, NyaruSchemaTypeUnknow, @"");
    [_schema pushNyaruIndex:@"000-000" value:[NSDate dateWithTimeIntervalSince1970:0]];
    XCTAssertEqual(_schema.schemaType, NyaruSchemaTypeDate, @"");
}

- (void)testSchemaTypeError
{
    _schema = [[NyaruSchema alloc] initWithName:@"name" previousOffser:0 nextOffset:0];
    XCTAssertThrows([_schema pushNyaruIndex:@"000-000" value:@{@"a": @1}], @"");
    XCTAssertThrows([_schema pushNyaruIndex:@"000-000" value:@[@1]], @"");
}

@end
