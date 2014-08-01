//
//  LeftDataSource.m
//  FileCatalyst1
//
//  Created by Viktoryia Labunets on 12/30/12.
//  Copyright (c) 2012 Nuno Brum. All rights reserved.
//

#import "FolderCellView.h"
#import "TreeItem.h"
#import "TreeLeaf.h"
#import "TreeBranch.h"
#import "TreeRoot.h"
#import "FileInformation.h"
#import "LeftDataSource.h"


#define COL_FILENAME @"NameID"
#define COL_DATE     @"ModifiedID"
#define COL_SIZE     @"SizeID"


void DateFormatter(NSDate *date, NSString **output) {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    
    //NSLocale *systemLocale = [[NSLocale alloc] init];
    //[dateFormatter setLocale:systemLocale];
    
    *output = [dateFormatter stringFromDate:date];
    // Output:
    // Date for locale en_US: Jan 2, 2001

}

@interface LeftDataSource ( PrivateMethods )

-(void) _refreshDataView;

@end

@implementation LeftDataSource

-(void)setTreeOutlineView:(NSOutlineView*) outlineView {
    _TreeOutlineView = outlineView;
    [outlineView setDataSource:self];
    [outlineView setDelegate:self];
}

-(void)setTableView:(NSTableView*) tableView {
    _TableView = tableView;
    [tableView setDataSource:self];
    [tableView setDelegate:self];
}



-(NSOutlineView*) treeOutlineView {
    return _TreeOutlineView;
}

-(LeftDataSource*) init {
    self = [super init];
    self->_extendToSubdirectories = NO;
    self->tableData = [[NSMutableArray new] init];
    self->_foldersInTable = YES;
    self->_catalystMode = YES;
    return self;
}

-(id) getFileAtIndex:(NSUInteger)index {
    return [tableData objectAtIndex:index];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    //NSLog(@"number of children %@", item);
    if(item==nil) {
        return [_LeftBaseDirectories count];
    }
    else {
        // Returns the total number of leafs
        return [item numberOfBranchesInNode];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    //NSLog(@"child # %ld of %@", (long)index, item);
    id ret;
    if (item==nil || [item isKindOfClass:[NSMutableArray class]])
        ret = [_LeftBaseDirectories objectAtIndex:index];
    else {
        ret = [item branchAtIndex:index];
    }
    if ([ret isBranch] && _catalystMode==NO)
        [ret refreshTreeFromURLs];
    return ret;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    //NSLog(@"Is expandable: %@", item);
    if ([item isKindOfClass:[NSMutableArray class]])
        return [item count]>1 ? YES : NO;
    else {
            return ([item isBranch] && [item numberOfBranchesInNode]!=0) ? YES : NO;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    //NSLog(@"Object of %@", item);
    return item;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSView *result = [outlineView makeViewWithIdentifier:[tableColumn identifier] owner:self];
    if ([result isKindOfClass:[FolderCellView class]]) {
        FolderCellView *cellView = (FolderCellView *)result;
        
        if ([[tableColumn identifier] isEqualToString:COL_FILENAME]) {
            if ([item isKindOfClass:[TreeLeaf class]]) {//if it is a file
                // This is not needed now since the Tree View is not displaying files in this application
            }
            else if ([item isKindOfClass:[TreeBranch class]]) { // it is a directory
                // Display the directory name followed by the number of files inside
                NSString *path = [(TreeBranch*)item path];
                NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
                
                NSString *subTitle;
                if (self->_catalystMode==YES) {
                    subTitle = [NSString stringWithFormat:@"%ld Files %@",
                                (long)[(TreeBranch*)item numberOfLeafsInBranch],
                                [NSByteCountFormatter stringFromByteCount:[item byteSize] countStyle:NSByteCountFormatterCountStyleFile]];
                }
                else {
                    subTitle = @""; //[NSString stringWithFormat:@"%ld Files here",
                                //(long)[(TreeBranch*)item numberOfLeafsInBranch]];
                }
                [cellView setSubTitle:subTitle];
                [[cellView imageView] setImage:icon];
                [cellView setTitle:[item name]];
            }
        }
    }
    return result;
}

//- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
//    
//}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
     //if ((tableColumn != nil) || [[tableColumn identifier] isEqualToString:COL_FILENAME]) {
     //       [item setTitle:object];
     //
    //}
    NSLog(@"setObjectValue Object Class %@ Table Column %@ Item %@",[(NSObject*)object class], tableColumn.identifier, [item name]);
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
//    if ([item isKindOfClass:[TreeBranch class]]) {
//        TreeItem *treeItem = item;
//        if (treeItem  != nil) {
//            // We could dynamically change the thumbnail size, if desired
//            return IMAGE_SIZE + PADDING_AROUND_INFO_IMAGE; // The extra space is padding around the cell
//        }
//    }
    return [outlineView rowHeight];
}

//- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
//    if ([[tableColumn identifier] isEqualToString:COL_FILENAME]) {
//        if ([item isKindOfClass:[TreeLeaf class]]) {//if it is a file
//            // This is not needed now since the Tree View is not displaying files in this application
//        }
//        else if ([item isKindOfClass:[TreeBranch class]] && // it is a directory
//                 [cell isKindOfClass:[FolderCellView class]]) { // It is a Image Preview Class
//            // Display the directory name followed by the number of files inside
//            NSString *path = [(TreeBranch*)item path];
//            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
//            [icon setBackgroundColor:[NSColor whiteColor]];
//            [icon setSize:iconSize];
//            
//            NSString *subTitle = [NSString stringWithFormat:@"%ld Files %@", (long)[(TreeBranch*)item numberOfLeafsInBranch], [NSByteCountFormatter stringFromByteCount:[item byteSize] countStyle:NSByteCountFormatterCountStyleFile]];
//            [cell setSubTitle:subTitle];
//            [cell setImage:icon];
//            
//        }
//    }
//    else
//        NSLog(@"Cell Class %@ Table Column %@ Item %@",[(NSObject*)cell class], tableColumn.identifier, [item name]);
//}


/* Called before the outline is selected.
 Workaround to make the path bar always updated.
 Can be used later to block access to private directories */
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    [_PathBar setURL: [item theURL]];
    _treeNodeSelected = item;
    return YES;
}

