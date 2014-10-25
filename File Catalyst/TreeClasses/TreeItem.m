//
//  TreeItem.m
//  FileCatalyst1
//
//  Created by Viktoryia Labunets on 12/31/12.
//  Copyright (c) 2012 Nuno Brum. All rights reserved.
//

#import "TreeItem.h"
//#import "MyDirectoryEnumerator.h"
#import "TreeBranch.h"
#import "FileUtils.h"

@implementation TreeItem


-(TreeItem*) initWithURL:(NSURL*)url parent:(id)parent {
    self = [super init];
    if (self) {
        self.tag = 0;
        self->_url = url;
        self->_parent = parent;
    }
    return self;
}

-(TreeItem*) initWithMDItem:(NSMetadataItem*)mdItem parent:(id)parent {
    self = [super init];
    if (self) {
        NSString *path = [mdItem valueForAttribute:(id)kMDItemPath];
        self.tag = 0;
        self->_url = [NSURL fileURLWithPath:path];
        self->_parent = parent;
    }
    return self;
}


+(TreeItem *)treeItemForURL:(NSURL *)url parent:(id)parent {
    // We create folder items or image items, and ignore everything else; all based on the UTI we get from the URL

    NSString *typeIdentifier;
    if ([url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:NULL]) {
        if (isFolder(url)) {
            BOOL ispackage = isPackage(url);
            if (ispackage) {
                if (//[typeIdentifier isEqualToString:(NSString*)kUTTypeApplication] ||
                    //[typeIdentifier isEqualToString:(NSString*)kUTTypeApplicationFile] ||
                    [typeIdentifier isEqualToString:(NSString*)kUTTypeApplicationBundle]) {
                    id appsAsFolders =[[NSUserDefaults standardUserDefaults] objectForKey:@"prefsBrowseAppsAsFolder"];
                    if (appsAsFolders==NO) {
                        return [[TreeLeaf alloc] initWithURL:url parent:parent];
                    }
                }
                /* Debug Code */
                else if ([typeIdentifier isEqualToString:@"com.apple.xcode.project"] ||
                         [typeIdentifier isEqualToString:@"com.apple.dt.document.workspace"]) {
                    return [[TreeLeaf alloc] initWithURL:url parent:parent];
                }
            }
            if (//[typeIdentifier isEqualToString:(NSString *)kUTTypeFolder] ||
                [typeIdentifier isEqualToString:(NSString *)kUTTypeVolume]) {
                NSLog(@"This is a Volume. TODO !!! Create a dedicated class" );
            }
            return [[TreeBranch alloc] initWithURL:url parent:parent];
        }
        else {
            /* Check if it is an image type */
            NSArray *imageUTIs = [NSImage imageTypes];
            if ([imageUTIs containsObject:typeIdentifier]) {
                // !!! TODO : Treat here other file types other than just not folders
                return [[TreeLeaf alloc] initWithURL:url parent:parent];
            }
            return [[TreeLeaf alloc] initWithURL:url parent:parent];
        }
    }
    return nil;
}

+(TreeItem *)treeItemForMDItem:(NSMetadataItem *)mdItem parent:(id)parent {
    // We create folder items or image items, and ignore everything else; all based on the UTI we get from the URL
    NSString *typeIdentifier = [mdItem valueForAttribute:(id)kMDItemContentType];
    NSString *path = [mdItem valueForAttribute:(id)kMDItemPath];
    //NSURL *url = [NSURL fileURLWithPath:path];
    NSLog(@"%@ - %@", path, typeIdentifier);
        if ([typeIdentifier isEqualToString:(NSString *)kUTTypeFolder] || // !!! TODO: Correct this conditions
            [typeIdentifier isEqualToString:(NSString *)kUTTypeVolume]) {
            return [[TreeBranch alloc] initWithMDItem:mdItem parent:parent];
        }
        else if (//[typeIdentifier isEqualToString:(NSString*)kUTTypeApplication] ||
                 //[typeIdentifier isEqualToString:(NSString*)kUTTypeApplicationFile] ||
                 [typeIdentifier isEqualToString:(NSString*)kUTTypeApplicationBundle]) {
            NSString *path = [mdItem valueForAttribute:(id)kMDItemPath];
            NSURL *url = [NSURL fileURLWithPath:path];
            if (!isFolder(url)) {
                NSLog(@"Ai Ai As aplicações não são folders");
            }
            id appsAsFolders =[[NSUserDefaults standardUserDefaults] objectForKey:@"prefsBrowseAppsAsFolder"];
            if (appsAsFolders) {
                return [[TreeBranch alloc] initWithURL:url parent:parent];
            }
        }
        NSArray *imageUTIs = [NSImage imageTypes];
        if ([imageUTIs containsObject:typeIdentifier]) { // !!! TODO : Correct This condition
            // !!! TODO : Treat here other file types other than just not folders
            return [[TreeLeaf alloc] initWithMDItem:mdItem parent:parent];
        }
        else {
            return [[TreeLeaf alloc] initWithMDItem:mdItem parent:parent];
        }
    return nil;
}



