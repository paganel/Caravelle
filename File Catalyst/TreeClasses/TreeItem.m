//
//  TreeItem.m
//  FileCatalyst1
//
//  Created by Nuno Brum on 12/31/12.
//  Copyright (c) 2012 Nuno Brum. All rights reserved.
//

#import "TreeItem.h"
//#import "MyDirectoryEnumerator.h"
#import "TreeBranch.h"
#import "TreePackage.h"
#import "FileUtils.h"

const NSString *keyDuplicateInfo = @"TStoreDuplicateKey";
const NSString *keyMD5Info       = @"TStoreMD5Key";
const NSString *keyDupRefresh    = @"TStoreDupRefreshKey";


@implementation TreeItem

-(ItemType) itemType {
    NSAssert(NO, @"This method is supposed to not be called directly. Virtual Method.");
    return ItemTypeNone;
}

-(TreeItem*) initWithURL:(NSURL*)url parent:(id)parent {
    self = [super init];
    if (self) {
        self->_tag = 0;
        [self setUrl:url];
        self->_parent = parent;
        self->_store = nil;
    }
    return self;
}

-(TreeItem*) initWithMDItem:(NSMetadataItem*)mdItem parent:(id)parent {
    NSString *path = [mdItem valueForAttribute:(id)kMDItemPath];
    return [self initWithURL: [NSURL fileURLWithPath:path] parent:parent];
 }


+(instancetype) treeItemForURL:(NSURL *)url parent:(id)parent {
    // We create folder items or image items, and ignore everything else; all based on the UTI we get from the URL
    // TODO:!! Check Is regular file First. See NSURLIsRegularFileKey
    NSString *typeIdentifier;
    if ([url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:NULL]) {
        if (isFolder(url)) {
            BOOL ispackage = isPackage(url);
            if (ispackage) {
                if (//[typeIdentifier isEqualToString:(NSString*)kUTTypeApplication] ||
                    //[typeIdentifier isEqualToString:(NSString*)kUTTypeApplicationFile] ||
                    [typeIdentifier isEqualToString:(NSString*)kUTTypeApplicationBundle]) {
                    return [[TreePackage alloc] initWithURL:url parent:parent];
                }
                /* Debug Code */
                /*else if ([typeIdentifier isEqualToString:@"com.apple.xcode.project"] ||
                         [typeIdentifier isEqualToString:@"com.apple.dt.document.workspace"]) {
                    return [[TreeLeaf alloc] initWithURL:url parent:parent];
                }*/
            }
            if (//[typeIdentifier isEqualToString:(NSString *)kUTTypeFolder] ||
                [typeIdentifier isEqualToString:(NSString *)kUTTypeVolume]) {
                // TODO:!!! Create a dedicated class for a Volume or a mounting point
            }
            return [[TreeBranch alloc] initWithURL:url parent:parent];
        }
        else {
            /* Check if it is an image type */
            NSArray *imageUTIs = [NSImage imageTypes];
            if ([imageUTIs containsObject:typeIdentifier]) {
                //  TODO:!!! Treat here other file types other than just not folders
                return [[TreeLeaf alloc] initWithURL:url parent:parent];
            }
            return [[TreeLeaf alloc] initWithURL:url parent:parent];
        }
    }
    return nil;
}

+(instancetype)treeItemForMDItem:(NSMetadataItem *)mdItem parent:(id)parent {
    // We create folder items or image items, and ignore everything else; all based on the UTI we get from the URL
    //NSString *typeIdentifier = [mdItem valueForAttribute:(id)kMDItemContentType];
    NSString *path = [mdItem valueForAttribute:(id)kMDItemPath];
    NSURL *url = [NSURL fileURLWithPath:path];
    id answer = [self treeItemForURL:url parent:parent];
    return answer;
}


-(void) setUrl:(NSURL*)url {
    // The tags shoud be set here accordingly to the information got from URL
    //[self willChangeValueForKey:@"url"];
    [self willChangeValueForKey:@"name"]; // This assures that the IconView is informed of the change
    self->_url = url;
    [self updateFileTags];
    //[self didChangeValueForKey:@"url"];
    [self didChangeValueForKey:@"name"]; // This assures that the IconView is informed of the change.
}

-(NSURL*) url {
    return _url;
}

-(void) setTag:(TreeItemTagEnum)tag {
    _tag |= tag;
}
-(void) resetTag:(TreeItemTagEnum)tag {
    _tag &= ~tag;
}
-(void) toggleTag:(TreeItemTagEnum)tag {
    _tag ^= tag;
}

-(TreeItemTagEnum) tag {
    return _tag;
}

-(BOOL) hasTags:(TreeItemTagEnum) tag {
    return (_tag & tag)!=0 ? YES : NO;
}

