//
//  CoreDataManager.m
//  MWKCoreData
//
//  Created by Mark Kirk on 6/15/15.
//  Copyright (c) 2015 com.markwkirk. All rights reserved.
//  MIT License. Please see the included LICENSE file of the
//  software https://github.com/mwkirk/MWKCoreData
//

#import "CoreDataManager.h"
#import "MigrationManager.h"
#import "MWKCoreDataError.h"

static NSString* const kMWKCoreDataDefaultContext = @"__MWKCoreDataDefaultContext__";
static NSString* const kMWKCoreDataMissingModel = @"MWKCoreDataMissingModel";
static NSSearchPathDirectory const kMWKCoreDataPersistentStoreBaseDir = NSApplicationSupportDirectory;
static NSString* const kMWKCoreDataPersistentStoreSubdir = @"CoreDataStore";

@interface CoreDataManager ()

@property (nonatomic, strong, readonly) dispatch_queue_t stackInitQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t contextAccessQueue;
@property (nonatomic, strong, readonly) NSMutableDictionary *contexts;

@end

// @TODO:
// - in memory stores (for testing)

@implementation CoreDataManager

+ (CoreDataManager*)sharedInstance
{
    static CoreDataManager *sharedInstance = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    
    return sharedInstance;
}

#pragma mark - Initializers

// Designated initializer
- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel*)aModel
                    persistentStoreOptions:(NSDictionary*)aStoreOptions
                       persistentStoreType:(NSString*)aStoreType
                         persisentStoreURL:(NSURL*)aStoreURL
                                    bundle:(NSBundle*)aBundle
{
    if (!(self = [super init])) return nil;
    
    // Set the configuration of the stack, but don't fire it up yet
    _bundle = aBundle ?: [NSBundle mainBundle];
    _managedObjectModel = aModel ?: [self defaultManagedObjectModel];
    _persistentStoreOptions = aStoreOptions ?: [self defaultPersistentStoreOptions];
    _persistentStoreType = aStoreType ?: [self defaultPersistentStoreType];
    _persistentStoreURL = aStoreURL ?: [self defaultPersistentStoreURL];
    
    _stackInitQueue = dispatch_queue_create("com.mwkcoredata.stackinitqueue", DISPATCH_QUEUE_SERIAL);
    _contextAccessQueue = dispatch_queue_create("com.mwkcoredata.contextacessqueue", DISPATCH_QUEUE_CONCURRENT);
    _contexts = [NSMutableDictionary new];
    
     return self;
}


- (instancetype)init
{
    self = [self initWithManagedObjectModel:nil
                     persistentStoreOptions:nil
                        persistentStoreType:nil
                          persisentStoreURL:nil
                                     bundle:nil];
    return self;
}


- (BOOL)requiresMigration
{
    // Ignore the error for now. If the store doesn't yet exist, we'll get an error, but that's OK
    // and the correct NO will be returned. If the store should exist but doesn't we've got bigger problems.
    // @Note: This method is deprecated, but don't see a good alternative
    NSDictionary *srcMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.persistentStoreType
                                                                                           URL:self.persistentStoreURL
                                                                                         error:nil];
    BOOL requiresMigration = NO;
    
    if (srcMetadata) {
        NSManagedObjectModel *destModel = self.managedObjectModel;
        requiresMigration = ![destModel isConfiguration:nil compatibleWithStoreMetadata:srcMetadata];
    }
    
    return requiresMigration;
}


- (BOOL)lightweightMigrationPossible
{
    BOOL lightweight = NO;
    
    NSDictionary *srcMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.persistentStoreType
                                                                                           URL:self.persistentStoreURL
                                                                                         error:nil];
    if (srcMetadata) {
        NSManagedObjectModel *srcModel = [NSManagedObjectModel mergedModelFromBundles:@[self.bundle] forStoreMetadata:srcMetadata];
        
        if (srcModel) {
            NSManagedObjectModel *destModel = self.managedObjectModel;
            NSMappingModel *mappingModel = [NSMappingModel inferredMappingModelForSourceModel:srcModel destinationModel:destModel error:nil];
            lightweight = (mappingModel != nil);
        }
    }
    
    return lightweight;
}


- (BOOL)initializeStack:(NSError**)aError
{
    __block BOOL status = YES;
    __block NSError *error = nil;
    
    // @Note: This won't protect someone who tries to read _persistentStoreCoordinator elsewhere since
    //        the read accessor doesn't use the queue currently.
    dispatch_sync(self.stackInitQueue, ^{
        // We'll only do this one time...
        if (!self->_persistentStoreCoordinator) {
            NSManagedObjectModel *model = self.managedObjectModel;
            NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];

            // Create path to store if needed. The default adds subdirs.
            NSFileManager *fm = [NSFileManager defaultManager];
            NSURL *url = [self.persistentStoreURL URLByDeletingLastPathComponent];
            BOOL dirCreated = [fm createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
            
            if (dirCreated) {
                [psc addPersistentStoreWithType:self.persistentStoreType
                                  configuration:nil
                                            URL:self.persistentStoreURL
                                        options:self.persistentStoreOptions
                                          error:&error];
            }

            if (!dirCreated || error) {
                // @TODO: Is there any other error handling we want to do?
                status = NO;
            }
            else {
                self->_persistentStoreCoordinator = psc;
            }
        }
    });
    
    if (error) *aError = error;
    return status;
}


