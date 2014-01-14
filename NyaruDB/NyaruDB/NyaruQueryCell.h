//
//  NyaruQueryCell.h
//  NyaruDB
//
//  Created by Kelp on 2013/02/19.
//
//

#import <Foundation/Foundation.h>


#define QUERY_OPERATION_MASK 0x3F
typedef NS_ENUM(NSUInteger, NyaruQueryOperation) {
    NyaruQueryUnequal = 0U,
    NyaruQueryEqual = 1U,                // suport unique schema
    
    NyaruQueryLess = 2U,
    NyaruQueryLessEqual = 3U,
    
    NyaruQueryGreater = 4U,
    NyaruQueryGreaterEqual = 5U,
    
    // empty 0x10U
    // empty 0x20U
    NyaruQueryLike = 0x30U,               // only for NSString
    
    NyaruQueryIntersection = 0x40U,
    NyaruQueryUnion = 0x00U,
    
    NyaruQueryAll = 0x80U,
    
    NyaruQueryOrderASC = 0x100U,
    NyaruQueryOrderDESC = 0x200U,
};


@interface NyaruQueryCell : NSObject

@property (strong, nonatomic) NSString *schemaName;
@property (nonatomic) NyaruQueryOperation operation;
@property (strong, nonatomic) id value;

@end