-(void) updateFileTags {
    _tag &= ~tagTreeItemDirty;
    if (isWritable(_url))
        _tag &= ~tagTreeItemReadOnly;
    else
        _tag |= tagTreeItemReadOnly;
    
    if (isHidden(_url))
        _tag |= tagTreeItemHidden;
    else
        _tag &= ~tagTreeItemHidden;
    
}

-(NSString*) name {
    NSString *nameStr = [_url lastPathComponent];
    if ([nameStr isEqualToString:@"/"]) {
        nameStr = mediaNameFromURL(_url);
    }
    return nameStr;
}

-(void) setName:(NSString*)newName {
    NSString *operation=nil;
    if ([self hasTags:tagTreeItemNew]) {
        operation = opNewFolder;
    }
    else {
        // If the name didn't change. Do Nothing
        if ([newName isEqualToString:[self name]]) {
            return;
        }
        operation = opRename;
    }
    NSArray *items = [NSArray arrayWithObject:self];

    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          items, kDFOFilesKey,
                          operation, kDFOOperationKey,
                          newName, kDFORenameFileKey,
                          self.parent, kDFODestinationKey,
                          //self, kFromObjectKey,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationDoFileOperation object:self userInfo:info];

}

-(NSDate*) date_modified {
    NSDate *date=nil;
    NSError *errorCode;
    if ([_url isFileURL]) {
        [_url getResourceValue:&date forKey:NSURLContentModificationDateKey error:&errorCode];
    }
    else {
        NSDictionary *dirAttributes =[[NSFileManager defaultManager] attributesOfItemAtPath:[_url path] error:NULL];
        date = [dirAttributes fileModificationDate];

    }
    return date;
}

-(NSDate*)   date_accessed {
    NSDate *date=nil;
    NSError *errorCode;
    if ([_url isFileURL]) {
        [_url getResourceValue:&date forKey:NSURLContentAccessDateKey error:&errorCode];
    }
    else {
        NSDictionary *dirAttributes =[[NSFileManager defaultManager] attributesOfItemAtPath:[_url path] error:NULL];
        date = [dirAttributes fileModificationDate];

    }
    return date;
}
-(NSDate*)   date_created {
    NSDate *date=nil;
    NSError *errorCode;
    if ([_url isFileURL]) {
        [_url getResourceValue:&date forKey:NSURLCreationDateKey error:&errorCode];
    }
    else {
        NSDictionary *dirAttributes =[[NSFileManager defaultManager] attributesOfItemAtPath:[_url path] error:NULL];
        date = [dirAttributes fileCreationDate];

    }
    return date;
}

-(NSString*) path {
    //NSString *path;
    //[_url getResourceValue:&path     forKey:NSURLPathKey error:NULL];
    return [_url path];
}

-(NSString*) location {
    //NSString *path;
    //[_url getResourceValue:&path     forKey:NSURLPathKey error:NULL];
    return [[_url URLByDeletingLastPathComponent] path];
}

-(NSImage*) image {
    NSImage *iconImage;
    NSImage *image;
    
    // First get the image
    if ([self hasTags:tagTreeItemNew]) {
        if ([self itemType] == ItemTypeBranch)
            iconImage = [NSImage imageNamed:@"GenericFolderIcon"];
        else
            iconImage = [NSImage imageNamed:@"GenericDocumentIcon"];
    }
    else  {
        iconImage =[[NSWorkspace sharedWorkspace] iconForFile: [_url path]];
    }
    
    
    NSSize imageSize= [iconImage size];
    //TreeItemTagEnum tags = [self tag];
    image = [NSImage imageWithSize:imageSize flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [iconImage drawInRect:dstRect];
        
        // Then will apply an overlay
        // The code below only draw one of the badges in the order the code is presented.
        // TODO: ! Consider making an overlay where all the applicable badges are placed
        //         in sequence, starting from right to left
        if ([self hasTags:tagTreeItemHidden]) {
            [[NSImage imageNamed:@"PrivateFolderBadgeIcon"] drawInRect:dstRect];
            //NSLog(@"%@ private", [self url]);
        }
        else if ([self hasTags:tagTreeItemReadOnly]) {
            [[NSImage imageNamed:@"ReadOnlyFolderBadgeIcon"] drawInRect:dstRect];
            //NSLog(@"%@ read-only", [self url]);
        }
        else if ([self hasTags:tagTreeItemDropped]) {
            [[NSImage imageNamed:@"DropFolderBadgeIcon"] drawInRect:dstRect];
            //NSLog(@"%@ dropped", [self url]);
        }
        return YES;
    }];
    return image;
}

-(long long) filesize {
    NSNumber *filesize;
    [_url getResourceValue:&filesize     forKey:NSURLFileSizeKey error:NULL];
    return [filesize longLongValue];
}

