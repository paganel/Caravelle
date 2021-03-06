//
//  TreeLeaf.m
//  Caravelle
//
//  Created by Nuno Brum on 1/22/13.
//  Copyright (c) 2013 Nuno Brum. All rights reserved.
//

#import "TreeLeaf.h"
#import "DuplicateInformation.h"
#import "PasteboardUtils.h"


const NSString *keyDuplicateInfo = @"TStoreDuplicateKey";
//const NSString *keyMD5Info       = @"TStoreMD5Key";
//const NSString *keyDupRefresh    = @"TStoreDupRefreshKey";

@implementation TreeLeaf

-(void) deinit {
    [self removeFromDuplicateRing];
    [self->_store removeAllObjects];
    self->_store = nil;
    [super deinit];
}

-(ItemType) itemType {
    return ItemTypeLeaf;
}


-(BOOL) removeItem {
    return [super removeItem];
}



// Copy and paste support
-(NSDragOperation) supportedPasteOperations:(id<NSDraggingInfo>) info {
    NSDragOperation sourceDragMask = supportedOperations(info);
    sourceDragMask &= NSDragOperationGeneric;
    return sourceDragMask;
}

-(NSArray*) acceptDropped:(id<NSDraggingInfo>)info operation:(NSDragOperation)operation sender:(id)fromObject {
    // TODO:1.5 Implement drop of files
    NSLog(@"TreeItem.acceptDropped:operation:  Missing implementation");
    return nil; // Invalidate all
}


/*
 * Menu support
 */
-(BOOL) respondsToMenuTag:(EnumContextualMenuItemTags)tag {
    BOOL answer;
    switch (tag) {
            // Enables these ones
        case menuOpenWith:
            answer = YES;
            break;
            
            // Invalidates these ones
        //case xxxxxx:
        //    answer = NO;
        //    break;
            
        default:
            answer = [super respondsToMenuTag:tag];
            break;
    }
    
    return answer;
}

/*
 * Dupplicate Support
 */

-(DuplicateInformation*) duplicateInfo {
    DuplicateInformation *dupInfo = [self->_store objectForKey:keyDuplicateInfo];
    return dupInfo;
}

-(DuplicateInformation*) startDuplicateInfo {
    DuplicateInformation *dupInfo = [[DuplicateInformation alloc] init];
    [self addToStore:[NSDictionary dictionaryWithObject:dupInfo forKey:keyDuplicateInfo]];
    return dupInfo;
}

-(void) removeDuplicateInfo {
    // It will remove the current duplicate, if exists
    [self->_store removeObjectForKey:keyDuplicateInfo];
}

-(TreeLeaf*) nextDuplicate {
    DuplicateInformation *dupInfo = [self->_store objectForKey:keyDuplicateInfo];
    if (dupInfo)
        return [dupInfo nextDuplicate];
    else
        return nil;
}

/*-(void) setNextDuplicate:(TreeLeaf*)item group:(NSUInteger)group {
    assert(item!=nil);
    // Get nextDuplicate and create it if Needed
    DuplicateInformation *dupInfo = [self->_store objectForKey:keyDuplicateInfo];
    if (dupInfo == nil) {
        dupInfo = [self startDuplicateInfo];
    }
    [dupInfo setNextDuplicate:item];
    dupInfo->dupGroup = group;
}*/

// The duplicates are organized on a ring fashion for memory space efficiency
// FileA -> FileB -> FileC-> FileA
// This function returns an indicator whether the group should be incremented, if it is a new group of duplicates

-(BOOL) addDuplicate:(TreeLeaf*)duplicateFile group:(NSUInteger)group {
    DuplicateInformation *selfdi = [self duplicateInfo];
    if (selfdi == nil) {
        selfdi = [self startDuplicateInfo];
    }
    
    DuplicateInformation *dupdi = [duplicateFile duplicateInfo];
    if (dupdi == nil) {
        dupdi = [duplicateFile startDuplicateInfo];
    }
    
    if ([selfdi nextDuplicate]==nil) // A new set of duplicates
    {
        [selfdi setNextDuplicate:duplicateFile];
        selfdi->dupGroup = group;
        [dupdi setNextDuplicate:self];
        dupdi->dupGroup = group;
        return YES;
    }
    else {
        [dupdi setNextDuplicate:[selfdi nextDuplicate]];
        dupdi->dupGroup = selfdi->dupGroup;
        [selfdi setNextDuplicate:duplicateFile];
        return  NO;
    }
}

