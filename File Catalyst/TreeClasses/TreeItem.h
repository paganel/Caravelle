//
//  TreeItem.h
//  Caravelle
//
//  Created by Nuno Brum on 12/31/12.
//  Copyright (c) 2012 Nuno Brum. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "Definitions.h"
#import "FileUtils.h"

extern const NSString *keyDuplicateInfo;

typedef NS_OPTIONS(NSUInteger, TreeItemTagEnum) {
    tagTreeItemDirty     = (1UL << 0), // Used to force TreeBranches to make a refresh from disk
    tagTreeItemScanned   = (1UL << 1), // Used to indicate that the directory was already read from the disk
    tagTreeItemMarked    = (1UL << 2),
    tagTreeItemDropped   = (1UL << 3), // Used for drag&drop operations
    tagTreeItemToMove    = (1UL << 4),
    tagTreeItemUpdating  = (1UL << 5),
    tagTreeItemRelease   = (1UL << 6), // Used inform BrowserControllers to remove items from Root
    tagTreeItemReadOnly  = (1UL << 7),
    tagTreeItemNew       = (1UL << 8),
    tagTreeItemHidden    = (1UL << 9),
    tagTreeSizeCalcReq   = (1UL << 10), // Used to avoid multiple orders to size calculation
    //tagTreeSizeCalcDone  = (1UL << 11),
    tagTreeItemAll       = NSUIntegerMax
};


typedef NS_ENUM(NSInteger, ItemType) {
    ItemTypeNone = 0,
    ItemTypeLeaf = 1,
    ItemTypeBranch,
    ItemTypeFilter
};


@protocol TreeProtocol <NSObject>

- (ItemType) itemType;

@end


@interface TreeItem : NSObject <NSPasteboardWriting, NSPasteboardReading> {
    NSURL           *_url;
    TreeItemTagEnum _tag;
    TreeItem __weak *_parent; /* Declaring the parent as weak will solve the problem of doubled linked objects */
}

@property (weak) TreeItem           *parent;
@property NSString *nameCache; // This is to lower memory allocation calls, for each name call, a new CFString was being allocated

-(TreeItem*) initWithURL:(NSURL*)url parent:(id)parent;
-(TreeItem*) initWithMDItem:(NSMetadataItem*)mdItem parent:(id)parent;

-(void) purgeURLCacheResources;

+(id)treeItemForURL:(NSURL *)url parent:(id)parent;
+(id)treeItemForMDItem:(NSMetadataItem *)mdItem parent:(id)parent;
- (TreeItem*) root;

-(void) notifyChange;

-(NSArray *) treeComponents;
-(NSArray *) treeComponentsToParent:(id)parent;

-(ItemType)  itemType;
-(NSString*) name;
-(void) setName:(NSString*)newName;
-(NSDate*)   date_modified;
-(NSDate*)   date_accessed;
-(NSDate*)   date_created;
-(NSString*) path ;
-(NSString*) location;
-(NSImage*) image;
-(NSNumber*) fileSize;
-(NSNumber*) allocatedSize;
-(NSNumber*) totalSize;
-(NSNumber*) totalAllocatedSize;
-(NSString*) fileKind;
-(NSString*) hint;


-(void) setUrl:(NSURL*)url;
-(NSURL*) url;

-(void) setTag:(TreeItemTagEnum)tag;
-(void) resetTag:(TreeItemTagEnum)tag;
-(void) toggleTag:(TreeItemTagEnum)tag;

-(TreeItemTagEnum) tag;
-(BOOL) hasTags:(TreeItemTagEnum) tag;
-(void) updateFileTags;

/*
 * File manipulation methods
 */
-(BOOL) openFile;
-(BOOL) removeItem;

/*
 * URL Comparison methods
 */

-(enumPathCompare) relationToPath:(NSString*) otherPath;
-(enumPathCompare) compareTo:(TreeItem*) otherItem;
-(BOOL) canContainPath:(NSString*)path;
-(BOOL) containedInPath: (NSString*) path;
-(BOOL) canContainURL:(NSURL*)url;
-(BOOL) containedInURL:(NSURL*) url;

/*
 * Coding Compliant methods
 */
-(void) setValue:(id)value forUndefinedKey:(NSString *)key;

-(BOOL) hasDuplicates;
-(NSNumber*) duplicateGroup;


@end