-(NSNumber*) fileSize {
    NSNumber *filesize;
    [_url getResourceValue:&filesize     forKey:NSURLFileSizeKey error:NULL];
    return filesize;

}

-(NSString*) fileKind {
    NSString *kind;
    [_url getResourceValue:&kind     forKey:NSURLLocalizedTypeDescriptionKey error:NULL];
    return kind;
}

-(NSString*) hint {
    return [self name];
}

-(NSData*) MD5 {
    NSData *MD5 = [self->_store objectForKey:keyMD5Info];
    if (MD5==nil) {
        MD5 = calculateMD5(self->_url);
        if (MD5!=nil) {// Success in the calculation
            // Store it
            [self addToStore:[NSDictionary dictionaryWithObjectsAndKeys:MD5, keyMD5Info, nil]];
        }
    }
    return MD5;
}


-(TreeItem*) root {
    TreeItem *cursor = self;
    while (cursor->_parent!=NULL) {
        cursor=cursor->_parent;
    }
    return cursor;
}

-(NSArray *) treeComponents {
    NSMutableArray *answer = [NSMutableArray arrayWithObject:self];
    TreeItem *cursor = self;
    while (cursor->_parent!=NULL) {
        cursor=cursor->_parent;
        [answer insertObject:cursor atIndex:0];
    }
    return answer;
}

-(NSArray *) treeComponentsToParent:(id)parent {
    NSMutableArray *answer = [NSMutableArray arrayWithObject:self];
    TreeItem *cursor = self;
    while (cursor!=parent && cursor->_parent!=NULL ) {
        cursor=cursor->_parent;
        [answer insertObject:cursor atIndex:0];
    }
    return answer;
}

-(BOOL) openFile {
    [[NSWorkspace sharedWorkspace] openFile:[self path]];
    return YES;
}

-(BOOL) removeItem {
    if (_parent) {
        [(TreeBranch*)_parent removeChild:self];
    }
    [self setTag:tagTreeItemRelease];
    return YES;
}

#pragma mark -
#pragma mark URL comparison methods

-(enumPathCompare) relationToPath:(NSString*) otherPath {
    return path_relation([self path], otherPath);
}

-(enumPathCompare) compareTo:(TreeItem*) otherItem {
    return [self relationToPath:[otherItem path]];
}

/* This is a test if it can contain the URL */
-(BOOL) canContainPath:(NSString*)path {
    NSArray *cpself = [[self path] pathComponents];
    NSArray *cppath = [path pathComponents];
    NSUInteger cpsc = [cpself count];
    if (cpsc> [cppath count])
        return NO;
    for (NSUInteger i = 0 ; i < cpsc ; i++) {
        if (NO == [cpself[i] isEqualToString:cppath[i]]) {
            return NO;
        }
    }
    return YES;
}

-(BOOL) containedInPath: (NSString*) path {
    NSArray *cpself = [[self path] pathComponents];
    NSArray *cppath = [path pathComponents];
    NSUInteger cppc = [cppath count];
    if (cppc> [cppath count])
        return NO;
    for (NSUInteger i = 0 ; i < cppc ; i++) {
        if (NO == [cpself[i] isEqualToString:cppath[i]]) {
            return NO;
        }
    }
    return YES;
}
/* This is a test if it can contain the URL */
-(BOOL) canContainURL:(NSURL*)url {
    return [self canContainPath:[url path]];
}

-(BOOL) containedInURL: (NSURL*) url {
    return [self containedInPath:[url path]];

}
#pragma mark -
#pragma mark NSPasteboardWriting support


//TODO:!!! Try to pass NSFilenamePboardType to see if drag to recycle bin can be executed
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
#ifdef USE_UTI
    /* Adding the TreeType */
    NSMutableArray *answer =[NSMutableArray arrayWithObject:(__bridge id)kTreeItemDropUTI];
    [answer addObjectsFromArray:[self.url writableTypesForPasteboard:pasteboard]];
    return answer;
#else
    return [self.url writableTypesForPasteboard:pasteboard];
#endif
}

- (id)pasteboardPropertyListForType:(NSString *)type {
    id answer;
#ifdef USE_UTI
    if (UTTypeEqual ((__bridge CFStringRef)(type),kTreeItemDropUTI)) {
        answer = self;
    }
    else
#endif
    answer = [self.url pasteboardPropertyListForType:type];
    return answer;
}

- (NSPasteboardWritingOptions)writingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    NSPasteboardWritingOptions answer;
#ifdef USE_UTI
    if (UTTypeEqual ((__bridge CFStringRef)(type),kTreeItemDropUTI)) {
        // If a custom UTI is ever considered, write the Write to pasteboard
        answer = 0;
    }
    else
