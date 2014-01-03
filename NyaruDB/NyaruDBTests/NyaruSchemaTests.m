//
//  NyaruSchemaTests.m
//  NyaruDB
//
//  Created by Kelp on 2014/01/02.
//
//

#import <XCTest/XCTest.h>
#import "NyaruSchema.h"

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

@end