-(void) setTag:(TreeItemTagEnum)tag {
    _tag |= tag;
}
-(void) resetTag:(TreeItemTagEnum)tag {
    _tag &= tag;
}
-(TreeItemTagEnum) tag {
    return _tag;
}

-(BOOL) hasTags:(TreeItemTagEnum) tag {
    return (_tag & tag)!=0 ? YES : NO;
}

-(BOOL) isBranch {
    NSAssert(NO, @"This method is supposed to not be called directly. Virtual Method.");
    return NO;
}

-(NSString*) name {
    NSString *nameStr = [_url lastPathComponent];
    if ([nameStr isEqualToString:@"/"]) {
        nameStr = mediaNameFromURL(_url);
    }
    return nameStr;
}

-(NSDate*) dateModified {
    NSDate *date=nil;
    NSError *errorCode;
    if ([_url isFileURL]) {
        [_url getResourceValue:&date forKey:NSURLContentModificationDateKey error:&errorCode];
        if (errorCode || date==nil) {
            [_url getResourceValue:&date forKey:NSURLContentAccessDateKey error:&errorCode];
            
        }
    }
    else {
        NSDictionary *dirAttributes =[[NSFileManager defaultManager] attributesOfItemAtPath:[_url path] error:NULL];
        date = [dirAttributes fileModificationDate];

    }
    return date;
}

-(NSString*) path {
    //NSString *path;
    //[_url getResourceValue:&path     forKey:NSURLPathKey error:NULL];
    return [_url path];
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

-(long long) filesize {
    NSNumber *filesize;
    [_url getResourceValue:&filesize     forKey:NSURLFileSizeKey error:NULL];
    return [filesize longLongValue];
}


-(BOOL) openFile {
    [[NSWorkspace sharedWorkspace] openFile:[self path]];
    return YES;
}

-(BOOL) removeItem {
    if (_parent) {
        [(TreeBranch*)_parent removeChild:self];
    }
    return YES;
}

#pragma mark -
#pragma mark URL comparison methods

-(NSInteger) relationTo:(NSString*) otherPath {
    NSRange result;
    NSInteger answer = pathsHaveNoRelation;
    NSString *myPath = [self path];

    if ([myPath isEqualToString:otherPath])
        return pathIsSame;

    result = [otherPath rangeOfString:myPath];
    if (NSNotFound!=result.location) {
        // The new root is already contained in the existing trees
        answer = pathIsChild;
    }
    else {
        /* The new contains exiting */
        result = [myPath rangeOfString:otherPath];
        if (NSNotFound!=result.location) {
            // Will need to replace current position
            answer = pathIsParent;
        }
    }
    return answer;
}

-(BOOL) containsURL:(NSURL*)url {
    NSRange result;
    result = [[url path] rangeOfString:[self path]];
    if (NSNotFound!=result.location) {
        // The new root is already contained in the existing trees
        return YES;
    }
    else {
        return NO;
    }
}

-(BOOL) containedInURL: (NSURL*) url {
    NSRange result;
    result = [[self path] rangeOfString:[url path]];
    if (NSNotFound!=result.location) {
        // The new root is already contained in the existing trees
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark -
#pragma mark NSPasteboardWriting support

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
        // !!! Todo What to do here
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
    return [NSArray arrayWithObjects: //(id)kUTTypeFolder, (id)kUTTypeFileURL, (id)kUTTypeItem,
            (id)NSFilenamesPboardType, (id)NSURLPboardType, OwnUTITypes nil];

}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    return NSPasteboardReadingAsString;
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    // We recreate the appropriate object
#ifdef USE_UTI
    if (UTTypeEqual ((__bridge CFStringRef)(type),kTreeItemDropUTI)) {
        // !!! Todo What to do here
        return propertyList; // !!! TODO check if this works
    }
    else 
#endif
    {
        // We only have URLs accepted. Create the URL
        NSURL *url = [[NSURL alloc] initWithPasteboardPropertyList:propertyList ofType:type] ;
        return [TreeItem treeItemForURL:url parent:nil];
    }
}

#pragma mark -


@end