// NSWorkspace Class Reference - (NSImage *)iconForFile:(NSString *)fullPath

-(void) refreshDataView {
    /* Always uses the _treeNodeSelected property to manage the Table View */
    if ([_treeNodeSelected isKindOfClass:[TreeBranch class]]){
        if (self->_extendToSubdirectories==YES && self->_foldersInTable==YES) {
            tableData = [(TreeBranch*)_treeNodeSelected itemsInBranch];
        }
        else if (self->_extendToSubdirectories==YES && self->_foldersInTable==NO) {
            tableData = [(TreeBranch*)_treeNodeSelected leafsInBranch];
        }
        else if (self->_extendToSubdirectories==NO && self->_foldersInTable==YES) {
            tableData = [(TreeBranch*)_treeNodeSelected itemsInNode];
        }
        else if (self->_extendToSubdirectories==NO && self->_foldersInTable==NO) {
            tableData = [(TreeBranch*)_treeNodeSelected leafsInNode];
        }
    }
}

// Table Data Source Protocol
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    [self refreshDataView];
    return [tableData count];
}

- (NSView *)tableView:(NSTableView *)aTableView viewForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    TreeItem *theFile = [tableData objectAtIndex:rowIndex];
    // In IB the tableColumn has the identifier set to the same string as the keys in our dictionary
    NSString *identifier = [aTableColumn identifier];
    // We pass us as the owner so we can setup target/actions into this main controller object
    NSTableCellView *cellView = [aTableView makeViewWithIdentifier:identifier owner:self];

    if ([identifier isEqualToString:COL_FILENAME]) {
        NSString *path = [theFile path];
        if (path) {
            // Then setup properties on the cellView based on the column
            cellView.textField.stringValue = [theFile name];  // Display simply the name of the file;
            cellView.imageView.objectValue = [[NSWorkspace sharedWorkspace] iconForFile:path];
        }
    }
    else if ([identifier isEqualToString:COL_SIZE]) {
        if (_catalystMode==NO && [theFile isKindOfClass:[TreeBranch class]]){
            //cellView.textField.objectValue = [NSString stringWithFormat:@"%ld Items", [(TreeBranch*)theFile numberOfItemsInNode]];
            cellView.textField.objectValue = @"--";
        }
        else
            cellView.textField.objectValue = [NSByteCountFormatter stringFromByteCount:[theFile byteSize] countStyle:NSByteCountFormatterCountStyleFile];

    } else if ([identifier isEqualToString:COL_DATE]) {
        NSString *result=nil;
        DateFormatter([theFile dateModified], &result);
        if (result == nil)
            cellView.textField.stringValue = NSLocalizedString(@"(Date)", @"Unknown Date");
        else
            cellView.textField.stringValue = result;
    }
    else {
        /* Debug code for further implementation */
        cellView.textField.stringValue = [NSString stringWithFormat:@"%@ %ld", aTableColumn.identifier, rowIndex];
    }
    return cellView;
}

-(void) setFilterText:(NSString *) filterText {
    self->_filterText = filterText;
}

