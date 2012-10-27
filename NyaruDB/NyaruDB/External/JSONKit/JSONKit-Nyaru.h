//
//  JSONKit.h
//  http://github.com/johnezang/JSONKit
//  Dual licensed under either the terms of the BSD License, or alternatively
//  under the terms of the Apache License, Version 2.0, as specified below.
//
/*
 JSONKit Mode NyaruDB
*/
/*
 Copyright (c) 2011, John Engelhart
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of the Zang Industries nor the names of its
 contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 Copyright 2011 John Engelhart
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include <TargetConditionals.h>
#include <AvailabilityMacros.h>

#ifdef    __OBJC__
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>
#endif // __OBJC__
 
#ifdef __cplusplus
extern "C" {
#endif
  

// For Mac OS X < 10.5.
#ifndef   NSINTEGER_DEFINED
#define   NSINTEGER_DEFINED
#if       defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
typedef long           NSInteger;
typedef unsigned long  NSUInteger;
#define NSIntegerMin   LONG_MIN
#define NSIntegerMax   LONG_MAX
#define NSUIntegerMax  ULONG_MAX
#else  // defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
typedef int            NSInteger;
typedef unsigned int   NSUInteger;
#define NSIntegerMin   INT_MIN
#define NSIntegerMax   INT_MAX
#define NSUIntegerMax  UINT_MAX
#endif // defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
#endif // NSINTEGER_DEFINED


#ifndef _JSONKIT_H_
#define _JSONKIT_H_

#if defined(__GNUC__) && (__GNUC__ >= 4) && defined(__APPLE_CC__) && (__APPLE_CC__ >= 5465)
#define JKN_DEPRECATED_ATTRIBUTE __attribute__((deprecated))
#else
#define JKN_DEPRECATED_ATTRIBUTE
#endif
  
#define JSONKIT_VERSION_MAJOR 1
#define JSONKIT_VERSION_MINOR 4

typedef NSUInteger JKNFlags;

/*
  JKNParseOptionComments        : Allow C style // and /_* ... *_/ (without a _, obviously) comments in JSON.
  JKNParseOptionUnicodeNewlines : Allow Unicode recommended (?:\r\n|[\n\v\f\r\x85\p{Zl}\p{Zp}]) newlines.
  JKNParseOptionLooseUnicode    : Normally the decoder will stop with an error at any malformed Unicode.
                                 This option allows JSON with malformed Unicode to be parsed without reporting an error.
                                 Any malformed Unicode is replaced with \uFFFD, or "REPLACEMENT CHARACTER".
 */

enum {
  JKNParseOptionNone                     = 0,
  JKNParseOptionStrict                   = 0,
  JKNParseOptionComments                 = (1 << 0),
  JKNParseOptionUnicodeNewlines          = (1 << 1),
  JKNParseOptionLooseUnicode             = (1 << 2),
  JKNParseOptionPermitTextAfterValidJSON = (1 << 3),
  JKNParseOptionValidFlags               = (JKNParseOptionComments | JKNParseOptionUnicodeNewlines | JKNParseOptionLooseUnicode | JKNParseOptionPermitTextAfterValidJSON),
};
typedef JKNFlags JKNParseOptionFlags;

enum {
  JKNSerializeOptionNone                 = 0,
  JKNSerializeOptionPretty               = (1 << 0),
  JKNSerializeOptionEscapeUnicode        = (1 << 1),
  JKNSerializeOptionEscapeForwardSlashes = (1 << 4),
  JKNSerializeOptionValidFlags           = (JKNSerializeOptionPretty | JKNSerializeOptionEscapeUnicode | JKNSerializeOptionEscapeForwardSlashes),
};
typedef JKNFlags JKNSerializeOptionFlags;

#ifdef    __OBJC__

typedef struct JKNParseState JKNParseState; // Opaque internal, private type.

// As a general rule of thumb, if you use a method that doesn't accept a JKNParseOptionFlags argument, it defaults to JKNParseOptionStrict

@interface JSONDecoderN : NSObject {
  JKNParseState *parseState;
}
+ (id)decoder;
+ (id)decoderWithParseOptions:(JKNParseOptionFlags)parseOptionFlags;
- (id)initWithParseOptions:(JKNParseOptionFlags)parseOptionFlags;
- (void)clearCache;

// The parse... methods were deprecated in v1.4 in favor of the v1.4 objectWith... methods.
- (id)parseUTF8String:(const unsigned char *)string length:(size_t)length                         JKN_DEPRECATED_ATTRIBUTE; // Deprecated in JSONKit v1.4.  Use objectWithUTF8String:length:        instead.
- (id)parseUTF8String:(const unsigned char *)string length:(size_t)length error:(NSError **)error JKN_DEPRECATED_ATTRIBUTE; // Deprecated in JSONKit v1.4.  Use objectWithUTF8String:length:error:  instead.
// The NSData MUST be UTF8 encoded JSON.
- (id)parseJSONData:(NSData *)jsonData                                                            JKN_DEPRECATED_ATTRIBUTE; // Deprecated in JSONKit v1.4.  Use objectWithData:                     instead.
- (id)parseJSONData:(NSData *)jsonData error:(NSError **)error                                    JKN_DEPRECATED_ATTRIBUTE; // Deprecated in JSONKit v1.4.  Use objectWithData:error:               instead.

// Methods that return immutable collection objects.
- (id)objectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length;
- (id)objectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length error:(NSError **)error;
// The NSData MUST be UTF8 encoded JSON.
- (id)objectWithData:(NSData *)jsonData;
- (id)objectWithData:(NSData *)jsonData error:(NSError **)error;

// Methods that return mutable collection objects.
- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length;
- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length error:(NSError **)error;
// The NSData MUST be UTF8 encoded JSON.
- (id)mutableObjectWithData:(NSData *)jsonData;
- (id)mutableObjectWithData:(NSData *)jsonData error:(NSError **)error;

@end

////////////
#pragma mark Deserializing methods
////////////

@interface NSData (JSONKitDeserializing)
// The NSData MUST be UTF8 encoded JSON.
- (id)mutableObjectFromJSONDataN;
@end

////////////
#pragma mark Serializing methods
////////////

@interface NSDictionary (JSONKitSerializing)
- (NSData *)JSONDataN;
@end


#endif // __OBJC__

#endif // _JSONKIT_H_

#ifdef __cplusplus
}  // extern "C"
#endif