- (void)resetPersistentStore
{
    // This should pull the rug out from anyone that is holding/using any of
    // *these* contexts, but there can still be other contexts out there
    [self resetAndRemoveAllContexts];

    NSPersistentStoreCoordinator *psc = self.persistentStoreCoordinator;
    
    if ([psc removePersistentStore:psc.persistentStores.firstObject error:nil]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *storeUrl = self.persistentStoreURL;
        
        [fm removeItemAtURL:storeUrl error:nil];
        
        if ([_persistentStoreType isEqualToString:NSSQLiteStoreType]) {
            [fm removeItemAtPath:[storeUrl.path stringByAppendingString:@"-wal"] error:nil];
            [fm removeItemAtPath:[storeUrl.path stringByAppendingString:@"-shm"] error:nil];
        }
        
        NSError *error = nil;
        [psc addPersistentStoreWithType:self.persistentStoreType
                          configuration:nil
                                    URL:self.persistentStoreURL
                                options:self.persistentStoreOptions
                                  error:&error];
        if (error) {
            NSLog(@"Failed to add persistent store after reset: %@", error);
        }
    }
}


#pragma mark - Default Configuration
// There private default configuration methods are called by initializers and are order-indendepent
- (NSManagedObjectModel*)defaultManagedObjectModel
{
    NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:@[self.bundle]];
    if (!model) {
        [NSException raise:kMWKCoreDataMissingModel format:@"Managed object model missing"];
    }
    
    return model;
}


- (NSDictionary*)defaultPersistentStoreOptions
{
    return @{NSInferMappingModelAutomaticallyOption : @YES,
             NSPersistentStoreFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication};
}


- (NSString*)defaultPersistentStoreType
{
    return NSSQLiteStoreType;
}


- (NSURL*)defaultPersistentStoreURL
{
    NSDictionary *info = self.bundle.infoDictionary;
    NSString *appName = info[@"CFBundleIdentifier"];
    NSString *storeFilename = [NSString stringWithFormat:@"%@.sqlite", appName];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *baseUrl = [[fm URLsForDirectory:kMWKCoreDataPersistentStoreBaseDir inDomains:NSUserDomainMask] lastObject];
    NSString *subpath = [NSString stringWithFormat:@"%@/%@", appName, kMWKCoreDataPersistentStoreSubdir];
    NSURL *url = [NSURL URLWithString:subpath relativeToURL:baseUrl];

    return [url URLByAppendingPathComponent:storeFilename];
}


- (NSString*)description
{
    NSMutableString *out = [NSMutableString new];

    [out appendFormat:@"CoreDataManager (%p):\n", self];
    [out appendFormat:@"  model: %@", _managedObjectModel];
    [out appendFormat:@"  storeType: %@", _persistentStoreType];
    [out appendFormat:@"  storeURL: %@", _persistentStoreURL];
    [out appendFormat:@"  coordinator: %@", _persistentStoreCoordinator];
    
    return out;
}


#pragma mark - Managed Object Contexts


- (void)setDefaultContext:(NSManagedObjectContext*)aCtx
{
    if (!aCtx.name) aCtx.name = @"defaultContext";
    [self setContext:aCtx forKey:kMWKCoreDataDefaultContext];
}


- (NSManagedObjectContext*)defaultContext
{
    return [self contextForKey:kMWKCoreDataDefaultContext];
}


- (void)setContext:(NSManagedObjectContext*)aCtx forKey:(id<NSCopying>)aKey
{
    dispatch_barrier_async(_contextAccessQueue, ^{
        self->_contexts[aKey] = aCtx;
    });
}


- (NSManagedObjectContext*)contextForKey:(id<NSCopying>)aKey
{
    __block NSManagedObjectContext *ctx = nil;
    
    dispatch_sync(_contextAccessQueue, ^{
        ctx = self->_contexts[aKey];
    });
    
    return ctx;
}


- (void)removeContextForKey:(id<NSCopying>)aKey
{
    dispatch_barrier_async(_contextAccessQueue, ^{
        [self->_contexts removeObjectForKey:aKey];
    });
}


// Private
- (void)resetAndRemoveAllContexts
{
    dispatch_barrier_sync(_contextAccessQueue, ^{
        for (NSManagedObjectContext *ctx in self->_contexts.allValues) {
            // @TODO: test that this is OK. May need to mark contexts which are observers, only remove did save notifications
            [[NSNotificationCenter defaultCenter] removeObserver:ctx];
            [ctx reset];
        }
        
        [self->_contexts removeAllObjects];
    });
}



#pragma mark - Migration

- (void)migrateWithProgress:(MWKCoreDataMigrationProgressHandler)aProgess
                 completion:(MWKCoreDataMigrationCompletionHandler)aCompletion
{
    // Enable migrations to run even while user exits app
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    MigrationManager *migrationManager = [MigrationManager new];
    migrationManager.migrationProgressHandler = aProgess;
    
    NSError *error = nil;
    BOOL migrationSuccess = [migrationManager progressivelyMigrateStoreAtURL:self.persistentStoreURL
                                                                      ofType:self.persistentStoreType
                                                                     toModel:self.managedObjectModel
                                                                modelsBundle:self.bundle
                                                                       error:&error];
    if (aCompletion) {
        aCompletion(migrationSuccess, error, migrationManager.originalSrcStoreBackupURL, bgTask);
    }
    else {
        // Since the caller didn't provide a completion handler, end the background task
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }
}


@end
