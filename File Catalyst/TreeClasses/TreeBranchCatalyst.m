//
//  TreeBranchCatalyst.m
//  Caravelle
//
//  Created by Nuno on 02/10/15.
//  Copyright (c) 2015 Nuno Brum. All rights reserved.
//

#import "TreeBranchCatalyst.h"
#import "TreeBranch_TreeBranchPrivate.h"

/* This class is the same as TreeBranch, but the refresh won't be done from the URL.
  refreshContens will only check for released and deleted items */

@implementation TreeBranchCatalyst

-(BOOL) addTreeItem:(TreeItem*) newItem {
    @synchronized(self) {
        if (self->_children == nil)
            self->_children = [[NSMutableArray alloc] init];
    }
    TreeBranch *cursor = self;
    NSArray *pcomps = [newItem.url pathComponents];
    unsigned long level = [[_url pathComponents] count];
    unsigned long leaf_level = [pcomps count]-1;
    while (level < leaf_level) {
        NSURL *pathURL = [cursor.url URLByAppendingPathComponent:pcomps[level] isDirectory:YES];
        TreeItem *child = [cursor childContainingURL:pathURL];
        if (child==nil) {/* Doesnt exist or if existing is not branch*/
            /* This is a new Branch Item that will contain the URL*/
            child = [[TreeBranchCatalyst alloc] initWithURL:pathURL parent:cursor];
            if (child!=nil) {
                @synchronized(cursor) {
                    [cursor->_children addObject:child];
                }
            }
            else {
                NSLog(@"TreeBranchCatalyst._addURLnoRecurr: Couldn't create path %@",pathURL);
            }
        }
        if ([child isFolder])
        {
            cursor = (TreeBranch*)child;
            if (cursor->_children==nil) {
                cursor->_children = [[NSMutableArray alloc] init];
            }
        }
        else {
            // Will ignore this child
            NSLog(@"TreeBranchCatalyst._addURLnoRecurr: Error:%@ can't be added to %@", newItem.url, pathURL);
            return NO;
        }
        level++;
    }
    // Checks if it exists ; The base class is provided TreeItem so that it can match anything
    TreeItem *replacedChild = [self childWithName:[newItem name] class:[TreeLeaf class]];
    @synchronized(cursor) {
        if (replacedChild)
            [cursor->_children removeObject:replacedChild];
        [cursor->_children addObject:newItem];
    }
    [newItem setParent:cursor];
    return YES; /* Stops here Nothing More to Add */
}

-(void) _coreRefreshContents {
    BOOL is_dirty = NO;
    [self willChangeValueForKey:kvoTreeBranchPropertyChildren];  // This will inform the observer about change
    @synchronized(self) {
        // Set all items as candidates for release
        NSUInteger index = 0 ;
        while ( index < [_children count]) {
            TreeItem *item = self->_children[index];
            if ([item hasTags:tagTreeItemRelease]!=0) {
                [self->_children removeObjectAtIndex:index];
                is_dirty = YES;
            }
            // at this point the files should be marked as released
            else if (fileExistsOnPath([item path])==NO) { // Safefy check
                [self->_children removeObjectAtIndex:index];
                is_dirty = YES;
            }
            else {
                if ([item itemType]==ItemTypeBranch) {
                    // TODO:!!!! Recurse the refresh Contents folder ?????
                    // Maybe it sufices to mark it as dirty, it will be automatically done on the browser
                    // But the size calculators must be changed accordingly
                }
                index++;
            }
        }
        if (is_dirty) {
            [self _invalidateSizes]; // Invalidates the previous calculated size
        }
        [self tagRefreshFinished];
        
    } // synchronized
    [self notifyDidChangeTreeBranchPropertyChildren];   // This will inform the observer about change
   
}

-(void) refreshContents {
    NSLog(@"TreeBranchCatalyst.refreshContents (%@)", [self path]);
    if ([self needsRefresh]) {
        [self tagRefreshStart];
        //NSLog(@"TreeBranch.refreshContents:(%@) H:%hhd", [self path], [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEF_SEE_HIDDEN_FILES]);
        
        [browserQueue addOperationWithBlock:^(void) {
            [self _coreRefreshContents];
         }];
    }
}



@end