-(BOOL) hasDuplicates {
    return ([self nextDuplicate] == nil ? NO : YES);
}

-(NSUInteger) duplicateCount {
    if ([self nextDuplicate] == nil)
        return 0;
    else
    {
        TreeLeaf *cursor=self.nextDuplicate;
        int count =0;
        while (cursor!=self) {
            cursor = cursor.nextDuplicate;
            count++;
        }
        return count;
    }
}

-(NSMutableArray*) duplicateList {
    if (self.nextDuplicate==nil)
        return nil;
    else
    {
        TreeLeaf *cursor=self.nextDuplicate;
        NSMutableArray *answer =[[NSMutableArray new]init];
        while (cursor!=self && cursor != nil) {
            [answer addObject:cursor];
            cursor = cursor.nextDuplicate;
        }
        return answer;
    }
}

-(void) removeFromDuplicateRing {
    if (self.nextDuplicate!=nil)
    {
        TreeLeaf *cursor=self.nextDuplicate;
        if (cursor.nextDuplicate == self) { // In case if only one duplicate
            [cursor removeDuplicateInfo];   // Deletes the chain
        }
        else {
            while (cursor.nextDuplicate!=self) { // searches for the file that references this one
                cursor = cursor.nextDuplicate;
            }
            [cursor.duplicateInfo setNextDuplicate: self.nextDuplicate ]; // and bypasses this one
        }
        [self removeDuplicateInfo];
    }
}

-(void) resetDuplicates {
    TreeLeaf *cursor=self;
    while (cursor.duplicateInfo!=nil) {
        TreeLeaf *tmp = cursor;
        cursor = cursor.nextDuplicate;
        //[tmp->_store removeObjectForKey:keyDuplicateInfo]; // Deletes the nextDuplicate AND refreshCount
        tmp->_store = nil;
    }
}

-(void) setDuplicateRefreshCount:(NSInteger)count {
    DuplicateInformation *dupInfo = [self duplicateInfo];
    if (dupInfo)
        dupInfo->dupRefreshCounter = count;
}

-(NSInteger) duplicateRefreshCount {
    return [self duplicateInfo]->dupRefreshCounter;
}

-(NSNumber*)duplicateGroup {
    DuplicateInformation *dupInfo = [self->_store objectForKey:keyDuplicateInfo];
    if (dupInfo)
        return [NSNumber numberWithInteger:dupInfo->dupGroup];
    else
        return nil;
}


/*-(NSData*) MD5 {
    NSData * MD5;
    // First Check gets the duplicate Info
    DuplicateInformation *dupInfo = [self duplicateInfo];
    if (dupInfo) {
        if (dupInfo->valid_md5) {
            return [[NSData alloc] initWithBytes:dupInfo->md5_checksum length:16];
        }
    }
    else {
        dupInfo = [self startDuplicateInfo];
    }
    calculateMD5(self->_url, dupInfo->md5_checksum);
    return [[NSData alloc] initWithBytes:dupInfo->md5_checksum length:16];
}*/

-(BOOL) compareMD5checksum: (TreeLeaf *)otherFile {
    DuplicateInformation *myDupInfo = [self duplicateInfo];
    DuplicateInformation *otherDupInfo = [otherFile duplicateInfo];
    
    if (myDupInfo    == nil)
        myDupInfo = [self startDuplicateInfo];
    if (otherDupInfo == nil)
        otherDupInfo = [otherFile startDuplicateInfo];
    
    if (myDupInfo->valid_md5 == NO) {
        calculateMD5(self->_url, myDupInfo->md5_checksum);
        myDupInfo->valid_md5 = YES;
    }
    if (otherDupInfo->valid_md5 == NO) {
        calculateMD5(otherFile->_url, otherDupInfo->md5_checksum);
        otherDupInfo->valid_md5 = YES;
    }
    int res = memcmp(myDupInfo->md5_checksum, otherDupInfo->md5_checksum, 16);
    return  res==0 ? YES : NO;
}


@end