-(void) refreshTrees {
    if (_catalystMode) {
        for (TreeRoot *tree in _LeftBaseDirectories) {
            [tree refreshTreeFromCollection];
        }
    }
    else {
        for (TreeRoot *tree in _LeftBaseDirectories) {
            [tree refreshTreeFromURLs];
        }
    }
}

-(void) addWithFileCollection:(FileCollection *)fileCollection callback:(void (^)(NSInteger fileno))callbackhandler {
    TreeRoot *rootDir = [[TreeRoot new] init];
    NSURL *rootpath = [NSURL URLWithString:[fileCollection rootPath]];
    
    // assigns the name to the root directory
    [rootDir setTheURL: rootpath];
    [rootDir setFileCollection: fileCollection];
    [rootDir setIsCollectionSet:YES];
    
    
    if(_LeftBaseDirectories==nil) {
        _LeftBaseDirectories = [[NSMutableArray new] init];
    }
    [_LeftBaseDirectories addObject: rootDir];
}
-(void) addWithRootPath:(NSURL*) rootPath {
    TreeRoot *rootDir = [[TreeRoot new] init];
    // assigns the name to the root directory
    [rootDir setTheURL: rootPath];
    [rootDir setFileCollection: NULL];
    [rootDir setIsCollectionSet:NO];
    //[rootDir refreshTreeFromURLs];

    if(_LeftBaseDirectories==nil) {
        _LeftBaseDirectories = [[NSMutableArray new] init];
    }
    [_LeftBaseDirectories addObject: rootDir];

}

-(TreeBranch*) selectFolderByURL:(NSURL*)theURL {
    NSRange result;
    BOOL found = false;
    TreeBranch *cursor = NULL;
    for(TreeRoot *root in _LeftBaseDirectories) {
        /* Checks if rootPath in root */
        NSString *path = [theURL path];
        result = [path rangeOfString:[root path]];
        if (NSNotFound!=result.location) {
            /* The URL is already contained in this tree */
            /* Start climbing tree */
            cursor = root;
            do {
                /* Test if the current directory is already a match */
                NSComparisonResult res = [[cursor path] compare:path];
                if (res==NSOrderedSame) { /* Matches the directory. Maybe there is a more clever way to do this. */
                    found = true;
                    break;
                }
                else {
                    found=FALSE;
                    for (TreeBranch *child in [cursor children]) {
                        result = [path rangeOfString:[child path]];
                        //NSLog(@"Cursor=%@ Child=%@, result=%lu", [cursor path], [child path], (unsigned long)result.location);
                        if (NSNotFound!=result.location) { /* Matches the directory. Maybe there is a more clever way to do this. */
                            cursor = child;
                            found = true;
                            break;
                        }
                        
                    }
                }
            } while (found);
        }
        if (found)
            break;
    }
    if (found) {/* Exited by the break */
        /* Select the node in the outline View */
        NSInteger row = [_TreeOutlineView rowForItem:cursor];
        if (row!=-1) {
            [_TreeOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            /* Sets the directory to be Displayed */
            _treeNodeSelected = cursor;
            /* Update data in the Table */
            [self refreshDataView];
        }
        return cursor;
    }
    return NULL;
}

-(void) removeRootWithIndex:(NSInteger)index {
    TreeRoot *itemToBeDeleted = [_LeftBaseDirectories objectAtIndex:index];
    [itemToBeDeleted removeBranch];
    [_LeftBaseDirectories removeObjectAtIndex:index];
}

-(void) removeRoot: (TreeRoot*) root {
    [root removeBranch];
    [_LeftBaseDirectories removeObjectIdenticalTo:root];
    [self refreshDataView];
}

// This method checks if a root can be added to existing set.
-(NSInteger) canAddRoot: (NSString*) rootPath {
    NSInteger answer = rootCanBeInserted;
    NSRange result;
    for(TreeRoot *root in _LeftBaseDirectories) {
        /* Checks if rootPath in root */
        result = [rootPath rangeOfString:[root path]];
        if (NSNotFound!=result.location) {
            // The new root is already contained in the existing trees
            answer = rootAlreadyContained;
            NSLog(@"The added path is contained in existing roots.");
            
        }
        else {
            /* The new contains exiting */
            result = [[root path] rangeOfString:rootPath];
            if (NSNotFound!=result.location) {
            // Will need to replace current position
                answer = rootContainsExisting;
                NSLog(@"The added path contains already existing roots, please delete them.");
            //[root removeBranch];
            //fileCollection_inst = [root fileCollection];
            }
        }
    }
    return answer;
}

-(FileCollection *) concatenateAllCollections {
    FileCollection *collection =[[FileCollection new] init];
    // Will concatenate all file collections into a single one.
    for (TreeRoot *theRoot in _LeftBaseDirectories) {
        [collection concatenateFileCollection: [theRoot fileCollection]];
    }
    return collection;
}



@end