#endif
    if ([self.url respondsToSelector:@selector(writingOptionsForType:pasteboard:)]) {
        answer = [self.url writingOptionsForType:type pasteboard:pasteboard];
    } else {
        answer = 0;
    }
    return answer;
}

#pragma mark -
#pragma mark  NSPasteboardReading support

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    //return [NSArray arrayWithObjects: //(id)kUTTypeFolder, (id)kUTTypeFileURL, (id)kUTTypeItem,
    //        (id)NSFilenamesPboardType, (id)NSURLPboardType, OwnUTITypes nil];
    return [NSURL readableTypesForPasteboard:pasteboard];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    //return NSPasteboardReadingAsString;
    return [NSURL readingOptionsForType:type pasteboard:pasteboard];
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    // We recreate the appropriate object
#ifdef USE_UTI
    if (UTTypeEqual ((__bridge CFStringRef)(type),kTreeItemDropUTI)) {
        // If a custom UTI is ever considered, write the Write to pasteboard
        return propertyList; // If ever the custom UTI is created. Check if this works
    }
    else 
#endif
    {
        // We only have URLs accepted. Create the URL
        NSURL *url = [[NSURL alloc] initWithPasteboardPropertyList:propertyList ofType:type] ;
        return [TreeItem treeItemForURL:url parent:nil];
    }
}

#pragma mark - Coding Compliant

/*
 * Coding Compliant methods
 */
-(void) setValue:(id)value forUndefinedKey:(NSString *)key {

    NSLog(@"Trying to set value for Key %@", key);
}

/*
 * Dupplicate Support
 */

-(void) addToStore:(NSDictionary*) dict {
    if (self->_store==nil)
        self->_store = [[NSMutableDictionary alloc] initWithCapacity:3]; // Deems a reasonable number
    
    [self->_store addEntriesFromDictionary: dict];
}



-(BOOL) compareMD5checksum: (TreeItem *)otherFile {
    NSData *myMD5 = [self MD5];
    NSData *otherMD5 = [otherFile MD5];
    return  [myMD5 isEqualToData:otherMD5];
 }

-(TreeItem*) nextDuplicate {
    return [self->_store objectForKey:keyDuplicateInfo];
}

-(void) setNextDuplicate:(TreeItem*) item {
    if (item==nil) {
        // It will remove the current duplicate, if exists
        [self->_store removeObjectForKey:keyDuplicateInfo];
        // and also removes the refreshCount
        [self->_store removeObjectForKey:keyDupRefresh];
    }
    else {
        [self addToStore: [NSDictionary dictionaryWithObjectsAndKeys:item, keyDuplicateInfo, nil]];
    }
}

// The duplicates are organized on a ring fashion for memory space efficiency
// FileA -> FileB -> FileC-> FileA
-(void) addDuplicate:(TreeItem*)duplicateFile {
    if (self.nextDuplicate==nil)
    {
        [self setNextDuplicate: duplicateFile];
        [duplicateFile setNextDuplicate: self];
    }
    else {
        [duplicateFile setNextDuplicate: [self nextDuplicate]];
        [self setNextDuplicate: duplicateFile];
    }
}

-(BOOL) hasDuplicates {
    return (self.nextDuplicate==nil ? NO : YES);
}

-(NSUInteger) duplicateCount {
    if (self.nextDuplicate==nil)
        return 0;
    else
    {
        TreeItem *cursor=self.nextDuplicate;
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
        TreeItem *cursor=self.nextDuplicate;
        NSMutableArray *answer =[[NSMutableArray new]init];
        while (cursor!=self) {
            [answer addObject:cursor];
            cursor = cursor.nextDuplicate;
        }
        return answer;
    }
}

-(void) removeFromDuplicateRing {
    if (self.nextDuplicate!=nil)
    {
        TreeItem *cursor=self.nextDuplicate;
        if (cursor == self.nextDuplicate) // In case if only one duplicate
            [cursor setNextDuplicate: nil];   // Deletes the chain
        else {
            while (cursor.nextDuplicate!=self) { // searches for the file that references this one
                cursor = cursor.nextDuplicate;
            }
            [cursor setNextDuplicate: self.nextDuplicate]; // and bypasses this one
        }
    }
}

-(void) resetDuplicates {
    TreeItem *cursor=self;
    TreeItem *tmp=self;
    while (cursor.nextDuplicate!=nil) {
        tmp = cursor;
        cursor = cursor.nextDuplicate;
        [tmp setNextDuplicate: nil]; // Deletes the nextDuplicate AND refreshCount
    }
    
}

-(void) setDuplicateRefreshCount:(NSInteger)count {
    [self addToStore: [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInteger:count ], keyDupRefresh, nil]];
}

-(NSInteger) duplicateRefreshCount {
    return [[self->_store objectForKey:keyDupRefresh] integerValue];
}


@end
