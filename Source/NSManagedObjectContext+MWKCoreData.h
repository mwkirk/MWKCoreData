//
//  NSManagedObjectContext+MWKCoreData.h
//  MWKCoreData
//
//  Created by Mark Kirk on 6/15/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//

#import <CoreData/CoreData.h>

typedef void(^MWKCoreDataContextSaveErrorHandler)(NSManagedObjectContext *aCtx, NSError *aError);

@interface NSManagedObjectContext (MWKCoreData)

@property (nonatomic, copy) NSString *name;


/**
 *  Convenience method for retrieving the default context held by the shared CoreDataManager
 *  (it will be nil if not set).
 *
 *  @return A managed object context.
 */
+ (NSManagedObjectContext*)defaultContext;

/**
 *  Creates a new main queue context with the shared CoreDataManager's persistent store coordinator.
 *  If the coordinator is nil, an exception will be thrown.
 *
 *  @return New main queue context.
 */
+ (NSManagedObjectContext*)mainQueueContext;

/**
 *  Creates a new private queue context with the shared CoreDataManager's persistent store coordinator.
 *  If the coordinator is nil, an exception will be thrown.
 *
 *  @return New private queue context.
 */
+ (NSManagedObjectContext*)privateQueueContext;

/**
 *  Creates a new main queue context and set its parent to the given context.
 *
 *  @param aParentCtx A parent context.
 *
 *  @return New main queue context with given parent.
 */
+ (NSManagedObjectContext*)mainQueueContextWithParent:(NSManagedObjectContext*)aParentCtx;

/**
 *  Creates a new private queue context and set its parent to the given context.
 *
 *  @param aParentCtx A parent context.
 *
 *  @return New private queue context with given parent.
 */
+ (NSManagedObjectContext*)privateQueueContextWithParent:(NSManagedObjectContext*)aParentCtx;

#pragma mark - Temporary IDs

/**
 *  Gets the objects registered with the context that have temporary object IDs.
 *
 *  @return Set of objects having temporary IDs.
 */
- (NSSet*)objectsWithTemporaryIDs;

#pragma mark - Saving

/**
 *  Sets a default handler that will be called if there's an error when a context saves.
 *  Useful for logging errors, handling recoverable errors, etc.
 *
 *  @param aErrorHandler Error handler block.
 */
+ (void)setSaveDefaultErrorHandler:(MWKCoreDataContextSaveErrorHandler)aErrorHandler;

/**
 *  Saves the context and calls the default error handler if the save fails. If a default save 
 *  error handler is not set, an exception will be raised on any save error.
 *
 *  In debug builds, if the receiver is a child context, also checks that all registered
 *  managed objects have permanent object IDs before saving. An exception is thrown if any
 *  have temporary IDs.
 *
 *  @return YES if the save succeeds, otherwise NO.
 */
- (BOOL)save;

/**
 *  Useful when saving child contexts.
 *
 *  First attempts to obtain permanent IDs for the given objects. If successful, then
 *  -save is called. 
 *
 *  If the receiver fails to obtain permanent IDs, the default save error handler is called
 *  if set. If a default save error handler is not set, an exception is raised.
 *
 *  @return YES if the save succeeds, otherwise NO.
 */
- (BOOL)saveAfterObtainingPermanentIDsForObjects:(NSArray*)aObjects;

#pragma mark - ContextDidSave Observation

/**
 *  Observe NSManagedObjectContextDidSaveNotifications for the given context and merge changes
 *  asynchronously (i.e. within a -performBlock call) into this context.
 *
 *  @param aCtx The context to observe.
 */
- (void)observeSaveOfContext:(NSManagedObjectContext*)aCtx;

/**
 *  Observe NSManagedObjectContextDidSaveNotifications for the given context and merge changes
 *  either synchronously (i.e. within a -performBlockAndWait call) or asynchronously (peformBlock)
 *  into this context.
 *
 *  @param aCtx  The context to observe.
 *  @param aWait YES to merge changes synchronously, NO to merge changes asynchronously.
 */
- (void)observeSaveOfContext:(NSManagedObjectContext*)aCtx andWaitForMerge:(BOOL)aWait;

/**
 *  Stop observing NSManagedObjectContextDidSaveNotifications for the given context.
 *
 *  @param aCtx The context to stop observing.
 */
- (void)stopObservingSaveOfContext:(NSManagedObjectContext*)aCtx;

#pragma mark - ContextObjectsDidChange Observation

/**
 *  Observe the parent context's NSManagedObjectContextObjectsDidChangeNotifications and refresh
 *  the objects that are registered in this (child) context. Also observing its parent's
 *  NSManagedObjectContextDidSaveNotifications provides the means to keep a child "in sync" with
 *  its parent.
 */
- (void)observeObjectChangesInParentContext;

/**
 *  Stop observing the parent context's NSManagedObjectContextObjectsDidChangeNotifications.
 */
- (void)stopObservingObjectChangesInParentContext;

@end
