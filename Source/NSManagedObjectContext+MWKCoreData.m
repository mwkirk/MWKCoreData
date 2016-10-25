//
//  NSManagedObjectContext+MWKCoreData.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/15/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//

#import "NSManagedObjectContext+MWKCoreData.h"
#import "CoreDataManager.h"

static NSString* const kMWKCoreDataMOCName = @"MWKCoreDataMOCName";
static MWKCoreDataContextSaveErrorHandler __defaultSaveErrorHandler;

@implementation NSManagedObjectContext (MWKCoreData)


- (void)setName:(NSString*)aName
{
    self.userInfo[kMWKCoreDataMOCName] = [aName copy];
}


- (NSString*)name
{
    return [self.userInfo[kMWKCoreDataMOCName] copy];
}


+ (NSManagedObjectContext*)defaultContext
{
    return [CoreDataManager sharedInstance].defaultContext;
}


+ (NSManagedObjectContext*)mainQueueContext
{
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    ctx.persistentStoreCoordinator = [CoreDataManager sharedInstance].persistentStoreCoordinator;
    return ctx;
}


+ (NSManagedObjectContext*)privateQueueContext
{
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    ctx.persistentStoreCoordinator = [CoreDataManager sharedInstance].persistentStoreCoordinator;
    return ctx;
}


+ (NSManagedObjectContext*)mainQueueContextWithParent:(NSManagedObjectContext*)aParentCtx
{
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    ctx.parentContext = aParentCtx;
    return ctx;
}


+ (NSManagedObjectContext*)privateQueueContextWithParent:(NSManagedObjectContext*)aParentCtx
{
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    ctx.parentContext = aParentCtx;
    return ctx;
}

#pragma mark - Temporary IDs

- (NSSet*)objectsWithTemporaryIDs
{
    NSSet *objects = [self registeredObjects];
    NSSet *tmpIdObjects = [objects objectsPassingTest:^BOOL(NSManagedObject *aObject, BOOL *aStop) {
        return (aObject.objectID.isTemporaryID);
    }];
    
    return tmpIdObjects;
}

#pragma mark - Saving

+ (void)setSaveDefaultErrorHandler:(MWKCoreDataContextSaveErrorHandler)aErrorHandler
{
    __defaultSaveErrorHandler = [aErrorHandler copy];
}


- (BOOL)save
{
    if (!self.hasChanges) return YES;
    
#if DEBUG
    // For debug builds, guard against the evil of child contexts and temporary object IDs
    if (self.parentContext) {
        for (NSManagedObject *obj in self.registeredObjects) {
            if (obj.objectID.isTemporaryID) {
                [NSException raise:NSGenericException format:@"You should probably never save a child context with objects that have temporary object IDs; it leads to pain and misery. Call -[NSManagedObjectContext obtainPermanentIDsForObjects:error:] prior to saving the child context. Object with temporary ID: %@", obj];
            }
        }
    }
#endif
    
    NSError *error = nil;
    BOOL status = [self save:&error];
    
    if (error || !status) {
        if (__defaultSaveErrorHandler) {
            __defaultSaveErrorHandler(self, error);
        }
        else {
            // If no error handler set, then we raise an exception
            NSString *ctxName = (self.name) ? [NSString stringWithFormat:@", %@", self.name] : @"";
            [NSException raise:NSGenericException format:@"Unresolved save error for NSMangedObjectContext (%p%@): %@", self, ctxName, error];
        }
    }
    
    return status;
}


- (BOOL)saveAfterObtainingPermanentIDsForObjects:(NSArray*)aObjects
{
    NSError *error = nil;
    BOOL status = [self obtainPermanentIDsForObjects:aObjects error:&error];
    
    if (status && !error) {
        status = [self save];
    }
    else if (__defaultSaveErrorHandler) {
        __defaultSaveErrorHandler(self, error);
    }
    else {
        NSString *ctxName = (self.name) ? [NSString stringWithFormat:@", %@", self.name] : @"";
        [NSException raise:NSGenericException format:@"Failed to obtain permanent IDs for managed objects in context (%p%@): %@", self, ctxName, error];
    }
    
    return status;
}


#pragma mark - ContextDidSave Observation

- (void)observeSaveOfContext:(NSManagedObjectContext*)aCtx
{
    [self observeSaveOfContext:aCtx andWaitForMerge:NO];
}


- (void)observeSaveOfContext:(NSManagedObjectContext*)aCtx andWaitForMerge:(BOOL)aWait
{
    if (self == aCtx) return;

    SEL mergeChanges = (aWait) ? @selector(syncMergeChangesFromContextDidSaveNotification:) :
                                 @selector(asyncMergeChangesFromContextDidSaveNotification:);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:mergeChanges
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:aCtx];
}


- (void)stopObservingSaveOfContext:(NSManagedObjectContext*)aCtx
{
    if (self == aCtx) return;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:aCtx];
}

#pragma mark - Private ContextDidSave Observation

- (void)syncMergeChangesFromContextDidSaveNotification:(NSNotification*)aNote
{
    NSManagedObjectContext *savingCtx = [aNote object];
    if (self == savingCtx) return;
    
    [self performBlockAndWait:^{
        [self mergeChangesFromContextDidSaveNotification:aNote];
    }];
}


- (void)asyncMergeChangesFromContextDidSaveNotification:(NSNotification*)aNote
{
    NSManagedObjectContext *savingCtx = [aNote object];
    if (self == savingCtx) return;
    
    [self performBlock:^{
        [self mergeChangesFromContextDidSaveNotification:aNote];
    }];
}

#pragma mark - ContextObjectsDidChange Observation

- (void)observeObjectChangesInParentContext
{
    if (!self.parentContext) return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshChildContextFromParentObjectsDidChangeNotification:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:self.parentContext];
}


- (void)stopObservingObjectChangesInParentContext
{
    if (!self.parentContext) return;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextObjectsDidChangeNotification
                                                  object:self.parentContext];
}


#pragma mark - Private ContextObjectsDidChange Observation

- (void)refreshChildContextFromParentObjectsDidChangeNotification:(NSNotification*)aNote
{
    if (aNote.object != self.parentContext) return;
    
    // Get objectIds of objects that changed in the parent context
    NSMutableSet *objectIds = [NSMutableSet new];
    
    [self.parentContext performBlockAndWait:^{
        NSDictionary *userInfo = aNote.userInfo;
        NSArray *keys = @[NSUpdatedObjectsKey, NSInsertedObjectsKey, NSDeletedObjectsKey];
        
        for (NSString *key in keys) {
            for (NSManagedObject *obj in userInfo[key]) {
                [objectIds addObject:obj.objectID];
            }
        }
    }];
    
    // Refresh changed objects that are registered in the child context
    [self performBlockAndWait:^{
        for (NSManagedObjectID *objectId in objectIds) {
            NSManagedObject *obj = [self objectRegisteredForID:objectId];
            if (obj) [self refreshObject:obj mergeChanges:YES];
        }
    }];
}

@end
