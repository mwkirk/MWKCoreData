//
//  NSManagedObject+MWKCoreData.h
//  MWKCoreData
//
//  Created by Mark Kirk on 6/15/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//
// Portions of this software are based upon and inspired by ObjectiveRecord
// https://github.com/supermarin/ObjectiveRecord by Marin Usalj <http://supermar.in>
// The following notice is included per ObjectiveRecord's MIT License:
//
// Copyright (c) 2014 Marin Usalj <http://supermar.in>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import <CoreData/CoreData.h>

@interface NSManagedObject (MWKCoreData)

#pragma mark - Default Context

- (BOOL)save;
- (void)delete;
+ (void)deleteAll;

/**
 *  Called by the +[NSManagedObject create] and +[NSManagedObject createInContext:] class constructors.
 *  Override in a managed object subclass to set default values or create related objects rather than 
 *  using -[NSManagedObject awakeFromInsert] (which is not useful for nested contexts, see below). 
 *  Your implementation should call [super awakeFromCreate].
 *
 *  When using nested (i.e. parent/child) contexts, -[NSManagedObject awakeFromInsert] is essentially
 *  broken – or at least its behavior unexpected. The documentation states "this method is invoked
 *  only once in the object's lifetime". If an object is created in a child context, -[awakeFromInsert]
 *  is called (first time). When the child context saves, the object is inserted into the parent context
 *  and -[awakeFromInsert] is called again (second time). These are, in fact, two different objects, so
 *  the documentation is correct in a literal reading. However, this behavior is almost never what the
 *  programmer wants or expects.
 *
 *  WARNING: Do not use this method to perform actions that truly must be performed in each context
 *  (e.g. setting up KVO, initializing non-persistent properties, etc.). Use -[awakeFromInsert] and/or
 *  [awakeFromFetch].
 */
- (void)awakeFromCreate;

+ (instancetype)create;

+ (NSArray*)all;
+ (NSArray*)allWithOrder:(id)order;
+ (NSArray*)where:(id)condition, ...;
+ (NSArray*)where:(id)condition order:(id)order;
+ (NSArray*)where:(id)condition limit:(NSNumber*)limit;
+ (NSArray*)where:(id)condition order:(id)order limit:(NSNumber*)limit;

+ (NSUInteger)count;
+ (NSUInteger)countWhere:(id)condition, ...;

#pragma mark - Custom Context

+ (instancetype)createInContext:(NSManagedObjectContext*)context;

+ (void)deleteAllInContext:(NSManagedObjectContext*)context;

+ (NSArray*)allInContext:(NSManagedObjectContext*)context;
+ (NSArray*)allInContext:(NSManagedObjectContext*)context order:(id)order;
+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context;
+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context order:(id)order;
+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context limit:(NSNumber*)limit;
+ (NSArray*)where:(id)condition inContext:(NSManagedObjectContext*)context order:(id)order limit:(NSNumber*)limit;

+ (NSUInteger)countInContext:(NSManagedObjectContext*)context;
+ (NSUInteger)countWhere:(id)condition inContext:(NSManagedObjectContext*)context;

#pragma mark - Naming

+ (NSString*)entityName;

@end
