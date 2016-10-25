//
//  CoreDataManager.h
//  MWKCoreData
//
//  Created by Mark Kirk on 6/15/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "MigrationManager.h"

/**
 *  Block called when migration completes.
 *
 *  The backup URL may be nil, meaning the migration never progressed far enough for the backup
 *  to be performed, and the store should still be intact in its original location.
 *
 *  It not nil, the backup URL references a backup of the original store in the temp directory.
 *  The handler can decide what action to take based upon the migration's success. Typically,
 *  if the migration failed, you'll want to move it back into its original location, and if
 *  the migration succeeded, you'll remove it (though it should eventually be removed by the OS
 *  since it's in the temp directory). However, there could be reasons after a successful
 *  migration (e.g. testing) that you would move the backup out of the temp directory and save it.
 *
 *  If you provide a completion handler, you must call [UIApplication endBackgroundTask:] with the
 *  background task ID.
 *
 *  @param aSuccess                   Indicates success or failure of migration.
 *  @param aError                     Error, if any.
 *  @param aOriginalSrcStoreBackupURL URL for backup of the original, pre-migration store. May be nil.
 *  @param aBgTask                    Background task ID for the migration
 */
typedef void (^MWKCoreDataMigrationCompletionHandler)(BOOL aSuccess, NSError *aError, NSURL *aOriginalSrcStoreBackupURL, UIBackgroundTaskIdentifier aBgTask);

@interface CoreDataManager : NSObject

@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly) NSDictionary *persistentStoreOptions;
@property (nonatomic, readonly, copy) NSString *persistentStoreType;
@property (nonatomic, readonly) NSURL *persistentStoreURL;
@property (nonatomic, readonly) NSPersistentStore *persistentStore;
@property (nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readonly) NSBundle *bundle;

/**
 *  Whether the manager's persistent store requires migration to the current model version. 
 *  The check is performed without setting up the entire stack.
 */
@property (nonatomic, readonly) BOOL requiresMigration;

/**
 *  Whether a lightweight migration is possible. Note that this returns YES
 *  even when no migration is required. It simply means that a suitable
 *  NSMappingModel can be inferred by the Core Data framework.
 *
 *  @see requiresMigration
 */
@property (nonatomic, readonly) BOOL lightweightMigrationPossible;


/**
 *  Creates a singleton manager with the default configuration:
 *  an auto-migrating SQLite store named <CFBundleIdentifier>.sqlite
 *  in the app's documents directory.
 *
 *  @return CoreDataManager singleton
 */
+ (CoreDataManager*)sharedInstance;


/**
 *  Creates a CoreDataManager with the default configuration.
 *
 *  @return CoreDataManager instance.
 */
- (instancetype)init;


/**
 *  Initializes a CoreDataManager with a custom configuration. 
 *  Passing nil for any parameter will cause the default to be used for that parameter.
 *
 *  @param aModel        Managed obect model
 *  @param aStoreOptions Persistent store options
 *  @param aStoreType    Persistent store type
 *  @param aStoreURL     URL for persistent store
 *  @param aBundle       Bundle searched when using default model and store (nil for mainBundle)
 *
 *  @return Newly initialized CoreDataManager instance.
 */
- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel*)aModel
                    persistentStoreOptions:(NSDictionary*)aStoreOptions
                       persistentStoreType:(NSString*)aStoreType
                         persisentStoreURL:(NSURL*)aStoreURL
                                    bundle:(NSBundle*)aBundle NS_DESIGNATED_INITIALIZER;


/**
 *  Set up the Core Data stack for use other than migration.
 *
 *  Creates the NSPersistentStoreCoordinator and adds the NSPersistentStore. 
 *  Deferring this step to here rather than the intitializer allows checking for
 *  and performing any needed migrations.
 *
 *  @param aError Error reported if there was a problem adding the persistent store
 *
 *  @return YES if the stack successfully initialized (or already is)
 */
- (BOOL)initializeStack:(NSError**)aError;


/**
 *  Reset the persisistent store by resetting and releasing all managed object contexts held
 *  by the CoreDataManager, removing the store files, then creating a new store. This is primarily
 *  useful for testing and development.
 */
- (void)resetPersistentStore;


#pragma mark - Managed Object Contexts

/**
 *  Convenience accessor for a managed object context designated as the default.
 *  This context will be nil until you set it. It can be any type of context you create (main, private)
 */
@property (nonatomic, strong) NSManagedObjectContext *defaultContext;

/**
 *  Store a managed object context in the manager with a key used for later retrieval.
 *
 *  Note that it's usually best to create contexts and dispose of them as
 *  soon as they're no longer needed. However, there are cases where you may need
 *  to store/retrieve long-lived contexts (such as a default context). Access to the
 *  context instances is thread-safe, but you still must always use the the contexts
 *  correctly for their concurrency type (main or private). There is no magic!
 *
 *  @param aCtx A managed object context.
 *  @param aKey A key used to identify the context.
 */
- (void)setContext:(NSManagedObjectContext*)aCtx forKey:(id<NSCopying>)aKey;


/**
 *  Retrieve a managed object context for the given key.
 *
 *  @param aKey A key used to identify the context.
 *
 *  @return A managed object context.
 */
- (NSManagedObjectContext*)contextForKey:(id<NSCopying>)aKey;


/**
 *  Removes managed object context with key from the manager. If no other references are held
 *  to the context, it may be deallocated.
 *
 *  @param aKey A key used to identify the context.
 */
- (void)removeContextForKey:(id<NSCopying>)aKey;


#pragma mark - Migration

/**
 *  Perform a progressive migration.
 *
 *  The progress and completion handlers are encouraged, but not required.
 *
 *  A background task is started so that the migration may proceed in the background (up to
 *  the limits imposed by the OS). If no completion handler is provided, the method will
 *  end the background task on your behalf when the migration finishes.
 *
 *  @param aProgess    Block called periodically with float progress by migration manager
 *  @param aCompletion Block called upon migration completion. 
 *
 *  @see MWKCoreDataMigrationCompletionHandler
 */
- (void)migrateWithProgress:(MWKCoreDataMigrationProgressHandler)aProgess
                 completion:(MWKCoreDataMigrationCompletionHandler)aCompletion;



@end
