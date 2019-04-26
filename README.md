# MWKCoreData
[![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/mwkirk/MWKCoreData/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/mwkirk/mwkcoredata.svg)](https://github.com/mwkirk/MWKCoreData/releases)
[![Cocoapods Compatible](https://img.shields.io/cocoapods/v/MWKCoreData.svg)](https://cocoapods.org/pods/MWKCoreData)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)


MWKCoreData is a lightweight, curated library for Core Data that keeps you close to the metal but removes some of the drudgery and eases progressive migrations.

Ah, Core Data... Whatever your opinion of it, as an Apple developer you'll probably find yourself using it at some point. It's a powerful, but capricious framework. Some would say its many subtleties are highly underdocumented. Typical usage patterns are verbose and repetitive, so almost everyone will want it wrapped to some degree.

There are many Core Data libraries floating about. They range from simple categories to wrap boilerplate and sweeten syntax, to large frameworks like [MagicalRecord](https://github.com/magicalpanda/MagicalRecord) which cover every aspect of Core Data and are a universe unto themselves. 

MWKCoreData takes a minimalist approach which aims to:
* Create more concise, readable code for queries and common `NSManagedObjectContext` operations.
* Reduce the boilerplate of setting up a simple, typical Core Data stack.
* Encapsulate progressive migration.
* Keep the library small, simple, and understandable.

If you're looking to completely forget that you're using Core Data, this isn't the right library for you. You still need to understand Core Data – or at least the portions you're using. It deliberately limits its abstraction of the Core Data framework so that it remains easily understandable and debuggable when something goes wrong. 

It doesn't try to cover the entire Core Data framework or more exotic usage patterns, but it's sufficient for most use cases and easy to extend.

## Credit Where It's Due

Key parts of this library are taken from two sources:

* The `NSManagedObject` category is from [Objective Record](https://github.com/supermarin/ObjectiveRecord) by [Marin Usalj](http://supermar.in/) with a few minor changes. Its elegant, concise query syntax makes your code much more readable. 

* The progressive migration code is based on the excellent article [Custom Core Data Migrations](https://www.objc.io/issues/4-core-data/core-data-migration/) by Martin Hwasser in [ObjC.io](https://www.objc.io) Issue #4 and its accompanying [example](https://github.com/objcio/issue-4-core-data-migration). If you want to wrap your head around Core Data migrations, this is the place to start.
 
## Organization

MWKCoreData is comprised of two classes and two categories.

* `MWKCoreDataManager` provides methods to check if migration is required, perform a progressive migration, and set up the Core Data stack.
* `MigrationManager` performs that actual work of progressive migrations. You will typically not create instances directly.
* `NSManagedObject+MWKCoreData` provides [Objective Record's](https://github.com/supermarin/ObjectiveRecord) query syntax and an `-[awakeFromCreate]` method which can be overridden in your `NSManagedObject` subclass to work around the difficulties of `-[awakeFromInsert]` when used with nested (i.e. parent/child) contexts. See the note in the header.
* `NSManagedObjectContext+MWKCoreData` provides convenience methods for creating and saving contexts (including a conditional save useful for child contexts that first obtains permanent object IDs), convenience methods for setting up and sychronizing nested contexts via notification observation + merge/refresh. 

## Usage

### Core Data Migration and Stack Setup

Somewhere early in your application's setup, you should check if a migration is required and perform it if needed. On iOS, you shouldn't migrate within `-[application:didFinishLaunchingWithOptions:]`; the watchdog will kill your app mid-migration if it's taking too long. Typically, you should present a UI which informs the user about the migration and posts updates via the progress block. 

You can dispatch the migration to a background queue _if you're careful_. You must be certain your app doesn't do _anything_ with Core Data until the migration completes, and dispatch your UI progress updates back to the main queue. If in doubt, keep your migration on the main queue.

If you don't need a migration or after it completes successfully, initialize the Core Data stack.

The way in which you do this is specific to your app, but this is the crux of it.

```objective-c
CoreDataManager *mgr = [CoreDataManager sharedInstance];

if (mgr.requiresMigration) {
    [mgr migrateWithProgress:^(NSUInteger aPass, float aProgress) {
        // Update your UI so that the user is informed about what's happening
        NSLog(@"Migration pass %td at %.2f", aPass, aProgress);
    } 
    completion:^(BOOL aSuccess, NSError *aError, NSURL *aOriginalSrcStoreBackupURL, UIBackgroundTaskIdentifier aBgTask) {
        if (aSuccess) {
            NSLog(@"Migration completed successfully, old store backup at %@", aOriginalSrcStoreBackupURL.path);
            // Now you can initialize the Core Data stack finish your app setup
        }
        else {
            // If migration fails, determine how to recover. You could choose
            // to restore the original store, for example.
            NSLog(@"Migration failed with error: %@", aError);
        }
        
        // You are responsible for ending the background task
        [[UIApplication sharedApplication] endBackgroundTask:aBgTask];
    }];
}
else {
    NSError *error = nil;
    [mgr initializeStack:&error];
    
    if (error) {
        // Handle the error
    }
    
    [mgr setDefaultContext:[NSManagedObjectContext mainQueueContext]];
}
```

### Managed Object Contexts
You spend a lot of time in Core Data with managed object contexts, so streamlining common operations is a big win. Observing another context also enables its saves or changes to be automatically merged into the receiver. There's no magic here; just convenient ways to employ some useful Core Data patterns and a little help in avoiding some pitfalls.

```objective-c
// Convenience methods use the stack's configured store and coordinator
NSManagedObjectContext *mainCtx = [NSManagedObjectContext mainQueueContext];
NSManagedObjectContext *privateCtx = [NSManagedObjectContext privateQueueContext];
NSManagedObjectContext *childOfPrivateCtx = [NSManagedObjectContext privateQueueContextWithParent:privateCtx];
NSManagedObjectContext *childOfDefaultCtx = [NSManagedObjectContext mainQueueContextWithParent:[NSManagedObjectContext defaultContext]];

// Observe notifications and merge or refresh to keep in sync with main context
[childOfDefaultCtx observeSaveOfContext:childOfDefaultCtx.parentContext];
[childOfDefaultCtx observeObjectChangesInParentContext];

// Save after obtaining permanent objectIDs. Useful with child contexts.
NSArray *tmpIdObjects = [[childOfDefaultCtx objectsWithTemporaryIDs] allObjects];
[childOfDefaultCtx saveAfterObtainingPermanentIDsForObjects:tmpIdObjects];

// Stop observing notifications from main context
[childOfDefaultCtx stopObservingSaveOfContext:childOfDefaultCtx.parentContext];
[childOfDefaultCtx stopObservingObjectChangesInParentContext];
```

### Managed Objects

Compare [Objective Record's](https://github.com/supermarin/ObjectiveRecord) query syntax:
```objective-c
// Fetch in the default context
NSArray *persons = [Person where:@"firstName == %@ AND lastName == %@", firstName, lastName];
```

with the same fetch in "stock" Core Data:
```objective-c
// A typical fetch 
NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Person"];
request.predicate = [NSPredicate predicateWithFormat:@"firstName == %@ AND lastName == %@", firstName, lastName];
NSError *error = nil;
NSManagedObjectContext *yourManagedObjectCtx = ...;
NSArray *persons = [yourManagedObjectCtx executeFetchRequest:request error:&error];
```
You'll improve your code's readability enormously. The more complex your queries (ordering, limits, etc.), the better it gets.

## Installation
###CocoaPods
You can install MWKCoreData in your project with [CocoaPods](https://github.com/cocoapods/cocoapods) by adding this to your `Podfile`:

```Ruby
pod 'MWKCoreData', '~> 1.0.0'
```

### Carthage
MWKCoreData also supports [Carthage](https://github.com/Carthage/Carthage). Specify it in your `Cartfile` like this:

```
github "mwkirk/MWKCoreData" ~> 1.0
```

### Manually
Since MWKCoreData is just a few files, it's also simple to integrate it into your project manually.

## Requirements

MWKCoreData requires iOS 8.0 or higher. 

It _should_ work on all Apple platforms that support Core Data, but it is untested.

## About

This library has grown and evolved based purely on what I've needed; it doesn't doesn't cover the Core Data gamut. However, it's such a simple library that you can probably add the additional bits you need quite easily – and perhaps send a pull request if you think it's something others could use or you find a bug!

I've tried several Core Data libraries, but nothing ever quite satisfied. Some weren't my style and others were just more than I needed. And, because debugging Core Data problems can be painful, I wanted a small codebase that I owned and understood (or could understand again quickly).

However, in some cases, I've cherry-picked others' code because it was so excellent. With [Objective Record](https://github.com/supermarin/ObjectiveRecord), the query syntax was exactly what I wanted, but the rest of the library wasn't a good fit (and I didn't feel like my code would be a good contribution to that project either). Apologies to [Supermarin](http://supermar.in/). I guess that's how forks happen.

## License

MWKCoreData is available under the MIT license. See the LICENSE file for more info.




