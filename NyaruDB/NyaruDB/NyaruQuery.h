//
//  NyaruQuery.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import <Foundation/Foundation.h>

@class NyaruCollection;


@interface NyaruQuery : NSObject {
    
}

#pragma mark - Properties
@property (strong, nonatomic, readonly) NyaruCollection *collection;
@property (strong, nonatomic) NSMutableArray *queries;

/**
 Get NyaruQuery instance.
 */
- (id)initWithCollection:(NyaruCollection *)collection;

@end



@interface NyaruQuery (NyaruQueryIn)
#pragma mark - Intersection
- (NyaruQuery *)and:(NSString *)indexName equalTo:(id)value;
- (NyaruQuery *)and:(NSString *)indexName notEqualTo:(id)value;
- (NyaruQuery *)and:(NSString *)indexName lessThan:(id)value;
- (NyaruQuery *)and:(NSString *)indexName lessEqualThan:(id)value;
- (NyaruQuery *)and:(NSString *)indexName greaterThan:(id)value;
- (NyaruQuery *)and:(NSString *)indexName greaterEqualThan:(id)value;
- (NyaruQuery *)and:(NSString *)indexName likeTo:(NSString *)value;

#pragma mark - Union
- (NyaruQuery *)unionAll;
- (NyaruQuery *)union:(NSString *)indexName equalTo:(id)value;
- (NyaruQuery *)union:(NSString *)indexName notEqualTo:(id)value;
- (NyaruQuery *)union:(NSString *)indexName lessThan:(id)value;
- (NyaruQuery *)union:(NSString *)indexName lessEqualThan:(id)value;
- (NyaruQuery *)union:(NSString *)indexName greaterThan:(id)value;
- (NyaruQuery *)union:(NSString *)indexName greaterEqualThan:(id)value;
- (NyaruQuery *)union:(NSString *)indexName likeTo:(NSString *)value;

#pragma mark - Order By
- (NyaruQuery *)orderBy:(NSString *)indexName;
- (NyaruQuery *)orderByDESC:(NSString *)indexName;

#pragma mark - Count
- (NSUInteger)count;

#pragma mark - Fetch
- (NSArray *)fetch;
- (NSArray *)fetch:(NSUInteger)limit;
- (NSArray *)fetch:(NSUInteger)limit skip:(NSUInteger)skip;

#pragma mark - Remove
- (void)remove;

@end
