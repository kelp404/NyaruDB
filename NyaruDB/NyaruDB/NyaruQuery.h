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
- (NyaruQuery *)and:(NSString *)indexName equal:(id)value;
- (NyaruQuery *)and:(NSString *)indexName notEqual:(id)value;
- (NyaruQuery *)and:(NSString *)indexName less:(id)value;
- (NyaruQuery *)and:(NSString *)indexName lessEqual:(id)value;
- (NyaruQuery *)and:(NSString *)indexName greater:(id)value;
- (NyaruQuery *)and:(NSString *)indexName greaterEqual:(id)value;
- (NyaruQuery *)and:(NSString *)indexName like:(NSString *)value;

#pragma mark - Union
- (NyaruQuery *)unionAll;
- (NyaruQuery *)union:(NSString *)indexName equal:(id)value;
- (NyaruQuery *)union:(NSString *)indexName notEqual:(id)value;
- (NyaruQuery *)union:(NSString *)indexName less:(id)value;
- (NyaruQuery *)union:(NSString *)indexName lessEqual:(id)value;
- (NyaruQuery *)union:(NSString *)indexName greater:(id)value;
- (NyaruQuery *)union:(NSString *)indexName greaterEqual:(id)value;
- (NyaruQuery *)union:(NSString *)indexName like:(NSString *)value;

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
